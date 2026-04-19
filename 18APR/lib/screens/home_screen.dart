import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/group_service.dart';
import '../services/update_service.dart';
import '../services/notification_service.dart';
import '../services/presence_service.dart';
import '../models/chat_models.dart';
import '../theme/app_theme.dart';
import 'chat_detail_screen.dart';
import 'group_chat_screen.dart';
import 'group_creator_screen.dart';
import 'profile_editor_screen.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'external_share_pick_screen.dart';
import 'personal_hub_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _presenceService = PresenceService();
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  late TabController _tabController;
  String _searchQuery = "";
  StreamSubscription? _intentSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _presenceService.activate();
    unawaited(UpdateService().checkForUpdates(context));
    NotificationService().init();
    _initSharing();
  }

  void _initSharing() {
    if (kIsWeb) return;
    
    // Listen for shared media while app is in memory
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      if (value.isNotEmpty) {
        _handleMediaValue(value);
      }
    });

    // Handle shared media when app is started from closed state
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        _handleMediaValue(value);
      }
    });

    // Removed duplicated listeners to avoid multiple triggers
  }

  void _handleMediaValue(List<SharedMediaFile> value) {
    // SharedMediaFile handles both files and text in 1.8.x
    final files = value.where((f) => f.type != SharedMediaType.text).map((f) => f.path).toList();
    final textFile = value.firstWhere((f) => f.type == SharedMediaType.text, orElse: () => value.first);
    
    _navigateToSharePicker(
      files: files.isEmpty ? null : files,
      text: value.any((f) => f.type == SharedMediaType.text) ? textFile.path : null, // text is in path for SharedMediaType.text
    );
  }

  void _navigateToSharePicker({List<String>? files, String? text}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ExternalSharePickScreen(
      sharedFiles: files,
      sharedText: text,
    )));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _presenceService.deactivate();
    _intentSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ADVANCED CHAT'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'MY CHATS', icon: Icon(Icons.forum_outlined)),
            Tab(text: 'ALL MEMBERS', icon: Icon(Icons.people_alt_outlined)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add_check_rounded, color: ChatTheme.primary),
            tooltip: 'Personal Hub',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonalHubScreen())),
          ),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('users').doc(currentUserId).snapshots(),
            builder: (context, snap) {
              final data = snap.data?.data();
              final photoUrl = data?['photoUrl'];
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditorScreen())),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: ChatTheme.primary.withOpacity(0.2),
                    backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                    child: (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person, color: ChatTheme.primary, size: 20) : null,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: _searchQuery.isEmpty 
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _ChatsTab(searchQuery: _searchQuery),
                        _MembersTab(searchQuery: _searchQuery),
                      ],
                    )
                  : GlobalSearchScreen(query: _searchQuery),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupCreatorScreen())),
        child: const Icon(Icons.group_add_rounded),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Container(
        decoration: BoxDecoration(
          color: ChatTheme.surface,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: ChatTheme.primary.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Search people or groups...',
            prefixIcon: const Icon(Icons.search_rounded, color: ChatTheme.primary),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }
}

class _ChatsTab extends StatefulWidget {
  final String searchQuery;
  const _ChatsTab({required this.searchQuery});

