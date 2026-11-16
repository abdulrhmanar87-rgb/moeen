import 'package:flutter/material.dart';

/// ألوان النسخة (مدرس أو إدارة). الشاشات المشتركة تقرأها من السياق:
/// `context.palette.ink` بدل لون ثابت، فتأخذ كل نسخة ألوانها تلقائياً.
@immutable
class MoeenPalette extends ThemeExtension<MoeenPalette> {
  const MoeenPalette({
    required this.dark,
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
    required this.card,
    required this.cardAlt,
    required this.text,
    required this.muted,
    required this.faint,
    required this.hero,
    required this.heroAlt,
    required this.warnText,
    required this.warnBg,
    required this.warnBorder,
    required this.track,
    required this.paperRule,
  });

  final bool dark;

  /// لون العناوين والنص البارز (فاتح في الوضع الليلي).
  final Color ink;

  /// لون الأزرار والعناصر التفاعلية.
  final Color primary;

  /// خلفية خفيفة للشارات والدوائر.
  final Color soft;

  /// خلفية العنصر المختار.
  final Color selected;
  final Color border;
  final Color outline;

  /// خلفية الشاشة.
  final Color surface;
  final Color field;
  final Color fieldBorder;
  final Color imageBackdrop;

  /// لمسة مميزة (ذهبي في نسخة الإدارة).
  final Color accent;

  /// خلفية البطاقات والصفوف.
  final Color card;

  /// خلفية الصف المتناوب أو الخانة الفارغة.
  final Color cardAlt;

  /// النص العادي.
  final Color text;

  /// النص الثانوي (الشرح، التاريخ، الأرقام الجانبية).
  final Color muted;

  /// النص الباهت جداً (تلميحات).
  final Color faint;

  /// خلفية ملونة يُكتب عليها بالأبيض (رأس الصفحة، الأزرار الكبيرة).
  final Color hero;
  final Color heroAlt;

  /// التنبيهات (النسخ الاحتياطي، المؤجل).
  final Color warnText;
  final Color warnBg;
  final Color warnBorder;

  /// مسار شريط التقدير.
  final Color track;
  final Color paperRule;

  /// خلفية خفيفة بلون دلالي (أخضر، أحمر، برتقالي) تصلح للوضعين.
  Color tint(Color c) => dark
      ? Color.alphaBlend(c.withValues(alpha: .22), card)
      : Color.alphaBlend(c.withValues(alpha: .11), Colors.white);

  /// لون دلالي (أحمر، أخضر...) أفتح قليلاً في الوضع الليلي ليُقرأ.
  Color sem(Color c) => dark ? Color.lerp(c, Colors.white, .28)! : c;

  /// نسخة المدرس: بنفسجي «دفتر المدرس».
  static const teacher = MoeenPalette(
    dark: false,
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
    card: Colors.white,
    cardAlt: Color(0xFFFAF9FD),
    text: Color(0xFF222222),
    muted: Color(0xFF5F5A73),
    faint: Color(0xFF9993B0),
    hero: Color(0xFF3D2B86),
    heroAlt: Color(0xFF5B45B5),
    warnText: Color(0xFF8A5A00),
    warnBg: Color(0xFFFFF6E0),
    warnBorder: Color(0xFFF1D58A),
    track: Color(0xFFE9E6F2),
    paperRule: Color(0xFFE4E9F5),
  );

  /// نسخة المدرس في الوضع الليلي.
  static const teacherDark = MoeenPalette(
    dark: true,
    ink: Color(0xFFCFC4FF),
    primary: Color(0xFF9D8BF0),
    soft: Color(0xFF2E2852),
    selected: Color(0xFF2A2547),
    border: Color(0xFF34304B),
    outline: Color(0xFF4C4670),
    surface: Color(0xFF14131C),
    field: Color(0xFF1F1D2C),
    fieldBorder: Color(0xFF3B3754),
    imageBackdrop: Color(0xFF1B1A26),
    accent: Color(0xFFE38B8F),
    card: Color(0xFF1D1B29),
    cardAlt: Color(0xFF232031),
    text: Color(0xFFECEAF5),
    muted: Color(0xFFB3AEC8),
    faint: Color(0xFF807A98),
    hero: Color(0xFF3E3190),
    heroAlt: Color(0xFF5543B0),
    warnText: Color(0xFFF2BE6A),
    warnBg: Color(0xFF332A17),
    warnBorder: Color(0xFF6A5525),
    track: Color(0xFF38344F),
    paperRule: Color(0xFF2B2940),
  );

