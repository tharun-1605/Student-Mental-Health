import 'package:flutter/material.dart';
import 'questionnaire_data.dart';
import 'screening_service.dart';

class ScreeningResultsPage extends StatelessWidget {
  final Questionnaire questionnaire;
  final List<int> scores;
  final ScoringResult result;

  const ScreeningResultsPage({
    super.key,
    required this.questionnaire,
    required this.scores,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment Results'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              questionnaire.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Total Score: ${result.totalScore}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: result.severityColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              result.severityDescription,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: result.severityColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              result.recommendation,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                // Save the screening result
                final screeningService = ScreeningService();
                final mentorId = await screeningService.getMentorIdForStudent();

                if (mentorId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mentor not found. Cannot save results.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                await screeningService.saveScreeningResult(
                  type: questionnaire.type,
                  scores: scores,
                  result: result,
                  mentorId: mentorId,
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Screening results saved successfully.'),
                    backgroundColor: Colors.green,
                  ),
                );

                Navigator.popUntil(context, (route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: result.severityColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Save Results'),
            ),
          ],
        ),
      ),
    );
  }
}
