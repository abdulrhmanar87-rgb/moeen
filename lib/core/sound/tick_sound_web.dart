import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

// أصوات شريط التقدير عبر Web Audio API دون ملفات صوتية:
// - «تكّة» ميكانيكية قصيرة جداً (ضجيج مُرشَّح يخفت خلال 12 ملي ثانية)
//   تشبه عجلة الاختيار في iOS، بدل النغمة الحادة.
// - «نقرة» تأكيد ناعمة عند الترك، تهبط طبقتها قليلاً.
@JS('AudioContext')
extension type _Ctx._(JSObject _) implements JSObject {
  external _Ctx();
  external double get currentTime;
  external double get sampleRate;
  external String get state;
  external _Node get destination;
  external JSPromise<JSAny?> resume();
  external _Osc createOscillator();
  external _Gain createGain();
  external _Filter createBiquadFilter();
  external _Buffer createBuffer(int channels, int length, double sampleRate);
  external _Source createBufferSource();
}

extension type _Node._(JSObject _) implements JSObject {
  external JSObject connect(_Node destination);
}

extension type _Osc._(JSObject _) implements _Node {
  external _Param get frequency;
  external set type(String value);
  external void start(double when);
  external void stop(double when);
}

extension type _Gain._(JSObject _) implements _Node {
  external _Param get gain;
}

extension type _Filter._(JSObject _) implements _Node {
  external set type(String value);
  external _Param get frequency;
  external _Param get Q;
}

extension type _Buffer._(JSObject _) implements JSObject {
  external void copyToChannel(JSFloat32Array source, int channel);
}

extension type _Source._(JSObject _) implements _Node {
  external set buffer(_Buffer value);
  external _Param get playbackRate;
  external void start(double when);
}

extension type _Param._(JSObject _) implements JSObject {
  external void setValueAtTime(double value, double time);
  external void linearRampToValueAtTime(double value, double time);
  external void exponentialRampToValueAtTime(double value, double time);
}

_Ctx? _ctx;
_Buffer? _click;
double _lastTick = -1;

_Ctx? _context() {
  try {
    final ctx = _ctx ??= _Ctx();
    if (ctx.state != 'running') ctx.resume();
    return ctx;
  } catch (_) {
    return null; // لا صوت في هذا المتصفح: نكمل بصمت.
  }
}

/// يُستدعى عند لمس الشريط: سفاري لا يسمح بالصوت إلا بعد لمسة من المستخدم.
void primeSound() => _context();

_Buffer? _clickBuffer(_Ctx ctx) {
  if (_click != null) return _click;
  final rate = ctx.sampleRate;
  final length = (rate * 0.014).round();
  final buf = ctx.createBuffer(1, length, rate);
  final data = Float32List(length);
  final rnd = math.Random(7);
  for (var i = 0; i < length; i++) {
    final env = math.exp(-i / (rate * 0.0018)); // يخفت بسرعة كبيرة
    data[i] = (rnd.nextDouble() * 2 - 1) * env;
  }
  // نسخ صريح: يعمل مع dart2js و wasm معاً.
  buf.copyToChannel(data.toJS, 0);
  return _click = buf;
}

/// تكّة عند كل درجة صحيحة يمر بها المؤشر؛ طبقتها ترتفع قليلاً مع الدرجة.
void playTick(double value, {double max = 10}) {
  final ctx = _context();
  if (ctx == null) return;
  final t = ctx.currentTime;
  if (t - _lastTick < 0.025) return; // سحب سريع جداً: لا نكدّس التكّات
  _lastTick = t;
  final buf = _clickBuffer(ctx);
  if (buf == null) return;
  final ratio = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);

  final src = ctx.createBufferSource()..buffer = buf;
  final filter = ctx.createBiquadFilter()..type = 'bandpass';
  filter.frequency.setValueAtTime(2600 + ratio * 1400, t);
  filter.Q.setValueAtTime(1.4, t);
  final gain = ctx.createGain();
  gain.gain.setValueAtTime(0.55, t);
  src.connect(filter);
  filter.connect(gain);
  gain.connect(ctx.destination);
  src.start(t);
}

/// نقرة تأكيد ناعمة عند ترك المؤشر (حُفظت الدرجة).
void playSettle(double value, {double max = 10}) {
  final ctx = _context();
  if (ctx == null) return;
  final t = ctx.currentTime + 0.01;
  final ratio = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
  final f = 700 + ratio * 260;
  final osc = ctx.createOscillator()..type = 'sine';
  osc.frequency.setValueAtTime(f, t);
  osc.frequency.exponentialRampToValueAtTime(f * 0.72, t + 0.07);
  final gain = ctx.createGain();
  gain.gain.setValueAtTime(0.0001, t);
  gain.gain.linearRampToValueAtTime(0.09, t + 0.006);
  gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.11);
  osc.connect(gain);
  gain.connect(ctx.destination);
  osc.start(t);
  osc.stop(t + 0.13);
}
