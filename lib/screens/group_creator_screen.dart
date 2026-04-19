import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/chat_models.dart';
import '../services/group_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'group_chat_screen.dart';

class GroupCreatorScreen extends StatefulWidget {
  const GroupCreatorScreen({super.key});

  @override
  State<GroupCreatorScreen> createState() => _GroupCreatorScreenState();
}

class _GroupCreatorScreenState extends State<GroupCreatorScreen> {
  final _groupService = GroupService();
  final _storageService = MediaStorageService();
  final _nameController = TextEditingController();
  final String _currentUid = FirebaseAuth.instance.currentUser!.uid;
  final Set<String> _selectedUids = {};
  bool _isCreating = false;
  String? _groupPhotoUrl;
  bool _isUploadingPhoto = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createGroup(List<UserModel> allUsers) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name.')),
      );
      return;
    }
    if (_selectedUids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member.')),
      );
      return;
    }

    setState(() => _isCreating = true);
    final groupId = await _groupService.createGroup(
      name,
      _selectedUids.toList(),
      groupPhotoUrl: _groupPhotoUrl,
    );
    setState(() => _isCreating = false);

    if (groupId != null && mounted) {
      final group = GroupModel(
        groupId: groupId,
        name: name,
        members: [_currentUid, ..._selectedUids],
        lastMessage: 'Group created 🚀',
        lastMessageAt: DateTime.now(),
        createdBy: _currentUid,
        groupPhotoUrl: _groupPhotoUrl,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create group. Try again.')),
      );
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      String? url;
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        url = await _storageService.uploadImageHtmlWithProgress(bytes, onProgress: (_) {});
      } else {
        url = await _storageService.uploadImage(File(image.path));
      }
      if (url != null) {
        setState(() => _groupPhotoUrl = url);
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Group'),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snap) {
              final users = snap.hasData
                  ? snap.data!.docs
                      .map((d) => UserModel.fromMap(d.data() as Map<String, dynamic>))
                      .where((u) => 
                        u.uid != _currentUid && 
                        u.name.trim().isNotEmpty && 
                        !u.blockedUsers.contains(_currentUid) // Add this check
                      )
                      .toList()
                  : <UserModel>[];
              return TextButton(
                onPressed: _isCreating ? null : () => _createGroup(users),
                child: _isCreating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create', style: TextStyle(color: ChatTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
          // ─── Group Photo & Name Input ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _isUploadingPhoto ? null : _pickPhoto,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: ChatTheme.surface,
                        backgroundImage: (_groupPhotoUrl != null)
                            ? NetworkImage(_groupPhotoUrl!)
                            : null,
                        child: (_groupPhotoUrl == null)
                            ? const Icon(Icons.camera_alt_rounded, color: ChatTheme.primary, size: 24)
                            : null,
                      ),
                      if (_isUploadingPhoto)
                        const Positioned.fill(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Group name...',
                      border: UnderlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),
          ),
          // ─── Selected members chip row ───
          if (_selectedUids.isNotEmpty)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox.shrink();
                final users = snap.data!.docs
                    .map((d) => UserModel.fromMap(d.data() as Map<String, dynamic>))
                    .where((u) => _selectedUids.contains(u.uid))
                    .toList();
                return SizedBox(
                  height: 64,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: users
                        .map(
                          (u) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Chip(
                              label: Text(u.name),
                              avatar: CircleAvatar(
                                backgroundColor: ChatTheme.accent,
                                backgroundImage: (u.photoUrl != null && u.photoUrl!.isNotEmpty)
                                    ? NetworkImage(u.photoUrl!)
                                    : null,
                                child: (u.photoUrl == null || u.photoUrl!.isEmpty)
                                    ? Text((u.name.isNotEmpty ? u.name[0] : '?').toUpperCase())
                                    : null,
                              ),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () => setState(() => _selectedUids.remove(u.uid)),
                              backgroundColor: ChatTheme.surface,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                );
              },
            ),
          const Divider(height: 1, color: Colors.white12),
          // ─── Contact List ───
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final users = snap.data!.docs
                    .map((d) => UserModel.fromMap(d.data() as Map<String, dynamic>))
                    .where((u) => 
                      u.uid != _currentUid && 
                      u.name.trim().isNotEmpty && 
                      !u.blockedUsers.contains(_currentUid) // Filter out blockers
                    )
                    .toList()
                  ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isSelected = _selectedUids.contains(user.uid);
                    return ListTile(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedUids.remove(user.uid);
                          } else {
                            _selectedUids.add(user.uid);
                          }
                        });
                      },
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: ChatTheme.accent,
                        backgroundImage: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                            ? NetworkImage(user.photoUrl!)
                            : null,
                        child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                            ? Text((user.name.isNotEmpty ? user.name[0] : '?').toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold))
                            : null,
                      ),
                      title: Text(user.name),
                      subtitle: Text(
                        user.isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          color: user.isOnline ? Colors.greenAccent : ChatTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      trailing: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: isSelected ? ChatTheme.primary : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? ChatTheme.primary : Colors.white38,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded, color: Colors.black, size: 16)
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
    );
  }
}
