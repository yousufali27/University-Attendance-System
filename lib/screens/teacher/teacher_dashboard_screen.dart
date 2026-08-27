import 'package:flutter/material.dart';
import '../../models/course_model.dart';
import '../../services/attendance_sheet_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/roster_util.dart';
import '../auth/login_screen.dart';
import 'attendance_roster_screen.dart';

class TeacherDashboardScreen extends StatelessWidget {
  const TeacherDashboardScreen({super.key});

  Future<void> _showAddCourseDialog(
    BuildContext context,
    FirestoreService firestoreService,
    String teacherId,
  ) async {
    final nameController = TextEditingController();
    final deptController = TextEditingController();
    final creditController = TextEditingController();
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> handleAdd() async {
              final name = nameController.text.trim();
              final dept = deptController.text.trim();
              final credit = creditController.text.trim();
              if (name.isEmpty || dept.isEmpty || credit.isEmpty || submitting) {
                return;
              }

              setDialogState(() => submitting = true);
              try {
                final courseId = await firestoreService.addCourse(
                  teacherId: teacherId,
                  courseName: name,
                  dept: dept,
                  credit: credit,
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Course created — ID: $courseId')),
                  );
                }
              } catch (e) {
                setDialogState(() => submitting = false);
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Failed to add course: $e')),
                  );
                }
              }
            }

            return AlertDialog(
              title: const Text('New Course'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Course name',
                      hintText: 'e.g. Algorithms',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: deptController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      hintText: 'e.g. CSE',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: creditController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Credit',
                      hintText: 'e.g. 3',
                    ),
                    onSubmitted: (_) => handleAdd(),
                  ),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Course ID is generated automatically from the '
                      'course name (e.g. MAT101).',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: submitting ? null : handleAdd,
                  child: submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAddStudentDialog(
    BuildContext context,
    FirestoreService firestoreService,
    CourseModel course,
  ) async {
    final nameController = TextEditingController();
    final regNoController = TextEditingController();
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> handleAdd() async {
              final name = nameController.text.trim();
              final regNo = regNoController.text.trim();
              if (name.isEmpty || regNo.isEmpty || submitting) return;

              setDialogState(() => submitting = true);
              try {
                await firestoreService.addStudentToCourse(
                  courseId: course.courseId,
                  studentId: regNo,
                  studentName: name,
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              } catch (e) {
                setDialogState(() => submitting = false);
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Failed to add student: $e')),
                  );
                }
              }
            }

            return AlertDialog(
              title: Text('Add Student to ${course.courseName}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Student name',
                      hintText: 'e.g. Rahim Uddin',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: regNoController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Registration number',
                      hintText: 'e.g. 20238361',
                    ),
                    onSubmitted: (_) => handleAdd(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: submitting ? null : handleAdd,
                  child: submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmEndCourse(
    BuildContext context,
    FirestoreService firestoreService,
    CourseModel course,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End Course?'),
        content: Text(
          'This will mark "${course.courseName}" as ended. '
          'You will no longer be able to take attendance for it, '
          'but you can generate the attendance sheet afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('End Course'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await firestoreService.endCourse(course.courseId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${course.courseName}" ended')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to end course: $e')),
        );
      }
    }
  }

  Future<void> _generateAttendanceSheet(
    BuildContext context,
    FirestoreService firestoreService,
    CourseModel course,
  ) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    var spinnerOpen = true;
    void closeSpinner() {
      if (spinnerOpen && context.mounted) {
        Navigator.of(context).pop();
        spinnerOpen = false;
      }
    }

    try {
      final records =
          await firestoreService.attendanceRecordsForCourse(course.courseId);

      // Names of students who registered themselves through the app,
      // keyed by registration number.
      final registeredNames =
          await firestoreService.studentNamesByRegistrationNumber();

      // Only include a roll number if BOTH:
      //  1) it has a real registered account (registeredNames has it), and
      //  2) it is actually enrolled in THIS course (course.studentIds) —
      //     either the student joined by course ID, or the teacher added
      //     them via "Add Student".
      // A roll number that merely falls in the default preview range (see
      // roster_util.dart) but never joined this course does NOT get a row
      // here, even if that reg number has an account from some other
      // course.
      final roster = course.studentIds
          .where((id) => registeredNames.containsKey(id))
          .toList()
        ..sort();

      final studentNames = {...registeredNames, ...course.studentNames};

      closeSpinner();

      await AttendanceSheetService().generateAndShare(
        course: course,
        records: records,
        studentIds: roster,
        studentNames: studentNames,
      );
    } catch (e) {
      closeSpinner();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate sheet: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final firestoreService = FirestoreService();
    final teacherId = authService.currentUser!.uid;

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
        onPressed: () =>
            _showAddCourseDialog(context, firestoreService, teacherId),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<CourseModel>>(
        stream: firestoreService.coursesForTeacher(teacherId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final courses = snapshot.data ?? [];
          if (courses.isEmpty) {
            return const Center(child: Text('No courses assigned yet.'));
          }
          return ListView.builder(
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              final rosterCount = buildRosterIds(course.studentIds).length;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(course.courseName),
                  subtitle: Text(
                    'ID: ${course.courseId} • ${course.dept} • '
                    '${course.credit} credits • $rosterCount students'
                    '${course.isEnded ? ' • Ended' : ''}',
                    style: course.isEnded
                        ? const TextStyle(color: Colors.red)
                        : null,
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'add_student':
                          _showAddStudentDialog(
                              context, firestoreService, course);
                          break;
                        case 'end_course':
                          _confirmEndCourse(context, firestoreService, course);
                          break;
                        case 'generate_sheet':
                          _generateAttendanceSheet(
                              context, firestoreService, course);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      if (!course.isEnded)
                        const PopupMenuItem(
                          value: 'add_student',
                          child: Text('Add Student'),
                        ),
                      if (!course.isEnded)
                        const PopupMenuItem(
                          value: 'end_course',
                          child: Text('End Course'),
                        ),
                      if (course.isEnded)
                        const PopupMenuItem(
                          value: 'generate_sheet',
                          child: Text('Generate Attendance Sheet'),
                        ),
                    ],
                  ),
                  onTap: () {
                    if (course.isEnded) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'This course has ended. Use "Generate Attendance '
                            'Sheet" from the menu.',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AttendanceRosterScreen(course: course),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}