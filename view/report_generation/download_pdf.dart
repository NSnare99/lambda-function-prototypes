import 'dart:io' as io;
import 'dart:convert';
import 'dart:typed_data';

import 'package:base/utilities/models/reports_classes.dart';
import 'package:base/utilities/requests/api_gateway.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:web_plugins/web_plugins.dart';

Future<void> downloadPdfFile({required String fileName}) async {
  BytesBuilder bytesBuilder = BytesBuilder(); // Use BytesBuilder to accumulate data
  String contentType = 'application/octet-stream';
  bool responseError = false;
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
      bytesBuilder.add(base64Decode(body['bytes'])); // Add decoded bytes to the builder
      contentType = body['contentType'];
    } else {
      responseError = true;
    }
  } while (responseError != true && jsonDecode(response.body)['next'] == true);

  if (!responseError) {
    Uint8List dataUint8List = bytesBuilder.toBytes(); // Convert accumulated bytes to Uint8List

    if (kIsWeb) {
      await WebPlugins().downloadByteData(
        dataURI: base64Encode(dataUint8List), // Convert to Base64 string if necessary
        contentType: contentType,
        fileName: fileName,
      );
    } else {
      String? selectedDirectory =
          await FilePicker.platform.getDirectoryPath(dialogTitle: "Choose Save Location");
      if (selectedDirectory != null) {
        await io.File("$selectedDirectory/$fileName").writeAsBytes(dataUint8List);
      }
    }
  }
}

/* 
Given template variable names and their substitutions, make a list of replacements to be used in a ReplacementsPayload
Note: assumes all data is a String
 */

List<Replacement> generateReplacements(Map<String, String> inputMap) {
  List<Replacement> output = [];
  inputMap.forEach((key, value) {
    output.add(
      Replacement(
        keyword: key,
        data: value,
        type: "string",
      ),
    );
  });

  return output;
}
