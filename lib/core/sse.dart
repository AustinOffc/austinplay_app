import 'dart:convert';
import 'package:dio/dio.dart';

/// Satu event Server-Sent Events.
class SseEvent {
  const SseEvent(this.event, this.data);
  final String event;
  final String data;
}

/// Membuka aliran SSE lewat Dio (header Authorization tetap dikirim interceptor).
/// Melempar [DioException] bila gagal terhubung (status bukan 200) atau terputus.
/// Stream berakhir normal bila server menutup koneksi.
Stream<SseEvent> openSse(
  Dio dio,
  String path, {
  Map<String, dynamic>? query,
  CancelToken? cancel,
  bool soft401 = false,
}) async* {
  final res = await dio.get<ResponseBody>(
    path,
    queryParameters: query,
    cancelToken: cancel,
    options: Options(
      responseType: ResponseType.stream,
      receiveTimeout: const Duration(seconds: 70),
      headers: {'Accept': 'text/event-stream', 'Cache-Control': 'no-cache'},
      extra: {'soft401': soft401},
    ),
  );
  final body = res.data;
  if (body == null) return;

  var event = 'message';
  final data = StringBuffer();
  final lines =
      body.stream.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter());
  await for (final line in lines) {
    if (line.isEmpty) {
      if (data.isNotEmpty) yield SseEvent(event, data.toString());
      event = 'message';
      data.clear();
      continue;
    }
    if (line.startsWith(':')) continue;
    final i = line.indexOf(':');
    final field = i < 0 ? line : line.substring(0, i);
    var value = i < 0 ? '' : line.substring(i + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    if (field == 'event') {
      event = value;
    } else if (field == 'data') {
      if (data.isNotEmpty) data.write('\n');
      data.write(value);
    }
  }
}
