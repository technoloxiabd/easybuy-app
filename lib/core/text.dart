/// Product names in Title Case (owner, 29 Sep 2026): "cross-border wooden
/// wall clock for living room" reads "Cross-Border Wooden Wall Clock for
/// Living Room".
///
/// The supplier's titles arrive machine-translated and mostly lower case.
/// Only first letters are raised; nothing is lowered, so "USB", "LED",
/// "iPhone" and "3D" stay as written. Short joining words stay small unless
/// they start or end the name. Bengali has no case and passes through.
String titleCase(String text) {
  final words = text.split(' ');
  final last = words.lastIndexWhere((w) => w.isNotEmpty);
  var first = true;
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    if (w.isEmpty) continue;
    final edge = first || i == last;
    words[i] = w.split('-').map((part) => _capital(part, small: !edge)).join('-');
    first = false;
  }
  return words.join(' ');
}

const _small = {'a', 'an', 'and', 'as', 'at', 'but', 'by', 'for', 'from', 'in', 'into', 'nor', 'of', 'on', 'or', 'per', 'the', 'to', 'vs', 'via', 'with'};

final _letter = RegExp(r'\p{L}', unicode: true);
final _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);
final _upperAfterFirst = RegExp(r'^.+\p{Lu}', unicode: true);

String _capital(String word, {required bool small}) {
  if (word.isEmpty) return word;
  if (small && _small.contains(word)) return word;
  // "iPhone", "eBay": a capital already inside the word was meant.
  if (_upperAfterFirst.hasMatch(word)) return word;
  // The first letter, after any bracket or quote: "(new)" -> "(New)". A
  // word led by a digit is left alone, so "10pcs" does not become "10Pcs".
  final at = word.indexOf(_letterOrDigit);
  if (at < 0 || !_letter.hasMatch(word[at])) return word;
  return word.substring(0, at) + word[at].toUpperCase() + word.substring(at + 1);
}
