import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:aura_frontend/core/theme.dart';
import 'package:aura_frontend/providers/providers.dart';
import 'package:aura_frontend/models/models.dart';
import 'package:go_router/go_router.dart';
import 'package:aura_frontend/core/google_calendar_picker.dart';

class AssignmentsView extends ConsumerStatefulWidget {
  const AssignmentsView({Key? key}) : super(key: key);

  @override
  ConsumerState<AssignmentsView> createState() => _AssignmentsViewState();
}

class _AssignmentsViewState extends ConsumerState<AssignmentsView> {
  String _filter = 'All'; // 'All', 'Pending', 'Submitted'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final student = ref.read(authProvider);
      if (student != null) {
        ref.read(assignmentsProvider.notifier).listenToStream(student.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final assignments = ref.watch(assignmentsProvider);
    final filtered = _filter == 'All'
        ? assignments
        : _filter == 'Pending'
        ? assignments.where((a) => !a.isSubmitted).toList()
        : assignments.where((a) => a.isSubmitted).toList();

    final pending = assignments.where((a) => !a.isSubmitted).length;
    final overdue = assignments.where((a) => a.isOverdue).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                              'ASSIGNMENT TRACKER',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AuraColors.secondary,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Assignments',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Stats row
                  Row(
                    children: [
                      _buildStatChip(
                        '${assignments.length} Total',
                        Colors.white24,
                      ),
                      const SizedBox(width: 8),
                      _buildStatChip('$pending Pending', AuraColors.leave),
                      const SizedBox(width: 8),
                      if (overdue > 0)
                        _buildStatChip('$overdue Overdue', AuraColors.absent),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Pending', 'Submitted'].map((f) {
                        final active = _filter == f;
                        return GestureDetector(
                          onTap: () => setState(() => _filter = f),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              gradient: active
                                  ? AuraColors.auroraGradient
                                  : null,
                              color: active
                                  ? null
                                  : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: active
                                    ? Colors.transparent
                                    : Colors.white.withOpacity(0.08),
                              ),
                            ),
                            child: Text(
                              f,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: active
                                    ? Colors.black
                                    : AuraColors.textMuted,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) =>
                          _buildAssignmentCard(filtered[i], i),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAssignmentDialog(context),
        backgroundColor: AuraColors.secondary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Assignment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 72,
            color: AuraColors.textMuted.withOpacity(0.3),
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: 16),
          Text(
            _filter == 'All' ? 'No assignments yet' : 'No $_filter assignments',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AuraColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap + to track an assignment',
            style: TextStyle(color: AuraColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(Assignment assignment, int index) {
    Color priorityColor;
    switch (assignment.priority) {
      case 'High':
        priorityColor = AuraColors.absent;
        break;
      case 'Low':
        priorityColor = AuraColors.present;
        break;
      default:
        priorityColor = AuraColors.leave;
    }

    final daysLeft = assignment.daysUntilDue;
    Color urgencyColor;
    String urgencyLabel;
    if (assignment.isSubmitted) {
      urgencyColor = AuraColors.present;
      urgencyLabel = 'Submitted';
    } else if (assignment.isOverdue) {
      urgencyColor = AuraColors.absent;
      urgencyLabel = 'OVERDUE';
    } else if (daysLeft == 0) {
      urgencyColor = AuraColors.absent;
      urgencyLabel = 'Due Today!';
    } else if (daysLeft == 1) {
      urgencyColor = AuraColors.leave;
      urgencyLabel = 'Due Tomorrow';
    } else if (daysLeft <= 3) {
      urgencyColor = AuraColors.leave;
      urgencyLabel = 'Due in $daysLeft days';
    } else {
      urgencyColor = AuraColors.present;
      urgencyLabel = 'Due in $daysLeft days';
    }

    final student = ref.read(authProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(assignment.id),
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
              title: Text('Delete "${assignment.title}"?'),
              content: const Text(
                'This action cannot be undone.',
                style: TextStyle(color: AuraColors.textMuted),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AuraColors.absent,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        },
        onDismissed: (_) {
          if (student != null) {
            ref
                .read(assignmentsProvider.notifier)
                .delete(student.id, assignment.id);
          }
        },
        child:
            GestureDetector(
                  onTap: () {
                    if (student != null) {
                      HapticFeedback.lightImpact();
                      ref
                          .read(assignmentsProvider.notifier)
                          .toggle(student.id, assignment.id, assignment.status);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: assignment.isSubmitted
                          ? Colors.white.withOpacity(0.015)
                          : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: assignment.isSubmitted
                            ? AuraColors.present.withOpacity(0.15)
                            : priorityColor.withOpacity(0.2),
                        width: 1.2,
                      ),
                      boxShadow: assignment.isOverdue
                          ? [
                              BoxShadow(
                                color: AuraColors.absent.withOpacity(0.12),
                                blurRadius: 12,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        // Priority indicator
                        Container(
                          width: 4,
                          height: 60,
                          decoration: BoxDecoration(
                            color: priorityColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                assignment.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: assignment.isSubmitted
                                      ? AuraColors.textMuted
                                      : Colors.white,
                                  decoration: assignment.isSubmitted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AuraColors.secondary.withOpacity(
                                        0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      assignment.subject,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AuraColors.secondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: priorityColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      assignment.priority,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: priorityColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${assignment.dueDate.day}/${assignment.dueDate.month}/${assignment.dueDate.year}',
                                style: const TextStyle(
                                  color: AuraColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Status/Urgency badge
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: urgencyColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: urgencyColor.withOpacity(0.25),
                                ),
                              ),
                              child: Text(
                                urgencyLabel,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: urgencyColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to toggle',
                              style: TextStyle(
                                fontSize: 9,
                                color: AuraColors.textMuted.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
                .animate(delay: Duration(milliseconds: 60 * index))
                .fadeIn(duration: 300.ms)
                .slideX(begin: 0.05),
      ),
    );
  }

  void _showAddAssignmentDialog(BuildContext context) {
    final titleController = TextEditingController();
    final subjectController = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 3));
    String priority = 'Medium';
    bool reminderSet = true;
    String reminderTime = '09:00';

    final attendance = ref.read(attendanceProvider);
    final subjects =
        attendance?.subjectsDetail.map((s) => s.subjectName).toList() ?? [];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: AuraTheme.glassDecoration(
                  borderColor: AuraColors.secondary,
                ),
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
                              color: AuraColors.secondary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.assignment,
                              color: AuraColors.secondary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Add Assignment',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      _dialogField(
                        titleController,
                        'Assignment Title',
                        'e.g. Lab Report Unit 3',
                      ),
                      const SizedBox(height: 12),

                      subjects.isNotEmpty
                          ? DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'Subject',
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.04),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              dropdownColor: AuraColors.background,
                              items: subjects
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  subjectController.text = val ?? '',
                            )
                          : _dialogField(
                              subjectController,
                              'Subject',
                              'e.g. Computer Networks',
                            ),
                      const SizedBox(height: 12),

                      // Due Date picker
                      GestureDetector(
                        onTap: () async {
                          final picked = await showGoogleCalendarDatePicker(
                            context: context,
                            initialDate: dueDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null)
                            setStateDialog(() => dueDate = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.event,
                                color: AuraColors.secondary,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Due: ${dueDate.day}/${dueDate.month}/${dueDate.year}',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Priority selector
                      const Text(
                        'Priority',
                        style: TextStyle(
                          fontSize: 12,
                          color: AuraColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: ['High', 'Medium', 'Low'].map((p) {
                          final selected = priority == p;
                          Color c = p == 'High'
                              ? AuraColors.absent
                              : p == 'Medium'
                              ? AuraColors.leave
                              : AuraColors.present;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setStateDialog(() => priority = p),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? c.withOpacity(0.2)
                                      : Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: selected
                                        ? c
                                        : Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                child: Text(
                                  p,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: selected ? c : AuraColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Switch(
                            value: reminderSet,
                            activeColor: AuraColors.secondary,
                            onChanged: (val) =>
                                setStateDialog(() => reminderSet = val),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Reminder (1 day before)',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      if (reminderSet) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Notification Time', style: TextStyle(fontSize: 12)),
                          subtitle: Text(reminderTime, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                          trailing: const Icon(Icons.access_alarm, color: AuraColors.secondary, size: 20),
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
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: AuraColors.textMuted),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AuraColors.secondary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () async {
                                final title = titleController.text.trim();
                                final subject = subjectController.text.trim();
                                if (title.isEmpty || subject.isEmpty) return;

                                final student = ref.read(authProvider);
                                if (student == null) return;

                                Navigator.pop(ctx);
                                await ref
                                    .read(assignmentsProvider.notifier)
                                    .add(
                                      student.id,
                                      Assignment(
                                        id: '',
                                        studentId: student.id,
                                        title: title,
                                        subject: subject,
                                        dueDate: dueDate,
                                        priority: priority,
                                        status: 'pending',
                                        reminderSet: reminderSet,
                                        reminderTime: reminderTime,
                                      ),
                                    );
                              },
                              child: const Text(
                                'Add Assignment',
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

  Widget _dialogField(
    TextEditingController controller,
    String label,
    String hint,
  ) {
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
          borderSide: const BorderSide(color: AuraColors.secondary),
        ),
      ),
    );
  }
}
