class ArabicSort {
  static const _order = 'ابتثجحخدذرزسشصضطظعغفقكلمنهوي';

  static String normalize(String value) {
    var s = value.trim().toLowerCase();
    const replacements = {
      'أ': 'ا',
      'إ': 'ا',
      'آ': 'ا',
      'ٱ': 'ا',
      'ى': 'ي',
      'ة': 'ه',
      'ؤ': 'و',
      'ئ': 'ي',
    };
    for (final entry in replacements.entries) {
      s = s.replaceAll(entry.key, entry.value);
    }
    // إزالة التشكيل وعلامات المدّ.
    s = s.replaceAll(RegExp(r'[\u064B-\u065F\u0670ـ]'), '');
    return s;
  }

  static int compare(String a, String b) {
    final aa = normalize(a);
    final bb = normalize(b);
    final length = aa.length < bb.length ? aa.length : bb.length;

    for (var i = 0; i < length; i++) {
      final ca = aa[i];
      final cb = bb[i];
      if (ca == cb) continue;

      final ia = _order.indexOf(ca);
      final ib = _order.indexOf(cb);

      if (ia != -1 && ib != -1) return ia.compareTo(ib);
      if (ia != -1) return -1;
      if (ib != -1) return 1;
      final result = ca.compareTo(cb);
      if (result != 0) return result;
    }

    return aa.length.compareTo(bb.length);
  }
}
