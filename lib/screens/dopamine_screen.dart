import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/mission_model.dart';
import '../services/mission_service.dart';
import '../theme/app_theme.dart';

/// The Dopamine Loop screen — Heatmap, Elite Status & Trophy Room.
class DopamineScreen extends StatefulWidget {
  const DopamineScreen({super.key});

  @override
  State<DopamineScreen> createState() => _DopamineScreenState();
}

class _DopamineScreenState extends State<DopamineScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _missionService = MissionService();
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ChatTheme.primary,
        title: Text(
          'DOPAMINE LAB',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tab,
          labelColor: ChatTheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: ChatTheme.primary,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold, fontSize: 10),
          tabs: const [
            Tab(text: 'ELITE STATUS', icon: Icon(Icons.local_fire_department_rounded)),
            Tab(text: 'TROPHY ROOM', icon: Icon(Icons.emoji_events_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _EliteStatusTab(uid: _uid, service: _missionService),
          _TrophyRoomTab(uid: _uid, service: _missionService),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// TAB 1 — ELITE STATUS (Productivity Heatmap)
// ─────────────────────────────────────────────────────────
class _EliteStatusTab extends StatelessWidget {
  final String uid;
  final MissionService service;
  const _EliteStatusTab({required this.uid, required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Mission>>(
      stream: service.getMissions(),
      builder: (context, snap) {
        final missions = snap.data ?? [];

        // Compute stats
        final total = missions.length;
        int completed = 0;
        int teamMissions = 0;
        int tasks = 0;
        int approvedTasks = 0;

        for (final m in missions) {
          if (m.isCompleted) completed++;
          if (m.type == MissionType.teamMission ||
              m.type == MissionType.teamTask) teamMissions++;
        }

        // Elite score formula
        final completionRate =
            total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
        final eliteScore =
            ((completionRate * 60) + (teamMissions * 5)).clamp(0, 100).toInt();

        final rank = _getRank(eliteScore);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Rank Banner ──
              _RankBanner(rank: rank, score: eliteScore),
              const SizedBox(height: 24),

              // ── Stats Row ──
              Row(
                children: [
                  Expanded(child: _StatCard('📋', 'MISSIONS', '$total', Colors.blueAccent)),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard('✅', 'DONE', '$completed', Colors.greenAccent)),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard('🤝', 'TEAM', '$teamMissions', Colors.purpleAccent)),
                ],
              ),
              const SizedBox(height: 24),

              // ── Productivity Heatmap ──
              _HeatmapGrid(missions: missions),
              const SizedBox(height: 24),

              // ── Progress Bar ──
              _ProgressToNextRank(score: eliteScore),
            ],
          ),
        );
      },
    );
  }

  static _Rank _getRank(int score) {
    if (score >= 90) return _Rank('⚡ LEGEND', const Color(0xFFFFD700), 'TOP 1%');
    if (score >= 75) return _Rank('🔥 ELITE', const Color(0xFFFF6B35), 'TOP 5%');
    if (score >= 55) return _Rank('💎 DIAMOND', const Color(0xFF00D4FF), 'TOP 15%');
    if (score >= 35) return _Rank('🥇 GOLD', const Color(0xFFFFC107), 'TOP 30%');
    if (score >= 20) return _Rank('🥈 SILVER', const Color(0xFFB0BEC5), 'TOP 50%');
    return _Rank('🥉 BRONZE', const Color(0xFFCD7F32), 'RISING');
  }
}

class _Rank {
  final String label;
  final Color color;
  final String tier;
  const _Rank(this.label, this.color, this.tier);
}

class _RankBanner extends StatefulWidget {
  final _Rank rank;
  final int score;
  const _RankBanner({required this.rank, required this.score});

  @override
  State<_RankBanner> createState() => _RankBannerState();
}

