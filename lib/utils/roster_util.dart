/// Default registration-number range shown for every course, so a
/// teacher's course roster is pre-populated without anyone needing to
/// join or be added first.
const int kRosterStartReg = 2023831001;
const int kRosterEndReg = 2023831070;

/// Builds the roster for a course: the default registration-number
/// range above, plus any extra student IDs on the course (added
/// manually by the teacher, or via a student joining by course ID)
/// that fall outside that range — deduped and sorted.
///
/// Used by AttendanceRosterScreen (so the roll numbers show up as
/// checkboxes automatically, even before every student has joined).
///
/// The generated attendance sheet does NOT use this pre-populated list
/// directly — it only includes a roll number if it is both (a) actually
/// enrolled in the course (course.studentIds — via joining by course ID
/// or the teacher's "Add Student") and (b) has a real registered account
/// (see TeacherDashboardScreen._generateAttendanceSheet). A roll number
/// that shows up here for taking attendance but was never truly enrolled
/// in this course, or never registered an account, gets no row — and is
/// effectively absent — on the generated sheet.
List<String> buildRosterIds(List<String> extraStudentIds) {
  final base = [
    for (int reg = kRosterStartReg; reg <= kRosterEndReg; reg++)
      reg.toString(),
  ];
  final extra = extraStudentIds.where((id) => !base.contains(id));
  final combined = {...base, ...extra}.toList();
  combined.sort();
  return combined;
}
