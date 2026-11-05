import 'package:flutter/material.dart';
import '../../core/app_mode.dart';
import '../../core/app_theme.dart';

/// أول تشغيل: اختيار نوع النسخة.
class ModeChoicePage extends StatelessWidget {
  const ModeChoicePage({super.key, required this.onChoose});
  final Future<void> Function(String mode) onChoose;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(22),
                children: [
                  const Text('مُعين',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppTheme.primaryDark)),
                  const SizedBox(height: 6),
                  Text('من سيستخدم التطبيق على هذا الجهاز؟',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                  const SizedBox(height: 24),
                  _choice(
                    icon: Icons.menu_book_rounded,
                    title: 'نسخة المدرس',
                    body: 'طلاب شعبك، الحضور، الامتحانات والتقدير، سعي الفصل، وسجل المدرس لمادتك.',
                    onTap: () => onChoose(AppMode.teacher),
                  ),
                  const SizedBox(height: 12),
                  _choice(
                    icon: Icons.account_balance_rounded,
                    title: 'نسخة الإدارة',
                    body: 'للمدير أو المعاون: إعداد الشعب ومواد كل صف، إرسال قوائم الطلاب للمدرسين، '
                        'استلام درجات كل المواد، والنتائج والسجل الوسطي.',
                    onTap: () => onChoose(AppMode.admin),
                  ),
                  const SizedBox(height: 18),
                  Text('يمكنك التغيير لاحقاً من الإعدادات، ولكل نسخة بياناتها المنفصلة.',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _choice({
    required IconData icon,
    required String title,
    required String body,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE0DAF3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(color: AppTheme.softPurple, shape: BoxShape.circle),
              child: Icon(icon, color: AppTheme.primaryDark, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.primaryDark)),
                const SizedBox(height: 4),
                Text(body, style: TextStyle(color: Colors.grey.shade700, height: 1.5)),
              ]),
            ),
            const Icon(Icons.chevron_left_rounded, color: Color(0xFFA9A2BF)),
          ]),
        ),
      ),
    );
  }
}
