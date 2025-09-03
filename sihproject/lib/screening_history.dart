import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screening_service.dart';

class ScreeningHistoryPage extends StatefulWidget {
  const ScreeningHistoryPage({super.key});

  @override
  State<ScreeningHistoryPage> createState() => _ScreeningHistoryPageState();
}

class _ScreeningHistoryPageState extends State<ScreeningHistoryPage> {
  final ScreeningService _screeningService = ScreeningService();
  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _screeningService.getScreeningHistory();
  }

  String _formatDate(DateTime date) {
    return DateFormat.yMMMd().format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screening History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading history: ${snapshot.error}'),
            );
          }
          final history = snapshot.data ?? [];
          if (history.isEmpty) {
            return const Center(
              child: Text('No screening history found.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              final timestamp = item['timestamp'] as Timestamp?;
              final date = timestamp != null ? timestamp.toDate() : null;
              final formattedDate = date != null ? _formatDate(date) : 'Unknown date';
              final type = item['questionnaireType'] ?? 'Unknown';
              final severity = item['severity'] ?? 'Unknown';
              final totalScore = item['totalScore'] ?? 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(
                    Icons.assessment,
                    color: severity == 'severe' ? Colors.red : Colors.blue,
                  ),
                  title: Text('$type Screening'),
                  subtitle: Text('Score: $totalScore • Severity: $severity'),
                  trailing: Text(formattedDate),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
