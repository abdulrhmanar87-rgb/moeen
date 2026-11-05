import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../core/backup/file_saver.dart';
import '../../core/storage/app_store.dart';

/// عمليات النسخ الاحتياطي المشتركة بين الإعدادات والواجهة الرئيسية.
class BackupActions {
  BackupActions._();

  /// عدد الأيام بعد آخر نسخة قبل أن يظهر التذكير.
  static const reminderDays = 7;

  static String _stamp(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}_${two(d.hour)}-${two(d.minute)}';
  }

  static String formatDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  /// «اليوم»، «أمس»، «قبل 5 أيام»...
  static String ago(DateTime? d) {
    if (d == null) return 'لم تُعمل نسخة بعد';
    final days = DateTime.now().difference(d).inDays;
    if (days <= 0) return 'اليوم';
    if (days == 1) return 'أمس';
    if (days == 2) return 'قبل يومين';
    if (days <= 10) return 'قبل $days أيام';
    return 'قبل $days يوماً';
  }

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes بايت';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} كيلوبايت';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} ميغابايت';
  }

  /// هل يحتاج المستخدم تذكيراً؟ (توجد بيانات، ولم تُعمل نسخة منذ أسبوع)
  static bool needsReminder(AppStore store) {
    if (store.students.isEmpty) return false;
    final last = store.lastBackupAt;
    return last == null || DateTime.now().difference(last).inDays >= reminderDays;
  }

  static void _snack(BuildContext context, String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  /// تصدير كل البيانات إلى ملف على الجهاز.
  static Future<void> export(BuildContext context, AppStore store) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final json = const JsonEncoder.withIndent(' ').convert(store.exportData());
      final saved = await saveTextFile('moeen-backup_${_stamp(DateTime.now())}.json', json);
      if (!saved) return;
      await store.markBackedUp();
      messenger.showSnackBar(const SnackBar(
        content: Text('تم حفظ النسخة الاحتياطية. احتفظ بها في مكان آمن خارج هذا الجهاز (iCloud، Google Drive، واتساب، فلاش).'),
        duration: Duration(seconds: 6),
      ));
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('تعذر حفظ النسخة الاحتياطية. حاول مرة أخرى.')));
    }
  }

  /// استعادة البيانات من ملف نسخة. يعيد true إذا تمت الاستعادة.
  static Future<bool> restore(BuildContext context, AppStore store) async {
    final XFile? file;
    try {
      file = await openFile(acceptedTypeGroups: const [
        XTypeGroup(label: 'نسخة مُعين', extensions: ['json']),
      ]);
    } catch (_) {
      if (context.mounted) _snack(context, 'تعذر فتح نافذة اختيار الملف.');
      return false;
    }
    if (file == null) return false;

    final Object? decoded;
    final BackupSummary summary;
    try {
      decoded = jsonDecode(await file.readAsString());
      summary = AppStore.inspectBackup(decoded);
    } on FormatException catch (e) {
      if (context.mounted) {
        _snack(context, e.message.contains('مُعين') ? e.message : 'الملف ليس نسخة احتياطية صالحة من مُعين.');
      }
      return false;
    } catch (_) {
      if (context.mounted) _snack(context, 'تعذر قراءة الملف.');
      return false;
    }
    if (!context.mounted) return false;

    final hasData = store.students.isNotEmpty || store.sections.isNotEmpty;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('استعادة النسخة الاحتياطية؟'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _summaryLine('تاريخ النسخة', summary.exportedAt == null ? 'غير معروف' : formatDate(summary.exportedAt!)),
            if (summary.schoolName.isNotEmpty) _summaryLine('المدرسة', summary.schoolName),
            _summaryLine('الشعب', '${summary.sections}'),
            _summaryLine('الطلاب', '${summary.students}'),
            _summaryLine('الدرجات المدخلة', '${summary.scores}'),
            const SizedBox(height: 12),
            Text(
              hasData
                  ? 'ستحل هذه النسخة محل كل بياناتك الحالية (${store.students.length} طالب في ${store.sections.length} شعبة). '
                      'قبل الاستعادة يحفظ مُعين نسخة من بياناتك الحالية تلقائياً في التنزيلات.'
                  : 'ستُحمَّل هذه البيانات إلى التطبيق.',
              style: const TextStyle(height: 1.6),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('استعادة')),
          ],
        ),
      ),
    );
    if (ok != true) return false;

    try {
      if (hasData) {
        // شبكة أمان: نسخة من البيانات الحالية قبل استبدالها.
        final current = const JsonEncoder.withIndent(' ').convert(store.exportData());
        await saveTextFile('moeen-before-restore_${_stamp(DateTime.now())}.json', current);
      }
      await store.importData(decoded);
    } on FormatException catch (e) {
      if (context.mounted) _snack(context, 'لم تتم الاستعادة: ${e.message} بياناتك الحالية لم تتغير.');
      return false;
    } catch (_) {
      if (context.mounted) _snack(context, 'لم تتم الاستعادة بسبب خطأ في الملف. بياناتك الحالية لم تتغير.');
      return false;
    }
    if (context.mounted) {
      _snack(context, 'تمت الاستعادة: ${store.students.length} طالب في ${store.sections.length} شعبة.');
    }
    return true;
  }

  static Widget _summaryLine(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold))),
        ]),
      );
}