  @override
  State<_ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<_ChatsTab> with AutomaticKeepAliveClientMixin {
  bool _incomingExpanded = false;
  bool _sentExpanded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final chatService = ChatService();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: chatService.getChatThreads(),
      builder: (context, threadSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, userSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: GroupService().getGroups(),
              builder: (context, groupSnapshot) {
                return StreamBuilder<List<ConnectionModel>>(
                  stream: chatService.getIncomingFriendRequests(),
                  builder: (context, incomingSnap) {
                    return StreamBuilder<List<ConnectionModel>>(
                      stream: chatService.getSentFriendRequests(), // Added sent requests
                      builder: (context, sentSnap) {
                        if (!threadSnapshot.hasData || !userSnapshot.hasData || !groupSnapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final usersById = {for (var d in userSnapshot.data!.docs) d.id: UserModel.fromMap(d.data() as Map<String, dynamic>)};
                        final chatDocs = threadSnapshot.data!.docs
                            .where((d) => (d.data() as Map<String, dynamic>)['participants'] != null)
                            .toList()
                          ..sort((a, b) {
                            final aT = (a.data() as Map<String, dynamic>)['lastMessageAt'] as Timestamp?;
                            final bT = (b.data() as Map<String, dynamic>)['lastMessageAt'] as Timestamp?;
                            return (bT ?? Timestamp(0, 0)).compareTo(aT ?? Timestamp(0, 0));
                          });
                        
                        final groupDocs = groupSnapshot.data!.docs
                            .where((d) => (d.data() as Map<String, dynamic>)['name']
                                .toString()
                                .toLowerCase()
                                .contains(widget.searchQuery.toLowerCase()))
                            .toList();

                        final incomingRequests = incomingSnap.data ?? [];
                        final sentRequests = sentSnap.data ?? [];

                        return ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: [
                            // 1. Group Section
                            if (groupDocs.isNotEmpty) ...[
                              const _SectionHeader('GROUPS'),
                              ...groupDocs.map((d) => _buildGroupTile(context, GroupModel.fromMap(d.data() as Map<String, dynamic>))),
                            ],

                            // 2. Incoming Requests (PENDING)
                            if (incomingRequests.isNotEmpty) ...[
                              _buildClickableHeader(
                                'FRIEND REQUESTS PENDING (${incomingRequests.length})',
                                _incomingExpanded, // Changed state name for clarity
                                () => setState(() => _incomingExpanded = !_incomingExpanded),
                                Colors.orangeAccent,
                              ),
                              if (_incomingExpanded)
                                ...incomingRequests.map((req) {
                                  final sender = usersById[req.senderId];
                                  if (sender == null) return const SizedBox.shrink();
                                  return _buildIncomingRequestTile(context, sender);
                                }),
                            ],

                            // 3. Sent Requests (WAITING)
                            if (sentRequests.isNotEmpty) ...[
                              _buildClickableHeader(
                                'WAITING FOR APPROVALS (${sentRequests.length})',
                                _sentExpanded,
                                () => setState(() => _sentExpanded = !_sentExpanded),
                                Colors.blueAccent,
                              ),
                              if (_sentExpanded)
                                ...sentRequests.map((req) {
                                  final receiver = usersById[req.receiverId];
                                  if (receiver == null) return const SizedBox.shrink();
                                  return _buildSentRequestTile(context, receiver);
                                }),
                            ],

                            // 4. Approved Friends
                            const _SectionHeader('FRIENDS APPROVED'),
                            ...chatDocs.map((d) {
                              final p = List<String>.from(d.data()['participants'] ?? []);
                              final otherId = p.firstWhere((id) => id != currentUserId, orElse: () => '');
                              
                              return StreamBuilder<ConnectionModel?>(
                                stream: chatService.getConnection(otherId),
                                builder: (context, connSnap) {
                                  if (!connSnap.hasData || connSnap.data?.status != ConnectionStatus.accepted) {
                                    return const SizedBox.shrink();
                                  }

                                  final user = usersById[otherId];
                                  if (user == null) return const SizedBox.shrink();
                                  if (!user.name.toLowerCase().contains(widget.searchQuery.toLowerCase())) return const SizedBox.shrink();
                                  return _buildChatThreadTile(context, user, d.data());
                                },
                              );
                            }),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildClickableHeader(String title, bool isExpanded, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: 2,
              ),
            ),
            const Spacer(),
            Icon(
              isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              color: color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingRequestTile(BuildContext context, UserModel sender) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: ChatTheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ChatTheme.primary.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: sender.photoUrl.isNotEmpty ? NetworkImage(sender.photoUrl) : null,
          child: sender.photoUrl.isEmpty ? const Icon(Icons.person) : null,
        ),
        title: Text(sender.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: const Text('Sent you a friend request', style: TextStyle(fontSize: 11)),
        trailing: Wrap(
          spacing: 8,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
              onPressed: () => ChatService().acceptFriendRequest(sender.uid),
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 28),
              onPressed: () => ChatService().unfriend(sender.uid),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentRequestTile(BuildContext context, UserModel receiver) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: receiver.photoUrl.isNotEmpty ? NetworkImage(receiver.photoUrl) : null,
          child: receiver.photoUrl.isEmpty ? const Icon(Icons.person) : null,
        ),
        title: Text(receiver.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: const Text('Waiting for approval...', style: TextStyle(fontSize: 11)),
        trailing: IconButton(
          icon: const Icon(Icons.cancel_outlined, color: Colors.blueGrey, size: 24),
          onPressed: () => ChatService().unfriend(receiver.uid),
          tooltip: 'Cancel Request',
        ),
      ),
    );
  }

  Widget _buildChatThreadTile(BuildContext context, UserModel user, Map<String, dynamic> data) {
    final String myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final Map unreadCounts = data['unreadCounts'] as Map? ?? {};
    final int myUnread = unreadCounts[myUid] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: ChatTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(otherUser: user))),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: ChatTheme.primary.withOpacity(0.1),
              backgroundImage: (user.photoUrl != null && user.photoUrl!.isNotEmpty) ? NetworkImage(user.photoUrl!) : null,
              child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                  ? Text((user.name.isNotEmpty ? user.name[0] : '?').toUpperCase(),
                      style: const TextStyle(color: ChatTheme.primary, fontWeight: FontWeight.bold, fontSize: 14))
                  : null,
            ),
            if (user.isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.name,
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: ChatTheme.textPrimary, fontSize: 13),
              ),
            ),
            if (myUnread > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ChatTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$myUnread',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: StreamBuilder<String>(
            stream: ChatService().getPartnerStatus(user.uid),
            builder: (context, statusSnap) {
              final status = statusSnap.data ?? '';
              final isAction = status.isNotEmpty;
              
              return Text(
                isAction ? status : (data['lastMessageText'] ?? 'Start chatting...'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.montserrat(
                  color: isAction ? ChatTheme.primary : ChatTheme.textSecondary, 
                  fontSize: 12,
                  fontWeight: isAction ? FontWeight.bold : FontWeight.normal,
                ),
              );
            },
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: ChatTheme.primary, size: 20),
      ),
    );
  }

