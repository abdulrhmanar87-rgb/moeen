import 'package:flutter/services.dart';

/// على الهاتف: نقرة النظام (الاهتزاز يضيفه الشريط نفسه).
void playTick(double value, {double max = 10}) {
  SystemSound.play(SystemSoundType.click);
}

/// صوت تأكيد عند ترك المؤشر.
void playSettle(double value, {double max = 10}) {}

/// تجهيز الصوت عند أول لمسة (مطلوب في المتصفح فقط).
void primeSound() {}
