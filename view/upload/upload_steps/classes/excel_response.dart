import 'package:base/utilities/models/api_gateway_models.dart';

class ExcelResponseData {
  final int lastRowProcessed;
  final ExcelSheetData excelSheetData;

  ExcelResponseData({
    required this.excelSheetData,
    required this.lastRowProcessed,
  });
}
