import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';
import '../services/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendProfileScreen extends StatelessWidget {
  final UserModel user;
  const FriendProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(user.name),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Profile Photo
            Center(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ChatTheme.primary, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: ChatTheme.primary.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 80,
                      backgroundColor: ChatTheme.surface,
                      backgroundImage: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                          ? NetworkImage(user.photoUrl!)
                          : null,
                      child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                          ? Text(
                              user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                              style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w900, color: ChatTheme.primary),
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: user.isOnline ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // User Info
            Text(
              user.name,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: ChatTheme.textPrimary,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user.email,
              style: const TextStyle(
                fontSize: 16,
                color: ChatTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            // Details List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _buildDetailItem(
                    Icons.history_rounded,
                    'Last Seen',
                    user.isOnline ? 'Online Now' : DateFormat('MMM d, hh:mm a').format(user.lastSeen),
                  ),
                  const Divider(height: 32, color: Colors.black12),
                  _buildDetailItem(
                    Icons.verified_user_outlined,
                    'About',
                    'Hey there! I am using Advanced Chat.',
                  ),
                  const SizedBox(height: 12),
                  // Block Button
                  StreamBuilder<bool>(
                    stream: ChatService().amIBlocking(user.uid),
                    builder: (context, snap) {
                      final isBlocked = snap.data ?? false;
                      return SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => ChatService().toggleBlockUser(user.uid, isBlocked),
                          icon: Icon(isBlocked ? Icons.gpp_bad_rounded : Icons.block_flipped, size: 20),
                          label: Text(
                            isBlocked ? 'UNBLOCK USER' : 'BLOCK USER',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isBlocked ? Colors.green : Colors.redAccent,
                            side: BorderSide(color: isBlocked ? Colors.green : Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      );
                    }
                  ),
                  const SizedBox(height: 20),
                  const SizedBox(height: 12),
                  // Connection Status Widget
                  StreamBuilder<ConnectionModel?>(
                    stream: ChatService().getConnection(user.uid),
                    builder: (context, snap) {
                      final conn = snap.data;
                      final String myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

                      if (conn == null || conn.status == ConnectionStatus.none) {
                        return _buildActionButton(
                          Icons.person_add_rounded,
                          'ADD FRIEND',
                          ChatTheme.primary,
                          () => ChatService().sendFriendRequest(user.uid),
                        );
                      }

                      if (conn.status == ConnectionStatus.pending) {
                        if (conn.senderId == myUid) {
                          return _buildActionButton(
                            Icons.hourglass_empty_rounded,
                            'REQUEST SENT - CANCEL',
                            Colors.orangeAccent,
                            () => ChatService().unfriend(user.uid),
                          );
                        } else {
                          return _buildActionButton(
                            Icons.check_circle_outline_rounded,
                            'ACCEPT REQUEST',
                            Colors.greenAccent,
                            () => ChatService().acceptFriendRequest(user.uid),
                          );
                        }
                      }

                      if (conn.status == ConnectionStatus.accepted) {
                        return _buildActionButton(
                          Icons.person_remove_rounded,
                          'UNFRIEND',
                          Colors.redAccent,
                          () => ChatService().unfriend(user.uid),
                        );
                      }

                      // Soft Unfriend states
                      bool unfriendedByMe = (myUid == conn.senderId && conn.status == ConnectionStatus.unfriendedBySender) ||
                                           (myUid == conn.receiverId && conn.status == ConnectionStatus.unfriendedByReceiver);
                      
                      if (unfriendedByMe) {
                        return _buildActionButton(
                          Icons.person_add_alt_1_rounded,
                          'RE-FRIEND DIRECTLY',
                          ChatTheme.primary,
                          () => ChatService().reFriend(user.uid),
                        );
                      } else {
                        // Unfriended by THEM, but I still have "accepted" perspective? 
                        // No, the UI should show Send Request.
                        return _buildActionButton(
                          Icons.person_add_rounded,
                          'SEND FRIEND REQUEST',
                          ChatTheme.primary,
                          () => ChatService().sendFriendRequest(user.uid),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  // Chat Button (Disabled if not friends)
                  StreamBuilder<ConnectionModel?>(
                    stream: ChatService().getConnection(user.uid),
                    builder: (context, snap) {
                      final isFriend = snap.data?.status == ConnectionStatus.accepted;
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isFriend ? () => Navigator.pop(context) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFriend ? ChatTheme.primary : Colors.grey.withOpacity(0.1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(
                            isFriend ? 'MESSAGE' : 'NOT FRIENDS',
                            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
                          ),
                        ),
                      );
                    }
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ChatTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: ChatTheme.primary),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: ChatTheme.textSecondary, fontSize: 12),
            ),
            Text(
              value,
              style: const TextStyle(
                color: ChatTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
