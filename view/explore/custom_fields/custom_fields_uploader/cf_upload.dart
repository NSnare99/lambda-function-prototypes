import 'dart:convert';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/models/ModelProvider.dart';
import 'package:base/utilities/extensions/string.dart';
import 'package:base/utilities/files/file_upload_page.dart';
import 'package:base/utilities/models/api_gateway_models.dart';
import 'package:base/utilities/requests/api_gateway.dart';
import 'package:base/utilities/requests/graphql.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:rms/view/explore/custom_fields/custom_fields_uploader/cf_loader.dart';
import 'package:rms/view/upload/upload_steps/classes/excel_response.dart';
import 'package:rms/view/upload/upload_steps/logic/upload_utilities.dart';
import 'package:path/path.dart' as path;

class CustomFieldsUpload extends StatefulWidget {
  final ModelType<Model> model;
  final String? filter;
  final void Function() completeStep;
  final List<ExcelError> errors;
  final List<ExcelError> uploadErrors;
  final User? selectedUser;
  final List<ExcelCellData> columnCells;
  const CustomFieldsUpload({
    super.key,
    required this.completeStep,
    required this.errors,
    required this.model,
    required this.filter,
    required this.selectedUser,
    required this.columnCells,
    required this.uploadErrors,
  });

  @override
  State<CustomFieldsUpload> createState() => _CustomFieldsUploadState();
}

class _CustomFieldsUploadState extends State<CustomFieldsUpload> {
  bool isLoading = false;
  String status = "";
  int processed = 0;
  bool criticalError = false;

  Future<void> validateOrUploadCustomFieldsLoaderFile({
    required List<Map<String, dynamic>> fileUploadList,
    required List<TableField> tableFields,
    bool upload = false,
  }) async {
    if (upload) widget.errors.clear();
    // get the vales from the xlsx file
    setState(() {
      isLoading = true;
      status = "${upload ? "uploading" : "processing"} file";
    });
    if (fileUploadList.length > 1) {
      ExcelError error = ExcelError(
        sheet: widget.model.modelName(),
        row: 0,
        col: 0,
        error: "Multiple Files found. Please upload only one",
      );
      if (upload) {
        widget.uploadErrors.add(error);
      } else {
        widget.errors.add(error);
      }
      return;
    }
    Response responseJsonFileInfo = await apiGatewayGET(
      server: Uri.parse("$endpoint/excel"),
      queryParameters: {"fileName": fileUploadList.last['name'], "action": "fileInfo"},
    );
    var jsonResponse = jsonDecode(responseJsonFileInfo.body);
    if (jsonResponse is List<dynamic> && jsonResponse.isEmpty) {
      ExcelError error =
          ExcelError(sheet: widget.model.modelName(), row: 0, col: 0, error: "No data found!");
      if (upload) {
        widget.uploadErrors.add(error);
      } else {
        widget.errors.add(error);
      }
      setState(() {
        processed = 0;
        criticalError = true;
        status = "Error: No data found!";
      });
      return;
    }
    // loop through file info
    if (jsonResponse is List) {
      if (jsonResponse.length > 1) {
        ExcelError error = ExcelError(
          sheet: jsonResponse[0]['sheetName'].toString(),
          row: 0,
          col: 0,
          error: "${jsonResponse.length} sheets found when looking for one sheet per upload",
        );
        if (upload) {
          widget.uploadErrors.add(error);
        } else {
          widget.errors.add(error);
        }
        setState(() {
          processed = 0;
          criticalError = true;
          status = "Error: More than one sheet found!";
        });
      }
      // define the schema and loop through the sheets
      ModelSchema? schema = ModelProvider.instance.modelSchemas
          .firstWhereOrNull((ms) => ms.name == widget.model.modelName());
      for (var sheetCount = 0; sheetCount < jsonResponse.length; sheetCount++) {
        if (criticalError || schema == null) {
          return;
        }
        // get the excel data by segments
        ExcelResponseData? excelResponseData = await getExcelResponseSegment(
          fileName: fileUploadList.last['name'],
          sheetName: jsonResponse[sheetCount]['sheetName'].toString(),
          batchStartRow: 1,
        );
        if (widget.columnCells.isEmpty) {
          widget.columnCells.addAll(excelResponseData?.excelSheetData.columns.cells ?? []);
        }

        String? firstIndex = schema.indexes?.first.fields.first;
        List<Future> futures = [];
        // loop through each row of the excel
        for (ExcelRowData rowData in excelResponseData?.excelSheetData.rows ?? []) {
          if (futures.length > 300) {
            setState(() {
              processed += 300;
              status = "${upload ? "uploading" : "processing"} file (processed: $processed)";
            });
            await Future.wait(futures);
            futures.clear();
          }
          await _validateOrUploadRow(
            columnCells: excelResponseData?.excelSheetData.columns.cells ?? [],
            tableFields: tableFields,
            rowData: rowData,
            firstIndex: firstIndex,
            futures: futures,
            errors: widget.errors,
            uploadErrors: widget.uploadErrors,
            model: widget.model,
            upload: upload,
          );
        }
        if (excelResponseData != null) {
          while (excelResponseData != null &&
              !criticalError &&
              excelResponseData.lastRowProcessed < jsonResponse[sheetCount]['rowCount'] - 1) {
            excelResponseData = await getExcelResponseSegment(
              fileName: fileUploadList.last['name'],
              sheetName: jsonResponse[sheetCount]['sheetName'].toString(),
              batchStartRow: excelResponseData.lastRowProcessed + 1,
            );
            for (ExcelRowData rowData in excelResponseData?.excelSheetData.rows ?? []) {
              if (futures.length > 300) {
                await Future.wait(futures);
                futures.clear();
              }
              await _validateOrUploadRow(
                columnCells: excelResponseData?.excelSheetData.columns.cells ?? [],
                tableFields: tableFields,
                rowData: rowData,
                firstIndex: firstIndex,
                futures: futures,
                errors: widget.errors,
                uploadErrors: widget.uploadErrors,
                model: widget.model,
                upload: upload,
              );
            }
          }
        }
        await Future.wait(futures);
        futures.clear();
      }
    }
    if (mounted) {
      setState(() {
        status = "";
        isLoading = false;
      });
    }
  }

