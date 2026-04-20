import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import '../services/group_service.dart';
import '../services/update_service.dart';
import '../models/chat_models.dart';
import '../theme/app_theme.dart';

class RequestsCenterScreen extends StatefulWidget {
  const RequestsCenterScreen({super.key});

  @override
  State<RequestsCenterScreen> createState() => _RequestsCenterScreenState();
}

class _RequestsCenterScreenState extends State<RequestsCenterScreen> {
  final _chatService = ChatService();
  final _groupService = GroupService();
  final _updateService = UpdateService();
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatTheme.background,
      appBar: AppBar(
        title: const Text('NOTIFICATIONS & REQUESTS'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('SYSTEM UPDATES', Icons.system_update_rounded),
            _buildAppUpdateItem(),
            
            _buildSectionHeader('FRIEND REQUESTS', Icons.person_add_rounded),
            _buildFriendRequestsList(),
            
            _buildSectionHeader('GROUP INVITATIONS', Icons.group_add_rounded),
            _buildGroupInvitesList(),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: ChatTheme.primary, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: ChatTheme.primary,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const Expanded(child: Divider(indent: 12, color: Colors.white12)),
        ],
      ),
    );
  }

  Widget _buildAppUpdateItem() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('app_config').doc('version_info').get(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();
        final data = snap.data!.data() as Map<String, dynamic>;
        final latestVersion = data['latest_version'] ?? '1.0.0';
        if (latestVersion == _updateService.currentVersion) return _buildEmptyItem('Your app is up to date.');

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orangeAccent),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New Update: v$latestVersion', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const Text('Performance improvements & new features!', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _updateService.checkForUpdates(context),
                child: const Text('UPDATE', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFriendRequestsList() {
    return StreamBuilder<List<ConnectionModel>>(
      stream: _chatService.getIncomingFriendRequests(),
      builder: (context, snap) {
        final requests = snap.data ?? [];
        if (requests.isEmpty) return _buildEmptyItem('No pending friend requests.');

        return Column(
          children: requests.map((req) => _buildFriendRequestCard(req)).toList(),
        );
      },
    );
  }

  Widget _buildFriendRequestCard(ConnectionModel req) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(req.senderId).get(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final user = snap.data!.data() as Map<String, dynamic>?;
        if (user == null) return const SizedBox.shrink();

        final name = user['name'] ?? 'Unknown';
        final photoUrl = user['photoUrl'] ?? '';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ChatTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
                onPressed: () => _chatService.acceptFriendRequest(req.senderId),
              ),
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.redAccent),
                onPressed: () => _chatService.unfriend(req.senderId),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupInvitesList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _groupService.getIncomingInvites(),
      builder: (context, snap) {
        final invites = snap.data ?? [];
        if (invites.isEmpty) return _buildEmptyItem('No group invitations.');

        return Column(
          children: invites.map((inv) => _buildGroupInviteCard(inv)).toList(),
        );
      },
    );
  }

  Widget _buildGroupInviteCard(Map<String, dynamic> inv) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ChatTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: ChatTheme.primary,
            child: Icon(Icons.groups_rounded, color: Colors.black),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(inv['groupName'] ?? 'Unnamed Group', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                const Text('Wants you to join', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _groupService.respondToInvite(inv['inviteId'], inv['groupId'], true),
            child: const Text('JOIN', style: TextStyle(color: ChatTheme.primary, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54),
            onPressed: () => _groupService.respondToInvite(inv['inviteId'], inv['groupId'], false),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyItem(String text) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(color: Colors.white24, fontSize: 13, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}
