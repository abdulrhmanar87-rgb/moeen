import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/storage/app_store.dart';
import '../../models/academic.dart';
import '../../services/admin_results_service.dart';
import '../settings/backup_actions.dart';
import '../settings/settings_page.dart';
import '../students/students_page.dart';
import 'admin_exchange_page.dart';
import 'admin_results_page.dart';
import 'admin_setup_page.dart';
import 'admin_student_info_page.dart';

/// الواجهة الرئيسية لنسخة الإدارة.
class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key, required this.store});
  final AppStore store;

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  static const _ink = AppTheme.primaryDark;
  AppStore get store => widget.store;

  Section? get _section {
    for (final s in store.sections) {
      if (s.id == store.currentSectionId) return s;
    }
    return null;
  }

  Future<void> open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final section = _section;
    final svc = AdminResultsService(store);
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
                  Row(children: [
                    const Text('مُعين', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _ink)),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('نسخة الإدارة', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'الإعدادات',
                      onPressed: () => open(SettingsPage(store: store)),
                      icon: const Icon(Icons.settings_outlined, color: _ink),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  _header(),
                  if (BackupActions.needsReminder(store)) ...[
                    const SizedBox(height: 10),
                    _backupReminder(),
                  ],
                  const SizedBox(height: 24),
                  Row(children: [
                    const Expanded(
                      child: Text('الشعب', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
                    ),
                    TextButton.icon(
                      onPressed: () => open(AdminSetupPage(store: store)),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('شعبة جديدة'),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  _sectionTabs(section, svc),
                  const SizedBox(height: 24),
                  const Text('الخطوات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
                  const SizedBox(height: 10),
                  _steps(section),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final school = store.school?.name ?? '';
    final year = store.years.isEmpty ? '' : store.years.first.name;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(school.isEmpty ? 'اسم المدرسة لم يُكتب بعد' : school,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(
          '${year.isEmpty ? '' : 'العام الدراسي $year، '}${store.sections.length} شعبة، ${store.students.length} طالب',
          style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 14.5),
        ),
      ]),
    );
  }

  Widget _backupReminder() => Material(
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
                'آخر نسخة احتياطية: ${BackupActions.ago(store.lastBackupAt)}. درجات كل المواد هنا، فاحفظ نسخة.',
                style: const TextStyle(color: Color(0xFF6B4700), height: 1.5),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8A5A00)),
              onPressed: () async {
                await BackupActions.export(context, store);
                if (mounted) setState(() {});
              },
              child: const Text('حفظ نسخة'),
            ),
          ]),
        ),
      );

  Widget _sectionTabs(Section? selected, AdminResultsService svc) {
    if (store.sections.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            const Expanded(child: Text('ابدأ بإضافة الصفوف والشعب ومواد كل صف.', style: TextStyle(height: 1.5))),
            FilledButton(onPressed: () => open(AdminSetupPage(store: store)), child: const Text('إضافة شعبة')),
          ]),
        ),
      );
    }
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: store.sections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final s = store.sections[i];
          final receipts = svc.receipts(s);
          final done = receipts.where((r) => r.isComplete).length;
          final isSelected = selected?.id == s.id;
          return SizedBox(
            width: 170,
            child: Material(
              color: isSelected ? const Color(0xFFF1EEFB) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: isSelected ? _ink : const Color(0xFFE6E2F2), width: isSelected ? 2 : 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: isSelected
                    ? () => open(AdminResultsPage(store: store))
                    : () async {
                        await store.setCurrentSection(s.id);
                        if (mounted) setState(() {});
                      },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(s.name, style: const TextStyle(fontSize: 28, height: 1, fontWeight: FontWeight.w900, color: _ink)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(s.gradeName,
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ]),
                    const Spacer(),
                    Text('${store.studentsOf(s.id).length} طالب', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text(
                      'وصلت $done من ${receipts.length} مادة',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: done == receipts.length && receipts.isNotEmpty ? AppTheme.success : const Color(0xFF8A5A00),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// خطوات العمل بالترتيب الفعلي (التسلسل هنا حقيقي، لذلك الأرقام).
  Widget _steps(Section? section) {
    final items = <(IconData, String, String, Widget)>[
      (Icons.class_outlined, 'الصفوف والشعب والمواد', 'الشعب، مواد كل صف، بيانات المدرسة', AdminSetupPage(store: store)),
      (Icons.groups_rounded, 'الطلاب', 'إضافة طلاب كل شعبة (كتابة، Word، صورة)',
          StudentsPage(store: store, initialSectionId: section?.id)),
      (Icons.badge_outlined, 'بيانات السجل', 'رقم القيد، المواليد، سنوات الرسوب', AdminStudentInfoPage(store: store)),
      (Icons.outbox_rounded, 'إرسال ملفات الشعب للمدرسين', 'قائمة طلاب موحّدة لكل مدرس', AdminExchangePage(store: store)),
      (Icons.move_to_inbox_rounded, 'استلام درجات المدرسين', 'ملف درجات من كل مدرس لكل مادة',
          AdminExchangePage(store: store, receive: true)),
      (Icons.fact_check_outlined, 'النتائج والسجل الوسطي', 'المواد الناقصة، النتيجة العامة، الطباعة', AdminResultsPage(store: store)),
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
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.softPurple,
              child: Text('${i + 1}', style: const TextStyle(color: _ink, fontWeight: FontWeight.w900)),
            ),
            title: Text(items[i].$2, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(items[i].$3, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
            trailing: Icon(items[i].$1, color: _ink),
            onTap: () => open(items[i].$4),
          ),
          if (i < items.length - 1) const Divider(height: 1, indent: 60),
        ],
      ]),
    );
  }
}
