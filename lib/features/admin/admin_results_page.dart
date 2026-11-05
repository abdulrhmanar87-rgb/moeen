import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/print/print_bridge.dart';
import '../../core/storage/app_store.dart';
import '../../models/academic.dart';
import '../../models/student.dart';
import '../../services/admin_results_service.dart';
import 'central_record_print.dart';

/// نسخة الإدارة: المواد المستلمة والناقصة، النتيجة العامة، وطباعة السجل الوسطي.
class AdminResultsPage extends StatefulWidget {
  const AdminResultsPage({super.key, required this.store});
  final AppStore store;

  @override
  State<AdminResultsPage> createState() => _AdminResultsPageState();
}

class _AdminResultsPageState extends State<AdminResultsPage> {
  AppStore get store => widget.store;
  late String? sectionId = store.currentSectionId;

  Section? get section {
    for (final s in store.sections) {
      if (s.id == sectionId) return s;
    }
    return null;
  }

  static const _statusColors = {
    'ناجح': Color(0xFF2E8B57),
    'ناجح بالإكمال': Color(0xFF4FA05A),
    'مكمل': Color(0xFFD9822B),
    'راسب': Color(0xFFD64545),
    'ناقص': Color(0xFF8A8599),
  };

  String _fmt(double? v) {
    if (v == null) return '—';
    final r = double.parse(v.toStringAsFixed(2));
    return r % 1 == 0 ? r.toInt().toString() : r.toString();
  }

  Future<void> _print({String? onlyStudentId}) async {
    final s = section;
    if (s == null) return;
    final html = centralRecordHtmlFor(
      store,
      s,
      onlyStudentId: onlyStudentId,
      fontUrl: Uri.base.resolve('assets/assets/fonts/KhalidArt-Bold.ttf').toString(),
    );
    final ok = await printHtml(html);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('منع المتصفح فتح صفحة الطباعة. اسمح بالنوافذ المنبثقة لهذا الموقع ثم أعد المحاولة.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = section;
    final svc = AdminResultsService(store);
    final students = s == null ? <Student>[] : store.studentsOf(s.id);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('النتائج والسجل الوسطي'),
          actions: [
            if (s != null && students.isNotEmpty && canPrintHtml)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: FilledButton.icon(
                  onPressed: () => _print(),
                  icon: const Icon(Icons.print_rounded),
                  label: const Text('طباعة السجل الوسطي'),
                ),
              ),
          ],
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: sectionId,
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
                if (s != null) ...[
                  const SizedBox(height: 14),
                  _summary(svc.summary(s)),
                  const SizedBox(height: 18),
                  const Text('المواد', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.primaryDark)),
                  const SizedBox(height: 8),
                  _receipts(svc.receipts(s)),
                  const SizedBox(height: 18),
                  const Text('الطلاب', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.primaryDark)),
                  const SizedBox(height: 8),
                  if (students.isEmpty)
                    const Text('لا يوجد طلاب في هذه الشعبة.')
                  else
                    Card(
                      child: Column(children: [
                        for (var i = 0; i < students.length; i++) ...[
                          _studentRow(i + 1, students[i], svc.studentResult(students[i].id, s)),
                          if (i < students.length - 1) const Divider(height: 1, indent: 14, endIndent: 14),
                        ],
                      ]),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summary(Map<String, int> m) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in m.entries)
          if (e.value > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: (_statusColors[e.key] ?? Colors.grey).withValues(alpha: .12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${e.key}: ${e.value}',
                  style: TextStyle(color: _statusColors[e.key], fontWeight: FontWeight.w800)),
            ),
      ]);

  Widget _receipts(List<SubjectReceipt> list) => Card(
        child: Column(children: [
          for (var i = 0; i < list.length; i++) ...[
            ListTile(
              dense: true,
              leading: Icon(
                list[i].isComplete
                    ? Icons.check_circle_rounded
                    : (list[i].isMissing ? Icons.radio_button_unchecked_rounded : Icons.timelapse_rounded),
                color: list[i].isComplete
                    ? AppTheme.success
                    : (list[i].isMissing ? Colors.grey : const Color(0xFFD9822B)),
              ),
              title: Text(list[i].subject, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(list[i].isMissing
                  ? 'لم تصل بعد'
                  : '${list[i].received} من ${list[i].total} طالب'
                      '${list[i].teacher.isEmpty ? '' : '، ${list[i].teacher}'}'),
            ),
            if (i < list.length - 1) const Divider(height: 1, indent: 56),
          ],
        ]),
      );

  Widget _studentRow(int n, Student st, StudentOverallResult r) {
    final status = r.status.isEmpty ? 'ناقص' : r.status;
    final color = _statusColors[status] ?? Colors.grey;
    return ListTile(
      leading: SizedBox(width: 26, child: Text('$n', style: TextStyle(color: Colors.grey.shade600))),
      title: Text(st.name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(r.statusDetail, style: TextStyle(color: color, fontSize: 12.5)),
      trailing: const Icon(Icons.chevron_left_rounded),
      onTap: () => _showStudent(st, r),
    );
  }

  void _showStudent(Student st, StudentOverallResult r) {
    const heads = ['الفصل 1', 'نصف السنة', 'الفصل 2', 'السعي', 'النهائي', 'النهائية', 'الإكمال', 'بعد الإكمال'];
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(st.name),
          content: SizedBox(
            width: 760,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 14,
                  headingRowHeight: 40,
                  columns: [
                    const DataColumn(label: Text('المادة')),
                    for (final h in heads) DataColumn(label: Text(h)),
                  ],
                  rows: [
                    for (final subject in r.subjects)
                      DataRow(cells: [
                        DataCell(Text(subject, style: const TextStyle(fontWeight: FontWeight.w700))),
                        for (var c = 0; c < heads.length; c++)
                          DataCell(Text(r.grades[subject] == null ? '' : _fmt(r.grades[subject]!.values[c]))),
                      ]),
                    DataRow(cells: [
                      const DataCell(Text('المجموع', style: TextStyle(fontWeight: FontWeight.w900))),
                      for (final t in r.totals) DataCell(Text(_fmt(t), style: const TextStyle(fontWeight: FontWeight.w800))),
                    ]),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            Text(r.statusDetail, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(width: 12),
            if (canPrintHtml)
              OutlinedButton.icon(
                onPressed: () => _print(onlyStudentId: st.id),
                icon: const Icon(Icons.print_outlined),
                label: const Text('طباعة صفحته'),
              ),
            FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
          ],
        ),
      ),
    );
  }
}
