import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../models/student.dart';

/// قيمة خانة واحدة: درجة، أو غائب/مؤجل، أو فارغة.
class GradeValue {
  const GradeValue({this.score, this.absent = false});
  const GradeValue.empty() : score = null, absent = false;
  final double? score;
  final bool absent;
  bool get isEmpty => score == null && !absent;
}

/// إدخال الدرجات بأقل عدد من الضغطات:
/// - لوحة أرقام ثابتة أسفل الشاشة (لا تحتاج لوحة مفاتيح الهاتف ولا زر «التالي»).
/// - الدرجات أعداد صحيحة، والانتقال للطالب التالي فوري عندما تكتمل الدرجة
///   (مثلاً 7 من 10، أو 85 من 100).
/// - كل درجة تُحفظ فوراً، فلا يوجد زر حفظ.
/// - على الحاسوب: الأرقام و Enter والأسهم، و«غ» أو «-» للغائب.
class GradeEntryPage extends StatefulWidget {
  const GradeEntryPage({
    super.key,
    required this.title,
    required this.max,
    required this.students,
    required this.initial,
    required this.onSave,
    this.absentLabel = 'غائب',
    this.subtitle = '',
  });

  final String title;
  final String subtitle;
  final double max;
  final List<Student> students;
  final Map<String, GradeValue> initial;
  final String absentLabel;

  /// تُستدعى بكل القيم بعد كل تغيير (بتأخير بسيط) وعند الخروج.
  final Future<void> Function(Map<String, GradeValue> values) onSave;

  @override
  State<GradeEntryPage> createState() => _GradeEntryPageState();
}

class _GradeEntryPageState extends State<GradeEntryPage> {
  static const _rowHeight = 58.0;
  static const _red = Color(0xFFD64545), _amber = Color(0xFFD9822B);

  late final Map<String, GradeValue> values = {
    for (final s in widget.students) s.id: widget.initial[s.id] ?? const GradeValue.empty(),
  };
  final _scroll = ScrollController();
  final _focus = FocusNode();

  int index = 0;
  String buffer = '';
  bool _dirty = false;
  bool _flash = false;
  Timer? _advance;
  Timer? _saveTimer;

  List<Student> get students => widget.students;
  double get max => widget.max;

