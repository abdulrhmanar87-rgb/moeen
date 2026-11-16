import 'package:flutter/material.dart';

import '../app_theme.dart';

// عناصر واجهة مشتركة بين واجهتي المدرس والإدارة، حتى يبقى التصميم واحداً.

/// سطح قائمة واحد بفواصل (بدل بطاقات متكررة).
class MoeenSurface extends StatelessWidget {
  const MoeenSurface({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: p.border),
          children[i],
        ],
      ]),
    );
  }
}

class MoeenRadio extends StatelessWidget {
  const MoeenRadio({super.key, required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: on ? p.primary : p.outline, width: 2),
      ),
      alignment: Alignment.center,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        scale: on ? 1 : 0,
        child: Container(width: 10, height: 10, decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle)),
      ),
    );
  }
}

/// زر على اللوحة الملوّنة: أبيض للعمل الأساسي، وشفاف للثاني.
/// ينضغط قليلاً عند اللمس.
class PanelButton extends StatefulWidget {
  const PanelButton({super.key, required this.icon, required this.label, required this.primary, required this.onTap});
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  State<PanelButton> createState() => _PanelButtonState();
}

class _PanelButtonState extends State<PanelButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // على الأبيض نكتب بلون اللوحة نفسها، فيبقى واضحاً في الوضعين.
    final fgColor = widget.primary ? p.hero : Colors.white;
    return AnimatedScale(
      scale: _down ? .97 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: Material(
        color: widget.primary ? Colors.white : Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _down = v),
          child: SizedBox(
            height: 52,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(widget.icon, size: 20, color: fgColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(widget.label,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15.5, color: fgColor)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class GlassChip extends StatelessWidget {
  const GlassChip({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 5),
              Text(label, style: const TextStyle(fontSize: 13, color: Colors.white)),
            ]),
          ),
        ),
      );
}

/// أسطر دفتر خفيفة وهامش وردي على لوحة الحبر: توقيع «دفتر المدرس».
class NotebookLinesPainter extends CustomPainter {
  const NotebookLinesPainter({this.marginColor = const Color(0xFFE38B8F)});
  final Color marginColor;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: .06)
      ..strokeWidth = 1;
    for (var y = 32.0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    // الهامش على جهة بداية السطر (اليمين في العربية).
    final margin = Paint()
      ..color = marginColor.withValues(alpha: .5)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(size.width - 12, 0), Offset(size.width - 12, size.height), margin);
  }

  @override
  bool shouldRepaint(covariant NotebookLinesPainter oldDelegate) => oldDelegate.marginColor != marginColor;
}

/// لوحة ملوّنة بأسطر الدفتر (رأس الواجهة في النسختين).
class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key, required this.child, this.marginColor = const Color(0xFFE38B8F)});
  final Widget child;
  final Color marginColor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.hero,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          if (!p.dark)
            BoxShadow(color: p.hero.withValues(alpha: .45), blurRadius: 24, offset: const Offset(0, 10), spreadRadius: -12),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: CustomPaint(
          painter: NotebookLinesPainter(marginColor: marginColor),
          child: Padding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 16), child: child),
        ),
      ),
    );
  }
}

/// عنوان قسم في الواجهة مع زر اختياري.
class MoeenHeading extends StatelessWidget {
  const MoeenHeading(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 26, 2, 8),
        child: SizedBox(
          height: 36,
          child: Row(children: [
            Expanded(child: Text(text, style: TextStyle(fontSize: 16, color: context.palette.ink))),
            if (trailing != null) trailing!,
          ]),
        ),
      );
}

/// سطر في [MoeenSurface]: أيقونة أو عنصر بداية، عنوان وشرح، ونهاية اختيارية.
class MoeenRow extends StatelessWidget {
  const MoeenRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.selected = false,
    required this.onTap,
  });
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: selected ? p.selected : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 62),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(title, style: TextStyle(fontSize: 15, color: p.text)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: TextStyle(fontSize: 12.5, color: p.muted)),
                  ],
                ]),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            ]),
          ),
        ),
      ),
    );
  }
}

/// مربع أيقونة بخلفية خفيفة (بداية سطر في الفهرس).
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.badge});
  final IconData icon;

  /// رقم صغير على الزاوية (لخطوات حقيقية التسلسل).
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, size: 21, color: p.ink),
        ),
        if (badge != null)
          PositionedDirectional(
            top: -5,
            start: -5,
            child: Container(
              width: 19,
              height: 19,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.hero, shape: BoxShape.circle, border: Border.all(color: p.card, width: 2)),
              child: Text(badge!, style: const TextStyle(fontSize: 10.5, color: Colors.white, height: 1.1)),
            ),
          ),
      ]),
    );
  }
}
