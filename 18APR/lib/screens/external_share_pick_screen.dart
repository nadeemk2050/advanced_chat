import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/group_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class ExternalSharePickScreen extends StatefulWidget {
  final List<String>? sharedFiles; // Paths
  final String? sharedText;

  const ExternalSharePickScreen({super.key, this.sharedFiles, this.sharedText});

  @override
  State<ExternalSharePickScreen> createState() => _ExternalSharePickScreenState();
}

class _ExternalSharePickScreenState extends State<ExternalSharePickScreen> {
  final Set<String> _selectedRecipients = {};
  final String _currentUid = FirebaseAuth.instance.currentUser!.uid;
  bool _isSending = false;
  double _uploadProgress = 0.0;

  Future<void> _processAndSend() async {
    if (_selectedRecipients.isEmpty) return;
    setState(() => _isSending = true);

    final chatService = ChatService();
    final groupService = GroupService();
    final storageService = MediaStorageService();

    try {
      // 1. Handle Text
      if (widget.sharedText != null && widget.sharedText!.isNotEmpty) {
        for (var id in _selectedRecipients) {
          // Check if id is group or user (simplistic check for this app)
          // In this app, groups and users are in different collections, 
          // but we can try to send as user first, then group if failed or check metadata.
          // For now, let's assume we know if it's a group (e.g. by prefix or searching)
          // Re-using the strategy from forward picker.
          if (id.length > 20) { // Typical UID/DocID length
             // Determine if it's user or group by checking selected list metadata (if we had any)
             // Simple fallback: send to all. In this app, sendGroupMessage and sendMessage are distinct.
          }
           // We'll need to know which is which. Let's pass that info from the UI.
        }
      }

      // Instead of generic logic, I'll iterate and upload files for each if multiple.
      // But uploading once and sharing the URL is better.
      List<String> uploadedUrls = [];
      List<String> fileNames = [];
      
      if (widget.sharedFiles != null) {
        for (var filePath in widget.sharedFiles!) {
          File file = File(filePath);
          String name = filePath.split('/').last;
          String? url = await storageService.uploadFile(file, name);
          if (url != null) {
            uploadedUrls.add(url);
            fileNames.add(name);
          }
        }
      }

      for (var id in _selectedRecipients) {
        // Find if it's a group or user
        bool isGroup = _groupsMetadata.any((g) => g.groupId == id);

        if (widget.sharedText != null) {
          if (isGroup) {
            await groupService.sendGroupMessage(id, widget.sharedText!);
          } else {
            await chatService.sendMessage(widget.sharedText!, id);
          }
        }

        for (int i = 0; i < uploadedUrls.length; i++) {
          final url = uploadedUrls[i];
          final name = fileNames[i];
          final type = _getMessageType(name);
          
          if (isGroup) {
            await groupService.sendGroupMessage(id, name, type: type, mediaUrl: url, fileName: name);
          } else {
            await chatService.sendMessage(name, id, type: type, mediaUrl: url, fileName: name);
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully shared!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sharing: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  MessageType _getMessageType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return MessageType.image;
    if (['mp3', 'm4a', 'wav', 'aac'].contains(ext)) return MessageType.audio;
    return MessageType.document;
  }

  List<GroupModel> _groupsMetadata = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share to...'),
        actions: [
          if (_selectedRecipients.isNotEmpty)
            TextButton(
              onPressed: _isSending ? null : _processAndSend,
              child: const Text('SEND', style: TextStyle(color: ChatTheme.primary, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Selected: ${_selectedRecipients.length} recipients',
                  style: const TextStyle(color: ChatTheme.primary),
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
                        
                        _groupsMetadata = groups;

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
          if (_isSending)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
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
            _selectedRecipients.add(id);
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
