import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/sound/tick_sound.dart';

/// شريط تقدير من 0 إلى 10 مصمم لإصبع المدرس:
/// - مسار سميك بعلامات للدرجات الإحدى عشرة، والجزء المملوء بلون المستوى.
/// - المؤشر يتبع الإصبع بلا تأخير، والرقم يظهر فوقه أثناء السحب.
/// - عند الترك ينزلق بنعومة إلى أقرب درجة صحيحة.
/// - ضغطة واحدة على أي مكان في المسار تضع الدرجة مباشرة.
/// - السحب الأفقي فقط يحرك الشريط، فالتمرير العمودي للقائمة لا يتأثر.
/// - يعيد بناء نفسه فقط أثناء السحب (لا الصفحة كلها) فيبقى سلساً.
class RatingSlider extends StatefulWidget {
  const RatingSlider({
    super.key,
    required this.value,
    required this.colorOf,
    required this.onChanged,
    this.onPreview,
    this.sound = true,
  });

  /// الدرجة المحفوظة، أو null إذا لم يُقيَّم الطالب.
  final int? value;
  final Color Function(int? value) colorOf;
  final ValueChanged<int> onChanged;

  /// تُستدعى أثناء السحب بالدرجة الحالية (لتحديث الشارة بجانب الاسم).
  final ValueChanged<int?>? onPreview;
  final bool sound;

  @override
  State<RatingSlider> createState() => _RatingSliderState();
}

class _RatingSliderState extends State<RatingSlider> with SingleTickerProviderStateMixin {
  static const _max = 10;
  static const _thumb = 30.0;
  static const _track = 10.0;

  late final AnimationController _settle = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  Animation<double>? _settleAnim;

  double? _drag; // القيمة أثناء السحب (كسرية)
  int? _lastWhole;
  bool _hDrag = false;

  double get _shown {
    if (_drag != null) return _drag!;
    if (_settleAnim != null && _settle.isAnimating) return _settleAnim!.value;
    return (widget.value ?? 8).toDouble();
  }

  @override
  void initState() {
    super.initState();
    _settle.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  double _valueAt(double dx, double width) {
    final usable = width - _thumb;
    var f = ((dx - _thumb / 2) / usable).clamp(0.0, 1.0);
    if (_rtl) f = 1 - f;
    return f * _max;
  }

  void _start(double dx, double width) {
    primeSound();
    _settle.stop();
    setState(() {
      _drag = _valueAt(dx, width);
      _lastWhole = _drag!.round();
    });
    widget.onPreview?.call(_lastWhole);
  }

  void _move(double dx, double width) {
    final v = _valueAt(dx, width);
    final whole = v.round();
    setState(() => _drag = v);
    if (whole != _lastWhole) {
      _lastWhole = whole;
      HapticFeedback.selectionClick();
      if (widget.sound) playTick(whole.toDouble());
      widget.onPreview?.call(whole);
    }
  }

  void _end() {
    final from = _drag ?? _shown;
    final to = from.round().clamp(0, _max);
    _settleAnim = Tween(begin: from, end: to.toDouble())
        .animate(CurvedAnimation(parent: _settle, curve: Curves.easeOutBack));
    setState(() => _drag = null);
    _settle.forward(from: 0);
    HapticFeedback.lightImpact();
    if (widget.sound) playSettle(to.toDouble());
    widget.onPreview?.call(null);
    widget.onChanged(to);
  }

  @override
  Widget build(BuildContext context) {
    final dragging = _drag != null;
    final whole = dragging ? _drag!.round() : widget.value;
    final color = widget.colorOf(whole);
    final unrated = widget.value == null && !dragging;

    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final usable = w - _thumb;
      final f = _shown / _max;
      final x = _thumb / 2 + (_rtl ? (1 - f) : f) * usable; // مركز المؤشر
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (d) {
          _hDrag = true;
          _drag == null ? _start(d.localPosition.dx, w) : _move(d.localPosition.dx, w);
        },
        onHorizontalDragUpdate: (d) => _move(d.localPosition.dx, w),
        onHorizontalDragEnd: (_) {
          _hDrag = false;
          _end();
        },
        onHorizontalDragCancel: () {
          _hDrag = false;
          if (_drag != null) _end();
        },
        onTapDown: (d) {
          _start(d.localPosition.dx, w);
          if (widget.sound) playTick(_drag!.round().toDouble());
        },
        onTapUp: (_) => _end(),
        // لمسة تحولت إلى تمرير عمودي: نلغي بلا حفظ.
        onTapCancel: () {
          if (!_hDrag && _drag != null) {
            setState(() => _drag = null);
            widget.onPreview?.call(null);
          }
        },
        child: SizedBox(
          height: 64,
          child: Stack(clipBehavior: Clip.none, children: [
            // المسار
            Positioned(
              left: _thumb / 2,
              right: _thumb / 2,
              top: 40 - _track / 2,
              height: _track,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFE9E6F2),
                  borderRadius: BorderRadius.circular(_track),
                ),
              ),
            ),
            // الجزء المملوء: من بداية المسار (يمين في العربية) حتى المؤشر
            if (!unrated)
              Positioned(
                left: _rtl ? x : _thumb / 2,
                right: _rtl ? _thumb / 2 : w - x,
                top: 40 - _track / 2,
                height: _track,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(_track)),
                ),
              ),
            // علامات الدرجات
            for (var i = 0; i <= _max; i++)
              Positioned(
                left: _thumb / 2 + (_rtl ? (1 - i / _max) : i / _max) * usable - 2,
                top: 40 - 2,
                width: 4,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: !unrated && (i <= _shown + .01) ? Colors.white.withValues(alpha: .85) : const Color(0xFFC9C3DA),
                  ),
                ),
              ),
            // فقاعة الرقم أثناء السحب
            Positioned(
              left: x - 22,
              top: 0,
              width: 44,
              height: 24,
              child: AnimatedOpacity(
                opacity: dragging ? 1 : 0,
                duration: const Duration(milliseconds: 120),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                  child: Center(
                    child: Text('${whole ?? ''}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                  ),
                ),
              ),
            ),
            // المؤشر
            Positioned(
              left: x - _thumb / 2,
              top: 40 - _thumb / 2,
              width: _thumb,
              height: _thumb,
              child: AnimatedScale(
                scale: dragging ? 1.18 : 1,
                duration: const Duration(milliseconds: 140),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: unrated ? const Color(0xFFC9C3DA) : color, width: unrated ? 2 : 3),
                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
    });
  }
}
