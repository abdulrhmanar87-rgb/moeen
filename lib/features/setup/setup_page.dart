import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/storage/app_store.dart';
import '../../models/school.dart';
import '../../models/academic.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({super.key, required this.store});
  final AppStore store;

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final schoolName = TextEditingController();
  final schoolCode = TextEditingController();
  final director = TextEditingController();
  final teacher = TextEditingController();
  final year = TextEditingController();

  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    final s = store.school;
    schoolName.text = s?.name ?? '';
    schoolCode.text = s?.code ?? '';
    director.text = s?.directorName ?? '';
    teacher.text = (store.settings['teacherName'] ?? '').toString();
    year.text = store.years.isEmpty ? '2026-2027' : store.years.first.name;
  }

  @override
  void dispose() {
    for (final c in [schoolName, schoolCode, director, teacher, year]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> saveSchool() async {
    store.school ??= School(id: store.id(), name: '', code: '');
    store.school!
      ..name = schoolName.text.trim()
      ..code = schoolCode.text.trim()
      ..directorName = director.text.trim();
    store.settings['teacherName'] = teacher.text.trim();

    final yearName = year.text.trim().isEmpty ? '2026-2027' : year.text.trim();
    store.ensureCurrentYear(yearName).name = yearName;

    await store.saveAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ بيانات المدرسة')),
    );
    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // الصفوف والشعب
  // ---------------------------------------------------------------------------

  Future<void> editSection({Section? section}) async {
    final grades = store.sections.map((s) => s.gradeName).where((g) => g.isNotEmpty).toSet().toList();
    final last = store.sections.isEmpty ? null : store.sections.last;
    final grade = TextEditingController(text: section?.gradeName ?? last?.gradeName ?? '');
    final name = TextEditingController(text: section?.name ?? '');
    final subject = TextEditingController(text: section?.subjectName ?? last?.subjectName ?? '');
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(section == null ? 'إضافة صف / شعبة' : 'تعديل الشعبة'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: grade,
                      autofocus: section == null && grade.text.isEmpty,
                      decoration: const InputDecoration(
                        labelText: 'الصف *',
                        hintText: 'مثال: الرابع العلمي',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      onChanged: (_) => setDialogState(() => error = null),
                    ),
                    if (grades.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: grades
                            .map((g) => ActionChip(
                                  label: Text(g),
                                  onPressed: () => setDialogState(() => grade.text = g),
                                ))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: name,
                      autofocus: section == null && grade.text.isNotEmpty,
                      decoration: const InputDecoration(
                        labelText: 'الشعبة *',
                        hintText: 'مثال: أ',
                        prefixIcon: Icon(Icons.class_outlined),
                      ),
                      onChanged: (_) => setDialogState(() => error = null),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subject,
                      decoration: const InputDecoration(
                        labelText: 'المادة',
                        hintText: 'مثال: الرياضيات',
                        prefixIcon: Icon(Icons.menu_book_outlined),
                      ),
                      onChanged: (_) => setDialogState(() => error = null),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(error!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final g = grade.text.trim();
                  final n = name.text.trim();
                  final sub = subject.text.trim();
                  if (g.isEmpty || n.isEmpty) {
                    setDialogState(() => error = 'أدخل اسم الصف واسم الشعبة.');
                    return;
                  }
                  if (store.sectionExists(g, n, sub, exceptId: section?.id)) {
                    setDialogState(() => error = 'هذه الشعبة موجودة مسبقاً.');
                    return;
                  }
                  if (section == null) {
                    await store.addSection(grade: g, name: n, subject: sub);
                  } else {
                    section
                      ..gradeName = g
                      ..name = n
                      ..subjectName = sub;
                    await store.updateSection(section);
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );

    grade.dispose();
    name.dispose();
    subject.dispose();
    if (saved == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(section == null ? 'تمت إضافة الشعبة' : 'تم تعديل الشعبة'),
      ));
    }
  }

  Future<void> deleteSection(Section section) async {
    final count = store.studentsOf(section.id).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الشعبة؟'),
          content: Text(
            count == 0
                ? 'سيتم حذف شعبة ${section.gradeName} - ${section.name}.'
                : 'في شعبة ${section.gradeName} - ${section.name} عدد $count طالب.\n'
                    'سيتم حذف الشعبة مع طلابها وحضورهم ودرجاتهم فيها، ولا يمكن التراجع.\n'
                    'لنقل الطلاب إلى شعبة أخرى قبل الحذف استخدم «نقل» من صفحة الطلاب.',
            style: const TextStyle(height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
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
    await store.deleteSection(section.id);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حذف الشعبة')),
    );
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // الشعب مجمعة حسب الصف ومرتبة.
    final byGrade = <String, List<Section>>{};
    for (final s in store.sections) {
      byGrade.putIfAbsent(s.gradeName, () => []).add(s);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الإعداد الأولي والمدرسة')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => editSection(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة صف / شعبة'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
          children: [
            _title('الصفوف والشعب', '${store.sections.length} شعبة'),
            const SizedBox(height: 10),
            if (store.sections.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(children: [
                    const Icon(Icons.class_outlined, size: 46, color: AppTheme.primary),
                    const SizedBox(height: 8),
                    const Text('لا توجد شعب بعد', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text('أضف الصفوف والشعب التي تدرّسها، ويمكنك إضافة أكثر من صف وأكثر من شعبة.', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => editSection(),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('إضافة أول شعبة'),
                    ),
                  ]),
                ),
              )
            else
              for (final entry in byGrade.entries)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          const Icon(Icons.school_rounded, color: AppTheme.primaryDark, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.key.isEmpty ? 'بدون اسم صف' : entry.key,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _addToGrade(entry.key, entry.value),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('شعبة أخرى'),
                          ),
                        ]),
                        for (final s in entry.value)
                          ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            leading: CircleAvatar(
                              radius: 17,
                              backgroundColor: AppTheme.softPurple,
                              child: Text(
                                s.name.isEmpty ? '?' : s.name.characters.first,
                                style: const TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.w800),
                              ),
                            ),
                            title: Text('شعبة ${s.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              '${s.subjectName.isEmpty ? 'بدون مادة' : s.subjectName} • ${store.studentsOf(s.id).length} طالب',
                            ),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                tooltip: 'تعديل',
                                onPressed: () => editSection(section: s),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'حذف',
                                onPressed: () => deleteSection(s),
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              ),
                            ]),
                          ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 22),
            _title('بيانات المدرسة', null),
            const SizedBox(height: 12),
            _field(schoolName, 'اسم المدرسة'),
            _field(schoolCode, 'معرف المدرسة'),
            _field(director, 'اسم المدير'),
            _field(teacher, 'اسم المدرس (يظهر في سجل المدرس)'),
            _field(year, 'العام الدراسي'),
            FilledButton.icon(
              onPressed: saveSchool,
              icon: const Icon(Icons.save_outlined),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('حفظ بيانات المدرسة'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// إضافة شعبة جديدة لنفس الصف مع اقتراح الحرف التالي (أ ← ب ← ج ...).
  Future<void> _addToGrade(String grade, List<Section> existing) async {
    const letters = ['أ', 'ب', 'ج', 'د', 'هـ', 'و', 'ز', 'ح', 'ط', 'ي', 'ك', 'ل'];
    final used = existing.map((s) => s.name.trim()).toSet();
    final next = letters.firstWhere((l) => !used.contains(l), orElse: () => '');
    final subject = existing.isEmpty ? '' : existing.last.subjectName;
    if (next.isNotEmpty && !store.sectionExists(grade, next, subject)) {
      await store.addSection(grade: grade, name: next, subject: subject);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('تمت إضافة شعبة $next إلى $grade'),
        action: SnackBarAction(
          label: 'تعديل',
          onPressed: () {
            final added = store.sections.lastWhere((s) => s.gradeName == grade && s.name == next);
            editSection(section: added);
          },
        ),
      ));
    } else {
      await editSection();
    }
  }

  Widget _title(String text, String? trailing) => Row(children: [
        Expanded(child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
        if (trailing != null) Chip(label: Text(trailing)),
      ]);

  Widget _field(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: c, decoration: InputDecoration(labelText: label)),
      );
}
