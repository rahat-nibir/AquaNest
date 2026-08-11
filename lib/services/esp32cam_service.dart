import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Reads a raw MJPEG stream (the standard output of ESP32-CAM's
/// CameraWebServer example, typically served at http://<esp32-ip>:81/stream)
/// and emits individual decoded JPEG frames as they arrive.
///
/// This avoids pulling in an unmaintained third-party mjpeg package —
/// MJPEG-over-HTTP is just a multipart stream with each part separated
/// by a boundary marker, which we parse by hand below.
class Esp32CamService {
  http.Client? _client;
  StreamSubscription<List<int>>? _subscription;
  final StreamController<Uint8List> _frameController =
      StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get frames => _frameController.stream;

  bool get isConnected => _subscription != null;

  /// Connects to [streamUrl] (e.g. http://192.168.1.42:81/stream) and
  /// starts pushing decoded JPEG frames into [frames].
  Future<void> connect(String streamUrl) async {
    if (streamUrl.isEmpty) {
      throw Exception('ESP32-CAM stream URL is not configured.');
    }

    await disconnect();

    _client = http.Client();
    final request = http.Request('GET', Uri.parse(streamUrl));
    final response = await _client!.send(request);

    final List<int> buffer = [];
    // JPEG start-of-image / end-of-image markers.
    const jpegStart = [0xFF, 0xD8];
    const jpegEnd = [0xFF, 0xD9];

    _subscription = response.stream.listen((chunk) {
      buffer.addAll(chunk);

      while (true) {
        final startIndex = _indexOfMarker(buffer, jpegStart);
        if (startIndex == -1) break;

        final endIndex =
            _indexOfMarker(buffer, jpegEnd, start: startIndex + 2);
        if (endIndex == -1) break;

        final frame =
            Uint8List.fromList(buffer.sublist(startIndex, endIndex + 2));
        _frameController.add(frame);

        buffer.removeRange(0, endIndex + 2);
      }

      // Prevent unbounded growth if markers are ever malformed.
      if (buffer.length > 2 * 1024 * 1024) {
        buffer.clear();
      }
    }, onError: (e) {
      _frameController.addError(e);
    });
  }

  int _indexOfMarker(List<int> data, List<int> marker, {int start = 0}) {
    for (int i = start; i <= data.length - marker.length; i++) {
      if (data[i] == marker[0] && data[i + 1] == marker[1]) return i;
    }
    return -1;
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
  }

  void dispose() {
    disconnect();
    _frameController.close();
  }
}
