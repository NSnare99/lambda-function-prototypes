import 'dart:convert';
import 'dart:math';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/models/ModelProvider.dart';
import 'package:base/utilities/extensions/string.dart';
import 'package:base/utilities/models/api_gateway_models.dart';
import 'package:base/utilities/requests/api_gateway.dart';
import 'package:base/utilities/requests/graphql.dart';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:rms/view/upload/upload_steps/classes/excel_response.dart';
import 'package:rms/view/upload/upload_steps/logic/string_to_scalar.dart';
import 'package:rms/view/upload/upload_steps/upload_file_step.dart';
import 'package:web_plugins/web_plugins.dart';

Future<void> validateData({
  required BuildContext context,
  required ExcelResponseData excelResponseData,
  required ModelType<Model> model,
  required List<ExcelError> excelErrors,
  required List<InputRow> inputList,
  // required Map<String, List<String>> enums,
  void Function({required int currentProgress})? progressCallback,
}) async {
  Map<String, List<String>> enums = {};

  ExcelSheetData? excelSheetData = excelResponseData.excelSheetData;
  ModelSchema? schema =
      ModelProvider.instance.modelSchemas.firstWhereOrNull((s) => s.name == model.modelName());

  Map<String, ModelField>? fields = schema?.fields;
  List<ModelIndex>? indexes = schema?.indexes;
  if (schema == null || fields == null || indexes == null) {
    excelErrors.add(
      ExcelError(
        sheet: model.modelName().toFirstUpper().splitCamelCase(),
        row: 0,
        col: 0,
        error: "Missing information in the database. Please contact support.",
      ),
    );
    return;
  }

  // Parallel uploading
  List<Future> futures = [];

  for (ModelField enumField
      in fields.values.where((v) => v.type.fieldType == ModelFieldTypeEnum.enumeration)) {
    futures.add(
      gqlQueryEnums(enumTypeName: "${model.modelName()}${enumField.name.toFirstUpper()}Enum").then(
          (value) =>
              enums.addAll({"${model.modelName()}${enumField.name.toFirstUpper()}Enum": value})),
    );
  }
  await Future.wait(futures);

  futures.clear();

  for (var rowCount = 0; rowCount < excelSheetData.rows.length; rowCount++) {
    if (!context.mounted) {
      futures.clear();
      break;
    }
    futures.add(
      _processRow(
        rowData: excelSheetData.rows[rowCount],
        columns: excelSheetData.columns,
        schema: schema,
        model: model,
        excelErrors: excelErrors,
        enums: enums,
      ).then((value) async {
        if (excelErrors.isEmpty && value != null) {
          inputList.add(
            InputRow(
              rowIndex: excelSheetData.rows[rowCount].rowIndex,
              input: value,
            ),
          );
        }
      }),
    );

    if (futures.length >= 1000) {
      await Future.wait(futures);
      if (progressCallback != null) {
        progressCallback(currentProgress: futures.length);
      }
      futures.clear();
    }
  }
  await Future.wait(futures);
  if (progressCallback != null) {
    progressCallback(currentProgress: futures.length);
  }
  futures.clear();
  excelErrors.sort((a, b) {
    if (a.row > b.row) {
      return 1;
    } else if (a.row < b.row) {
      return -1;
    }
    return 0;
  });
}

