import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_frontend/core/theme.dart';
import 'package:aura_frontend/providers/providers.dart';
import 'package:aura_frontend/models/models.dart';
import 'package:aura_frontend/services/local_storage.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class CalendarView extends ConsumerStatefulWidget {
  const CalendarView({Key? key}) : super(key: key);

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> with SingleTickerProviderStateMixin {
  DateTime _selectedDay = DateTime.now();
  late ScrollController _scrollController;
  int _activeSegment = 0; // 0: Logger, 1: Analytics

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final student = ref.read(authProvider);
      if (student != null) {
        ref.read(attendanceProvider.notifier).load(student.id);
        _scrollToCurrentDay(student.semesterStart);
      }
    });
  }

  void _scrollToCurrentDay(DateTime start) {
    final diff = _selectedDay.difference(start).inDays;
    if (diff > 0 && _scrollController.hasClients) {
      _scrollController.animateTo(
        diff * 82.0 - 100, 
        duration: const Duration(milliseconds: 500), 
        curve: Curves.easeInOut
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<DateTime> _generateDates(DateTime start, DateTime end) {
    List<DateTime> dates = [];
    DateTime current = start;
    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      dates.add(current);
      current = current.add(const Duration(days: 1));
    }
    return dates;
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'MON';
      case 2: return 'TUE';
      case 3: return 'WED';
      case 4: return 'THU';
      case 5: return 'FRI';
      case 6: return 'SAT';
      case 7: return 'SUN';
      default: return '';
    }
  }

  String _getMonthName(int month) {
    switch (month) {
      case 1: return 'Jan';
      case 2: return 'Feb';
      case 3: return 'Mar';
      case 4: return 'Apr';
      case 5: return 'May';
      case 6: return 'Jun';
      case 7: return 'Jul';
      case 8: return 'Aug';
      case 9: return 'Sep';
      case 10: return 'Oct';
      case 11: return 'Nov';
      case 12: return 'Dec';
      default: return '';
    }
  }

  void _showWateringAttendance(BuildContext context, SubjectAttendanceDetail sub, double target) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          child: _WateringAttendancePopup(sub: sub, target: target),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = ref.watch(authProvider);
    final attendance = ref.watch(attendanceProvider);

    if (student == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final allDates = _generateDates(student.semesterStart, student.semesterEnd);
    final rawSubjects = attendance?.subjectsDetail ?? [];
    final subjectsMap = <String, SubjectAttendanceDetail>{};
    for (var s in rawSubjects) {
      subjectsMap[s.subjectName.trim().toLowerCase()] = s;
    }
    final subjects = subjectsMap.values.toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top segment controller bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ATTENDANCE INTELLIGENCE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AuraColors.primary,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Class Attendance',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  
                  // Segment toggler
                  Container(
                    height: 38,
                    padding: const EdgeInsets.all(3.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(
                      children: [
                        _buildSegmentButton(0, 'Log'),
                        _buildSegmentButton(1, 'Analytics'),
                      ],
                    ),
                  )
                ],
              ),
            ),
            
            Expanded(
              child: _activeSegment == 0
                  ? _buildLoggerView(allDates, subjects, student)
                  : _buildAnalyticsView(subjects, student, attendance),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton(int index, String label) {
    final active = _activeSegment == index;
    return GestureDetector(
      onTap: () => setState(() => _activeSegment = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          gradient: active ? AuraColors.auroraGradient : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: active ? Colors.black : AuraColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildLoggerView(List<DateTime> allDates, List<SubjectAttendanceDetail> subjects, StudentProfile student) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Google Calendar Style sliding calendar strip
          Container(
            height: 90,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: allDates.length,
              itemBuilder: (context, idx) {
                final date = allDates[idx];
                final isSelected = DateUtils.isSameDay(_selectedDay, date);
                final isToday = DateUtils.isSameDay(DateTime.now(), date);
                final isPast = date.isBefore(DateTime.now()) && !isToday;
                
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedDay = date);
                  },
                  child: Container(
                    width: 56,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _getDayName(date.weekday),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFF1A73E8)
                                : isToday
                                    ? const Color(0xFF1A73E8)
                                    : AuraColors.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? const Color(0xFF1A73E8)
                                : isToday
                                    ? const Color(0xFF1A73E8).withOpacity(0.15)
                                    : Colors.transparent,
                            border: isToday && !isSelected
                                ? Border.all(color: const Color(0xFF1A73E8), width: 1)
                                : null,
                          ),
                          child: Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : isToday
                                      ? const Color(0xFF1A73E8)
                                      : Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (isPast && !isSelected)
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white24,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Date Details Title Row with Google-style "TODAY" shortcut
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Schedule for ${_selectedDay.day} ${_getMonthName(_selectedDay.month)} ${_selectedDay.year}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() => _selectedDay = DateTime.now());
                  _scrollToCurrentDay(student.semesterStart);
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1A73E8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.today_outlined, size: 14),
                label: const Text(
                  'TODAY',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Enrolled Subjects List with Sliding Transition
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              final offsetAnimation = Tween<Offset>(
                begin: const Offset(0.08, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ));
              return SlideTransition(
                position: offsetAnimation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<String>(_selectedDay.toIso8601String().substring(0, 10)),
              child: subjects.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40.0),
                        child: Text(
                          'No subjects added yet. Please onboard.',
                          style: TextStyle(color: AuraColors.textMuted),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: subjects.length,
                      itemBuilder: (context, index) {
                        final sub = subjects[index];
                        final pct = sub.percentage;
                        final dailyStatus = LocalStorageService.getDailyStatus(sub.subjectId, _selectedDay);
                        final isGlowing = dailyStatus != null;
                        final activeColor = dailyStatus == 'present' ? AuraColors.present : AuraColors.absent;

                        return GestureDetector(
                          onTap: () => _showWateringAttendance(context, sub, student.attendanceTarget),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: dailyStatus == 'present'
                                  ? AuraColors.present.withOpacity(0.12)
                                  : dailyStatus == 'absent'
                                      ? AuraColors.absent.withOpacity(0.12)
                                      : Colors.white.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: dailyStatus == 'present'
                                    ? AuraColors.present.withOpacity(0.85)
                                    : dailyStatus == 'absent'
                                        ? AuraColors.absent.withOpacity(0.85)
                                        : pct < student.attendanceTarget
                                            ? AuraColors.absent.withOpacity(0.5)
                                            : AuraColors.cardBorder.withOpacity(0.3),
                                width: isGlowing ? 2.0 : 1.2,
                              ),
                              boxShadow: isGlowing
                                  ? [
                                      BoxShadow(
                                        color: activeColor.withOpacity(0.2),
                                        blurRadius: 16,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Subject Title & Percentage
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sub.subjectName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Credits: ${sub.credits} • Tap to view detail wave',
                                            style: const TextStyle(color: AuraColors.textMuted, fontSize: 10.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${pct.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: pct < student.attendanceTarget 
                                            ? AuraColors.absent 
                                            : AuraColors.present,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Present, Absent, Clear Actions
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    _buildAttendanceButton(
                                      label: 'Present',
                                      color: AuraColors.present,
                                      icon: Icons.check_circle_outline,
                                      isActive: dailyStatus == 'present',
                                      onPressed: () {
                                        ref.read(attendanceProvider.notifier).record(
                                              sub.subjectId,
                                              _selectedDay,
                                              'present',
                                            );
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    _buildAttendanceButton(
                                      label: 'Absent',
                                      color: AuraColors.absent,
                                      icon: Icons.cancel_outlined,
                                      isActive: dailyStatus == 'absent',
                                      onPressed: () {
                                        ref.read(attendanceProvider.notifier).record(
                                              sub.subjectId,
                                              _selectedDay,
                                              'absent',
                                            );
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    _buildAttendanceButton(
                                      label: 'Clear',
                                      color: AuraColors.textMuted,
                                      icon: Icons.close_outlined,
                                      isActive: false,
                                      onPressed: () {
                                        ref.read(attendanceProvider.notifier).clearRecord(
                                              sub.subjectId,
                                              _selectedDay,
                                            );
                                      },
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ).animate(key: ValueKey('${sub.subjectId}_$dailyStatus'))
                         .shimmer(duration: 400.ms, color: dailyStatus == 'present' ? Colors.greenAccent : dailyStatus == 'absent' ? Colors.redAccent : Colors.white24)
                         .shake(duration: 300.ms, hz: 4);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceButton({
    required String label,
    required Color color,
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    final displayColor = isActive ? color : color.withOpacity(0.4);
    final bgColor = isActive ? color.withOpacity(0.25) : color.withOpacity(0.03);
    final borderColor = isActive ? color : color.withOpacity(0.15);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onPressed();
        },
        borderRadius: BorderRadius.circular(12),
        splashColor: color.withOpacity(0.3),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: isActive ? 2.0 : 1.2),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.35),
                      blurRadius: 12,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: displayColor, size: 15),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: displayColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsView(List<SubjectAttendanceDetail> subjects, StudentProfile student, AttendanceAnalysis? analysis) {
    if (subjects.isEmpty) {
      return const Center(child: Text('Add subjects to view charts.', style: TextStyle(color: AuraColors.textMuted)));
    }

    final double overall = analysis?.overallPercentage ?? 100.0;
    final target = student.attendanceTarget;

    // Data mapped for SfCircularChart (Overall Progress)
    final List<_RadialData> radialData = [
      _RadialData('Overall', overall, AuraColors.primary),
    ];

    // Data mapped for Subject Comparison Bar Chart
    final List<_BarData> barData = subjects.map((sub) {
      return _BarData(sub.subjectName, sub.percentage, sub.statusLabel == 'Critical' ? AuraColors.absent : AuraColors.present);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row of Circular Gauge + Stat Highlights
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Container(
                  height: 160,
                  decoration: AuraTheme.glassDecoration(),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SfCircularChart(
                        series: <CircularSeries>[
                          RadialBarSeries<_RadialData, String>(
                            dataSource: radialData,
                            xValueMapper: (_RadialData data, _) => data.label,
                            yValueMapper: (_RadialData data, _) => data.value,
                            pointColorMapper: (_RadialData data, _) => data.color,
                            maximumValue: 100,
                            radius: '90%',
                            innerRadius: '75%',
                            cornerStyle: CornerStyle.bothCurve,
                          )
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${overall.toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Current Avg',
                            style: TextStyle(fontSize: 9, color: AuraColors.textMuted, fontWeight: FontWeight.bold),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: Container(
                  height: 160,
                  padding: const EdgeInsets.all(16.0),
                  decoration: AuraTheme.glassDecoration(borderColor: AuraColors.secondary),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TARGET REQUIRED', style: TextStyle(fontSize: 9, color: AuraColors.textMuted, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      Text('${target.round()}%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 10),
                      const Text('STATUS INDEX', style: TextStyle(fontSize: 9, color: AuraColors.textMuted, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      Text(
                        overall >= target ? 'SAFE BUFFER' : 'ATTENDANCE RISK',
                        style: TextStyle(
                          fontSize: 12, 
                          fontWeight: FontWeight.bold, 
                          color: overall >= target ? AuraColors.present : AuraColors.absent
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        overall >= target ? 'Keep skipping minimal.' : 'Recovery recommended.',
                        style: const TextStyle(fontSize: 10, color: AuraColors.textMuted),
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 18),

          // Subject-by-Subject Bar Chart
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: AuraTheme.glassDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Subject Percentage Comparison',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: SfCartesianChart(
                    plotAreaBorderWidth: 0,
                    primaryXAxis: CategoryAxis(
                      labelStyle: const TextStyle(fontSize: 9, color: AuraColors.textMuted),
                      majorGridLines: const MajorGridLines(width: 0),
                    ),
                    primaryYAxis: NumericAxis(
                      labelStyle: const TextStyle(fontSize: 9, color: AuraColors.textMuted),
                      axisLine: const AxisLine(width: 0),
                      majorGridLines: const MajorGridLines(width: 1, color: Colors.white10),
                      maximum: 100,
                    ),
                    series: <CartesianSeries>[
                      ColumnSeries<_BarData, String>(
                        dataSource: barData,
                        xValueMapper: (_BarData data, _) => data.subject,
                        yValueMapper: (_BarData data, _) => data.percentage,
                        pointColorMapper: (_BarData data, _) => data.color,
                        borderRadius: BorderRadius.circular(6),
                        dataLabelSettings: const DataLabelSettings(
                          isVisible: true,
                          textStyle: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Attendance Tips Panel
          Container(
            padding: const EdgeInsets.all(18.0),
            decoration: AuraTheme.glassDecoration(borderColor: AuraColors.primary.withOpacity(0.2)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.tips_and_updates_outlined, color: AuraColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text('Subject Recovery Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),
                ...subjects.map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: s.percentage >= student.attendanceTarget ? AuraColors.present : AuraColors.absent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.subjectName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        s.percentage >= student.attendanceTarget
                            ? '${s.safeLeaves} safe leaves'
                            : '${s.requiredToRecover} classes needed',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: s.percentage >= student.attendanceTarget ? AuraColors.present : AuraColors.absent,
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _RadialData {
  final String label;
  final double value;
  final Color color;
  _RadialData(this.label, this.value, this.color);
}

class _BarData {
  final String subject;
  final double percentage;
  final Color color;
  _BarData(this.subject, this.percentage, this.color);
}

// Glowing circular watering fluid wave widget
class _WateringAttendancePopup extends StatefulWidget {
  final SubjectAttendanceDetail sub;
  final double target;
  const _WateringAttendancePopup({required this.sub, required this.target});

  @override
  State<_WateringAttendancePopup> createState() => _WateringAttendancePopupState();
}

class _WateringAttendancePopupState extends State<_WateringAttendancePopup> with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = widget.sub.percentage;
    final isCritical = pct < widget.target;
    final waveColor = isCritical ? AuraColors.absent : AuraColors.primary;
    
    final total = widget.sub.totalClasses;
    final present = widget.sub.present;

    int getClassesNeededToReach(double targetPct) {
      if (pct >= targetPct) return 0;
      final targetFraction = targetPct / 100.0;
      final denom = 1.0 - targetFraction;
      if (denom <= 0) return 0;
      final val = (targetFraction * total - present) / denom;
      return math.max(0, (val).ceil());
    }

    int getSafeLeavesFor(double targetPct) {
      if (pct < targetPct) return 0;
      final targetFraction = targetPct / 100.0;
      if (targetFraction <= 0) return 0;
      final val = present / targetFraction - total;
      return math.max(0, (val).floor());
    }

    final needed75 = getClassesNeededToReach(75.0);
    final safe75 = getSafeLeavesFor(75.0);
    
    final needed65 = getClassesNeededToReach(65.0);
    final safe65 = getSafeLeavesFor(65.0);

    String adviceText;
    if (pct < 65.0) {
      adviceText = 'Urgent: You need to attend the next $needed65 classes consecutively to cross 65%, and $needed75 classes consecutively to cross the safer 75% target.';
    } else if (pct < 75.0) {
      adviceText = 'Safety margin: You are safe from the 65% limit (cushion: $safe65 classes), but you need to attend the next $needed75 classes consecutively to cross the safer 75% target.';
    } else {
      adviceText = 'Excellent! Your attendance is safe. You have a cushion of $safe75 classes before dropping below 75%, and up to $safe65 classes before dropping below 65%.';
    }

    return Container(
      padding: const EdgeInsets.all(28.0),
      decoration: AuraTheme.glassDecoration(
        borderColor: waveColor,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.sub.subjectName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Target Required: ${widget.target.round()}%',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AuraColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 28),

          // Fluid Waving Circular Dial
          Center(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glowing background border
                    Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: waveColor.withOpacity(0.35), width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: waveColor.withOpacity(0.2),
                            blurRadius: 18,
                            spreadRadius: 2,
                          )
                        ]
                      ),
                    ),
                    // Liquid Custom Painter
                    SizedBox(
                      width: 154,
                      height: 154,
                      child: CustomPaint(
                        painter: _LiquidWavePainter(
                          progress: pct / 100.0,
                          wavePhase: _waveController.value * 2 * math.pi,
                          waveColor: waveColor,
                        ),
                      ),
                    ),
                    // Percentage text overlay
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 32, 
                            fontWeight: FontWeight.bold, 
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 4,
                                offset: Offset(1, 1),
                              )
                            ]
                          ),
                        ),
                        Text(
                          isCritical ? 'CRITICAL' : 'SAFE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isCritical ? Colors.redAccent : AuraColors.primary,
                            letterSpacing: 1.5,
                          ),
                        )
                      ],
                    )
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 28),

          // Detailed metrics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetric('Present', widget.sub.present, AuraColors.present),
              _buildMetric('Absent', widget.sub.absent, AuraColors.absent),
              _buildMetric('Total', widget.sub.totalClasses, AuraColors.textMuted),
            ],
          ),
          const SizedBox(height: 20),

          // Advice Text
          Text(
            adviceText,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 24),

          // Close button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: waveColor.withOpacity(0.12),
              foregroundColor: waveColor,
              side: BorderSide(color: waveColor.withOpacity(0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          )
        ],
      ),
    );
  }

  Widget _buildMetric(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(color: AuraColors.textMuted, fontSize: 9, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}

// Wave custom painter
class _LiquidWavePainter extends CustomPainter {
  final double progress;
  final double wavePhase;
  final Color waveColor;

  _LiquidWavePainter({required this.progress, required this.wavePhase, required this.waveColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Offset center = Offset(radius, radius);

    final Paint bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.015)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    final Path clipPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.clipPath(clipPath);

    final double waterHeight = size.height * (1.0 - progress);

    final Paint backWavePaint = Paint()
      ..color = waveColor.withOpacity(0.28)
      ..style = PaintingStyle.fill;

    final Path backPath = Path();
    backPath.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 1.0) {
      final double y = waterHeight + 6 * math.sin((x / size.width * 2 * math.pi) - wavePhase + math.pi / 2);
      backPath.lineTo(x, y);
    }
    backPath.lineTo(size.width, size.height);
    backPath.close();
    canvas.drawPath(backPath, backWavePaint);

    final Paint frontWavePaint = Paint()
      ..color = waveColor.withOpacity(0.48)
      ..style = PaintingStyle.fill;

    final Path frontPath = Path();
    frontPath.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 1.0) {
      final double y = waterHeight + 8 * math.sin((x / size.width * 2 * math.pi) + wavePhase);
      frontPath.lineTo(x, y);
    }
    frontPath.lineTo(size.width, size.height);
    frontPath.close();
    canvas.drawPath(frontPath, frontWavePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
