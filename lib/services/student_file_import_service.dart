import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../core/utils/arabic_name_utils.dart';
import '../models/student_import.dart';

class StudentFileImportResult {
  StudentFileImportResult({
    required this.items,
    required this.source,
    this.sheetName,
    this.detectedNameColumn,
    this.detectedNationalIdColumn,
    this.skippedLines = 0,
    this.warnings = const [],
  });

  final List<StudentImportItem> items;
  final String source;
  final String? sheetName;
  final String? detectedNameColumn;
  final String? detectedNationalIdColumn;

  /// عدد الأسطر/الصفوف التي تم تجاهلها لأنها لا تبدو أسماء طلاب
  /// (عناوين، اسم المدرسة، الصف، ملاحظات...).
  final int skippedLines;
  final List<String> warnings;
}

/// جدول مستخرج من Word: صفوف من خلايا نصية.
class _WordTable {
  _WordTable(this.rows, {required this.rtl});
  final List<List<String>> rows;
  final bool rtl;
}

/// مستورد أسماء الطلاب (الثلاثية/الرباعية) من ملفات Word (DOCX).
///
/// يدعم:
/// - الجداول بأي ترتيب أعمدة، مع أو بدون صف عناوين، وجداول متعددة.
/// - الاسم المجزأ على أعمدة (الاسم | الأب | الجد | اللقب) فيُدمج تلقائياً.
/// - الخلايا المدمجة أفقياً (gridSpan).
/// - القوائم النصية: سطر لكل اسم، مع تسلسل أو رقم وطني أو بدونهما،
///   والأسطر المفصولة بـ Tab، والأسماء داخل مربعات النص.
/// - النص العربي المقطّع داخل Word إلى أجزاء (runs) دون إدخال مسافات خاطئة.
class StudentFileImportService {
  Future<StudentFileImportResult> fromWord(Uint8List bytes) async {
    if (bytes.isEmpty) return _empty('ملف Word فارغ.');
    if (bytes.length > 4 && bytes[0] == 0xD0 && bytes[1] == 0xCF) {
      return _empty(
        'هذا ملف Word قديم بصيغة DOC. افتحه في Word واحفظه باسم DOCX ثم أعد الاستيراد.',
      );
    }

    final XmlDocument document;
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final entry = archive.findFile('word/document.xml');
      if (entry == null) {
        return _empty('ملف Word غير صالح أو لا يحتوي على نص.');
      }
      final xml = utf8.decode(entry.content as List<int>, allowMalformed: true);
      document = XmlDocument.parse(xml);
    } catch (e) {
      return _empty('تعذر فتح ملف Word. تأكد أن الملف بصيغة DOCX وغير تالف.');
    }

    final tables = <_WordTable>[];
    final paragraphs = <String>[];
    final body = _firstDescendant(document.rootElement, 'body') ??
        document.rootElement;
    _walkBlocks(body, tables, paragraphs);

    final items = <StudentImportItem>[];
    var skipped = 0;
    String? nameColumnLabel;
    String? idColumnLabel;

    for (final table in tables) {
      final parsed = _parseTable(table.rows, rtl: table.rtl);
      items.addAll(parsed.items);
      skipped += parsed.skipped;
      nameColumnLabel ??= parsed.nameLabel;
      idColumnLabel ??= parsed.idLabel;
    }

    final fromParagraphs = _parseParagraphs(paragraphs);
    items.addAll(fromParagraphs.items);
    skipped += fromParagraphs.skipped;

    final unique = _dedupe(items);
    final warnings = <String>[];
    if (unique.isEmpty) {
      warnings.add(
        'لم نجد أسماء طلاب في ملف Word. إذا كانت الأسماء صورة داخل الملف، استخدم الاستيراد من الصورة.',
      );
    }

