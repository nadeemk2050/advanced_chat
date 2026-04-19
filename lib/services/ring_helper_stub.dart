/// Web / unsupported platform stub — all methods are no-ops.
class RingHelper {
  RingHelper._();
  static final RingHelper instance = RingHelper._();
  Future<void> init() async {}
  Future<void> showRingNotification(String senderName) async {}
  Future<void> cancelRingNotification() async {}
  Future<void> showMessageNotification(String senderName, String text) async {}
  Future<void> scheduleTaskAlarm(String id, String title, DateTime alarmTime) async {}
  Future<void> cancelTaskAlarm(String id) async {}
}
