import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/group_service.dart';
import '../theme/app_theme.dart';

class ForwardPickerScreen extends StatefulWidget {
  final MessageModel message;
  const ForwardPickerScreen({super.key, required this.message});

  @override
  State<ForwardPickerScreen> createState() => _ForwardPickerScreenState();
}

class _ForwardPickerScreenState extends State<ForwardPickerScreen> {
  final Set<String> _selectedRecipients = {}; // uids or groupIds
  final String _currentUid = FirebaseAuth.instance.currentUser!.uid;

  void _forward() {
    if (_selectedRecipients.isEmpty) return;
    
    final chatService = ChatService();
    // Forward to each selected
    for (var id in _selectedRecipients) {
      // Determine if it's a group or user
      // Normally we'd check if 'id' starts with a group prefix or check metadata.
      // For this app, let's assume we know if it was picked from groups list.
      // But a simpler way: try both or check a mapping.
      // Let's just call ChatService.forwardMessage(message, id)
      chatService.sendMessage(
        widget.message.text, 
        id, 
        type: widget.message.type, 
        mediaUrl: widget.message.mediaUrl,
        fileName: widget.message.fileName
      );
    }
    
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Forwarded to ${_selectedRecipients.length} recipients'))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forward to...'),
        actions: [
          if (_selectedRecipients.isNotEmpty)
            TextButton(
              onPressed: _forward,
              child: const Text('FORWARD', style: TextStyle(color: ChatTheme.primary, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Selected: ${_selectedRecipients.length} / 7',
              style: TextStyle(color: _selectedRecipients.length > 7 ? Colors.red : ChatTheme.primary),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, userSnap) {
                if (userSnap.hasError) return Center(child: Text('User Error: ${userSnap.error}', style: const TextStyle(color: Colors.red)));
                return StreamBuilder<QuerySnapshot>(
                  stream: GroupService().getGroups(),
                  builder: (context, groupSnap) {
                    if (groupSnap.hasError) return Center(child: Text('Group Error: ${groupSnap.error}', style: const TextStyle(color: Colors.red)));
                    if (!userSnap.hasData || !groupSnap.hasData) return const Center(child: CircularProgressIndicator());
                    
                    final users = userSnap.data!.docs
                        .map((d) => UserModel.fromMap(d.data() as Map<String, dynamic>))
                        .where((u) => u.uid != _currentUid && u.name.trim().isNotEmpty)
                        .toList();
                    final groups = groupSnap.data!.docs
                        .map((d) => GroupModel.fromMap(d.data() as Map<String, dynamic>))
                        .toList();

                    if (users.isEmpty && groups.isEmpty) {
                      return const Center(child: Text('No users or groups found.'));
                    }

                    return ListView(
                      children: [
                        if (groups.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Groups', style: TextStyle(fontWeight: FontWeight.bold, color: ChatTheme.textSecondary)),
                          ),
                          ...groups.map((g) => _buildSelectionTile(g.groupId, g.name, true)),
                        ],
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Contacts', style: TextStyle(fontWeight: FontWeight.bold, color: ChatTheme.textSecondary)),
                        ),
                        ...users.map((u) => _buildSelectionTile(u.uid, u.name, false)),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionTile(String id, String name, bool isGroup) {
    bool isSelected = _selectedRecipients.contains(id);
    return ListTile(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedRecipients.remove(id);
          } else {
            if (_selectedRecipients.length < 7) {
              _selectedRecipients.add(id);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 7 selection allowed')));
            }
          }
        });
      },
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: isGroup ? Colors.blueGrey : ChatTheme.primary.withOpacity(0.1),
        child: Text((name.isNotEmpty ? name[0] : '?').toUpperCase(), style: const TextStyle(fontSize: 14)),
      ),
      title: Text(name, style: const TextStyle(fontSize: 14)),
      trailing: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected ? ChatTheme.primary : Colors.white24,
      ),
    );
  }
}
