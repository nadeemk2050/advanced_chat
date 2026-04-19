import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_models.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign Up
  Future<UserCredential?> signUp(String email, String password, String name) async {
    try {
      // 1. Solid Username Check (Case-Insensitive)
      final nameCheck = await _firestore
          .collection('users')
          .where('nameLowercase', isEqualTo: name.toLowerCase().trim())
          .get();
      if (nameCheck.docs.isNotEmpty) {
        throw Exception('The username "$name" is already taken. Please try another one. 🛡️');
      }

      // 2. Solid Email Check (Pre-check for better messaging)
      final emailCheck = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase().trim())
          .get();
      if (emailCheck.docs.isNotEmpty) {
        throw Exception('The email "$email" is already linked to an account. Did you forget your password? 🔑');
      }

      // 3. Create Firebase Auth account
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 4. Create record in Firestore
      UserModel newUser = UserModel(
        uid: credential.user!.uid,
        name: name.trim(),
        nameLowercase: name.toLowerCase().trim(),
        email: email.toLowerCase().trim(),
        lastSeen: DateTime.now(),
        isOnline: true,
        photoUrl: '',
        blockedUsers: [],
        isVisibleInMembersList: true,
      );

      await _firestore.collection('users').doc(newUser.uid).set(newUser.toMap());
      return credential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('This email is already in use by another user.');
      } else if (e.code == 'weak-password') {
        throw Exception('The password provided is too weak.');
      } else if (e.code == 'invalid-email') {
        throw Exception('The email address is not valid.');
      }
      rethrow;
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