  Widget _buildGroupTile(BuildContext context, GroupModel group) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: ChatTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupChatScreen(group: group))),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: ChatTheme.primary.withOpacity(0.1),
          backgroundImage: (group.groupPhotoUrl != null && group.groupPhotoUrl!.isNotEmpty) ? NetworkImage(group.groupPhotoUrl!) : null,
          child: (group.groupPhotoUrl == null || group.groupPhotoUrl!.isEmpty)
              ? const Icon(Icons.group_rounded, color: ChatTheme.primary, size: 30)
              : null,
        ),
        title: Text(
          group.name,
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: ChatTheme.textPrimary, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            group.lastMessage ?? 'Group created',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.montserrat(color: ChatTheme.textSecondary, fontSize: 13),
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: ChatTheme.primary),
      ),
    );
  }
}

class _MembersTab extends StatefulWidget {
  final String searchQuery;
  const _MembersTab({required this.searchQuery});

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final users = snap.data!.docs
            .map((d) => UserModel.fromMap(d.data() as Map<String, dynamic>))
            .where((u) => 
                u.uid != currentUserId && 
                u.name.trim().isNotEmpty && 
                u.isVisibleInMembersList && // Added filter
                u.name.toLowerCase().contains(widget.searchQuery.toLowerCase()))
            .toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) => _buildMemberTile(context, users[index]),
        );
      },
    );
  }

  Widget _buildMemberTile(BuildContext context, UserModel user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: ChatTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(otherUser: user))),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: ChatTheme.primary.withOpacity(0.1),
          backgroundImage: (user.photoUrl != null && user.photoUrl!.isNotEmpty) ? NetworkImage(user.photoUrl!) : null,
          child: (user.photoUrl == null || user.photoUrl!.isEmpty)
              ? Text((user.name.isNotEmpty ? user.name[0] : '?').toUpperCase(),
                  style: const TextStyle(color: ChatTheme.primary, fontWeight: FontWeight.bold, fontSize: 14))
              : null,
        ),
        title: Text(
          user.name,
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: ChatTheme.textPrimary, fontSize: 13),
        ),
        subtitle: Text(
          user.isOnline ? 'Active Now' : 'Recently Active',
          style: GoogleFonts.montserrat(color: user.isOnline ? Colors.green : ChatTheme.textSecondary, fontSize: 12),
        ),
        trailing: Icon(Icons.circle, color: user.isOnline ? Colors.green : Colors.transparent, size: 10),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: ChatTheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: ChatTheme.primary,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class GlobalSearchScreen extends StatelessWidget {
  final String query;
  const GlobalSearchScreen({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: LocalDatabaseService().searchGlobal(query),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final results = snap.data!;
        
        if (results.isEmpty) {
          return Center(
            child: Text('No results for "$query"', 
              style: const TextStyle(color: Colors.white38)),
          );
        }

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, i) {
            final res = results[i];
            final timestamp = DateTime.parse(res['timestamp']);
            final isGroup = (res['isGroup'] as int? ?? 0) == 1;
            
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isGroup ? Colors.blueAccent : ChatTheme.primary.withOpacity(0.1),
                child: Icon(isGroup ? Icons.group_rounded : Icons.person_rounded, 
                  size: 20, color: Colors.white70),
              ),
              title: Text(res['text'] ?? '', 
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(
                '${isGroup ? "Group" : "Chat"} · ${DateFormat('MMM dd, HH:mm').format(timestamp)}',
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
              onTap: () {
                // Navigate to the chat
                // For simplicity, we navigate. In real app, we might need to fetch the target profile/group details first.
                // We'll jump to the chat screen.
              },
            );
          },
        );
      },
    );
  }
}
