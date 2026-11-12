import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/constants/semesters.dart';
import '../../core/print/print_bridge.dart';
import '../../core/storage/app_store.dart';
import '../../core/utils/arabic_numbers.dart';
import '../../models/academic.dart';
import '../../services/calculation_service.dart';
import 'teacher_record_print.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.store});
  final AppStore store;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String n(num? value) {
    if (value == null) return '';
    return ArabicNumbers.toArabic(value);
  }


  String? sectionId;
  int semester = Semesters.current();

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    sectionId ??= store.currentSectionId;
    final students = sectionId == null ? const [] : store.studentsOf(sectionId!);
    Section? section;
    for (final s in store.sections) {
      if (s.id == sectionId) section = s;
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('سجل المدرس النهائي')),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (store.sections.length > 1) ...[
                  DropdownButtonFormField<String>(
                    initialValue: sectionId,
                    decoration: const InputDecoration(labelText: 'الشعبة', prefixIcon: Icon(Icons.class_outlined)),
                    items: [
                      for (final s in store.sections)
                        DropdownMenuItem(value: s.id, child: Text('${s.gradeName} - ${s.name}')),
                    ],
                    onChanged: (v) {
                      setState(() => sectionId = v);
                      store.setCurrentSection(v);
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        const Icon(Icons.menu_book_outlined, size: 30),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            section == null ? 'سجل المدرس' : 'سجل المدرس: ${section.gradeName} ${section.name}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        'معدل الفصلين ونصف السنة والسعي السنوي والنهائي والإكمال لكل طالب، '
                        'يتحدث تلقائياً خلال السنة ويُطبع على ورق A4 (${students.length} طالب).',
                        style: TextStyle(color: Colors.grey.shade700, height: 1.6),
                      ),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: section == null || students.isEmpty
                                ? null
                                : () => _printTeacherRecord(section!, students),
                            icon: const Icon(Icons.print_rounded),
                            label: const Text('طباعة / حفظ PDF'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: section == null || students.isEmpty ? null : _showTeacherRecord,
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('معاينة'),
                          ),
                        ),
                      ]),
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


  void _showTeacherRecord() {
    if (sectionId == null) return;

    final section = widget.store.sections.firstWhere(
      (s) => s.id == sectionId,
    );
    final students = widget.store.studentsOf(sectionId!);

    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد طلاب في الشعبة المختارة')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: SizedBox(
          width: 900,
          height: 760,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'معاينة سجل المدرس — A4',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _printTeacherRecord(section, students),
                      icon: const Icon(Icons.print_rounded),
                      label: const Text('طباعة / حفظ PDF'),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'إغلاق',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: InteractiveViewer(
                  minScale: 0.55,
                  maxScale: 2.0,
                  boundaryMargin: const EdgeInsets.all(80),
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var start = 0;
                              start < students.length;
                              start += 22)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: _teacherRecordA4(
                                section,
                                start,
                                students.sublist(
                                  start,
                                  (start + 22 > students.length)
                                      ? students.length
                                      : start + 22,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  'هذه معاينة فقط. للطباعة اضغط «طباعة / حفظ PDF» في الأعلى (وليس Ctrl + P): '
                  'يفتح السجل في تبويب جديد كصفحات A4 مضبوطة وتظهر نافذة الطباعة تلقائياً.',
                  style: TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// طباعة سجل المدرس كمستند A4 مستقل (وليس صورة الشاشة)، فيطابق الورقة بدقة.
  Future<void> _printTeacherRecord(dynamic section, List<dynamic> students) async {
    if (!canPrintHtml) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الطباعة متاحة حالياً في نسخة المتصفح.')),
      );
      return;
    }
    final calc = CalculationService(widget.store);
    final school = widget.store.school;
    final year = widget.store.years.where((y) => y.id == section.yearId).firstOrNull;
    final rows = <TeacherRecordRow>[
      for (final st in students)
        TeacherRecordRow(st.name as String, _recordValues(calc.year(st.id, section.id))),
    ];

    final html = buildTeacherRecordHtml(
      schoolName: school?.name ?? '',
      teacherName: (widget.store.settings['teacherName'] ?? '').toString().trim(),
      subject: section.subjectName as String,
      grade: section.gradeName as String,
      sectionName: section.name as String,
      academicYear: year?.name ?? '',
      columns: const [
        'معدل الفصل الأول',
        'امتحان نصف السنة',
        'معدل الفصل الثاني',
        'السعي السنوي',
        'درجة الامتحان النهائي',
        'الدرجة النهائية',
        'درجة الإكمال',
        'الدرجة بعد الإكمال',
        'الملاحظات',
      ],
      rows: rows,
      // خط التطبيق من نفس عنوان التطبيق (Flutter Web ينشر الأصول تحت assets/).
      fontUrl: Uri.base.resolve('assets/assets/fonts/KhalidArt-Bold.ttf').toString(),
    );
    final opened = await printHtml(html);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('منع المتصفح فتح صفحة الطباعة. اسمح بالنوافذ المنبثقة لهذا الموقع (أيقونة في شريط العنوان) ثم أعد المحاولة.'),
        duration: Duration(seconds: 8),
      ));
    }
  }

  /// [startIndex] موقع أول طالب في الصفحة، ليستمر التسلسل بين الصفحات.
  Widget _teacherRecordA4(dynamic section, int startIndex, List<dynamic> students) {
    final school = widget.store.school;
    final year = widget.store.years
        .where((y) => y.id == section.yearId)
        .firstOrNull;

    final calc = CalculationService(widget.store);

    // أعمدة السجل ثابتة، والقيم تملأ تدريجياً خلال السنة.
    const columns = <String>[
      'معدل الفصل الأول',
      'امتحان نصف السنة',
      'معدل الفصل الثاني',
      'السعي السنوي',
      'درجة الامتحان النهائي',
      'الدرجة النهائية',
      'درجة الإكمال',
      'الدرجة بعد الإكمال',
      'الملاحظات',
    ];

    final teacherName =
        (widget.store.settings['teacherName'] ?? '').toString().trim();

    return Container(
      width: 794,
      constraints: const BoxConstraints(minHeight: 1123),
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(30, 28, 30, 28),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.black,
          fontSize: 11,
          fontFamily: AppTheme.fontFamily,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _recordHeader(
              schoolName: school?.name ?? '',
              teacherName: teacherName,
              subject: section.subjectName,
              grade: section.gradeName,
              sectionName: section.name,
              academicYear: year?.name ?? '',
            ),
            const SizedBox(height: 8),
            _recordTable(section, startIndex, students, calc, columns),
            const SizedBox(height: 14),
            const Row(
              children: [
                Expanded(
                  child: Text(
                    'توقيع المدير: .................................',
                    textAlign: TextAlign.left,
                  ),
                ),
                SizedBox(width: 30),
                Expanded(
                  child: Text(
                    'توقيع المدرس: .................................',
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// شريط تعريفي مختصر بسطر واحد: العناصر بجانب بعضها أفقياً.
  Widget _recordHeader({
    required String schoolName,
    required String teacherName,
    required String subject,
    required String grade,
    required String sectionName,
    required String academicYear,
  }) {
    String value(String text) => text.isEmpty ? '..........' : ArabicNumbers.toArabic(text);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 14,
        runSpacing: 2,
        children: [
          _headerLine('المدرسة', value(schoolName)),
          _headerLine('المدرس', value(teacherName)),
          _headerLine('المادة', value(subject)),
          _headerLine('الصف', '${value(grade)} / ${value(sectionName)}'),
          _headerLine('العام', value(academicYear)),
        ],
      ),
    );
  }

  Widget _headerLine(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black, fontSize: 10.5),
        children: [
          TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: value),
        ],
      ),
    );
  }

  Widget _recordTable(
    dynamic section,
    int startIndex,
    List<dynamic> students,
    CalculationService calc,
    List<String> columns,
  ) {
    final border = TableBorder.all(color: Colors.black, width: 0.8);

    // ترتيب الأعمدة بصرياً من اليمين إلى اليسار، وفق السياق العربي:
    // ت ← اسم الطالب ← معدل الفصل الأول ← نصف السنة ← معدل الفصل الثاني
    // ← السعي السنوي ← النهائي ← النهائية ← الإكمال ← بعد الإكمال ← الملاحظات.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Table(
        border: border,
        columnWidths: const {
          0: FixedColumnWidth(28),
          1: FlexColumnWidth(3.1),
          2: FlexColumnWidth(0.82),
          3: FlexColumnWidth(0.82),
          4: FlexColumnWidth(0.82),
          5: FlexColumnWidth(0.82),
          6: FlexColumnWidth(0.82),
          7: FlexColumnWidth(0.82),
          8: FlexColumnWidth(0.82),
          9: FlexColumnWidth(0.82),
          10: FlexColumnWidth(1.15),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF2F2F2)),
            children: [
              // Table نفسها لا تعكس ترتيب الخلايا تلقائياً؛ لذلك نضع
              // الخلايا بترتيب RTL صريح داخل الصف.
              _tableHeaderVertical('ت'),
              _tableHeader('اسم الطالب'),
              _tableHeaderVertical('معدل الفصل الأول'),
              _tableHeaderVertical('امتحان نصف السنة'),
              _tableHeaderVertical('معدل الفصل الثاني'),
              _tableHeaderVertical('السعي السنوي'),
              _tableHeaderVertical('درجة الامتحان النهائي'),
              _tableHeaderVertical('الدرجة النهائية'),
              _tableHeaderVertical('درجة الإكمال'),
              _tableHeaderVertical('الدرجة بعد الإكمال'),
              _tableHeaderVertical('الملاحظات'),
            ],
          ),
          for (var i = 0; i < students.length; i++)
            TableRow(
              children: [
                _tableCell(
                  ArabicNumbers.toArabic(startIndex + i + 1),
                  center: true,
                ),
                _tableCell(students[i].name, bold: true),
                for (final v in _recordValues(calc.year(students[i].id, section.id)))
                  _tableCell(v, center: true),
              ],
            ),
        ],
      ),
    );
  }

  Widget _tableHeader(String text) {
    return Container(
      height: 58,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(5),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _tableHeaderVertical(String text) {
    return SizedBox(
      height: 118,
      child: Center(
        child: RotatedBox(
          quarterTurns: 3,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 9,
            ),
          ),
        ),
      ),
    );
  }

  Widget _tableCell(String text, {bool center = false, bool bold = false}) {
    return Container(
      height: 38,
      alignment: center ? Alignment.center : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.right,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: bold ? 14 : 12.5,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  /// قيم أعمدة السجل التسعة بالترتيب: الفصل الأول، نصف السنة، الفصل الثاني،
  /// السعي السنوي، الامتحان النهائي، الدرجة النهائية، الإكمال، بعد الإكمال، الملاحظات.
  List<String> _recordValues(YearResult y) => [
        _fmt(y.first),
        _fmt(y.midyear),
        _fmt(y.second),
        _fmt(y.annual),
        _fmt(y.finalExam),
        _fmt(y.finalGrade),
        _fmt(y.completionExam),
        _fmt(y.afterCompletion),
        y.status,
      ];

  String _fmt(double? value) {
    if (value == null) return '';
    final rounded = value % 1 == 0
        ? value.toInt()
        : double.parse(value.toStringAsFixed(2));
    return ArabicNumbers.toArabic(rounded);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
