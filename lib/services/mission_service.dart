import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/mission_model.dart';
import '../models/chat_models.dart';
import 'package:rxdart/rxdart.dart';

class MissionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // Stream of all missions the user is part of (Owner or Member)
  Stream<List<Mission>> getMissions() {
    final uid = _uid;
    if (uid.isEmpty) return Stream.value([]);
    return _db
        .collection('missions')
        .where('memberIds', arrayContains: uid)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Mission.fromMap(doc.data())).toList());
  }

  // Stream of tasks for a specific mission
  Stream<List<MissionTask>> getMissionTasks(String missionId) {
    final uid = _uid;
    if (uid.isEmpty) return Stream.value([]);
    return _db
        .collection('mission_tasks')
        .where('missionId', isEqualTo: missionId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => MissionTask.fromMap(doc.data())).toList());
  }

  Future<void> createMission(String title, MissionType type, {List<String> memberIds = const []}) async {
    final uid = _uid;
    if (uid.isEmpty) throw Exception("Uauthenticated. Please login.");
    
    final doc = _db.collection('missions').doc();
    final allMembers = [uid, ...memberIds];
    final mission = Mission(
      id: doc.id,
      title: title,
      type: type,
      ownerId: uid,
      memberIds: allMembers,
      createdAt: DateTime.now(),
    );
    await doc.set(mission.toMap());
  }

  Future<void> addTask(String missionId, String title, String userName, {DateTime? dueDate}) async {
    final doc = _db.collection('mission_tasks').doc();
    final task = MissionTask(
      id: doc.id,
      missionId: missionId,
      title: title,
      addedByName: userName,
      addedByUid: _uid,
      dueDate: dueDate,
      isCompleted: false,
    );
    await doc.set(task.toMap());
  }

  Future<void> toggleTaskStatus(String taskId, bool isCompleted, String userName) async {
    await _db.collection('mission_tasks').doc(taskId).update({
      'isCompleted': isCompleted,
      'completedByName': isCompleted ? userName : null,
    });
  }

  Future<void> completeMission(String missionId) async {
    await _db.collection('missions').doc(missionId).update({
      'isCompleted': true,
      'completedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteMission(String missionId) async {
    // Delete mission and its tasks
    await _db.collection('missions').doc(missionId).delete();
    final tasks = await _db.collection('mission_tasks').where('missionId', isEqualTo: missionId).get();
    for (var doc in tasks.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> deleteTask(String taskId) async {
    await _db.collection('mission_tasks').doc(taskId).delete();
  }

  Stream<List<UserModel>> getFriends() {
    final uid = _uid;
    if (uid.isEmpty) return Stream.value([]);
    
    // We fetch connections where user is sender OR receiver separately
    // to satisfy strict document-level security rules.
    final senderQuery = _db
        .collection('connections')
        .where('senderId', isEqualTo: uid)
        .where('status', isEqualTo: ConnectionStatus.accepted.index)
        .snapshots();

    final receiverQuery = _db
        .collection('connections')
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: ConnectionStatus.accepted.index)
        .snapshots();

    return CombineLatestStream.list([senderQuery, receiverQuery]).asyncMap((snaps) async {
      final ids = <String>{};
      for (var snap in snaps) {
        for (var d in snap.docs) {
          final data = d.data();
          if (data['senderId'] == uid) ids.add(data['receiverId']);
          if (data['receiverId'] == uid) ids.add(data['senderId']);
        }
      }
      
      final friendIds = ids.toList();
      if (friendIds.isEmpty) return [];
      
      // Batch fetch actual UserModels
      final userSnaps = await _db.collection('users').where('uid', whereIn: friendIds).get();
      return userSnaps.docs.map((d) => UserModel.fromMap(d.data())).toList();
    });
  }

  Future<void> addMember(String missionId, String memberUid) async {
    await _db.collection('missions').doc(missionId).update({
      'memberIds': FieldValue.arrayUnion([memberUid]),
    });
  }

  Future<void> assignTask(String taskId, String memberUid, String memberName) async {
    await _db.collection('mission_tasks').doc(taskId).update({
      'assignedToUid': memberUid,
      'assignedToName': memberName,
    });
  }

  Future<void> submitForApproval(String taskId, String userName) async {
    await _db.collection('mission_tasks').doc(taskId).update({
      'isCompleted': true,
      'completedByName': userName,
      'needsApproval': true,
    });
  }

  Future<void> approveTask(String taskId) async {
    await _db.collection('mission_tasks').doc(taskId).update({
      'needsApproval': false,
      'isApproved': true,
    });
  }

  Future<void> attachResource(String taskId, String url, String name, String type) async {
    await _db.collection('mission_tasks').doc(taskId).update({
      'resources': FieldValue.arrayUnion([
        {'url': url, 'name': name, 'type': type}
      ]),
    });
  }

  Future<void> toggleBigThree(String missionId, bool isBigThree) async {
    await _db.collection('missions').doc(missionId).update({
      'isBigThree': isBigThree,
      'bigThreeDate': isBigThree ? DateTime.now().toIso8601String() : null,
    });
  }

  Future<void> updateTaskSchedule(String taskId, DateTime? start, DateTime? end) async {
    await _db.collection('mission_tasks').doc(taskId).update({
      'startTime': start?.toIso8601String(),
      'endTime': end?.toIso8601String(),
    });
  }

  Stream<List<MissionTask>> getScheduledTasksForDay(DateTime date) {
    final uid = _uid;
    if (uid.isEmpty) return Stream.value([]);
    
    return _db
        .collection('mission_tasks')
        .snapshots()
        .map((snap) {
          final allTasks = snap.docs.map((doc) => MissionTask.fromMap(doc.data())).toList();
          return allTasks.where((t) {
            // Include if added by user OR assigned to user
            if (t.addedByUid != uid && t.assignedToUid != uid) return false;
            if (t.startTime == null) return false;
            return t.startTime!.year == date.year && 
                   t.startTime!.month == date.month && 
                   t.startTime!.day == date.day;
          }).toList()..sort((a, b) => a.startTime!.compareTo(b.startTime!));
        });
  }

  Future<void> startTaskTimer(String taskId) async {
    await _db.collection('mission_tasks').doc(taskId).update({
      'isTimerRunning': true,
      'lastStartTime': DateTime.now().toIso8601String(),
    });
  }

  Future<void> stopTaskTimer(String taskId, int currentTotalSeconds) async {
    final doc = await _db.collection('mission_tasks').doc(taskId).get();
    final task = MissionTask.fromMap(doc.data()!);
    if (task.lastStartTime == null) return;

    final elapsed = DateTime.now().difference(task.lastStartTime!).inSeconds;
    await _db.collection('mission_tasks').doc(taskId).update({
      'isTimerRunning': false,
      'lastStartTime': null,
      'totalTimeSeconds': currentTotalSeconds + elapsed,
    });
  }

  // Load Balancing: Fetch all active tasks assigned to anyone in missions I lead
  Stream<Map<String, int>> getTeamWorkload() {
    final uid = _uid;
    if (uid.isEmpty) return Stream.value({});
    
    return _db.collection('mission_tasks')
        .where('isCompleted', isEqualTo: false)
        .snapshots()
        .map((snap) {
          final map = <String, int>{};
          for (var doc in snap.docs) {
            final t = MissionTask.fromMap(doc.data());
            if (t.assignedToName != null) {
              map[t.assignedToName!] = (map[t.assignedToName!] ?? 0) + 1;
            }
          }
          return map;
        });
  }

  // Legacy Feature: All completed missions for the team
  Stream<List<Mission>> getLegacyMissions() {
    final uid = _uid;
    if (uid.isEmpty) return Stream.value([]);
    return _db
        .collection('missions')
        .where('memberIds', arrayContains: uid)
        .where('isCompleted', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Mission.fromMap(doc.data())).toList());
  }

  Future<String> ensureProjectChat(Mission mission) async {
    // Validate that the existing chat ID still points to a real 'groups' doc.
    // Old missions had projectChatId pointing to 'chats' collection — those
    // will fail the exists() check and need to be recreated properly.
    if (mission.projectChatId != null) {
      final existsInGroups = await _db
          .collection('groups')
          .doc(mission.projectChatId!)
          .get();
      if (existsInGroups.exists) return mission.projectChatId!;
      // Falls through to recreate — old 'chats'-based ID is invalid.
    }

    // War Room MUST live in 'groups' so the group_messages Firestore rule
    // (which does get(/groups/{groupId}).data.members) passes correctly.
    final doc = _db.collection('groups').doc();
    await doc.set({
      'groupId': doc.id,
      'name': 'WAR ROOM: ${mission.title}',
      'members': mission.memberIds,
      'createdBy': _uid,
      'lastMessage': 'War Room created',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'missionId': mission.id,
      'isWarRoom': true,
    });

    await _db.collection('missions').doc(mission.id).update({
      'projectChatId': doc.id,
    });

    return doc.id;
  }
}

