/// Русское склонение по числу: plural(1, 'тема', 'темы', 'тем') → «тема», 3 → «темы», 11 → «тем».
String plural(int n, String one, String few, String many) {
  final mod100 = n.abs() % 100;
  final mod10 = mod100 % 10;
  if (mod100 >= 11 && mod100 <= 14) return many;
  if (mod10 == 1) return one;
  if (mod10 >= 2 && mod10 <= 4) return few;
  return many;
}
