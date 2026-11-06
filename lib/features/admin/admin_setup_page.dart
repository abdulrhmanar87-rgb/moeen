import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/storage/app_store.dart';
import '../../models/academic.dart';
import '../../models/school.dart';
import '../../services/exchange_service.dart';

/// نسخة الإدارة: بيانات المدرسة، الشعب، ومواد كل صف.
class AdminSetupPage extends StatefulWidget {
  const AdminSetupPage({super.key, required this.store});
  final AppStore store;

  @override
  State<AdminSetupPage> createState() => _AdminSetupPageState();
}

class _AdminSetupPageState extends State<AdminSetupPage> {
  late final _school = TextEditingController(text: store.school?.name ?? '');
  late final _director = TextEditingController(text: store.school?.directorName ?? '');
  late final _year = TextEditingController(text: store.years.isEmpty ? '2026-2027' : store.years.first.name);

  AppStore get store => widget.store;

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  void dispose() {
    _school.dispose();
    _director.dispose();
    _year.dispose();
    super.dispose();
  }

  int get _maxCompletion {
    final v = store.settings['maxCompletionSubjects'];
    return v is num ? v.toInt() : 3;
  }

  Future<void> _saveSchool() async {
    store.school ??= School(id: store.id(), name: '', code: '');
    store.school!
      ..name = _school.text.trim()
      ..directorName = _director.text.trim();
    final y = _year.text.trim().isEmpty ? '2026-2027' : _year.text.trim();
    store.ensureCurrentYear(y).name = y;
    await store.saveAll();
    if (mounted) _snack('تم حفظ بيانات المدرسة');
  }

