import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_models.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign Up
  Future<UserCredential?> signUp(String email, String password, String name) async {
    try {
      // 1. Check if name is already taken (Case-Insensitive)
      final nameCheck = await _firestore
          .collection('users')
          .where('nameLowercase', isEqualTo: name.toLowerCase())
          .get();
      if (nameCheck.docs.isNotEmpty) {
        throw Exception('This username is already taken. Please choose another.');
      }

      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user in Firestore
      UserModel newUser = UserModel(
        uid: credential.user!.uid,
        name: name,
        nameLowercase: name.toLowerCase(),
        email: email,
        lastSeen: DateTime.now(),
        isOnline: true,
        photoUrl: '',
        blockedUsers: [],
        isVisibleInMembersList: true,
      );

      await _firestore.collection('users').doc(newUser.uid).set(newUser.toMap());
      return credential;
    } catch (e) {
      print('Sign Up Error: $e');
      rethrow;
    }
  }

  // Sign In
  Future<UserCredential?> signIn(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update online status
      await _firestore.collection('users').doc(credential.user!.uid).update({
        'isOnline': true,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      });
      
      return credential;
    } catch (e) {
      print('Sign In Error: $e');
      return null;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    final String? uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _firestore.collection('users').doc(uid).update({
        'isOnline': false,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      });
    }
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;

  /// Update display name in Firestore (DISABLED: Names are immutable after first set)
  Future<bool> updateName(String name) async {
    return false; // Not allowed to change name anymore
  }

  /// Update profile photo URL in Firestore
  Future<bool> updatePhotoUrl(String photoUrl) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return false;
      await _firestore.collection('users').doc(uid).update({'photoUrl': photoUrl});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Update profile visibility in the members list
  Future<bool> updateVisibility(bool isVisible) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return false;
      await _firestore.collection('users').doc(uid).update({'isVisibleInMembersList': isVisible});
      return true;
    } catch (_) {
      return false;
    }
  }
}
