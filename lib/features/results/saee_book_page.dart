import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/constants/semesters.dart';
import '../../core/print/print_bridge.dart';
import '../../core/storage/app_store.dart';
import '../../core/utils/arabic_numbers.dart';
import '../../models/academic.dart';
import '../../models/assessment.dart';
import '../../models/student.dart';

/// دفتر السعي: قائمة الطلاب وأمام كل اسم درجاته المدخلة في الفصل أفقياً
/// (اليومية ثم الشهرية ثم التقدير)، مع طباعة على ورق A4 بالعرض.
class SaeeBookPage extends StatefulWidget {
  const SaeeBookPage({super.key, required this.store, this.initialSectionId});
  final AppStore store;
  final String? initialSectionId;

  @override
  State<SaeeBookPage> createState() => _SaeeBookPageState();
}

/// عمود في الدفتر.
class _Col {
  const _Col(this.title, this.sub, this.group, this.cell);
  final String title;
  final String sub;

  /// 0 يومي، 1 شهري، 2 تقدير.
  final int group;

  /// قيمة الخلية لطالب: نص، و«غ» للغائب و«م» للمؤجل.
  final String Function(String studentId) cell;
}

class _SaeeBookPageState extends State<SaeeBookPage> {
  static const _rowH = 44.0, _headH = 62.0, _nameW = 210.0, _cellW = 66.0;

  AppStore get store => widget.store;
  late String? sectionId = widget.initialSectionId ?? store.currentSectionId;
  int semester = Semesters.current();

  Section? get section {
    for (final s in store.sections) {
      if (s.id == sectionId) return s;
    }
    return null;
  }

  String _fmt(double? v) {
    if (v == null) return '';
    return v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
  }

