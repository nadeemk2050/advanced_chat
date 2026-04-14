import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_models.dart';

class GroupService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> createGroup(String groupName, List<String> memberUids) async {
    try {
      final String groupId = DateTime.now().millisecondsSinceEpoch.toString();
      final List<String> allMembers = [_auth.currentUser!.uid, ...memberUids];

      await _firestore.collection('groups').doc(groupId).set({
        'id': groupId,
        'name': groupName,
        'members': allMembers,
        'lastMessage': 'Group formed 🚀',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isGroup': true,
      });
    } catch (e) {
      print('Group Creation Error: $e');
    }
  }

  Stream<QuerySnapshot> getGroups() {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: _auth.currentUser!.uid)
        .snapshots();
  }
}
