import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/backup/file_saver.dart';
import '../../core/storage/app_store.dart';
import '../../models/academic.dart';
import '../../services/calculation_service.dart';
import '../../services/exchange_service.dart';

/// نسخة المدرس: استيراد قائمة الشعبة من الإدارة، وإرسال درجات المادة إليها.
class TeacherExchangePage extends StatefulWidget {
  const TeacherExchangePage({super.key, required this.store});
  final AppStore store;

  @override
  State<TeacherExchangePage> createState() => _TeacherExchangePageState();
}

class _TeacherExchangePageState extends State<TeacherExchangePage> {
  AppStore get store => widget.store;
  bool _busy = false;

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('ملفات الإدارة')),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _step(
                  icon: Icons.download_for_offline_outlined,
                  title: 'استيراد ملف الشعبة من الإدارة',
                  body: 'الإدارة ترسل لك ملفاً بقائمة طلاب الشعبة الموحّدة. استيراده يربط طلابك '
                      'بطلاب الإدارة حتى تصل درجاتك لكل طالب بدقة، ويضيف من ينقصك. لا يُحذف شيء من بياناتك.',
                  action: FilledButton.icon(
                    onPressed: _busy ? null : _importSectionFile,
                    icon: const Icon(Icons.file_open_outlined),
                    label: const Text('اختيار ملف الشعبة'),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('إرسال درجات المادة للإدارة',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.primaryDark)),
                const SizedBox(height: 4),
                Text(
                  'يُرسل النتائج المحسوبة فقط (معدلا الفصلين، نصف السنة، السعي، النهائي، الإكمال). '
                  'إذا عدّلت درجة بعد الإرسال، أرسل الملف من جديد فيحل محل القديم.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, height: 1.6),
                ),
                const SizedBox(height: 10),
                if (store.sections.isEmpty)
                  const Padding(padding: EdgeInsets.all(20), child: Text('لا توجد شعب بعد.'))
                else
                  for (final s in store.sections) _sectionCard(s),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _step({required IconData icon, required String title, required String body, required Widget action}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: AppTheme.primaryDark),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 6),
          Text(body, style: TextStyle(color: Colors.grey.shade700, height: 1.6)),
          const SizedBox(height: 12),
          action,
        ]),
      ),
    );
  }

  Widget _sectionCard(Section s) {
    final students = store.studentsOf(s.id);
    final linked = students.where((x) => x.adminId.isNotEmpty).length;
    final calc = CalculationService(store);
    final withFinal = students.where((x) => calc.year(x.id, s.id).finalGrade != null).length;
    final fromAdmin = s.adminSectionId.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s.gradeName} ${s.name}${s.subjectName.isEmpty ? '' : '، ${s.subjectName}'}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                fromAdmin
                    ? 'مرتبطة بالإدارة: $linked من ${students.length} طالب • الدرجة النهائية مكتملة لـ $withFinal'
                    : 'غير مرتبطة بملف من الإدارة (ستُطابق الأسماء) • الدرجة النهائية مكتملة لـ $withFinal من ${students.length}',
                style: TextStyle(fontSize: 12.5, color: fromAdmin ? Colors.grey.shade700 : const Color(0xFF8A5A00)),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _busy || students.isEmpty ? null : () => _sendGrades(s),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('إرسال'),
          ),
        ]),
      ),
    );
  }

  Future<void> _sendGrades(Section s) async {
    if (s.subjectName.trim().isEmpty) {
      _snack('حدد اسم المادة لهذه الشعبة أولاً من «الصفوف والشعب».');
      return;
    }
    final json = const JsonEncoder.withIndent(' ').convert(ExchangeService.buildGradesFile(store, s));
    final saved = await saveTextFile(ExchangeService.gradesFileName(s), json);
    if (saved && mounted) {
      _snack('تم تجهيز ملف درجات ${s.subjectName}. أرسله للإدارة (واتساب أو فلاش).');
    }
  }

  Future<void> _importSectionFile() async {
    final XFile? file;
    try {
      file = await openFile(acceptedTypeGroups: const [XTypeGroup(label: 'ملف شعبة', extensions: ['json'])]);
    } catch (_) {
      _snack('تعذر فتح نافذة اختيار الملف.');
      return;
    }
    if (file == null) return;

    final Object? decoded;
    final SectionFileInfo info;
    try {
      decoded = jsonDecode(await file.readAsString());
      info = ExchangeService.inspectSectionFile(decoded);
    } on FormatException catch (e) {
      _snack(e.message.contains('ملف') ? e.message : 'الملف ليس «ملف شعبة» صالحاً.');
      return;
    } catch (_) {
      _snack('تعذر قراءة الملف.');
      return;
    }
    if (!mounted) return;

    final subject = await _chooseSubject(info);
    if (subject == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final r = await ExchangeService.importSectionFile(store, decoded, subject);
      await store.setCurrentSection(r.section.id);
      if (!mounted) return;
      setState(() => _busy = false);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('تم استيراد ${info.grade} ${info.sectionName}'),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.createdSection ? 'أُنشئت شعبة جديدة لمادة $subject.' : 'رُبطت بشعبتك الموجودة لمادة $subject.'),
              const SizedBox(height: 6),
              Text('رُبط ${r.linked} طالباً بطلابك، وأُضيف ${r.added}.'),
              if (r.teacherOnly.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('عندك ${r.teacherOnly.length} طالب غير موجودين في قائمة الإدارة، ولن تصل درجاتهم:',
                    style: const TextStyle(color: Color(0xFF8A5A00), fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(r.teacherOnly.join('، '), style: const TextStyle(height: 1.6)),
                const SizedBox(height: 4),
                const Text('إذا كان الاسم مكتوباً بشكل مختلف، صحّحه ليطابق قائمة الإدارة ثم أعد الاستيراد.',
                    style: TextStyle(fontSize: 12.5)),
              ],
            ]),
            actions: [FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('تم'))],
          ),
        ),
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e is FormatException ? e.message : 'تعذر استيراد الملف.');
    }
  }

  /// اختيار المادة التي تدرّسها لهذه الشعبة من مواد الصف في الملف.
  Future<String?> _chooseSubject(SectionFileInfo info) {
    final mine = store.sections
        .where((s) => s.gradeName.trim() == info.grade.trim() && s.subjectName.trim().isNotEmpty)
        .map((s) => s.subjectName)
        .toSet();
    final options = info.subjects.isEmpty ? mine.toList() : info.subjects;
    String? chosen = options.firstWhere(
      (o) => mine.any((m) => m.trim() == o.trim()),
      orElse: () => options.isEmpty ? '' : options.first,
    );
    final custom = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('${info.grade} ${info.sectionName} (${info.studentCount} طالب)'),
            content: SizedBox(
              width: 420,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (info.schoolName.isNotEmpty) Text('من: ${info.schoolName}'),
                const SizedBox(height: 10),
                const Text('ما المادة التي تدرّسها لهذه الشعبة؟', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                if (options.isNotEmpty)
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final o in options)
                      ChoiceChip(
                        label: Text(o),
                        selected: chosen == o,
                        onSelected: (_) => setDialogState(() {
                          chosen = o;
                          custom.clear();
                        }),
                      ),
                  ]),
                const SizedBox(height: 10),
                TextField(
                  controller: custom,
                  decoration: const InputDecoration(labelText: 'أو اكتب اسم المادة'),
                  onChanged: (v) => setDialogState(() => chosen = v.trim().isEmpty ? null : v.trim()),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
              FilledButton(
                onPressed: (chosen ?? '').isEmpty ? null : () => Navigator.pop(dialogContext, chosen),
                child: const Text('استيراد'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
