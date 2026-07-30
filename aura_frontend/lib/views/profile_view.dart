import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:aura_frontend/core/theme.dart';
import 'package:aura_frontend/providers/providers.dart';
import 'package:aura_frontend/models/models.dart';
import 'package:go_router/go_router.dart';

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final student = ref.read(authProvider);
      if (student != null) {
        ref.read(attendanceProvider.notifier).load(student.id);
      }
    });
  }

  double _calculateSemProgress(DateTime start, DateTime end) {
    final now = DateTime.now();
    if (now.isBefore(start)) return 0.0;
    if (now.isAfter(end)) return 1.0;
    final total = end.difference(start).inDays;
    final passed = now.difference(start).inDays;
    return total > 0 ? passed / total : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final student = ref.watch(authProvider);
    final attendance = ref.watch(attendanceProvider);

    if (student == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final overall = attendance?.overallPercentage ?? 100.0;
    final progress = _calculateSemProgress(student.semesterStart, student.semesterEnd);
    final daysRemaining = student.semesterEnd.difference(DateTime.now()).inDays;
    final target = student.attendanceTarget;

    // Deduplicate attendance subjects list for the graph
    final rawSubjects = attendance?.subjectsDetail ?? [];
    final subjectsMap = <String, SubjectAttendanceDetail>{};
    for (var s in rawSubjects) {
      subjectsMap[s.subjectName.trim().toLowerCase()] = s;
    }
    final subjects = subjectsMap.values.toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Redesigned Glassmorphic Header Card (Animated)
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: AuraTheme.glassDecoration(borderColor: AuraColors.primary),
                child: Column(
                  children: [
                    // Premium Avatar
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AuraColors.auroraGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AuraColors.primary.withOpacity(0.4),
                            blurRadius: 16,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        student.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 32,
                        ),
                      ),
                    ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
                    const SizedBox(height: 16),
                    // Name and University
                    Text(
                      student.name.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      student.university,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AuraColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Sem Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AuraColors.secondary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AuraColors.secondary.withOpacity(0.3)),
                      ),
                      child: Text(
                        'SEMESTER ${student.semester} • ${student.branch.toUpperCase()}',
                        style: const TextStyle(
                          color: AuraColors.secondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),

              const SizedBox(height: 20),

              // Statistics Cards Row (Health, Semester Ring, Streaks)
              Row(
                children: [
                  // Attendance health progress card
                  Expanded(
                    child: Container(
                      height: 140,
                      padding: const EdgeInsets.all(16.0),
                      decoration: AuraTheme.glassDecoration(borderColor: AuraColors.primary),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            overall >= target ? Icons.verified_user : Icons.gpp_maybe,
                            color: overall >= target ? AuraColors.present : AuraColors.absent,
                            size: 28,
                          ).animate().scale(duration: 300.ms),
                          const SizedBox(height: 10),
                          Text(
                            '${overall.toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Attendance Status',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, color: AuraColors.textMuted, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            overall >= target ? 'SAFE BUFFER' : 'AT RISK',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: overall >= target ? AuraColors.present : AuraColors.absent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Semester progress progress card
                  Expanded(
                    child: Container(
                      height: 140,
                      padding: const EdgeInsets.all(16.0),
                      decoration: AuraTheme.glassDecoration(borderColor: AuraColors.secondary),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 44,
                                height: 44,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 4,
                                  backgroundColor: Colors.white.withOpacity(0.05),
                                  color: AuraColors.secondary,
                                ),
                              ),
                              Text(
                                '${(progress * 100).round()}%',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${daysRemaining > 0 ? daysRemaining : 0} Days',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Semester Progress',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, color: AuraColors.textMuted, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 150.ms, duration: 400.ms).slideY(begin: 0.1),

              const SizedBox(height: 20),

              // Attendance Monitoring Graph Card
              Container(
                padding: const EdgeInsets.all(18.0),
                decoration: AuraTheme.glassDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.insights, color: AuraColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Attendance Analytics Summary',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'White line indicates your target requirement (${target.round()}%). Red represents critical subjects.',
                      style: const TextStyle(color: AuraColors.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 20),
                    subjects.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20.0),
                              child: Text(
                                'No subjects to monitor yet.',
                                style: TextStyle(color: AuraColors.textMuted, fontSize: 12),
                              ),
                            ),
                          )
                        : Column(
                            children: subjects.map((sub) {
                              final isCritical = sub.percentage < target;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          sub.subjectName,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          '${sub.percentage.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isCritical ? AuraColors.absent : AuraColors.present,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final targetFraction = target / 100.0;
                                        final fillFraction = sub.percentage / 100.0;
                                        
                                        final targetX = constraints.maxWidth * targetFraction;
                                        final fillWidth = constraints.maxWidth * (fillFraction > 1.0 ? 1.0 : fillFraction);

                                        return Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            // Background track
                                            Container(
                                              height: 12,
                                              width: constraints.maxWidth,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.04),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                            ),
                                            // Progress bar
                                            Container(
                                              height: 12,
                                              width: fillWidth > 0 ? fillWidth : 0,
                                              decoration: BoxDecoration(
                                                gradient: isCritical
                                                    ? const LinearGradient(colors: [AuraColors.absent, Colors.redAccent])
                                                    : AuraColors.auroraGradient,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                            ),
                                            // Target vertical line indicator
                                            Positioned(
                                              left: targetX,
                                              top: -3,
                                              bottom: -3,
                                              child: Container(
                                                width: 2,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    )
                                  ],
                                ),
                              );
                            }).toList(),
                          )
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1),

              const SizedBox(height: 20),

              // Student Info Card
              Container(
                padding: const EdgeInsets.all(18.0),
                decoration: AuraTheme.glassDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.badge_outlined, color: AuraColors.secondary, size: 20),
                        SizedBox(width: 8),
                        Text('Student Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Name', student.name),
                    _buildInfoRow('University', student.university),
                    _buildInfoRow('Branch', student.branch),
                    _buildInfoRow('Academic Year', '${student.year} Year'),
                    _buildInfoRow('Semester', 'Semester ${student.semester}'),
                    _buildInfoRow('Attendance Target', '${student.attendanceTarget.round()}%'),
                    _buildInfoRow('Daily Study Goal', '${student.dailyStudyGoalHours.toStringAsFixed(1)} hrs'),
                    if (student.careerGoal != null && student.careerGoal!.isNotEmpty)
                      _buildInfoRow('Career Path', student.careerGoal!),
                  ],
                ),
              ).animate().fadeIn(delay: 250.ms, duration: 400.ms).slideY(begin: 0.1),

              const SizedBox(height: 24),

              // Sign Out and Reset Options
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AuraTheme.glassDecoration(borderColor: AuraColors.absent),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AuraColors.absent.withOpacity(0.12),
                        foregroundColor: AuraColors.absent,
                        side: const BorderSide(color: AuraColors.absent, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        ref.read(authProvider.notifier).logout();
                        context.go('/login');
                      },
                      icon: const Icon(Icons.logout, size: 16),
                      label: const Text(
                        'SIGN OUT',
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.04),
                        foregroundColor: AuraColors.textMuted,
                        side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        ref.read(authProvider.notifier).logout();
                        context.go('/onboarding');
                      },
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text(
                        'RESET ACADEMIC PROFILE',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.1),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: AuraColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
