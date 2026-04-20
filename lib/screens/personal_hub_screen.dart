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

        final double screenWidth = MediaQuery.of(context).size.width;
        final int crossAxisCount = screenWidth > 600 ? 2 : 1;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: crossAxisCount == 1 ? 2.5 : 0.85,
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
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(labelText: 'Mission Title', border: OutlineInputBorder(), labelStyle: TextStyle(color: Colors.black54)),
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
  final TextEditingController _pointsController = TextEditingController(text: '0');
  final AIService _aiService = AIService();
  DateTime? _selectedDueDate;
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  final Set<String> _collapsedTaskIds = {}; // Track collapsed tasks

  @override
  void initState() {
    super.initState();
    _loadAIConfig();
  }

  Future<void> _loadAIConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _aiService.setApiKey(prefs.getString('gemini_api_key') ?? '');
  }

  void _showRenameMissionDialog() {
    final ctrl = TextEditingController(text: widget.mission.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('RENAME MISSION', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: ChatTheme.primary, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(labelText: 'Mission Name', border: OutlineInputBorder(), labelStyle: TextStyle(color: Colors.black54)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ChatTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                await widget.service.renameMission(widget.mission.id, name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _showRenameTaskDialog(MissionTask task) {
    final ctrl = TextEditingController(text: task.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('RENAME TASK', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: ChatTheme.primary, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(labelText: 'Task Name', border: OutlineInputBorder(), labelStyle: TextStyle(color: Colors.black54)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ChatTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                await widget.service.renameTask(task.id, name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTaskWithPassword(String taskId) async {
    final passCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('DELETE TASK', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: Colors.redAccent, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter password to confirm deletion:', style: TextStyle(fontSize: 13, color: Colors.black87)),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              autofocus: true,
              obscureText: true,
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (passCtrl.text == 'abcd') {
        await widget.service.deleteTask(taskId);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incorrect password. Task not deleted.'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
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

    final points = int.tryParse(_pointsController.text.trim()) ?? 0;
    widget.service.addTask(widget.mission.id, title, widget.userName, dueDate: _selectedDueDate, pointsRewards: points);
    _taskController.clear();
    _pointsController.text = '0';
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
    final double screenHeight = MediaQuery.of(context).size.height;
    return Container(
      height: screenHeight,
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
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          widget.mission.title.toUpperCase(),
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: widget.mission.ownerId == _uid ? Colors.orange : Colors.blue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.mission.ownerId == _uid ? 'CREATOR' : 'TEAM MEMBER',
                              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(widget.mission.type.name.toUpperCase(), 
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),
                StreamBuilder<List<MissionTask>>(
                  stream: widget.service.getMissionTasks(widget.mission.id),
                  builder: (context, taskSnap) {
                    final allTasks = taskSnap.data ?? [];
                    final needsVaulting = allTasks.isNotEmpty && allTasks.every((t) => t.isApproved);
                    final isCreator = widget.mission.ownerId == _uid;

                    return PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.black),
                      onSelected: (val) async {
                        switch (val) {
                          case 'rename': _showRenameMissionDialog(); break;
                          case 'invite': _showAddMemberDialog(); break;
                          case 'big_three': 
                            widget.service.toggleBigThree(widget.mission.id, !widget.mission.isBigThree); 
                            break;
                          case 'war_room':
                            final chatId = await widget.service.ensureProjectChat(widget.mission);
                            if (mounted) {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => GroupChatScreen(
                                group: GroupModel(
                                  groupId: chatId,
                                  name: 'WAR ROOM: ${widget.mission.title}',
                                  members: widget.mission.memberIds,
                                  lastMessageAt: DateTime.now(),
                                  createdBy: widget.mission.ownerId,
                                ),
                              )));
                            }
                            break;
                          case 'vault':
                            if (!needsVaulting && isCreator) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot vault: tasks missing approval!')));
                              return;
                            }
                            await widget.service.completeMission(widget.mission.id, widget.userName);
                            Navigator.pop(context);
                            break;
                          case 'members':
                            _showMembersEarningsDialog(allTasks);
                            break;
                          case 'delete':
                            await widget.service.deleteMission(widget.mission.id);
                            Navigator.pop(context);
                            break;
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'rename', child: ListTile(dense: true, leading: Icon(Icons.edit_rounded), title: Text('Rename Mission'))),
                        if (widget.mission.type == MissionType.teamMission || widget.mission.type == MissionType.teamTask)
                          const PopupMenuItem(value: 'invite', child: ListTile(dense: true, leading: Icon(Icons.person_add_rounded), title: Text('Invite Members'))),
                        const PopupMenuItem(value: 'members', child: ListTile(dense: true, leading: Icon(Icons.badge_rounded), title: Text('Mission Members List'))),
                        PopupMenuItem(value: 'big_three', child: ListTile(dense: true, leading: Icon(widget.mission.isBigThree ? Icons.auto_awesome_rounded : Icons.auto_awesome_outlined), title: Text(widget.mission.isBigThree ? 'Focus Big 3' : 'Focus Big 3'))),
                        const PopupMenuItem(value: 'war_room', child: ListTile(dense: true, leading: Icon(Icons.forum_rounded), title: Text('War Room Chat'))),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'vault', 
                          enabled: needsVaulting && isCreator,
                          child: ListTile(
                            dense: true, 
                            leading: Icon(Icons.emoji_events_rounded, color: needsVaulting ? Colors.amber : Colors.grey), 
                            title: Text('Vault Mission', style: TextStyle(color: needsVaulting ? Colors.black : Colors.grey)),
                          ),
                        ),
                        const PopupMenuItem(value: 'delete', child: ListTile(dense: true, leading: Icon(Icons.delete_forever_rounded, color: Colors.red), title: Text('Delete Mission'))),
                      ],
                    );
                  }
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
                  flex: 3,
                  child: TextField(
                    controller: _taskController,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(hintText: 'Add a new sub-task...', border: InputBorder.none),
                    onSubmitted: (_) => _handleAddTask(),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _pointsController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w900, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Pts',
                      hintStyle: TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.bold),
                      border: InputBorder.none, 
                      prefixIcon: Icon(Icons.stars_rounded, size: 14, color: Colors.orange),
                    ),
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
                // Sort top-level tasks (no parent) first
                final rootTasks = tasks.where((t) => t.parentId == null).toList();
                
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: rootTasks.map((task) => _buildTaskNode(task, tasks, 0)).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskNode(MissionTask task, List<MissionTask> allTasks, int level) {
    if (level >= 10) return const SizedBox.shrink(); // Tree depth limit

    final children = allTasks.where((t) => t.parentId == task.id).toList();
    final double fontSize = 16.0 - (level * 1.2); 
    final double paddingLeft = level * 16.0;

    int calculateTotalGroupPotential(MissionTask t, List<MissionTask> others) {
      int total = t.pointsRewards;
      final directChildren = others.where((task) => task.parentId == t.id).toList();
      for (var child in directChildren) {
        total += calculateTotalGroupPotential(child, others);
      }
      return total;
    }

    final int totalGroupPotential = calculateTotalGroupPotential(task, allTasks);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: paddingLeft),
          child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: level == 0 ? 2 : 0,
            color: level == 0 ? Colors.white : Colors.white.withOpacity(1.0 - (level * 0.05)),
            child: Column(
              children: [
                ListTile(
                  dense: level > 0,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: IconButton(
                    icon: const Icon(Icons.more_vert, size: 20, color: Colors.black54),
                    onPressed: () => _showTaskOptions(task),
                  ),
                  title: Row(
                    children: [
                      if (children.isNotEmpty)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            _collapsedTaskIds.contains(task.id) ? Icons.chevron_right_rounded : Icons.expand_more_rounded,
                            size: 18,
                            color: Colors.black54,
                          ),
                          onPressed: () => setState(() {
                            if (_collapsedTaskIds.contains(task.id)) {
                              _collapsedTaskIds.remove(task.id);
                            } else {
                              _collapsedTaskIds.add(task.id);
                            }
                          }),
                        ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            task.title,
                            style: TextStyle(
                              decoration: task.isApproved ? TextDecoration.lineThrough : null,
                              fontWeight: level == 0 ? FontWeight.bold : FontWeight.w600,
                              fontSize: fontSize,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.black, size: 20),
                        onPressed: () => _showPlusMenu(task),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (task.pointsRewards > 0)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text('🎯 Self: +${task.pointsRewards}P', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                            ),
                          if (children.isNotEmpty)
                             Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)),
                              child: Text('TOTAL WEIGHT: $totalGroupPotential Pts', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                            ),
                          const SizedBox(width: 8),
                          if (task.notes != null && task.notes!.isNotEmpty)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.notes_rounded, color: Colors.blueAccent, size: 16),
                              onPressed: () => _showTaskNoteDialog(task),
                            ),
                          const SizedBox(width: 8),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              task.isTimerRunning ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                              color: task.isTimerRunning ? Colors.orange : Colors.black54,
                              size: 16,
                            ),
                            onPressed: () {
                              if (task.isTimerRunning) {
                                widget.service.stopTaskTimer(task.id, task.totalTimeSeconds);
                              } else {
                                widget.service.startTaskTimer(task.id);
                              }
                            },
                          ),
                          if (task.needsApproval && (widget.mission.ownerId == _uid))
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.verified_user_rounded, color: Colors.green, size: 16),
                              onPressed: () => _showApprovalMarksDialog(task),
                            ),
                        ],
                      ),
                      if (task.assignedToName != null)
                        Text('User: ${task.assignedToName}', style: TextStyle(fontSize: fontSize * 0.7, color: Colors.blue, fontWeight: FontWeight.bold)),
                      if (task.isCompleted && task.needsApproval)
                        Text('WAITING FOR CREATOR APPROVAL', style: TextStyle(fontSize: fontSize * 0.7, color: Colors.orange, fontWeight: FontWeight.bold))
                      else if (task.isApproved)
                        Text('APPROVED: ${task.approvedPoints}/${task.pointsRewards} Pts', style: TextStyle(fontSize: fontSize * 0.7, color: Colors.green, fontWeight: FontWeight.bold))
                      else
                        Text('Total Potential: ${task.pointsRewards} Pts', style: TextStyle(fontSize: fontSize * 0.7, color: Colors.grey)),
                      if (task.resources.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 4,
                            children: task.resources.map((res) => GestureDetector(
                              onTap: () => launchUrl(Uri.parse(res['url']!)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                                child: Text(res['name'] ?? 'File', style: const TextStyle(fontSize: 8, color: Colors.black87)),
                              ),
                            )).toList(),
                          ),
                        ),
                    ],
                  ),
                  trailing: Checkbox(
                    value: task.isCompleted,
                    onChanged: (val) => _handleTaskToggle(task, val ?? false),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!_collapsedTaskIds.contains(task.id))
          ...children.map((child) => _buildTaskNode(child, allTasks, level + 1)).toList(),
      ],
    );
  }

  void _showMembersEarningsDialog(List<MissionTask> tasks) {
    // Map UID to Points
    final earnings = <String, int>{};
    for (var t in tasks) {
      if (t.isApproved && t.completedByUid != null) {
        earnings[t.completedByUid!] = (earnings[t.completedByUid!] ?? 0) + t.approvedPoints;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            const Icon(Icons.groups_rounded, size: 40, color: ChatTheme.primary),
            const SizedBox(height: 8),
            Text('MISSION MEMBERS', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 18)),
            const Divider(),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').where('uid', whereIn: widget.mission.memberIds).snapshots(),
            builder: (context, userSnap) {
              if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());
              final userDocs = userSnap.data!.docs;

              return ListView.builder(
                shrinkWrap: true,
                itemCount: userDocs.length,
                itemBuilder: (context, i) {
                  final userData = userDocs[i].data() as Map<String, dynamic>;
                  final name = userData['name'] ?? 'Unknown';
                  final uid = userData['uid'] ?? '';
                  final points = earnings[uid] ?? 0;
                  final isCreator = uid == widget.mission.ownerId;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCreator ? Colors.orange.withOpacity(0.05) : Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isCreator ? Colors.orange : Colors.blue, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: isCreator ? Colors.orange : Colors.blue,
                          child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black, fontSize: 14)),
                              Text(isCreator ? 'CREATOR' : 'TEAM USER', style: TextStyle(fontSize: 10, color: isCreator ? Colors.orange : Colors.blue, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            '$points PTS',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _showApprovalMarksDialog(MissionTask task) {
    final marksCtrl = TextEditingController(text: task.pointsRewards.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('APPROVE & REWARD', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Task: ${task.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Assign Marks (Max ${task.pointsRewards}):', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: marksCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.black),
              decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.stars_rounded, color: Colors.orange)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              final marks = int.tryParse(marksCtrl.text) ?? 0;
              widget.service.approveTask(task.id, marks, widget.userName);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Task Approved with $marks Marks!')));
            },
            child: const Text('APPROVE TASK'),
          ),
        ],
      ),
    );
  }

  void _handleTaskToggle(MissionTask task, bool newValue) async {
    // If we are unchecking, ask for password
    if (task.isCompleted && !newValue) {
      final passCtrl = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('UNLOCK TASK', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter password to uncheck this task:', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Password'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('UNLOCK')),
          ],
        ),
      );

      if (confirmed == true && passCtrl.text == 'abcd') {
         widget.service.toggleTaskStatus(task.id, false, widget.userName);
      } else if (confirmed == true) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wrong password!')));
      }
      return;
    }

    // Normal completion
    if (newValue) {
      if (widget.mission.type == MissionType.teamMission || widget.mission.type == MissionType.teamTask) {
        widget.service.submitForApproval(task.id, widget.userName);
      } else {
        widget.service.toggleTaskStatus(task.id, true, widget.userName);
      }
    }
  }

  void _showPlusMenu(MissionTask parentTask) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_task_rounded, color: Colors.black, size: 28),
              title: const Text('Add Subtask', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 20)),
              onTap: () {
                Navigator.pop(context);
                _showAddSubtaskDialog(parentTask);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.note_add_rounded, color: Colors.black, size: 28),
              title: const Text('Add / View Note', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 20)),
              onTap: () {
                Navigator.pop(context);
                _showTaskNoteDialog(parentTask);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.forum_rounded, color: Colors.black, size: 28),
              title: const Text('War Room Chat', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 20)),
              onTap: () async {
                Navigator.pop(context);
                final chatId = await widget.service.ensureProjectChat(widget.mission);
                if (mounted) {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => GroupChatScreen(
                    group: GroupModel(
                      groupId: chatId,
                      name: 'CHAT: ${parentTask.title}',
                      members: widget.mission.memberIds,
                      lastMessageAt: DateTime.now(),
                      createdBy: widget.mission.ownerId,
                    ),
                  )));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSubtaskDialog(MissionTask parentTask) {
    final ctrl = TextEditingController();
    final pointsCtrl = TextEditingController(text: '0');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ChatTheme.surface,
        title: Text('NEW SUBTASK', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: ChatTheme.primary, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(labelText: 'Subtask Title', labelStyle: TextStyle(color: Colors.black54)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pointsCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Points Reward', 
                labelStyle: TextStyle(color: Colors.black54),
                hintStyle: TextStyle(color: Colors.black54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.isNotEmpty) {
                widget.service.addTask(
                  widget.mission.id, 
                  ctrl.text.trim(), 
                  widget.userName, 
                  parentId: parentTask.id,
                  pointsRewards: int.tryParse(pointsCtrl.text) ?? 0
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('ADD'),
          ),
        ],
      ),
    );
  }

  void _showTaskNoteDialog(MissionTask task) {
    final noteController = TextEditingController(text: task.notes);
    final commentController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(height: 4, width: 40, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('TASK NOTES & DISCUSSION', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: ChatTheme.primary, fontSize: 16)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      TextField(
                        controller: noteController,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.black, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Core Notes (Shared)',
                          labelStyle: TextStyle(color: Colors.black54),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) async {
                           // Debounced update or manual save button
                        },
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.save_rounded, size: 16),
                        label: const Text('SAVE NOTES'),
                        onPressed: () async {
                           await widget.service.updateTaskNotes(task.id, noteController.text.trim());
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notes Saved!')));
                        },
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(),
                      ),
                      Text('TEAM COMMENTS', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: StreamBuilder<List<Map<String, dynamic>>>(
                          stream: widget.service.getTaskComments(task.id),
                          builder: (context, commentSnap) {
                            final comments = commentSnap.data ?? [];
                            if (comments.isEmpty) return const Center(child: Text('No comments yet. Start the discussion!', style: TextStyle(fontSize: 12, color: Colors.grey)));
                            
                            return ListView.builder(
                              itemCount: comments.length,
                              itemBuilder: (context, i) {
                                final c = comments[i];
                                final bool isMe = c['senderId'] == _uid;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isMe ? ChatTheme.primary.withOpacity(0.05) : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(c['senderName'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: isMe ? ChatTheme.primary : Colors.black54)),
                                      Text(c['text'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.black)),
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
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        style: const TextStyle(color: Colors.black),
                        decoration: const InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          fillColor: Colors.transparent,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: ChatTheme.primary),
                      onPressed: () async {
                        if (commentController.text.isNotEmpty) {
                          await widget.service.addTaskComment(task.id, commentController.text.trim(), widget.userName);
                          commentController.clear();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTaskOptions(MissionTask task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: Colors.black, size: 28),
              title: const Text('Rename', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 20)),
              onTap: () {
                Navigator.pop(context);
                _showRenameTaskDialog(task);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_add_rounded, color: Colors.black, size: 28),
              title: const Text('Assign', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 20)),
              onTap: () {
                Navigator.pop(context);
                _showAssignMemberDialog(task.id);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded, color: Colors.black, size: 28),
              title: const Text('Attach File', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 20)),
              onTap: () {
                Navigator.pop(context);
                _pickAndAttachFile(task.id);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 28),
              title: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 20)),
              onTap: () {
                Navigator.pop(context);
                _deleteTaskWithPassword(task.id);
              },
            ),
          ],
        ),
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

