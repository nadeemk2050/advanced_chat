import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/chat_models.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import 'chat_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final NotificationService _notificationService = NotificationService();
  final UpdateService _updateService = UpdateService();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Start Advanced Services
    _notificationService.init();
    _updateService.checkForUpdates(context);
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: ChatTheme.textSecondary),
            onPressed: () => authService.signOut(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: ChatTheme.primary,
          labelColor: ChatTheme.primary,
          unselectedLabelColor: ChatTheme.textSecondary,
          tabs: const [
            Tab(text: 'CHATS', icon: Icon(Icons.forum_outlined)),
            Tab(text: 'MEMBERS', icon: Icon(Icons.people_alt_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRecentChats(currentUser),
          _buildGlobalDirectory(currentUser),
        ],
      ),
    );
  }

  Widget _buildRecentChats(User? currentUser) {
    return const Center(child: Text('Your recent chats will appear here 📩', style: TextStyle(color: ChatTheme.textSecondary)));
  }

  Widget _buildGlobalDirectory(User? currentUser) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Find members globally...',
              prefixIcon: const Icon(Icons.search_rounded, color: ChatTheme.primary),
              fillColor: ChatTheme.surface,
              filled: true,
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('uid', isNotEqualTo: currentUser?.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No members found globally.', style: TextStyle(color: ChatTheme.textSecondary)));
              }

              final users = snapshot.data!.docs
                  .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
                  .where((user) => user.name.toLowerCase().contains(_searchQuery.toLowerCase()))
                  .toList();

              return ListView.separated(
                itemCount: users.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: user.isOnline ? ChatTheme.primary : Colors.transparent, width: 2),
                      ),
                      child: CircleAvatar(
                        backgroundColor: ChatTheme.accent,
                        child: Text(user.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(user.isOnline ? 'Active Now' : 'Last seen: ${user.lastSeen.hour}:${user.lastSeen.minute}', 
                        style: TextStyle(color: user.isOnline ? ChatTheme.primary : ChatTheme.textSecondary, fontSize: 13)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: ChatTheme.textSecondary),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(otherUser: user))),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
