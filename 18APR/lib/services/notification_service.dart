import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'media_cleanup_service.dart';

// Conditionally import the real flutter_local_notifications helper only on
// non-web platforms (dart.library.io = Dart VM = Android/iOS/desktop).
import 'ring_helper_stub.dart' if (dart.library.io) 'ring_helper_mobile.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init() async {
    if (kIsWeb) {
      debugPrint('NotificationService: messaging disabled for web.');
      return;
    }

    try {
      // 1. Init platform-specific local notifications (Android/iOS)
      await RingHelper.instance.init();

      // 2. Request FCM permissions
      await _fcm.requestPermission(alert: true, badge: true, sound: true);
      await _fcm.setForegroundNotificationPresentationOptions(
          alert: true, badge: true, sound: true);

      // 3. Save / refresh FCM token in Firestore
      await _updateToken();
      _fcm.onTokenRefresh.listen((token) async {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .update({'fcmToken': token});
        }
      });

      // 4. Handle FCM when app is in foreground
      FirebaseMessaging.onMessage.listen((message) {
        final data = message.data;
        if (data['type'] == 'ring') {
          RingHelper.instance
              .showRingNotification(data['senderName'] ?? 'Someone');
        } else if (data['type'] == 'message') {
          RingHelper.instance.showMessageNotification(
            data['senderName'] ?? 'Message',
            data['messageText'] ?? '...',
          );
        }
      });

      // 5. Start Temporal Cloud Cleanup
      MediaCleanupService().start();
      
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  Future<void> _updateToken() async {
    try {
      final token = await _fcm.getToken();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (token != null && uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'fcmToken': token});
      }
    } catch (e) {
      debugPrint('FCM token update skipped: $e');
    }
  }

  Future<void> showRingNotification(String senderName) =>
      RingHelper.instance.showRingNotification(senderName);

  Future<void> cancelRingNotification() =>
      RingHelper.instance.cancelRingNotification();

  Future<void> scheduleTaskAlarm(String id, String title, DateTime alarmTime) =>
      RingHelper.instance.scheduleTaskAlarm(id, title, alarmTime);

  Future<void> cancelTaskAlarm(String id) =>
      RingHelper.instance.cancelTaskAlarm(id);
}
