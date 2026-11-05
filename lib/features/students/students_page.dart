import 'package:flutter/material.dart';
import '../../core/storage/app_store.dart';
import '../../core/utils/arabic_numbers.dart';
import '../../models/student.dart';
import 'student_import_page.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key, required this.store, this.initialSectionId});
  final AppStore store;
  final String? initialSectionId;

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  late String? sectionId = _validInitial();
  String search = '';

  String? _validInitial() {
    final id = widget.initialSectionId;
    return widget.store.sections.any((s) => s.id == id) ? id : widget.store.currentSectionId;
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    sectionId ??= store.sections.isEmpty ? null : store.sections.first.id;

    final section = sectionId == null
        ? null
        : store.sections.where((s) => s.id == sectionId).firstOrNull;

    final allStudents =
        sectionId == null ? <Student>[] : store.studentsOf(sectionId!);

    final students = allStudents.where((student) {
      final q = search.trim().toLowerCase();
      if (q.isEmpty) return true;
      return student.name.toLowerCase().contains(q) ||
          student.nationalId.toLowerCase().contains(q);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الطلاب'),
          actions: [
            IconButton(
              tooltip: 'تحديث الترتيب',
              onPressed: () async {
                if (sectionId != null) {
                  await store.renumberSection(sectionId!);
                }
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.sort_by_alpha),
            ),
          ],
        ),
        floatingActionButton: sectionId == null
            ? null
            : FloatingActionButton.extended(
                onPressed: _showAddMenu,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('إضافة طلاب'),
              ),
        body: Column(
          children: [
            if (store.sections.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                child: DropdownButtonFormField<String>(
                  initialValue: sectionId,
                  decoration: const InputDecoration(
                    labelText: 'الشعبة الحالية',
                    prefixIcon: Icon(Icons.class_outlined),
                  ),
                  items: store.sections
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text('${s.gradeName} - ${s.name}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    sectionId = value;
                    store.setCurrentSection(value);
                    search = '';
                  }),
                ),
              ),
            if (section != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${section.gradeName} • ${section.name}'
                        '${section.subjectName.isEmpty ? '' : ' • ${section.subjectName}'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '${allStudents.length}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(width: 5),
                    const Text('طالب'),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: TextField(
                onChanged: (value) => setState(() => search = ArabicNumbers.toEnglish(value)),
                decoration: InputDecoration(
                  hintText: 'بحث باسم الطالب أو الرقم الوطني',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: search.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => setState(() => search = ''),
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
            ),
            Expanded(
              child: students.isEmpty
                  ? _emptyState(allStudents.isEmpty)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
                      itemCount: students.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _studentCard(
                        context,
                        students[i],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(bool noStudents) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              noStudents ? Icons.groups_2_outlined : Icons.search_off_outlined,
              size: 58,
            ),
            const SizedBox(height: 12),
            Text(
              noStudents
                  ? 'لا يوجد طلاب في هذه الشعبة'
                  : 'لا توجد نتائج مطابقة للبحث',
              textAlign: TextAlign.center,
            ),
            if (noStudents) ...[
              const SizedBox(height: 8),
              const Text(
                'أضف أسماء الطلاب فقط، ومُعين يتولى الترقيم والترتيب تلقائياً.',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _studentCard(
    BuildContext context,
    Student student,
  ) {
    final serial = '${ArabicNumbers.parseInt(student.number) ?? 0}';

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          radius: 25,
          child: Text(
            serial,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          student.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: student.nationalId.isEmpty
            ? null
            : Text('الرقم الوطني: ${student.nationalId}'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'profile') {
              showStudentProfile(student);
            } else if (value == 'edit') {
              addOrEditStudent(student: student);
            } else if (value == 'move') {
              moveStudent(student);
            } else if (value == 'archive') {
              archiveStudent(student);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'profile',
              child: ListTile(
                leading: Icon(Icons.person_outline),
                title: Text('ملف الطالب'),
              ),
            ),
            PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('تعديل البيانات'),
              ),
            ),
            PopupMenuItem(
              value: 'move',
              child: ListTile(
                leading: Icon(Icons.swap_horiz_outlined),
                title: Text('نقل إلى شعبة'),
              ),
            ),
            PopupMenuItem(
              value: 'archive',
              child: ListTile(
                leading: Icon(Icons.archive_outlined),
                title: Text('أرشفة من الشعبة'),
              ),
            ),
          ],
        ),
        onTap: () => showStudentProfile(student),
      ),
    );
  }

  /// يفتح شاشة الإضافة مباشرة (كتابة/لصق، Word، صورة) — اسم واحد أو قائمة كاملة.
  Future<void> _showAddMenu() async {
    if (sectionId == null) return;
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => StudentImportPage(store: widget.store, sectionId: sectionId!)),
    );
    if (added == true && mounted) setState(() {});
  }

  Future<void> addOrEditStudent({Student? student}) async {
    final store = widget.store;
    final name = TextEditingController(text: student?.name ?? '');
    final nationalId =
        TextEditingController(text: student?.nationalId ?? '');
    final notes = TextEditingController(text: student?.notes ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(student == null ? 'إضافة طالب' : 'تعديل بيانات الطالب'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'اسم الطالب *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nationalId,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [EnglishDigitsFormatter()],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'الرقم الوطني (اختياري)',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notes,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات (اختياري)',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'مُعين يتولى الرقم التسلسلي والترتيب الأبجدي تلقائياً.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
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
                final studentName = name.text.trim();

                if (studentName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال اسم الطالب.')),
                  );
                  return;
                }

                if (student == null) {
                  final newStudent = Student(
                    id: store.id(),
                    schoolId: store.school?.id ?? '',
                    number: '0',
                    name: studentName,
                    nationalId: ArabicNumbers.toEnglish(nationalId.text.trim()),
                    notes: notes.text.trim(),
                    createdAt: DateTime.now().toIso8601String(),
                  );
                  await store.addStudent(
                    newStudent,
                    sectionId!,
                    store.years.first.id,
                  );
                } else {
                  student
                    ..name = studentName
                    ..nationalId = ArabicNumbers.toEnglish(nationalId.text.trim())
                    ..notes = notes.text.trim();
                  await store.updateStudent(student);
                  await store.renumberSection(sectionId!);
                }

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    name.dispose();
    nationalId.dispose();
    notes.dispose();

    if (saved == true && mounted) {
      setState(() {});
    }
  }

  Future<void> showStudentProfile(Student student) async {
    final store = widget.store;
    final enrollment = store.enrollments
        .where((e) => e.studentId == student.id && e.endDate == null)
        .firstOrNull;

    final section = enrollment == null
        ? null
        : store.sections
            .where((s) => s.id == enrollment.sectionId)
            .firstOrNull;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        child: Text(
                          student.name.trim().isEmpty
                              ? '?'
                              : student.name.trim().characters.first,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text('التسلسل: ${student.number}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _infoRow('الصف والشعبة', section == null
                      ? 'غير محددة'
                      : '${section.gradeName} - ${section.name}'),
                  _infoRow(
                    'المادة',
                    section?.subjectName.isEmpty ?? true
                        ? 'غير محددة'
                        : section!.subjectName,
                  ),
                  if (student.nationalId.isNotEmpty)
                    _infoRow('الرقم الوطني', student.nationalId),
                  if (student.notes.isNotEmpty)
                    _infoRow('ملاحظات', student.notes),
                  const Divider(height: 28),
                  const Text(
                    'سيظهر السجل الدراسي هنا تدريجياً:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      Chip(label: Text('الحضور')),
                      Chip(label: Text('السلوك')),
                      Chip(label: Text('المشاركة')),
                      Chip(label: Text('الامتحانات اليومية')),
                      Chip(label: Text('الدرجات الشهرية')),
                      Chip(label: Text('النتائج')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 115,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );

  Future<void> moveStudent(Student student) async {
    final store = widget.store;
    final targets =
        store.sections.where((section) => section.id != sectionId).toList();

    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد شعبة أخرى متاحة للنقل.')),
      );
      return;
    }

    String? targetId = targets.first.id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('نقل الطالب'),
            content: DropdownButtonFormField<String>(
              initialValue: targetId,
              decoration: const InputDecoration(labelText: 'الشعبة الجديدة'),
              items: targets
                  .map(
                    (s) => DropdownMenuItem(
                      value: s.id,
                      child: Text('${s.gradeName} - ${s.name}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setDialogState(() => targetId = value),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('تأكيد النقل'),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && targetId != null) {
      final from = sectionId!;
      await store.moveStudent(
        studentId: student.id,
        fromSectionId: from,
        toSectionId: targetId!,
        yearId: store.sections.firstWhere((s) => s.id == targetId).yearId,
      );
      await store.renumberSection(from);
      await store.renumberSection(targetId!);
      if (mounted) setState(() {});
    }
  }

  Future<void> archiveStudent(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('أرشفة الطالب'),
          content: const Text(
            'سيتم إنهاء ارتباط الطالب بهذه الشعبة مع الاحتفاظ ببياناته وسجله التاريخي. هل تريد المتابعة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('أرشفة'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await widget.store.archiveStudentFromSection(student.id, sectionId!);
      await widget.store.renumberSection(sectionId!);
      if (mounted) setState(() {});
    }
  }
}
