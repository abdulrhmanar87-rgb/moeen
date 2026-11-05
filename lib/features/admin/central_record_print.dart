import '../../core/storage/app_store.dart';
import '../../core/utils/arabic_name_utils.dart';
import '../../core/utils/arabic_numbers.dart';
import '../../models/academic.dart';
import '../../services/admin_results_service.dart';

/// بيانات صفحة طالب واحد في السجل الوسطي (نصوص جاهزة للعرض).
class CentralRecordStudent {
  const CentralRecordStudent({
    required this.nameColumns,
    required this.sectionLabel,
    required this.regNo,
    required this.birthDate,
    required this.failedYears,
    required this.rows,
    required this.totals,
    required this.result,
  });

  /// [الطالب، الأب، الجد، أب الجد واللقب]
  final List<String> nameColumns;
  final String sectionLabel, regNo, birthDate, failedYears;

  /// لكل مادة: 9 قيم بترتيب أعمدة السجل (الأخيرة الملاحظات).
  final Map<String, List<String>> rows;

  /// مجموع الأعمدة الثمانية الرقمية.
  final List<String> totals;
  final String result;
}

/// يبني «سجل الدرجات للمدارس المتوسطة والثانوية»: صفحة A4 لكل طالب،
/// بنفس ترتيب النموذج الورقي، وأرقام بالسياق العربي.
String buildCentralRecordHtml({
  required String schoolName,
  required String academicYear,
  required String directorName,
  required List<String> subjects,
  required List<CentralRecordStudent> students,
  String? fontUrl,
  int firstPageNumber = 1,
}) {
  String esc(String v) => v.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
  String ar(String v) => esc(ArabicNumbers.toArabic(v.trim()));

  // «2026-2027» ← «٢٠٢٦ / ٢٠٢٧»
  final years = RegExp(r'\d{4}').allMatches(ArabicNumbers.toEnglish(academicYear)).map((m) => m.group(0)!).toList();
  final yearText = years.length >= 2
      ? '${ArabicNumbers.toArabic(years[0])} / ${ArabicNumbers.toArabic(years[1])}'
      : (academicYear.trim().isEmpty ? '٢٠٢ &nbsp; / &nbsp; ٢٠٢' : ar(academicYear));

  const headers = [
    'معدل الفصل الأول',
    'نصف السنة',
    'معدل الفصل الثاني',
    'درجة السعي السنوي',
    'درجة الامتحان النهائي',
    'الدرجة النهائية',
    'درجة الإكمال',
    'الدرجة النهائية بعد الإكمال',
    'الملاحظات',
  ];

  final pages = <String>[];
  for (var i = 0; i < students.length; i++) {
    final st = students[i];
    final body = StringBuffer();
    for (final subject in subjects) {
      final values = st.rows[subject] ?? const [];
      body.write('<tr><th class="subj">${esc(subject)}</th>');
      for (var c = 0; c < headers.length; c++) {
        final v = c < values.length ? values[c] : '';
        body.write('<td${c == headers.length - 1 ? ' class="note"' : ''}>${ar(v)}</td>');
      }
      body.write('</tr>');
    }
    body.write('<tr class="total"><th class="subj">المجموع</th>');
    for (var c = 0; c < headers.length - 1; c++) {
      body.write('<td>${c < st.totals.length ? ar(st.totals[c]) : ''}</td>');
    }
    body.write('<td></td></tr>');
    body.write('<tr class="result"><th class="subj">النتيجة</th><td colspan="${headers.length}">${ar(st.result)}</td></tr>');

    final n = st.nameColumns;
    String part(int k) => k < n.length ? ar(n[k]) : '';
    pages.add('''
<section class="page">
  <div class="top">
    <div class="page-no">رقم الصفحة ( ${ArabicNumbers.toArabic(firstPageNumber + i)} )</div>
    <div class="title">
      <div class="t1">سجل الدرجات للمدارس</div>
      <div class="t2">المتوسطة والثانوية</div>
      <div class="t3">للسنة الدراسية &nbsp; $yearText</div>
    </div>
    <div class="spacer"></div>
  </div>
  <div class="school">إدارة &nbsp; ${schoolName.trim().isEmpty ? '<span class="dots"></span>' : ar(schoolName)}</div>
  <table class="info">
    <tr><th>اسم الطالب</th><th>اسم الأب</th><th>اسم الجد</th><th>اسم أب الجد</th><th>الصف والشعبة</th><th>رقم القيد</th><th>المواليد</th><th>سنوات الرسوب</th></tr>
    <tr><td>${part(0)}</td><td>${part(1)}</td><td>${part(2)}</td><td>${part(3)}</td><td>${ar(st.sectionLabel)}</td><td>${ar(st.regNo)}</td><td>${ar(st.birthDate)}</td><td>${ar(st.failedYears)}</td></tr>
  </table>
  <table class="grid">
    <colgroup><col class="c-subj">${headers.map((_) => '<col class="c-val">').join()}</colgroup>
    <thead><tr><th class="subj head">المـــــادة</th>${headers.map((h) => '<th>${esc(h)}</th>').join()}</tr></thead>
    <tbody>$body</tbody>
  </table>
  <footer><div>مدير المدرسة</div><div class="dir">${ar(directorName)}</div></footer>
</section>''');
  }

  final fontFace = fontUrl == null
      ? ''
      : "@font-face { font-family: 'KhalidArt'; src: url('${esc(fontUrl)}') format('truetype'); font-weight: 100 900; }";

  return '''<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<title>السجل الوسطي</title>
<style>
  $fontFace
  @page { size: A4 portrait; margin: 10mm; }
  * { box-sizing: border-box; }
  html, body { margin: 0; padding: 0; background: #fff; color: #000; }
  body { font-family: ${fontUrl == null ? '' : "'KhalidArt', "}Arial, Tahoma, sans-serif; font-size: 10.5pt;
         -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .page { width: 190mm; height: 277mm; margin: 0 auto; display: flex; flex-direction: column;
          page-break-after: always; break-after: page; overflow: hidden; }
  .page:last-child { page-break-after: auto; break-after: auto; }
  .top { display: flex; align-items: flex-start; justify-content: space-between; }
  .title { text-align: center; line-height: 1.35; }
  .t1 { font-size: 15pt; } .t2 { font-size: 13pt; } .t3 { font-size: 11pt; }
  .page-no, .spacer { width: 42mm; }
  .page-no { border: 0.8pt solid #000; padding: 1.5mm 2mm; text-align: center; font-size: 10pt; }
  .school { margin: 3mm auto 3mm; width: 70%; border: 0.8pt solid #000; border-radius: 3mm; padding: 1.5mm 4mm; }
  .dots { display: inline-block; width: 60%; border-bottom: 0.6pt dotted #000; }
  table { width: 190mm; border-collapse: collapse; table-layout: fixed; }
  th, td { border: 0.7pt solid #000; text-align: center; vertical-align: middle; padding: 0 0.6mm; }
  table.info th { font-size: 9.5pt; height: 9mm; background: #f2f2f2; }
  table.info td { height: 9mm; font-size: 10.5pt; }
  table.grid { margin-top: 4mm; }
  .c-subj { width: 33mm; } .c-val { width: 17.4mm; }
  table.grid thead th { height: 17mm; font-size: 9pt; line-height: 1.2; background: #f2f2f2; }
  table.grid th.subj { text-align: right; padding-right: 2mm; font-size: 10.5pt; }
  table.grid th.head { text-align: center; }
  table.grid tbody td, table.grid tbody th { height: 10.5mm; }
  table.grid td { font-size: 11pt; }
  table.grid td.note { font-size: 9pt; line-height: 1.1; }
  tr.total th, tr.total td { background: #f7f7f7; }
  tr.result td { text-align: right; padding-right: 3mm; font-size: 11.5pt; }
  footer { margin-top: auto; padding: 6mm 4mm 2mm; text-align: left; line-height: 1.6; }
  .toolbar { display: none; }
  @media screen {
    body { background: #888; padding: 0 0 8mm; }
    .page { background: #fff; box-shadow: 0 0 4mm rgba(0,0,0,.4); margin-bottom: 8mm; outline: 10mm solid #fff; }
    .toolbar { display: flex; gap: 10px; align-items: center; justify-content: center; position: sticky; top: 0;
               z-index: 9; background: #3D2B86; color: #fff; padding: 10px; margin-bottom: 8mm; font-size: 14px; }
    .toolbar button { font: inherit; font-weight: bold; border: 0; border-radius: 8px; padding: 8px 22px;
               background: #fff; color: #3D2B86; cursor: pointer; }
  }
</style>
</head>
<body>
<div class="toolbar">
  <button onclick="window.print()">🖨 طباعة / حفظ PDF</button>
  <span>الورق: A4 — الهوامش: افتراضي — المقياس: 100%</span>
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

String _fmt(double? v) {
  if (v == null) return '';
  final r = double.parse(v.toStringAsFixed(2));
  return r % 1 == 0 ? r.toInt().toString() : r.toString();
}

/// صفحات السجل الوسطي لكل طلاب [section] من الدرجات المستلمة.
String centralRecordHtmlFor(AppStore store, Section section, {String? fontUrl, String? onlyStudentId}) {
  final svc = AdminResultsService(store);
  var yearName = '';
  for (final y in store.years) {
    if (y.id == section.yearId) yearName = y.name;
  }
  final students = store.studentsOf(section.id).where((s) => onlyStudentId == null || s.id == onlyStudentId).toList();
  List<String> subjects = const [];
  final pages = <CentralRecordStudent>[];
  for (final st in students) {
    final r = svc.studentResult(st.id, section);
    subjects = r.subjects;
    pages.add(CentralRecordStudent(
      nameColumns: ArabicNameUtils.recordNameColumns(st.name),
      sectionLabel: '${section.gradeName} / ${section.name}',
      regNo: st.regNo,
      birthDate: st.birthDate,
      failedYears: st.failedYears,
      rows: {
        for (final subject in r.subjects)
          subject: () {
            final g = r.grades[subject];
            if (g == null) return const <String>[];
            return [...g.values.map(_fmt), g.note];
          }(),
      },
      totals: r.totals.map(_fmt).toList(),
      result: r.statusDetail,
    ));
  }
  final firstPage = onlyStudentId == null
      ? 1
      : store.studentsOf(section.id).indexWhere((s) => s.id == onlyStudentId) + 1;
  return buildCentralRecordHtml(
    schoolName: store.school?.name ?? '',
    academicYear: yearName,
    directorName: store.school?.directorName ?? '',
    subjects: subjects.isEmpty ? const [] : subjects,
    students: pages,
    fontUrl: fontUrl,
    firstPageNumber: firstPage,
  );
}
