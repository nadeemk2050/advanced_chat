import 'dart:typed_data';

import 'blob_reader_stub.dart'
    if (dart.library.html) 'blob_reader_web.dart';

Future<Uint8List?> readBlobUrlBytes(String url) {
  return readBlobUrlBytesImpl(url);
}