    return StudentFileImportResult(
      items: unique,
      source: 'Word',
      detectedNameColumn: nameColumnLabel,
      detectedNationalIdColumn: idColumnLabel,
      skippedLines: skipped,
      warnings: warnings,
    );
  }

  // ---------------------------------------------------------------------------
  // قراءة بنية ملف Word
  // ---------------------------------------------------------------------------

  void _walkBlocks(
    XmlElement element,
    List<_WordTable> tables,
    List<String> paragraphs,
  ) {
    for (final child in element.childElements) {
      final name = child.name.local;
      if (name == 'p') {
        final text = _paragraphText(child);
        if (text.trim().isNotEmpty) paragraphs.add(text);
        // مربعات النص داخل الفقرة.
        for (final box in _textBoxes(child)) {
          _walkBlocks(box, tables, paragraphs);
        }
      } else if (name == 'tbl') {
        _readTable(child, tables, paragraphs);
      } else if (_skipElements.contains(name)) {
        continue;
      } else {
        _walkBlocks(child, tables, paragraphs);
      }
    }
  }

  void _readTable(
    XmlElement table,
    List<_WordTable> tables,
    List<String> paragraphs,
  ) {
    final tblPr = _firstChild(table, 'tblPr');
    final bidi = tblPr == null ? null : _firstChild(tblPr, 'bidiVisual');
    final rtl = bidi != null && _val(bidi) != '0' && _val(bidi) != 'false';

    final rows = <List<String>>[];
    for (final row in _deepChildren(table, 'tr', stopAt: const {'tbl'})) {
      final cells = <String>[];
      for (final cell in _deepChildren(row, 'tc', stopAt: const {'tbl'})) {
        final lines = <String>[];
        for (final child in cell.childElements) {
          final n = child.name.local;
          if (n == 'p') {
            final text = _paragraphText(child).trim();
            if (text.isNotEmpty) lines.add(text);
          } else if (n == 'tbl') {
            _readTable(child, tables, paragraphs); // جدول متداخل
          } else if (n == 'sdt') {
            final content = _firstChild(child, 'sdtContent');
            if (content != null) {
              for (final p in _deepChildren(content, 'p', stopAt: const {'tbl'})) {
                final text = _paragraphText(p).trim();
                if (text.isNotEmpty) lines.add(text);
              }
            }
          }
        }
        cells.add(lines.join('\n'));

        // خلية مدمجة أفقياً: نضيف خلايا فارغة لتبقى الأعمدة متطابقة.
        final tcPr = _firstChild(cell, 'tcPr');
        final span = tcPr == null ? null : _firstChild(tcPr, 'gridSpan');
        final spanCount = int.tryParse(span == null ? '' : _val(span) ?? '') ?? 1;
        for (var i = 1; i < spanCount; i++) {
          cells.add('');
        }
      }
      if (cells.any((c) => c.trim().isNotEmpty)) rows.add(cells);
    }
    if (rows.isNotEmpty) tables.add(_WordTable(rows, rtl: rtl));
  }

  /// نص الفقرة: أجزاء النص (runs) تُدمج بدون مسافات إضافية — Word يقطّع
  /// الكلمة العربية الواحدة أحياناً إلى عدة أجزاء — مع تحويل Tab والسطر الجديد.
  String _paragraphText(XmlElement paragraph) {
    final buffer = StringBuffer();
    void collect(XmlElement element) {
      for (final child in element.childElements) {
        final n = child.name.local;
        if (n == 't') {
          buffer.write(child.innerText);
        } else if (n == 'tab' || n == 'ptab') {
          buffer.write('\t');
        } else if (n == 'br' || n == 'cr') {
          buffer.write('\n');
        } else if (_skipElements.contains(n) ||
            n == 'txbxContent' ||
            n == 'drawing' ||
            n == 'pict' ||
            n == 'object' ||
            n == 'p' ||
            n == 'tbl') {
          continue;
        } else {
          collect(child);
        }
      }
    }

    collect(paragraph);
    return buffer.toString();
  }

  Iterable<XmlElement> _textBoxes(XmlElement paragraph) sync* {
    for (final child in paragraph.childElements) {
      final n = child.name.local;
      if (n == 'Fallback' || n == 'pPr' || n == 'rPr') continue;
      if (n == 'txbxContent') {
        yield child;
      } else {
        yield* _textBoxes(child);
      }
    }
  }

  // عناصر لا تحتوي نص الطالب: الخصائص والنص المحذوف ورموز الحقول
  // والنسخة الاحتياطية المكررة لمربعات النص.
  static const _skipElements = {
    'pPr',
    'rPr',
    'tblPr',
    'trPr',
    'tcPr',
    'sectPr',
    'del',
    'delText',
    'instrText',
    'Fallback',
    'tblGrid',
  };

  XmlElement? _firstChild(XmlElement e, String local) {
    for (final c in e.childElements) {
      if (c.name.local == local) return c;
    }
    return null;
  }

  XmlElement? _firstDescendant(XmlElement e, String local) {
    for (final c in e.descendantElements) {
      if (c.name.local == local) return c;
    }
    return null;
  }

  /// العناصر المطلوبة كأبناء مباشرين، أو داخل حاويات وسيطة مثل sdt.
  Iterable<XmlElement> _deepChildren(
    XmlElement e,
    String local, {
    Set<String> stopAt = const {},
  }) sync* {
    for (final c in e.childElements) {
      final n = c.name.local;
      if (n == local) {
        yield c;
      } else if (!stopAt.contains(n) && !_skipElements.contains(n)) {
        yield* _deepChildren(c, local, stopAt: stopAt);
      }
    }
  }

  String? _val(XmlElement e) {
    for (final a in e.attributes) {
      if (a.name.local == 'val') return a.value;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // تحليل الجداول
  // ---------------------------------------------------------------------------

  ({List<StudentImportItem> items, int skipped, String? nameLabel, String? idLabel})
      _parseTable(List<List<String>> rawRows, {required bool rtl}) {
    final rows = rawRows
        .map((r) => r.map((c) => c.replaceAll('\t', ' ').trim()).toList())
        .where((r) => r.any((c) => c.isNotEmpty))
        .toList();
    if (rows.isEmpty) {
      return (items: <StudentImportItem>[], skipped: 0, nameLabel: null, idLabel: null);
    }

    final maxCols = rows.map((r) => r.length).fold<int>(0, (a, b) => a > b ? a : b);

    // 1) صف العناوين (مطابقة كاملة للخلايا، وليس احتواء).
    var headerIndex = -1;
    for (var i = 0; i < rows.length && i < 6; i++) {
      if (rows[i].any(ArabicNameUtils.isNameHeader)) {
        headerIndex = i;
        break;
      }
    }
    final headers = headerIndex >= 0 ? rows[headerIndex] : const <String>[];
    final dataStart = headerIndex + 1;

    // 2) أعمدة الاسم.
    var nameCols = <int>[];
    var idCol = -1;
    if (headerIndex >= 0) {
      final mainCol = headers.indexWhere(ArabicNameUtils.isNameHeader);
      final parts = <(int role, int col)>[(0, mainCol)];
      for (var c = 0; c < headers.length; c++) {
        final role = ArabicNameUtils.namePartRole(headers[c]);
        if (role > 0) parts.add((role, c));
      }
      parts.sort((a, b) => a.$1.compareTo(b.$1));
      nameCols = parts.map((p) => p.$2).toList();
      idCol = headers.indexWhere(ArabicNameUtils.isNationalIdHeader);
    }

    if (nameCols.isEmpty) {
      final best = _bestNameColumn(rows, dataStart, maxCols);
      if (best < 0) {
        return (items: <StudentImportItem>[], skipped: 0, nameLabel: null, idLabel: null);
      }
      nameCols = _expandSplitName(rows, dataStart, maxCols, best, rtl: rtl);
    }
    if (idCol < 0) idCol = _bestIdColumn(rows, dataStart, maxCols, nameCols);

    // 3) استخراج الأسماء.
    final items = <StudentImportItem>[];
    var skipped = 0;
    final confidence = headerIndex >= 0 ? 1.0 : 0.97;

    for (var r = dataStart; r < rows.length; r++) {
      final row = rows[r];
      String cell(int c) => c >= 0 && c < row.length ? row[c] : '';

      if (row.any(ArabicNameUtils.isNameHeader)) continue; // عنوان مكرر بصفحة جديدة

      final nationalId = idCol >= 0 ? ArabicNameUtils.extractNationalId(cell(idCol)) : '';

      // خلية واحدة فيها عدة أسماء (كل اسم بسطر).
      final mainCell = cell(nameCols.first);
      final lines = mainCell.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (nameCols.length == 1 &&
          lines.length > 1 &&
          lines.where(ArabicNameUtils.looksLikeName).length == lines.length) {
        for (final line in lines) {
          items.add(_item(line, '', confidence));
        }
        continue;
      }

      final raw = nameCols.map((c) => cell(c).replaceAll('\n', ' ')).join(' ');
      if (!ArabicNameUtils.looksLikeName(raw)) {
        if (raw.trim().isNotEmpty) skipped++;
        continue;
      }
      items.add(_item(raw, nationalId, confidence));
    }

    return (
      items: items,
      skipped: skipped,
      nameLabel: headerIndex >= 0
          ? nameCols.map((c) => c < headers.length ? headers[c] : '').where((e) => e.isNotEmpty).join(' + ')
          : 'العمود ${nameCols.first + 1}',
      idLabel: idCol < 0
          ? null
          : (headerIndex >= 0 && idCol < headers.length ? headers[idCol] : 'العمود ${idCol + 1}'),
    );
  }

  int _bestNameColumn(List<List<String>> rows, int start, int maxCols) {
    var bestCol = -1;
    var bestScore = 0.0;
    for (var c = 0; c < maxCols; c++) {
      var score = 0.0;
      for (var r = start; r < rows.length && r < start + 120; r++) {
        if (c >= rows[r].length) continue;
        final v = rows[r][c];
        if (v.isEmpty) continue;
        final letters = ArabicNameUtils.arabicLetterCount(v);
        if (letters < 2 || ArabicNameUtils.isHeader(v)) continue;
        final words = ArabicNameUtils.words(v).length;
        // الاسم الثلاثي/الرباعي في عمود واحد يتفوق على الأعمدة المجزأة.
        score += words >= 3 ? 3 : (words == 2 ? 2 : 1);
      }
      if (score > bestScore) {
        bestScore = score;
        bestCol = c;
      }
    }
    return bestCol;
  }

  /// إذا كان عمود الاسم يحتوي غالباً كلمة واحدة، فالاسم مجزأ على أعمدة
  /// متجاورة (الاسم، الأب، الجد، اللقب) فنضمها بترتيب القراءة.
  List<int> _expandSplitName(
    List<List<String>> rows,
    int start,
    int maxCols,
    int best, {
    required bool rtl,
  }) {
    double avgWords(int c) {
      var total = 0, count = 0;
      for (var r = start; r < rows.length; r++) {
        if (c >= rows[r].length || rows[r][c].isEmpty) continue;
        total += ArabicNameUtils.words(rows[r][c]).length;
        count++;
      }
      return count == 0 ? 0 : total / count;
    }

    bool isNamePartColumn(int c) {
      if (c < 0 || c >= maxCols) return false;
      var good = 0, filled = 0;
      final distinct = <String>{};
      for (var r = start; r < rows.length; r++) {
        if (c >= rows[r].length || rows[r][c].isEmpty) continue;
        filled++;
        final v = rows[r][c];
        distinct.add(ArabicNameUtils.key(v));
        final w = ArabicNameUtils.words(v).length;
        if (w >= 1 && w <= 2 && ArabicNameUtils.arabicLetterCount(v) >= 2 &&
            !RegExp(r'\d').hasMatch(v) &&
            !ArabicNameUtils.isStatusWord(v)) {
          good++;
        }
      }
      // أعمدة مثل الجنس (ذكر/أنثى) أو النتيجة تتكرر قيمها فلا تُعد جزءاً من الاسم.
      final varied = filled < 4 || distinct.length / filled >= .6;
      return filled > 0 && good / filled >= .8 && varied;
    }

    if (avgWords(best) >= 1.5) return [best];

    // في الجدول من اليمين لليسار يكون ترتيب الخلايا في الملف هو ترتيب القراءة؛
    // وفي الجدول من اليسار لليمين يكون الاسم الأول في آخر خلية.
    final step = rtl ? 1 : -1;
    var first = best;
    while (isNamePartColumn(first - step)) {
      first -= step;
    }
    final cols = <int>[first];
    var next = first + step;
    while (cols.length < 5 && isNamePartColumn(next)) {
      cols.add(next);
      next += step;
    }
    return cols;
  }

  int _bestIdColumn(List<List<String>> rows, int start, int maxCols, List<int> nameCols) {
    var bestCol = -1;
    var bestScore = 0;
    for (var c = 0; c < maxCols; c++) {
      if (nameCols.contains(c)) continue;
      var score = 0;
      for (var r = start; r < rows.length && r < start + 60; r++) {
        if (c >= rows[r].length) continue;
        final v = rows[r][c];
        final id = ArabicNameUtils.extractNationalId(v);
        if (id.length >= 6 && ArabicNameUtils.arabicLetterCount(v) == 0) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        bestCol = c;
      }
    }
    return bestCol;
  }

  // ---------------------------------------------------------------------------
  // تحليل الفقرات النصية
  // ---------------------------------------------------------------------------

  ({List<StudentImportItem> items, int skipped}) _parseParagraphs(List<String> paragraphs) {
    final lines = paragraphs
        .expand((p) => p.split('\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return (items: <StudentImportItem>[], skipped: 0);

    // قائمة مرتبة بـ Tab (تسلسل ⇥ الاسم ⇥ الرقم الوطني) تعامل كجدول.
    final arabicLines = lines.where((l) => ArabicNameUtils.arabicLetterCount(l) >= 4).toList();
    final tabbed = arabicLines.where((l) => l.contains('\t')).length;
    if (arabicLines.length >= 3 && tabbed / arabicLines.length >= .6) {
      final rows = lines
          .map((l) => l.split(RegExp(r'\t+')).map((c) => c.trim()).toList())
          .toList();
      final parsed = _parseTable(rows, rtl: true);
      if (parsed.items.isNotEmpty) {
        return (items: parsed.items, skipped: parsed.skipped);
      }
    }

    final items = <StudentImportItem>[];
    var skipped = 0;
    for (final line in lines) {
      // سطر فيه عمودان من الأسماء مفصولان بـ Tab أو بمسافات كثيرة.
      final segments = line
          .split(RegExp(r'\t+| {4,}'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final candidates = segments.length > 1 &&
              segments.where(ArabicNameUtils.looksLikeName).length >= 2
          ? segments
          : [line];

      for (final segment in candidates) {
        if (!ArabicNameUtils.looksLikeName(segment)) {
          if (ArabicNameUtils.arabicLetterCount(segment) > 0) skipped++;
          continue;
        }
        items.add(_item(segment, ArabicNameUtils.extractNationalId(segment), .95));
      }
    }
    return (items: items, skipped: skipped);
  }

  // ---------------------------------------------------------------------------

  StudentImportItem _item(String raw, String nationalId, double confidence) {
    return StudentImportItem(
      name: ArabicNameUtils.cleanName(raw),
      nationalId: nationalId,
      confidence: confidence,
      source: 'Word',
    );
  }

  List<StudentImportItem> _dedupe(List<StudentImportItem> items) {
    final names = <String>{};
    final ids = <String>{};
    final result = <StudentImportItem>[];
    for (final item in items) {
      final nameKey = ArabicNameUtils.key(item.name);
      final idKey = item.nationalId.trim();
      if (nameKey.isEmpty) continue;
      if (idKey.isNotEmpty) {
        if (ids.contains(idKey)) continue;
        ids.add(idKey);
      } else if (names.contains(nameKey)) {
        continue;
      }
      names.add(nameKey);
      result.add(item);
    }
    return result;
  }

  StudentFileImportResult _empty(String warning) =>
      StudentFileImportResult(items: [], source: 'Word', warnings: [warning]);
}
