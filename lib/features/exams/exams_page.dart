import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/constants/semesters.dart';
import '../../core/sound/tick_sound.dart';
import '../../core/storage/app_store.dart';
import '../../core/utils/arabic_numbers.dart';
import '../../models/assessment.dart';
import '../../services/calculation_service.dart';

class ExamsPage extends StatefulWidget {
  const ExamsPage({super.key, required this.store, this.initialSectionId});
  final String? initialSectionId;
  final AppStore store;

  @override
  State<ExamsPage> createState() => _ExamsPageState();
}

class _ExamsPageState extends State<ExamsPage> with SingleTickerProviderStateMixin {
  late TabController tabs;
  String? sectionId;
  int semester = Semesters.current();

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 3, vsync: this);
    final initial = widget.initialSectionId;
    sectionId = (initial != null && widget.store.sections.any((s) => s.id == initial))
        ? initial
        : widget.store.currentSectionId;
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  double get _dailyExamInputMax {
    final raw = widget.store.settings['dailyExamInputMax'];
    final value = raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? '');
    if (value == null || value <= 0) return 10;
    return value.clamp(1, 100).toDouble();
  }

  String _maxText(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 2);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الامتحانات والدرجات'),
          bottom: TabBar(controller: tabs, tabs: [
            Tab(text: 'يومي من ${_maxText(_dailyExamInputMax)}'),
            const Tab(text: 'شهري ونصف السنة'),
            const Tab(text: 'التقدير'),
          ]),
        ),
        body: Column(
          children: [
            if (widget.store.sections.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: DropdownButtonFormField<String>(
                  initialValue: sectionId,
                  decoration: const InputDecoration(labelText: 'الشعبة'),
                  items: widget.store.sections.map((s) => DropdownMenuItem(
                    value: s.id, child: Text('${s.gradeName} - ${s.name}'),
                  )).toList(),
                  onChanged: (v) {
                    setState(() => sectionId = v);
                    widget.store.setCurrentSection(v);
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 1, label: Text('الفصل الأول')),
                  ButtonSegment(value: 2, label: Text('الفصل الثاني')),
                ],
                selected: {semester},
                onSelectionChanged: (v) => setState(() => semester = v.first),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: tabs,
                children: [
                  _daily(),
                  _monthly(),
                  _rating(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _daily() {
    final store = widget.store;
    final exams = store.dailyExams
        .where((e) => e.sectionId == sectionId && e.semester == semester)
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: FilledButton.icon(
            onPressed: sectionId == null ? null : _newDailyExam,
            icon: const Icon(Icons.add),
            label: const Text('امتحان يومي جديد'),
          ),
        ),
        Expanded(
          child: exams.isEmpty
              ? Center(child: Text('لا توجد امتحانات يومية في ${Semesters.name(semester)}.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: exams.length,
                  itemBuilder: (_, i) => Card(
                    child: ListTile(
                      title: Text(exams[i].title),
                      subtitle: Text('${exams[i].date} • ${_enteredCount(exams[i].id)} درجة مدخلة'),
                      trailing: FilledButton(
                        onPressed: () => _enterDaily(exams[i]),
                        child: const Text('الدرجات'),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _newDailyExam() async {
    final title = TextEditingController();
    final store = widget.store;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('امتحان يومي جديد — ${Semesters.name(semester)}'),
        content: TextField(controller: title, decoration: const InputDecoration(labelText: 'اسم الامتحان')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              if (title.text.trim().isEmpty) return;
              store.dailyExams.add(DailyExam(
                id: store.id(),
                sectionId: sectionId!,
                date: DateTime.now().toIso8601String().substring(0, 10),
                title: title.text.trim(),
                semester: semester,
              ));
              await store.saveAll();
              if (mounted) {
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
  }

  Future<void> _enterDaily(DailyExam exam) async {
    final store = widget.store;
    final students = store.studentsOf(exam.sectionId);
    final controllers = <String, TextEditingController>{};
    final focusNodes = <String, FocusNode>{};
    for (final s in students) {
      final old = store.dailyScores
          .where((x) => x.examId == exam.id && x.studentId == s.id)
          .toList();
      controllers[s.id] = TextEditingController(
        text: old.isEmpty || old.first.score == null
            ? ''
            : old.first.score!.toString(),
      );
      focusNodes[s.id] = FocusNode();
    }

    bool invalidGradeExists() {
      for (final s in students) {
        final text = controllers[s.id]!.text.trim();
        if (text.isEmpty) continue;
        final value = ArabicNumbers.parseDouble(text);
        final maxInput = _dailyExamInputMax;
        if (value == null || value < 0 || value > maxInput) return true;
      }
      return false;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('درجات: ${exam.title}'),
        content: SizedBox(
          width: 520,
          child: ListView(
            shrinkWrap: true,
            children: students.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(s.name)),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: controllers[s.id],
                        focusNode: focusNodes[s.id],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: const [EnglishDigitsFormatter()],
                        textInputAction: i == students.length - 1
                            ? TextInputAction.done
                            : TextInputAction.next,
                        onSubmitted: (_) {
                          final text = controllers[s.id]!.text.trim();
                          final value = ArabicNumbers.parseDouble(text);
                          if (text.isNotEmpty &&
                              (value == null || value < 0 || value > _dailyExamInputMax)) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text('الدرجة يجب أن تكون بين 0 و ${_maxText(_dailyExamInputMax)}.'),
                              ),
                            );
                            focusNodes[s.id]!.requestFocus();
                            return;
                          }
                          if (i < students.length - 1) {
                            FocusScope.of(dialogContext).requestFocus(
                              focusNodes[students[i + 1].id],
                            );
                          } else {
                            FocusScope.of(dialogContext).unfocus();
                          }
                        },
                        decoration: InputDecoration(
                          labelText: '0-${_maxText(_dailyExamInputMax)}',
                          hintText: 'مثال: ${(_dailyExamInputMax / 2).toStringAsFixed(1)}',
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              if (invalidGradeExists()) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text('يوجد طالب بدرجة غير صحيحة. أدخل درجة بين 0 و ${_maxText(_dailyExamInputMax)} فقط.'),
                  ),
                );
                return;
              }

              for (final s in students) {
                final text = controllers[s.id]!.text.trim();
                final value = ArabicNumbers.parseDouble(text);
                final idx = store.dailyScores.indexWhere(
                  (x) => x.examId == exam.id && x.studentId == s.id,
                );
                final row = DailyExamScore(
                  id: idx >= 0 ? store.dailyScores[idx].id : store.id(),
                  examId: exam.id,
                  studentId: s.id,
                  score: value,
                  status: value == null ? 'لم يدخل' : 'درجة',
                );
                if (idx >= 0) {
                  store.dailyScores[idx] = row;
                } else {
                  store.dailyScores.add(row);
                }
              }
              await store.saveAll();
              if (!mounted || !dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              setState(() {});
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    // Dispose resources if the dialog was closed using Cancel or otherwise.
    for (final controller in controllers.values) {
      controller.dispose();
    }
    for (final node in focusNodes.values) {
      if (!node.hasFocus) node.dispose();
    }
  }

  int _enteredCount(String examId) => widget.store.dailyScores
      .where((x) => x.examId == examId && x.status == 'درجة' && x.score != null)
      .length;

  Widget _monthly() {
    final store = widget.store;
    final students = sectionId == null ? [] : store.studentsOf(sectionId!);
    final periods = Semesters.months(semester);
    int entered(String period, {bool midyear = false}) => midyear
        ? store.midyearScores.where((x) => x.sectionId == sectionId && x.score != null).length
        : store.monthlyScores
            .where((x) => x.sectionId == sectionId && x.period == period && x.score != null)
            .length;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text('الامتحانات الشهرية — ${Semesters.name(semester)} (من 100)',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        for (final period in periods)
          Card(
            child: ListTile(
              title: Text(period),
              subtitle: Text('${entered(period)} من ${students.length} طالب'),
              trailing: FilledButton(
                onPressed: sectionId == null ? null : () => _enterMonthly(period),
                child: const Text('إدخال'),
              ),
            ),
          ),
        const SizedBox(height: 18),
        const Text('امتحان نصف السنة (من 100)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            title: const Text(Semesters.midyear),
            subtitle: Text('${entered('', midyear: true)} من ${students.length} طالب'),
            trailing: FilledButton(
              onPressed: sectionId == null ? null : () => _enterMonthly(Semesters.midyear, midyear: true),
              child: const Text('إدخال'),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _endOfYear(students.cast()),
        const SizedBox(height: 14),
        Text(
          'سعي الفصل = معدل الامتحانات الشهرية (${store.weight('monthlyExamsWeight', 70)}) '
          '+ معدل الامتحانات اليومية (${store.weight('dailyExamsWeight', 20)}) '
          '+ تقدير السلوك والمشاركة (${store.weight('ratingWeight', 10)}). '
          'الطالب المؤجل أو الغائب يُستبعد امتحانه من معدله.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.6),
        ),
      ],
    );
  }

  /// نهاية السنة: الامتحان النهائي لكل الطلاب، والإكمال للطلاب دون 50 فقط.
  Widget _endOfYear(List<dynamic> students) {
    final store = widget.store;
    final calc = CalculationService(store);
    final sid = sectionId;
    int entered(String period) => store.monthlyScores
        .where((x) => x.sectionId == sid && x.period == period && x.score != null)
        .length;
    final needCompletion = sid == null
        ? <String>{}
        : {for (final st in students) if (calc.year(st.id, sid).needsCompletion) st.id as String};

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('نهاية السنة (من 100)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(
        'الدرجة النهائية = (السعي السنوي + الامتحان النهائي) ÷ 2. '
        'من تقل درجته النهائية عن ${Semesters.passMark} يكون مكملاً ويُدخل له امتحان الإكمال.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.6),
      ),
      const SizedBox(height: 10),
      Card(
        child: ListTile(
          title: const Text(Semesters.finalExam),
          subtitle: Text('${entered(Semesters.finalExam)} من ${students.length} طالب'),
          trailing: FilledButton(
            onPressed: sid == null ? null : () => _enterMonthly(Semesters.finalExam),
            child: const Text('إدخال'),
          ),
        ),
      ),
      Card(
        child: ListTile(
          title: const Text(Semesters.completionExam),
          subtitle: Text(needCompletion.isEmpty
              ? 'لا يوجد طلاب مكملون حالياً'
              : '${needCompletion.length} طالب مكمل'),
          trailing: FilledButton(
            onPressed: sid == null || needCompletion.isEmpty
                ? null
                : () => _enterMonthly(Semesters.completionExam, onlyStudentIds: needCompletion),
            child: const Text('إدخال'),
          ),
        ),
      ),
    ]);
  }

  // ---------------------------------------------------------------------------
  // تقدير السلوك والمشاركة بشريط متحرك
  // ---------------------------------------------------------------------------

  /// قيم الشريط أثناء السحب (لكل طالب) لتبقى الحركة سلسة دون حفظ كل لحظة.
  final Map<String, double> _drag = {};

  bool get _soundOn => widget.store.settings['ratingSound'] != false;

  static Color _ratingColor(int? score) {
    if (score == null) return const Color(0xFFB8B4C6);
    if (score >= 9) return const Color(0xFF2E9B5F);
    if (score == 8) return const Color(0xFF4FA85A);
    if (score == 7) return const Color(0xFF8DB43C);
    if (score == 6) return const Color(0xFFD9A400);
    if (score == 5) return const Color(0xFFE8892B);
    return const Color(0xFFD64545);
  }

  Widget _rating() {
    final store = widget.store;
    if (sectionId == null) return const Center(child: Text('اختر شعبة أولاً.'));
    final sid = sectionId!;
    final students = store.studentsOf(sid);
    final weight = store.weight('ratingWeight', 10);
    final unrated = students.where((s) => store.ratingOf(s.id, sid, semester) == null).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      children: [
        Row(children: [
          Expanded(
            child: Text('تقدير السلوك والمشاركة، ${Semesters.name(semester)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            tooltip: _soundOn ? 'إيقاف الصوت' : 'تشغيل الصوت',
            onPressed: () async {
              store.settings['ratingSound'] = !_soundOn;
              await store.saveAll();
              if (mounted) setState(() {});
            },
            icon: Icon(_soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded),
          ),
        ]),
        Text(
          'اسحب المؤشر لكل طالب: الدرجة من 0 إلى 10'
          '${weight == 10 ? '' : '، وتُحسب من $weight في سعي الفصل'}. '
          'ضعيف أقل من 5، مقبول 5، متوسط 6، جيد 7، جيد جداً 8، ممتاز 9 و10.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.6),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Chip(label: Text(unrated == 0 ? 'تم تقييم الجميع ✓' : 'لم يُقيَّم: $unrated من ${students.length}')),
          if (unrated > 0)
            OutlinedButton.icon(
              onPressed: () => _fillUnrated(students.map((s) => s.id).toList(), sid),
              icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
              label: const Text('إعطاء غير المقيَّمين 8'),
            ),
        ]),
        const SizedBox(height: 10),
        if (students.isEmpty)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: Text('لا يوجد طلاب في الشعبة.')),
          )
        else
          Card(
            child: Column(children: [
              for (var i = 0; i < students.length; i++) ...[
                _ratingRow(i + 1, students[i].id, students[i].name, sid),
                if (i < students.length - 1) const Divider(height: 1, indent: 14, endIndent: 14),
              ],
            ]),
          ),
      ],
    );
  }

  Widget _ratingRow(int number, String studentId, String name, String sid) {
    final store = widget.store;
    final saved = store.ratingOf(studentId, sid, semester);
    final dragging = _drag.containsKey(studentId);
    final shown = dragging ? _drag[studentId]!.round() : saved;
    final color = _ratingColor(shown);

    Widget slider(double value) => CupertinoSlider(
          value: value.clamp(0, 10).toDouble(),
          min: 0,
          max: 10,
          activeColor: color,
          onChangeStart: (v) => setState(() => _drag[studentId] = v),
          onChanged: (v) {
            final before = (_drag[studentId] ?? v).round();
            setState(() => _drag[studentId] = v);
            if (v.round() != before && _soundOn) playTick(v);
          },
          onChangeEnd: (v) {
            final score = v.round().clamp(0, 10);
            setState(() => _drag.remove(studentId));
            store.setRating(studentId, sid, semester, score);
            if (_soundOn) playSettle(score.toDouble());
          },
        );

    // شريط واحد ثابت: يتبع الإصبع فوراً أثناء السحب، وعند الترك
    // ينزلق بنعومة إلى أقرب درجة صحيحة (المحفوظة).
    final sliderWidget = TweenAnimationBuilder<double>(
      key: ValueKey('rating-$studentId'),
      tween: Tween(end: dragging ? _drag[studentId]! : (saved ?? 8).toDouble()),
      duration: dragging ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => slider(v),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          SizedBox(width: 28, child: Text('$number', style: TextStyle(color: Colors.grey.shade600))),
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              shown == null ? 'لم يُقيَّم' : '$shown  ${RatingLevels.label(shown)}',
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Text('0', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          Expanded(
            child: Opacity(opacity: saved == null && !dragging ? 0.55 : 1, child: sliderWidget),
          ),
          Text('10', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ]),
      ]),
    );
  }

  Future<void> _fillUnrated(List<String> studentIds, String sid) async {
    final store = widget.store;
    for (final id in studentIds) {
      if (store.ratingOf(id, sid, semester) == null) {
        store.semesterRatings.add(SemesterRating(
          id: store.id() + id,
          sectionId: sid,
          studentId: id,
          semester: semester,
          score: 8,
        ));
      }
    }
    await store.saveAll();
    if (mounted) setState(() {});
  }

  Future<void> _enterMonthly(String period, {bool midyear = false, Set<String>? onlyStudentIds}) async {
    final store = widget.store;
    final students = store
        .studentsOf(sectionId!)
        .where((s) => onlyStudentIds == null || onlyStudentIds.contains(s.id))
        .toList();
    final controllers = <String, TextEditingController>{};
    final focusNodes = <String, FocusNode>{};
    String fmt(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();
    for (final s in students) {
      double? old;
      if (midyear) {
        for (final x in store.midyearScores) {
          if (x.sectionId == sectionId && x.studentId == s.id) old = x.score;
        }
      } else {
        for (final x in store.monthlyScores) {
          if (x.sectionId == sectionId && x.studentId == s.id && x.period == period) old = x.score;
        }
      }
      controllers[s.id] = TextEditingController(text: old == null ? '' : fmt(old));
      focusNodes[s.id] = FocusNode();
    }

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(period),
        content: SizedBox(
          width: 520,
          child: ListView(
            shrinkWrap: true,
            children: students.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              return Row(
              children: [
                Expanded(child: Text(s.name)),
                const SizedBox(width: 10),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: controllers[s.id],
                    focusNode: focusNodes[s.id],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: const [EnglishDigitsFormatter()],
                    textInputAction: i == students.length - 1 ? TextInputAction.done : TextInputAction.next,
                    onSubmitted: (_) {
                      if (i < students.length - 1) {
                        FocusScope.of(context).requestFocus(focusNodes[students[i + 1].id]);
                      } else {
                        FocusScope.of(context).unfocus();
                      }
                    },
                    decoration: const InputDecoration(labelText: '0-100'),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => controllers[s.id]!.text = v == 'صفر' ? '0' : '',
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'مؤجل', child: Text('مؤجل')),
                    PopupMenuItem(value: 'صفر', child: Text('صفر')),
                  ],
                ),
              ],
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              for (final s in students) {
                final text = controllers[s.id]!.text.trim();
                final value = ArabicNumbers.parseDouble(text);
                if (midyear) {
                  final mi = store.midyearScores.indexWhere((x) => x.sectionId == sectionId && x.studentId == s.id);
                  final row = MidyearScore(
                    id: mi >= 0 ? store.midyearScores[mi].id : store.id(),
                    sectionId: sectionId!,
                    studentId: s.id,
                    score: value?.clamp(0, 100).toDouble(),
                    status: value == null ? 'مؤجل' : 'مكتمل',
                  );
                  if (mi >= 0) {
                    store.midyearScores[mi] = row;
                  } else {
                    store.midyearScores.add(row);
                  }
                  continue;
                }
                final idx = store.monthlyScores.indexWhere((x) =>
                    x.sectionId == sectionId && x.studentId == s.id && x.period == period);
                final row = MonthlyExamScore(
                  id: idx >= 0 ? store.monthlyScores[idx].id : store.id(),
                  sectionId: sectionId!,
                  studentId: s.id,
                  period: period,
                  score: value?.clamp(0, 100).toDouble(),
                  status: value?.toString() == null ? 'مؤجل' : 'مكتمل',
                );
                if (idx >= 0) {
                  store.monthlyScores[idx] = row;
                } else {
                  store.monthlyScores.add(row);
                }
              }
              await store.saveAll();
              if (mounted) {
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    for (final node in focusNodes.values) {
      node.dispose();
    }
  }
}