  Future<void> _validateOrUploadRow({
    required List<ExcelCellData> columnCells,
    required ExcelRowData rowData,
    required List<Future<dynamic>> futures,
    required List<ExcelError> errors,
    required List<ExcelError> uploadErrors,
    required ModelType<Model> model,
    required List<TableField> tableFields,
    bool upload = false,
    String? firstIndex,
  }) async {
    if (firstIndex != null) {
      String? firstIndexCellValue = rowData.cells
          .firstWhereOrNull(
            (c) => c.columnName == firstIndex.toFirstUpper().splitCamelCase(),
          )
          ?.value;
      String query = '''
      query _ {
        get${model.modelName()}($firstIndex: "$firstIndexCellValue") {
          $firstIndex
          customFields
          _version
        }
      }''';
      futures.add(
        gqlQuery(gqlMinQueryString(query)).then(
          (response) async {
            var data = jsonDecode(response.body);
            data = data['data'] is Map ? data['data'] : null;
            data = data['get${model.modelName()}'] is Map ? data['get${model.modelName()}'] : null;
            if (response.statusCode == 200 && data != null) {
              List<String> errorMessage = [];
              int firstColumnErrorIndex = 0;
              if (upload) {
                // build the rowData's customFields object
                Map<String, dynamic> customField = {};
                List<String> tableFieldNames = tableFields
                    .map(
                      (tf) => tf.fieldName
                          ?.split(RegExp(r"\s+"))
                          .map((s) => s.toFirstUpper())
                          .join()
                          .toFirstUpper()
                          .splitCamelCase(),
                    )
                    .whereNotNull()
                    .toList();
                for (ExcelCellData cell in rowData.cells) {
                  if (tableFieldNames.contains(
                    cell.columnName,
                  )) {
                    TableField? currentTableField = tableFields.firstWhereOrNull(
                      (tf) => tf.fieldName?.toLowerCase() == cell.columnName.toLowerCase(),
                    );
                    if (currentTableField != null) {
                      customField[currentTableField.id] = {
                        widget.selectedUser?.id: cell.value,
                      };
                    }
                  }
                }
                // Integrate with the current customFields object or create a new one
                if (widget.selectedUser != null &&
                    data is Map &&
                    data.containsKey('customFields') &&
                    data['customFields'] is Map) {
                  Map<String, dynamic> dataCustomFields =
                      Map<String, dynamic>.from(jsonDecode(data['customFields']));

                  // Extract nested keys that match the selectedUserId
                  Map<String, Map<String, String>> dataCustomFieldsAdvisorOnly = Map.fromEntries(
                    dataCustomFields.entries.where((entry) {
                      var innerMap = entry.value as Map<String, dynamic>;
                      return innerMap.containsKey(widget.selectedUser?.id);
                    }).map((entry) {
                      var innerMap = entry.value as Map<String, dynamic>;
                      return MapEntry(
                        entry.key,
                        {widget.selectedUser?.id ?? "": innerMap[widget.selectedUser?.id]},
                      );
                    }),
                  );

                  // Sort entries for comparison
                  List<MapEntry<String, dynamic>> entries1 = customField.entries.toList()
                    ..sort((e1, e2) => e1.key.compareTo(e2.key));
                  List<MapEntry<String, Map<String, String>>> entries2 =
                      dataCustomFieldsAdvisorOnly.entries.toList()
                        ..sort((e1, e2) => e1.key.compareTo(e2.key));

                  // Check if lists match
                  bool listsMatch = entries1.length == entries2.length &&
                      List.generate(entries1.length, (i) => entries1[i] == entries2[i])
                          .every((e) => e);

                  if (!listsMatch && widget.selectedUser != null) {
                    // Adding or updating
                    customField.forEach((cfKey, cfValue) {
                      if (!dataCustomFields.containsKey(cfKey)) {
                        dataCustomFields[cfKey] = cfValue;
                      } else {
                        (dataCustomFields[cfKey]
                                as Map<String, dynamic>)[widget.selectedUser?.id ?? ""] =
                            (cfValue as Map<String, dynamic>)[widget.selectedUser?.id];
                      }
                    });

                    // Cleanup
                    dataCustomFields.removeWhere((dcfKey, dcfValue) {
                      if (!customField.containsKey(dcfKey)) {
                        (dcfValue as Map).remove(widget.selectedUser?.id);
                      }
                      return (dcfValue as Map).isEmpty;
                    });

                    // Update the data object with the new combined customFields
                    data['customFields'] = jsonEncode(dataCustomFields);
                    await gqlMutation(
                      input: Map<String, dynamic>.from(data),
                      model: model,
                      mutationType: GraphQLMutationType.update,
                    );
                  }
                } else {
                  data['customFields'] = jsonEncode(customField);
                  await gqlMutation(
                    input: Map<String, dynamic>.from(data),
                    model: model,
                    mutationType: GraphQLMutationType.update,
                  );
                }
              } else {
                List<String?> tableFieldNames = tableFields
                    .map(
                      (tf) => tf.fieldName
                          ?.split(RegExp(r"\s+"))
                          .map((s) => s.toFirstUpper())
                          .join()
                          .toFirstUpper()
                          .splitCamelCase()
                          .toLowerCase(),
                    )
                    .toList()
                  ..removeWhere((tfn) => tfn == null);
                for (var cell in rowData.cells) {
                  String cellName = cell.columnName
                      .split(RegExp(r"\s+"))
                      .map((s) => s.toFirstUpper())
                      .join()
                      .toFirstUpper()
                      .splitCamelCase()
                      .toLowerCase();
                  for (int i = 0; i < tableFieldNames.length; i++) {
                    if (cellName == tableFieldNames[i]) {
                      TableField? foundTableField = tableFields[i];
                      if (foundTableField.fieldType == TableFieldFieldTypeEnum.SingleSelect &&
                          ![...?foundTableField.Options?.map((o) => o.labelText?.toLowerCase())]
                              .contains(cell.value.toLowerCase())) {
                        if (firstColumnErrorIndex == 0) {
                          firstColumnErrorIndex = columnCells
                              .map((c) => c.columnName.toLowerCase())
                              .toList()
                              .indexOf(cellName.toLowerCase());
                        }
                        errorMessage.add(
                          "${cellName.split(RegExp(r"\s+")).map((s) => s.toFirstUpper()).join().toFirstUpper().splitCamelCase()}: ${cell.value}",
                        );
                      }
                    }
                  }
                }
              }
              if (errorMessage.isNotEmpty) {
                ExcelError error = ExcelError(
                  sheet: model.modelName(),
                  row: rowData.rowIndex,
                  col: firstColumnErrorIndex + 1,
                  error:
                      "Option${errorMessage.length > 1 ? "s" : ""} not found: ${errorMessage.first}${errorMessage.length > 1 ? ", ..." : ""}",
                  data: {for (var c in rowData.cells) c.columnName: c.value},
                  advancedError:
                      "Option${errorMessage.length > 1 ? "s" : ""} not found:\n\n${errorMessage.join(",\n")}",
                );
                if (upload) {
                  widget.uploadErrors.add(error);
                } else {
                  widget.errors.add(error);
                }
              }
            } else {
              ExcelError error = ExcelError(
                sheet: model.modelName(),
                row: rowData.rowIndex,
                col: 0,
                error: "Row item not found!",
                data: {for (var c in rowData.cells) c.columnName: c.value},
                advancedError: data is Map ? data['error'] : null,
              );
              if (upload) {
                widget.uploadErrors.add(error);
              } else {
                widget.errors.add(error);
              }
            }
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: FileUploadPage(
              clearHistoryOnReUpload: true,
              allowedExtensions: const ["xlsx, xls"],
              endpoint: endpoint,
              endpointPath: "/excel",
              onPreUpload: ({List<Map<String, dynamic>>? fileUploadList}) async {
                setState(() {
                  status = "uploading files";
                });
                if (widget.errors.isNotEmpty) {
                  widget.errors.clear();
                }
                if (fileUploadList != null && fileUploadList.length == 1) {
                  String filePath = fileUploadList.last['name'].toString();
                  String extension = path.extension(filePath);
                  List<String> validExtensions = ['.xlsx', '.xls'];
                  if (validExtensions.contains(extension)) {
                    return true;
                  }
                }
                return false;
              },
              onUploadFinished: ({List<Map<String, dynamic>>? fileUploadList}) async {
                List<TableField> customFields = [];
                List<TableField> tableFields = [];
                await getCustomColumnsWithId(
                  id: "default",
                  tableFields: customFields,
                  model: widget.model,
                );
                String? selectedUserId = widget.selectedUser?.id;
                if (selectedUserId != null) {
                  await getCustomColumnsWithId(
                    id: selectedUserId,
                    tableFields: customFields,
                    model: widget.model,
                  );
                }
                for (TableField tableField in customFields) {
                  List<TableFieldOption> options = await getAdvisorTableFieldOptions(
                    tableFieldOptionsId: tableField.id,
                    selectedUser: widget.selectedUser,
                  );
                  tableFields.add(tableField.copyWith(Options: options));
                }
                await validateOrUploadCustomFieldsLoaderFile(
                  fileUploadList: fileUploadList ?? [],
                  tableFields: tableFields,
                );
                if (widget.errors.isNotEmpty) {
                  return widget.completeStep();
                }
                await validateOrUploadCustomFieldsLoaderFile(
                  fileUploadList: fileUploadList ?? [],
                  tableFields: tableFields,
                  upload: true,
                );
                return widget.completeStep();
              },
            ),
          ),
        ),
        SizedBox(
          height: AppBarTheme.of(context).toolbarHeight,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(status),
              const SizedBox(
                width: 8,
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: isLoading ? const CircularProgressIndicator() : Container(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
