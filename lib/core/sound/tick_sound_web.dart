import 'dart:js_interop';

// ربط مباشر بـ Web Audio API لتوليد الصوت دون ملفات صوتية.
@JS('AudioContext')
extension type _AudioContext._(JSObject _) implements JSObject {
  external _AudioContext();
  external double get currentTime;
  external String get state;
  external _AudioNode get destination;
  external JSPromise<JSAny?> resume();
  external _Oscillator createOscillator();
  external _Gain createGain();
}

extension type _AudioNode._(JSObject _) implements JSObject {
  external JSObject connect(_AudioNode destination);
}

extension type _Oscillator._(JSObject _) implements _AudioNode {
  external _Param get frequency;
  external set type(String value);
  external void start(double when);
  external void stop(double when);
}

extension type _Gain._(JSObject _) implements _AudioNode {
  external _Param get gain;
}

extension type _Param._(JSObject _) implements JSObject {
  external void setValueAtTime(double value, double time);
  external void linearRampToValueAtTime(double value, double time);
  external void exponentialRampToValueAtTime(double value, double time);
}

_AudioContext? _ctx;
double _lastTick = 0;

_AudioContext? _context() {
  try {
    final ctx = _ctx ??= _AudioContext();
    if (ctx.state == 'suspended') ctx.resume();
    return ctx;
  } catch (_) {
    return null; // المتصفح لا يدعم الصوت: نكمل بصمت.
  }
}

/// نغمة قصيرة ناعمة: ترتفع طبقتها قليلاً مع ارتفاع القيمة.
void _blip({required double frequency, required double duration, required double volume}) {
  final ctx = _context();
  if (ctx == null) return;
  final t = ctx.currentTime;
  final osc = ctx.createOscillator();
  final gain = ctx.createGain();
  osc.type = 'sine';
  osc.frequency.setValueAtTime(frequency, t);
  gain.gain.setValueAtTime(0.0001, t);
  gain.gain.linearRampToValueAtTime(volume, t + 0.004);
  gain.gain.exponentialRampToValueAtTime(0.0001, t + duration);
  osc.connect(gain);
  gain.connect(ctx.destination);
  osc.start(t);
  osc.stop(t + duration + 0.02);
}

/// تكّة عند كل درجة صحيحة يمر بها المؤشر.
void playTick(double value, {double max = 10}) {
  final ctx = _context();
  if (ctx == null) return;
  // لا أكثر من تكّة كل 30 ملي ثانية عند السحب السريع.
  if (ctx.currentTime - _lastTick < 0.03) return;
  _lastTick = ctx.currentTime;
  final ratio = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
  _blip(frequency: 680 + ratio * 520, duration: 0.045, volume: 0.07);
}

/// نغمة تأكيد مزدوجة خفيفة عند ترك المؤشر (حفظ القيمة).
void playSettle(double value, {double max = 10}) {
  final ratio = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
  final base = 520 + ratio * 380;
  _blip(frequency: base, duration: 0.09, volume: 0.06);
  final ctx = _context();
  if (ctx == null) return;
  final t = ctx.currentTime + 0.07;
  final osc = ctx.createOscillator();
  final gain = ctx.createGain();
  osc.type = 'sine';
  osc.frequency.setValueAtTime(base * 1.5, t);
  gain.gain.setValueAtTime(0.0001, t);
  gain.gain.linearRampToValueAtTime(0.05, t + 0.005);
  gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.12);
  osc.connect(gain);
  gain.connect(ctx.destination);
  osc.start(t);
  osc.stop(t + 0.14);
}