Future<Map<String, dynamic>?> _processRow({
  required ExcelRowData rowData,
  required ExcelRowData columns,
  required ModelSchema schema,
  required ModelType<Model> model,
  required List<ExcelError> excelErrors,
  required Map<String, List<String>> enums,
}) async {
  String sheetName = model.modelName().splitCamelCase().toFirstUpper();
  // Check if more than one field is filled in
  int maxIndexLength = 1;
  List<ModelIndex>? indexes = schema.indexes;
  if (indexes != null) {
    for (ModelIndex index in indexes) {
      if (maxIndexLength < index.fields.length) {
        maxIndexLength = index.fields.length;
      }
    }
  }
  bool multipleFilledInFilds =
      rowData.cells.where((element) => element.value != "").length > maxIndexLength;
  if (!multipleFilledInFilds) {
    excelErrors.add(
      ExcelError(
        sheet: sheetName,
        row: rowData.rowIndex,
        col: 0,
        error: "More than one value must be filled in.",
        data: rowData.cells
            .map((c) => {c.columnName.split(" ").join().toFirstLower(): c.value})
            .reduce((value, element) => {...value, ...element}),
      ),
    );
    return null;
  }
  // Check for existance based on inexes

  List<String> requiredDiffNames = [
    ...?schema.fields?.values
        .where(
          (v) =>
              v.isRequired &&
              !(schema.indexes
                      ?.map((i) => i.fields)
                      .expand((list) => list)
                      .toList()
                      .contains(v.name) ==
                  true),
        )
        .map((mf) => mf.name.toFirstUpper().splitCamelCase()),
  ].where((rf) => !rowData.cells.map((c) => c.columnName).contains(rf)).toList();
  if (requiredDiffNames.isNotEmpty) {
    excelErrors.add(
      ExcelError(
        sheet: model.modelName(),
        row: rowData.rowIndex,
        col: 0,
        error: "Missing Required Values: ${requiredDiffNames.join(", ")}",
        advancedError: "Missing Required Values:\n${requiredDiffNames.join("\n")}",
        data: rowData.cells
            .map((c) => {c.columnName.split(" ").join().toFirstLower(): c.value})
            .reduce((value, element) => {...value, ...element}),
      ),
    );
    return null;
  }
  List<ModelIndex>? schemaIndexes = schema.indexes;
  if (schemaIndexes != null) {
    List<String> indexes =
        schemaIndexes.map((index) => index.fields).toList().expand((e) => e).toList();
    List<String> inputs = [];
    for (String fieldName in indexes) {
      String rowValue =
          rowData.cells.firstWhereOrNull((c) => c.columnName == fieldName)?.columnName ?? "";
      if (rowValue != "") {
        inputs.add("$fieldName: $rowValue");
      }
    }
    if (inputs.isNotEmpty) {
      String input = inputs.join(" ,");
      String query = '''
                query GetItem {
                  get${schema.name} ($input) {
                    id
                  }
                }
              ''';
      Response response = await gqlQuery(
        query,
      );
      Map responseBody = jsonDecode(response.body) is Map ? jsonDecode(response.body) as Map : {};
      if (response.statusCode != 200 || responseBody['data'] == null) {
        // retries
        for (var i = 0; i < 2; i++) {
          await Future.delayed(Duration(milliseconds: Random().nextInt(300) + 1000));
          response = await gqlQuery(
            query,
          );
          responseBody = jsonDecode(response.body) is Map ? jsonDecode(response.body) as Map : {};
          if (response.statusCode == 200 && responseBody['data']?["get${schema.name}"] != null) {
            break;
          }
        }
        if (response.statusCode != 200 || responseBody['data'] == null) {
          excelErrors.add(
            ExcelError(
              sheet: sheetName,
              row: rowData.rowIndex,
              col: 0,
              error: "An error occured when looking for item.",
              data: rowData.cells
                  .map((c) => {c.columnName.split(" ").join().toFirstLower(): c.value})
                  .reduce((value, element) => {...value, ...element}),
            ),
          );
          return null;
        }
      }
    }
  } else {
    excelErrors.add(
      ExcelError(
        sheet: sheetName,
        row: rowData.rowIndex,
        col: 0,
        error: "No unique identifier found!",
        data: rowData.cells
            .map((c) => {c.columnName.split(" ").join().toFirstLower(): c.value})
            .reduce((value, element) => {...value, ...element}),
      ),
    );
    return null;
  }

  // Validate cells
  Map<String, dynamic>? validatedInput = await _validateCells(
    rowData: rowData,
    columns: columns,
    schema: schema,
    excelErrors: excelErrors,
    model: model,
    enums: enums,
  );
  validatedInput?.removeWhere((key, value) => value == null || value == "");
  return validatedInput;
}

