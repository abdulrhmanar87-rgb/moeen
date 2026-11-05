import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/backup/file_saver.dart';
import '../../core/storage/app_store.dart';
import '../../models/academic.dart';
import '../../services/exchange_service.dart';

/// نسخة الإدارة: إرسال ملفات الشعب للمدرسين، واستلام ملفات درجاتهم.
class AdminExchangePage extends StatefulWidget {
  const AdminExchangePage({super.key, required this.store, this.receive = false});
  final AppStore store;
  final bool receive;

  @override
  State<AdminExchangePage> createState() => _AdminExchangePageState();
}

class _ReceiveLine {
  _ReceiveLine.ok(this.fileName, GradesImportResult this.result) : error = null;
  _ReceiveLine.error(this.fileName, String this.error) : result = null;
  final String fileName;
  final GradesImportResult? result;
  final String? error;
}

class _AdminExchangePageState extends State<AdminExchangePage> {
  AppStore get store => widget.store;
  late int _tab = widget.receive ? 1 : 0;
  bool _busy = false;
  final List<_ReceiveLine> _lines = [];

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('ملفات المدرسين')),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 0, icon: Icon(Icons.outbox_rounded), label: Text('إرسال ملفات الشعب')),
                    ButtonSegment(value: 1, icon: Icon(Icons.move_to_inbox_rounded), label: Text('استلام الدرجات')),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (v) => setState(() => _tab = v.first),
                ),
                const SizedBox(height: 14),
                if (_tab == 0) ..._sendView() else ..._receiveView(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------

  List<Widget> _sendView() => [
        Text(
          'لكل شعبة ملف واحد فيه قائمة طلابها الموحّدة ومواد صفها. أرسل نفس الملف لكل مدرسي الشعبة '
          '(واتساب أو فلاش)، وكل مدرس يستورده من «ملفات الإدارة» في نسخته ويختار مادته. '
          'إذا أضفت طلاباً لاحقاً أرسل الملف من جديد.',
          style: TextStyle(color: Colors.grey.shade700, height: 1.6),
        ),
        const SizedBox(height: 12),
        if (store.sections.isEmpty) const Text('لا توجد شعب بعد.'),
        for (final s in store.sections)
          Card(
            child: ListTile(
              title: Text('${s.gradeName} ${s.name}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${store.studentsOf(s.id).length} طالب، ${ExchangeService.subjectsOf(store, s.gradeName).length} مادة'),
              trailing: FilledButton.icon(
                onPressed: store.studentsOf(s.id).isEmpty ? null : () => _sendSection(s),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('إرسال'),
              ),
            ),
          ),
      ];

  Future<void> _sendSection(Section s) async {
    final json = const JsonEncoder.withIndent(' ').convert(ExchangeService.buildSectionFile(store, s));
    final ok = await saveTextFile(ExchangeService.sectionFileName(s), json);
    if (ok && mounted) _snack('تم تجهيز ملف ${s.gradeName} ${s.name}. أرسله لمدرسي الشعبة.');
  }

  // ---------------------------------------------------------------------------

  List<Widget> _receiveView() => [
        Text(
          'اختر ملفات الدرجات التي أرسلها المدرسون، ويمكن اختيار عدة ملفات معاً. '
          'كل ملف يحل محل الدرجات السابقة لنفس المادة في نفس الشعبة.',
          style: TextStyle(color: Colors.grey.shade700, height: 1.6),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : _receive,
          icon: const Icon(Icons.file_open_outlined),
          label: const Text('اختيار ملفات الدرجات'),
        ),
        if (_busy) const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
        const SizedBox(height: 12),
        for (final line in _lines) _lineCard(line),
      ];

  Future<void> _receive() async {
    final List<XFile> files;
    try {
      files = await openFiles(acceptedTypeGroups: const [XTypeGroup(label: 'ملفات درجات', extensions: ['json'])]);
    } catch (_) {
      _snack('تعذر فتح نافذة اختيار الملفات.');
      return;
    }
    if (files.isEmpty) return;
    setState(() => _busy = true);
    final lines = <_ReceiveLine>[];
    for (final f in files) {
      try {
        final decoded = jsonDecode(await f.readAsString());
        final r = await ExchangeService.importGradesFile(store, decoded);
        lines.add(_ReceiveLine.ok(f.name, r));
      } on FormatException catch (e) {
        lines.add(_ReceiveLine.error(f.name, e.message.contains('ملف') || e.message.contains('شعبة') ? e.message : 'الملف تالف.'));
      } catch (_) {
        lines.add(_ReceiveLine.error(f.name, 'تعذر قراءة الملف.'));
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lines.insertAll(0, lines);
    });
  }

  Widget _lineCard(_ReceiveLine line) {
    final r = line.result;
    if (r == null) {
      return Card(
        color: const Color(0xFFFFEDED),
        child: ListTile(
          leading: const Icon(Icons.error_outline_rounded, color: Colors.red),
          title: Text(line.fileName, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(line.error ?? ''),
        ),
      );
    }
    final warn = r.unmatched.isNotEmpty || r.missingStudents.isNotEmpty || !r.subjectInList;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(warn ? Icons.info_outline_rounded : Icons.check_circle_rounded,
                color: warn ? const Color(0xFF8A5A00) : AppTheme.success),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${r.subject}: ${r.section.gradeName} ${r.section.name}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            '${r.teacher.isEmpty ? '' : 'من ${r.teacher}، '}وصلت درجات ${r.received} طالب'
            '${r.replaced ? '، وحلّت محل النسخة السابقة' : ''}.',
          ),
          if (!r.subjectInList)
            Text('«${r.subject}» ليست في قائمة مواد ${r.section.gradeName}، فلن تدخل في النتيجة. أضفها من «الصفوف والشعب والمواد».',
                style: const TextStyle(color: Color(0xFF8A5A00), height: 1.5)),
          if (r.unmatched.isNotEmpty)
            Text('أسماء عند المدرس غير موجودة في الشعبة: ${r.unmatched.join('، ')}',
                style: const TextStyle(color: Color(0xFF8A5A00), height: 1.5)),
          if (r.missingStudents.isNotEmpty)
            Text('لم تصل درجات: ${r.missingStudents.join('، ')}',
                style: const TextStyle(color: Color(0xFF8A5A00), height: 1.5)),
        ]),
      ),
    );
  }
}
