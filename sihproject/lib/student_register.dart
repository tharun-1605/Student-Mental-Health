import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'student_home.dart';

class StudentRegisterPage extends StatefulWidget {
  const StudentRegisterPage({super.key});

  @override
  State<StudentRegisterPage> createState() => _StudentRegisterPageState();
}

class _StudentRegisterPageState extends State<StudentRegisterPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _rollNumberController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _selectedCollege;
  List<String> _colleges = [];
  bool _isLoading = false;
  bool _isLoadingColleges = true;
  String? _errorMessage;
  bool _obscurePassword = true;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _errorController;
  late AnimationController _loadingController;
  
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _errorAnimation;
  late Animation<double> _loadingAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _errorController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Initialize animations
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _errorAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _errorController,
      curve: Curves.elasticOut,
    ));

    _loadingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingController,
      curve: Curves.easeInOut,
    ));

    _fetchColleges();
    
    // Start entrance animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
  }

  Future<void> _fetchColleges() async {
    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('mentors').get();
      Set<String> collegeSet = {};
      for (var doc in snapshot.docs) {
        String college = doc['college'];
        if (college.isNotEmpty) {
          collegeSet.add(college);
        }
      }
      setState(() {
        _colleges = collegeSet.toList();
        _isLoadingColleges = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load colleges';
        _isLoadingColleges = false;
      });
      _errorController.forward().then((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _errorController.reverse();
        });
      });
    }
  }

  Future<void> _registerStudent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCollege == null) {
      setState(() {
        _errorMessage = 'Please select a college';
      });
      _errorController.forward().then((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _errorController.reverse();
        });
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _loadingController.forward();

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim());

      await FirebaseFirestore.instance
          .collection('students')
          .doc(userCredential.user!.uid)
          .set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'college': _selectedCollege,
        'department': _departmentController.text.trim(),
        'rollNumber': _rollNumberController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Registration successful! Welcome to MentorConnect'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        // Animate out before navigation
        await _fadeController.reverse();
        
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const StudentHomePage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut,
                )),
                child: child,
              );
            },
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
      _errorController.forward().then((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _errorController.reverse();
        });
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
      });
      _errorController.forward().then((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _errorController.reverse();
        });
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _loadingController.reverse();
      }
    }
  }

  Widget _buildAnimatedTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    int delay = 0,
  }) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: labelText,
                  prefixIcon: Icon(icon),
                  suffixIcon: suffixIcon,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                keyboardType: keyboardType,
                obscureText: obscureText,
                validator: validator,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedDropdown() {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<String>(
                value: _selectedCollege,
                decoration: InputDecoration(
                  labelText: 'College',
                  prefixIcon: const Icon(Icons.school),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                items: _colleges.map((college) {
                  return DropdownMenuItem(
                    value: college,
                    child: Text(college),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCollege = value;
                  });
                },
                validator: (value) => value == null
                    ? 'Please select a college'
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _departmentController.dispose();
    _rollNumberController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _errorController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Student Registration'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: SlideTransition(
              position: _slideAnimation,
              child: _isLoadingColleges
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TweenAnimationBuilder(
                            tween: Tween<double>(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 1200),
                            curve: Curves.elasticOut,
                            builder: (context, double value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Colors.green, Colors.teal],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                  child: const Icon(
                                    Icons.school,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          const CircularProgressIndicator(color: Colors.green),
                          const SizedBox(height: 16),
                          const Text(
                            'Loading colleges...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(
                        child: SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 500),
                            child: Card(
                              elevation: 8,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Header
                                    TweenAnimationBuilder(
                                      tween: Tween<double>(begin: 0, end: 1),
                                      duration: const Duration(milliseconds: 1200),
                                      curve: Curves.elasticOut,
                                      builder: (context, double value, child) {
                                        return Transform.scale(
                                          scale: value,
                                          child: Container(
                                            width: 80,
                                            height: 80,
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [Colors.green, Colors.teal],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(40),
                                            ),
                                            child: const Icon(
                                              Icons.school,
                                              size: 40,
                                              color: Colors.white,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    
                                    const SizedBox(height: 24),
                                    
                                    const Text(
                                      'Join as Student',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 8),
                                    
                                    Text(
                                      'Connect with mentors from your college',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    
                                    const SizedBox(height: 32),

                                    // Error message
                                    if (_errorMessage != null)
                                      AnimatedBuilder(
                                        animation: _errorAnimation,
                                        builder: (context, child) {
                                          return Transform.translate(
                                            offset: Offset(
                                              10 * _errorAnimation.value * (1 - _errorAnimation.value),
                                              0,
                                            ),
                                            child: Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(12),
                                              margin: const EdgeInsets.only(bottom: 16),
                                              decoration: BoxDecoration(
                                                color: Colors.red[50],
                                                border: Border.all(color: Colors.red[200]!),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.error_outline, 
                                                       color: Colors.red[700], size: 20),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      _errorMessage!,
                                                      style: TextStyle(
                                                        color: Colors.red[700],
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),

                                    // Form
                                    Form(
                                      key: _formKey,
                                      child: Column(
                                        children: [
                                          _buildAnimatedTextField(
                                            controller: _nameController,
                                            labelText: 'Full Name',
                                            icon: Icons.person_outline,
                                            validator: (value) => value == null || value.isEmpty
                                                ? 'Enter name'
                                                : null,
                                            delay: 0,
                                          ),

                                          _buildAnimatedTextField(
                                            controller: _emailController,
                                            labelText: 'Email',
                                            icon: Icons.email_outlined,
                                            keyboardType: TextInputType.emailAddress,
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
                                                return 'Enter email';
                                              }
                                              final emailRegex = RegExp(
                                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                              if (!emailRegex.hasMatch(value)) {
                                                return 'Enter valid email';
                                              }
                                              return null;
                                            },
                                            delay: 100,
                                          ),

                                          _buildAnimatedDropdown(),

                                          _buildAnimatedTextField(
                                            controller: _departmentController,
                                            labelText: 'Department',
                                            icon: Icons.business_outlined,
                                            validator: (value) => value == null || value.isEmpty
                                                ? 'Enter department'
                                                : null,
                                            delay: 200,
                                          ),

                                          _buildAnimatedTextField(
                                            controller: _rollNumberController,
                                            labelText: 'Roll Number',
                                            icon: Icons.badge_outlined,
                                            validator: (value) => value == null || value.isEmpty
                                                ? 'Enter roll number'
                                                : null,
                                            delay: 300,
                                          ),

                                          _buildAnimatedTextField(
                                            controller: _passwordController,
                                            labelText: 'Password',
                                            icon: Icons.lock_outline,
                                            obscureText: _obscurePassword,
                                            suffixIcon: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _obscurePassword = !_obscurePassword;
                                                });
                                              },
                                              child: Icon(
                                                _obscurePassword
                                                    ? Icons.visibility_outlined
                                                    : Icons.visibility_off_outlined,
                                              ),
                                            ),
                                            validator: (value) => value == null || value.length < 6
                                                ? 'Password must be at least 6 characters'
                                                : null,
                                            delay: 400,
                                          ),

                                          const SizedBox(height: 16),

                                          // Register button
                                          TweenAnimationBuilder(
                                            tween: Tween<double>(begin: 0, end: 1),
                                            duration: const Duration(milliseconds: 1000),
                                            curve: Curves.easeOutCubic,
                                            builder: (context, double value, child) {
                                              return Transform.translate(
                                                offset: Offset(0, 30 * (1 - value)),
                                                child: Opacity(
                                                  opacity: value,
                                                  child: SizedBox(
                                                    width: double.infinity,
                                                    height: 50,
                                                    child: AnimatedBuilder(
                                                      animation: _loadingController,
                                                      builder: (context, child) {
                                                        return ElevatedButton(
                                                          onPressed: _isLoading ? null : _registerStudent,
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: Colors.green,
                                                            foregroundColor: Colors.white,
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                            elevation: 3,
                                                          ),
                                                          child: _isLoading
                                                              ? Row(
                                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                                  children: [
                                                                    SizedBox(
                                                                      width: 20,
                                                                      height: 20,
                                                                      child: CircularProgressIndicator(
                                                                        strokeWidth: 2,
                                                                        valueColor: AlwaysStoppedAnimation<Color>(
                                                                          Colors.white.withOpacity(0.8),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(width: 12),
                                                                    Text(
                                                                      'Creating Account...',
                                                                      style: TextStyle(
                                                                        fontSize: 16,
                                                                        fontWeight: FontWeight.w600,
                                                                        color: Colors.white.withOpacity(0.8),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                )
                                                              : const Text(
                                                                  'Create Account',
                                                                  style: TextStyle(
                                                                    fontSize: 16,
                                                                    fontWeight: FontWeight.w600,
                                                                  ),
                                                                ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}
