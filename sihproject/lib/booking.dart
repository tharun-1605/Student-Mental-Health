import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedCounsellor;
  final TextEditingController _reasonController = TextEditingController();
  bool _isLoading = false;
  List<String> _counsellors = [];

  @override
  void initState() {
    super.initState();
    _fetchCounsellors();
    _setupFCM();
  }

  Future<void> _fetchCounsellors() async {
    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('mentors').get();
      setState(() {
        _counsellors = snapshot.docs.map((doc) => doc['name'] as String).toList();
      });
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _setupFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    String? token = await messaging.getToken();
    // Store token in Firestore for the user
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && token != null) {
      // Update token in 'students' collection for students
      final studentDoc = await FirebaseFirestore.instance.collection('students').doc(user.uid).get();
      if (studentDoc.exists) {
        await FirebaseFirestore.instance.collection('students').doc(user.uid).update({
          'fcmToken': token,
        });
      } else {
        // fallback to 'users' collection if needed
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'fcmToken': token,
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _bookSession() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null || _selectedCounsellor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('bookings').add({
          'studentId': user.uid,
          'counsellorName': _selectedCounsellor,
          'date': _selectedDate,
          'time': '${_selectedTime!.hour}:${_selectedTime!.minute}',
          'reason': _reasonController.text,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking request submitted successfully')),
        );

        // Reset form
        _formKey.currentState!.reset();
        setState(() {
          _selectedDate = null;
          _selectedTime = null;
          _selectedCounsellor = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to book session')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Counselling Session'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedCounsellor,
                decoration: const InputDecoration(labelText: 'Select Counsellor'),
                items: _counsellors.map((counsellor) {
                  return DropdownMenuItem(
                    value: counsellor,
                    child: Text(counsellor),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCounsellor = value;
                  });
                },
                validator: (value) => value == null ? 'Please select a counsellor' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedDate == null
                          ? 'No date selected'
                          : 'Date: ${_selectedDate!.toLocal().toString().split(' ')[0]}',
                    ),
                  ),
                  TextButton(
                    onPressed: () => _selectDate(context),
                    child: const Text('Select Date'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedTime == null
                          ? 'No time selected'
                          : 'Time: ${_selectedTime!.format(context)}',
                    ),
                  ),
                  TextButton(
                    onPressed: () => _selectTime(context),
                    child: const Text('Select Time'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(labelText: 'Reason for session'),
                maxLines: 3,
                validator: (value) => value == null || value.isEmpty
                    ? 'Please provide a reason'
                    : null,
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _bookSession,
                      child: const Text('Book Session'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
