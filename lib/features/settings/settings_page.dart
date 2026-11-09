import 'package:flutter/material.dart';
import '../../core/storage/app_store.dart';
import '../../core/utils/arabic_numbers.dart';
import 'backup_actions.dart';
import '../../core/app.dart';
import '../../core/app_mode.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.store});
  final AppStore store;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<void> _editDailyWeights() async {
    final store = widget.store;
    final controllers = <String, TextEditingController>{
      'monthlyExamsWeight': TextEditingController(
        text: store.weight('monthlyExamsWeight', 70).toString(),
      ),
      'dailyExamsWeight': TextEditingController(
        text: store.weight('dailyExamsWeight', 20).toString(),
      ),
      'ratingWeight': TextEditingController(
        text: store.weight('ratingWeight', 10).toString(),
      ),
    };
    const labelKeys = {'monthlyExamsWeight': 'monthly', 'dailyExamsWeight': 'daily', 'ratingWeight': 'rating'};
    final labels = {
      for (final e in labelKeys.entries) e.key: TextEditingController(text: store.componentLabel(e.value)),
    };

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        String? error;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            int value(String key) =>
                ArabicNumbers.parseInt(controllers[key]!.text) ?? -1;

            final total = controllers.values
                .map((controller) => ArabicNumbers.parseInt(controller.text) ?? 0)
                .fold<int>(0, (sum, item) => sum + item);

            return AlertDialog(
              title: const Text('توزيع درجات سعي الفصل'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'سعي الفصل من 100. سمِّ كل عنصر بما يناسب مادتك وحدد درجته، ويجب أن يكون المجموع 100. '
                      'الامتحانات تُحسب بالتناسب: درجة العنصر تتوزع على عدد امتحاناته، '
                      'والعنصر الثالث تقدير بالشريط المتحرك.',
                      style: TextStyle(height: 1.6),
                    ),
                    const SizedBox(height: 14),
                    for (final item in const [
                      ('monthlyExamsWeight', 'الامتحانات الشهرية', Icons.calendar_month_outlined),
                      ('dailyExamsWeight', 'الامتحانات اليومية', Icons.edit_note_rounded),
                      ('ratingWeight', 'التقدير (شريط)', Icons.tune_rounded),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(children: [
                          Icon(item.$3, size: 22, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: labels[item.$1],
                              decoration: InputDecoration(
                                labelText: 'اسم العنصر',
                                hintText: item.$2,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 96,
                            child: TextField(
                              controller: controllers[item.$1],
                              keyboardType: TextInputType.number,
                              inputFormatters: const [EnglishDigitsFormatter()],
                              decoration: const InputDecoration(
                                labelText: 'الدرجة',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                        ]),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'المجموع: $total / 100',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: total == 100 ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () async {
                    final values = {
                      for (final key in controllers.keys) key: value(key),
                    };
                    final valid = values.values.every((v) => v >= 0 && v <= 100);
                    if (!valid || total != 100) {
                      setDialogState(() {
                        error = 'أدخل قيماً بين 0 و100، ويجب أن يكون مجموعها 100.';
                      });
                      return;
                    }
                    store.settings.addAll(values);
                    for (final e in labelKeys.entries) {
                      final t = labels[e.key]!.text.trim();
                      if (t.isEmpty || t == AppStore.componentDefaults[e.value]) {
                        store.settings.remove('label_${e.value}');
                      } else {
                        store.settings['label_${e.value}'] = t;
                      }
                    }
                    await store.saveAll();
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, true);
                    }
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );

    for (final controller in [...controllers.values, ...labels.values]) {
      controller.dispose();
    }
    if (result == true && mounted) setState(() {});
  }

  Future<void> _editGeminiKey() async {
    final store = widget.store;
    final controller = TextEditingController(
      text: (store.settings['geminiApiKey'] ?? '').toString(),
    );
    var obscure = true;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('القراءة الذكية للصور'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'القراءة المحلية مجانية وتعمل على الجهاز، وممتازة للأوراق المطبوعة. '
                  'القراءة الذكية (Gemini من Google) أدق بكثير مع خط اليد والجداول والصور المائلة.',
                  style: TextStyle(height: 1.5),
                ),
                const SizedBox(height: 8),
                const Text(
                  'تنبيه: عند تفعيلها تُرسل صورة ورقة الأسماء إلى Google لقراءتها. '
                  'احصل على مفتاح مجاني من Google AI Studio والصقه هنا. اتركه فارغاً لإيقافها.',
                  style: TextStyle(height: 1.5, fontSize: 12.5, color: Color(0xFF9A6A00)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  obscureText: obscure,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'مفتاح Gemini API',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, ''),
              child: const Text('إيقاف'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    if (result == null) return;
    if (result.isEmpty) {
      store.settings.remove('geminiApiKey');
    } else {
      store.settings['geminiApiKey'] = result;
    }
    await store.saveAll();
    if (mounted) setState(() {});
  }

  /// نوع النسخة: المدرس أو الإدارة (لكل منهما بياناتها المنفصلة).
  Widget _editionTile(AppStore store) {
    final current = store.isAdmin ? 'نسخة الإدارة' : 'نسخة المدرس';
    final other = store.isAdmin ? 'نسخة المدرس' : 'نسخة الإدارة';
    return ListTile(
      leading: Icon(store.isAdmin ? Icons.account_balance_rounded : Icons.menu_book_rounded),
      title: Text('نوع النسخة: $current', style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('التبديل إلى $other. لكل نسخة بياناتها المنفصلة، ولا يُحذف شيء عند التبديل.'),
      trailing: const Icon(Icons.swap_horiz_rounded),
      onTap: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text('التبديل إلى $other؟'),
              content: Text(
                'ستفتح $other ببياناتها الخاصة. بيانات $current تبقى محفوظة كما هي، '
                'وتعود إليها متى شئت من هنا.',
                style: const TextStyle(height: 1.6),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
                FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('تبديل')),
              ],
            ),
          ),
        );
        if (ok != true || !mounted) return;
        await MoeenApp.switchMode(context, store.isAdmin ? AppMode.teacher : AppMode.admin);
      },
    );
  }

  Widget _backupSection(AppStore store) {
    final size = store.dataSizeBytes;
    // localStorage يسمح بحوالي 5 ميغابايت؛ IndexedDB أكبر بكثير.
    final limited = store.storageBackend.contains('localStorage');
    final nearLimit = limited && size > 3.5 * 1024 * 1024;
    final persisted = store.storagePersisted;
    final last = store.lastBackupAt;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text('النسخ الاحتياطي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(
          'بياناتك محفوظة داخل هذا المتصفح فقط. إذا مُسحت بيانات المتصفح أو تغيّر الجهاز تضيع، '
          'لذلك احفظ نسخة احتياطية بانتظام وانقلها إلى مكان آمن.',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, height: 1.6),
        ),
      ),
      ListTile(
        leading: const Icon(Icons.download_rounded),
        title: const Text('حفظ نسخة احتياطية'),
        subtitle: Text(last == null
            ? 'لم تُعمل نسخة بعد'
            : 'آخر نسخة: ${BackupActions.ago(last)} (${BackupActions.formatDate(last)})'),
        trailing: const Icon(Icons.chevron_left),
        onTap: () async {
          await BackupActions.export(context, store);
          if (mounted) setState(() {});
        },
      ),
      ListTile(
        leading: const Icon(Icons.upload_file_rounded),
        title: const Text('استعادة من نسخة احتياطية'),
        subtitle: const Text('اختر ملف النسخة (json). تُحفظ نسخة من بياناتك الحالية قبل الاستعادة.'),
        trailing: const Icon(Icons.chevron_left),
        onTap: () async {
          final restored = await BackupActions.restore(context, store);
          if (restored && mounted) setState(() {});
        },
      ),
      ListTile(
        leading: Icon(Icons.storage_rounded, color: nearLimit ? Colors.red : null),
        title: Text('حجم البيانات: ${BackupActions.formatSize(size)}'),
        subtitle: Text(nearLimit
            ? 'اقتربت البيانات من الحد الذي يسمح به المتصفح (حوالي 5 ميغابايت). احفظ نسخة احتياطية الآن.'
            : 'مكان الحفظ: ${store.storageBackend}${limited ? '، يسمح بحوالي 5 ميغابايت' : '، سعته كبيرة'}.'),
      ),
      if (persisted != null)
        ListTile(
          leading: Icon(persisted ? Icons.verified_user_outlined : Icons.info_outline_rounded,
              color: persisted ? const Color(0xFF2E8B57) : const Color(0xFF8A5A00)),
          title: Text(persisted ? 'البيانات محمية من المسح التلقائي' : 'البيانات غير محمية من المسح التلقائي'),
          subtitle: Text(persisted
              ? 'لن يمسحها المتصفح وحده عند امتلاء القرص. مسحها يدوياً من إعدادات المتصفح ما زال ممكناً، فاستمر بالنسخ الاحتياطي.'
              : 'قد يمسحها المتصفح إذا امتلأ القرص. ثبّت مُعين على الشاشة الرئيسية أو سطح المكتب لتحسين الحماية، واستمر بالنسخ الاحتياطي.'),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الإعدادات')),
        body: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _editionTile(store),
            const Divider(),
            if (!store.isAdmin) ...[
            ListTile(
              leading: const Icon(Icons.tune_rounded),
              title: const Text(
                'توزيع درجات سعي الفصل',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${store.componentLabel('monthly')} ${store.weight('monthlyExamsWeight', 70)} + '
                '${store.componentLabel('daily')} ${store.weight('dailyExamsWeight', 20)} + '
                '${store.componentLabel('rating')} ${store.weight('ratingWeight', 10)} '
                '= ${store.weight('monthlyExamsWeight', 70) + store.weight('dailyExamsWeight', 20) + store.weight('ratingWeight', 10)}',
              ),
              trailing: const Icon(Icons.chevron_left),
              onTap: _editDailyWeights,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text(
                'القراءة الذكية للصور (اختياري)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                (store.settings['geminiApiKey'] ?? '').toString().trim().isEmpty
                    ? 'غير مفعّلة — تُستخدم القراءة المحلية المجانية.'
                    : 'مفعّلة (Gemini) — أدق مع خط اليد والصور المائلة.',
              ),
              trailing: const Icon(Icons.chevron_left),
              onTap: _editGeminiKey,
            ),
            const Divider(),
            ],
            _backupSection(store),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('مسح بيانات الاختبار'),
              textColor: Theme.of(context).colorScheme.error,
              onTap: () async {
                final navigator = Navigator.of(context);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('مسح البيانات؟'),
                    content: Text(store.isAdmin
                        ? 'سيحذف هذا كل بيانات «نسخة الإدارة» على هذا الجهاز. بيانات نسخة المدرس لا تتأثر.'
                        : 'سيحذف هذا كل بيانات «نسخة المدرس» على هذا الجهاز. بيانات نسخة الإدارة لا تتأثر.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('مسح'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await store.clearAllData();
                  if (!mounted) return;
                  navigator.pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
