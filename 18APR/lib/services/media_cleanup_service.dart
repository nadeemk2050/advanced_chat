import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database_service.dart';
import '../models/chat_models.dart';

class MediaCleanupService {
  static final MediaCleanupService _instance = MediaCleanupService._internal();
  factory MediaCleanupService() => _instance;
  MediaCleanupService._internal();

  bool _isRunning = false;

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    Timer.periodic(const Duration(hours: 1), (timer) {
      _runCleanup();
    });
    // Run once immediately
    _runCleanup();
  }

  Future<void> _runCleanup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. Get all messages from Local DB that have mediaUrl and are > 24 hours old
    // We assume if it's in local DB, it's saved (or should be handled by a downloader).
    
    // For this demonstration, we focus on messages SENT by this user 
    // because you can only delete your own files from storage normally.
    
    final db = LocalDatabaseService();
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    
    // We'll search for messages with media links
    final results = await db.searchGlobal('http'); 
    
    for (var row in results) {
      final ts = DateTime.parse(row['timestamp']);
      if (ts.isBefore(cutoff)) {
        final url = row['mediaUrl'] as String?;
        final senderId = row['senderId'] as String?;
        final msgId = row['messageId'] as String?;
        final roomId = row['chatRoomId'] as String?;
        final isGroup = (row['isGroup'] as int? ?? 0) == 1;

        if (url != null && senderId == user.uid && url.contains('firebasestorage')) {
          try {
            // Delete from storage
            await FirebaseStorage.instance.refFromURL(url).delete();
            
            // Clear URL from Firestore to signify it's expired in cloud
            if (isGroup) {
              await FirebaseFirestore.instance
                  .collection('groups').doc(roomId)
                  .collection('messages').doc(msgId)
                  .update({'mediaUrl': null, 'text': '[Media Cloud Expired] ${row['text']}'});
            } else {
              await FirebaseFirestore.instance
                  .collection('chats').doc(roomId)
                  .collection('messages').doc(msgId)
                  .update({'mediaUrl': null, 'text': '[Media Cloud Expired] ${row['text']}'});
            }
          } catch (e) {
            print('Cleanup error: $e');
          }
        }
      }
    }
  }
}
