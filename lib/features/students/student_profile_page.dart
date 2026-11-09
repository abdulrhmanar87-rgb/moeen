import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/constants/semesters.dart';
import '../../core/storage/app_store.dart';
import '../../models/academic.dart';
import '../../models/student.dart';
import '../../services/calculation_service.dart';

/// ملف الطالب: الحضور، الامتحانات، التقدير، والسعي في مكان واحد.
class StudentProfilePage extends StatefulWidget {
  const StudentProfilePage({super.key, required this.store, required this.student, required this.sectionId});
  final AppStore store;
  final Student student;
  final String sectionId;

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  static const _green = Color(0xFF2E8B57), _red = Color(0xFFD64545), _amber = Color(0xFFD9822B);

  AppStore get store => widget.store;
  Student get st => widget.student;
  String get sid => widget.sectionId;

  Section? get section {
    for (final s in store.sections) {
      if (s.id == sid) return s;
    }
    return null;
  }

  String _fmt(double? v) {
    if (v == null) return '—';
    final r = double.parse(v.toStringAsFixed(2));
    return r % 1 == 0 ? r.toInt().toString() : r.toString();
  }

  Color _scoreColor(double? v, [double max = 100]) {
    if (v == null) return Colors.grey;
    return v < max / 2 ? _red : (v >= max * .85 ? _green : const Color(0xFF333333));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final calc = CalculationService(store);
    final sec = section;
    final year = calc.year(st.id, sid);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('ملف الطالب')),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                _header(p, sec, year),
                const SizedBox(height: 14),
                _attendance(p),
                const SizedBox(height: 14),
                _semester(p, calc.semester(st.id, sid, 1)),
                const SizedBox(height: 14),
                _semester(p, calc.semester(st.id, sid, 2)),
                const SizedBox(height: 14),
                _year(p, year),
                const SizedBox(height: 14),
                _notes(p),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(MoeenPalette p, String title, IconData icon, List<Widget> children, {Widget? trailing}) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(icon, color: p.ink, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: p.ink))),
              if (trailing != null) trailing,
            ]),
            const SizedBox(height: 10),
            ...children,
          ]),
        ),
      );

  Widget _line(String label, String value, {Color? color, bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: Colors.grey.shade800))),
          Text(value,
              style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w700, color: color, fontSize: bold ? 16 : 14.5)),
        ]),
      );

  Widget _header(MoeenPalette p, Section? sec, YearResult year) {
    final status = year.status;
    final statusColor = status == 'ناجح' || status == 'ناجح بالإكمال' ? _green : (status == 'مكمل' ? _amber : _red);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.white.withValues(alpha: .15),
          child: Text(st.name.trim().isEmpty ? '?' : st.name.trim().characters.first,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(st.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              [
                if (sec != null) '${sec.gradeName} ${sec.name}',
                if (sec != null && sec.subjectName.isNotEmpty) sec.subjectName,
                if (st.number.isNotEmpty) 'التسلسل ${st.number}',
              ].join('، '),
              style: TextStyle(color: Colors.white.withValues(alpha: .8)),
            ),
          ]),
        ),
        if (status.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w900)),
          ),
      ]),
    );
  }

  Widget _attendance(MoeenPalette p) {
    final days = store.attendanceDays(sid);
    final records = store.attendance.where((a) => a.studentId == st.id && a.sectionId == sid).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final absent = records.where((r) => r.status == 'غائب').toList();
    final excused = records.where((r) => r.status == 'مجاز').toList();
    final rate = CalculationService(store).attendanceRate(st.id, sid);
    String d(String iso) {
      final x = DateTime.tryParse(iso);
      return x == null ? iso : '${x.day}/${x.month}';
    }

    return _card(p, 'الحضور', Icons.how_to_reg_outlined, [
      if (days.isEmpty)
        Text('لم يُسجَّل حضور بعد.', style: TextStyle(color: Colors.grey.shade600))
      else ...[
        Wrap(spacing: 8, runSpacing: 8, children: [
          _stat('أيام مسجلة', '${days.length}', p.ink),
          _stat('غياب', '${absent.length}', absent.isEmpty ? _green : _red),
          if (excused.isNotEmpty) _stat('إجازة', '${excused.length}', _amber),
          if (rate != null) _stat('نسبة الحضور', '${_fmt(rate)}%', rate < 85 ? _red : _green),
        ]),
        if (absent.isNotEmpty || excused.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final r in [...absent, ...excused]..sort((a, b) => b.date.compareTo(a.date)))
              Chip(
                visualDensity: VisualDensity.compact,
                backgroundColor: (r.status == 'غائب' ? _red : _amber).withValues(alpha: .1),
                label: Text('${r.status} ${d(r.date)}',
                    style: TextStyle(color: r.status == 'غائب' ? _red : _amber, fontSize: 12.5)),
              ),
          ]),
        ],
      ],
    ]);
  }

  Widget _stat(String label, String value, Color c) => Container(
        width: 104,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: c.withValues(alpha: .08), borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c)),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ]),
      );

  Widget _semester(MoeenPalette p, SemesterBreakdown b) {
    final exams = store.dailyExams.where((e) => e.sectionId == sid && e.semester == b.semester).toList()
      ..sort((a, c) => a.date.compareTo(c.date));
    final total = b.total;
    final monthStatus = {
      for (final m in store.monthlyScores)
        if (m.studentId == st.id && m.sectionId == sid) m.period: m.status,
    };
    return _card(
      p,
      Semesters.name(b.semester),
      Icons.event_note_outlined,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: total == null ? Colors.grey.shade100 : p.soft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          total == null ? 'السعي غير مكتمل' : 'السعي ${_fmt(total)}',
          style: TextStyle(fontWeight: FontWeight.w900, color: total == null ? Colors.grey.shade700 : _scoreColor(total)),
        ),
      ),
      [
        Text(b.monthlyLabel, style: TextStyle(fontWeight: FontWeight.w800, color: Colors.grey.shade800)),
        for (final m in Semesters.months(b.semester))
          _line(
            m,
            b.monthlyScores[m] != null ? _fmt(b.monthlyScores[m]) : (monthStatus[m] == 'مؤجل' ? 'مؤجل' : '—'),
            color: monthStatus[m] == 'مؤجل' ? _amber : _scoreColor(b.monthlyScores[m]),
          ),
        const Divider(height: 18),
        Text(b.dailyLabel,
            style: TextStyle(fontWeight: FontWeight.w800, color: Colors.grey.shade800)),
        if (exams.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('لا توجد امتحانات يومية في هذا الفصل.', style: TextStyle(color: Colors.grey.shade600)),
          ),
        for (final e in exams) _dailyLine(e.id, e.title.isEmpty ? e.date : e.title, store.dailyMaxOf(e)),
        const Divider(height: 18),
        _line(
          b.ratingLabel,
          b.ratingScore == null ? '—' : '${b.ratingScore} من 10 (${RatingLevels.label(b.ratingScore!)})',
        ),
        const Divider(height: 18),
        _line('${b.monthlyLabel} (من ${_fmt(b.monthlyWeight)})', _fmt(b.monthlyPart)),
        _line('${b.dailyLabel} (من ${_fmt(b.dailyWeight)})', _fmt(b.dailyPart)),
        _line('${b.ratingLabel} (من ${_fmt(b.ratingWeight)})', _fmt(b.ratingPart)),
        if (total == null && b.partialTotal > 0)
          _line('المجموع حتى الآن', _fmt(b.partialTotal), bold: true),
        if (b.missing.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('ينقص: ${b.missing.join('، ')}', style: const TextStyle(color: _amber, fontSize: 12.5)),
          ),
      ],
    );
  }

  Widget _dailyLine(String examId, String title, double max) {
    String value = 'لم تُدخل';
    Color color = Colors.grey;
    for (final s in store.dailyScores) {
      if (s.examId == examId && s.studentId == st.id) {
        if (s.status == 'درجة' && s.score != null) {
          value = '${_fmt(s.score)} / ${_fmt(max)}';
          color = _scoreColor(s.score, max);
        } else {
          value = 'غائب';
          color = _amber;
        }
        break;
      }
    }
    return _line(title, value, color: color);
  }

  Widget _year(MoeenPalette p, YearResult y) => _card(p, 'نتيجة السنة', Icons.workspace_premium_outlined, [
        _line('معدل الفصل الأول', _fmt(y.first), color: _scoreColor(y.first)),
        _line('نصف السنة', _fmt(y.midyear), color: _scoreColor(y.midyear)),
        _line('معدل الفصل الثاني', _fmt(y.second), color: _scoreColor(y.second)),
        _line('السعي السنوي', _fmt(y.annual), color: _scoreColor(y.annual), bold: true),
        const Divider(height: 18),
        _line('الامتحان النهائي', _fmt(y.finalExam), color: _scoreColor(y.finalExam)),
        _line('الدرجة النهائية', _fmt(y.finalGrade), color: _scoreColor(y.finalGrade), bold: true),
        if (y.needsCompletion) ...[
          _line('امتحان الإكمال', _fmt(y.completionExam), color: _scoreColor(y.completionExam)),
          _line('بعد الإكمال', _fmt(y.afterCompletion), color: _scoreColor(y.afterCompletion), bold: true),
        ],
      ]);

  Widget _notes(MoeenPalette p) => _card(
        p,
        'ملاحظات',
        Icons.sticky_note_2_outlined,
        trailing: TextButton.icon(
          onPressed: _editNotes,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: Text(st.notes.isEmpty ? 'إضافة' : 'تعديل'),
        ),
        [
          Text(st.notes.isEmpty ? 'لا توجد ملاحظات.' : st.notes,
              style: TextStyle(color: st.notes.isEmpty ? Colors.grey.shade600 : null, height: 1.6)),
        ],
      );

  Future<void> _editNotes() async {
    final c = TextEditingController(text: st.notes);
    final saved = await showDialog<String>(
      context: context,
      builder: (dc) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('ملاحظات عن الطالب'),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: c,
              autofocus: true,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(hintText: 'مثال: تواصلت مع ولي أمره بتاريخ…'),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dc), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dc, c.text.trim()), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (saved == null) return;
    st.notes = saved;
    await store.saveAll();
    if (mounted) setState(() {});
  }
}