  List<_Col> _columns(String sid) {
    final exams = store.dailyExams.where((e) => e.sectionId == sid && e.semester == semester).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final daily = <String, Map<String, DailyExamScore>>{};
    for (final x in store.dailyScores) {
      (daily[x.examId] ??= {})[x.studentId] = x;
    }
    final monthly = <String, Map<String, MonthlyExamScore>>{};
    for (final x in store.monthlyScores) {
      if (x.sectionId == sid) (monthly[x.period] ??= {})[x.studentId] = x;
    }
    return [
      for (final e in exams)
        _Col(e.title.isEmpty ? e.date : e.title, 'من ${_fmt(store.dailyMaxOf(e))}', 0, (st) {
          final x = daily[e.id]?[st];
          if (x == null) return '';
          if (x.status == 'غائب') return 'غ';
          return x.status == 'درجة' ? _fmt(x.score) : '';
        }),
      for (final m in Semesters.months(semester))
        _Col(m, 'من 100', 1, (st) {
          final x = monthly[m]?[st];
          if (x == null) return '';
          if (x.score != null) return _fmt(x.score);
          return x.status == 'مؤجل' ? 'م' : '';
        }),
      _Col(store.componentLabel('rating'), 'من 10', 2, (st) {
        final r = store.ratingOf(st, sid, semester);
        return r == null ? '' : '$r';
      }),
    ];
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = section;
    final students = s == null ? <Student>[] : store.studentsOf(s.id);
    final cols = s == null ? <_Col>[] : _columns(s.id);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('دفتر السعي'),
          actions: [
            if (s != null && students.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 10),
                child: FilledButton.icon(
                  onPressed: () => _print(s, students, cols),
                  icon: const Icon(Icons.print_rounded, size: 20),
                  label: const Text('طباعة'),
                ),
              ),
          ],
        ),
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (store.sections.length > 1)
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<String>(
                    initialValue: sectionId,
                    isDense: true,
                    decoration: const InputDecoration(labelText: 'الشعبة'),
                    items: [
                      for (final x in store.sections)
                        DropdownMenuItem(value: x.id, child: Text('${x.gradeName} - ${x.name}')),
                    ],
                    onChanged: (v) {
                      setState(() => sectionId = v);
                      store.setCurrentSection(v);
                    },
                  ),
                ),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 1, label: Text('الفصل الأول')),
                  ButtonSegment(value: 2, label: Text('الفصل الثاني')),
                ],
                selected: {semester},
                onSelectionChanged: (v) => setState(() => semester = v.first),
              ),
            ]),
          ),
          Expanded(
            child: s == null
                ? const Center(child: Text('اختر شعبة.'))
                : students.isEmpty
                    ? const Center(child: Text('لا يوجد طلاب في هذه الشعبة.'))
                    : _table(p, students, cols),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
            child: Text('غ: غائب عن الامتحان اليومي · م: مؤجل في الامتحان الشهري · الخانة الفارغة: لم تُدخل بعد',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
        ]),
      ),
    );
  }

  Widget _table(MoeenPalette p, List<Student> students, List<_Col> cols) {
    Color groupColor(int g) => g == 0 ? p.soft : (g == 1 ? const Color(0xFFE8F1FB) : const Color(0xFFFBF3E2));
    final border = BorderSide(color: p.border);

    Widget headCell(_Col c) => Container(
          width: _cellW,
          height: _headH,
          padding: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(color: groupColor(c.group), border: Border(left: border, bottom: border)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(c.title,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: p.ink, height: 1.15)),
            Text(c.sub, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ]),
        );

    Widget valueCell(_Col c, String v, bool odd) {
      final n = double.tryParse(v);
      final max = c.group == 0
          ? double.tryParse(c.sub.replaceAll('من ', '')) ?? 10
          : (c.group == 1 ? 100.0 : 10.0);
      final low = n != null && n < max / 2;
      return Container(
        width: _cellW,
        height: _rowH,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: odd ? const Color(0xFFFAF9FD) : Colors.white,
          border: Border(left: border, bottom: border),
        ),
        child: Text(v,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: v == 'غ' || v == 'م' ? const Color(0xFFD9822B) : (low ? const Color(0xFFD64545) : const Color(0xFF222222)),
            )),
      );
    }

    // عمود الأسماء ثابت، والدرجات تتمرر أفقياً، والكل يتمرر عمودياً معاً.
    final names = Column(children: [
      Container(
        width: _nameW,
        height: _headH,
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: p.ink),
        child: const Text('اسم الطالب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      ),
      for (var i = 0; i < students.length; i++)
        Container(
          width: _nameW,
          height: _rowH,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: i.isOdd ? const Color(0xFFFAF9FD) : Colors.white,
            border: Border(left: BorderSide(color: p.outline, width: 2), bottom: border),
          ),
          child: Row(children: [
            SizedBox(width: 26, child: Text('${i + 1}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
            Expanded(
              child: Text(students[i].name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
    ]);

    final grid = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [for (final c in cols) headCell(c)]),
      for (var i = 0; i < students.length; i++)
        Row(children: [for (final c in cols) valueCell(c, c.cell(students[i].id), i.isOdd)]),
    ]);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          names,
          Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: grid)),
        ]),
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Future<void> _print(Section s, List<Student> students, List<_Col> cols) async {
    if (!canPrintHtml) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الطباعة متاحة حالياً في نسخة المتصفح.')),
      );
      return;
    }
    final html = buildSaeeBookHtml(
      schoolName: store.school?.name ?? '',
      teacherName: (store.settings['teacherName'] ?? '').toString().trim(),
      subject: s.subjectName,
      grade: s.gradeName,
      sectionName: s.name,
      semester: Semesters.name(semester),
      groups: [
        (store.componentLabel('daily'), cols.where((c) => c.group == 0).length),
        (store.componentLabel('monthly'), cols.where((c) => c.group == 1).length),
        ('', 1),
      ],
      columns: [for (final c in cols) (c.title, c.sub)],
      rows: [
        for (final st in students) (st.name, [for (final c in cols) c.cell(st.id)]),
      ],
      fontUrl: Uri.base.resolve('assets/assets/fonts/KhalidArt-Bold.ttf').toString(),
    );
    final ok = await printHtml(html);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('منع المتصفح فتح صفحة الطباعة. اسمح بالنوافذ المنبثقة لهذا الموقع ثم أعد المحاولة.'),
        duration: Duration(seconds: 8),
      ));
    }
  }
}

