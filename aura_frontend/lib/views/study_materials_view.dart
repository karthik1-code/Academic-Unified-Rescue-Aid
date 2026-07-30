import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:aura_frontend/core/theme.dart';
import 'package:aura_frontend/services/api_service.dart';

class StudyMaterialsView extends ConsumerStatefulWidget {
  final String fileId;
  final String fileName;

  const StudyMaterialsView({
    Key? key,
    required this.fileId,
    required this.fileName,
  }) : super(key: key);

  @override
  ConsumerState<StudyMaterialsView> createState() => _StudyMaterialsViewState();
}

class _StudyMaterialsViewState extends ConsumerState<StudyMaterialsView> {
  bool _isLoading = true;
  Map<String, dynamic>? _materials;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ApiService.getStudyMaterials(widget.fileId);
      if (data != null) {
        setState(() {
          _materials = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = "Failed to load study materials. Backend may still be processing.";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = "Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuraColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'AI STUDY GUIDE: ${widget.fileName.toUpperCase()}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AuraColors.primary),
                  const SizedBox(height: 20),
                  Text(
                    'AI is analyzing your document...',
                    style: TextStyle(color: AuraColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AuraColors.absent),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadMaterials,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionHeader('SUMMARY', Icons.summarize_outlined),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AuraTheme.glassDecoration(),
                        child: Text(
                          _materials?['summary'] ?? 'No summary available.',
                          style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.white),
                        ),
                      ).animate().fadeIn(duration: 400.ms),

                      const SizedBox(height: 24),
                      _buildSectionHeader('FLASHCARDS', Icons.quiz_outlined),
                      const SizedBox(height: 12),
                      _buildFlashcards(_materials?['flashcards'] ?? []),

                      const SizedBox(height: 24),
                      _buildSectionHeader('PRACTICE MCQS', Icons.checklist_outlined),
                      const SizedBox(height: 12),
                      _buildMCQs(_materials?['mcqs'] ?? []),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AuraColors.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AuraColors.primary,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildFlashcards(List<dynamic> cards) {
    if (cards.isEmpty) return const Text('No flashcards generated.');
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        itemBuilder: (context, index) {
          final card = cards[index];
          return Container(
            width: 250,
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AuraColors.secondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AuraColors.secondary.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  card['front'] ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Divider(height: 24, color: Colors.white10),
                Text(
                  card['back'] ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AuraColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ).animate().fadeIn(delay: Duration(milliseconds: 100 * index));
        },
      ),
    );
  }

  Widget _buildMCQs(List<dynamic> mcqs) {
    if (mcqs.isEmpty) return const Text('No MCQs generated.');
    return Column(
      children: mcqs.asMap().entries.map((entry) {
        final index = entry.key;
        final mcq = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: AuraTheme.glassDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Q${index + 1}: ${mcq['question']}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              ...(mcq['options'] as List? ?? []).map((opt) {
                final key = opt['key'];
                final text = opt['text'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(key, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                );
              }).toList(),
              const Divider(color: Colors.white10, height: 24),
              Text(
                'Correct Answer: ${mcq['correct_key']}',
                style: const TextStyle(color: AuraColors.present, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                mcq['explanation'] ?? '',
                style: const TextStyle(color: AuraColors.textMuted, fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: 150 * index));
      }).toList(),
    );
  }
}
