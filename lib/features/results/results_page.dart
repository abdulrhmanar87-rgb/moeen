import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/constants/semesters.dart';
import '../../core/storage/app_store.dart';
import '../../services/calculation_service.dart';
import '../../models/student.dart';

class ResultsPage extends StatefulWidget {
  final AppStore store;

  const ResultsPage({super.key, required this.store});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  String? sectionId;
  int semester = Semesters.current();

  @override
  Widget build(BuildContext context) {
    final sections = widget.store.sections;
    sectionId ??= widget.store.currentSectionId;
    final students = sectionId == null ? <Student>[] : widget.store.studentsOf(sectionId!);
    final calc = CalculationService(widget.store);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('النتائج والحسابات')),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: DropdownButtonFormField<String>(
                initialValue: sectionId,
                decoration: const InputDecoration(labelText: 'الشعبة', prefixIcon: Icon(Icons.class_outlined)),
                items: [
                  for (final s in sections)
                    DropdownMenuItem(value: s.id, child: Text('${s.gradeName} - ${s.name}')),
                ],
                onChanged: (v) {
                  setState(() => sectionId = v);
                  widget.store.setCurrentSection(v);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 1, label: Text('الفصل الأول')),
                  ButtonSegment(value: 2, label: Text('الفصل الثاني')),
                ],
                selected: {semester},
                onSelectionChanged: (v) => setState(() => semester = v.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'سعي الفصل = ${widget.store.componentLabel('monthly')} ${calc.monthlyWeight.toInt()} '
                '+ ${widget.store.componentLabel('daily')} ${calc.dailyWeight.toInt()} '
                '+ ${widget.store.componentLabel('rating')} ${calc.ratingWeight.toInt()}',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: students.isEmpty
                  ? const Center(child: Text('لا يوجد طلاب في الشعبة المختارة'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: students.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _studentCard(
                        students[i],
                        i + 1,
                        calc.semester(students[i].id, sectionId!, semester),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _studentCard(Student student, int serial, SemesterBreakdown b) {
    final total = b.total;
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        title: Row(children: [
          SizedBox(width: 30, child: Text('$serial', style: TextStyle(color: Colors.grey.shade600))),
          Expanded(child: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold))),
          _badge(total),
        ]),
        subtitle: Padding(
          padding: const EdgeInsetsDirectional.only(start: 30, top: 4),
          child: Wrap(spacing: 14, runSpacing: 4, children: [
            _mini(b.monthlyLabel, b.monthlyPart, b.monthlyWeight),
            _mini(b.dailyLabel, b.dailyPart, b.dailyWeight),
            _mini(b.ratingLabel, b.ratingPart, b.ratingWeight),
          ]),
        ),
        children: [_details(b)],
      ),
    );
  }

  Widget _badge(double? total) {
    final done = total != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: done ? AppTheme.softPurple : const Color(0xFFFFF4D7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        done ? _fmt(total) : 'ناقص',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: done ? 17 : 13,
          color: done ? AppTheme.primaryDark : const Color(0xFF8A5A00),
        ),
      ),
    );
  }

  Widget _mini(String label, double? value, double max) => Text(
        '$label: ${value == null ? '—' : _fmt(value)}/${_fmt(max)}',
        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
      );

  Widget _details(SemesterBreakdown b) {
    final rows = <Widget>[
      const Divider(),
      // الامتحانات الشهرية
      _line(
        b.monthlyLabel,
        b.monthlyScores.isEmpty
            ? 'لم تُدخل بعد'
            : '${Semesters.months(b.semester).map((m) => b.monthlyScores[m] == null ? '—' : _fmt(b.monthlyScores[m])).join(' ، ')}'
                '  ← المعدل ${_fmt(b.monthlyAverage)} من 100',
        b.monthlyPart,
        b.monthlyWeight,
      ),
      _line(
        b.dailyLabel,
        b.dailyScores.isEmpty
            ? 'لا توجد درجات'
            : 'النسب: ${b.dailyScores.map((v) => '${_fmt(v)}%').join(' ، ')}  ← المعدل ${_fmt(b.dailyAverage)}%',
        b.dailyPart,
        b.dailyWeight,
      ),
      _line(
        b.ratingLabel,
        b.ratingScore == null
            ? 'لم يُقيَّم بعد (من تبويب «${b.ratingLabel}» في الامتحانات)'
            : '${b.ratingScore} من 10، ${RatingLevels.label(b.ratingScore!)}',
        b.ratingPart,
        b.ratingWeight,
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: b.isComplete ? AppTheme.softPurple : const Color(0xFFFFF4D7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          b.isComplete
              ? 'سعي ${Semesters.name(b.semester)}: ${_fmt(b.monthlyPart)} + ${_fmt(b.dailyPart)} + ${_fmt(b.ratingPart)} = ${_fmt(b.total)}'
              : 'المجموع الحالي ${_fmt(b.partialTotal)} — ينقص: ${b.missing.join('، ')}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }

  Widget _line(String title, String detail, double? part, double max) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(detail, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
            ]),
          ),
          Text(
            '${part == null ? '—' : _fmt(part)} / ${_fmt(max)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ]),
      );

  String _fmt(double? value) {
    if (value == null) return '—';
    final rounded = double.parse(value.toStringAsFixed(2));
    return rounded % 1 == 0 ? rounded.toInt().toString() : rounded.toString();
  }
}
