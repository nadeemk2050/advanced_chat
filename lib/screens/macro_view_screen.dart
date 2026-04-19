import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/mission_service.dart';
import '../models/mission_model.dart';
import '../theme/app_theme.dart';

class MacroViewScreen extends StatefulWidget {
  const MacroViewScreen({super.key});

  @override
  State<MacroViewScreen> createState() => _MacroViewScreenState();
}

class _MacroViewScreenState extends State<MacroViewScreen> {
  final MissionService _missionService = MissionService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatTheme.background,
      appBar: AppBar(
        title: Text('MACRO VIEW', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('LOAD BALANCING', Icons.monitor_heart_rounded),
              const SizedBox(height: 16),
              _buildWorkloadDashboard(),
              const SizedBox(height: 40),
              _buildSectionHeader('LEGACY MISSIONS', Icons.history_rounded),
              const SizedBox(height: 16),
              _buildLegacyList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: ChatTheme.primary, size: 20),
        const SizedBox(width: 12),
        Text(title, style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2, color: Colors.white70)),
      ],
    );
  }

  Widget _buildWorkloadDashboard() {
    return StreamBuilder<Map<String, int>>(
      stream: _missionService.getTeamWorkload(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        if (data.isEmpty) return _buildEmptyState('No active tasks found in team missions.');

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ChatTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: data.entries.map((e) {
              final isOverloaded = e.value > 5;
              final color = isOverloaded ? Colors.redAccent : Colors.greenAccent;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('${e.value} TASKS', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (e.value / 10).clamp(0, 1),
                      backgroundColor: Colors.white10,
                      color: color,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    if (isOverloaded)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('⚠️ OVERLOADED', style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildLegacyList() {
    return StreamBuilder<List<Mission>>(
      stream: _missionService.getLegacyMissions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final missions = snapshot.data!;
        if (missions.isEmpty) return _buildEmptyState('No completed missions in the vault yet.');

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: missions.length,
          itemBuilder: (context, i) {
            final m = missions[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ChatTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ChatTheme.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Colors.amberAccent, size: 30),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('SUCCESSFULLY VETTER BY ${m.memberIds.length} AGENTS', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: ChatTheme.surface, borderRadius: BorderRadius.circular(24)),
      child: Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white30, fontSize: 12)),
    );
  }
}
