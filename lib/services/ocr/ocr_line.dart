/// سطر نصي ناتج عن قراءة الصورة، مع درجة الثقة (0-100، أو -1 إذا كانت غير متوفرة).
class OcrLine {
  const OcrLine(this.text, [this.confidence = -1]);
  final String text;
  final double confidence;
}
