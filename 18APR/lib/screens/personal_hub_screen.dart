import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../services/database_service.dart';
import '../models/personal_models.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class PersonalHubScreen extends StatefulWidget {
  const PersonalHubScreen({super.key});

  @override
  State<PersonalHubScreen> createState() => _PersonalHubScreenState();
}

class _PersonalHubScreenState extends State<PersonalHubScreen> with SingleTickerProviderStateMixin {
  final LocalDatabaseService _db = LocalDatabaseService();
  late TabController _tabController;

  List<PersonalTask> _tasks = [];
  List<TaskGroup> _groups = [];
  String? _selectedGroupId; // null means 'Main List'
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    final tasks = await _db.getTasks();
    final groups = await _db.getTaskGroups();
    setState(() {
      _tasks = tasks;
      _groups = groups;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatTheme.background,
      appBar: AppBar(
        title: Text('PERSONAL HUB', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, letterSpacing: 2)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ChatTheme.primary,
        bottom: TabBar(
          controller: _tabController,
          labelColor: ChatTheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: ChatTheme.primary,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 10),
          tabs: const [
            Tab(text: 'TASKS', icon: Icon(Icons.playlist_add_check_rounded)),
            Tab(text: 'NOTES', icon: Icon(Icons.note_alt_rounded)),
            Tab(text: 'EXPENSES', icon: Icon(Icons.account_balance_wallet_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTasksTab(),
          _buildPlaceholderTab('PERSONAL NOTES', Icons.note_alt_rounded, Colors.amberAccent),
          _buildPlaceholderTab('EXPENSES MANAGER', Icons.account_balance_wallet_rounded, Colors.greenAccent),
        ],
      ),
    );
  }

  Widget _buildTasksTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    // Filter tasks by current group
    final filteredTasks = _tasks.where((t) => t.groupId == _selectedGroupId).toList();
    final activeTasks = filteredTasks.where((t) => !t.isCompleted).toList();
    final completedTasks = filteredTasks.where((t) => t.isCompleted).toList();

    return Column(
      children: [
        // Group Selector Line
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: ChatTheme.surface,
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<String?>(
                  value: _selectedGroupId,
                  isExpanded: true,
                  underline: const SizedBox(),
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: ChatTheme.textPrimary, fontSize: 14),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Main List')),
                    ..._groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.title))),
                  ],
                  onChanged: (val) => setState(() => _selectedGroupId = val),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.create_new_folder_rounded, color: ChatTheme.primary),
                tooltip: 'New Special Task Group',
                onPressed: _showCreateGroupDialog,
              ),
              if (_selectedGroupId != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: () async {
                    await _db.deleteTaskGroup(_selectedGroupId!);
                    setState(() => _selectedGroupId = null);
                    _loadAll();
                  },
                ),
            ],
          ),
        ),
        
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (filteredTasks.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.only(top: 40), child: Text('No tasks in this list yet.')))
              else ...[
                ...activeTasks.map((t) => _buildTaskTile(t)),
                if (completedTasks.isNotEmpty) ...[
                  const Divider(height: 32),
                  const Text('COMPLETED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  ...completedTasks.map((t) => _buildTaskTile(t)),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTaskTile(PersonalTask task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ChatTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
      ),
      child: ListTile(
        onTap: () => _showTaskDialog(task: task),
        leading: Checkbox(
          value: task.isCompleted,
          activeColor: ChatTheme.primary,
          onChanged: (val) async {
            await _db.updateTaskStatus(task.id, val ?? false);
            _loadAll();
          },
        ),
        title: Text(
          task.title,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 12, color: task.dueDate.isBefore(DateTime.now()) && !task.isCompleted ? Colors.redAccent : Colors.grey),
            const SizedBox(width: 4),
            Text(
              '${DateFormat('MMM dd').format(task.dueDate)} at ${DateFormat('hh:mm a').format(task.dueDate)}',
              style: TextStyle(fontSize: 11, color: task.dueDate.isBefore(DateTime.now()) && !task.isCompleted ? Colors.redAccent : Colors.grey),
            ),
            if (task.hasAlarm) ...[
              const SizedBox(width: 8),
              const Icon(Icons.alarm_on_rounded, size: 12, color: ChatTheme.primary),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
          onPressed: () async {
            await NotificationService().cancelTaskAlarm(task.id);
            await _db.deleteTask(task.id);
            _loadAll();
          },
        ),
      ),
    );
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

  void _showCreateGroupDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Special Task Group'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Group Title')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final group = TaskGroup(id: const Uuid().v4(), title: controller.text, createdAt: DateTime.now());
                await _db.saveTaskGroup(group);
                _loadAll();
                Navigator.pop(context);
              }
            },
            child: const Text('CREATE'),
          ),
        ],
      ),
    );
  }

  void _showTaskDialog({PersonalTask? task}) {
    final bool isEditing = task != null;
    final titleController = TextEditingController(text: task?.title ?? '');
    DateTime selectedDateTime = task?.dueDate ?? DateTime.now().add(const Duration(hours: 1));
    bool alarmEnabled = task?.hasAlarm ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(isEditing ? 'EDIT TASK' : 'NEW TASK', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: ChatTheme.primary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'What needs to be done?', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_rounded),
                  title: const Text('Set Date & Time', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: Text(DateFormat('EEEE, MMM dd - hh:mm a').format(selectedDateTime)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDateTime,
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(selectedDateTime));
                      if (time != null) {
                        setDialogState(() => selectedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                      }
                    }
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Alarm Needed?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Remind me with a ringtone', style: TextStyle(fontSize: 11)),
                  value: alarmEnabled,
                  onChanged: (val) => setDialogState(() => alarmEnabled = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ChatTheme.primary, foregroundColor: Colors.white),
              onPressed: () async {
                if (titleController.text.isNotEmpty) {
                  final taskToSave = PersonalTask(
                    id: isEditing ? task.id : const Uuid().v4(),
                    title: titleController.text,
                    dueDate: selectedDateTime,
                    createdAt: isEditing ? task.createdAt : DateTime.now(),
                    isCompleted: isEditing ? task.isCompleted : false,
                    hasAlarm: alarmEnabled,
                    alarmTime: alarmEnabled ? selectedDateTime : null,
                    groupId: _selectedGroupId,
                  );
                  await _db.saveTask(taskToSave);
                  
                  // Schedule/Cancel Alarm
                  if (alarmEnabled) {
                    await NotificationService().scheduleTaskAlarm(taskToSave.id, taskToSave.title, taskToSave.dueDate);
                  } else {
                    await NotificationService().cancelTaskAlarm(taskToSave.id);
                  }

                  _loadAll();
                  Navigator.pop(context);
                }
              },
              child: Text(isEditing ? 'UPDATE' : 'SAVE'),
            ),
          ],
        ),
      ),
    );
  }
}
