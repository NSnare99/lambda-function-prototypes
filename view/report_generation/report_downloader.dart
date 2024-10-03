//Specifically downloads the report data which has been generated in memory
import 'dart:convert';

import 'package:base/utilities/requests/api_gateway.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:web_plugins/web_plugins.dart';
import 'dart:io' as io;

//Returns Data URI and other information about PDF in memory without downloading
Future<String> getJSONData({required String fileName}) async {
  String dataURI = '';
  bool responseError = false;
  // download file
  Response response;
  int chunk = 0;
  do {
    chunk++;
    response = await apiGatewayGET(
      server: Uri.parse("$endpoint/file/report"),
      queryParameters: {
        "requestType": "file",
        "requestSource": "storage",
        "fileName": fileName,
        "chunk": "$chunk",
      },
    );
    if (response.statusCode == 200) {
      Map<String, dynamic> body = jsonDecode(response.body);
      dataURI += body['bytes'];
    } else {
      responseError = true;
    }
  } while (responseError != true && jsonDecode(response.body)['next'] == true);

  if (!responseError) {
    // Decode the base64 string to bytes
    Uint8List bytes = base64.decode(dataURI);
    // Convert bytes to string
    String decodedString = utf8.decode(bytes);
    return decodedString;
  } else {
    return "";
  }
}

//Returns Data URI and other information about PDF in memory without downloading
Future<Map<String, String>> getPdfData({required String fileName}) async {
  String dataURI = '';
  String contentType = 'application/octet-stream';
  bool responseError = false;
  // download file
  Response response;
  int chunk = 0;
  do {
    chunk++;
    response = await apiGatewayGET(
      server: Uri.parse("$endpoint/file/pdf"),
      queryParameters: {
        "requestType": "file",
        "requestSource": "storage",
        "fileName": fileName,
        "chunk": "$chunk",
      },
    );
    if (response.statusCode == 200) {
      Map<String, dynamic> body = jsonDecode(response.body);
      dataURI += body['bytes'];
      contentType = body['contentType'];
    } else {
      responseError = true;
    }
  } while (responseError != true && jsonDecode(response.body)['next'] == true);

  if (!responseError) {
    return {"dataURI": dataURI, "contentType": contentType, "fileName": fileName};
  } else {
    return {};
  }
}

Future<void> downloadReportPdfFile({
  required String dataURI,
  required String contentType,
  required String fileName,
}) async {
  if (kIsWeb) {
    await WebPlugins()
        .downloadByteData(dataURI: dataURI, contentType: contentType, fileName: fileName);
  } else {
    String? selectedDirectory =
        await FilePicker.platform.getDirectoryPath(dialogTitle: "Choose Save Location");
    if (selectedDirectory != null) {
      await io.File("$selectedDirectory/$fileName").writeAsBytes(base64Decode(dataURI));
    }
  }
}
