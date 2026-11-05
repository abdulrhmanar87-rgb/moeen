import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';

import '../../core/app_theme.dart';
import '../../core/storage/app_store.dart';
import '../../core/utils/arabic_name_utils.dart';
import '../../core/utils/arabic_numbers.dart';
import '../../models/student.dart';
import '../../models/student_import.dart';
import '../../services/smart_student_ocr_service.dart';
import '../../services/student_ocr_service.dart';
import '../../services/student_file_import_service.dart';

enum _Source { text, word, image }

/// إضافة الطلاب بخطوتين واضحتين:
/// 1) اختيار المصدر: كتابة/لصق، ملف Word، أو صورة.
/// 2) مراجعة الأسماء ثم إضافتها.
class StudentImportPage extends StatefulWidget {
  const StudentImportPage({super.key, required this.store, required this.sectionId});
  final AppStore store;
  final String sectionId;

  @override
  State<StudentImportPage> createState() => _StudentImportPageState();
}

class _StudentImportPageState extends State<StudentImportPage> {
  final _textController = TextEditingController();
  final _picker = ImagePicker();
  final StudentOcrService _ocr = ArabicTesseractOcrService();
  final StudentFileImportService _fileImport = StudentFileImportService();
  final List<StudentImportItem> _items = [];

  _Source _source = _Source.text;
  bool _reviewing = false;
  bool _onlyAttention = false;
  bool _busy = false;
  String _busyText = '';
  String? _notice;

  Uint8List? _imageBytes;
  String? _imagePath;
  String _imageMime = 'image/jpeg';
  int _quarterTurns = 0;
  bool _rotatedSinceRead = false;
  bool _showImage = true;

  Set<String> _existingKeys = {};
  Set<String> _existingIds = {};

  static const _amber = Color(0xFF8A5A00);
  static const _amberBg = Color(0xFFFFF4D7);
  static const _red = Color(0xFFB3261E);

  AppStore get store => widget.store;

  String get _geminiKey => (store.settings['geminiApiKey'] ?? '').toString().trim();

