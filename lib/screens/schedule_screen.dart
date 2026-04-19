import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/mission_model.dart';
import '../services/mission_service.dart';
import '../theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _service = MissionService();
  DateTime _selectedDate = DateTime.now();
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ChatTheme.primary,
        title: Text(
          'SMART SCHEDULER',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMorningBriefingBot(),
            const SizedBox(height: 24),
            _buildBigThreeSection(),
            const SizedBox(height: 24),
            _buildDailyBlockSchedule(),
            const SizedBox(height: 100), // Space for FAB or scrolling
          ],
        ),
      ),
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
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ready for takeoff?',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You have ${activeMissions.length} active missions today. '
                      '${bigThreeCount == 3 ? "Big 3 are set!" : "Only $bigThreeCount/3 of your Big 3 are ready."}',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
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
                color: Colors.white,
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ChatTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ChatTheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$startStr - $endStr',
                style: GoogleFonts.montserrat(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: ChatTheme.primary,
                ),
              ),
              GestureDetector(
                onTap: () => _service.updateTaskSchedule(task.id, null, null),
                child: const Icon(Icons.close_rounded, size: 14, color: ChatTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            task.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: ChatTheme.textPrimary,
            ),
          ),
        ],
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
                              title: Text(m.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              children: unscheduled.map((t) => ListTile(
                                title: Text(t.title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
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
