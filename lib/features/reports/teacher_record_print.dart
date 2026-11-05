import '../../core/utils/arabic_numbers.dart';

/// صف طالب في سجل المدرس: الاسم ثم قيم الأعمدة (نصوص جاهزة للعرض).
class TeacherRecordRow {
  const TeacherRecordRow(this.name, this.values);
  final String name;
  final List<String> values;
}

/// يبني صفحة HTML لسجل المدرس مضبوطة على ورق A4 عمودي:
/// - هوامش ثابتة، وكل صفحة بعدد ثابت من الطلاب مع تكرار الترويسة.
/// - جدول بعرض الصفحة بالضبط (من اليمين لليسار) وأعمدة بعرض محدد.
/// - أرقام بالسياق العربي، والطباعة بالأسود فقط.
String buildTeacherRecordHtml({
  required String schoolName,
  required String teacherName,
  required String subject,
  required String grade,
  required String sectionName,
  required String academicYear,
  required List<String> columns,
  required List<TeacherRecordRow> rows,
  int rowsPerPage = 22,
  String? fontUrl,
}) {
  String esc(String v) => v
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
  String value(String v) => v.trim().isEmpty
      ? '<span class="blank"></span>'
      : esc(ArabicNumbers.toArabic(v.trim()));

  final pages = <String>[];
  final pageCount = rows.isEmpty ? 1 : (rows.length / rowsPerPage).ceil();

  for (var p = 0; p < pageCount; p++) {
    final start = p * rowsPerPage;
    final slice = rows.skip(start).take(rowsPerPage).toList();
    final body = StringBuffer();
    for (var i = 0; i < rowsPerPage; i++) {
      // صفوف فارغة لإكمال الصفحة حتى يبقى طول الجدول ثابتاً في كل الصفحات.
      final row = i < slice.length ? slice[i] : null;
      body.write('<tr>');
      body.write('<td class="num">${row == null ? '' : ArabicNumbers.toArabic(start + i + 1)}</td>');
      // الأسماء الطويلة جداً تُصغَّر قليلاً حتى تظهر كاملة.
      final nameClass = row != null && row.name.length > 30 ? 'name long' : 'name';
      body.write('<td class="$nameClass">${row == null ? '' : esc(row.name)}</td>');
      for (var c = 0; c < columns.length; c++) {
        final v = row == null || c >= row.values.length ? '' : row.values[c];
        final cls = c == columns.length - 1 ? 'val note' : 'val';
        body.write('<td class="$cls">${v.isEmpty ? '' : esc(ArabicNumbers.toArabic(v))}</td>');
      }
      body.write('</tr>');
    }

    final heads = columns
        .map((c) => '<th class="v"><div>${esc(c)}</div></th>')
        .join();

    pages.add('''
<section class="page">
  <header class="box">
    <span><b>المدرسة:</b> ${value(schoolName)}</span>
    <span><b>المدرس:</b> ${value(teacherName)}</span>
    <span><b>المادة:</b> ${value(subject)}</span>
    <span><b>الصف:</b> ${value(grade)} / ${value(sectionName)}</span>
    <span><b>العام:</b> ${value(academicYear)}</span>
    ${pageCount > 1 ? '<span class="page-no">${ArabicNumbers.toArabic(p + 1)}/${ArabicNumbers.toArabic(pageCount)}</span>' : ''}
  </header>
  <table class="grid">
    <colgroup>
      <col style="width:6mm"><col class="name-col">
      ${[for (var c = 0; c < columns.length; c++) c == columns.length - 1 ? '<col class="note-col">' : '<col class="val-col">'].join()}
    </colgroup>
    <thead><tr><th>ت</th><th>اسم الطالب</th>$heads</tr></thead>
    <tbody>$body</tbody>
  </table>
  <footer>
    <span>توقيع المدرس: ..............................</span>
    <span>توقيع المدير: ..............................</span>
  </footer>
</section>''');
  }

  // A4 = 210×297mm. الهوامش 10mm => مساحة 190×277mm.
  // عرض عمود الاسم يُحسب ليملأ العرض المتبقي بدقة.
  // عمود الملاحظات (الأخير) أعرض ليتسع لـ«ناجح بالإكمال».
  final valueWidth = columns.length > 9 ? 9.5 : 10.0;
  const noteWidth = 19.0;
  final nameWidth = 190 - 6 - valueWidth * (columns.length - 1) - noteWidth;

  return '''<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<title>سجل المدرس - ${esc(grade)} ${esc(sectionName)}</title>
<style>
  ${fontUrl == null ? '' : "@font-face { font-family: 'KhalidArt'; src: url('${esc(fontUrl)}') format('truetype'); font-weight: 100 900; }"}
  @page { size: A4 portrait; margin: 10mm; }
  * { box-sizing: border-box; }
  html, body { margin: 0; padding: 0; background: #fff; color: #000; }
  body { font-family: ${fontUrl == null ? '' : "'KhalidArt', "}"Arial", "Tahoma", "Segoe UI", sans-serif; font-size: 10.5pt;
         -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .page { width: 190mm; height: 277mm; margin: 0 auto; display: flex; flex-direction: column;
          page-break-after: always; break-after: page; overflow: hidden; }
  .page:last-child { page-break-after: auto; break-after: auto; }
  /* شريط تعريفي واحد مختصر: العناصر بجانب بعضها أفقياً. */
  .box { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: baseline;
         column-gap: 2.5mm; row-gap: 1mm; border: 1pt solid #000; border-radius: 1.5mm;
         padding: 1.6mm 2.5mm; margin-bottom: 2mm; font-size: 9.5pt; line-height: 1.3; }
  .box span { white-space: nowrap; }
  .page-no { font-size: 9pt; }
  .blank { display: inline-block; width: 22mm; border-bottom: 0.6pt dotted #000; }
  table.grid { width: 190mm; border-collapse: collapse; table-layout: fixed; flex: 0 0 auto; }
  .name-col { width: ${nameWidth.toStringAsFixed(1)}mm; }
  .val-col { width: ${valueWidth.toStringAsFixed(1)}mm; }
  .note-col { width: ${noteWidth.toStringAsFixed(1)}mm; }
  table.grid td.note { font-size: 9.5pt; white-space: normal; line-height: 1.15; }
  table.grid th, table.grid td { border: 0.7pt solid #000; padding: 0 1mm; text-align: center;
          vertical-align: middle; overflow: hidden; white-space: nowrap; }
  table.grid thead th { background: #eee; font-size: 9pt; height: 30mm; }
  th.v div { writing-mode: vertical-rl; transform: rotate(180deg); margin: 0 auto;
             max-height: 29mm; line-height: 1.15; white-space: normal; }
  table.grid tbody td { height: 10.1mm; font-size: 10.5pt; padding: 0 0.5mm; }
  table.grid td.name { text-align: right; padding-right: 2.5mm; text-overflow: ellipsis; font-size: 13.5pt; font-weight: bold; }
  table.grid td.name.long { font-size: 11.5pt; }
  footer { display: flex; justify-content: space-between; margin-top: 5mm; padding: 0 2mm; font-size: 10.5pt; flex: 0 0 auto; }
  .toolbar { display: none; }
  @media screen {
    body { background: #888; padding: 0 0 8mm; }
    .toolbar { display: flex; gap: 10px; align-items: center; justify-content: center; position: sticky; top: 0;
               z-index: 9; background: #3D2B86; color: #fff; padding: 10px; margin-bottom: 8mm; font-size: 14px; }
    .toolbar button { font: inherit; font-weight: bold; border: 0; border-radius: 8px; padding: 8px 22px;
               background: #fff; color: #3D2B86; cursor: pointer; }
    .page { background: #fff; padding: 0; box-shadow: 0 0 4mm rgba(0,0,0,.4); margin-bottom: 8mm; outline: 10mm solid #fff; }
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
