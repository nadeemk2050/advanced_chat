import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_models.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<QuerySnapshot> getGroups() {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: _auth.currentUser!.uid)
        // .orderBy('lastMessageAt', descending: true) // Index required for this
        .snapshots();
  }

  Future<String> createGroup(String name, List<String> members, {String? groupPhotoUrl}) async {
    final uid = _auth.currentUser!.uid;
    if (!members.contains(uid)) members.add(uid);

    final doc = _firestore.collection('groups').doc();
    await doc.set({
      'groupId': doc.id,
      'name': name,
      'members': members,
      'lastMessage': 'Group created',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'groupPhotoUrl': groupPhotoUrl,
      'createdBy': uid,
    });
    return doc.id;
  }

  Future<void> sendGroupMessage(
    String groupId,
    String text, {
    MessageType type = MessageType.text,
    String? mediaUrl,
    String? fileName,
    String? replyToText,
  }) async {
    final uid = _auth.currentUser!.uid;
    final messageId =
        _firestore.collection('group_messages').doc(groupId).collection('messages').doc().id;

    final message = MessageModel(
      messageId: messageId,
      senderId: uid,
      text: text,
      timestamp: DateTime.now(),
      type: type,
      mediaUrl: mediaUrl,
      fileName: fileName,
      replyToText: replyToText,
    );

    await _firestore
        .collection('group_messages')
        .doc(groupId)
        .collection('messages')
        .doc(messageId)
        .set(message.toMap());

    // Update last message in group
    await _firestore.collection('groups').doc(groupId).update({
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getGroupMessages(String groupId, {int limit = 50}) {
    return _firestore
        .collection('group_messages')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  Future<void> deleteGroupMessage(String groupId, String messageId) async {
    await _firestore
        .collection('group_messages')
        .doc(groupId)
        .collection('messages')
        .doc(messageId)
        .update({'isDeleted': true, 'text': 'This message was deleted'});
  }

  Future<void> addReaction(String groupId, String messageId, String emoji) async {
    final uid = _auth.currentUser!.uid;
    await _firestore
        .collection('group_messages')
        .doc(groupId)
        .collection('messages')
        .doc(messageId)
        .update({'reactions.$uid': emoji});
  }

  Future<List<UserModel>> getGroupMembers(List<String> memberUids) async {
    if (memberUids.isEmpty) return [];
    final snapshots = await _firestore.collection('users').where('uid', whereIn: memberUids).get();
    return snapshots.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
  }

  Future<void> inviteToGroup(String groupId, String targetUserId, String groupName) async {
    final myUid = _auth.currentUser!.uid;
    final inviteId = '${groupId}_$targetUserId';
    await _firestore.collection('group_invites').doc(inviteId).set({
      'inviteId': inviteId,
      'groupId': groupId,
      'groupName': groupName,
      'senderId': myUid,
      'receiverId': targetUserId,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> getIncomingInvites() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    return _firestore
        .collection('group_invites')
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  Future<void> respondToInvite(String inviteId, String groupId, bool accept) async {
    if (accept) {
      final uid = _auth.currentUser!.uid;
      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayUnion([uid])
      });
    }
    await _firestore.collection('group_invites').doc(inviteId).delete();
  }
}
