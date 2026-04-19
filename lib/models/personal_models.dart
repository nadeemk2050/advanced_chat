class PersonalTask {
  final String id;
  final String title;
  final String description;
  final DateTime dueDate;
  final bool isCompleted;
  final DateTime createdAt;
  final bool hasAlarm;
  final DateTime? alarmTime;
  final String? groupId; // For sub-tasks under a major task list

  PersonalTask({
    required this.id,
    required this.title,
    this.description = '',
    required this.dueDate,
    this.isCompleted = false,
    required this.createdAt,
    this.hasAlarm = false,
    this.alarmTime,
    this.groupId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDate.millisecondsSinceEpoch,
      'isCompleted': isCompleted ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'hasAlarm': hasAlarm ? 1 : 0,
      'alarmTime': alarmTime?.millisecondsSinceEpoch,
      'groupId': groupId,
    };
  }

  factory PersonalTask.fromMap(Map<String, dynamic> map) {
    return PersonalTask(
      id: map['id'],
      title: map['title'],
      description: map['description'] ?? '',
      dueDate: DateTime.fromMillisecondsSinceEpoch(map['dueDate']),
      isCompleted: (map['isCompleted'] ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      hasAlarm: (map['hasAlarm'] ?? 0) == 1,
      alarmTime: map['alarmTime'] != null ? DateTime.fromMillisecondsSinceEpoch(map['alarmTime']) : null,
      groupId: map['groupId'],
    );
  }
}

class TaskGroup {
  final String id;
  final String title;
  final DateTime createdAt;

  TaskGroup({required this.id, required this.title, required this.createdAt});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory TaskGroup.fromMap(Map<String, dynamic> map) {
    return TaskGroup(
      id: map['id'],
      title: map['title'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }
}
