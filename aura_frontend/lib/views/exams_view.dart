import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:aura_frontend/core/theme.dart';
import 'package:aura_frontend/providers/providers.dart';
import 'package:aura_frontend/models/models.dart';
import 'package:go_router/go_router.dart';
import 'package:aura_frontend/core/google_calendar_picker.dart';

class ExamsView extends ConsumerStatefulWidget {
  const ExamsView({Key? key}) : super(key: key);

  @override
  ConsumerState<ExamsView> createState() => _ExamsViewState();
}

class _ExamsViewState extends ConsumerState<ExamsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final student = ref.read(authProvider);
      if (student != null) {
        ref.read(examsProvider.notifier).listenToStream(student.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final exams = ref.watch(examsProvider);
    final now = DateTime.now();
    final upcoming = exams.where((e) => e.date.isAfter(now)).toList();
    final past = exams.where((e) => !e.date.isAfter(now)).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.go('/dashboard'),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'EXAM SCHEDULER',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AuraColors.primary,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Upcoming Exams',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: AuraColors.auroraGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${upcoming.length} Upcoming',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: exams.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      children: [
                        if (upcoming.isNotEmpty) ...[
                          _buildSectionLabel('UPCOMING', AuraColors.primary),
                          const SizedBox(height: 8),
                          ...upcoming.asMap().entries.map((e) =>
                              _buildExamCard(e.value, e.key, isUpcoming: true)),
                        ],
                        if (past.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildSectionLabel('COMPLETED', AuraColors.textMuted),
                          const SizedBox(height: 8),
                          ...past.asMap().entries.map((e) =>
                              _buildExamCard(e.value, e.key, isUpcoming: false)),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExamDialog(context),
        backgroundColor: AuraColors.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Add Exam', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSectionLabel(String label, Color color) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: color,
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 72,
            color: AuraColors.textMuted.withOpacity(0.3),
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: 16),
          const Text(
            'No exams scheduled',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AuraColors.textMuted),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap + to add an upcoming exam',
            style: TextStyle(color: AuraColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildExamCard(Exam exam, int index, {required bool isUpcoming}) {
    final now = DateTime.now();
    final daysLeft = exam.date.difference(now).inDays;
    final hoursLeft = exam.date.difference(now).inHours;

    Color accentColor;
    String countdown;
    if (!isUpcoming) {
      accentColor = AuraColors.textMuted;
      countdown = 'Completed';
    } else if (daysLeft == 0) {
      accentColor = AuraColors.absent;
      countdown = 'TODAY';
    } else if (daysLeft == 1) {
      accentColor = AuraColors.leave;
      countdown = 'TOMORROW';
    } else if (daysLeft <= 7) {
      accentColor = AuraColors.leave;
      countdown = 'in $daysLeft days';
    } else {
      accentColor = AuraColors.present;
      countdown = 'in $daysLeft days';
    }

    final student = ref.read(authProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(exam.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AuraColors.absent.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline, color: AuraColors.absent),
        ),
        confirmDismiss: (_) async {
          HapticFeedback.mediumImpact();
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AuraColors.background,
              title: Text('Delete ${exam.name}?'),
              content: const Text('This action cannot be undone.', style: TextStyle(color: AuraColors.textMuted)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AuraColors.absent),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
        onDismissed: (_) {
          if (student != null) {
            ref.read(examsProvider.notifier).delete(student.id, exam.id);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(isUpcoming ? 0.03 : 0.015),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentColor.withOpacity(isUpcoming ? 0.25 : 0.1),
              width: 1.2,
            ),
            boxShadow: isUpcoming
                ? [
                    BoxShadow(
                      color: accentColor.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Date block
              Container(
                width: 52,
                height: 60,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withOpacity(0.25)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${exam.date.day}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                    Text(
                      _monthAbbr(exam.date.month),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: accentColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isUpcoming ? Colors.white : AuraColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AuraColors.secondary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            exam.subject,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AuraColors.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (exam.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        exam.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AuraColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),

              // Countdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accentColor.withOpacity(0.25)),
                    ),
                    child: Text(
                      countdown,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ),
                  if (isUpcoming && exam.reminderSet) ...[
                    const SizedBox(height: 6),
                    const Icon(Icons.notifications_active, size: 14, color: AuraColors.textMuted),
                  ],
                ],
              ),
            ],
          ),
        )
            .animate(delay: Duration(milliseconds: 60 * index))
            .fadeIn(duration: 300.ms)
            .slideX(begin: 0.05),
      ),
    );
  }

  void _showAddExamDialog(BuildContext context) {
    final nameController = TextEditingController();
    final subjectController = TextEditingController();
    final descController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    bool reminderSet = true;
    String reminderTime = '09:00';

    // Get subject names from attendance for dropdown hints
    final attendance = ref.read(attendanceProvider);
    final subjects = attendance?.subjectsDetail.map((s) => s.subjectName).toList() ?? [];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: AuraTheme.glassDecoration(borderColor: AuraColors.primary),
                constraints: const BoxConstraints(maxWidth: 400),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AuraColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.school, color: AuraColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Add Exam',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      _dialogField(nameController, 'Exam Name', 'e.g. Final Theory Exam'),
                      const SizedBox(height: 12),

                      // Subject dropdown or text field
                      subjects.isNotEmpty
                          ? DropdownButtonFormField<String>(
                              value: subjects.contains(subjectController.text) ? subjectController.text : null,
                              decoration: InputDecoration(
                                labelText: 'Subject',
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.04),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              dropdownColor: AuraColors.background,
                              items: subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (val) => subjectController.text = val ?? '',
                            )
                          : _dialogField(subjectController, 'Subject', 'e.g. Operating Systems'),
                      const SizedBox(height: 12),

                      // Date picker
                      GestureDetector(
                        onTap: () async {
                          final picked = await showGoogleCalendarDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setStateDialog(() => selectedDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.12)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: AuraColors.primary, size: 18),
                              const SizedBox(width: 10),
                              Text(
                                '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      _dialogField(descController, 'Description (Optional)', 'e.g. Covers Unit 1-4'),
                      const SizedBox(height: 12),

                      // Reminder toggle
                      Row(
                        children: [
                          Switch(
                            value: reminderSet,
                            activeColor: AuraColors.primary,
                            onChanged: (val) => setStateDialog(() => reminderSet = val),
                          ),
                          const SizedBox(width: 8),
                          const Text('Set reminder (1 day before)', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                      if (reminderSet) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Notification Time', style: TextStyle(fontSize: 12)),
                          subtitle: Text(reminderTime, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                          trailing: const Icon(Icons.access_alarm, color: AuraColors.primary, size: 20),
                          onTap: () async {
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (pickedTime != null) {
                              setStateDialog(() {
                                reminderTime = '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel', style: TextStyle(color: AuraColors.textMuted)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AuraColors.primary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () async {
                                final name = nameController.text.trim();
                                final subject = subjectController.text.trim();
                                if (name.isEmpty || subject.isEmpty) return;

                                final student = ref.read(authProvider);
                                if (student == null) return;

                                Navigator.pop(ctx);

                                await ref.read(examsProvider.notifier).add(
                                  student.id,
                                  Exam(
                                    id: '',
                                    studentId: student.id,
                                    name: name,
                                    subject: subject,
                                    date: selectedDate,
                                    description: descController.text.trim(),
                                    reminderSet: reminderSet,
                                    reminderTime: reminderTime,
                                  ),
                                );
                              },
                              child: const Text(
                                'Add Exam',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _dialogField(TextEditingController controller, String label, String hint) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: AuraColors.textMuted, fontSize: 12),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AuraColors.primary),
        ),
      ),
    );
  }

  String _monthAbbr(int month) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
                    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[month - 1];
  }
}
