import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init() async {
    // 1. Request Permission
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // 2. Refresh Token
    _updateToken();

    // 3. Listen for Foreground Messages (Simple Alert)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('New message received: ${message.notification?.body}');
    });
  }

  Future<void> _updateToken() async {
    String? token = await _fcm.getToken();
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (token != null && uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': token,
      });
    }
  }
}
