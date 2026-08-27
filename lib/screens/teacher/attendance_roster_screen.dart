import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/course_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/roster_util.dart';

class AttendanceRosterScreen extends StatefulWidget {
  final CourseModel course;

  const AttendanceRosterScreen({super.key, required this.course});

  @override
  State<AttendanceRosterScreen> createState() =>
      _AttendanceRosterScreenState();
}

class _AttendanceRosterScreenState extends State<AttendanceRosterScreen> {
  final _firestoreService = FirestoreService();

  // Hardcoded registration-number range (20238301-20238360) plus any
  // extra students the teacher manually added or who joined by name.
  late final List<String> _studentIds =
      buildRosterIds(widget.course.studentIds);

  // studentId -> present/absent. Defaults to unchecked (absent).
  late Map<String, bool> _presentMap;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _presentMap = {for (final id in _studentIds) id: false};
  }

  String get _todayString => DateFormat('dd-MM-yyyy').format(DateTime.now());

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final presentIds = _presentMap.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      await _firestoreService.submitAttendance(
        courseId: widget.course.courseId,
        date: _todayString,
        presentStudentIds: presentIds,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance submitted')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirmEndCourse() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End Course?'),
        content: Text(
          'This will mark "${widget.course.courseName}" as ended. '
          'You will no longer be able to take attendance for it.',
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
      await _firestoreService.endCourse(widget.course.courseId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${widget.course.courseName}" ended')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to end course: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.courseName),
        actions: [
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined),
            tooltip: 'End Course',
            onPressed: _confirmEndCourse,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Date: $_todayString',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _studentIds.length,
              itemBuilder: (context, index) {
                final id = _studentIds[index];
                return CheckboxListTile(
                  title: Text(id),
                  value: _presentMap[id] ?? false,
                  onChanged: (checked) {
                    setState(() => _presentMap[id] = checked ?? false);
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Done'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}