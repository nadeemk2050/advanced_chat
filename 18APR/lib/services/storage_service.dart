import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class MediaStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _uuid = const Uuid().v4();

  Future<String?> uploadImage(File file) async {
    try {
      final ref = _storage.ref().child('chat_images').child('$_uuid.jpg');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  // Web Support for Images
  Future<String?> uploadImageHtml(Uint8List bytes) async {
    try {
      final ref = _storage.ref().child('chat_images').child('$_uuid.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      print('Web image upload error: $e');
      return null;
    }
  }

  Future<String?> uploadAudio(File file) async {
    try {
      final ref = _storage.ref().child('chat_audio').child('$_uuid.m4a');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<String?> uploadAudioWeb(Uint8List bytes, String fileName) async {
    try {
      final ref = _storage.ref().child('chat_audio').child('$_uuid-$fileName');
      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'audio/wav'),
      );
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  // NEW: General File Upload (Universal)
  Future<String?> uploadFile(File file, String fileName) async {
    try {
      final ref = _storage.ref().child('chat_docs').child(_uuid).child(fileName);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  // NEW: Web Support for General Files
  Future<String?> uploadFileWeb(Uint8List bytes, String fileName) async {
    try {
      final ref = _storage.ref().child('chat_docs').child(_uuid).child(fileName);
      await ref.putData(bytes);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  /// Upload image (web) with live progress via callback [onProgress] (0.0 – 1.0).
  Future<String?> uploadImageHtmlWithProgress(
    Uint8List bytes, {
    void Function(double)? onProgress,
  }) async {
    try {
      final ref = _storage.ref().child('chat_images').child('${const Uuid().v4()}.jpg');
      final task = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      task.snapshotEvents.listen((snap) {
        if (onProgress != null && snap.totalBytes > 0) {
          onProgress(snap.bytesTransferred / snap.totalBytes);
        }
      });
      await task;
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  /// Upload file (web) with live progress.
  Future<String?> uploadFileWebWithProgress(
    Uint8List bytes,
    String fileName, {
    void Function(double)? onProgress,
  }) async {
    try {
      final ref = _storage.ref().child('chat_docs').child(const Uuid().v4()).child(fileName);
      final task = ref.putData(bytes);
      task.snapshotEvents.listen((snap) {
        if (onProgress != null && snap.totalBytes > 0) {
          onProgress(snap.bytesTransferred / snap.totalBytes);
        }
      });
      await task;
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      print('Delete error: $e');
    }
  }
}
