import 'package:flutter/material.dart';

/// ألوان النسخة (مدرس أو إدارة). الشاشات المشتركة تقرأها من السياق:
/// `context.palette.ink` بدل لون ثابت، فتأخذ كل نسخة ألوانها تلقائياً.
@immutable
class MoeenPalette extends ThemeExtension<MoeenPalette> {
  const MoeenPalette({
    required this.ink,
    required this.primary,
    required this.soft,
    required this.selected,
    required this.border,
    required this.outline,
    required this.surface,
    required this.field,
    required this.fieldBorder,
    required this.imageBackdrop,
    required this.accent,
  });

  /// لون العناوين والنص البارز.
  final Color ink;

  /// لون الأزرار والعناصر التفاعلية.
  final Color primary;

  /// خلفية فاتحة للشارات والدوائر.
  final Color soft;

  /// خلفية العنصر المختار.
  final Color selected;
  final Color border;
  final Color outline;
  final Color surface;
  final Color field;
  final Color fieldBorder;
  final Color imageBackdrop;

  /// لمسة مميزة (ذهبي في نسخة الإدارة).
  final Color accent;

  /// نسخة المدرس: بنفسجي «دفتر المدرس».
  static const teacher = MoeenPalette(
    ink: Color(0xFF3D2B86),
    primary: Color(0xFF5B45B5),
    soft: Color(0xFFEDE9FF),
    selected: Color(0xFFF1EEFB),
    border: Color(0xFFE6E2F2),
    outline: Color(0xFFD7D0F2),
    surface: Color(0xFFF8F7FD),
    field: Color(0xFFF9F8FE),
    fieldBorder: Color(0xFFE2DDF1),
    imageBackdrop: Color(0xFFF2F0F7),
    accent: Color(0xFFE38B8F),
  );

  /// نسخة الإدارة: كحلي السجلات الرسمية مع لمسة ذهبية.
  static const admin = MoeenPalette(
    ink: Color(0xFF14305A),
    primary: Color(0xFF1F4E8C),
    soft: Color(0xFFE3EBF6),
    selected: Color(0xFFEDF2FA),
    border: Color(0xFFD9E2EF),
    outline: Color(0xFFC3D2E6),
    surface: Color(0xFFF3F6FA),
    field: Color(0xFFF7F9FC),
    fieldBorder: Color(0xFFD5DFEC),
    imageBackdrop: Color(0xFFEEF2F8),
    accent: Color(0xFFC9A043),
  );

  @override
  MoeenPalette copyWith({Color? ink, Color? primary, Color? soft}) => MoeenPalette(
        ink: ink ?? this.ink,
        primary: primary ?? this.primary,
        soft: soft ?? this.soft,
        selected: selected,
        border: border,
        outline: outline,
        surface: surface,
        field: field,
        fieldBorder: fieldBorder,
        imageBackdrop: imageBackdrop,
        accent: accent,
      );

  @override
  MoeenPalette lerp(MoeenPalette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return MoeenPalette(
      ink: l(ink, other.ink),
      primary: l(primary, other.primary),
      soft: l(soft, other.soft),
      selected: l(selected, other.selected),
      border: l(border, other.border),
      outline: l(outline, other.outline),
      surface: l(surface, other.surface),
      field: l(field, other.field),
      fieldBorder: l(fieldBorder, other.fieldBorder),
      imageBackdrop: l(imageBackdrop, other.imageBackdrop),
      accent: l(accent, other.accent),
    );
  }
}

extension MoeenPaletteContext on BuildContext {
  MoeenPalette get palette => Theme.of(this).extension<MoeenPalette>() ?? MoeenPalette.teacher;
}

/// ألوان ثابتة لشاشات الإدارة فقط (تطابق [MoeenPalette.admin]).
class AdminColors {
  static const ink = Color(0xFF14305A);
  static const primary = Color(0xFF1F4E8C);
  static const soft = Color(0xFFE3EBF6);
  static const selected = Color(0xFFEDF2FA);
  static const border = Color(0xFFD9E2EF);
  static const gold = Color(0xFFC9A043);
  static const goldSoft = Color(0xFFF7EFD9);
}

class AppTheme {
  /// خط التطبيق (assets/fonts/KhalidArt-Bold.ttf).
  static const fontFamily = 'KhalidArt';

  // ألوان نسخة المدرس (للشاشات الخاصة بالمدرس).
  static const primary = Color(0xFF5B45B5);
  static const primaryDark = Color(0xFF3D2B86);
  static const surface = Color(0xFFF8F7FD);
  static const softPurple = Color(0xFFEDE9FF);
  static const success = Color(0xFF39B982);
  static const warning = Color(0xFFFFC857);

  static ThemeData get light => lightFor(MoeenPalette.teacher);
  static ThemeData get dark => darkFor(const Color(0xFF9B88E8), MoeenPalette.teacher);

  static ThemeData get adminLight => lightFor(MoeenPalette.admin);
  static ThemeData get adminDark => darkFor(const Color(0xFF6F96CF), MoeenPalette.admin);

  static ThemeData lightFor(MoeenPalette p) {
    final scheme = ColorScheme.fromSeed(
      seedColor: p.primary,
      brightness: Brightness.light,
      primary: p.primary,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.surface,
      fontFamily: fontFamily,
      extensions: [p],
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.ink,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: p.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.field,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: p.fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: p.fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: p.primary, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          side: BorderSide(color: p.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        backgroundColor: p.soft,
        labelStyle: TextStyle(fontWeight: FontWeight.w700, color: p.ink),
      ),
    );
  }

  static ThemeData darkFor(Color seed, MoeenPalette p) => ThemeData(
        useMaterial3: true,
        fontFamily: fontFamily,
        extensions: [p],
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
      );
}
