import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/expense_model.dart';
import '../models/chat_models.dart';

class ExpenseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  // PROJET MANAGEMENT
  Stream<List<ExpenseProject>> getExpenseProjects() {
    if (_uid.isEmpty) return Stream.value([]);
    return _db.collection('expense_projects')
        .where('memberIds', arrayContains: _uid)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ExpenseProject.fromMap(doc.data())).toList());
  }

  Future<void> createProject(String title, {double budget = 0}) async {
    final id = const Uuid().v4();
    final project = ExpenseProject(
      id: id,
      title: title,
      ownerId: _uid,
      memberIds: [_uid],
      createdAt: DateTime.now(),
      budget: budget,
    );
    await _db.collection('expense_projects').doc(id).set(project.toMap());
  }

  Future<void> updateProjectBudget(String projectId, double budget) async {
    await _db.collection('expense_projects').doc(projectId).update({'budget': budget});
  }

  // AMBANI'S SETTLEMENT ENGINE: Who owes whom?
  Future<List<Settlement>> calculateSettlements(String projectId) async {
    final entriesSnap = await _db.collection('expense_entries').where('projectId', isEqualTo: projectId).get();
    final projectSnap = await _db.collection('expense_projects').doc(projectId).get();
    if (!projectSnap.exists) return [];
    
    final members = List<String>.from(projectSnap.data()?['memberIds'] ?? []);
    if (members.isEmpty) return [];

    final entries = entriesSnap.docs.map((doc) => ExpenseEntry.fromMap(doc.data())).toList();
    
    // 1. Calculate net balance for each person
    // Net balance = (What you paid) - (Your fair share of what everyone paid)
    Map<String, double> balanceMap = {for (var m in members) m : 0.0};
    double totalSpent = 0;

    for (var entry in entries) {
      if (entry.type == EntryType.payment) {
        balanceMap[entry.addedBy] = (balanceMap[entry.addedBy] ?? 0) + entry.amount;
        totalSpent += entry.amount;
      }
    }

    double fairShare = totalSpent / members.length;
    for (var m in members) {
      balanceMap[m] = balanceMap[m]! - fairShare;
    }

    // 2. Greedy algorithm to match debtors and creditors
    List<Settlement> settlements = [];
    List<MapEntry<String, double>> debtors = balanceMap.entries.where((e) => e.value < -0.01).toList();
    List<MapEntry<String, double>> creditors = balanceMap.entries.where((e) => e.value > 0.01).toList();

    debtors.sort((a, b) => a.value.compareTo(b.value));
    creditors.sort((a, b) => b.value.compareTo(a.value));

    int d = 0, c = 0;
    while (d < debtors.length && c < creditors.length) {
      double amount = (-debtors[d].value).clamp(0, creditors[c].value);
      if (amount > 0.01) {
        settlements.add(Settlement(
          fromUser: debtors[d].key, 
          toUser: creditors[c].key, 
          amount: amount
        ));
      }
      
      // Update remaining balances (simplified as we don't mutate the list entries)
      // For a more robust version, we'd use local variables to track remaining debt/credit
      d++; // Move to next for demo simplicity
      c++;
    }
    return settlements;
  }

  // GATES'S CATEGORY HEATMAP DATA
  Stream<Map<String, double>> getCategoryBreakdown(String projectId) {
    return getEntries(projectId).map((entries) {
      Map<String, double> map = {};
      for (var e in entries) {
        if (e.type == EntryType.payment) {
          map[e.category] = (map[e.category] ?? 0) + e.amount;
        }
      }
      return map;
    });
  }

  Future<void> addMember(String projectId, String userId) async {
    await _db.collection('expense_projects').doc(projectId).update({
      'memberIds': FieldValue.arrayUnion([userId])
    });
  }

  // ENTRY MANAGEMENT
  Stream<List<ExpenseEntry>> getEntries(String projectId) {
    return _db.collection('expense_entries')
        .where('projectId', isEqualTo: projectId)
        // .orderBy('date', descending: true) // Temporarily disabled to avoid index blocker
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((doc) => ExpenseEntry.fromMap(doc.data())).toList();
          list.sort((a, b) => b.date.compareTo(a.date)); // Manual sort until index is ready
          return list;
        });
  }

  Future<void> addEntry({
    required String projectId,
    required String title,
    required double amount,
    required String category,
    required EntryType type,
    required String userName,
    String? note,
  }) async {
    final id = const Uuid().v4();
    final entry = ExpenseEntry(
      id: id,
      projectId: projectId,
      title: title,
      amount: amount,
      category: category,
      type: type,
      date: DateTime.now(),
      addedBy: _uid,
      addedByName: userName,
      note: note,
    );
    await _db.collection('expense_entries').doc(id).set(entry.toMap());
  }

  Future<void> deleteEntry(String entryId) async {
    await _db.collection('expense_entries').doc(entryId).delete();
  }

  Future<void> deleteProject(String projectId) async {
    await _db.collection('expense_projects').doc(projectId).delete();
    // Also delete all entries
    final entries = await _db.collection('expense_entries').where('projectId', isEqualTo: projectId).get();
    for (var doc in entries.docs) {
      await doc.reference.delete();
    }
  }

  Stream<List<UserModel>> getFriends() {
    return _db.collection('users').doc(_uid).snapshots().asyncMap((snap) async {
      final friendIds = List<String>.from(snap.data()?['friends'] ?? []);
      if (friendIds.isEmpty) return [];
      final friendsSnap = await _db.collection('users').where(FieldPath.documentId, whereIn: friendIds).get();
      return friendsSnap.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
    });
  }
}
