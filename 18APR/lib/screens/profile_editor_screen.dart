import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/group_service.dart';
import 'requests_center_screen.dart';

class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({super.key});

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  final _authService = AuthService();
  final _storageService = MediaStorageService();
  final _nameController = TextEditingController();
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  Uint8List? _localPhotoBytes;

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    final bytes = await image.readAsBytes();
    setState(() {
      _localPhotoBytes = bytes;
      _isUploadingPhoto = true;
    });

    try {
      String? url;
      if (kIsWeb) {
        url = await _storageService.uploadImageHtmlWithProgress(bytes, onProgress: (_) {});
      } else {
        url = await _storageService.uploadImage(File(image.path));
      }
      if (url != null) {
        await _authService.updatePhotoUrl(url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated! ✨')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _saveName(String currentName) async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name == currentName) return;
    setState(() => _isSaving = true);
    final ok = await _authService.updateName(name);
    setState(() => _isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Name updated! ✨' : 'Failed to update name.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('EDIT PROFILE')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!.data() ?? {};
          final user = UserModel.fromMap(data);

          if (_nameController.text.isEmpty && user.name.isNotEmpty) {
            _nameController.text = user.name;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // ─── Profile Photo ───
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 80,
                      backgroundColor: ChatTheme.primary.withOpacity(0.1),
                      backgroundImage: _localPhotoBytes != null
                          ? MemoryImage(_localPhotoBytes!)
                          : (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                              ? NetworkImage(user.photoUrl!)
                              : null,
                      child: (_localPhotoBytes == null && (user.photoUrl == null || user.photoUrl!.isEmpty))
                          ? Text(
                              (user.name.isNotEmpty ? user.name[0] : '?').toUpperCase(),
                              style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: ChatTheme.primary),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 5,
                      right: 5,
                      child: GestureDetector(
                        onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ChatTheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: _isUploadingPhoto
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.camera_alt_rounded, size: 20, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),

                // ─── Username (Immutable) ───
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.01),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextFormField(
                    initialValue: user.name,
                    readOnly: true,
                    style: TextStyle(color: Colors.black.withOpacity(0.5)),
                    decoration: const InputDecoration(
                      labelText: 'Username (Solid)',
                      labelStyle: TextStyle(color: Colors.black54),
                      prefixIcon: Icon(Icons.person_outline_rounded, color: Colors.black26),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ─── Registered Email (Immutable) ───
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.01),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextFormField(
                    initialValue: user.email,
                    readOnly: true,
                    style: TextStyle(color: Colors.black.withOpacity(0.5)),
                    decoration: const InputDecoration(
                      labelText: 'Registered Email (Solid)',
                      labelStyle: TextStyle(color: Colors.black54),
                      prefixIcon: Icon(Icons.email_outlined, color: Colors.black26),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ─── Discovery Settings ───
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: ChatTheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ChatTheme.primary.withOpacity(0.1)),
                  ),
                  child: SwitchListTile(
                    title: const Text('Visible to Others in Members List', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('If off, you will only appear in your friends\' lists.', style: TextStyle(fontSize: 12)),
                    value: user.isVisibleInMembersList,
                    activeColor: ChatTheme.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => _authService.updateVisibility(val),
                  ),
                ),
                const SizedBox(height: 32),

                // ─── Notifications & Requests Portal ───
                _buildRequestsPortal(context),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestsPortal(BuildContext context) {
    final chatService = ChatService();
    final groupService = GroupService();

    return StreamBuilder<List<ConnectionModel>>(
      stream: chatService.getIncomingFriendRequests(),
      builder: (context, friendSnap) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: groupService.getIncomingInvites(),
          builder: (context, groupSnap) {
            final total = (friendSnap.data?.length ?? 0) + (groupSnap.data?.length ?? 0);

            return InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestsCenterScreen())),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [ChatTheme.primary.withOpacity(0.1), ChatTheme.accent.withOpacity(0.05)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ChatTheme.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        const Icon(Icons.notifications_active_outlined, color: ChatTheme.primary, size: 28),
                        if (total > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              child: Text(
                                '$total',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Notifications & Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Manage friend & group requests', style: TextStyle(color: Colors.black45, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.black26),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
