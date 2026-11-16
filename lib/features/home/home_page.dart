import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/app_version.dart';
import '../../core/ui/moeen_ui.dart';
import '../../core/constants/semesters.dart';
import '../../core/storage/app_store.dart';
import '../../models/academic.dart';
import '../students/students_page.dart';
import '../attendance/attendance_page.dart';
import '../exams/exams_page.dart';
import '../reports/reports_page.dart';
import '../setup/setup_page.dart';
import '../results/saee_book_page.dart';
import '../settings/settings_page.dart';
import '../settings/backup_actions.dart';
import '../exchange/teacher_exchange_page.dart';

/// الواجهة الرئيسية للمدرس:
/// - لوحة «الشعبة الحالية» بلون الحبر، عليها أسطر دفتر خفيفة وهامش،
///   وفيها حالة اليوم (الحضور، آخر امتحان) وأكثر عملين يتكرران.
/// - «شعبي»: قائمة هادئة لاختيار الشعبة.
/// - فهرس مقسّم: السجلات، ثم البيانات. كل وجهة تظهر مرة واحدة.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store});
  final AppStore store;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await BackupActions.remindOnOpen(context, widget.store);
      if (mounted) setState(() {});
    });
  }

  static const _weekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
  static const _months = [
    'كانون الثاني', 'شباط', 'آذار', 'نيسان', 'أيار', 'حزيران',
    'تموز', 'آب', 'أيلول', 'تشرين الأول', 'تشرين الثاني', 'كانون الأول',
  ];

  AppStore get store => widget.store;
  MoeenPalette get p => context.palette;

  Section? get _section {
    for (final s in store.sections) {
      if (s.id == store.currentSectionId) return s;
    }
    return store.sections.isEmpty ? null : store.sections.first;
  }

  String get _today {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  Future<void> _select(Section s) async {
    await store.setCurrentSection(s.id);
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
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 36),
                children: [
                  _topBar(),
                  _greeting(),
                  const SizedBox(height: 14),
                  if (section == null) _emptySections() else _currentPanel(section),
                  if (BackupActions.needsReminder(store)) ...[
                    const SizedBox(height: 12),
                    _backupReminder(),
                  ],
                  if (store.sections.isNotEmpty) ...[
                    _heading('شعبي', trailing: TextButton.icon(
                      onPressed: () => open(SetupPage(store: store)),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('شعبة'),
                    )),
                    _sectionList(section),
                  ],
                  _heading('السجلات'),
                  _group([
                    (Icons.table_chart_outlined, 'دفتر السعي', 'اليومي والشهري والتقدير أمام كل طالب',
                        () => open(SaeeBookPage(store: store, initialSectionId: section?.id))),
                    (Icons.menu_book_outlined, 'سجل المدرس النهائي', 'طباعة السجل على ورق A4',
                        () => open(ReportsPage(store: store))),
                  ]),
                  _heading('البيانات'),
                  _group([
                    (Icons.download_for_offline_outlined, 'ملفات الإدارة', 'استلام قائمة الطلاب وإرسال الدرجات',
                        () => open(TeacherExchangePage(store: store))),
                    (Icons.groups_outlined, 'الطلاب', 'قائمة الشعبة وملف كل طالب',
                        () => open(StudentsPage(store: store, initialSectionId: section?.id))),
                    (Icons.grid_view_rounded, 'الصفوف والشعب', 'الشعب وبيانات المدرسة',
                        () => open(SetupPage(store: store))),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _topBar() => SizedBox(
        height: 52,
        child: Row(children: [
          Text('مُعين', style: TextStyle(fontSize: 23, color: p.ink)),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(appVersion, style: TextStyle(fontSize: 12, color: p.faint)),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'الإعدادات',
            onPressed: () => open(SettingsPage(store: store)),
            icon: Icon(Icons.settings_outlined, color: p.ink),
          ),
        ]),
      );

  Widget _greeting() {
    final now = DateTime.now();
    final teacher = (store.settings['teacherName'] ?? '').toString().trim();
    final hello = now.hour < 12 ? 'صباح الخير' : 'مساء الخير';
    final year = store.years.isEmpty ? '' : '، ${store.years.first.name}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        '${_weekdays[now.weekday - 1]} ${now.day} ${_months[now.month - 1]} · ${Semesters.name(Semesters.current())}$year',
        style: TextStyle(fontSize: 13, color: p.muted),
      ),
      const SizedBox(height: 2),
      Text(teacher.isEmpty ? hello : '$hello، أستاذ $teacher', style: TextStyle(fontSize: 21, color: p.text, height: 1.4)),
    ]);
  }

  Widget _heading(String text, {Widget? trailing}) => MoeenHeading(text, trailing: trailing);

  // ---------------------------------------------------------------------------
  // لوحة الشعبة الحالية

  /// حالة حضور اليوم: (نص، لون النقطة).
  (String, Color) _attendanceStatus(Section s) {
    if (!store.attendanceTaken(s.id, _today)) return ('حضور اليوم لم يُسجَّل بعد', const Color(0xFFF2BE6A));
    var absent = 0;
    for (final st in store.studentsOf(s.id)) {
      if (store.attendanceOf(s.id, _today, st.id) == 'غائب') absent++;
    }
    return (absent == 0 ? 'حضور اليوم: الجميع حاضرون' : 'حضور اليوم: $absent غائب', const Color(0xFF7ED3A4));
  }

  /// آخر امتحان يومي في الفصل الحالي وكم أُدخل منه.
  (String, Color)? _examStatus(Section s) {
    final semester = Semesters.current();
    final exams = store.dailyExams.where((e) => e.sectionId == s.id && e.semester == semester).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (exams.isEmpty) return null;
    final e = exams.last;
    final total = store.studentsOf(s.id).length;
    final entered = store.dailyScores.where((x) => x.examId == e.id && (x.status == 'درجة' || x.status == 'غائب')).length;
    final done = total > 0 && entered >= total;
    return (
      done ? '${e.title}: اكتمل الإدخال' : '${e.title}: أُدخلت درجات $entered من $total',
      done ? const Color(0xFF7ED3A4) : const Color(0xFFF2BE6A),
    );
  }

  Widget _currentPanel(Section s) {
    final count = store.studentsOf(s.id).length;
    final statuses = [_attendanceStatus(s), _examStatus(s)].whereType<(String, Color)>();
    final sub = [if (s.subjectName.isNotEmpty) s.subjectName, '$count طالب'].join(' · ');
    return HeroPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${s.gradeName} · ${s.name}',
                        style: const TextStyle(fontSize: 25, color: Colors.white, height: 1.3)),
                    const SizedBox(height: 2),
                    Text(sub, style: TextStyle(fontSize: 13.5, color: Colors.white.withValues(alpha: .74))),
                  ]),
                ),
                if (store.sections.length > 1)
                  GlassChip(icon: Icons.swap_vert_rounded, label: 'تغيير', onTap: _pickSection),
              ]),
              const SizedBox(height: 14),
              for (final (text, color) in statuses)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(text, style: TextStyle(fontSize: 13.5, color: Colors.white.withValues(alpha: .9))),
                    ),
                  ]),
                ),
              const SizedBox(height: 9),
              Row(children: [
                Expanded(
                  child: PanelButton(
                    icon: Icons.fact_check_outlined,
                    label: 'تسجيل الحضور',
                    primary: true,
                    onTap: () => open(AttendancePage(store: store, initialSectionId: s.id)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PanelButton(
                    icon: Icons.edit_outlined,
                    label: 'إدخال الدرجات',
                    primary: false,
                    onTap: () => open(ExamsPage(store: store, initialSectionId: s.id)),
                  ),
                ),
              ]),
            ]),
    );
  }

  Future<void> _pickSection() async {
    final picked = await showModalBottomSheet<Section>(
      context: context,
      showDragHandle: true,
      builder: (sc) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text('اختر الشعبة', style: TextStyle(fontSize: 17, color: p.ink)),
              ),
              _sectionList(_section, onPick: (s) => Navigator.pop(sc, s)),
            ]),
          ),
        ),
      ),
    );
    if (picked != null) await _select(picked);
  }

  // ---------------------------------------------------------------------------

  Widget _sectionList(Section? selected, {ValueChanged<Section>? onPick}) {
    return MoeenSurface(
      children: [
        for (final s in store.sections)
          _row(
            leading: MoeenRadio(on: s.id == selected?.id),
            title: '${s.gradeName} · ${s.name}',
            subtitle: s.subjectName.isEmpty ? null : s.subjectName,
            selected: s.id == selected?.id,
            trailing: _sectionMeta(s),
            onTap: onPick != null
                ? () => onPick(s)
                // نقرة على شعبة أخرى تختارها، ونقرة على المختارة تفتح طلابها.
                : s.id == selected?.id
                    ? () => open(StudentsPage(store: store, initialSectionId: s.id))
                    : () => _select(s),
          ),
      ],
    );
  }

  Widget _sectionMeta(Section s) {
    final count = store.studentsOf(s.id).length;
    final taken = store.attendanceTaken(s.id, _today);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text.rich(TextSpan(children: [
        TextSpan(text: '$count', style: TextStyle(fontSize: 15, color: p.text)),
        TextSpan(text: ' طالب', style: TextStyle(fontSize: 12, color: p.muted)),
      ])),
      if (taken)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_rounded, size: 14, color: p.sem(AppTheme.success)),
          const SizedBox(width: 3),
          Text('حضور اليوم', style: TextStyle(fontSize: 11.5, color: p.sem(AppTheme.success))),
        ]),
    ]);
  }

  Widget _group(List<(IconData, String, String, VoidCallback)> items) => MoeenSurface(children: [
        for (final (icon, title, sub, onTap) in items)
          _row(
            leading: IconTile(icon),
            title: title,
            subtitle: sub,
            trailing: Icon(Icons.chevron_left_rounded, color: p.faint),
            onTap: onTap,
          ),
      ]);

  Widget _row({
    required Widget leading,
    required String title,
    String? subtitle,
    Widget? trailing,
    bool selected = false,
    required VoidCallback onTap,
  }) =>
      MoeenRow(leading: leading, title: title, subtitle: subtitle, trailing: trailing, selected: selected, onTap: onTap);

  // ---------------------------------------------------------------------------

  /// تذكير بحفظ نسخة احتياطية (يظهر إذا مرّ أسبوع على آخر نسخة).
  Widget _backupReminder() {
    final last = store.lastBackupAt;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: p.warnBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.warnBorder),
      ),
      child: Row(children: [
        Icon(Icons.shield_outlined, color: p.warnText, size: 21),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            last == null ? 'لم تحفظ نسخة احتياطية بعد.' : 'آخر نسخة احتياطية ${BackupActions.ago(last)}.',
            style: TextStyle(color: p.warnText, fontSize: 13, height: 1.5),
          ),
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: p.warnText,
            side: BorderSide(color: p.warnText.withValues(alpha: .7)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(0, 38),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () async {
            await BackupActions.export(context, store);
            if (mounted) setState(() {});
          },
          child: const Text('حفظ نسخة'),
        ),
      ]),
    );
  }

  Widget _emptySections() => HeroPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('ابدأ بشعبتك الأولى', style: TextStyle(fontSize: 23, color: Colors.white)),
                const SizedBox(height: 6),
                Text(
                  'استورد ملف الشعبة الذي أرسلته الإدارة، فتُضاف الشعبة وأسماء طلابها مرة واحدة. '
                  'أو أضف شعبة يدوياً إذا لم تستعمل مدرستك نسخة الإدارة.',
                  style: TextStyle(fontSize: 13.5, color: Colors.white.withValues(alpha: .8), height: 1.6),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: PanelButton(
                      icon: Icons.download_for_offline_outlined,
                      label: 'ملف الإدارة',
                      primary: true,
                      onTap: () => open(TeacherExchangePage(store: store)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PanelButton(
                      icon: Icons.add_rounded,
                      label: 'إضافة يدوية',
                      primary: false,
                      onTap: () => open(SetupPage(store: store)),
                    ),
                  ),
                ]),
              ]),
      );
}
