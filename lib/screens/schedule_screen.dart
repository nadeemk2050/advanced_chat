import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/mission_model.dart';
import '../services/mission_service.dart';
import '../theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

enum CalendarView { daily, weekly, monthly }

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _service = MissionService();
  DateTime _selectedDate = DateTime.now();
  CalendarView _currentView = CalendarView.daily;
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _currentUserName = 'User';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    if (_uid.isEmpty) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
    if (doc.exists) {
      setState(() => _currentUserName = doc.data()?['name'] ?? 'User');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(
              'SMART SCHEDULER',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1))),
                  child: const Icon(Icons.chevron_left_rounded, size: 22, color: Colors.black),
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('EEE, MMM d').format(_selectedDate).toUpperCase(),
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14, color: ChatTheme.primary),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1))),
                  child: const Icon(Icons.chevron_right_rounded, size: 22, color: Colors.black),
                ),
              ],
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<CalendarView>(
            icon: const Icon(Icons.grid_view_rounded),
            onSelected: (view) => setState(() => _currentView = view),
            itemBuilder: (context) => [
              const PopupMenuItem(value: CalendarView.daily, child: Text('Daily View')),
              const PopupMenuItem(value: CalendarView.weekly, child: Text('Weekly View')),
              const PopupMenuItem(value: CalendarView.monthly, child: Text('Monthly View')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            if (_currentView == CalendarView.daily) ...[
              _buildMorningBriefingBot(),
              const SizedBox(height: 24),
              _buildBigThreeSection(),
              const SizedBox(height: 24),
              _buildDailyBlockSchedule(),
            ] else if (_currentView == CalendarView.weekly) ...[
              _buildWeeklyView(),
            ] else if (_currentView == CalendarView.monthly) ...[
              _buildMonthlyView(),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('WEEKLY HORIZON', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black)),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.5),
          itemCount: 7,
          itemBuilder: (context, index) {
            final day = _selectedDate.add(Duration(days: index - _selectedDate.weekday + 1));
            final isToday = DateFormat('yMd').format(day) == DateFormat('yMd').format(DateTime.now());
            return GestureDetector(
              onTap: () => setState(() {
                _selectedDate = day;
                _currentView = CalendarView.daily;
              }),
              child: Column(
                children: [
                  Text(
                    DateFormat('E').format(day)[0],
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 13, color: isToday ? ChatTheme.primary : Colors.black),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 11, color: isToday ? ChatTheme.primary : Colors.black),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: StreamBuilder<List<MissionTask>>(
                      stream: _service.getScheduledTasksForDay(day),
                      builder: (context, snap) {
                        final tasks = snap.data ?? [];
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: tasks.isNotEmpty ? Colors.blue.withOpacity(0.08) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: isToday ? Border.all(color: ChatTheme.primary, width: 2) : Border.all(color: Colors.black12),
                          ),
                          child: Column(
                            children: tasks.take(8).map((t) => Container(
                              height: 10,
                              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                              decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(3)),
                            )).toList(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMonthlyView() {
    final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    final daysInMonth = lastDay.day;
    final startWeekday = firstDay.weekday;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MONTHLY CALENDAR', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black)),
        const SizedBox(height: 16),
        // Day of week headers
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 7,
          childAspectRatio: 2.5,
          children: ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'].map((d) => Center(
            child: Text(d, style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.black)),
          )).toList(),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.9),
          itemCount: daysInMonth + startWeekday - 1,
          itemBuilder: (context, index) {
            if (index < startWeekday - 1) return const SizedBox();
            final dayNum = index - startWeekday + 2;
            final day = DateTime(_selectedDate.year, _selectedDate.month, dayNum);
            final isToday = DateFormat('yMd').format(day) == DateFormat('yMd').format(DateTime.now());
            final dayAbbr = DateFormat('EEE').format(day).toUpperCase();
            return StreamBuilder<List<MissionTask>>(
              stream: _service.getScheduledTasksForDay(day),
              builder: (context, snap) {
                final tasks = snap.data ?? [];
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedDate = day;
                    _currentView = CalendarView.daily;
                  }),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isToday ? ChatTheme.primary.withOpacity(0.15) : (tasks.isNotEmpty ? Colors.orangeAccent.withOpacity(0.15) : Colors.white),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isToday ? ChatTheme.primary : Colors.black26, width: isToday ? 2 : 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayAbbr,
                          style: GoogleFonts.montserrat(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.black),
                        ),
                        Text(
                          '$dayNum',
                          style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black),
                        ),
                        if (tasks.isNotEmpty)
                          Container(width: 5, height: 5, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // ── MORNING BRIEFING BOT ──
  Widget _buildMorningBriefingBot() {
    return StreamBuilder<List<Mission>>(
      stream: _service.getMissions(),
      builder: (context, snap) {
        final missions = snap.data ?? [];
        final activeMissions = missions.where((m) => !m.isCompleted).toList();
        final bigThreeCount = activeMissions.where((m) => m.isBigThree).length;
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [ChatTheme.primary.withOpacity(0.8), ChatTheme.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: ChatTheme.primary.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white24,
                child: Text('🤖', style: TextStyle(fontSize: 32)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MORNING BRIEFING',
                      style: GoogleFonts.montserrat(
                        color: Colors.black54,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ready for takeoff?',
                      style: GoogleFonts.montserrat(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You have ${activeMissions.length} active missions today. '
                      '${bigThreeCount == 3 ? "Big 3 are set!" : "Only $bigThreeCount/3 of your Big 3 are ready."}',
                      style: GoogleFonts.montserrat(
                        color: Colors.black87,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── THE BIG 3 DAILY ──
  Widget _buildBigThreeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'THE BIG 3 DAILY',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: ChatTheme.primary,
                letterSpacing: 2,
              ),
            ),
            Text(
              'ELITE FOCUS',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                fontSize: 10,
                color: Colors.orangeAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Mission>>(
          stream: _service.getMissions(),
          builder: (context, snap) {
            final missions = snap.data ?? [];
            final bigThree = missions.where((m) => m.isBigThree && !m.isCompleted).toList();
            
            if (bigThree.isEmpty) {
              return _buildEmptyBigThree();
            }

            return Column(
              children: bigThree.map((m) => _buildBigThreeCard(m)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyBigThree() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ChatTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Icon(Icons.priority_high_rounded, color: Colors.grey, size: 32),
          const SizedBox(height: 12),
          Text(
            'NO BIG 3 SET YET',
            style: GoogleFonts.montserrat(
              color: ChatTheme.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Focus on the 3 critical missions that will move the needle today.',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              color: ChatTheme.textPrimary.withOpacity(0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBigThreeCard(Mission mission) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ChatTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Colors.orangeAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              mission.title.toUpperCase(),
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: Colors.black,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.grey, size: 20),
            onPressed: () => _service.toggleBigThree(mission.id, false),
          ),
        ],
      ),
    );
  }

  // ── DAILY BLOCK SCHEDULE (Timetable) ──
  Widget _buildDailyBlockSchedule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DAILY BLOCK SCHEDULE',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            color: ChatTheme.primary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<MissionTask>>(
          stream: _service.getScheduledTasksForDay(_selectedDate),
          builder: (context, snap) {
            final tasks = snap.data ?? [];
            
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 24,
              itemBuilder: (context, hour) {
                final hourTasks = tasks.where((t) => t.startTime!.hour == hour).toList();
                
                return IntrinsicHeight(
                  child: Row(
                    children: [
                      // Time side
                      SizedBox(
                        width: 50,
                        child: Column(
                          children: [
                            Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                              style: GoogleFonts.montserrat(
                                color: ChatTheme.textPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (hour != 23)
                              Expanded(
                                child: Container(
                                  width: 1,
                                  color: Colors.white10,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Task side
                      Expanded(
                        child: Column(
                          children: [
                            if (hourTasks.isEmpty)
                              _buildEmptyTimeSlot(hour)
                            else
                              ...hourTasks.map((t) => _buildScheduledTaskCard(t)),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyTimeSlot(int hour) {
    return GestureDetector(
      onTap: () => _showScheduleTaskPicker(hour),
      child: Container(
        height: 60,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10, style: BorderStyle.none),
        ),
        child: Center(
          child: Icon(Icons.add_rounded, color: Colors.white.withOpacity(0.1)),
        ),
      ),
    );
  }

  Widget _buildScheduledTaskCard(MissionTask task) {
    final startStr = DateFormat('HH:mm').format(task.startTime!);
    final endStr = task.endTime != null ? DateFormat('HH:mm').format(task.endTime!) : '--:--';
    
    return Container(
      constraints: const BoxConstraints(minHeight: 28), // Aiming for ultra-compact
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: ChatTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ChatTheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Checkbox(
            visualDensity: VisualDensity.compact,
            value: task.isCompleted,
            onChanged: (val) {
              _service.toggleTaskStatus(task.id, val ?? false, _currentUserName);
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      '$startStr-$endStr ',
                      style: GoogleFonts.montserrat(fontSize: 8, fontWeight: FontWeight.bold, color: ChatTheme.primary),
                    ),
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (task.notes != null && task.notes!.isNotEmpty)
                       GestureDetector(
                         onTap: () => _showEditTaskDialog(task),
                         child: const Icon(Icons.notes_rounded, color: Colors.blueAccent, size: 14),
                       ),
                    const SizedBox(width: 4),
                    if (task.pointsRewards > 0)
                      Text(
                         '${task.pointsRewards}P',
                         style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.orangeAccent),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.edit_note_rounded, size: 16, color: Colors.blueAccent),
            onPressed: () => _showEditTaskDialog(task),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _service.updateTaskSchedule(task.id, null, null),
            child: const Icon(Icons.close_rounded, size: 12, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  void _showEditTaskDialog(MissionTask task) {
    final titleCtrl = TextEditingController(text: task.title);
    final noteCtrl = TextEditingController(text: task.notes);
    final commentCtrl = TextEditingController();

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
                child: Text('EDIT TASK & DISCUSSION', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: ChatTheme.primary, fontSize: 16)),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      TextField(
                        controller: titleCtrl,
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(labelText: 'Task Title', border: OutlineInputBorder(), labelStyle: TextStyle(color: Colors.black54)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteCtrl,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.black),
                        decoration: const InputDecoration(labelText: 'Internal Notes', border: OutlineInputBorder(), labelStyle: TextStyle(color: Colors.black54)),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                          onPressed: () async {
                            await _service.renameTask(task.id, titleCtrl.text.trim());
                            await _service.updateTaskNotes(task.id, noteCtrl.text.trim());
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved!')));
                          },
                          child: const Text('SAVE TITLE & NOTES'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('BLOCK ADJUSTMENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(task.startTime!));
                                if (picked != null) {
                                  final newStart = DateTime(task.startTime!.year, task.startTime!.month, task.startTime!.day, picked.hour, picked.minute);
                                  _service.updateTaskSchedule(task.id, newStart, task.endTime);
                                }
                              },
                              child: const Text('START'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(task.endTime ?? task.startTime!.add(const Duration(hours: 1))));
                                if (picked != null) {
                                  final newEnd = DateTime(task.startTime!.year, task.startTime!.month, task.startTime!.day, picked.hour, picked.minute);
                                  _service.updateTaskSchedule(task.id, task.startTime, newEnd);
                                }
                              },
                              child: const Text('END'),
                            ),
                          ),
                        ],
                      ),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
                      Text('TEAM DISCUSSION', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _service.getTaskComments(task.id),
                        builder: (context, commentSnap) {
                          final comments = commentSnap.data ?? [];
                          if (comments.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Text('No comments yet.', style: TextStyle(fontSize: 12, color: Colors.grey)));
                          
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
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
                        controller: commentCtrl,
                        style: const TextStyle(color: Colors.black),
                        decoration: const InputDecoration(
                          hintText: 'Add a comment...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: ChatTheme.primary),
                      onPressed: () async {
                        if (commentCtrl.text.isNotEmpty) {
                          await _service.addTaskComment(task.id, commentCtrl.text.trim(), _currentUserName);
                          commentCtrl.clear();
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

  // ── PICKERS & DIALOGS ──

  void _showScheduleTaskPicker(int hour) {
    // Show a dialog to pick a task from any active mission to schedule it at this hour
    showModalBottomSheet(
      context: context,
      backgroundColor: ChatTheme.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) {
        return StreamBuilder<List<Mission>>(
          stream: _service.getMissions(),
          builder: (context, snap) {
            final missions = snap.data ?? [];
            final activeMissions = missions.where((m) => !m.isCompleted).toList();
            
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SCHEDULE FOR ${hour.toString().padLeft(2, '0')}:00',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 16, color: ChatTheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: activeMissions.length,
                      itemBuilder: (context, i) {
                        final m = activeMissions[i];
                        return StreamBuilder<List<MissionTask>>(
                          stream: _service.getMissionTasks(m.id),
                          builder: (context, taskSnap) {
                            final tasks = taskSnap.data ?? [];
                            final unscheduled = tasks.where((t) => t.startTime == null && !t.isCompleted).toList();
                            
                            if (unscheduled.isEmpty) return const SizedBox();
                            
                            return ExpansionTile(
                              title: Text(m.title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                              children: unscheduled.map((t) => ListTile(
                                title: Text(t.title, style: const TextStyle(color: Colors.black87, fontSize: 13)),
                                trailing: const Icon(Icons.add_circle_outline_rounded, color: ChatTheme.primary),
                                onTap: () async {
                                  final start = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay(hour: hour, minute: 0),
                                    helpText: 'SELECT START TIME (MINUTES ALLOWED)',
                                  );
                                  if (start == null) return;

                                  final end = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay(hour: start.hour + 1, minute: start.minute),
                                    helpText: 'SELECT END TIME',
                                  );
                                  if (end == null) return;

                                  final startTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, start.hour, start.minute);
                                  final endTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, end.hour, end.minute);
                                  
                                  _service.updateTaskSchedule(t.id, startTime, endTime);
                                  if (context.mounted) Navigator.pop(context);
                                },
                              )).toList(),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
