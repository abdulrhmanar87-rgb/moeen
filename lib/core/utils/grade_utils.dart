class GradeUtils {
  static double rawRound(double value) => value.floorToDouble() +
      ((value - value.floor()) >= 0.5 ? 1 : 0);

  static int roundFinal(double value) => rawRound(value).toInt();

  static double clamp(double value, double min, double max) =>
      value.clamp(min, max).toDouble();
}
