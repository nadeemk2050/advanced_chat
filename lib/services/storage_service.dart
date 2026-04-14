import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class MediaStorageService {
  final _storage = FirebaseStorage.instance;

  // Upload Image
  Future<String?> uploadImage(File file) async {
    try {
      final String fileName = const Uuid().v4();
      final ref = _storage.ref().child('chat_images/$fileName.jpg');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Image Upload Error: $e');
      return null;
    }
  }

  // Upload Audio
  Future<String?> uploadAudio(File file) async {
    try {
      final String fileName = const Uuid().v4();
      final ref = _storage.ref().child('chat_audio/$fileName.m4a');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Audio Upload Error: $e');
      return null;
    }
  }
}
