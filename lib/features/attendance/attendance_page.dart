import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/storage/app_store.dart';
import '../../models/student.dart';
import '../students/student_profile_page.dart';

/// تسجيل الحضور السريع: الجميع حاضرون، والمدرس يضغط على الغائب فقط.
/// كل ضغطة تُحفظ فوراً (حاضر ← غائب ← مجاز ← حاضر).
class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key, required this.store, this.initialSectionId});
  final String? initialSectionId;
  final AppStore store;

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  static const present = 'حاضر', absent = 'غائب', excused = 'مجاز';
  static const _green = Color(0xFF2E8B57), _red = Color(0xFFD64545), _amber = Color(0xFFD9822B);

  static const _weekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

  AppStore get store => widget.store;
  String? sectionId;
  late DateTime day;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    day = DateTime(now.year, now.month, now.day);
    final initial = widget.initialSectionId;
    sectionId = (initial != null && store.sections.any((s) => s.id == initial)) ? initial : store.currentSectionId;
    if (sectionId == null && store.sections.isNotEmpty) sectionId = store.sections.first.id;
  }

  String get date =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  bool get _isToday {
    final n = DateTime.now();
    return day.year == n.year && day.month == n.month && day.day == n.day;
  }

  void _shift(int days) => setState(() => day = day.add(Duration(days: days)));

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: day,
    );
    if (d != null) setState(() => day = DateTime(d.year, d.month, d.day));
  }

  Map<String, String> _statuses(List<Student> students) => {
        for (final s in students) s.id: store.attendanceOf(sectionId!, date, s.id) ?? present,
      };

  Future<void> _set(List<Student> students, String studentId, String status) async {
    final map = _statuses(students)..[studentId] = status;
    await store.saveAttendanceDay(
      sectionId: sectionId!,
      date: date,
      studentIds: [for (final s in students) s.id],
      statuses: map,
    );
    if (mounted) setState(() {});
  }

  Future<void> _cycle(List<Student> students, Student s) async {
    HapticFeedback.selectionClick();
    final now = store.attendanceOf(sectionId!, date, s.id) ?? present;
    final next = now == present ? absent : (now == absent ? excused : present);
    await _set(students, s.id, next);
  }

  Future<void> _allPresent(List<Student> students) async {
    await store.saveAttendanceDay(
      sectionId: sectionId!,
      date: date,
      studentIds: [for (final s in students) s.id],
      statuses: const {},
    );
    if (mounted) setState(() {});
  }

  Future<void> _clearDay() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف تسجيل هذا اليوم؟'),
          content: const Text('يُحذف حضور وغياب كل الطلاب في هذا اليوم لهذه الشعبة فقط.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _red),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await store.clearAttendanceDay(sectionId!, date);
    if (mounted) setState(() {});
  }

  int _absences(String studentId) => store.attendance
      .where((a) => a.sectionId == sectionId && a.studentId == studentId && a.status == absent)
      .length;

  Color _color(String status) => status == absent ? _red : (status == excused ? _amber : _green);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final students = sectionId == null ? <Student>[] : store.studentsOf(sectionId!);
    final taken = sectionId != null && store.attendanceTaken(sectionId!, date);
    final statuses = sectionId == null ? <String, String>{} : _statuses(students);
    final nAbsent = statuses.values.where((v) => v == absent).length;
    final nExcused = statuses.values.where((v) => v == excused).length;
    final nPresent = students.length - nAbsent - nExcused;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الحضور والغياب'),
          actions: [
            if (taken)
              IconButton(
                tooltip: 'حذف تسجيل هذا اليوم',
                onPressed: _clearDay,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(children: [
              if (store.sections.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                  child: DropdownButtonFormField<String>(
                    initialValue: sectionId,
                    decoration: const InputDecoration(labelText: 'الشعبة'),
                    items: [
                      for (final s in store.sections)
                        DropdownMenuItem(value: s.id, child: Text('${s.gradeName} - ${s.name}')),
                    ],
                    onChanged: (v) {
                      setState(() => sectionId = v);
                      store.setCurrentSection(v);
                    },
                  ),
                ),
              _dateBar(p),
              if (students.isNotEmpty) _statusBar(p, students, taken, nPresent, nAbsent, nExcused),
              Expanded(
                child: students.isEmpty
                    ? const Center(child: Text('أضف شعبة وطلاباً أولاً.'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                        itemCount: students.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, i) => _row(p, students, i, statuses[students[i].id]!, taken),
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _dateBar(MoeenPalette p) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          IconButton(
            tooltip: 'اليوم السابق',
            onPressed: () => _shift(-1),
            icon: const Icon(Icons.chevron_right_rounded, size: 30),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickDate,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(children: [
                  Text(_isToday ? 'اليوم، ${_weekdays[day.weekday - 1]}' : _weekdays[day.weekday - 1],
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: p.ink)),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('${day.day}/${day.month}/${day.year}', style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(width: 6),
                    Icon(Icons.calendar_month_outlined, size: 16, color: Colors.grey.shade600),
                  ]),
                ]),
              ),
            ),
          ),
          IconButton(
            tooltip: 'اليوم التالي',
            onPressed: () => _shift(1),
            icon: const Icon(Icons.chevron_left_rounded, size: 30),
          ),
        ]),
      );

  Widget _statusBar(MoeenPalette p, List<Student> students, bool taken, int nP, int nA, int nE) {
    Widget pill(String t, int n, Color c) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
          child: Text('$t $n', style: TextStyle(color: c, fontWeight: FontWeight.w800)),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!taken)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            decoration: BoxDecoration(
              color: p.soft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Expanded(
                child: Text('لم يُسجَّل هذا اليوم بعد. اضغط على الغائب فقط، والباقون حاضرون.',
                    style: TextStyle(color: p.ink, height: 1.5)),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => _allPresent(students),
                child: const Text('الكل حاضر'),
              ),
            ]),
          )
        else
          Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 20),
            pill('حاضر', nP, _green),
            pill('غائب', nA, _red),
            if (nE > 0) pill('مجاز', nE, _amber),
          ]),
      ]),
    );
  }

  Widget _row(MoeenPalette p, List<Student> students, int i, String status, bool taken) {
    final s = students[i];
    final c = _color(status);
    final marked = taken && status != present;
    final total = _absences(s.id);
    return Material(
      color: marked ? c.withValues(alpha: .07) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: marked ? c.withValues(alpha: .55) : p.border, width: marked ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _cycle(students, s),
        onLongPress: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StudentProfilePage(store: store, student: s, sectionId: sectionId!)),
        ).then((_) => mounted ? setState(() {}) : null),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            SizedBox(
              width: 28,
              child: Text('${i + 1}', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                if (total > 0)
                  Text('غيابات الطالب: $total',
                      style: TextStyle(fontSize: 12, color: total >= 5 ? _red : Colors.grey.shade600)),
              ]),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 74,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: taken || status != present ? c : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: taken || status != present ? c : Colors.grey.shade300),
              ),
              child: Text(
                status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: taken || status != present ? Colors.white : Colors.grey.shade500,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
