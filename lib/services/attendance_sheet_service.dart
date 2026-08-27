import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/attendance_record_model.dart';
import '../models/course_model.dart';

/// Builds a spreadsheet-style attendance sheet for an ended course and
/// opens the OS share sheet so the teacher can save or send it:
/// - Column 1: student registration number
/// - Column 2: student name
/// - One column per day the class was held (P / A)
/// - Final columns: Total Classes, Total Present, Total Absent, Percentage
///
/// Built with the `pdf` + `printing` packages already in this project, so
/// no new dependencies are required.
class AttendanceSheetService {
  static final DateFormat _dateFormat = DateFormat('dd-MM-yyyy');

  // Matches the name shown on the login screen.
  static const String _universityName =
      'Shahjalal University of Science and Technology, Sylhet';

  Future<void> generateAndShare({
    required CourseModel course,
    required List<AttendanceRecordModel> records,
    required List<String> studentIds,
    Map<String, String> studentNames = const {},
  }) async {
    // Sort chronologically. Dates are stored as dd-MM-yyyy, which does NOT
    // sort correctly as plain text, so parse before comparing.
    final sortedRecords = [...records]
      ..sort((a, b) {
        final da = _tryParse(a.date);
        final db = _tryParse(b.date);
        if (da == null || db == null) return a.date.compareTo(b.date);
        return da.compareTo(db);
      });

    final dates = sortedRecords.map((r) => r.date).toList();
    final totalClasses = dates.length;

    final headers = [
      'Reg No',
      'Name',
      ...dates,
      'Total\nClasses',
      'Total\nPresent',
      'Total\nAbsent',
      '%',
    ];

    final rows = <List<String>>[];
    for (final studentId in studentIds) {
      var presentCount = 0;
      final row = <String>[studentId, studentNames[studentId] ?? ''];

      for (final record in sortedRecords) {
        final present = record.isPresent(studentId);
        if (present) presentCount++;
        row.add(present ? 'P' : 'A');
      }

      final absentCount = totalClasses - presentCount;
      final percentage =
          totalClasses == 0 ? 0.0 : (presentCount / totalClasses) * 100;

      row.addAll([
        totalClasses.toString(),
        presentCount.toString(),
        absentCount.toString(),
        '${percentage.toStringAsFixed(1)}%',
      ]);
      rows.add(row);
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    _universityName,
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 6),
                  // Left-aligned as a group (so the colons line up under each
                  // other) while the group itself sits centered on the page,
                  // since it's a child of the pw.Center above.
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      if (course.dept.isNotEmpty)
                        _infoRow('Department', course.dept),
                      _infoRow('Course',
                          '${course.courseName} (${course.courseId})'),
                      if (course.credit.isNotEmpty)
                        _infoRow('Credits', course.credit),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            // Not centered like the block above — sits flush with the left
            // page margin, directly above where the "Reg No" column of the
            // table starts (the table below shares the same page margin).
            _infoRow('Total classes held', totalClasses.toString()),
            pw.SizedBox(height: 10),
          ],
        ),
        build: (context) => [
          pw.Table.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerAlignment: pw.Alignment.center,
            cellAlignment: pw.Alignment.center,
            cellAlignments: const {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
            },
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey600),
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 5),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey300),
          ),
        ],
      ),
    );

    final safeCourseName =
        course.courseName.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final fileName =
        '${safeCourseName.isEmpty ? course.courseId : safeCourseName}_attendance.pdf';

    await Printing.sharePdf(bytes: await pdf.save(), filename: fileName);
  }

  DateTime? _tryParse(String date) {
    try {
      return _dateFormat.parseStrict(date);
    } catch (_) {
      return null;
    }
  }

  /// One "Label : value" line for the header block. The label sits in a
  /// fixed-width, right-aligned box so the colons after Department /
  /// Course / Credits / Total classes held all line up in the same
  /// column no matter how long each label text is.
  pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(label, textAlign: pw.TextAlign.right),
          ),
          pw.Text('  :  '),
          pw.Text(value),
        ],
      ),
    );
  }
}
