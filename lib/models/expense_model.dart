import 'package:cloud_firestore/cloud_firestore.dart';

enum ExpenseCategory { travel, pettyCash, project, other }
enum EntryType { payment, receipt }

class ExpenseProject {
  final String id;
  final String title;
  final String ownerId;
  final List<String> memberIds;
  final DateTime createdAt;
  final double budget;

  ExpenseProject({
    required this.id,
    required this.title,
    required this.ownerId,
    required this.memberIds,
    required this.createdAt,
    this.budget = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'ownerId': ownerId,
      'memberIds': memberIds,
      'createdAt': createdAt.toIso8601String(),
      'budget': budget,
    };
  }

  factory ExpenseProject.fromMap(Map<String, dynamic> map) {
    return ExpenseProject(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      ownerId: map['ownerId'] ?? '',
      memberIds: List<String>.from(map['memberIds'] ?? []),
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      budget: (map['budget'] ?? 0.0).toDouble(),
    );
  }
}

class Settlement {
  final String fromUser;
  final String toUser;
  final double amount;

  Settlement({required this.fromUser, required this.toUser, required this.amount});
}

class ExpenseEntry {
  final String id;
  final String projectId;
  final String title;
  final double amount;
  final ExpenseCategory category;
  final EntryType type;
  final DateTime date;
  final String addedBy;
  final String addedByName;
  final String? note;
  final String? attachmentUrl;

  ExpenseEntry({
    required this.id,
    required this.projectId,
    required this.title,
    required this.amount,
    required this.category,
    required this.type,
    required this.date,
    required this.addedBy,
    required this.addedByName,
    this.note,
    this.attachmentUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'title': title,
      'amount': amount,
      'category': category.name,
      'type': type.name,
      'date': date.toIso8601String(),
      'addedBy': addedBy,
      'addedByName': addedByName,
      'note': note,
      'attachmentUrl': attachmentUrl,
    };
  }

  factory ExpenseEntry.fromMap(Map<String, dynamic> map) {
    return ExpenseEntry(
      id: map['id'] ?? '',
      projectId: map['projectId'] ?? '',
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      category: ExpenseCategory.values.firstWhere((e) => e.name == map['category'], orElse: () => ExpenseCategory.other),
      type: EntryType.values.firstWhere((e) => e.name == map['type'], orElse: () => EntryType.payment),
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      addedBy: map['addedBy'] ?? '',
      addedByName: map['addedByName'] ?? 'User',
      note: map['note'],
      attachmentUrl: map['attachmentUrl'],
    );
  }
}