class _RankBannerState extends State<_RankBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _glow = Tween<double>(begin: 8, end: 24).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, __) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              widget.rank.color.withOpacity(0.15),
              ChatTheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: widget.rank.color, width: 2),
          boxShadow: [
            BoxShadow(
              color: widget.rank.color.withOpacity(0.4),
              blurRadius: _glow.value,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              widget.rank.label,
              style: GoogleFonts.montserrat(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: widget.rank.color,
                letterSpacing: 2,
              ),
            ),
            Text(
              widget.rank.tier,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white54,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 16),
            Stack(
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: (widget.score / 100).clamp(0.0, 1.0),
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [widget.rank.color.withOpacity(0.7), widget.rank.color],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'ELITE SCORE: ${widget.score}/100',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: widget.rank.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard(this.icon, this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ChatTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.montserrat(
                fontSize: 22, fontWeight: FontWeight.w900, color: color),
          ),
          Text(
            label,
            style: GoogleFonts.montserrat(
                fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}

// ── Productivity Heatmap ──
class _HeatmapGrid extends StatelessWidget {
  final List<Mission> missions;
  const _HeatmapGrid({required this.missions});

  @override
  Widget build(BuildContext context) {
    // Build a 7×7 grid representing last 49 days
    final now = DateTime.now();
    final dayMap = <int, int>{}; // dayOffset -> activity score
    for (final m in missions) {
      final diff = now.difference(m.createdAt).inDays;
      if (diff < 49) {
        dayMap[diff] = (dayMap[diff] ?? 0) + 1;
        if (m.isCompleted) dayMap[diff] = (dayMap[diff] ?? 0) + 2;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ACTIVITY HEATMAP (LAST 49 DAYS)',
          style: GoogleFonts.montserrat(
              fontSize: 11, fontWeight: FontWeight.w900,
              color: ChatTheme.primary, letterSpacing: 2),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 1,
          ),
          itemCount: 49,
          itemBuilder: (_, i) {
            final score = dayMap[i] ?? 0;
            final opacity = score == 0
                ? 0.05
                : score == 1
                    ? 0.3
                    : score <= 3
                        ? 0.6
                        : 1.0;
            final dayDate =
                now.subtract(Duration(days: 48 - i));
            return Tooltip(
              message:
                  '${_monthName(dayDate.month)} ${dayDate.day}: $score activities',
              child: Container(
                decoration: BoxDecoration(
                  color: ChatTheme.primary.withOpacity(opacity),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Less',
                style: GoogleFonts.montserrat(
                    fontSize: 9, color: Colors.grey)),
            const SizedBox(width: 6),
            for (final o in [0.05, 0.25, 0.5, 0.75, 1.0])
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(left: 3),
                decoration: BoxDecoration(
                  color: ChatTheme.primary.withOpacity(o),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            const SizedBox(width: 6),
            Text('More',
                style: GoogleFonts.montserrat(
                    fontSize: 9, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  String _monthName(int m) {
    const names = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[m.clamp(1, 12)];
  }
}

class _ProgressToNextRank extends StatelessWidget {
  final int score;
  const _ProgressToNextRank({required this.score});

  @override
  Widget build(BuildContext context) {
    final thresholds = [0, 20, 35, 55, 75, 90, 100];
    final nextIdx = thresholds.indexWhere((t) => t > score);
    if (nextIdx < 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFD700)),
        ),
        child: Text(
          '⚡ MAXIMUM LEGEND STATUS ACHIEVED',
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFFFD700),
          ),
        ),
      );
    }
    final nextThresh = thresholds[nextIdx];
    final prevThresh = thresholds[nextIdx - 1];
    final progress = (score - prevThresh) / (nextThresh - prevThresh);
    final needed = nextThresh - score;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ChatTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEXT RANK IN $needed POINTS',
            style: GoogleFonts.montserrat(
                fontSize: 11, fontWeight: FontWeight.bold,
                color: Colors.grey, letterSpacing: 2),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.white10,
              color: ChatTheme.primary,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Complete missions and collaborate with your team to climb the ranks!',
            style: GoogleFonts.montserrat(
                fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// TAB 2 — TROPHY ROOM (Success Vault)
// ─────────────────────────────────────────────────────────
class _TrophyRoomTab extends StatelessWidget {
  final String uid;
  final MissionService service;
  const _TrophyRoomTab({required this.uid, required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Mission>>(
      stream: service.getMissions(),
      builder: (context, snap) {
        final all = snap.data ?? [];
        final completed = all.where((m) => m.isCompleted).toList()
          ..sort((a, b) =>
              (b.completedAt ?? DateTime(0)).compareTo(a.completedAt ?? DateTime(0)));

        if (completed.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events_rounded,
                    size: 90, color: ChatTheme.primary.withOpacity(0.15)),
                const SizedBox(height: 20),
                Text(
                  'THE VAULT IS EMPTY',
                  style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w900,
                      color: Colors.grey,
                      letterSpacing: 3),
                ),
                const SizedBox(height: 8),
                Text(
                  'Approve your first mission to earn a trophy.',
                  style: GoogleFonts.montserrat(
                      fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Row(
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Text(
                      '${completed.length} VICTORIES ARCHIVED',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: ChatTheme.primary,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _TrophyCard(mission: completed[i], index: i),
                  childCount: completed.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TrophyCard extends StatefulWidget {
  final Mission mission;
  final int index;
  const _TrophyCard({required this.mission, required this.index});

  @override
  State<_TrophyCard> createState() => _TrophyCardState();
}

class _TrophyCardState extends State<_TrophyCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmer;
  late Animation<double> _shimmerAnim;

  static const _trophyEmojis = ['🏆', '🥇', '🎯', '🌟', '💎', '🚀'];
  static const _gradients = [
    [Color(0xFFFFD700), Color(0xFFFFA000)],
    [Color(0xFF9B59B6), Color(0xFF6C3483)],
    [Color(0xFF1ABC9C), Color(0xFF148F77)],
    [Color(0xFFE74C3C), Color(0xFF922B21)],
    [Color(0xFF3498DB), Color(0xFF1A5276)],
    [Color(0xFF27AE60), Color(0xFF1D8348)],
  ];

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _shimmerAnim =
        Tween<double>(begin: -1, end: 2).animate(_shimmer);
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gi = widget.index % _gradients.length;
    final g = _gradients[gi];
    final emoji = _trophyEmojis[widget.index % _trophyEmojis.length];
    final completedOn = widget.mission.completedAt;
    final dateStr = completedOn != null
        ? '${completedOn.day}/${completedOn.month}/${completedOn.year}'
        : 'Archived';
    final typeLabel = widget.mission.type.name
        .replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m.group(0)}')
        .toUpperCase()
        .trim();

    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              g[0].withOpacity(0.9),
              g[1].withOpacity(0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: g[0].withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 32)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'COMPLETE',
                    style: GoogleFonts.montserrat(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              widget.mission.title.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              typeLabel,
              style: GoogleFonts.montserrat(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                  letterSpacing: 1),
            ),
            const SizedBox(height: 2),
            Text(
              '📅 $dateStr',
              style: GoogleFonts.montserrat(
                  fontSize: 9, color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}