  @override
  void initState() {
    super.initState();
    // ابدأ من أول طالب بلا درجة.
    final first = students.indexWhere((s) => values[s.id]!.isEmpty);
    index = first < 0 ? 0 : first;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(index, animate: false));
  }

  @override
  void dispose() {
    _advance?.cancel();
    _commit();
    _saveTimer?.cancel();
    if (_dirty) widget.onSave(Map.of(values));
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------

  String _fmt(double v) {
    final r = double.parse(v.toStringAsFixed(2));
    return r % 1 == 0 ? r.toInt().toString() : r.toString();
  }

  void _scheduleSave() {
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () async {
      _dirty = false;
      await widget.onSave(Map.of(values));
    });
  }

  void _set(int i, GradeValue v) {
    values[students[i].id] = v;
    _scheduleSave();
  }

  /// يحفظ ما كُتب في الخانة الحالية.
  void _commit() {
    _advance?.cancel();
    if (buffer.isEmpty || index >= students.length) return;
    final v = double.tryParse(buffer);
    if (v != null && v <= max) _set(index, GradeValue(score: v));
    buffer = '';
  }

  void _go(int i) {
    _commit();
    setState(() {
      index = i.clamp(0, students.length);
      buffer = '';
    });
    if (index < students.length) _scrollTo(index);
  }

  void _next() => _go(index + 1);
  void _prev() => _go(index - 1);

  void _scrollTo(int i, {bool animate = true}) {
    if (!_scroll.hasClients) return;
    final view = _scroll.position.viewportDimension;
    final target = (i * _rowHeight - view / 2 + _rowHeight / 2)
        .clamp(0.0, _scroll.position.maxScrollExtent)
        .toDouble();
    if (animate) {
      _scroll.animateTo(target, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(target);
    }
  }

  /// هل اكتملت الدرجة فلا يمكن إضافة رقم آخر إليها؟
  bool _complete(String b) {
    if (b.isEmpty) return false;
    if (b == '0') return true;
    final v = double.parse(b);
    return v * 10 > max;
  }

  void _error() {
    HapticFeedback.heavyImpact();
    setState(() => _flash = true);
    Future.delayed(const Duration(milliseconds: 260), () {
      if (mounted) setState(() => _flash = false);
    });
  }

  void _digit(String d) {
    if (index >= students.length) return;
    HapticFeedback.selectionClick();
    // رقم جديد بعد درجة مكتملة = بداية درجة الطالب التالي.
    if (_complete(buffer)) {
      _next();
      if (index >= students.length) return;
    }
    final nb = buffer + d;
    final v = double.tryParse(nb);
    if (v == null || v > max) {
      _error();
      return;
    }
    setState(() => buffer = nb);
    if (_complete(nb)) {
      // لحظة قصيرة ليرى المدرس الرقم قبل الانتقال.
      _advance?.cancel();
      _advance = Timer(const Duration(milliseconds: 150), () {
        if (mounted) _next();
      });
    }
  }

  void _backspace() {
    if (index >= students.length) return;
    _advance?.cancel();
    HapticFeedback.selectionClick();
    setState(() {
      if (buffer.isNotEmpty) {
        buffer = buffer.substring(0, buffer.length - 1);
      } else {
        _set(index, const GradeValue.empty());
      }
    });
  }

  void _absent() {
    if (index >= students.length) return;
    HapticFeedback.selectionClick();
    buffer = '';
    _advance?.cancel();
    _set(index, const GradeValue(absent: true));
    _next();
  }

  void _full() {
    if (index >= students.length) return;
    HapticFeedback.selectionClick();
    buffer = '';
    _advance?.cancel();
    _set(index, GradeValue(score: max));
    _next();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter || k == LogicalKeyboardKey.tab ||
        k == LogicalKeyboardKey.arrowDown) {
      _next();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      _prev();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.backspace || k == LogicalKeyboardKey.delete) {
      _backspace();
      return KeyEventResult.handled;
    }
    final ch = e.character;
    if (ch == null || ch.isEmpty) return KeyEventResult.ignored;
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    final ai = arabic.indexOf(ch);
    if (ai >= 0) {
      _digit('$ai');
    } else if (RegExp(r'^[0-9]$').hasMatch(ch)) {
      _digit(ch);
    } else if (ch == 'غ' || ch == '-' || ch == 'a' || ch == 'A') {
      _absent();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final done = values.values.where((v) => !v.isEmpty).length;
    final finished = index >= students.length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          appBar: AppBar(
            title: Column(children: [
              Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w900)),
              Text(
                '${widget.subtitle.isEmpty ? '' : '${widget.subtitle} · '}من ${_fmt(max)}',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
              ),
            ]),
            actions: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: Center(
                  child: Text('$done/${students.length}',
                      style: TextStyle(fontWeight: FontWeight.w900, color: done == students.length ? AppTheme.success : p.ink)),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: LinearProgressIndicator(
                value: students.isEmpty ? 0 : done / students.length,
                minHeight: 4,
                backgroundColor: p.border,
                valueColor: AlwaysStoppedAnimation(done == students.length ? AppTheme.success : p.primary),
              ),
            ),
          ),
          body: Column(children: [
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView.builder(
                    controller: _scroll,
                    itemExtent: _rowHeight,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: students.length + 1,
                    itemBuilder: (_, i) => i == students.length ? _doneRow(p, finished) : _row(p, i),
                  ),
                ),
              ),
            ),
            _keypad(p, finished),
          ]),
        ),
      ),
    );
  }

  Widget _doneRow(MoeenPalette p, bool finished) => Center(
        child: finished
            ? FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check_rounded),
                label: const Text('تم، رجوع'),
              )
            : Text('الدرجات تُحفظ تلقائياً', style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5)),
      );

  Widget _row(MoeenPalette p, int i) {
    final s = students[i];
    final v = values[s.id]!;
    final current = i == index;
    final typing = current && buffer.isNotEmpty;
    String text;
    Color color;
    if (typing) {
      text = buffer;
      color = p.ink;
    } else if (v.absent) {
      text = widget.absentLabel;
      color = _amber;
    } else if (v.score != null) {
      text = _fmt(v.score!);
      color = v.score! < max / 2 ? _red : const Color(0xFF222222);
    } else {
      text = '';
      color = Colors.grey;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: current ? p.soft : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: current ? (_flash ? _red : p.primary) : p.border, width: current ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          canRequestFocus: false,
          onTap: () => _go(i),
          child: Row(children: [
            const SizedBox(width: 12),
            SizedBox(
              width: 28,
              child: Text('${i + 1}', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: Text(s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: current ? FontWeight.w900 : FontWeight.w600)),
            ),
            Container(
              width: 76,
              height: 40,
              margin: const EdgeInsets.all(6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: current ? Colors.white : (v.isEmpty ? Colors.grey.shade50 : Colors.transparent),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: current ? p.primary.withValues(alpha: .4) : Colors.grey.shade200),
              ),
              child: Text(
                text.isEmpty && current ? '|' : text,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: v.absent && !typing ? 14 : 19,
                  fontWeight: FontWeight.w900,
                  color: text.isEmpty && current ? p.primary : color,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _keypad(MoeenPalette p, bool finished) {
    Widget key(Widget child, VoidCallback? onTap, {Color? bg, Color? fg, int flex = 1}) => Expanded(
          flex: flex,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Material(
              color: bg ?? Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                canRequestFocus: false,
                borderRadius: BorderRadius.circular(12),
                onTap: finished ? null : onTap,
                child: SizedBox(
                  height: 50,
                  child: Center(
                    child: DefaultTextStyle(
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: finished ? Colors.grey : (fg ?? const Color(0xFF222222)),
                      ),
                      child: IconTheme(
                        data: IconThemeData(color: finished ? Colors.grey : (fg ?? const Color(0xFF222222))),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
    Widget digit(String d) => key(Text(d), () => _digit(d));
    const small = TextStyle(fontSize: 15, fontWeight: FontWeight.w800);

    return Container(
      color: p.border.withValues(alpha: .6),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
              // ترتيب لوحة الهاتف: 1 2 3 من اليسار.
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    digit('1'), digit('2'), digit('3'),
                    key(const Icon(Icons.backspace_outlined), _backspace),
                  ]),
                  Row(children: [
                    digit('4'), digit('5'), digit('6'),
                    key(Text(widget.absentLabel, style: small), _absent, bg: const Color(0xFFFFF1E2), fg: _amber),
                  ]),
                  Row(children: [
                    digit('7'), digit('8'), digit('9'),
                    key(Text('كاملة ${_fmt(max)}', style: small), _full, bg: const Color(0xFFE6F6EE), fg: AppTheme.success),
                  ]),
                  Row(children: [
                    key(const Icon(Icons.keyboard_arrow_up_rounded, size: 30), index == 0 ? null : _prev),
                    key(const Text('0'), () => _digit('0'), flex: 2),
                    key(const Icon(Icons.keyboard_arrow_down_rounded, size: 30), _next, bg: p.primary, fg: Colors.white),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
