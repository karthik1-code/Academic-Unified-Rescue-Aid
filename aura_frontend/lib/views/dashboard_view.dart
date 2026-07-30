import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_frontend/core/theme.dart';
import 'package:aura_frontend/providers/providers.dart';
import 'package:aura_frontend/models/models.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'dart:math' as math;
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({Key? key}) : super(key: key);

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final student = ref.read(authProvider);
      if (student != null) {
        ref.read(attendanceProvider.notifier).load(student.id);
        ref.read(goalsProvider.notifier).load(student.id);
        ref.read(syllabusProvider.notifier).load(student.id);
        ref.read(tasksProvider.notifier).load(student.id);
        ref.read(examsProvider.notifier).listenToStream(student.id);
        ref.read(assignmentsProvider.notifier).listenToStream(student.id);
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

  Widget _buildProfileStat({required String label, required String val}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: AuraColors.textMuted, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        const SizedBox(height: 3),
        Text(
          val,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = ref.watch(authProvider);
    final attendance = ref.watch(attendanceProvider);
    final goals = ref.watch(goalsProvider);
    final syllabus = ref.watch(syllabusProvider);
    final tasks = ref.watch(tasksProvider);
    final exams = ref.watch(examsProvider);
    final assignments = ref.watch(assignmentsProvider);

    if (student == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final progress = _calculateSemProgress(student.semesterStart, student.semesterEnd);
    final daysRemaining = student.semesterEnd.difference(DateTime.now()).inDays;

    // Filter daily goals
    final dailyGoals = goals.where((g) => g.timeframe == 'daily').toList();
    final completedDaily = dailyGoals.where((g) => g.status == 'completed').length;

    // Calculate syllabus progress percentages per subject
    final Map<String, double> syllabusProgressMap = {};
    for (var subjectSyllabus in syllabus) {
      final totalUnits = subjectSyllabus.units.length;
      if (totalUnits > 0) {
        final completedUnits = subjectSyllabus.units.where((u) => u.status == 'completed').length;
        syllabusProgressMap[subjectSyllabus.subjectName.toLowerCase().trim()] = (completedUnits / totalUnits) * 100.0;
      } else {
        syllabusProgressMap[subjectSyllabus.subjectName.toLowerCase().trim()] = 0.0;
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    const _AuraLogoHeader(),
                    // Current date chip
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Text(
                          '${DateTime.now().day} ${_getMonthName(DateTime.now().month)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AuraColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Premium Glassmorphic Student Card
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AuraColors.primary.withOpacity(0.15)),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.04),
                      Colors.white.withOpacity(0.01),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AuraColors.primary.withOpacity(0.03),
                      blurRadius: 16,
                      spreadRadius: 2,
                    )
                  ]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AuraColors.auroraGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AuraColors.primary.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            student.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student.name.toUpperCase(),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                student.university,
                                style: const TextStyle(color: AuraColors.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AuraColors.secondary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AuraColors.secondary.withOpacity(0.3)),
                          ),
                          child: Text(
                            'SEM ${student.semester}',
                            style: const TextStyle(color: AuraColors.secondary, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildProfileStat(label: 'BRANCH', val: student.branch),
                        _buildProfileStat(label: 'YEAR', val: student.year),
                        _buildProfileStat(label: 'DAILY GOAL', val: '${student.dailyStudyGoalHours.round()} hrs'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Quick Actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AuraColors.primary.withOpacity(0.08),
                        foregroundColor: AuraColors.primary,
                        side: BorderSide(color: AuraColors.primary.withOpacity(0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => context.go('/todo'),
                      icon: const Icon(Icons.playlist_add_check, size: 18),
                      label: const Text('To-Do & Tasks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              if (syllabus.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: AuraTheme.glassDecoration(borderColor: AuraColors.accent),
                  child: Column(
                    children: [
                      const Icon(Icons.school_outlined, size: 40, color: AuraColors.accent),
                      const SizedBox(height: 12),
                      const Text(
                        'Initialize Academic OS',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Please complete onboarding to register your courses, syllabus progress trackers, and activate the AI features.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: AuraColors.textMuted),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AuraColors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => context.go('/onboarding'),
                        child: const Text('Start Onboarding Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Semester Progress Timeline
              Container(
                padding: const EdgeInsets.all(18.0),
                decoration: AuraTheme.glassDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Semester Progress',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          '${(progress * 100).round()}% Completed • ${daysRemaining > 0 ? daysRemaining : 0} days left',
                          style: const TextStyle(color: AuraColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        children: [
                          Container(
                            height: 10,
                            color: Colors.white.withOpacity(0.05),
                          ),
                          FractionallySizedBox(
                            widthFactor: progress,
                            child: Container(
                              height: 10,
                              decoration: const BoxDecoration(
                                gradient: AuraColors.auroraGradient,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${student.semesterStart.day}/${student.semesterStart.month}/${student.semesterStart.year}',
                          style: const TextStyle(fontSize: 10, color: AuraColors.textMuted),
                        ),
                        Text(
                          '${student.semesterEnd.day}/${student.semesterEnd.month}/${student.semesterEnd.year}',
                          style: const TextStyle(fontSize: 10, color: AuraColors.textMuted),
                        ),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Attendance Stats Sphere (Visual Wonder & Interactive Rotate)
              _VisualWonderAttendanceSphere(
                attendance: attendance,
                student: student,
              ),
              const SizedBox(height: 20),

              // High Priority Tasks Panel
              Container(
                padding: const EdgeInsets.all(18.0),
                decoration: AuraTheme.glassDecoration(
                  borderColor: AuraColors.secondary.withOpacity(0.3),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.check_circle_outline, color: AuraColors.secondary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'PRIORITY TASK LIST',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AuraColors.secondary,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => context.go('/todo'),
                          child: const Text(
                            'View All',
                            style: TextStyle(fontSize: 11, color: AuraColors.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (tasks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          'No pending priority tasks! Visit Task Planner to add tasks.',
                          style: TextStyle(color: AuraColors.textMuted, fontSize: 12),
                        ),
                      )
                    else ...[
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: tasks.take(3).length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          final isCompleted = task.isCompleted;
                          return AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: isCompleted ? 0.6 : 1.0,
                            child: Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color: Colors.white.withOpacity(0.02),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: isCompleted ? Colors.transparent : AuraColors.secondary.withOpacity(0.1),
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                leading: Checkbox(
                                  activeColor: AuraColors.secondary,
                                  value: isCompleted,
                                  onChanged: (val) {
                                    ref.read(tasksProvider.notifier).toggle(task.id, student.id);
                                  },
                                ),
                                title: Text(
                                  task.title,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                                    color: isCompleted ? AuraColors.textMuted : Colors.white,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AuraColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    task.category,
                                    style: const TextStyle(fontSize: 9, color: AuraColors.primary, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Goals Quick Checklist
              Container(
                padding: const EdgeInsets.all(18.0),
                decoration: AuraTheme.glassDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Daily Goal Progress',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          '$completedDaily/${dailyGoals.length} Done',
                          style: const TextStyle(color: AuraColors.secondary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    dailyGoals.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'No daily goals added. Go to Profile tab to add goals.',
                              style: TextStyle(color: AuraColors.textMuted, fontSize: 12),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: dailyGoals.length,
                            itemBuilder: (context, index) {
                              final goal = dailyGoals[index];
                              final isCompleted = goal.status == 'completed';
                              return CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                activeColor: AuraColors.primary,
                                value: isCompleted,
                                dense: true,
                                title: Text(
                                  goal.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                                    color: isCompleted ? AuraColors.textMuted : Colors.white,
                                  ),
                                ),
                                onChanged: (_) {
                                  ref.read(goalsProvider.notifier).toggle(goal.id, student.id);
                                },
                              );
                            },
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ─── Upcoming Exams Widget ───
              _buildUpcomingExamsWidget(exams, context),
              const SizedBox(height: 20),

              // ─── Upcoming Assignments Widget ───
              _buildUpcomingAssignmentsWidget(assignments, context),
              const SizedBox(height: 20),

              // Progress Graph Card replaced with Animated Sync Core
              if (syllabus.isNotEmpty) ...[
                _AuraCoreAcademicNode(
                  syllabusCount: syllabus.length,
                  overallAttendance: attendance?.overallPercentage ?? 100.0,
                ),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingExamsWidget(List<Exam> exams, BuildContext context) {
    final now = DateTime.now();
    final upcoming = exams.where((e) => e.date.isAfter(now)).toList();

    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: AuraTheme.glassDecoration(
        borderColor: AuraColors.primary.withOpacity(0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.school_outlined, color: AuraColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'UPCOMING EXAMS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AuraColors.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => context.go('/exams'),
                child: const Text(
                  'View All',
                  style: TextStyle(fontSize: 11, color: AuraColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (upcoming.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                'No upcoming exams scheduled!',
                style: TextStyle(color: AuraColors.textMuted, fontSize: 12),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: upcoming.take(2).length,
              itemBuilder: (context, index) {
                final exam = upcoming[index];
                final daysLeft = exam.date.difference(now).inDays;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: Colors.white.withOpacity(0.02),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: AuraColors.primary.withOpacity(0.1),
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    title: Text(
                      exam.name,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      exam.subject,
                      style: const TextStyle(fontSize: 10.5, color: AuraColors.textMuted),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AuraColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AuraColors.primary.withOpacity(0.3)),
                      ),
                      child: Text(
                        daysLeft == 0
                            ? 'TODAY'
                            : daysLeft == 1
                                ? 'TOMORROW'
                                : '$daysLeft days left',
                        style: const TextStyle(
                          fontSize: 9,
                          color: AuraColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAssignmentsWidget(List<Assignment> assignments, BuildContext context) {
    final now = DateTime.now();
    final pending = assignments.where((a) => !a.isSubmitted).toList();

    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: AuraTheme.glassDecoration(
        borderColor: AuraColors.secondary.withOpacity(0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.assignment_outlined, color: AuraColors.secondary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'PENDING ASSIGNMENTS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AuraColors.secondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => context.go('/assignments'),
                child: const Text(
                  'View All',
                  style: TextStyle(fontSize: 11, color: AuraColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (pending.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                'No pending assignments!',
                style: TextStyle(color: AuraColors.textMuted, fontSize: 12),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pending.take(2).length,
              itemBuilder: (context, index) {
                final assignment = pending[index];
                final daysLeft = assignment.daysUntilDue;
                Color urgencyColor = daysLeft <= 1 ? AuraColors.absent : AuraColors.leave;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: Colors.white.withOpacity(0.02),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: AuraColors.secondary.withOpacity(0.1),
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    title: Text(
                      assignment.title,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      assignment.subject,
                      style: const TextStyle(fontSize: 10.5, color: AuraColors.textMuted),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: urgencyColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: urgencyColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        daysLeft < 0
                            ? 'OVERDUE'
                            : daysLeft == 0
                                ? 'TODAY'
                                : daysLeft == 1
                                    ? 'TOMORROW'
                                    : '$daysLeft days left',
                        style: TextStyle(
                          fontSize: 9,
                          color: urgencyColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _AuraCoreAcademicNode extends StatefulWidget {
  final int syllabusCount;
  final double overallAttendance;
  const _AuraCoreAcademicNode({
    required this.syllabusCount,
    required this.overallAttendance,
  });

  @override
  State<_AuraCoreAcademicNode> createState() => _AuraCoreAcademicNodeState();
}

class _AuraCoreAcademicNodeState extends State<_AuraCoreAcademicNode> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AuraTheme.glassDecoration(
        borderColor: AuraColors.primary.withOpacity(0.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.greenAccent,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent,
                      blurRadius: 8,
                      spreadRadius: 2,
                    )
                  ]
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'AURA CORE SYSTEM SYNC',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AuraColors.primary,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Rotating & Pulsing Neural Core
              SizedBox(
                width: 90,
                height: 90,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _AuraCorePainter(
                        animationValue: _controller.value,
                        attendanceFactor: widget.overallAttendance / 100.0,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 20),
              // Dynamic Stats Panel
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Syllabus & Performance Synced',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Indexing ${widget.syllabusCount} courses with local storage and database cache.',
                      style: const TextStyle(fontSize: 11, color: AuraColors.textMuted, height: 1.3),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildStatusChip('CLOUD SHIELD ACTIVE', Colors.blueAccent),
                        const SizedBox(width: 8),
                        _buildStatusChip('AI ENGINE ONLINE', AuraColors.primary),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _AuraCorePainter extends CustomPainter {
  final double animationValue;
  final double attendanceFactor;
  _AuraCorePainter({required this.animationValue, required this.attendanceFactor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;

    // Background glow
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AuraColors.primary.withOpacity(0.25),
          AuraColors.secondary.withOpacity(0.05),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxRadius, bgPaint);

    final angleOffset = animationValue * 2 * math.pi;

    // Draw orbits
    final orbitPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, maxRadius * 0.7, orbitPaint);
    canvas.drawCircle(center, maxRadius * 0.4, orbitPaint);

    // Draw connecting neural lines
    final linePaint = Paint()
      ..color = AuraColors.primary.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final int nodeCount = 6;
    final List<Offset> nodes = [];

    // Calculate node coordinates on the outer orbit
    for (int i = 0; i < nodeCount; i++) {
      final double angle = (i * 2 * math.pi / nodeCount) + angleOffset;
      final double pulse = 1.0 + 0.1 * math.sin(angleOffset * 3 + i);
      final double radius = maxRadius * 0.7 * pulse;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      nodes.add(Offset(x, y));
    }

    // Connect nodes
    for (int i = 0; i < nodeCount; i++) {
      canvas.drawLine(nodes[i], nodes[(i + 1) % nodeCount], linePaint);
      canvas.drawLine(center, nodes[i], linePaint);
    }

    // Draw outer nodes (glowing dots)
    final nodePaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < nodeCount; i++) {
      final isAccent = i % 2 == 0;
      nodePaint.color = isAccent ? AuraColors.primary : AuraColors.secondary;
      canvas.drawCircle(nodes[i], 4.0, nodePaint);
      canvas.drawCircle(
        nodes[i],
        8.0 + 4 * math.sin(angleOffset * 4 + i),
        Paint()
          ..color = (isAccent ? AuraColors.primary : AuraColors.secondary).withOpacity(0.3)
          ..style = PaintingStyle.fill,
      );
    }

    // Draw pulsing inner core
    final coreRadius = maxRadius * 0.3 * (1.0 + 0.15 * math.sin(angleOffset * 5));
    final corePaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Colors.white,
          AuraColors.primary,
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: coreRadius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, coreRadius, corePaint);

    // Draw rotating particle dots
    final particlePaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 3; i++) {
      final double pAngle = angleOffset * -1.8 + (i * 2 * math.pi / 3);
      final px = center.dx + maxRadius * 0.4 * math.cos(pAngle);
      final py = center.dy + maxRadius * 0.4 * math.sin(pAngle);
      canvas.drawCircle(Offset(px, py), 2.5, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class LiquidCircularProgressIndicator extends StatefulWidget {
  final double value;
  final double size;
  final Color color;
  final Widget? center;

  const LiquidCircularProgressIndicator({
    Key? key,
    required this.value,
    this.size = 80,
    required this.color,
    this.center,
  }) : super(key: key);

  @override
  State<LiquidCircularProgressIndicator> createState() => _LiquidCircularProgressIndicatorState();
}

class _LiquidCircularProgressIndicatorState extends State<LiquidCircularProgressIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _LiquidPainter(
                  value: widget.value,
                  phase: _controller.value * 2 * math.pi,
                  color: widget.color,
                  amplitude: 4.0,
                ),
              ),
              if (widget.center != null) widget.center!,
            ],
          ),
        );
      },
    );
  }
}

class _LiquidPainter extends CustomPainter {
  final double value;
  final double phase;
  final Color color;
  final double amplitude;

  _LiquidPainter({
    required this.value,
    required this.phase,
    required this.color,
    required this.amplitude,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final clipPath = Path()..addOval(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.clipPath(clipPath);

    // Draw background
    final bgPaint = Paint()..color = Colors.white.withOpacity(0.04);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Border line
    final borderPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawOval(Rect.fromLTWH(1.5, 1.5, size.width - 3, size.height - 3), borderPaint);

    // Clamp value
    final double clampedVal = value.clamp(0.0, 1.0);
    final waterLevelHeight = (1.0 - clampedVal) * size.height;

    // Draw wave path
    final wavePath = Path();
    wavePath.moveTo(0, waterLevelHeight);

    final waveFrequency = (2 * math.pi) / size.width;

    for (double x = 0; x <= size.width; x++) {
      final y = waterLevelHeight + amplitude * math.sin(x * waveFrequency + phase);
      wavePath.lineTo(x, y);
    }

    wavePath.lineTo(size.width, size.height);
    wavePath.lineTo(0, size.height);
    wavePath.close();

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(0.85), color.withOpacity(0.5)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, waterLevelHeight - amplitude, size.width, size.height));

    canvas.drawPath(wavePath, paint);
  }

  @override
  bool shouldRepaint(covariant _LiquidPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.phase != phase ||
        oldDelegate.color != color ||
        oldDelegate.amplitude != amplitude;
  }
}

class _AuraLogoHeader extends StatefulWidget {
  const _AuraLogoHeader({Key? key}) : super(key: key);

  @override
  State<_AuraLogoHeader> createState() => _AuraLogoHeaderState();
}

class _AuraLogoHeaderState extends State<_AuraLogoHeader> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        setState(() => _isExpanded = !_isExpanded);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AuraColors.auroraGradient,
                boxShadow: [
                  BoxShadow(
                    color: AuraColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: const Icon(
                Icons.psychology,
                color: Colors.white,
                size: 20,
              ),
            ).animate(onPlay: (controller) => controller.repeat()).shimmer(duration: 1500.ms),
            const SizedBox(width: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildLetter('A', 'cademic'),
                const SizedBox(width: 2),
                _buildLetter('U', 'nified'),
                const SizedBox(width: 2),
                _buildLetter('R', 'escue'),
                const SizedBox(width: 2),
                _buildLetter('A', 'id'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLetter(String first, String remaining) {
    return ShaderMask(
      shaderCallback: (bounds) => AuraColors.auroraGradient.createShader(bounds),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            first,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _isExpanded ? 1.0 : 0.0,
                child: SizedBox(
                  width: _isExpanded ? null : 0.0,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 1.0, right: 3.0),
                    child: Text(
                      remaining,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ATTENDANCE STAT CARD — clean glass-style, project-consistent
// ─────────────────────────────────────────────────────────────────────────────
class _AttendanceStatCard extends StatefulWidget {
  final String label;
  final String value;
  final String subtitle;
  final double percentage;
  final double targetFraction;
  final Color color;
  final IconData icon;

  const _AttendanceStatCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.percentage,
    required this.targetFraction,
    required this.color,
    required this.icon,
  });

  @override
  State<_AttendanceStatCard> createState() => _AttendanceStatCardState();
}

class _AttendanceStatCardState extends State<_AttendanceStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _anim = Tween<double>(begin: 0.0, end: widget.percentage)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_AttendanceStatCard old) {
    super.didUpdateWidget(old);
    if (old.percentage != widget.percentage) {
      _anim = Tween<double>(begin: old.percentage, end: widget.percentage)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGood = widget.percentage >= widget.targetFraction;
    final statusColor = isGood ? AuraColors.present : AuraColors.absent;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AuraColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.color.withOpacity(0.22), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: widget.color.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AuraColors.textMuted,
                  letterSpacing: 1.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.icon, color: widget.color, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Animated progress bar
          AnimatedBuilder(
            animation: _anim,
            builder: (context, _) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(children: [
                Container(height: 5, color: Colors.white.withOpacity(0.06)),
                FractionallySizedBox(
                  widthFactor: _anim.value.clamp(0.0, 1.0),
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [widget.color.withOpacity(0.6), widget.color],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // Big stat number
          Text(
            widget.value,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: widget.color,
              height: 1.0,
              shadows: [Shadow(color: widget.color.withOpacity(0.35), blurRadius: 12)],
            ),
          ),
          const SizedBox(height: 6),

          // Subtitle + badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.subtitle,
                style: const TextStyle(fontSize: 10, color: AuraColors.textMuted),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  isGood ? '✓ Good' : '⚠ Low',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VISUAL WONDER ATTENDANCE SPHERE WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _VisualWonderAttendanceSphere extends StatefulWidget {
  final AttendanceAnalysis? attendance;
  final StudentProfile student;

  const _VisualWonderAttendanceSphere({
    Key? key,
    required this.attendance,
    required this.student,
  }) : super(key: key);

  @override
  State<_VisualWonderAttendanceSphere> createState() => _VisualWonderAttendanceSphereState();
}

class _VisualWonderAttendanceSphereState extends State<_VisualWonderAttendanceSphere>
    with TickerProviderStateMixin {
  bool _showOverall = true;
  late AnimationController _controller;
  late Animation<double> _animation;

  late AnimationController _liquidController;
  bool _isShaking = false;
  bool _showWarningMessage = false;
  Timer? _warningTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    _liquidController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _liquidController.dispose();
    _warningTimer?.cancel();
    super.dispose();
  }

  void _toggleView() {
    if (_controller.isAnimating) return;
    HapticFeedback.mediumImpact();
    _controller.forward().then((_) {
      setState(() {
        _showOverall = !_showOverall;
      });
      _controller.reset();
    });
  }

  void _triggerShake() {
    HapticFeedback.vibrate();
    setState(() {
      _isShaking = true;
      _showWarningMessage = true;
    });
    _warningTimer?.cancel();
    _warningTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isShaking = false;
          _showWarningMessage = false;
        });
      }
    });
  }

  String _getWarningMessage(bool showOverall, double pct, double health, double target) {
    if (showOverall) {
      if (pct < target) {
        return 'Critical overall attendance. Additional classes required for safety.';
      } else {
        return 'Safe overall attendance. Keep maintaining current standards.';
      }
    } else {
      if (health >= target + 10) {
        return 'Excellent attendance health status. Strong consistency index.';
      } else if (health < target) {
        return 'Low health score. Please prioritize attending upcoming lectures.';
      } else {
        return 'Good health score. Consistency metrics are stable.';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = widget.attendance?.overallPercentage ?? 100.0;
    final health = widget.attendance?.healthScore ?? 100.0;
    final target = widget.student.attendanceTarget;
    
    final isGood = _showOverall ? (pct >= target) : (health >= 75.0);
    final baseColor = isGood 
        ? (_showOverall ? AuraColors.present : AuraColors.primary)
        : (_showOverall ? AuraColors.absent : AuraColors.leave);

    return Column(
      children: [
        GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != 0) {
              _toggleView();
            }
          },
          onTap: _triggerShake,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  final angle = _animation.value * math.pi;
                  final isUnder = angle > math.pi / 2;
                  final displayOverall = isUnder ? !_showOverall : _showOverall;

                  return Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // perspective
                      ..rotateY(angle),
                    alignment: Alignment.center,
                    child: Transform(
                      transform: isUnder ? Matrix4.rotationY(math.pi) : Matrix4.identity(),
                      alignment: Alignment.center,
                      child: _buildSphere(displayOverall),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _showOverall ? AuraColors.primary : Colors.white24,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: !_showOverall ? AuraColors.primary : Colors.white24,
              ),
            ),
          ],
        ),
        
        // Animated warning message banner (only visible for 5s after tapping)
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: _showWarningMessage
              ? Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: baseColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: baseColor.withOpacity(0.3), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: baseColor.withOpacity(0.08),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isGood ? Icons.verified_user : Icons.warning_amber_rounded,
                        color: baseColor,
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          _getWarningMessage(_showOverall, pct, health, target),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().slideY(begin: 0.1, end: 0, duration: 250.ms).fadeIn(duration: 250.ms)
              : const SizedBox(),
        ),

        const SizedBox(height: 10),
        const Text(
          'Swipe left/right to Toggle • Tap to slosh liquid',
          style: TextStyle(
            fontSize: 9.5,
            color: AuraColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSphere(bool showOverall) {
    final pct = widget.attendance?.overallPercentage ?? 100.0;
    final health = widget.attendance?.healthScore ?? 100.0;
    final target = widget.student.attendanceTarget;
    
    final isGood = showOverall ? (pct >= target) : (health >= 75.0);
    final baseColor = isGood 
        ? (showOverall ? AuraColors.present : AuraColors.primary)
        : (showOverall ? AuraColors.absent : AuraColors.leave);

    return Center(
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: baseColor.withOpacity(0.25),
              blurRadius: 30,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Liquid wave indicating filling percentage
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _liquidController,
                builder: (context, child) {
                  final double phaseShift = _isShaking ? 6.0 : 1.0;
                  final double currentPhase = _liquidController.value * 2 * math.pi * phaseShift;
                  final double amplitude = _isShaking ? 16.0 : 5.0;
                  final double fillValue = showOverall ? (pct / 100.0) : (health / 100.0);
                  
                  return CustomPaint(
                    painter: _LiquidPainter(
                      value: fillValue,
                      phase: currentPhase,
                      color: baseColor,
                      amplitude: amplitude,
                    ),
                  );
                },
              ),
            ),

            // Glass reflection highlight overlay on top of wave
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.35),
                    Colors.white.withOpacity(0.05),
                    Colors.transparent,
                    Colors.black.withOpacity(0.55),
                  ],
                  center: const Alignment(-0.35, -0.35),
                  radius: 0.95,
                ),
              ),
            ),

            // Pulsing visual halo
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: baseColor.withOpacity(0.2), width: 1.5),
              ),
            ).animate(onPlay: (controller) => controller.repeat())
             .scale(begin: const Offset(0.92, 0.92), end: const Offset(1.08, 1.08), duration: 2200.ms, curve: Curves.easeInOut)
             .fadeIn(duration: 1000.ms)
             .fadeOut(delay: 1000.ms, duration: 1200.ms),

            // Central Stats Content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    showOverall ? Icons.bar_chart_rounded : Icons.favorite_rounded,
                    color: Colors.white,
                    size: 24,
                  ).animate().scale(delay: 50.ms, duration: 250.ms),
                  const SizedBox(height: 6),
                  Text(
                    showOverall ? '${pct.round()}%' : '${health.round()}',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.0,
                      shadows: [
                        Shadow(
                          color: baseColor.withOpacity(0.8),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    showOverall ? 'OVERALL ATTENDANCE' : 'ATTENDANCE HEALTH',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 8.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    showOverall 
                        ? 'Target: ${target.round()}%' 
                        : (health >= 75.0 ? 'Status: Excellent' : 'Status: Critical'),
                    style: TextStyle(
                      fontSize: 9.5,
                      color: isGood ? Colors.greenAccent : Colors.amberAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