Future<Map<String, dynamic>?> _validateCells({
  required ExcelRowData rowData,
  required ExcelRowData columns,
  required ModelSchema schema,
  required ModelType<Model> model,
  required List<ExcelError> excelErrors,
  required Map<String, List<String>> enums,
}) async {
  Map<String, dynamic> modelJsonObject = {};
  Map<String, ModelField>? fields =
      schema.fields?.map((key, value) => MapEntry(key.toLowerCase(), value));
  for (var cellCount = 0; cellCount < rowData.cells.length; cellCount++) {
    ExcelCellData cell = rowData.cells[cellCount];
    ModelField? field = fields?[cell.columnName.replaceAll(RegExp(r'\s+'), '').toLowerCase()];
    String columnName = field?.name ?? "";
    ModelFieldTypeEnum? fieldType = field?.type.fieldType;
    int cellIndex = rowData.cells.indexWhere(
      (cell) =>
          cell.columnName.replaceAll(RegExp(r'\s+'), '').toLowerCase() == columnName.toLowerCase(),
    );
    if (field != null && fieldType != null && cellIndex != -1) {
      ExcelCellData cellValue = rowData.cells[cellIndex];
      try {
        var processedValue = await processValue(
          fieldTypeEnum: fieldType,
          field: field,
          value: cellValue.value,
          columnName: columnName,
          model: model,
          collectionType: fieldType == ModelFieldTypeEnum.collection
              ? enumFromString<ModelFieldTypeEnum>(
                  field.type.ofModelName,
                  ModelFieldTypeEnum.values,
                )
              : null,
          enums: enums,
        );
        if (processedValue != null) {
          modelJsonObject[columnName] = processedValue;
        }
      } catch (e) {
        excelErrors.add(
          ExcelError(
            sheet: model.modelName(),
            row: rowData.rowIndex,
            col: columns.cells
                    .map((c) => c.columnName)
                    .toList()
                    .indexOf(rowData.cells[cellCount].columnName) +
                1,
            error: e.toString(),
            data: rowData.cells
                .map((c) => {c.columnName.split(" ").join().toFirstLower(): c.value})
                .reduce((value, element) => {...value, ...element}),
          ),
        );
        return null;
      }
    }
  }
  return modelJsonObject;
}

Future<void> downloadExcelFromMemory({
  required ModelType<Model> model,
  required ExcelRowData columns,
  required List<ExcelRowData> rows,
  required String fileName,
}) async {
  // get model and schema information
  ModelSchema? schema =
      ModelProvider.instance.modelSchemas.firstWhereOrNull((s) => s.name == model.modelName());
  Map<String, ModelField>? fields = schema?.fields;
  if (schema == null || fields == null) return;

  int chunkLength =
      (rows.map((e) => e.cells.map((c) => c.toString()).toList().toString()).join().length /
              (2 * 1024 * 1024))
          .ceil();
  await apiGatewayPOST(
    server: Uri.parse("$endpoint/excel"),
    payload: ExcelFileData(
      fileName: fileName,
      sheets: [
        ExcelSheetData(
          sheetName: model.modelName(),
          columns: columns,
          rows: rows.slice(
            0,
            (rows.length / chunkLength).ceil() > rows.length
                ? rows.length
                : (1 * (rows.length / chunkLength)).ceil(),
          ),
        ),
      ],
    ).toJson(),
  );
  for (var i = 1; i < chunkLength; i++) {
    await apiGatewayPUT(
      server: Uri.parse("$endpoint/excel"),
      payload: ExcelFileData(
        fileName: fileName,
        sheets: [
          ExcelSheetData(
            sheetName: model.modelName(),
            columns: columns,
            rows: rows.slice(
              (i * (rows.length / chunkLength)).ceil(),
              ((i + 1) * (rows.length / chunkLength)).ceil() > rows.length
                  ? rows.length
                  : ((i + 1) * (rows.length / chunkLength)).ceil(),
            ),
          ),
        ],
      ).toJson(),
    );
  }
  await downloadTempExcelFile(fileName: fileName);
}

Future<void> downloadTempExcelFile({required String fileName}) async {
  BytesBuilder bytesBuilder = BytesBuilder(); // Use BytesBuilder to accumulate data
  String contentType = 'application/octet-stream';
  bool responseError = false;
  Response response;
  int chunk = 0;

  do {
    chunk++;
    response = await apiGatewayGET(
      server: Uri.parse("$endpoint/file/excel"),
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
