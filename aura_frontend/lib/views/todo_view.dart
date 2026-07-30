import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_frontend/core/theme.dart';
import 'package:aura_frontend/providers/providers.dart';
import 'package:aura_frontend/models/models.dart';
import 'package:aura_frontend/core/google_calendar_picker.dart';

class TodoView extends ConsumerStatefulWidget {
  const TodoView({Key? key}) : super(key: key);

  @override
  ConsumerState<TodoView> createState() => _TodoViewState();
}

class _TodoViewState extends ConsumerState<TodoView> {
  String _selectedCategory = 'All';
  String _selectedPriority = 'All';
  bool _isLoadingOptimizations = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final student = ref.read(authProvider);
      if (student != null) {
        ref.read(tasksProvider.notifier).load(student.id);
      }
    });
  }

  void _showAddTaskDialog(BuildContext context, String studentId) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String priority = 'Medium';
    String category = 'Study';
    String dateStr = DateTime.now().toIso8601String().substring(0, 10);
    String startTime = '09:00';
    String endTime = '10:00';
    bool reminder = true;
    String reminderTime = '09:00';
    String repeat = 'None';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: AuraTheme.glassDecoration(borderColor: AuraColors.primary),
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Create Productivity Task',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: titleController,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Task Title',
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.02),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descController,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Description / Details',
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.02),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: priority,
                              dropdownColor: AuraColors.background,
                              style: const TextStyle(fontSize: 13, color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Priority',
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.02),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'High', child: Text('High')),
                                DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                                DropdownMenuItem(value: 'Low', child: Text('Low')),
                              ],
                              onChanged: (val) {
                                if (val != null) setStateDialog(() => priority = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: category,
                              dropdownColor: AuraColors.background,
                              style: const TextStyle(fontSize: 13, color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Category',
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.02),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Study', child: Text('Study')),
                                DropdownMenuItem(value: 'Exam', child: Text('Exam')),
                                DropdownMenuItem(value: 'Assignment', child: Text('Assignment')),
                                DropdownMenuItem(value: 'Personal', child: Text('Personal')),
                              ],
                              onChanged: (val) {
                                if (val != null) setStateDialog(() => category = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Target Date', style: TextStyle(fontSize: 11, color: AuraColors.textMuted)),
                        subtitle: Text(dateStr, style: const TextStyle(fontSize: 13)),
                        trailing: const Icon(Icons.calendar_month, color: AuraColors.primary, size: 20),
                        onTap: () async {
                          final picked = await showGoogleCalendarDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2027),
                          );
                          if (picked != null) {
                            setStateDialog(() => dateStr = picked.toIso8601String().substring(0, 10));
                          }
                        },
                      ),
                      
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Start Time', style: TextStyle(fontSize: 11, color: AuraColors.textMuted)),
                              subtitle: Text(startTime, style: const TextStyle(fontSize: 13)),
                              trailing: const Icon(Icons.access_time, color: AuraColors.secondary, size: 18),
                              onTap: () async {
                                final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                                if (time != null) {
                                  setStateDialog(() => startTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}');
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('End Time', style: TextStyle(fontSize: 11, color: AuraColors.textMuted)),
                              subtitle: Text(endTime, style: const TextStyle(fontSize: 13)),
                              trailing: const Icon(Icons.access_time_filled, color: AuraColors.secondary, size: 18),
                              onTap: () async {
                                final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                                if (time != null) {
                                  setStateDialog(() => endTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}');
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Push Notification Reminder', style: TextStyle(fontSize: 12)),
                        value: reminder,
                        activeColor: AuraColors.primary,
                        onChanged: (val) => setStateDialog(() => reminder = val),
                      ),
                      
                      if (reminder) ...[
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
                      
                      DropdownButtonFormField<String>(
                        value: repeat,
                        dropdownColor: AuraColors.background,
                        style: const TextStyle(fontSize: 13, color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Repeat Interval',
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.02),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'None', child: Text('None')),
                          DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                          DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                        ],
                        onChanged: (val) {
                          if (val != null) setStateDialog(() => repeat = val);
                        },
                      ),
                      const SizedBox(height: 24),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel', style: TextStyle(color: AuraColors.textMuted)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AuraColors.primary,
                              foregroundColor: Colors.black,
                            ),
                            onPressed: () {
                              ref.read(tasksProvider.notifier).add({
                                'student_id': studentId,
                                'title': titleController.text.trim(),
                                'description': descController.text.trim(),
                                'priority': priority,
                                'category': category,
                                'date': dateStr,
                                'start_time': startTime,
                                'end_time': endTime,
                                'reminder': reminder,
                                'repeat': repeat,
                                'reminder_time': reminderTime,
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('Add Task'),
                          ),
                        ],
                      )
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

  void _triggerAIScheduling(String studentId, List<Task> tasks) async {
    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tasks available to plan. Add some first!')),
      );
      return;
    }

    setState(() => _isLoadingOptimizations = true);
    
    // Simulate Gemini schedule generation
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: AuraColors.background,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: const [
                    Icon(Icons.auto_awesome, color: AuraColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text('AURA AI Task Optimization', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Based on your priorities, category filters, and subject credits, I suggest reorganizing your study slots as follows:',
                  style: TextStyle(color: AuraColors.textMuted, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 16),
                _buildOptimizationStep('1', 'Tackle High Priority items first during peak energy (09:00 - 11:00 AM).'),
                _buildOptimizationStep('2', 'Dedicate a 45-minute sprint for Syllabus topics with lower progress.'),
                _buildOptimizationStep('3', 'Take 10-minute active recall breaks to build persistent memory.'),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AuraColors.primary,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Apply AI Adjustments'),
                )
              ],
            ),
          );
        },
      );
    }
    setState(() => _isLoadingOptimizations = false);
  }

  Widget _buildOptimizationStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 9,
            backgroundColor: AuraColors.primary.withOpacity(0.2),
            child: Text(number, style: const TextStyle(fontSize: 9, color: AuraColors.primary, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    if (priority == 'High') return AuraColors.absent;
    if (priority == 'Medium') return AuraColors.leave;
    return AuraColors.present;
  }

  @override
  Widget build(BuildContext context) {
    final student = ref.watch(authProvider);
    final allTasks = ref.watch(tasksProvider);

    if (student == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Filter tasks
    final filteredTasks = allTasks.where((t) {
      final matchCat = _selectedCategory == 'All' || t.category == _selectedCategory;
      final matchPri = _selectedPriority == 'All' || t.priority == _selectedPriority;
      return matchCat && matchPri;
    }).toList();

    final completedTasksCount = filteredTasks.where((t) => t.isCompleted).length;
    final double completionPct = filteredTasks.isNotEmpty 
        ? completedTasksCount / filteredTasks.length 
        : 1.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DAILY SCHEDULE & GOALS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AuraColors.primary,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'To-Do & Tasks Manager',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: AuraColors.primary, size: 28),
                    onPressed: () => _showAddTaskDialog(context, student.id),
                  )
                ],
              ),
            ),

            // Dynamic Progress highlight
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: AuraTheme.glassDecoration(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Goal Completion Progress', style: TextStyle(fontSize: 11, color: AuraColors.textMuted)),
                        const SizedBox(height: 6),
                        Text(
                          '${(completionPct * 100).round()}% Completed',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AuraColors.primary),
                        ),
                        Text('$completedTasksCount of ${filteredTasks.length} tasks resolved', style: const TextStyle(fontSize: 10.5, color: AuraColors.textMuted)),
                      ],
                    ),
                    
                    _isLoadingOptimizations
                        ? const CircularProgressIndicator(color: AuraColors.primary)
                        : ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AuraColors.secondary.withOpacity(0.12),
                              foregroundColor: AuraColors.secondary,
                              side: BorderSide(color: AuraColors.secondary.withOpacity(0.3)),
                            ),
                            onPressed: () => _triggerAIScheduling(student.id, filteredTasks),
                            icon: const Icon(Icons.auto_awesome, size: 14),
                            label: const Text('AI Plan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category Horizontal Tabs
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                children: ['All', 'Study', 'Exam', 'Assignment', 'Personal'].map((cat) {
                  final active = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? AuraColors.primary : Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: active ? AuraColors.primary : Colors.white10),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: active ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Priority filter tags
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: ['All', 'High', 'Medium', 'Low'].map((pri) {
                  final active = _selectedPriority == pri;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedPriority = pri),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      child: Text(
                        pri,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: active ? AuraColors.primary : AuraColors.textMuted,
                          decoration: active ? TextDecoration.underline : null,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Tasks List
            Expanded(
              child: filteredTasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.checklist, size: 50, color: AuraColors.textMuted.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          const Text('No tasks found.', style: TextStyle(color: AuraColors.textMuted)),
                          const Text('Add tasks using the + button.', style: TextStyle(color: AuraColors.textMuted, fontSize: 11.5)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      itemCount: filteredTasks.length,
                      itemBuilder: (context, idx) {
                        final task = filteredTasks[idx];
                        final priColor = _getPriorityColor(task.priority);
                        
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: AuraTheme.glassDecoration(
                            borderColor: task.isCompleted 
                                ? AuraColors.present.withOpacity(0.2) 
                                : Colors.white.withOpacity(0.06),
                          ),
                          child: Row(
                            children: [
                              // Checkbox
                              InkWell(
                                onTap: () => ref.read(tasksProvider.notifier).toggle(task.id, student.id),
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: task.isCompleted ? AuraColors.present : Colors.white30,
                                      width: 1.5,
                                    ),
                                    color: task.isCompleted ? AuraColors.present : Colors.transparent,
                                  ),
                                  child: task.isCompleted
                                      ? const Icon(Icons.check, size: 14, color: Colors.black)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              
                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                        color: task.isCompleted ? AuraColors.textMuted : Colors.white,
                                      ),
                                    ),
                                    if (task.description.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        task.description,
                                        style: const TextStyle(color: AuraColors.textMuted, fontSize: 11),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: priColor.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            task.priority.toUpperCase(),
                                            style: TextStyle(color: priColor, fontSize: 8, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${task.category} • ${task.startTime}-${task.endTime}',
                                          style: const TextStyle(fontSize: 9.5, color: AuraColors.textMuted),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                              
                              // Delete Button
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: Colors.redAccent.withOpacity(0.6), size: 20),
                                onPressed: () => ref.read(tasksProvider.notifier).delete(task.id, student.id),
                              )
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
