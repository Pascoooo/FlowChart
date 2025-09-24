class VisibilityChangeRateLimitException implements Exception {
  final Duration remaining;
  VisibilityChangeRateLimitException(this.remaining);
  @override
  String toString() => 'VisibilityChangeRateLimitException: remaining ${remaining.inMinutes} minuti';
}
