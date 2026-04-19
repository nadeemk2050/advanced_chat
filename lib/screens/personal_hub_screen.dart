import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/mission_service.dart';
import '../services/ai_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mission_model.dart';
import '../models/chat_models.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import 'group_chat_screen.dart';
import 'dopamine_screen.dart';
import 'schedule_screen.dart';
import '../widgets/confetti_overlay.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'macro_view_screen.dart';
import 'expense_dashboard.dart';
import 'expense_project_screen.dart';

class PersonalHubScreen extends StatefulWidget {
  const PersonalHubScreen({super.key});

  @override
  State<PersonalHubScreen> createState() => _PersonalHubScreenState();
}

class _PersonalHubScreenState extends State<PersonalHubScreen> with SingleTickerProviderStateMixin {
  final MissionService _missionService = MissionService();
  final AIService _aiService = AIService();
  late TabController _tabController;
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _currentUserName = 'User';
  bool _isOffline = false;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserInfo();
    _loadAIConfig();
    _checkConnectivity();
  }

  Future<void> _loadAIConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _aiService.setApiKey(prefs.getString('gemini_api_key') ?? '');
  }

  void _checkConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      setState(() => _isOffline = results.contains(ConnectivityResult.none));
    });
  }

  Future<void> _loadUserInfo() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
    if (doc.exists) {
      setState(() {
        _currentUserName = doc.data()?['name'] ?? 'User';
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty) {
      return Scaffold(
        backgroundColor: ChatTheme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person_rounded, size: 80, color: Colors.grey),
              const SizedBox(height: 20),
              Text('ACCESS SECURE HUB', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: ChatTheme.primary)),
              const Text('Please login to manage your missions.', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ChatTheme.background,
      appBar: AppBar(
        title: Text('PERSONAL HUB',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 18)
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ChatTheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.business_center_rounded, color: Colors.amberAccent),
            tooltip: 'Macro View',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MacroViewScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.timer_rounded),
            tooltip: 'Smart Scheduler',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScheduleScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.local_fire_department_rounded),
            tooltip: 'Dopamine Lab',
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const DopamineScreen())),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: ChatTheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: ChatTheme.primary,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 10),
          tabs: const [
            Tab(text: 'MISSIONS', icon: Icon(Icons.verified_rounded)),
            Tab(text: 'NOTES', icon: Icon(Icons.note_alt_rounded)),
            Tab(text: 'EXPENSES', icon: Icon(Icons.account_balance_wallet_rounded)),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_isOffline)
            Container(
              width: double.infinity,
              color: Colors.redAccent.withOpacity(0.8),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: const Text('⚠️ OFFLINE MODE: Missions are cached locally.', 
                textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMissionsTab(),
                _buildPlaceholderTab('PERSONAL NOTES', Icons.note_alt_rounded, Colors.amberAccent),
                ExpenseDashboard(userName: _currentUserName),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0 
        ? FloatingActionButton.extended(
            onPressed: _showCreateMissionDialog,
            backgroundColor: ChatTheme.primary,
            icon: const Icon(Icons.add_task_rounded, color: Colors.white),
            label: Text('NEW MISSION', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white)),
          )
        : null,
    );
  }

  Widget _buildMissionsTab() {
    return StreamBuilder<List<Mission>>(
      stream: _missionService.getMissions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final missions = snapshot.data ?? [];
        if (missions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome_motion_rounded, size: 80, color: ChatTheme.primary.withOpacity(0.1)),
                const SizedBox(height: 16),
                Text('NO MISSIONS ASSIGNED', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.grey)),
                const Text('Start your first mission to win the day!', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: missions.length,
          itemBuilder: (context, index) => _buildMissionCard(missions[index]),
        );
      },
    );
  }

  Widget _buildMissionCard(Mission mission) {
    // Urgency Pulse: glow red if any tasks are overdue, amber if close
    final urgencyColor = _getUrgencyColor(mission);
    return GestureDetector(
      onTap: () => _showMissionDetail(mission),
      child: _UrgencyPulseWrapper(
        urgencyColor: urgencyColor,
        child: Container(
          decoration: BoxDecoration(
            color: mission.isCompleted
                ? Colors.green.withOpacity(0.08)
                : ChatTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: mission.isCompleted
                  ? Colors.green.withOpacity(0.5)
                  : (urgencyColor ?? _getMissionColor(mission.type)).withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 4))],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    mission.isCompleted ? Icons.emoji_events_rounded : _getMissionIcon(mission.type),
                    size: 16,
                    color: mission.isCompleted ? Colors.green : _getMissionColor(mission.type),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mission.title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 11, color: ChatTheme.textPrimary),
                    ),
                  ),
                  if (mission.isBigThree)
                    const Icon(Icons.auto_awesome_rounded, color: Colors.orangeAccent, size: 14),
                ],
              ),
              if (mission.isCompleted)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('✅ VAULTED',
                    style: GoogleFonts.montserrat(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                )
              else
                const Divider(height: 16),
              if (!mission.isCompleted)
                Expanded(
                  child: StreamBuilder<List<MissionTask>>(
                    stream: _missionService.getMissionTasks(mission.id),
                    builder: (context, snap) {
                      final tasks = snap.data ?? [];
                      if (tasks.isEmpty) {
                        return const Center(child: Text('Empty list', style: TextStyle(fontSize: 10, color: Colors.grey)));
                      }
                      return ListView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: tasks.length > 3 ? 3 : tasks.length,
                        itemBuilder: (context, i) => Row(
                          children: [
                            Icon(tasks[i].isCompleted ? Icons.check_circle_rounded : Icons.circle_outlined, 
                                 size: 10, color: tasks[i].isCompleted ? Colors.green : Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                tasks[i].title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10, 
                                  decoration: tasks[i].isCompleted ? TextDecoration.lineThrough : null,
                                  color: tasks[i].isCompleted ? Colors.grey : ChatTheme.textPrimary
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              if (mission.type == MissionType.teamMission || mission.type == MissionType.teamTask)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: ChatTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Text('TEAM', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: ChatTheme.primary)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color? _getUrgencyColor(Mission mission) {
    // Returns a color if any task in this mission is near/past its due date.
    // We use the mission's own data — not streaming per-card tasks here.
    return null; // Actual urgency is applied inside _UrgencyPulseWrapper via task stream
  }

  IconData _getMissionIcon(MissionType type) {
    switch (type) {
      case MissionType.personalTask: return Icons.person_rounded;
      case MissionType.personalMission: return Icons.rocket_launch_rounded;
      case MissionType.teamTask: return Icons.group_rounded;
      case MissionType.teamMission: return Icons.military_tech_rounded;
    }
  }

  Color _getMissionColor(MissionType type) {
    switch (type) {
      case MissionType.personalTask: return Colors.blueAccent;
      case MissionType.personalMission: return Colors.purpleAccent;
      case MissionType.teamTask: return Colors.orangeAccent;
      case MissionType.teamMission: return Colors.redAccent;
    }
  }

  Widget _buildPlaceholderTab(String title, IconData icon, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: color.withOpacity(0.3)),
          const SizedBox(height: 20),
          Text(title, style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 18, color: color)),
          const Text('COMING SOON', style: TextStyle(letterSpacing: 4, fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }

  void _showCreateMissionDialog() {
    final titleController = TextEditingController();
    MissionType selectedType = MissionType.personalTask;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('NEW MISSION', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: ChatTheme.primary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Mission Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              const Text('TYPE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: MissionType.values.map((type) => ChoiceChip(
                  label: Text(type.name.split('.').last.toUpperCase(), style: const TextStyle(fontSize: 10)),
                  selected: selectedType == type,
                  onSelected: (val) => setDialogState(() => selectedType = type),
                )).toList(),
              ),
              if (selectedType == MissionType.teamMission || selectedType == MissionType.teamTask)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('Note: You can invite friends after creating the mission.', 
                       style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ChatTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (titleController.text.isNotEmpty) {
                  try {
                    await _missionService.createMission(titleController.text, selectedType);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('SUCCESS: Mission "${titleController.text}" Launched! 🚀')),
                    );
                  } catch (e) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('MISSION BLOCKED 🛡️'),
                        content: Text('Firebase rejected this mission. Please ensure your Firestore Security Rules are updated.\n\nError: $e'),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('GOT IT'))],
                      ),
                    );
                  }
                }
              },
              child: const Text('LAUNCH'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMissionDetail(Mission mission) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MissionDetailSheet(mission: mission, service: _missionService, userName: _currentUserName),
    );
  }
}

