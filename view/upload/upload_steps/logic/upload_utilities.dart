import 'dart:convert';

import 'package:base/utilities/models/api_gateway_models.dart';
import 'package:base/utilities/requests/api_gateway.dart';
import 'package:http/http.dart';
import 'package:rms/view/upload/upload_steps/classes/excel_response.dart';

Future<ExcelResponseData?> getExcelResponseSegment({
  required String fileName,
  required String sheetName,
  required int batchStartRow,
  int columnRow = 1,
}) async {
  Response response = await apiGatewayGET(
    server: Uri.parse("$endpoint/excel"),
    queryParameters: {
      "fileName": fileName,
      "action": "processSheet",
      "sheetName": sheetName,
      "columnRow": columnRow.toString(),
      "batchStartRow": batchStartRow.toString(),
    },
  );

  if (response.statusCode == 200) {
    return ExcelResponseData(
      lastRowProcessed: jsonDecode(response.body)['LastProcessedRow'],
      excelSheetData: ExcelSheetData.fromJson(jsonDecode(response.body)['Data']),
    );
  } else {
    return null;
  }
}
