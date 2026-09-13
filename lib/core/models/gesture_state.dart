enum GestureState { idle, moving, tap, longPress, swipe, scroll }

class GesturePoint {
  const GesturePoint({required this.x, required this.y, this.timestamp});

  final double x;
  final double y;
  final DateTime? timestamp;

  GesturePoint lerp(GesturePoint other, double amount) => GesturePoint(
    x: x + (other.x - x) * amount,
    y: y + (other.y - y) * amount,
    timestamp: other.timestamp,
  );
}
