import 'package:flutter/material.dart';
import '../../models/course_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../auth/login_screen.dart';
import 'student_course.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() =>
      _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  Future<void> _showJoinCourseDialog(
    BuildContext context,
    String studentId,
  ) async {
    final controller = TextEditingController();
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> handleJoin() async {
              final courseId = controller.text.trim();
              if (courseId.isEmpty || submitting) return;

              setDialogState(() => submitting = true);
              try {
                await _firestoreService.joinCourseById(
                  studentId: studentId,
                  courseId: courseId,
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              } catch (e) {
                setDialogState(() => submitting = false);
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Failed to join course: $e')),
                  );
                }
              }
            }

            return AlertDialog(
              title: const Text('Join Course'),
              content: TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Course ID',
                  hintText: 'e.g. CSE101',
                ),
                onSubmitted: (_) => handleJoin(),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: submitting ? null : handleJoin,
                  child: submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Join'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _authService.fetchCurrentUserProfile(),
      builder: (context, profileSnap) {
        if (profileSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final profile = profileSnap.data;
        // A student's identity across courses/attendance is their real
        // registration number (set at sign-up), not the Firebase uid —
        // that's what ties them to the roster and the generated sheet.
        final studentId = profile?.registrationNumber ?? '';
        return _buildScaffold(context, studentId);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, String studentId) {
    final authService = _authService;
    final firestoreService = _firestoreService;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Courses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showJoinCourseDialog(context, studentId),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<CourseModel>>(
        stream: firestoreService.coursesForStudent(studentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final courses = snapshot.data ?? [];
          if (courses.isEmpty) {
            return const Center(child: Text('No courses joined yet.'));
          }
          return ListView.builder(
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(course.courseName),
                  subtitle: Text('ID: ${course.courseId}'),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StudentCourseStatusScreen(
                            course: course,
                            studentId: studentId,
                          ),
                        ),
                      );
                    },
                    child: const Text('See Attendance'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}