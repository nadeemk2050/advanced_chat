import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_models.dart';
import 'database_service.dart';

class ChatService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _localDb = LocalDatabaseService();

  // Get Chat ID (Unique for 2 users)
  String getChatRoomId(String user1, String user2) {
    List<String> ids = [user1, user2];
    ids.sort();
    return ids.join('_');
  }

  // Send Message
  Future<void> sendMessage(String text, String receiverId, {MessageType type = MessageType.text, String? mediaUrl}) async {
    final String currentUserId = _auth.currentUser!.uid;
    final String chatRoomId = getChatRoomId(currentUserId, receiverId);
    
    final MessageModel newMessage = MessageModel(
      id: '', // Firestore will generate
      senderId: currentUserId,
      text: text,
      type: type,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
      mediaUrl: mediaUrl,
    );

    // Add to Firestore
    final docRef = await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add(newMessage.toMap());

    // Update message with ID and save locally
    final savedMsg = newMessage; // Should ideally use docRef.id
    await _localDb.saveMessage(savedMsg);
  }

  // Stream of Messages
  Stream<QuerySnapshot> getMessages(String otherUserId) {
    String chatRoomId = getChatRoomId(_auth.currentUser!.uid, otherUserId);
    return _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}
