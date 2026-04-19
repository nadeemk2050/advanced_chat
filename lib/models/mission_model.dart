import 'package:cloud_firestore/cloud_firestore.dart';

enum MissionType {
  personalTask,
  personalMission,
  teamTask,
  teamMission,
}

class Mission {
  final String id;
  final String title;
  final MissionType type;
  final String ownerId;
  final List<String> memberIds;
  final DateTime createdAt;
  final int colorValue;
  final String? projectChatId;
  final bool isCompleted;
  final DateTime? completedAt;
  final bool isBigThree;
  final DateTime? bigThreeDate;

  Mission({
    required this.id,
    required this.title,
    required this.type,
    required this.ownerId,
    this.memberIds = const [],
    required this.createdAt,
    this.colorValue = 0xFFFFFFFF,
    this.projectChatId,
    this.isCompleted = false,
    this.completedAt,
    this.isBigThree = false,
    this.bigThreeDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type.index,
      'ownerId': ownerId,
      'memberIds': memberIds,
      'createdAt': createdAt.toIso8601String(),
      'colorValue': colorValue,
      'projectChatId': projectChatId,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'isBigThree': isBigThree,
      'bigThreeDate': bigThreeDate?.toIso8601String(),
    };
  }

  factory Mission.fromMap(Map<String, dynamic> map) {
    return Mission(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      type: MissionType.values[map['type'] ?? 0],
      ownerId: map['ownerId'] ?? '',
      memberIds: List<String>.from(map['memberIds'] ?? []),
      createdAt: DateTime.parse(map['createdAt']),
      colorValue: map['colorValue'] ?? 0xFFFFFFFF,
      projectChatId: map['projectChatId'],
      isCompleted: map['isCompleted'] ?? false,
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'])
          : null,
      isBigThree: map['isBigThree'] ?? false,
      bigThreeDate: map['bigThreeDate'] != null
          ? DateTime.tryParse(map['bigThreeDate'])
          : null,
    );
  }
}

class MissionTask {
  final String id;
  final String missionId;
  final String title;
  final bool isCompleted;
  final String? completedByName;
  final String addedByName;
  final String addedByUid;
  final String? assignedToUid;
  final String? assignedToName;
  final bool isApproved;
  final bool needsApproval;
  final List<Map<String, String>> resources;
  final DateTime? dueDate;
  final bool hasAlarm;
  final DateTime? alarmTime;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isTimerRunning;
  final DateTime? lastStartTime;
  final int totalTimeSeconds;

  MissionTask({
    required this.id,
    required this.missionId,
    required this.title,
    this.isCompleted = false,
    this.completedByName,
    required this.addedByName,
    required this.addedByUid,
    this.assignedToUid,
    this.assignedToName,
    this.isApproved = false,
    this.needsApproval = false,
    this.resources = const [],
    this.dueDate,
    this.hasAlarm = false,
    this.alarmTime,
    this.startTime,
    this.endTime,
    this.isTimerRunning = false,
    this.lastStartTime,
    this.totalTimeSeconds = 0,
  });

  Duration get totalDuration {
    Duration duration = Duration(seconds: totalTimeSeconds);
    if (isTimerRunning && lastStartTime != null) {
      duration += DateTime.now().difference(lastStartTime!);
    }
    return duration;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'missionId': missionId,
      'title': title,
      'isCompleted': isCompleted,
      'completedByName': completedByName,
      'addedByName': addedByName,
      'addedByUid': addedByUid,
      'assignedToUid': assignedToUid,
      'assignedToName': assignedToName,
      'isApproved': isApproved,
      'needsApproval': needsApproval,
      'resources': resources,
      'dueDate': dueDate?.toIso8601String(),
      'hasAlarm': hasAlarm,
      'alarmTime': alarmTime?.toIso8601String(),
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'isTimerRunning': isTimerRunning,
      'lastStartTime': lastStartTime?.toIso8601String(),
      'totalTimeSeconds': totalTimeSeconds,
    };
  }

  factory MissionTask.fromMap(Map<String, dynamic> map) {
    return MissionTask(
      id: map['id'] ?? '',
      missionId: map['missionId'] ?? '',
      title: map['title'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      completedByName: map['completedByName'],
      addedByName: map['addedByName'] ?? '',
      addedByUid: map['addedByUid'] ?? '',
      assignedToUid: map['assignedToUid'],
      assignedToName: map['assignedToName'],
      isApproved: map['isApproved'] ?? false,
      needsApproval: map['needsApproval'] ?? false,
      resources: List<Map<String, String>>.from((map['resources'] ?? []).map((e) => Map<String, String>.from(e))),
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      hasAlarm: map['hasAlarm'] ?? false,
      alarmTime: map['alarmTime'] != null ? DateTime.parse(map['alarmTime']) : null,
      startTime: map['startTime'] != null ? DateTime.parse(map['startTime']) : null,
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
      isTimerRunning: map['isTimerRunning'] ?? false,
      lastStartTime: map['lastStartTime'] != null ? DateTime.parse(map['lastStartTime']) : null,
      totalTimeSeconds: map['totalTimeSeconds'] ?? 0,
    );
  }
}