  /// نسخة الإدارة: كحلي السجلات الرسمية مع لمسة ذهبية.
  static const admin = MoeenPalette(
    dark: false,
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
    card: Colors.white,
    cardAlt: Color(0xFFF3F6FA),
    text: Color(0xFF1E2430),
    muted: Color(0xFF586579),
    faint: Color(0xFF8E9AAD),
    hero: Color(0xFF14305A),
    heroAlt: Color(0xFF1F4E8C),
    warnText: Color(0xFF8A5A00),
    warnBg: Color(0xFFFFF6E0),
    warnBorder: Color(0xFFF1D58A),
    track: Color(0xFFDCE4EF),
    paperRule: Color(0xFFE4E9F5),
  );

  /// نسخة الإدارة في الوضع الليلي.
  static const adminDark = MoeenPalette(
    dark: true,
    ink: Color(0xFFBFD4F4),
    primary: Color(0xFF7FA9E3),
    soft: Color(0xFF1F2E46),
    selected: Color(0xFF1C2A40),
    border: Color(0xFF2B3A52),
    outline: Color(0xFF3D506D),
    surface: Color(0xFF0F151F),
    field: Color(0xFF18212F),
    fieldBorder: Color(0xFF34455F),
    imageBackdrop: Color(0xFF151D2A),
    accent: Color(0xFFD4AE55),
    card: Color(0xFF172130),
    cardAlt: Color(0xFF1C2738),
    text: Color(0xFFE8EDF5),
    muted: Color(0xFFA9B6C9),
    faint: Color(0xFF75839A),
    hero: Color(0xFF16345F),
    heroAlt: Color(0xFF235492),
    warnText: Color(0xFFF2BE6A),
    warnBg: Color(0xFF332A17),
    warnBorder: Color(0xFF6A5525),
    track: Color(0xFF2E3D55),
    paperRule: Color(0xFF243247),
  );

  @override
  MoeenPalette copyWith() => this;

  @override
  MoeenPalette lerp(MoeenPalette? other, double t) {
    if (other == null) return this;
    return t < .5 ? this : other;
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
  static const surface = Color(0xFFF3F6FA);
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
  static ThemeData get dark => lightFor(MoeenPalette.teacherDark);

  static ThemeData get adminLight => lightFor(MoeenPalette.admin);
  static ThemeData get adminDark => lightFor(MoeenPalette.adminDark);

  static ThemeData lightFor(MoeenPalette p) {
    // الثيم نفسه للوضعين، والألوان من لوحة النسخة (فاتحة أو داكنة).
    final scheme = ColorScheme.fromSeed(
      seedColor: p.primary,
      brightness: p.dark ? Brightness.dark : Brightness.light,
      primary: p.primary,
      onPrimary: p.dark ? const Color(0xFF15121F) : Colors.white,
      surface: p.card,
      onSurface: p.text,
      onSurfaceVariant: p.muted,
      outline: p.outline,
      outlineVariant: p.border,
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
        titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 18.5, color: p.ink),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.ink,
        titleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 15, color: p.text),
        subtitleTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 12.5, color: p.muted, height: 1.45),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.soft : p.card),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.ink : p.muted),
          side: WidgetStatePropertyAll(BorderSide(color: p.outline)),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: fontFamily, fontSize: 14)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.hero,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary, linearTrackColor: p.border),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : p.faint),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.heroAlt : p.track),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 14.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      dividerColor: p.border,
      dividerTheme: DividerThemeData(color: p.border),
      dialogTheme: DialogThemeData(backgroundColor: p.card, surfaceTintColor: Colors.transparent),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.card, surfaceTintColor: Colors.transparent),
      popupMenuTheme: PopupMenuThemeData(color: p.card, surfaceTintColor: Colors.transparent),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.dark ? const Color(0xFFE8E6F0) : const Color(0xFF2A2340),
        contentTextStyle: TextStyle(fontFamily: fontFamily, color: p.dark ? const Color(0xFF15121F) : Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: p.card,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(18)),
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
          backgroundColor: p.dark ? p.heroAlt : p.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 46),
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          side: BorderSide(color: p.outline),
          minimumSize: const Size(0, 46),
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

}
