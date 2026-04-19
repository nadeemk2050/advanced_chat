import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/group_service.dart';
import '../theme/app_theme.dart';
import 'chat_detail_screen.dart';

class GroupDetailsScreen extends StatelessWidget {
  final GroupModel group;
  final List<UserModel>? members;
  const GroupDetailsScreen({super.key, required this.group, this.members});

  @override
  Widget build(BuildContext context) {
    final groupService = GroupService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Info'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Group Hero Section
            Center(
              child: Column(
                children: [
                  Hero(
                    tag: 'group-icon-${group.groupId}',
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: ChatTheme.primary.withOpacity(0.2),
                      backgroundImage: (group.groupPhotoUrl != null && group.groupPhotoUrl!.isNotEmpty)
                          ? NetworkImage(group.groupPhotoUrl!)
                          : null,
                      child: (group.groupPhotoUrl == null || group.groupPhotoUrl!.isEmpty)
                          ? Text(
                              (group.name.isNotEmpty ? group.name[0] : '?').toUpperCase(),
                              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: ChatTheme.primary),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    group.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: ChatTheme.textPrimary,
                    ),
                  ),
                  Text(
                    '${group.members.length} Members',
                    style: const TextStyle(color: ChatTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Members',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ChatTheme.primary,
                  ),
                ),
              ),
            ),
            // Members List
            if (members != null && members!.isNotEmpty)
              _buildMembersList(context, members!)
            else
              FutureBuilder<List<UserModel>>(
                future: groupService.getGroupMembers(group.members),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('No members found.');
                  }

                  return _buildMembersList(context, snapshot.data!);
                },
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersList(BuildContext context, List<UserModel> memberList) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: memberList.length,
      itemBuilder: (context, index) {
        final member = memberList[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: ChatTheme.primary.withOpacity(0.1),
              backgroundImage: (member.photoUrl != null && member.photoUrl!.isNotEmpty)
                  ? NetworkImage(member.photoUrl!)
                  : null,
              child: (member.photoUrl == null || member.photoUrl!.isEmpty)
                  ? Text((member.name.isNotEmpty ? member.name[0] : '?').toUpperCase(), style: const TextStyle(color: ChatTheme.primary))
                  : null,
            ),
            title: Text(
              member.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(member.email),
            trailing: IconButton(
              icon: const Icon(Icons.message_outlined, color: ChatTheme.primary),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatDetailScreen(otherUser: member),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