/// صفحة HTML لدفتر السعي على A4 بالعرض، بالأسود، وأرقام بالسياق العربي.
/// الترويسة وعناوين الأعمدة تتكرر في كل صفحة.
String buildSaeeBookHtml({
  required String schoolName,
  required String teacherName,
  required String subject,
  required String grade,
  required String sectionName,
  required String semester,
  required List<(String, int)> groups,
  required List<(String, String)> columns,
  required List<(String, List<String>)> rows,
  int rowsPerPage = 20,
  String? fontUrl,
}) {
  String esc(String v) =>
      v.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
  String ar(String v) => esc(ArabicNumbers.toArabic(v));

  final groupRow = StringBuffer();
  for (var g = 0; g < groups.length; g++) {
    final (label, n) = groups[g];
    if (n == 0) continue;
    if (g == groups.length - 1) {
      groupRow.write('<th rowspan="2" class="v">${esc(columns.last.$1)}<small>${ar(columns.last.$2)}</small></th>');
    } else {
      groupRow.write('<th colspan="$n" class="grp">${esc(label)}</th>');
    }
  }
  final subRow = StringBuffer();
  for (var c = 0; c < columns.length - 1; c++) {
    subRow.write('<th class="v">${esc(columns[c].$1)}<small>${ar(columns[c].$2)}</small></th>');
  }

  final pages = <String>[];
  final pageCount = rows.isEmpty ? 1 : (rows.length / rowsPerPage).ceil();
  for (var p = 0; p < pageCount; p++) {
    final start = p * rowsPerPage;
    final body = StringBuffer();
    for (var i = 0; i < rowsPerPage; i++) {
      final r = start + i < rows.length ? rows[start + i] : null;
      body.write('<tr><td class="num">${r == null ? '' : ar('${start + i + 1}')}</td>');
      body.write('<td class="name">${r == null ? '' : esc(r.$1)}</td>');
      for (var c = 0; c < columns.length; c++) {
        body.write('<td>${r == null ? '' : ar(r.$2[c])}</td>');
      }
      body.write('</tr>');
    }
    pages.add('''
<section class="page">
  <header>
    <div class="t">دفتر السعي · $semester</div>
    <div class="meta">
      ${schoolName.isEmpty ? '' : '<span>المدرسة: <b>${esc(schoolName)}</b></span>'}
      ${teacherName.isEmpty ? '' : '<span>المدرس: <b>${esc(teacherName)}</b></span>'}
      ${subject.isEmpty ? '' : '<span>المادة: <b>${esc(subject)}</b></span>'}
      <span>الصف والشعبة: <b>${esc(grade)} ${esc(sectionName)}</b></span>
      <span class="pg">${ar('${p + 1}')} / ${ar('$pageCount')}</span>
    </div>
  </header>
  <table>
    <thead>
      <tr><th rowspan="2" class="numh">ت</th><th rowspan="2" class="nameh">اسم الطالب</th>$groupRow</tr>
      <tr>$subRow</tr>
    </thead>
    <tbody>$body</tbody>
  </table>
  <footer>غ: غائب · م: مؤجل</footer>
</section>''');
  }

  return '''<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<title>دفتر السعي - ${esc(grade)} ${esc(sectionName)}</title>
<style>
  ${fontUrl == null ? '' : "@font-face { font-family: 'KhalidArt'; src: url('${esc(fontUrl)}') format('truetype'); }"}
  @page { size: A4 landscape; margin: 10mm; }
  * { box-sizing: border-box; }
  html, body { margin: 0; padding: 0; background: #fff; color: #000; }
  body { font-family: ${fontUrl == null ? '' : "'KhalidArt', "}Arial, Tahoma, sans-serif; font-size: 10.5pt;
         -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .page { width: 277mm; height: 190mm; display: flex; flex-direction: column; page-break-after: always; break-after: page; overflow: hidden; }
  .page:last-child { page-break-after: auto; break-after: auto; }
  header { margin-bottom: 3mm; }
  .t { font-size: 15pt; font-weight: bold; text-align: center; margin-bottom: 2mm; }
  .meta { display: flex; flex-wrap: wrap; gap: 3mm 8mm; font-size: 10pt; }
  .meta .pg { margin-inline-start: auto; }
  table { width: 100%; border-collapse: collapse; table-layout: fixed; flex: 1; }
  th, td { border: 0.3mm solid #000; text-align: center; padding: 0 1mm; overflow: hidden; }
  th { font-size: 9pt; background: #eee; line-height: 1.15; }
  th small { display: block; font-weight: normal; font-size: 7.5pt; }
  th.grp { height: 7mm; font-size: 10pt; }
  th.v { height: 12mm; }
  .numh, td.num { width: 8mm; }
  .nameh { width: 58mm; }
  td { height: 7.6mm; font-size: 11pt; }
  td.name { text-align: right; white-space: nowrap; font-size: 10.5pt; }
  footer { font-size: 8.5pt; margin-top: 2mm; }
  .toolbar { display: none; }
  @media screen {
    body { background: #888; padding: 0 0 8mm; }
    .toolbar { display: flex; gap: 10px; align-items: center; justify-content: center; position: sticky; top: 0;
               z-index: 9; background: #3D2B86; color: #fff; padding: 10px; margin-bottom: 8mm; font-size: 14px; }
    .toolbar button { font: inherit; font-weight: bold; border: 0; border-radius: 8px; padding: 8px 22px;
               background: #fff; color: #3D2B86; cursor: pointer; }
    .page { background: #fff; margin: 0 auto 8mm; box-shadow: 0 0 4mm rgba(0,0,0,.4); outline: 10mm solid #fff; }
  }
</style>
</head>
<body>
<div class="toolbar">
  <button onclick="window.print()">🖨 طباعة / حفظ PDF</button>
  <span>الورق: A4 بالعرض (Landscape) — المقياس: 100%</span>
</div>
${pages.join('\n')}
<script>
  window.addEventListener('load', function () {
    var go = function () { setTimeout(function () { window.print(); }, 300); };
    if (document.fonts && document.fonts.ready) { document.fonts.ready.then(go); } else { go(); }
  });
</script>
</body>
</html>''';
}
