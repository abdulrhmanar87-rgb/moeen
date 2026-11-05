import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/constants/semesters.dart';
import '../../core/storage/app_store.dart';
import '../../models/academic.dart';
import '../../services/calculation_service.dart';
import '../students/students_page.dart';
import '../attendance/attendance_page.dart';
import '../exams/exams_page.dart';
import '../reports/reports_page.dart';
import '../setup/setup_page.dart';
import '../results/results_page.dart';
import '../settings/settings_page.dart';
import '../settings/backup_actions.dart';
import '../exchange/teacher_exchange_page.dart';

/// الواجهة الرئيسية بفكرة «دفتر المدرس»:
/// صفحة مسطّرة بهامش أحمر للتحية والتاريخ، ثم الشعب كألسنة دفتر،
/// ثم مهام اليوم، ثم فهرس الأقسام.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store});
  final AppStore store;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  static const _ink = AppTheme.primaryDark;
  static const _tabColors = [
    Color(0xFF5B45B5),
    Color(0xFF2E8B7A),
    Color(0xFFD9822B),
    Color(0xFF3A7BD5),
    Color(0xFFC2477A),
    Color(0xFF6B8E23),
  ];

  static const _weekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
  static const _months = [
    'كانون الثاني', 'شباط', 'آذار', 'نيسان', 'أيار', 'حزيران',
    'تموز', 'آب', 'أيلول', 'تشرين الأول', 'تشرين الثاني', 'كانون الأول',
  ];

  AppStore get store => widget.store;

  Section? get _section {
    for (final s in store.sections) {
      if (s.id == store.currentSectionId) return s;
    }
    return store.sections.isEmpty ? null : store.sections.first;
  }

  Future<void> open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final section = _section;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                children: [
                  _topBar(),
                  const SizedBox(height: 10),
                  _notebookPage(),
                  if (BackupActions.needsReminder(store)) ...[
                    const SizedBox(height: 12),
                    _backupReminder(),
                  ],
                  const SizedBox(height: 26),
                  _heading('شعبي', trailing: TextButton.icon(
                    onPressed: () => open(SetupPage(store: store)),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('شعبة جديدة'),
                  )),
                  const SizedBox(height: 8),
                  _sectionTabs(section),
                  if (section != null) ...[
                    const SizedBox(height: 26),
                    _heading('مهام اليوم في ${section.gradeName} ${section.name}'),
                    const SizedBox(height: 10),
                    _todayActions(section),
                  ],
                  const SizedBox(height: 26),
                  _heading('كل الأقسام'),
                  const SizedBox(height: 10),
                  _index(section),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _topBar() => Row(children: [
        const Text('مُعين', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _ink)),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('مساعد الأستاذ', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'الإعدادات',
          onPressed: () => open(SettingsPage(store: store)),
          icon: const Icon(Icons.settings_outlined, color: _ink),
        ),
      ]);

  Widget _heading(String text, {Widget? trailing}) => Row(children: [
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
        ),
        if (trailing != null) trailing,
      ]);

  /// صفحة دفتر مسطّرة: التاريخ والتحية والفصل الحالي.
  Widget _notebookPage() {
    final now = DateTime.now();
    final date = '${_weekdays[now.weekday - 1]} ${now.day} ${_months[now.month - 1]} ${now.year}';
    final teacher = (store.settings['teacherName'] ?? '').toString().trim();
    final hello = now.hour < 12 ? 'صباح الخير' : 'مساء الخير';
    final greeting = teacher.isEmpty ? hello : '$hello، أستاذ $teacher';
    final year = store.years.isEmpty ? '' : store.years.first.name;
    final semester = Semesters.name(Semesters.current());
    final students = store.students.length;
    final sections = store.sections.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: CustomPaint(
        painter: const _RuledPaperPainter(),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(40, 20, 20, 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(date, style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600)),
            const SizedBox(height: 6),
            Text(greeting, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _ink, height: 1.3)),
            const SizedBox(height: 6),
            Text(
              year.isEmpty ? semester : '$semester، العام الدراسي $year',
              style: const TextStyle(fontSize: 14.5, color: Color(0xFF55506A)),
            ),
            const SizedBox(height: 14),
            Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 15, color: Color(0xFF55506A)),
                children: sections == 0
                    ? const [TextSpan(text: 'ابدأ بإضافة الصفوف والشعب التي تدرّسها.')]
                    : [
                        const TextSpan(text: 'في دفترك '),
                        TextSpan(text: '$students', style: const TextStyle(fontWeight: FontWeight.w900, color: _ink, fontSize: 18)),
                        const TextSpan(text: ' طالباً في '),
                        TextSpan(text: '$sections', style: const TextStyle(fontWeight: FontWeight.w900, color: _ink, fontSize: 18)),
                        TextSpan(text: sections == 1 ? ' شعبة.' : ' شعب.'),
                      ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// تذكير لطيف بحفظ نسخة احتياطية (يظهر إذا مرّ أسبوع على آخر نسخة).
  Widget _backupReminder() {
    final last = store.lastBackupAt;
    return Material(
      color: const Color(0xFFFFF6E0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFF1D58A)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(children: [
          const Icon(Icons.shield_outlined, color: Color(0xFF8A5A00)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              last == null
                  ? 'لم تحفظ نسخة احتياطية بعد. بياناتك موجودة في هذا المتصفح فقط.'
                  : 'آخر نسخة احتياطية ${BackupActions.ago(last)}. احفظ نسخة جديدة حتى لا تضيع الدرجات.',
              style: const TextStyle(color: Color(0xFF6B4700), height: 1.5),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8A5A00),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: () async {
              await BackupActions.export(context, store);
              if (mounted) setState(() {});
            },
            child: const Text('حفظ نسخة'),
          ),
        ]),
      ),
    );
  }

  /// الشعب كألسنة دفتر ملوّنة؛ اختيار شعبة يحدد ما تفتحه «مهام اليوم» والفهرس.
  Widget _sectionTabs(Section? selected) {
    if (store.sections.isEmpty) {
      return _emptySections();
    }
    final calc = CalculationService(store);
    final semester = Semesters.current();
    return SizedBox(
      height: 142,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: store.sections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final s = store.sections[i];
          final color = _tabColors[i % _tabColors.length];
          final students = store.studentsOf(s.id);
          final complete = students.where((st) => calc.semester(st.id, s.id, semester).isComplete).length;
          final isSelected = selected?.id == s.id;
          return _sectionTab(s, color, students.length, complete, isSelected);
        },
      ),
    );
  }

  Widget _sectionTab(Section s, Color color, int count, int complete, bool selected) {
    return SizedBox(
      width: 178,
      child: Material(
        color: selected ? Color.alphaBlend(color.withValues(alpha: .07), Colors.white) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? color : const Color(0xFFE6E2F2), width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // النقرة الأولى تختار الشعبة، والنقرة على الشعبة المختارة تفتح طلابها.
          onTap: selected
              ? () => open(StudentsPage(store: store, initialSectionId: s.id))
              : () async {
                  await store.setCurrentSection(s.id);
                  if (mounted) setState(() {});
                },
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // كعب اللسان الملوّن
            Container(width: 7, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(s.name, style: TextStyle(fontSize: 30, height: 1, fontWeight: FontWeight.w900, color: color)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.gradeName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, height: 1.2),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    s.subjectName.isEmpty ? '$count طالب' : '${s.subjectName}، $count طالب',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: count == 0 ? 0 : complete / count,
                      minHeight: 5,
                      color: color,
                      backgroundColor: color.withValues(alpha: .14),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    count == 0 ? 'لا يوجد طلاب بعد' : 'اكتمل سعي $complete من $count',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _emptySections() => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE6E2F2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            const Icon(Icons.bookmark_add_outlined, size: 34, color: AppTheme.primary),
            const SizedBox(width: 14),
            const Expanded(
              child: Text('لا توجد شعب بعد. أضف الصف والشعبة والمادة لتبدأ بإضافة الطلاب.', style: TextStyle(height: 1.5)),
            ),
            const SizedBox(width: 10),
            FilledButton(onPressed: () => open(SetupPage(store: store)), child: const Text('إضافة شعبة')),
          ]),
        ),
      );

  /// أكثر عملين يتكرران يومياً، للشعبة المختارة.
  Widget _todayActions(Section section) {
    return Row(children: [
      Expanded(
        child: _bigAction(
          icon: Icons.fact_check_rounded,
          title: 'تسجيل الحضور',
          subtitle: 'حاضر، غائب، مجاز',
          filled: true,
          onTap: () => open(AttendancePage(store: store, initialSectionId: section.id)),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _bigAction(
          icon: Icons.edit_note_rounded,
          title: 'إدخال الدرجات',
          subtitle: 'يومي، شهري، التقدير',
          filled: false,
          onTap: () => open(ExamsPage(store: store, initialSectionId: section.id)),
        ),
      ),
    ]);
  }

  Widget _bigAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool filled,
    required VoidCallback onTap,
  }) {
    final fg = filled ? Colors.white : _ink;
    return Material(
      color: filled ? _ink : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: filled ? BorderSide.none : const BorderSide(color: Color(0xFFD7D0F2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(children: [
            Icon(icon, color: fg, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: fg.withValues(alpha: .75), fontSize: 12.5)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  /// فهرس الدفتر: قائمة واحدة بفواصل بدل شبكة بطاقات متشابهة.
  Widget _index(Section? section) {
    final items = <(IconData, String, String, Widget)>[
      (Icons.groups_rounded, 'الطلاب', 'إضافة الطلاب وتعديلهم ونقلهم بين الشعب',
          StudentsPage(store: store, initialSectionId: section?.id)),
      (Icons.fact_check_outlined, 'الحضور والغياب', 'سجل الحضور اليومي لكل شعبة',
          AttendancePage(store: store, initialSectionId: section?.id)),
      (Icons.edit_note_rounded, 'الامتحانات والتقدير', 'اليومي، الشهري، نصف السنة، والسلوك والمشاركة',
          ExamsPage(store: store, initialSectionId: section?.id)),
      (Icons.calculate_outlined, 'النتائج', 'سعي الفصل لكل طالب وتفصيل حسابه', ResultsPage(store: store)),
      (Icons.print_outlined, 'التقارير وسجل المدرس', 'متابعة الشعبة وطباعة السجل على A4', ReportsPage(store: store)),
      (Icons.class_outlined, 'الصفوف والشعب', 'الصفوف والشعب وبيانات المدرسة', SetupPage(store: store)),
      (Icons.swap_vert_circle_outlined, 'ملفات الإدارة', 'استيراد قائمة الشعبة من الإدارة وإرسال درجات المادة إليها',
          TeacherExchangePage(store: store)),
    ];
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE6E2F2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (var i = 0; i < items.length; i++) ...[
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Icon(items[i].$1, color: _ink),
            title: Text(items[i].$2, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(items[i].$3, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
            trailing: const Icon(Icons.chevron_left_rounded, color: Color(0xFFA9A2BF)),
            onTap: () => open(items[i].$4),
          ),
          if (i < items.length - 1) const Divider(height: 1, indent: 56),
        ],
      ]),
    );
  }
}

/// ورقة دفتر: خلفية بيضاء، أسطر أفقية خفيفة، وهامش أحمر على اليمين.
class _RuledPaperPainter extends CustomPainter {
  const _RuledPaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final rule = Paint()
      ..color = const Color(0xFFE4E9F5)
      ..strokeWidth = 1;
    for (double y = 46; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }
    final margin = Paint()
      ..color = const Color(0xFFE38B8F)
      ..strokeWidth = 1.4;
    final x = size.width - 26;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), margin);
    // إطار خفيف
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFFE6E2F2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
