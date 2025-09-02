import 'package:flutter/material.dart';

class MentorHomePage extends StatelessWidget {
  const MentorHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mentor Home'),
      ),
      body: const Center(
        child: Text('Welcome Mentor!'),
      ),
    );
  }
}
