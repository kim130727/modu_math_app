String sanitizeTutorText(String text) {
  return text.replaceAll('**', '').replaceAll(RegExp(r'\s+\n'), '\n').trim();
}