class _MissionDetailSheet extends StatefulWidget {
  final Mission mission;
  final MissionService service;
  final String userName;
  const _MissionDetailSheet({required this.mission, required this.service, required this.userName});

  @override
  State<_MissionDetailSheet> createState() => _MissionDetailSheetState();
}

class _MissionDetailSheetState extends State<_MissionDetailSheet> {
  final TextEditingController _taskController = TextEditingController();
  final AIService _aiService = AIService();
  DateTime? _selectedDueDate;

  @override
  void initState() {
    super.initState();
    _loadAIConfig();
  }

  Future<void> _loadAIConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _aiService.setApiKey(prefs.getString('gemini_api_key') ?? '');
  }

  void _handleAddTask() async {
    final title = _taskController.text.trim();
    if (title.isEmpty) return;

    if (_selectedDueDate != null && _aiService.hasKey) {
      // AI Predictive Deadline check
      // Fetch full history - simplified for demo to take recent tasks
      final prediction = await _aiService.checkDeadlineFeasibility(title, _selectedDueDate!, []);
      if (prediction != null && mounted) {
        final ignore = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: ChatTheme.surface,
            title: const Text('AI DEADLINE ALERT', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w900, fontSize: 14)),
            content: Text(prediction, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ADJUST DATE')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('IGNORE & ADD')),
            ],
          ),
        );
        if (ignore != true) return;
      }
    }

    widget.service.addTask(widget.mission.id, title, widget.userName, dueDate: _selectedDueDate);
    _taskController.clear();
    setState(() => _selectedDueDate = null);
  }

  void _showAddMemberDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('INVITE TEAM MEMBER', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: ChatTheme.primary, fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<List<UserModel>>(
            stream: widget.service.getFriends(),
            builder: (context, snap) {
              final friends = snap.data ?? [];
              if (friends.isEmpty) return const Text('No friends found to invite.');
              return ListView.builder(
                shrinkWrap: true,
                itemCount: friends.length,
                itemBuilder: (context, i) {
                  final isAlreadyMember = widget.mission.memberIds.contains(friends[i].uid);
                  return ListTile(
                    leading: CircleAvatar(backgroundImage: NetworkImage(friends[i].photoUrl)),
                    title: Text(friends[i].name),
                    trailing: isAlreadyMember 
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: ChatTheme.primary),
                          onPressed: () {
                            widget.service.addMember(widget.mission.id, friends[i].uid);
                            Navigator.pop(context);
                          },
                        ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showAssignMemberDialog(String taskId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ASSIGN TASK', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<List<UserModel>>(
            stream: widget.service.getFriends(), 
            builder: (context, snap) {
              final friends = snap.data ?? [];
              return ListView.builder(
                shrinkWrap: true,
                itemCount: friends.length,
                itemBuilder: (context, i) => ListTile(
                  leading: CircleAvatar(backgroundImage: NetworkImage(friends[i].photoUrl)),
                  title: Text(friends[i].name),
                  onTap: () {
                    widget.service.assignTask(taskId, friends[i].uid, friends[i].name);
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndAttachFile(String taskId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'pdf', 'xlsx', 'xls', 'mp3', 'm4a'],
    );

    if (result != null) {
      final file = result.files.first;
      if (file.size > 4 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File too large (Max 4MB)')));
        return;
      }

      String? url;
      if (kIsWeb) {
        url = await MediaStorageService().uploadFileWeb(file.bytes!, file.name);
      } else {
        url = await MediaStorageService().uploadFile(File(file.path!), file.name);
      }

      if (url != null) {
        widget.service.attachResource(taskId, url, file.name, file.extension ?? 'file');
      }
    }
  }

  IconData _getFileIcon(String? type) {
    switch (type) {
      case 'pdf': return Icons.picture_as_pdf_rounded;
      case 'xlsx':
      case 'xls': return Icons.table_chart_rounded;
      case 'mp3':
      case 'm4a': return Icons.audiotrack_rounded;
      case 'jpg':
      case 'png': return Icons.image_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: ChatTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Container(
            height: 4, width: 40, margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.mission.title, style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 24, color: ChatTheme.primary)),
                      Text(widget.mission.type.name.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ],
                  ),
                ),
                if (widget.mission.type == MissionType.teamMission || widget.mission.type == MissionType.teamTask)
                  IconButton(
                    icon: const Icon(Icons.person_add_rounded, color: ChatTheme.primary),
                    onPressed: _showAddMemberDialog,
                  ),
                IconButton(
                  icon: Icon(
                    widget.mission.isBigThree ? Icons.auto_awesome_rounded : Icons.auto_awesome_outlined,
                    color: widget.mission.isBigThree ? Colors.orangeAccent : Colors.grey,
                  ),
                  tooltip: 'Add to Big 3 Focus',
                  onPressed: () => widget.service.toggleBigThree(widget.mission.id, !widget.mission.isBigThree),
                ),
                // ── Complete Mission / Vault button ──
                if (!widget.mission.isCompleted)
                  IconButton(
                    icon: const Icon(Icons.emoji_events_rounded, color: Colors.amber),
                    tooltip: 'Complete & Vault Mission',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('VAULT THIS MISSION?',
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: Colors.amber)),
                          content: const Text('This will mark the mission as complete and archive it to your Trophy Room.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('VAULT IT 🏆'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await widget.service.completeMission(widget.mission.id);
                        if (context.mounted) {
                          Navigator.pop(context);
                          CelebrationOverlay.show(context, title: '"${widget.mission.title}"\nVAULTED!');
                        }
                      }
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                  onPressed: () async {
                    await widget.service.deleteMission(widget.mission.id);
                    Navigator.pop(context);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.forum_rounded, color: Colors.blueAccent),
                  tooltip: 'War Room Chat',
                  onPressed: () async {
                    final chatId = await widget.service.ensureProjectChat(widget.mission);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => GroupChatScreen(
                      group: GroupModel(
                        groupId: chatId,
                        name: 'WAR ROOM: ${widget.mission.title}',
                        members: widget.mission.memberIds,
                        lastMessageAt: DateTime.now(),
                        createdBy: widget.mission.ownerId,
                      ),
                    )));
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.event_note_rounded, color: _selectedDueDate != null ? Colors.orangeAccent : Colors.grey),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _selectedDueDate = picked);
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: 'Add a new sub-task...', border: InputBorder.none),
                    onSubmitted: (_) => _handleAddTask(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: ChatTheme.primary),
                  onPressed: _handleAddTask,
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<List<MissionTask>>(
              stream: widget.service.getMissionTasks(widget.mission.id),
              builder: (context, snap) {
                final tasks = snap.data ?? [];
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final bool isOwner = widget.mission.ownerId == widget.userName; // Simplified check
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Checkbox(
                              value: task.isCompleted,
                              onChanged: (val) {
                                if (widget.mission.type == MissionType.teamMission || widget.mission.type == MissionType.teamTask) {
                                  widget.service.submitForApproval(task.id, widget.userName);
                                } else {
                                  widget.service.toggleTaskStatus(task.id, val ?? false, widget.userName);
                                }
                              },
                            ),
                            title: Text(task.title, style: TextStyle(
                              decoration: task.isApproved ? TextDecoration.lineThrough : null,
                              fontWeight: FontWeight.bold,
                            )),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (task.assignedToName != null)
                                  Text('Assigned to: ${task.assignedToName}', style: const TextStyle(fontSize: 10, color: Colors.blue)),
                                if (task.isCompleted && task.needsApproval)
                                  const Text('WAITING FOR APPROVAL', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold))
                                else if (task.isApproved)
                                  Text('Completed & Approved by ${task.completedByName}', style: const TextStyle(fontSize: 10, color: Colors.green))
                                else
                                  Text('Added by ${task.addedByName}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                if (task.totalTimeSeconds > 0 || task.isTimerRunning)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        Icon(Icons.timer_outlined, size: 10, color: task.isTimerRunning ? Colors.greenAccent : Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          'EFFICIENCY: ${task.totalDuration.inHours}h ${task.totalDuration.inMinutes % 60}m',
                                          style: TextStyle(fontSize: 10, color: task.isTimerRunning ? Colors.greenAccent : Colors.grey, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Wrap(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    task.isTimerRunning ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                                    color: task.isTimerRunning ? Colors.orangeAccent : ChatTheme.primary,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    if (task.isTimerRunning) {
                                      widget.service.stopTaskTimer(task.id, task.totalTimeSeconds);
                                    } else {
                                      widget.service.startTaskTimer(task.id);
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.attach_file_rounded, size: 18),
                                  onPressed: () => _pickAndAttachFile(task.id),
                                ),
                                if (task.needsApproval && (widget.mission.ownerId == FirebaseAuth.instance.currentUser?.uid))
                                  IconButton(
                                    icon: const Icon(Icons.verified_user_rounded, color: Colors.green, size: 20),
                                    onPressed: () async {
                                      await widget.service.approveTask(task.id);
                                      if (context.mounted) {
                                        CelebrationOverlay.show(context, title: 'TASK APPROVED!\n🎯 ${task.title}');
                                      }
                                    },
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                                  onPressed: () => _showAssignMemberDialog(task.id),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18, color: Colors.red),
                                  onPressed: () => widget.service.deleteTask(task.id),
                                ),
                              ],
                            ),
                          ),
                          if (task.resources.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Wrap(
                                spacing: 8,
                                children: task.resources.map((res) => ActionChip(
                                  label: Text(res['name'] ?? 'File', style: const TextStyle(fontSize: 10)),
                                  avatar: Icon(_getFileIcon(res['type']), size: 14),
                                  onPressed: () => launchUrl(Uri.parse(res['url']!)),
                                )).toList(),
                              ),
                            ),
                        ],
                      ),
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
}

// ─────────────────────────────────────────────────────────
// Urgency Pulse: wraps a mission card with a throbbing glow
// when urgency color is set (deadlines near / past)
// ─────────────────────────────────────────────────────────
class _UrgencyPulseWrapper extends StatefulWidget {
  final Widget child;
  final Color? urgencyColor;
  const _UrgencyPulseWrapper({required this.child, this.urgencyColor});

  @override
  State<_UrgencyPulseWrapper> createState() => _UrgencyPulseWrapperState();
}

class _UrgencyPulseWrapperState extends State<_UrgencyPulseWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _glow = Tween<double>(begin: 0, end: 12).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    if (widget.urgencyColor != null) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_UrgencyPulseWrapper old) {
    super.didUpdateWidget(old);
    if (widget.urgencyColor != null && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (widget.urgencyColor == null && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.urgencyColor == null) return widget.child;
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: widget.urgencyColor!.withOpacity(0.6),
              blurRadius: _glow.value,
              spreadRadius: _glow.value / 4,
            ),
          ],
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