  String get _sectionLabel {
    for (final s in store.sections) {
      if (s.id == widget.sectionId) {
        return '${s.gradeName} — شعبة ${s.name}';
      }
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _textController.addListener(() => setState(() {}));
    _loadExisting();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _loadExisting() {
    final existing = store.studentsOf(widget.sectionId);
    _existingKeys = existing.map((s) => ArabicNameUtils.key(s.name)).toSet();
    _existingIds = existing.map((s) => s.nationalId.trim()).where((e) => e.isNotEmpty).toSet();
  }

  bool _isExisting(StudentImportItem item) =>
      _existingKeys.contains(ArabicNameUtils.key(item.name)) ||
      (item.nationalId.isNotEmpty && _existingIds.contains(item.nationalId.trim()));

  bool _needsAttention(StudentImportItem item) => item.needsReview || _isExisting(item);

  List<String> get _textLines => _textController.text
      .split(RegExp(r'[\r\n]+'))
      .map((e) => e.trim())
      .where((e) => ArabicNameUtils.cleanName(e).isNotEmpty)
      .toList();

  TextStyle get _hint => TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.5);

  // ===========================================================================
  // الهيكل العام
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: !_reviewing,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !_busy) setState(() => _reviewing = false);
        },
        child: Scaffold(
          appBar: AppBar(
            title: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_reviewing ? 'مراجعة الأسماء' : 'إضافة طلاب', style: const TextStyle(fontWeight: FontWeight.w800)),
              if (_sectionLabel.isNotEmpty)
                Text(_sectionLabel, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
            ]),
            actions: [
              if (_reviewing && _items.isNotEmpty)
                PopupMenuButton<String>(
                  tooltip: 'خيارات',
                  onSelected: _menuAction,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'all', child: Text('تحديد الكل')),
                    PopupMenuItem(value: 'none', child: Text('إلغاء تحديد الكل')),
                    PopupMenuItem(value: 'review', child: Text('استبعاد ما يحتاج مراجعة')),
                  ],
                ),
            ],
          ),
          bottomNavigationBar: _reviewing ? _bottomBar() : null,
          body: Stack(children: [
            _reviewing ? _reviewView() : _inputView(),
            if (_busy) _busyOverlay(),
          ]),
        ),
      ),
    );
  }

  Widget _busyOverlay() => Positioned.fill(
        child: ColoredBox(
          color: Colors.black26,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_busyText, textAlign: TextAlign.center, style: const TextStyle(height: 1.5)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );

  // ===========================================================================
  // الخطوة 1: اختيار المصدر
  // ===========================================================================

  Widget _inputView() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            SegmentedButton<_Source>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _Source.text, icon: Icon(Icons.keyboard_alt_outlined), label: Text('كتابة / لصق')),
                ButtonSegment(value: _Source.word, icon: Icon(Icons.description_outlined), label: Text('ملف Word')),
                ButtonSegment(value: _Source.image, icon: Icon(Icons.photo_camera_outlined), label: Text('صورة')),
              ],
              selected: {_source},
              onSelectionChanged: (s) => setState(() => _source = s.first),
            ),
            const SizedBox(height: 16),
            switch (_source) {
              _Source.text => _textInput(),
              _Source.word => _wordInput(),
              _Source.image => _imageInput(),
            },
          ],
        ),
      ),
    );
  }

  Widget _textInput() {
    final count = _textLines.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('اكتب اسم الطالب، أو الصق قائمة كاملة — اسم في كل سطر.',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('يمكن كتابة الرقم الوطني بعد الاسم. أرقام التسلسل والرموز تُحذف تلقائياً.', style: _hint),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            autofocus: true,
            minLines: 8,
            maxLines: 14,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(hintText: 'أحمد محمد علي\nزينب حسين كاظم\nمصطفى عبد الله جاسم'),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Text(
                count == 0 ? 'لم تُكتب أسماء بعد' : (count == 1 ? 'اسم واحد' : '$count أسماء'),
                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
              ),
            ),
            FilledButton.icon(
              onPressed: count == 0 || _busy ? null : _prepareText,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('متابعة'),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _wordInput() => _sourceCard(
        icon: Icons.description_rounded,
        title: 'استيراد من ملف Word',
        body: 'جدول أو قائمة أسماء بصيغة DOCX. يتعرّف مُعين على عمود الاسم والرقم الوطني، '
            'ويدمج الاسم المجزأ على أعمدة، ويتجاهل العناوين واسم المدرسة.',
        actions: [
          FilledButton.icon(
            onPressed: _busy ? null : _pickWord,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('اختيار ملف Word'),
          ),
        ],
      );

  Widget _imageInput() => _sourceCard(
        icon: Icons.document_scanner_rounded,
        title: 'قراءة الأسماء من صورة',
        body: 'صوّر ورقة الأسماء من الأعلى، مستقيمة وبإضاءة جيدة، صفحة واحدة في كل صورة. '
            'ستراجع النتيجة قبل الإضافة.',
        actions: [
          FilledButton.icon(
            onPressed: _busy ? null : () => _pick(ImageSource.camera),
            icon: const Icon(Icons.photo_camera_rounded),
            label: const Text('التقاط صورة'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _pick(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('اختيار من الجهاز'),
          ),
        ],
        footer: _geminiKey.isEmpty
            ? 'الأسماء مكتوبة بخط اليد؟ فعّل «القراءة الذكية» من الإعدادات لنتيجة أدق.'
            : 'القراءة الذكية مفعّلة.',
      );

  Widget _sourceCard({
    required IconData icon,
    required String title,
    required String body,
    required List<Widget> actions,
    String? footer,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        child: Column(children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: AppTheme.softPurple, shape: BoxShape.circle),
            child: Icon(icon, color: AppTheme.primaryDark, size: 30),
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: _hint.copyWith(fontSize: 13.5)),
          const SizedBox(height: 20),
          Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: actions),
          if (footer != null) ...[
            const SizedBox(height: 16),
            Text(footer, textAlign: TextAlign.center, style: _hint),
          ],
        ]),
      ),
    );
  }

  // ===========================================================================
  // الخطوة 2: المراجعة
  // ===========================================================================

  Widget _reviewView() {
    final visible = _items.where((e) => !_onlyAttention || _needsAttention(e)).toList();

    final list = ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _summaryBar(),
        if (_notice != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_notice!, style: _hint),
          ),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Text(
              _items.isEmpty ? 'لا توجد أسماء.' : 'لا توجد أسماء تحتاج انتباهاً 👍',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          )
        else
          Card(
            child: Column(children: [
              for (var i = 0; i < visible.length; i++) ...[
                _row(visible[i]),
                if (i < visible.length - 1) const Divider(height: 1, indent: 12, endIndent: 12),
              ],
            ]),
          ),
        const SizedBox(height: 6),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: _addBlank,
            icon: const Icon(Icons.add_rounded),
            label: const Text('إضافة اسم يدوياً'),
          ),
        ),
      ],
    );

    final hasImage = _source == _Source.image && _imageBytes != null;
    if (!hasImage) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: list),
      );
    }

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 1000) {
        // شاشة عريضة: القائمة يميناً والصورة يساراً للمقارنة.
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: list),
          SizedBox(
            width: c.maxWidth * 0.4,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(0, 4, 16, 24),
              child: _imagePanel(wide: true),
            ),
          ),
        ]);
      }
      return Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: _imagePanel(wide: false)),
        Expanded(child: list),
      ]);
    });
  }

  Widget _summaryBar() {
    final review = _items.where((e) => e.needsReview && !_isExisting(e)).length;
    final existing = _items.where(_isExisting).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _pill(Icons.people_alt_rounded, '${_items.length} اسم', AppTheme.softPurple, AppTheme.primaryDark),
          if (review > 0) _pill(Icons.warning_amber_rounded, '$review تحتاج مراجعة', _amberBg, _amber),
          if (existing > 0) _pill(Icons.content_copy_rounded, '$existing موجود مسبقاً', const Color(0xFFFFE9E9), _red),
          if (review > 0 || existing > 0)
            FilterChip(
              label: const Text('عرضها فقط'),
              selected: _onlyAttention,
              onSelected: (v) => setState(() => _onlyAttention = v),
            ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _row(StudentImportItem item) {
    final number = _items.indexOf(item) + 1;
    final existing = _isExisting(item);
    final reason = existing ? 'موجود مسبقاً في الشعبة — لن يُضاف مرة أخرى' : item.reviewReason;
    final reasonColor = existing ? _red : _amber;

    return Padding(
      key: ObjectKey(item),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Checkbox(
            value: item.selected && !existing,
            onChanged: existing ? null : (v) => setState(() => item.selected = v ?? false),
          ),
        ),
        SizedBox(
          width: 26,
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text('$number', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(
              initialValue: item.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
              onChanged: (v) => setState(() {
                item.name = v;
                item.edited = true;
              }),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'اسم الطالب',
                suffixIcon: reason == null
                    ? const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 20)
                    : Icon(Icons.error_outline_rounded, color: reasonColor, size: 20),
              ),
            ),
            if (item.nationalId.isNotEmpty) ...[
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: SizedBox(
                  width: 230,
                  child: TextFormField(
                    initialValue: item.nationalId,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [EnglishDigitsFormatter()],
                    style: const TextStyle(fontSize: 13),
                    onChanged: (v) => setState(() => item.nationalId = ArabicNumbers.toEnglish(v).trim()),
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'الرقم الوطني',
                      prefixIcon: Icon(Icons.badge_outlined, size: 18),
                    ),
                  ),
                ),
              ),
            ],
            if (reason != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 4, start: 4),
                child: Text(reason, style: TextStyle(fontSize: 12, color: reasonColor)),
              ),
          ]),
        ),
        IconButton(
          tooltip: 'حذف',
          onPressed: () => setState(() => _items.remove(item)),
          icon: Icon(Icons.close_rounded, color: Colors.grey.shade500),
        ),
      ]),
    );
  }

  Widget _imagePanel({required bool wide}) {
    final bytes = _imageBytes!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.image_outlined, size: 20, color: AppTheme.primaryDark),
            const SizedBox(width: 6),
            const Expanded(child: Text('الصورة', style: TextStyle(fontWeight: FontWeight.w800))),
            IconButton(
              tooltip: 'تدوير',
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _quarterTurns = (_quarterTurns + 1) % 4;
                        _rotatedSinceRead = true;
                        _showImage = true;
                      }),
              icon: const Icon(Icons.rotate_right_rounded),
            ),
            IconButton(
              tooltip: 'صورة أخرى',
              onPressed: _busy ? null : () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.swap_horiz_rounded),
            ),
            if (!wide)
              IconButton(
                tooltip: _showImage ? 'إخفاء' : 'إظهار',
                onPressed: () => setState(() => _showImage = !_showImage),
                icon: Icon(_showImage ? Icons.expand_less_rounded : Icons.expand_more_rounded),
              ),
          ]),
          if (wide || _showImage) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: wide ? 520 : 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ColoredBox(
                  color: const Color(0xFFF2F0F7),
                  child: InteractiveViewer(
                    maxScale: 5,
                    child: Center(
                      child: RotatedBox(
                        quarterTurns: _quarterTurns,
                        child: Image.memory(bytes, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (_rotatedSinceRead) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _busy ? null : _readImage,
              icon: const Icon(Icons.document_scanner_rounded),
              label: const Text('إعادة القراءة بالاتجاه الجديد'),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _bottomBar() {
    final toAdd = _items.where((e) => e.selected && !_isExisting(e) && e.name.trim().isNotEmpty).length;
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : () => setState(() => _reviewing = false),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('رجوع'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: _busy || toAdd == 0 ? null : _importSelected,
              icon: const Icon(Icons.check_rounded),
              label: Text(toAdd == 0
                  ? 'لا توجد أسماء محددة'
                  : (toAdd == 1 ? 'إضافة طالب واحد' : 'إضافة $toAdd طلاب')),
            ),
          ),
        ]),
      ),
    );
  }

  // ===========================================================================
  // المنطق
  // ===========================================================================

  void _menuAction(String action) {
    setState(() {
      for (final e in _items) {
        switch (action) {
          case 'all':
            e.selected = true;
          case 'none':
            e.selected = false;
          case 'review':
            if (e.needsReview) e.selected = false;
        }
      }
    });
  }

  void _addBlank() {
    setState(() {
      _onlyAttention = false;
      _items.add(StudentImportItem(name: '', source: 'يدوي')..edited = true);
    });
  }

  /// الانتقال إلى المراجعة. الأسماء الموجودة مسبقاً في الشعبة تُلغى تلقائياً.
  void _enterReview(List<StudentImportItem> items, {String? notice}) {
    _loadExisting();
    for (final item in items) {
      if (_isExisting(item)) item.selected = false;
    }
    setState(() {
      _items
        ..clear()
        ..addAll(items);
      _reviewing = true;
      _onlyAttention = false;
      _notice = notice;
    });
  }

  void _prepareText() {
    final items = <StudentImportItem>[];
    final seen = <String>{};
    for (final line in _textLines) {
      final name = ArabicNameUtils.cleanName(line);
      if (name.isEmpty || ArabicNameUtils.isHeader(name)) continue;
      if (!seen.add(ArabicNameUtils.key(name))) continue;
      items.add(StudentImportItem(
        name: name,
        nationalId: ArabicNameUtils.extractNationalId(line),
        source: 'كتابة',
      ));
    }
    if (items.isEmpty) {
      _snack('لم نجد أسماء لإضافتها.');
      return;
    }
    _enterReview(items);
  }

  Future<void> _pickWord() async {
    try {
      const typeGroup = XTypeGroup(label: 'Word', extensions: <String>['docx']);
      final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
      if (file == null) return;
      final fileName = file.name;
      if (!fileName.toLowerCase().endsWith('.docx')) {
        _snack('اختر ملف Word بصيغة DOCX. إذا كان الملف بصيغة DOC القديمة افتحه في Word واحفظه باسم DOCX.');
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _busy = true;
        _busyText = 'جارٍ قراءة $fileName...';
      });
      final result = await _fileImport.fromWord(bytes);
      if (!mounted) return;
      setState(() => _busy = false);
      if (result.items.isEmpty) {
        _snack(result.warnings.isEmpty ? 'لم نجد أسماء في الملف.' : result.warnings.join('\n'));
        return;
      }
      _enterReview(
        result.items,
        notice: result.skippedLines > 0
            ? 'من الملف $fileName — تم تجاهل ${result.skippedLines} سطراً ليس اسماً (عناوين، اسم المدرسة...).'
            : 'من الملف $fileName',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('تعذر قراءة ملف Word. تأكد أنه ملف DOCX وليس صورة داخل Word.');
    }
  }

  Future<void> _pick(ImageSource source) async {
    final XFile? file;
    try {
      file = await _picker.pickImage(source: source, imageQuality: 95, maxWidth: 3000);
    } catch (_) {
      _snack('تعذر فتح ${source == ImageSource.camera ? 'الكاميرا' : 'الصور'}.');
      return;
    }
    if (file == null) return;
    final XFile picked = file;
    final lower = picked.name.toLowerCase();
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
      _snack('صيغة HEIC غير مدعومة في المتصفح. حوّل الصورة إلى JPG أو التقطها بالكاميرا.');
      return;
    }
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _imagePath = picked.path;
      _imageMime = picked.mimeType ??
          (lower.endsWith('.png') ? 'image/png' : (lower.endsWith('.webp') ? 'image/webp' : 'image/jpeg'));
      _quarterTurns = 0;
      _showImage = true;
    });
    await _readImage();
  }

  Future<void> _readImage() async {
    final bytes = _imageBytes;
    if (bytes == null) return;
    setState(() {
      _busy = true;
      _busyText = _geminiKey.isEmpty
          ? 'مُعين يحسّن الصورة ويقرأ الأسماء...\nأول قراءة أبطأ قليلاً.'
          : 'القراءة الذكية جارية...';
    });

    List<StudentImportItem> results;
    String? fallbackNote;
    try {
      if (_geminiKey.isNotEmpty) {
        try {
          results = await SmartStudentOcrService(apiKey: _geminiKey).recognize(
            bytes,
            path: _imagePath,
            quarterTurns: _quarterTurns,
            mimeType: _imageMime,
          );
        } catch (e) {
          fallbackNote = e.toString().contains('KEY_INVALID')
              ? 'مفتاح القراءة الذكية غير صالح؛ استُخدمت القراءة المحلية.'
              : 'تعذرت القراءة الذكية؛ استُخدمت القراءة المحلية.';
          if (mounted) setState(() => _busyText = 'مُعين يحسّن الصورة ويقرأ الأسماء...');
          results = await _ocr.recognize(bytes, path: _imagePath, quarterTurns: _quarterTurns, mimeType: _imageMime);
        }
      } else {
        results = await _ocr.recognize(bytes, path: _imagePath, quarterTurns: _quarterTurns, mimeType: _imageMime);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('تعذر قراءة الصورة. تأكد من الاتصال بالإنترنت عند أول استخدام، وأن الصورة JPG أو PNG.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _rotatedSinceRead = false;
    });
    if (results.isEmpty) {
      _snack('لم نتمكن من قراءة أسماء واضحة. جرّب تدوير الصورة ثم إعادة القراءة، أو صورة أقرب وأوضح.');
      if (!_reviewing) {
        // نعرض الصورة في شاشة المراجعة حتى يمكن تدويرها وإعادة قراءتها أو الإضافة يدوياً.
        _enterReview([], notice: 'دوّر الصورة وأعد القراءة، أو أضف الأسماء يدوياً.');
      }
      return;
    }
    _enterReview(results, notice: fallbackNote ?? 'قارن الأسماء مع الصورة قبل الإضافة.');
  }

  Future<void> _importSelected() async {
    final toAdd = <StudentImportItem>[];
    final keys = <String>{};
    final ids = <String>{};
    for (final item in _items) {
      if (!item.selected || _isExisting(item)) continue;
      final name = ArabicNameUtils.cleanName(item.name);
      if (name.isEmpty) continue;
      final id = ArabicNumbers.toEnglish(item.nationalId.trim());
      if (!keys.add(ArabicNameUtils.key(name))) continue;
      if (id.isNotEmpty && !ids.add(id)) continue;
      toAdd.add(item);
    }
    if (toAdd.isEmpty) {
      _snack('لا توجد أسماء جديدة لإضافتها.');
      return;
    }

    var yearId = store.years.isEmpty ? '' : store.years.first.id;
    for (final s in store.sections) {
      if (s.id == widget.sectionId) yearId = s.yearId;
    }

    setState(() {
      _busy = true;
      _busyText = 'جارٍ إضافة ${toAdd.length} طالب...';
    });
    for (final item in toAdd) {
      await store.addStudent(
        Student(
          id: store.id(),
          schoolId: store.school?.id ?? '',
          number: '0',
          name: ArabicNameUtils.cleanName(item.name),
          nationalId: ArabicNumbers.toEnglish(item.nationalId.trim()),
          createdAt: DateTime.now().toIso8601String(),
        ),
        widget.sectionId,
        yearId,
      );
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(toAdd.length == 1 ? 'تمت إضافة الطالب.' : 'تمت إضافة ${toAdd.length} طلاب وترتيبهم أبجدياً.');
    Navigator.pop(context, true);
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
