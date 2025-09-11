import 'dart:async';
import 'package:universal_html/html.dart' as html;

class VisibilityService {
  final _controller = StreamController<void>.broadcast();
  Stream<void> get onAppHidden => _controller.stream;

  void init() {
    html.document.addEventListener('visibilitychange', (event) {
      if (html.document.visibilityState == 'hidden') {
        _controller.add(null);
      }
    });
  }

  void dispose() {
    _controller.close();
  }
}
