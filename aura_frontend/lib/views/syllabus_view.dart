import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_frontend/core/theme.dart';
import 'package:aura_frontend/providers/providers.dart';
import 'package:aura_frontend/models/models.dart';
import 'package:go_router/go_router.dart';
import 'package:aura_frontend/core/google_calendar_picker.dart';
import 'package:aura_frontend/services/local_storage.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SyllabusView extends ConsumerStatefulWidget {
  const SyllabusView({Key? key}) : super(key: key);

  @override
  ConsumerState<SyllabusView> createState() => _SyllabusViewState();
}

class _SyllabusViewState extends ConsumerState<SyllabusView> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool _showGreeting = true;
  int? _expandedUnitId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final student = ref.read(authProvider);
      if (student != null) {
        ref.read(syllabusProvider.notifier).load(student.id);
      }
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Widget _buildStatusCheckbox({
    required String label,
    required bool isChecked,
    required Color color,
    required VoidCallback onChanged,
  }) {
    return InkWell(
      onTap: onChanged,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: isChecked ? color : Colors.white.withOpacity(0.15),
                  width: 1.5,
                ),
                color: isChecked ? color.withOpacity(0.12) : Colors.transparent,
              ),
              child: isChecked
                  ? Icon(
                      Icons.check,
                      size: 11,
                      color: color,
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                color: isChecked ? Colors.white : AuraColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUnitDialog(BuildContext context, SyllabusUnit unit, String studentId) {
    final titleController = TextEditingController(text: unit.title);
    final descController = TextEditingController(text: unit.description);
    String completionDateStr = unit.completionDate ?? '';
    String selectedStatus = unit.status;

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
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Customize Syllabus Unit',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: titleController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Unit Title',
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.02),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: descController,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Unit Description (Topics)',
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.02),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    
                    // Status Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      dropdownColor: AuraColors.background,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Syllabus Status',
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.02),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'pending', child: Text('Not Started')),
                        DropdownMenuItem(value: 'learning', child: Text('In Progress')),
                        DropdownMenuItem(value: 'completed', child: Text('Completed')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() {
                            selectedStatus = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    
                    // Completion Date Picker
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Completion Date', style: TextStyle(fontSize: 12, color: AuraColors.textMuted)),
                      subtitle: Text(
                        completionDateStr.isEmpty ? 'Not set' : completionDateStr,
                        style: const TextStyle(fontSize: 13, color: Colors.white),
                      ),
                      trailing: const Icon(Icons.calendar_month, color: AuraColors.primary),
                      onTap: () async {
                        final picked = await showGoogleCalendarDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2025),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setStateDialog(() {
                            completionDateStr = picked.toIso8601String().substring(0, 10);
                          });
                        }
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
                            ref.read(syllabusProvider.notifier).editUnit(
                              unit.id,
                              titleController.text.trim(),
                              descController.text.trim(),
                              selectedStatus,
                              completionDateStr,
                              studentId,
                            );
                            Navigator.pop(context);
                          },
                          child: const Text('Save Unit'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = ref.watch(authProvider);
    final rawSyllabusList = ref.watch(syllabusProvider);

    // Deduplicate syllabus subjects by name
    final uniqueSyllabusMap = <String, SubjectSyllabus>{};
    for (var s in rawSyllabusList) {
      uniqueSyllabusMap[s.subjectName.trim().toLowerCase()] = s;
    }
    final syllabusList = uniqueSyllabusMap.values.toList();

    if (student == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (syllabusList.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'SYLLABUS PLANNER',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AuraColors.primary, letterSpacing: 2),
                        ),
                        SizedBox(height: 4),
                        Text('Syllabus Progress Tracker', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: AuraTheme.glassDecoration(borderColor: AuraColors.primary),
                  child: Column(
                    children: [
                      const Icon(Icons.menu_book, size: 48, color: AuraColors.primary),
                      const SizedBox(height: 16),
                      const Text(
                        'No Subjects Configured',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'You must onboard your college subjects before you can log study targets or track syllabus units progress.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AuraColors.textMuted, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AuraColors.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => context.go('/onboarding'),
                        child: const Text('Start Setup Onboarding', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Dynamic TabController setup
    if (_tabController == null || _tabController!.length != syllabusList.length) {
      _tabController = TabController(length: syllabusList.length, vsync: this);
    }

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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SYLLABUS PLANNER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AuraColors.primary,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Syllabus & Units Tracker',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          'Customize units and track completion progress.',
                          style: TextStyle(color: AuraColors.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                ],
              ),
            ),

            if (_showGreeting)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                padding: const EdgeInsets.all(16.0),
                decoration: AuraTheme.glassDecoration(borderColor: AuraColors.primary.withOpacity(0.3)),
                child: Row(
                  children: [
                    const Icon(Icons.wb_sunny_outlined, color: AuraColors.primary, size: 24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Welcome to Syllabus Planner!',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'You can track your unit-wise progress and study targets here.',
                            style: TextStyle(color: AuraColors.textMuted, fontSize: 11.5, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: AuraColors.textMuted),
                      onPressed: () => setState(() => _showGreeting = false),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05),

            // Tab bar
            TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AuraColors.primary,
              labelColor: Colors.white,
              unselectedLabelColor: AuraColors.textMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: syllabusList.map((s) => Tab(text: s.subjectName)).toList(),
            ),

            // Tab view
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: syllabusList.map((subjectSyllabus) {
                  final compUnits = subjectSyllabus.units.where((u) => u.status == 'completed').length;
                  final totalUnits = subjectSyllabus.units.length;
                  final progress = totalUnits > 0 ? compUnits / totalUnits : 0.0;
                  
                  // Simple recommendation
                  String recommendation = "Aim to complete 1 unit every 3 weeks. You are making steady progress!";
                  if (progress < 0.25) {
                    recommendation = "You have just started! Focus on Unit 1 basics. Ask AURA AI: 'Explain difficult concepts in ${subjectSyllabus.subjectName}' to get started.";
                  } else if (progress < 0.75) {
                    recommendation = "You are in the core learning phase. Start attempting previous year question papers for the completed units.";
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Progress card
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: AuraTheme.glassDecoration(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Subject Progress', style: TextStyle(fontSize: 12, color: AuraColors.textMuted)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${(progress * 100).round()}% Completed',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AuraColors.primary),
                                  ),
                                ],
                              ),
                              Text('$compUnits / $totalUnits Units Done', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Units list
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: subjectSyllabus.units.length,
                          itemBuilder: (context, idx) {
                            final unit = subjectSyllabus.units[idx];
                            
                             final isExpanded = _expandedUnitId == unit.id;
                             final isReviewActive = LocalStorageService.isReviewLater(unit.id);
                             
                             Color statusColor = Colors.white.withOpacity(0.02);
                             Color borderGlowColor = Colors.white.withOpacity(0.08);
                             List<BoxShadow>? cardShadow;

                             if (unit.status == 'learning') {
                               statusColor = Colors.amber.withOpacity(0.08);
                               borderGlowColor = Colors.amber.withOpacity(0.65);
                               cardShadow = [
                                 BoxShadow(
                                   color: Colors.amber.withOpacity(0.12),
                                   blurRadius: 10,
                                   spreadRadius: 0,
                                 ),
                               ];
                             } else if (unit.status == 'completed') {
                               statusColor = AuraColors.primary.withOpacity(0.08);
                               borderGlowColor = AuraColors.primary.withOpacity(0.65);
                               cardShadow = [
                                 BoxShadow(
                                   color: AuraColors.primary.withOpacity(0.12),
                                   blurRadius: 10,
                                   spreadRadius: 0,
                                 ),
                               ];
                             }
                             
                             return GestureDetector(
                               onTap: () {
                                 setState(() {
                                   _expandedUnitId = isExpanded ? null : unit.id;
                                 });
                               },
                               child: MouseRegion(
                                 cursor: SystemMouseCursors.click,
                                 child: AnimatedContainer(
                                   duration: const Duration(milliseconds: 250),
                                   margin: const EdgeInsets.symmetric(vertical: 8),
                                   padding: const EdgeInsets.all(16),
                                   decoration: BoxDecoration(
                                     color: statusColor,
                                     borderRadius: BorderRadius.circular(16),
                                     border: Border.all(
                                       color: borderGlowColor,
                                       width: unit.status != 'pending' && unit.status != 'none' ? 2.0 : 1.2,
                                     ),
                                     boxShadow: cardShadow,
                                   ),
                                   child: Column(
                                     crossAxisAlignment: CrossAxisAlignment.stretch,
                                     children: [
                                       Row(
                                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                         children: [
                                           Expanded(
                                             child: Column(
                                               crossAxisAlignment: CrossAxisAlignment.start,
                                               children: [
                                                 Row(
                                                   children: [
                                                     Expanded(
                                                       child: Text(
                                                         unit.title,
                                                         style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                                         overflow: TextOverflow.ellipsis,
                                                       ),
                                                     ),
                                                     if (isReviewActive) ...[
                                                       const SizedBox(width: 8),
                                                       Container(
                                                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                         decoration: BoxDecoration(
                                                           color: Colors.amber.withOpacity(0.15),
                                                           borderRadius: BorderRadius.circular(4),
                                                           border: Border.all(color: Colors.amber.withOpacity(0.3), width: 0.5),
                                                         ),
                                                         child: const Text(
                                                           '📌 QUEUE',
                                                           style: TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.bold),
                                                         ),
                                                       ),
                                                     ],
                                                   ],
                                                 ),
                                                 if (unit.completionDate != null && unit.completionDate!.isNotEmpty) ...[
                                                   const SizedBox(height: 6),
                                                   Text(
                                                     'Completion Target: ${unit.completionDate}',
                                                     style: const TextStyle(color: AuraColors.present, fontSize: 10, fontWeight: FontWeight.bold),
                                                   ),
                                                 ],
                                               ],
                                             ),
                                           ),
                                           Row(
                                             mainAxisSize: MainAxisSize.min,
                                             children: [
                                               IconButton(
                                                 icon: const Icon(Icons.edit_note_outlined, color: AuraColors.primary, size: 20),
                                                 tooltip: 'Edit Unit Target',
                                                 onPressed: () => _showEditUnitDialog(context, unit, student.id),
                                               ),
                                             ],
                                           )
                                         ],
                                       ),
                                       const SizedBox(height: 14),
                                       
                                       // Expandable Topics and Revision section
                                       if (isExpanded) ...[
                                         const Divider(color: Colors.white10),
                                         const SizedBox(height: 8),
                                         const Text(
                                           'Topics & Syllabus Description:',
                                           style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AuraColors.secondary),
                                         ),
                                         const SizedBox(height: 4),
                                         Text(
                                           unit.description.isNotEmpty ? unit.description : 'No detailed topics specified. Tap the Edit button to add details.',
                                           style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.white70),
                                         ),
                                         const SizedBox(height: 14),
                                         
                                         // Quick revision check-box
                                         StatefulBuilder(
                                           builder: (context, setStateLocal) {
                                             final isReview = LocalStorageService.isReviewLater(unit.id);
                                             return InkWell(
                                               onTap: () {
                                                 final newVal = !isReview;
                                                 LocalStorageService.toggleReviewLater(unit.id, newVal);
                                                 setState(() {}); // refresh list view
                                                 setStateLocal(() {}); // refresh checkbox
                                               },
                                               borderRadius: BorderRadius.circular(8),
                                               child: Container(
                                                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                 decoration: BoxDecoration(
                                                   color: isReview ? Colors.amber.withOpacity(0.06) : Colors.white.withOpacity(0.01),
                                                   borderRadius: BorderRadius.circular(8),
                                                   border: Border.all(
                                                     color: isReview ? Colors.amber.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                                                   ),
                                                 ),
                                                 child: Row(
                                                   children: [
                                                     Icon(
                                                       isReview ? Icons.check_box : Icons.check_box_outline_blank,
                                                       size: 18,
                                                       color: isReview ? Colors.amber : AuraColors.textMuted,
                                                     ),
                                                     const SizedBox(width: 8),
                                                     const Expanded(
                                                       child: Text(
                                                         'Add to pending syllabus queue (Study/Revision later)',
                                                         style: TextStyle(fontSize: 11, color: Colors.white),
                                                       ),
                                                     ),
                                                   ],
                                                 ),
                                               ),
                                             );
                                           },
                                         ),
                                         const SizedBox(height: 14),
                                       ],
                                       
                                       // Inline Row of 3 Checkboxes
                                       Row(
                                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                         children: [
                                           _buildStatusCheckbox(
                                             label: 'Not Started',
                                             isChecked: unit.status == 'pending',
                                             color: Colors.amber,
                                             onChanged: () {
                                               ref.read(syllabusProvider.notifier).updateUnit(
                                                 unit.id,
                                                 'pending',
                                                 student.id,
                                               );
                                             },
                                           ),
                                           _buildStatusCheckbox(
                                             label: 'In Progress',
                                             isChecked: unit.status == 'learning',
                                             color: Colors.amber,
                                             onChanged: () {
                                               ref.read(syllabusProvider.notifier).updateUnit(
                                                 unit.id,
                                                 'learning',
                                                 student.id,
                                               );
                                             },
                                           ),
                                           _buildStatusCheckbox(
                                             label: 'Completed',
                                             isChecked: unit.status == 'completed',
                                             color: AuraColors.primary,
                                             onChanged: () {
                                               ref.read(syllabusProvider.notifier).updateUnit(
                                                 unit.id,
                                                 'completed',
                                                 student.id,
                                               );
                                             },
                                           ),
                                         ],
                                       )
                                     ],
                                   ),
                                 ),
                               ),
                             );
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
