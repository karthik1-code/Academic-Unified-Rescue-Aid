import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aura_frontend/core/theme.dart';
import 'package:aura_frontend/core/google_calendar_picker.dart';
import 'package:aura_frontend/services/auth_service.dart';
import 'package:aura_frontend/providers/providers.dart';

class OnboardingView extends ConsumerStatefulWidget {
  const OnboardingView({Key? key}) : super(key: key);

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  int _currentStep = 0;
  
  // Controllers
  final _nameController = TextEditingController();
  final _univController = TextEditingController();
  final _branchController = TextEditingController();
  final _yearController = TextEditingController();
  final _semController = TextEditingController();
  final _careerController = TextEditingController();
  
  double _attendanceTarget = 75.0;
  double _dailyStudyHours = 2.0;
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 120));

  // Subjects lists
  final List<Map<String, dynamic>> _subjects = [];

  String generateSubjectAcronym(String name) {
    final words = name.split(RegExp(r'[^a-zA-Z0-9]+'));
    final stopWords = {'and', 'or', 'of', 'to', 'for', 'with', 'in', 'on', 'at', 'by', 'a', 'an', 'the'};
    
    final buffer = StringBuffer();
    for (var word in words) {
      if (word.isEmpty) continue;
      if (words.length > 1 && stopWords.contains(word.toLowerCase())) {
        continue;
      }
      buffer.write(word[0].toUpperCase());
    }
    
    if (buffer.isEmpty) {
      for (var word in words) {
        if (word.isNotEmpty) {
          buffer.write(word[0].toUpperCase());
        }
      }
    }
    
    return buffer.toString();
  }

  final _subjectNameController = TextEditingController();
  final _facultyController = TextEditingController();
  int _subjectCredits = 3;

  // Weak/Strong subjects
  final List<String> _weakSubjects = [];
  final List<String> _strongSubjects = [];
  final _weakController = TextEditingController();
  final _strongController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _univController.dispose();
    _branchController.dispose();
    _yearController.dispose();
    _semController.dispose();
    _careerController.dispose();
    _subjectNameController.dispose();
    _facultyController.dispose();
    _weakController.dispose();
    _strongController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_nameController.text.isEmpty || _univController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out your Name and University details.')),
      );
      return;
    }

    final user = AuthService().currentUser;
    final uid = user?.uid ?? 'student_dev';

    final onboardData = {
      'id': uid,
      'name': _nameController.text,
      'university': _univController.text,
      'branch': _branchController.text,
      'year': _yearController.text,
      'semester': _semController.text,
      'semester_start': _startDate.toIso8601String().substring(0, 10),
      'semester_end': _endDate.toIso8601String().substring(0, 10),
      'attendance_target': _attendanceTarget,
      'daily_study_goal_hours': _dailyStudyHours,
      'career_goal': _careerController.text,
      'weak_subjects': _weakSubjects,
      'strong_subjects': _strongSubjects,
      'subjects': _subjects,
    };

    try {
      await ref.read(authProvider.notifier).onboard(onboardData);
      // Load initial state for the student using the actual UID
      ref.read(attendanceProvider.notifier).load(uid);
      ref.read(syllabusProvider.notifier).load(uid);
      ref.read(goalsProvider.notifier).load(uid);
      if (mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      debugPrint('Onboarding submit error (falling back to bypass): $e');
      ref.read(authProvider.notifier).setLocalProfile(onboardData);
      ref.read(attendanceProvider.notifier).load(uid);
      ref.read(syllabusProvider.notifier).load(uid);
      ref.read(goalsProvider.notifier).load(uid);
      if (mounted) {
        context.go('/dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuraColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.all(28.0),
              decoration: AuraTheme.glassDecoration(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo / Glow Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => AuraColors.auroraGradient.createShader(bounds),
                        child: const Icon(Icons.psychology, size: 40, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'AURA',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          foreground: Paint()
                            ..shader = AuraColors.auroraGradient.createShader(
                              const Rect.fromLTWH(0, 0, 200, 70),
                            ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Academic Unified Rescue Aid',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AuraColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  
                  // Step indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      final active = index == _currentStep;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: active ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: active ? AuraColors.primary : AuraColors.textMuted.withOpacity(0.4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),

                  // Forms based on current step
                  if (_currentStep == 0) _buildProfileStep(),
                  if (_currentStep == 1) _buildSubjectsStep(),
                  if (_currentStep == 2) _buildGoalsStep(),

                  const SizedBox(height: 32),

                  // Navigation buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentStep > 0)
                        TextButton(
                          onPressed: () => setState(() => _currentStep--),
                          child: const Text('Back', style: TextStyle(color: AuraColors.textMuted)),
                        )
                      else
                        const SizedBox(),
                      
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AuraColors.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        onPressed: () {
                          if (_currentStep < 2) {
                            setState(() => _currentStep++);
                          } else {
                            _submit();
                          }
                        },
                        child: Text(_currentStep < 2 ? 'Next' : 'Launch AURA'),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Tell us about yourself',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        _buildTextField(_nameController, 'Full Name', Icons.person_outline),
        const SizedBox(height: 16),
        _buildTextField(_univController, 'University / College Name', Icons.school_outlined),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildTextField(_branchController, 'Branch/Major', Icons.settings_ethernet)),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(_yearController, 'Year (e.g. 3rd)', Icons.history_edu)),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(_semController, 'Semester (e.g. 5th)', Icons.calendar_today_outlined)),
          ],
        ),
        const SizedBox(height: 16),
        // Date selectors
        Row(
          children: [
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sem Start Date', style: TextStyle(fontSize: 11, color: AuraColors.textMuted)),
                subtitle: Text('${_startDate.day}/${_startDate.month}/${_startDate.year}', style: const TextStyle(fontSize: 13, color: Colors.white)),
                trailing: const Icon(Icons.date_range, color: AuraColors.primary, size: 20),
                onTap: () async {
                  final picked = await showGoogleCalendarDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2025),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _startDate = picked);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sem End Date', style: TextStyle(fontSize: 11, color: AuraColors.textMuted)),
                subtitle: Text('${_endDate.day}/${_endDate.month}/${_endDate.year}', style: const TextStyle(fontSize: 13, color: Colors.white)),
                trailing: const Icon(Icons.date_range, color: AuraColors.primary, size: 20),
                onTap: () async {
                  final picked = await showGoogleCalendarDatePicker(
                    context: context,
                    initialDate: _endDate,
                    firstDate: DateTime(2025),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _endDate = picked);
                },
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildSubjectsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Configure enrolled subjects',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Subjects Logged
        Container(
          height: 160,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: _subjects.isEmpty
              ? const Center(child: Text('No subjects added yet.', style: TextStyle(color: AuraColors.textMuted)))
              : ListView.builder(
                  itemCount: _subjects.length,
                  itemBuilder: (context, index) {
                    final sub = _subjects[index];
                    return Card(
                      color: Colors.white.withOpacity(0.03),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 8,
                          backgroundColor: Color(int.parse(sub['color'])),
                        ),
                        title: Text('${sub['name']} (${sub['subtitle'] ?? ""})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${sub['credits']} credits • ${sub['faculty'] ?? "No faculty"}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AuraColors.absent, size: 18),
                          onPressed: () {
                            setState(() => _subjects.removeAt(index));
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 16),
        // Add new subject form
        _buildTextField(_subjectNameController, 'Subject Name (e.g. Operating Systems)', Icons.book_outlined),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTextField(_facultyController, 'Faculty Name (Optional)', Icons.face)),
            const SizedBox(width: 12),
            DropdownButton<int>(
              value: _subjectCredits,
              dropdownColor: AuraColors.background,
              items: [1, 2, 3, 4, 5].map((e) {
                return DropdownMenuItem(
                  value: e,
                  child: Text('$e Credits'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _subjectCredits = val);
              },
            )
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.08),
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            if (_subjectNameController.text.isNotEmpty) {
              final List<String> palette = ['0xFF00F0FF', '0xFFB5179E', '0xFFFFD166', '0xFF4A90E2', '0xFF00F5D4'];
              final color = palette[_subjects.length % palette.length];
              final name = _subjectNameController.text.trim();
              final acronym = generateSubjectAcronym(name);
              setState(() {
                _subjects.add({
                  'name': name,
                  'credits': _subjectCredits,
                  'faculty': _facultyController.text.isEmpty ? null : _facultyController.text.trim(),
                  'color': color,
                  'subtitle': acronym,
                });
                _subjectNameController.clear();
                _facultyController.clear();
              });
            }
          },
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Subject'),
        )
      ],
    );
  }

  Widget _buildGoalsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Target goals & weak subjects',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        // Attendance Threshold Slider
        Text('Attendance Target Requirement: ${_attendanceTarget.round()}%', style: const TextStyle(fontSize: 13)),
        Slider(
          value: _attendanceTarget,
          min: 50.0,
          max: 95.0,
          divisions: 9,
          activeColor: AuraColors.primary,
          onChanged: (val) => setState(() => _attendanceTarget = val),
        ),
        // Daily Study Target
        Text('Daily Study Target Hours: ${_dailyStudyHours.toStringAsFixed(1)} hrs', style: const TextStyle(fontSize: 13)),
        Slider(
          value: _dailyStudyHours,
          min: 1.0,
          max: 8.0,
          divisions: 14,
          activeColor: AuraColors.secondary,
          onChanged: (val) => setState(() => _dailyStudyHours = val),
        ),
        const SizedBox(height: 8),
        _buildTextField(_careerController, 'Career Goal (e.g. Cloud Engineer at Google)', Icons.star_border),
        const SizedBox(height: 16),
        // Weak subjects adder
        Row(
          children: [
            Expanded(child: _buildTextField(_weakController, 'Add Weak Subject', Icons.trending_down)),
            IconButton(
              icon: const Icon(Icons.add, color: AuraColors.primary),
              onPressed: () {
                if (_weakController.text.isNotEmpty) {
                  setState(() {
                    _weakSubjects.add(_weakController.text);
                    _weakController.clear();
                  });
                }
              },
            ),
          ],
        ),
        if (_weakSubjects.isNotEmpty)
          Wrap(
            spacing: 6,
            children: _weakSubjects.map((e) => Chip(
              label: Text(e, style: const TextStyle(fontSize: 11)),
              onDeleted: () => setState(() => _weakSubjects.remove(e)),
            )).toList(),
          ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AuraColors.primary, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.02),
        labelStyle: const TextStyle(color: AuraColors.textMuted, fontSize: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AuraColors.primary),
        ),
      ),
    );
  }
}
