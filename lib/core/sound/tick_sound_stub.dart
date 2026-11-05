import 'package:flutter/services.dart';

/// على الهاتف: نقرة النظام مع اهتزاز خفيف.
void playTick(double value, {double max = 10}) {
  SystemSound.play(SystemSoundType.click);
  HapticFeedback.selectionClick();
}

/// صوت تأكيد عند ترك المؤشر.
void playSettle(double value, {double max = 10}) {
  HapticFeedback.lightImpact();
}
