import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';
import '../teacher/teacher_dashboard_screen.dart';
import '../student/student_dashboard_screen.dart';

/// Listens to Firebase auth state; if a user is already signed in,
/// fetches their role from Firestore and routes straight to the
/// right dashboard instead of showing the login form again.
///
/// If no user is signed in, shows either the existing LoginScreen or
/// an inline registration form (toggle at the bottom), so new users
/// can create an account without touching any other file.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          return const _UnauthenticatedView();
        }

        return FutureBuilder<UserModel?>(
          future: authService.fetchCurrentUserProfile(),
          builder: (context, profileSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final profile = profileSnap.data;
            if (profile == null) {
              return const _UnauthenticatedView();
            }

            return profile.isTeacher
                ? const TeacherDashboardScreen()
                : const StudentDashboardScreen();
          },
        );
      },
    );
  }
}

/// Toggles between the existing LoginScreen and an inline registration
/// form. Once registration succeeds, Firebase's auth state changes and
/// AuthGate's StreamBuilder above automatically routes to the right
/// dashboard — no extra navigation needed here.
class _UnauthenticatedView extends StatefulWidget {
  const _UnauthenticatedView();

  @override
  State<_UnauthenticatedView> createState() => _UnauthenticatedViewState();
}

class _UnauthenticatedViewState extends State<_UnauthenticatedView> {
  bool _showRegister = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _showRegister ? const _RegisterScreen() : const LoginScreen(),
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Center(
            child: TextButton(
              onPressed: () => setState(() => _showRegister = !_showRegister),
              child: Text(
                _showRegister
                    ? 'Already have an account? Log in'
                    : "Don't have an account? Register",
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Self-contained registration form: creates the Firebase Auth user,
/// then writes the matching users/{uid} profile doc (name, email, role)
/// that the rest of the app (and AuthGate) relies on for routing.
class _RegisterScreen extends StatefulWidget {
  const _RegisterScreen();

  @override
  State<_RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<_RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _regNoController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = 'student';

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _regNoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final uid = credential.user!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _nameController.text.trim(),
        // Only students have a registration number — it's their identity
        // across courses/attendance. Teachers don't need one.
        'registrationNumber':
            _role == 'student' ? _regNoController.text.trim() : '',
        'email': _emailController.text.trim(),
        'role': _role,
      });

      // No manual navigation needed: AuthGate's authStateChanges +
      // fetchCurrentUserProfile stream picks this up and routes
      // automatically once the profile doc above is written.
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Registration failed.');
    } catch (e) {
      setState(() => _error = 'Registration failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_add_alt_1, size: 72),
                  const SizedBox(height: 12),
                  const Text(
                    'Create Account',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _role,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'student', child: Text('Student')),
                      DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _role = value);
                    },
                  ),
                  // Extra registration section — only students need this,
                  // right after Full Name/Role. Teachers skip straight to
                  // email/password.
                  if (_role == 'student') ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _regNoController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Registration Number',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter your registration number'
                          : null,
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Min 6 characters' : null,
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _handleRegister,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_role == 'teacher'
                              ? 'Register as Teacher'
                              : 'Register as Student'),
                    ),
                  ),
                  const SizedBox(height: 56),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}