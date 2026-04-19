import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

/// Listens to app lifecycle events and keeps the user's `isOnline` / `lastSeen`
/// fields in Firestore in sync. Mount this as a [WidgetsBindingObserver] in
/// the root widget's [initState].
class PresenceService with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void activate() {
    try {
      WidgetsBinding.instance.addObserver(this);
      _setOnline(true);
    } catch (_) {}
  }

  void deactivate() {
    try {
      WidgetsBinding.instance.removeObserver(this);
      _setOnline(false);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _setOnline(true);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
        _setOnline(false);
        break;
      case AppLifecycleState.hidden:
        _setOnline(false);
        break;
    }
  }

  Future<void> _setOnline(bool online) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore.collection('users').doc(uid).update({
        'isOnline': online,
        'lastSeen': Timestamp.now(),
      });
    } catch (_) {
      // Best-effort — don't crash if Firestore rules reject or user is gone.
    }
  }
}
