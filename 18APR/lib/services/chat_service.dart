import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_models.dart';
import 'database_service.dart';
import 'storage_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final MediaStorageService _storage = MediaStorageService();

  String getChatRoomId(String userA, String userB) {
    List<String> ids = [userA, userB];
    ids.sort();
    return ids.join('_');
  }

  Future<void> sendMessage(
    String text,
    String receiverId, {
    MessageType type = MessageType.text,
    String? mediaUrl,
    String? fileName,
    String? replyToMessageId,
    String? replyToText,
  }) async {
    final String currentUserId = _auth.currentUser!.uid;
    final String chatRoomId = getChatRoomId(currentUserId, receiverId);
    final String messageId = const Uuid().v4();
    final Timestamp timestamp = Timestamp.now();

    MessageModel newMessage = MessageModel(
      messageId: messageId,
      senderId: currentUserId,
      text: text,
      timestamp: timestamp.toDate(),
      type: type,
      mediaUrl: mediaUrl,
      fileName: fileName,
      status: MessageStatus.sent,
      replyToMessageId: replyToMessageId,
      replyToText: replyToText,
    );

    // Ensure the parent chat document exists with participants so message rules pass
    await _firestore.collection('chats').doc(chatRoomId).set({
      'participants': [currentUserId, receiverId],
    }, SetOptions(merge: true));

    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .set({
          ...newMessage.toMap(),
          'deletedFor': [],
        });

    await _upsertChatThreadFromMessage(
      chatRoomId: chatRoomId,
      senderId: currentUserId,
      receiverId: receiverId,
      message: newMessage,
      timestamp: timestamp,
    );

    if (type != MessageType.ring) {
      await _localDb.saveMessage(newMessage, chatRoomId);
    }
  }

  Future<void> sendRingSignal(String receiverId) async {
    final uid = _auth.currentUser!.uid;
    // Fetch sender name from Firestore
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userName = userDoc.data()?['name'] as String? ?? 'Someone';
    final chatRoomId = getChatRoomId(uid, receiverId);

    // Write to ring_signals — this triggers the Cloud Function to send FCM
    await _firestore.collection('ring_signals').doc(receiverId).set({
      'active': true,
      'senderId': uid,
      'senderName': userName,
      'chatRoomId': chatRoomId,
      'startedAt': Timestamp.now(),
      'stoppedAt': null,
    });

    // Also write a visual ring message in the chat for record
    await sendMessage("🔔 Wake up! Calling you...", receiverId, type: MessageType.ring);
  }

  /// Stop the ring signal. Pass the userId whose ring_signals doc should be cleared.
  /// Receiver calls this with their own uid; sender calls with receiver's uid.
  Future<void> stopRingSignal(String targetUserId) async {
    try {
      await _firestore.collection('ring_signals').doc(targetUserId).update({
        'active': false,
        'stoppedAt': Timestamp.now(),
      });
    } catch (_) {}
  }

  /// Listen to the ring_signals doc for the currently logged-in user (incoming rings).
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenMyRingSignal() {
    final uid = _auth.currentUser?.uid ?? '';
    return _firestore.collection('ring_signals').doc(uid).snapshots();
  }

  /// Listen to the ring_signals doc for a specific user (sender uses this to
  /// detect when the receiver has stopped the ring).
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenRingSignalOf(String userId) {
    return _firestore.collection('ring_signals').doc(userId).snapshots();
  }

  Stream<QuerySnapshot> getMessages(String otherUserId, {int limit = 50}) {
    String chatRoomId = getChatRoomId(_auth.currentUser!.uid, otherUserId);
    unawaited(_markMessagesAsRead(chatRoomId, otherUserId));

    return _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Returns paginated older messages before [lastTimestamp].
  Future<List<MessageModel>> loadOlderMessages(
    String otherUserId,
    DateTime beforeTimestamp, {
    int pageSize = 30,
  }) async {
    final chatRoomId = getChatRoomId(_auth.currentUser!.uid, otherUserId);
    final snap = await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .startAfter([Timestamp.fromDate(beforeTimestamp)])
        .limit(pageSize)
        .get();
    return snap.docs.map((d) => MessageModel.fromMap(d.data())).toList();
  }

  Stream<List<MessageModel>> getStarredMessages(String otherUserId) {
    final chatRoomId = getChatRoomId(_auth.currentUser!.uid, otherUserId);
    return _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .where('isStarred', isEqualTo: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => MessageModel.fromMap(d.data())).toList());
  }

  Future<void> toggleStarMessage(String otherUserId, String messageId, bool currentlyStarred) async {
    if (messageId.isEmpty) return;
    final chatRoomId = getChatRoomId(_auth.currentUser!.uid, otherUserId);
    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .update({'isStarred': !currentlyStarred});
  }

  /// Write status (typing/recording/idle).
  Future<void> setUserStatus(String otherUserId, UserChatStatus status) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final chatRoomId = getChatRoomId(uid, otherUserId);
    await _firestore.collection('chats').doc(chatRoomId).set({
      'participants': [uid, otherUserId],
      'status_$uid': status.index,
      'statusAt_$uid': status != UserChatStatus.idle ? Timestamp.now() : null,
    }, SetOptions(merge: true));
  }

  /// Emits the partner's current status string.
  Stream<String> getPartnerStatus(String otherUserId) {
    final uid = _auth.currentUser?.uid ?? '';
    final chatRoomId = getChatRoomId(uid, otherUserId);
    return _firestore
        .collection('chats')
        .doc(chatRoomId)
        .snapshots()
        .map((snap) {
          if (!snap.exists) return '';
          final data = snap.data() ?? {};
          final statusIndex = data['status_$otherUserId'] as int? ?? 0;
          final status = UserChatStatus.values[statusIndex];
          if (status == UserChatStatus.idle) return '';
          
          final ts = data['statusAt_$otherUserId'];
          if (ts == null) return '';
          final lastStatusAt = ts is Timestamp ? ts.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
          
          if (DateTime.now().difference(lastStatusAt).inSeconds > 10) return '';
          
          if (status == UserChatStatus.typing) return 'Typing...';
          if (status == UserChatStatus.recording) return 'Recording audio...';
          return '';
        });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getChatThreads() {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: _auth.currentUser!.uid)
        .snapshots();
  }

  Future<void> syncChatThread(String otherUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    final chatRoomId = getChatRoomId(currentUserId, otherUserId);
    
    // Explicitly create the chat room document with participants if it doesn't exist
    await _firestore.collection('chats').doc(chatRoomId).set({
      'participants': [currentUserId, otherUserId],
    }, SetOptions(merge: true));

    await _refreshChatRoomSummary(chatRoomId, [currentUserId, otherUserId]);
  }

  Future<void> editMessage(String otherUserId, String messageId, String newText) async {
    if (messageId.isEmpty) return;
    String currentUserId = _auth.currentUser!.uid;
    String chatRoomId = getChatRoomId(currentUserId, otherUserId);
    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .update({
          'text': newText,
          'isEdited': true,
        });

    await _refreshChatRoomSummary(chatRoomId, [currentUserId, otherUserId]);
  }

  Future<void> deleteForEveryone(String otherUserId, String messageId, {String? mediaUrl}) async {
    if (messageId.isEmpty) return;
    String currentUserId = _auth.currentUser!.uid;
    String chatRoomId = getChatRoomId(currentUserId, otherUserId);
    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .update({
          'isDeleted': true,
          'text': '🚫 This message was deleted',
          'type': MessageType.text.index,
          'mediaUrl': null,
          'fileName': null,
        });

    await _refreshChatRoomSummary(chatRoomId, [currentUserId, otherUserId]);

    if (mediaUrl != null) {
      await _storage.deleteFile(mediaUrl);
    }
  }

  Future<void> deleteForMe(String otherUserId, String messageId) async {
    if (messageId.isEmpty) return;
    String chatRoomId = getChatRoomId(_auth.currentUser!.uid, otherUserId);
    String myUid = _auth.currentUser!.uid;

    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .update({
          'deletedFor': FieldValue.arrayUnion([myUid])
        });
  }

  Future<void> _markMessagesAsRead(String chatRoomId, String senderId) async {
    try {
      var senderMessages = await _firestore
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .where('senderId', isEqualTo: senderId)
          .get();

      final batch = _firestore.batch();
      var hasUpdates = false;

      for (var doc in senderMessages.docs) {
        final data = doc.data();
        if (data['status'] != MessageStatus.read.index) {
          batch.update(doc.reference, {'status': MessageStatus.read.index});
          hasUpdates = true;
        }
      }

      if (hasUpdates) {
        await batch.commit();
      }

      await _firestore.collection('chats').doc(chatRoomId).set({
        'unreadCounts.${_auth.currentUser!.uid}': 0,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } on FirebaseException {
      // Keep the chat usable in web preview even if Firestore rules or indexes
      // reject the read-receipt update path.
    }
  }

  Future<void> addReaction(String otherUserId, String messageId, String emoji) async {
    if (messageId.isEmpty) return;
    String chatRoomId = getChatRoomId(_auth.currentUser!.uid, otherUserId);
    String myUid = _auth.currentUser!.uid;

    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .update({'reactions.$myUid': emoji});
  }

  Future<void> _upsertChatThreadFromMessage({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required MessageModel message,
    required Timestamp timestamp,
  }) async {
    await _firestore.collection('chats').doc(chatRoomId).set({
      'participants': [senderId, receiverId],
      'lastMessageText': _previewText(message),
      'lastMessageType': message.type.index,
      'lastMessageId': message.messageId,
      'lastSenderId': senderId,
      'lastMessageAt': timestamp,
      'updatedAt': timestamp,
      'unreadCounts.$senderId': 0,
      'unreadCounts.$receiverId': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  Future<void> _refreshChatRoomSummary(String chatRoomId, List<String> participants) async {
    final messagesSnapshot = await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .get();

    if (messagesSnapshot.docs.isEmpty) {
      return;
    }

    final unreadCounts = <String, int>{
      for (final participant in participants) participant: 0,
    };

    MessageModel? latestMessage;
    for (final doc in messagesSnapshot.docs) {
      final message = MessageModel.fromMap(doc.data());
      if (latestMessage == null || message.timestamp.isAfter(latestMessage.timestamp)) {
        latestMessage = message;
      }

      for (final participant in participants) {
        if (message.senderId != participant && message.status != MessageStatus.read) {
          unreadCounts[participant] = (unreadCounts[participant] ?? 0) + 1;
        }
      }
    }

    if (latestMessage == null) {
      return;
    }

    await _firestore.collection('chats').doc(chatRoomId).set({
      'participants': participants,
      'lastMessageText': _previewText(latestMessage),
      'lastMessageType': latestMessage.type.index,
      'lastMessageId': latestMessage.messageId,
      'lastSenderId': latestMessage.senderId,
      'lastMessageAt': Timestamp.fromDate(latestMessage.timestamp),
      'updatedAt': Timestamp.now(),
      'unreadCounts': unreadCounts,
    }, SetOptions(merge: true));
  }

  // Block Management
  Future<void> toggleBlockUser(String otherUserId, bool currentlyBlocked) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    if (currentlyBlocked) {
      await _firestore.collection('users').doc(myUid).update({
        'blockedUsers': FieldValue.arrayRemove([otherUserId])
      });
    } else {
      await _firestore.collection('users').doc(myUid).update({
        'blockedUsers': FieldValue.arrayUnion([otherUserId])
      });
    }
  }

  Stream<bool> amIBlocking(String otherUserId) {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return Stream.value(false);

    return _firestore.collection('users').doc(myUid).snapshots().map((snap) {
      if (!snap.exists) return false;
      final data = snap.data();
      final List blocked = data?['blockedUsers'] ?? [];
      return blocked.contains(otherUserId);
    });
  }

  Stream<bool> isBlockedBy(String otherUserId) {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return Stream.value(false);

    return _firestore.collection('users').doc(otherUserId).snapshots().map((snap) {
      if (!snap.exists) return false;
      final data = snap.data();
      final List blockedByOthers = data?['blockedUsers'] ?? [];
      return blockedByOthers.contains(myUid);
    });
  }

  String _previewText(MessageModel message) {
    switch (message.type) {
      case MessageType.image: return 'Photo';
      case MessageType.audio: return 'Voice note';
      case MessageType.document: return message.fileName ?? 'Document';
      case MessageType.ring: return 'Wake-up ring';
      case MessageType.text: return message.text;
    }
  }

  // Connection Management
  Future<void> sendFriendRequest(String targetUserId) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;
    final id = getChatRoomId(myUid, targetUserId);
    await _firestore.collection('connections').doc(id).set({
      'senderId': myUid,
      'receiverId': targetUserId,
      'status': ConnectionStatus.pending.index,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acceptFriendRequest(String senderUserId) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;
    final id = getChatRoomId(myUid, senderUserId);
    await _firestore.collection('connections').doc(id).set({
      'senderId': senderUserId,
      'receiverId': myUid,
      'status': ConnectionStatus.accepted.index,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unfriend(String targetUserId) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;
    final id = getChatRoomId(myUid, targetUserId);
    final doc = await _firestore.collection('connections').doc(id).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final status = ConnectionStatus.values[data['status'] ?? 0];
    final senderId = data['senderId'];

    if (status == ConnectionStatus.accepted) {
      // If was accepted, change status based on who is unfriending
      final newStatus = (myUid == senderId) 
          ? ConnectionStatus.unfriendedBySender.index 
          : ConnectionStatus.unfriendedByReceiver.index;
      await _firestore.collection('connections').doc(id).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // If already partially unfriended by the OTHER person, change to none/delete
      bool isOtherPersonUnfriended = (myUid == senderId) 
          ? status == ConnectionStatus.unfriendedByReceiver 
          : status == ConnectionStatus.unfriendedBySender;
      
      if (isOtherPersonUnfriended) {
        await _firestore.collection('connections').doc(id).delete();
      } else {
        // If I am just cancelling my own request or re-unfriending
        await _firestore.collection('connections').doc(id).delete();
      }
    }
  }

  Future<void> reFriend(String targetUserId) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;
    final id = getChatRoomId(myUid, targetUserId);
    await _firestore.collection('connections').doc(id).update({
      'status': ConnectionStatus.accepted.index,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<ConnectionModel>> getIncomingFriendRequests() {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return Stream.value([]);
    return _firestore
        .collection('connections')
        .where('receiverId', isEqualTo: myUid)
        .where('status', isEqualTo: ConnectionStatus.pending.index)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ConnectionModel.fromMap(d.data())).toList());
  }

  Stream<List<ConnectionModel>> getSentFriendRequests() {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return Stream.value([]);
    return _firestore
        .collection('connections')
        .where('senderId', isEqualTo: myUid)
        .where('status', isEqualTo: ConnectionStatus.pending.index)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ConnectionModel.fromMap(d.data())).toList());
  }

  Stream<ConnectionModel?> getConnection(String otherUserId) {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return Stream.value(null);
    final id = getChatRoomId(myUid, otherUserId);
    return _firestore.collection('connections').doc(id).snapshots().map((snap) {
      if (!snap.exists) return null;
      return ConnectionModel.fromMap(snap.data()!);
    });
  }
}
