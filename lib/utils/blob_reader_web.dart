import 'dart:typed_data';
import 'dart:html' as html;

Future<Uint8List?> readBlobUrlBytesImpl(String url) async {
  final request = await html.HttpRequest.request(
    url,
    responseType: 'arraybuffer',
  );
  final response = request.response;
  if (response is ByteBuffer) {
    return Uint8List.view(response);
  }
  return null;
}