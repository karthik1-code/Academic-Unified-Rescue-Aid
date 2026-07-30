import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:aura_frontend/core/theme.dart';
import 'package:aura_frontend/providers/providers.dart';
import 'package:aura_frontend/models/models.dart';

// --- AI Response State ---
enum _AiStep { home, selectSubject, result }

class _CommandResult {
  final String title;
  final IconData icon;
  final List<_ResultRow> rows;
  final String summary;
  final Color accentColor;

  const _CommandResult({
    required this.title,
    required this.icon,
    required this.rows,
    required this.summary,
    required this.accentColor,
  });
}

class _ResultRow {
  final String label;
  final String value;
  final Color? valueColor;
  const _ResultRow(this.label, this.value, {this.valueColor});
}

class _AiCommand {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool needsSubject;

  const _AiCommand({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.needsSubject = false,
  });
}

// --- Main Chat View ---
class AuraChatView extends ConsumerStatefulWidget {
  const AuraChatView({Key? key}) : super(key: key);

  @override
  ConsumerState<AuraChatView> createState() => _AuraChatViewState();
}

class _AuraChatViewState extends ConsumerState<AuraChatView>
    with SingleTickerProviderStateMixin {
  _AiStep _step = _AiStep.home;
  _AiCommand? _activeCommand;
  _CommandResult? _result;
  late AnimationController _pulseController;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const _commands = [
    _AiCommand(
      id: 'attend_next',
      title: 'Should I attend next class?',
      subtitle: 'Checks your safe leave buffer',
      icon: Icons.school_outlined,
      color: AuraColors.primary,
      needsSubject: true,
    ),
    _AiCommand(
      id: 'weak_subjects',
      title: 'Show weak subjects',
      subtitle: 'Subjects below your target',
      icon: Icons.warning_amber_outlined,
      color: Color(0xFFFF5470),
    ),
    _AiCommand(
      id: 'attendance_summary',
      title: "Today's attendance summary",
      subtitle: 'Overall & per-subject stats',
      icon: Icons.bar_chart,
      color: AuraColors.secondary,
    ),
    _AiCommand(
      id: 'safe_leaves',
      title: 'Remaining safe leaves',
      subtitle: 'Classes you can skip safely',
      icon: Icons.beach_access_outlined,
      color: Color(0xFF00F5D4),
      needsSubject: true,
    ),
    _AiCommand(
      id: 'classes_for_75',
      title: 'Classes required for 75%',
      subtitle: 'Recovery calculation',
      icon: Icons.calculate_outlined,
      color: Color(0xFFFFD166),
      needsSubject: true,
    ),
    _AiCommand(
      id: 'study_today',
      title: 'What should I study today?',
      subtitle: 'Based on weak subjects',
      icon: Icons.menu_book_outlined,
      color: Color(0xFF7209B7),
    ),
    _AiCommand(
      id: 'revision',
      title: 'Revision suggestions',
      subtitle: 'Smart revision order',
      icon: Icons.auto_stories_outlined,
      color: AuraColors.accent,
    ),
    _AiCommand(
      id: 'health_check',
      title: 'Attendance health check',
      subtitle: 'Full academic health report',
      icon: Icons.favorite_outline,
      color: Color(0xFFB5179E),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final student = ref.read(authProvider);
      if (student != null) {
        ref.read(attendanceProvider.notifier).load(student.id);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleCommand(_AiCommand command) {
    final attendance = ref.read(attendanceProvider);
    final subjects = _getSubjects(attendance);
    setState(() {
      _activeCommand = command;
      if (command.needsSubject && subjects.isNotEmpty) {
        _step = _AiStep.selectSubject;
      } else {
        _result = _computeResult(command, null, attendance);
        _step = _AiStep.result;
      }
    });
  }

  void _handleSubjectSelect(SubjectAttendanceDetail subject) {
    final attendance = ref.read(attendanceProvider);
    setState(() {
      _result = _computeResult(_activeCommand!, subject, attendance);
      _step = _AiStep.result;
    });
  }

  void _goHome() {
    setState(() {
      _step = _AiStep.home;
      _activeCommand = null;
      _result = null;
    });
  }



  List<SubjectAttendanceDetail> _getSubjects(AttendanceAnalysis? attendance) {
    if (attendance == null) return [];
    final map = <String, SubjectAttendanceDetail>{};
    for (var s in attendance.subjectsDetail) {
      map[s.subjectName.toLowerCase().trim()] = s;
    }
    return map.values.toList();
  }

  _CommandResult _computeResult(
    _AiCommand cmd,
    SubjectAttendanceDetail? subject,
    AttendanceAnalysis? attendance,
  ) {
    final student = ref.read(authProvider);
    final target = student?.attendanceTarget ?? 75.0;
    final subjects = _getSubjects(attendance);

    switch (cmd.id) {
      case 'attend_next':
        if (subject == null) {
          return _CommandResult(
            title: 'Select a Subject',
            icon: Icons.book_outlined,
            rows: [],
            summary: 'No subject selected.',
            accentColor: cmd.color,
          );
        }
        final pct = subject.percentage;
        final isSafe = pct >= target;
        final safeLeaves = subject.safeLeaves;
        final required = subject.requiredToRecover;
        return _CommandResult(
          title: subject.subjectName,
          icon: isSafe ? Icons.check_circle_outline : Icons.warning_amber_outlined,
          rows: [
            _ResultRow('Current Attendance', '${pct.toStringAsFixed(1)}%',
                valueColor: isSafe ? AuraColors.present : AuraColors.absent),
            _ResultRow('Target', '${target.round()}%'),
            if (isSafe) ...[
              _ResultRow('Safe Leaves Remaining', '$safeLeaves',
                  valueColor: AuraColors.present),
              _ResultRow(
                  'Recommendation',
                  safeLeaves > 0
                      ? 'You can skip this class safely.'
                      : 'Attend to maintain buffer.'),
            ] else ...[
              _ResultRow('Classes Needed to Recover', '$required',
                  valueColor: AuraColors.absent),
              _ResultRow('Recommendation', 'Attend this class — you need it!'),
            ],
          ],
          summary: isSafe
              ? (safeLeaves > 0
                  ? 'You are safe! You can skip up to $safeLeaves more classes in ${subject.subjectName}.'
                  : 'You are right on the limit. Attend to stay safe.')
              : 'Attend! You need $required more classes to reach ${target.round()}% in ${subject.subjectName}.',
          accentColor: isSafe ? AuraColors.present : AuraColors.absent,
        );

      case 'safe_leaves':
        if (subject == null) {
          return _CommandResult(
            title: 'Safe Leaves',
            icon: Icons.beach_access_outlined,
            rows: [],
            summary: 'Select a subject.',
            accentColor: cmd.color,
          );
        }
        return _CommandResult(
          title: '${subject.subjectName} — Safe Leaves',
          icon: Icons.beach_access_outlined,
          rows: [
            _ResultRow('Current Attendance', '${subject.percentage.toStringAsFixed(1)}%'),
            _ResultRow('Safe Classes to Skip', '${subject.safeLeaves}',
                valueColor: subject.safeLeaves > 0 ? AuraColors.present : AuraColors.absent),
            _ResultRow('Present', '${subject.present}'),
            _ResultRow('Absent', '${subject.absent}'),
            _ResultRow('Total Classes', '${subject.totalClasses}'),
          ],
          summary: subject.safeLeaves > 0
              ? 'You can safely skip ${subject.safeLeaves} more class(es) in ${subject.subjectName}.'
              : 'No safe leaves left for ${subject.subjectName}. Attend every class!',
          accentColor: subject.safeLeaves > 0 ? AuraColors.present : AuraColors.absent,
        );

      case 'classes_for_75':
        if (subject == null) {
          return _CommandResult(
            title: 'Recovery Calculator',
            icon: Icons.calculate_outlined,
            rows: [],
            summary: 'Select a subject.',
            accentColor: cmd.color,
          );
        }
        final isSafe = subject.percentage >= target;
        return _CommandResult(
          title: '${subject.subjectName} — Recovery',
          icon: Icons.calculate_outlined,
          rows: [
            _ResultRow('Current Attendance', '${subject.percentage.toStringAsFixed(1)}%'),
            _ResultRow('Target', '${target.round()}%'),
            if (!isSafe)
              _ResultRow('Classes Required', '${subject.requiredToRecover}',
                  valueColor: AuraColors.absent)
            else
              _ResultRow('Status', 'Already above target!',
                  valueColor: AuraColors.present),
          ],
          summary: isSafe
              ? '${subject.subjectName} is already at ${subject.percentage.toStringAsFixed(1)}% — above the ${target.round()}% target!'
              : 'You need to attend ${subject.requiredToRecover} more consecutive classes in ${subject.subjectName} to reach ${target.round()}%.',
          accentColor: isSafe ? AuraColors.present : AuraColors.absent,
        );

      case 'weak_subjects':
        final weak = subjects.where((s) => s.percentage < target).toList();
        final rows = weak.map((s) => _ResultRow(
              s.subjectName,
              '${s.percentage.toStringAsFixed(1)}%',
              valueColor: AuraColors.absent,
            )).toList();
        return _CommandResult(
          title: 'Weak Subjects',
          icon: Icons.warning_amber_outlined,
          rows: rows.isEmpty
              ? [_ResultRow('All subjects', 'Above target', valueColor: AuraColors.present)]
              : rows,
          summary: weak.isEmpty
              ? 'All your subjects are above the ${target.round()}% target! Keep it up!'
              : '${weak.length} subject(s) need urgent attention: ${weak.map((s) => s.subjectName).join(', ')}.',
          accentColor: weak.isEmpty ? AuraColors.present : AuraColors.absent,
        );

      case 'attendance_summary':
        final overall = attendance?.overallPercentage ?? 0;
        final health = attendance?.healthScore ?? 0;
        final rows = subjects
            .map((s) => _ResultRow(
                  s.subjectName,
                  '${s.percentage.toStringAsFixed(1)}% (${s.statusLabel})',
                  valueColor: s.percentage >= target ? AuraColors.present : AuraColors.absent,
                ))
            .toList();
        return _CommandResult(
          title: "Today's Attendance Summary",
          icon: Icons.bar_chart_outlined,
          rows: [
            _ResultRow('Overall Attendance', '${overall.toStringAsFixed(1)}%',
                valueColor: overall >= target ? AuraColors.present : AuraColors.absent),
            _ResultRow('Health Score', '${health.toStringAsFixed(0)}/100'),
            _ResultRow('Target', '${target.round()}%'),
            const _ResultRow('', ''),
            ...rows,
          ],
          summary: overall >= target
              ? 'Overall attendance is ${overall.toStringAsFixed(1)}% — above your ${target.round()}% target.'
              : 'Overall attendance is ${overall.toStringAsFixed(1)}% — below your ${target.round()}% target. Act now!',
          accentColor: overall >= target ? AuraColors.present : AuraColors.absent,
        );

      case 'study_today':
        final weak = subjects.where((s) => s.percentage < target).toList();
        final critical = subjects
            .where((s) => s.statusLabel == 'Critical')
            .map((s) => s.subjectName)
            .toList();
        final moderate = subjects
            .where((s) => s.percentage >= target && s.percentage < target + 10)
            .map((s) => s.subjectName)
            .toList();
        return _CommandResult(
          title: "Study Plan for Today",
          icon: Icons.book_outlined,
          rows: [
            if (critical.isNotEmpty)
              _ResultRow('Critical Focus', critical.join(', '),
                  valueColor: AuraColors.absent),
            if (moderate.isNotEmpty)
              _ResultRow('Review', moderate.join(', '),
                  valueColor: AuraColors.leave),
            if (critical.isEmpty && moderate.isEmpty)
              _ResultRow('All Good!', 'Focus on upcoming exams', valueColor: AuraColors.present),
          ],
          summary: critical.isNotEmpty
              ? 'Prioritize: ${critical.join(', ')} today. Your attendance there is critical!'
              : 'All subjects look good. Focus on deep revision and upcoming exam prep.',
          accentColor: AuraColors.accent,
        );

      case 'revision':
        final sorted = [...subjects]
          ..sort((a, b) => a.percentage.compareTo(b.percentage));
        final rows = sorted
            .map((s) => _ResultRow(
                  s.subjectName,
                  '${s.percentage.toStringAsFixed(1)}% — ${s.statusLabel}',
                  valueColor: s.percentage >= target ? AuraColors.present : AuraColors.absent,
                ))
            .toList();
        return _CommandResult(
          title: 'Revision Priority Order',
          icon: Icons.assignment_outlined,
          rows: rows.isEmpty
              ? [const _ResultRow('No subjects found', 'Complete onboarding first')]
              : rows,
          summary:
              sorted.isEmpty
                  ? 'Complete onboarding to get personalized revision suggestions.'
                  : 'Revise in this order (weakest first): ${sorted.map((s) => s.subjectName).join(' → ')}.',
          accentColor: AuraColors.accent,
        );

      case 'health_check':
        final health = attendance?.healthScore ?? 100;
        final critical = subjects.where((s) => s.statusLabel == 'Critical').length;
        final safe = subjects.where((s) => s.statusLabel != 'Critical').length;
        Color hColor = health >= 80
            ? AuraColors.present
            : health >= 60
                ? AuraColors.leave
                : AuraColors.absent;
        String hLabel = health >= 80
            ? 'Excellent'
            : health >= 60
                ? 'Fair'
                : 'Critical';
        return _CommandResult(
          title: 'Academic Health Report',
          icon: health >= 80 ? Icons.favorite_outline : health >= 60 ? Icons.remove_circle_outline : Icons.error_outline,
          rows: [
            _ResultRow('Health Score', '${health.toStringAsFixed(0)}/100', valueColor: hColor),
            _ResultRow('Status', hLabel, valueColor: hColor),
            _ResultRow('Safe Subjects', '$safe', valueColor: AuraColors.present),
            _ResultRow('Critical Subjects', '$critical',
                valueColor: critical > 0 ? AuraColors.absent : AuraColors.present),
            _ResultRow('Overall Avg', '${attendance?.overallPercentage.toStringAsFixed(1) ?? 0}%'),
          ],
          summary: health >= 80
              ? 'Excellent health! Your attendance record is very strong.'
              : health >= 60
                  ? 'Fair health. Some subjects need attention before it\'s too late.'
                  : 'Critical! Multiple subjects at risk. Prioritize attendance immediately.',
          accentColor: hColor,
        );

      default:
        return _CommandResult(
          title: 'AURA AI',
          icon: Icons.psychology_outlined,
          rows: [],
          summary: 'Command not recognized.',
          accentColor: AuraColors.primary,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = ref.watch(authProvider);
    final isOnline = ref.watch(onlineProvider).value ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            _buildHeader(isOnline, student),

            // Content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _step == _AiStep.home
                    ? _buildHomeView(key: const ValueKey('home'))
                    : _step == _AiStep.selectSubject
                        ? _buildSubjectSelectView(key: const ValueKey('subject'))
                        : _buildResultView(key: const ValueKey('result')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isOnline, dynamic student) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          if (_step != _AiStep.home)
            GestureDetector(
              onTap: _goHome,
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: const Icon(Icons.arrow_back, size: 18, color: AuraColors.primary),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AURA AI ASSISTANT',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AuraColors.primary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _step == _AiStep.home
                      ? 'What can I help you with?'
                      : _step == _AiStep.selectSubject
                          ? 'Select a Subject'
                          : _activeCommand?.title ?? 'Result',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isOnline
                  ? AuraColors.present.withOpacity(0.1)
                  : AuraColors.absent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOnline
                    ? AuraColors.present.withOpacity(0.3)
                    : AuraColors.absent.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) => Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOnline ? AuraColors.present : AuraColors.absent,
                      boxShadow: [
                        BoxShadow(
                          color: (isOnline ? AuraColors.present : AuraColors.absent)
                              .withOpacity(_pulseController.value * 0.6),
                          blurRadius: 6,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isOnline ? 'ONLINE' : 'OFFLINE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isOnline ? AuraColors.present : AuraColors.absent,
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildHomeView({Key? key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Greeting banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AuraColors.accent.withOpacity(0.18),
                  AuraColors.primary.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AuraColors.primary.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AuraColors.primary.withOpacity(0.12),
                    border: Border.all(color: AuraColors.primary.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.psychology, color: AuraColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AURA Academic Intelligence',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Tap a command below to get personalized insights based on your attendance data.',
                        style: TextStyle(
                          color: AuraColors.textMuted,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1),
          const SizedBox(height: 20),

          const Text(
            'QUICK COMMANDS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AuraColors.textMuted,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),

          // Commands grid
          ...List.generate(_commands.length, (i) {
            final cmd = _commands[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildCommandCard(cmd, i),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCommandCard(_AiCommand cmd, int index) {
    return GestureDetector(
      onTap: () => _handleCommand(cmd),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cmd.color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cmd.color.withOpacity(0.2), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: cmd.color.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cmd.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(cmd.icon, color: cmd.color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cmd.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cmd.subtitle,
                    style: const TextStyle(
                      color: AuraColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: cmd.color.withOpacity(0.5),
              size: 14,
            ),
          ],
        ),
      )
          .animate(delay: Duration(milliseconds: 60 * index))
          .fadeIn(duration: 300.ms)
          .slideX(begin: 0.05),
    );
  }

  Widget _buildSubjectSelectView({Key? key}) {
    final attendance = ref.watch(attendanceProvider);
    final subjects = _getSubjects(attendance);
    final cmd = _activeCommand!;

    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cmd.color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cmd.color.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(cmd.icon, color: cmd.color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    cmd.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Select Subject',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AuraColors.textMuted,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          if (subjects.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AuraTheme.glassDecoration(),
              child: const Text(
                'No subjects found. Complete onboarding first.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AuraColors.textMuted),
              ),
            )
          else
            ...subjects.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              final isSafe = s.percentage >= (ref.read(authProvider)?.attendanceTarget ?? 75);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => _handleSubjectSelect(s),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSafe
                            ? AuraColors.present.withOpacity(0.2)
                            : AuraColors.absent.withOpacity(0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (isSafe ? AuraColors.present : AuraColors.absent)
                                .withOpacity(0.12),
                            border: Border.all(
                              color: (isSafe ? AuraColors.present : AuraColors.absent)
                                  .withOpacity(0.35),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            s.subjectName.substring(0, math.min(2, s.subjectName.length)).toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isSafe ? AuraColors.present : AuraColors.absent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.subjectName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${s.percentage.toStringAsFixed(1)}% • ${s.statusLabel}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSafe ? AuraColors.present : AuraColors.absent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios,
                            size: 14, color: AuraColors.textMuted),
                      ],
                    ),
                  ),
                )
                    .animate(delay: Duration(milliseconds: 60 * i))
                    .fadeIn(duration: 250.ms)
                    .slideX(begin: 0.05),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildResultView({Key? key}) {
    final result = _result!;
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Result Card Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  result.accentColor.withOpacity(0.15),
                  result.accentColor.withOpacity(0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: result.accentColor.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Icon(result.icon, size: 40, color: result.accentColor),
                const SizedBox(height: 10),
                Text(
                  result.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 350.ms).scale(begin: const Offset(0.95, 0.95)),
          const SizedBox(height: 16),

          // Data rows
          if (result.rows.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: AuraTheme.glassDecoration(),
              child: Column(
                children: result.rows.asMap().entries.map((entry) {
                  final i = entry.key;
                  final row = entry.value;
                  if (row.label.isEmpty) return const Divider(color: Colors.white10, height: 20);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          row.label,
                          style: const TextStyle(color: AuraColors.textMuted, fontSize: 12),
                        ),
                        Flexible(
                          child: Text(
                            row.value,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: row.valueColor ?? Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate(delay: Duration(milliseconds: 50 * i))
                      .fadeIn(duration: 250.ms)
                      .slideX(begin: 0.05);
                }).toList(),
              ),
            ),
          const SizedBox(height: 14),

          // Summary card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: result.accentColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: result.accentColor.withOpacity(0.25)),
            ),
            child: Text(
              result.summary,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ).animate(delay: 200.ms).fadeIn(duration: 300.ms),
          const SizedBox(height: 20),

          // Try another command button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.04),
              foregroundColor: AuraColors.primary,
              side: BorderSide(color: AuraColors.primary.withOpacity(0.25)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _goHome,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text(
              'Ask Another Question',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ).animate(delay: 300.ms).fadeIn(duration: 300.ms),
        ],
      ),
    );
  }


}
