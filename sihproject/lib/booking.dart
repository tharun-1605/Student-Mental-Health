import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'fcm_service.dart';

class BookingStatusPage extends StatefulWidget {
  const BookingStatusPage({super.key});

  @override
  State<BookingStatusPage> createState() => _BookingStatusPageState();
}

class _BookingStatusPageState extends State<BookingStatusPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _bookings = [];

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final bookingsQuery = await FirebaseFirestore.instance
          .collection('bookings')
          .where('studentId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> bookings = [];
      for (var doc in bookingsQuery.docs) {
        final bookingData = doc.data();
        bookingData['id'] = doc.id;

        // Get mentor name
        final mentorDoc = await FirebaseFirestore.instance
            .collection('mentors')
            .where('name', isEqualTo: bookingData['counsellorName'])
            .get();

        if (mentorDoc.docs.isNotEmpty) {
          bookingData['mentorCollege'] = mentorDoc.docs.first.data()['college'] ?? 'Unknown';
        } else {
          bookingData['mentorCollege'] = 'Unknown';
        }

        bookings.add(bookingData);
      }

      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load bookings: $e')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadBookings();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No bookings yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your booking requests will appear here.',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _bookings.length,
                  itemBuilder: (context, index) {
                    final booking = _bookings[index];
                    final timestamp = booking['createdAt'] as Timestamp?;
                    final dateTime = timestamp?.toDate();
                    final formattedDate = dateTime != null
                        ? '${dateTime.day}/${dateTime.month}/${dateTime.year}'
                        : 'Unknown';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person, color: Colors.blue, size: 24),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    booking['counsellorName'] ?? 'Mentor',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(booking['status'] ?? 'pending'),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    (booking['status'] ?? 'pending').toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'College: ${booking['mentorCollege']}',
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Date: ${booking['date']} at ${booking['time']}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Reason: ${booking['reason']}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            if (booking['meetLink'] != null && booking['meetLink'].isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Google Meet Link:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.green,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      booking['meetLink'],
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.blue,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),
                            Text(
                              'Requested: $formattedDate',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

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
    await FCMService().initialize();
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
        final bookingRef = await FirebaseFirestore.instance.collection('bookings').add({
          'studentId': user.uid,
          'counsellorName': _selectedCounsellor,
          'date': _selectedDate,
          'time': '${_selectedTime!.hour}:${_selectedTime!.minute}',
          'reason': _reasonController.text,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Get student name for notification
        final studentDoc = await FirebaseFirestore.instance.collection('students').doc(user.uid).get();
        final studentName = studentDoc.data()?['name'] ?? 'Student';

        // Send booking request notification
        await FCMService().sendBookingRequestNotification(_selectedCounsellor!, studentName, bookingRef.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking request submitted successfully')),
          );
        }

        // Reset form
        _formKey.currentState!.reset();
        setState(() {
          _selectedDate = null;
          _selectedTime = null;
          _selectedCounsellor = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to book session')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
