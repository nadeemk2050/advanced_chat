import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_models.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign Up
  Future<UserCredential?> signUp(String email, String password, String name) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user in Firestore
      UserModel newUser = UserModel(
        uid: credential.user!.uid,
        name: name,
        email: email,
        lastSeen: DateTime.now(),
        isOnline: true,
      );

      await _firestore.collection('users').doc(newUser.uid).set(newUser.toMap());
      return credential;
    } catch (e) {
      print('Sign Up Error: $e');
      return null;
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
}