  @override
  Widget build(BuildContext context) {
    final byGrade = <String, List<Section>>{};
    for (final s in store.sections) {
      byGrade.putIfAbsent(s.gradeName, () => []).add(s);
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الصفوف والشعب والمواد')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _editSection(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة شعبة'),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
              children: [
                if (byGrade.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(22),
                      child: Text('لا توجد شعب بعد. اضغط «إضافة شعبة» واكتب الصف (مثل: الخامس العلمي) واسم الشعبة (أ).',
                          style: TextStyle(height: 1.6)),
                    ),
                  ),
                for (final entry in byGrade.entries) _gradeCard(entry.key, entry.value),
                const SizedBox(height: 18),
                const Text('بيانات المدرسة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                TextField(controller: _school, decoration: const InputDecoration(labelText: 'اسم المدرسة (يظهر في «إدارة» بالسجل)')),
                const SizedBox(height: 10),
                TextField(controller: _director, decoration: const InputDecoration(labelText: 'اسم مدير المدرسة')),
                const SizedBox(height: 10),
                TextField(controller: _year, decoration: const InputDecoration(labelText: 'العام الدراسي')),
                const SizedBox(height: 10),
                FilledButton.icon(onPressed: _saveSchool, icon: const Icon(Icons.save_outlined), label: const Text('حفظ')),
                const SizedBox(height: 18),
                Card(
                  child: ListTile(
                    title: const Text('أقصى عدد لمواد الإكمال', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('الطالب الذي يقل في أكثر من $_maxCompletion مواد عن 50 يكون راسباً.'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        onPressed: _maxCompletion <= 1 ? null : () => _setMax(_maxCompletion - 1),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('$_maxCompletion', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      IconButton(
                        onPressed: _maxCompletion >= 10 ? null : () => _setMax(_maxCompletion + 1),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _setMax(int v) async {
    store.settings['maxCompletionSubjects'] = v;
    await store.saveAll();
    if (mounted) setState(() {});
  }

  Widget _gradeCard(String grade, List<Section> sections) {
    final subjects = ExchangeService.subjectsOf(store, grade);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.school_rounded, color: AdminColors.ink, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(grade, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
            TextButton.icon(
              onPressed: () => _editSection(grade: grade),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('شعبة'),
            ),
          ]),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final s in sections)
              InputChip(
                label: Text('${s.name}  (${store.studentsOf(s.id).length})'),
                onPressed: () => _editSection(section: s),
                onDeleted: () => _deleteSection(s),
              ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Text('مواد الصف (${subjects.length})', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            TextButton(onPressed: () => _editSubjects(grade), child: const Text('تعديل المواد')),
          ]),
          Text(subjects.join('، '), style: TextStyle(color: Colors.grey.shade700, height: 1.6)),
        ]),
      ),
    );
  }

  Future<void> _editSection({Section? section, String? grade}) async {
    final gradeC = TextEditingController(text: section?.gradeName ?? grade ?? '');
    final nameC = TextEditingController(text: section?.name ?? '');
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(section == null ? 'إضافة شعبة' : 'تعديل الشعبة'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: gradeC, decoration: const InputDecoration(labelText: 'الصف', hintText: 'مثال: الخامس العلمي')),
              const SizedBox(height: 10),
              TextField(controller: nameC, autofocus: true, decoration: const InputDecoration(labelText: 'الشعبة', hintText: 'مثال: أ')),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
              FilledButton(
                onPressed: () async {
                  final g = gradeC.text.trim(), n = nameC.text.trim();
                  if (g.isEmpty || n.isEmpty) {
                    setDialogState(() => error = 'أدخل الصف والشعبة.');
                    return;
                  }
                  if (store.sectionExists(g, n, '', exceptId: section?.id)) {
                    setDialogState(() => error = 'هذه الشعبة موجودة.');
                    return;
                  }
                  if (section == null) {
                    final created = await store.addSection(grade: g, name: n, subject: '');
                    await store.setCurrentSection(created.id);
                  } else {
                    section
                      ..gradeName = g
                      ..name = n;
                    await store.updateSection(section);
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true && mounted) setState(() {});
  }

  Future<void> _deleteSection(Section s) async {
    final n = store.studentsOf(s.id).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('حذف ${s.gradeName} ${s.name}؟'),
          content: Text(n == 0 ? 'الشعبة فارغة.' : 'سيُحذف $n طالب ودرجاتهم المستلمة في هذه الشعبة.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await store.deleteSection(s.id);
    if (mounted) setState(() {});
  }

  /// مواد الصف بالترتيب الذي تظهر به في السجل الوسطي.
  Future<void> _editSubjects(String grade) async {
    final list = List<String>.of(ExchangeService.subjectsOf(store, grade));
    final addC = TextEditingController();
    final saved = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('مواد $grade'),
            content: SizedBox(
              width: 440,
              height: 460,
              child: Column(children: [
                Expanded(
                  child: ReorderableListView(
                    buildDefaultDragHandles: false,
                    onReorderItem: (from, to) => setDialogState(() {
                      list.insert(to, list.removeAt(from));
                    }),
                    children: [
                      for (var i = 0; i < list.length; i++)
                        ListTile(
                          key: ValueKey('subject-$i-${list[i]}'),
                          dense: true,
                          title: Text(list[i]),
                          leading: ReorderableDragStartListener(
                            index: i,
                            child: const Icon(Icons.drag_indicator_rounded),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setDialogState(() => list.removeAt(i)),
                          ),
                        ),
                    ],
                  ),
                ),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: addC,
                      decoration: const InputDecoration(labelText: 'مادة جديدة'),
                      onSubmitted: (v) => setDialogState(() {
                        if (v.trim().isNotEmpty && !list.contains(v.trim())) list.add(v.trim());
                        addC.clear();
                      }),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_rounded, color: AdminColors.primary),
                    onPressed: () => setDialogState(() {
                      final v = addC.text.trim();
                      if (v.isNotEmpty && !list.contains(v)) list.add(v);
                      addC.clear();
                    }),
                  ),
                ]),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () => setDialogState(() {
                      list
                        ..clear()
                        ..addAll(ExchangeService.defaultSubjects(grade));
                    }),
                    child: const Text('استعادة القائمة المقترحة'),
                  ),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, list), child: const Text('حفظ')),
            ],
          ),
        ),
      ),
    );
    if (saved == null) return;
    await ExchangeService.setSubjects(store, grade, saved);
    if (mounted) setState(() {});
  }
}
