import 'dart:convert';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/models/ModelProvider.dart';
import 'package:base/utilities/extensions/string.dart';
import 'package:base/utilities/models/api_gateway_models.dart';
import 'package:base/utilities/models/join_table_model.dart';
import 'package:base/utilities/requests/api_gateway.dart';
import 'package:base/utilities/requests/graphql.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:rms/view/adaptive_grid.dart';
import 'package:rms/view/upload/upload_steps/logic/upload_logic.dart';
import 'package:web_plugins/web_plugins.dart';

class LoaderTables extends StatefulWidget {
  final void Function()? onDownloadFinished;
  final ModelType<Model> model;
  final List<String> stopModels;
  final Map<String, String> excelColumnReplacements;
  final Map<String, List<String>> enumData;
  final Map<String, List<JoinTableData>> joinTableData;
  final List<ModelField>? removeFields;
  const LoaderTables({
    super.key,
    required this.model,
    required this.stopModels,
    required this.excelColumnReplacements,
    required this.enumData,
    required this.joinTableData,
    this.onDownloadFinished,
    this.removeFields,
  });

  @override
  State<LoaderTables> createState() => _LoaderTablesState();
}

class _LoaderTablesState extends State<LoaderTables> {
  bool _isLoading = false;
  Map<String, bool> autoIdColumns = {};
  List<String> tableList = [];

  void _setLoadingState(bool value) {
    setState(() {
      _isLoading = value;
    });
  }

  void _sendSnackBarMessage(String snackBarText) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: SizedBox(
          height: MediaQuery.sizeOf(context).height * .1,
          width: MediaQuery.sizeOf(context).width,
          child: Center(child: Text(snackBarText)),
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  void initState() {
    for (ModelSchema schema in ModelProvider.instance.modelSchemas) {
      if (schema.name == widget.model.modelName()) {
        List<ModelIndex>? indexes = schema.indexes;
        if (indexes != null) {
          for (ModelIndex index in indexes) {
            for (String field in index.fields) {
              if (field.endsWith("Id") || field.endsWith("ID") || field.toLowerCase() == "id") {
                autoIdColumns.addAll({field: true});
              }
            }
          }
        }
      }
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Center(
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      String dtString = DateTime.now().millisecondsSinceEpoch.toString();
                      _setLoadingState(true);
                      _isLoading = true;
                      ExcelSheetData excelSheetData = ExcelSheetData(
                        sheetName: widget.model.modelName().toFirstUpper().splitCamelCase(),
                        columns: ExcelRowData(rowIndex: 0, cells: []),
                        rows: [],
                      );
                      excelSheetData =
                          await createExcelSheet(excelSheetData, widget.model, widget.removeFields);
                      // excelSheetData.columns.cells.sort((a, b) {
                      //   bool aHasExclamation = a.columnName.endsWith('!');
                      //   bool bHasExclamation = b.columnName.endsWith('!');
                      //   if (aHasExclamation && !bHasExclamation) {
                      //     return -1;
                      //   } else if (!aHasExclamation && bHasExclamation) {
                      //     return 1;
                      //   } else {
                      //     return 0;
                      //   }
                      // });
                      for (MapEntry<String, bool> autoIdColumn in autoIdColumns.entries) {
                        if (autoIdColumn.value) {
                          String autoIdColumnName = autoIdColumn.key.toLowerCase() == "id"
                              ? "ID"
                              : autoIdColumn.key.toFirstUpper().splitCamelCase();
                          excelSheetData.columns.cells.removeWhere((c) {
                            return c.columnName.replaceAll("!", "") == autoIdColumnName &&
                                autoIdColumn.value;
                          });
                        }
                      }
                      List<ExcelSheetData> newData = [excelSheetData];
                      newData = newData.reversed.toList();
                      List<int> byteSizes = [];
                      for (var element in newData) {
                        // length of string converted to bytes then assume each byte is at max value.
                        byteSizes.add(utf8.encode(element.toString()).length * 8 * 4);
                      }
                      int chunkSize = 0;
                      int totalByteSize = 0;
                      // 3MB (base 2)
                      if (byteSizes.isNotEmpty) {
                        while (totalByteSize < (3145728 - byteSizes.max)) {
                          totalByteSize += byteSizes.max;
                          chunkSize++;
                        }
                      }
                      List<List<ExcelSheetData>> chunks = [];
                      for (var i = 0; i < newData.length; i += chunkSize) {
                        chunks.add(
                          newData.sublist(
                            i,
                            i + chunkSize > newData.length ? newData.length : i + chunkSize,
                          ),
                        );
                      }
                      String fileName = '${dtString}_Loader_Tables.xlsx';
                      for (List<ExcelSheetData> element in chunks) {
                        ExcelFileData(
                          fileName: fileName,
                          sheets: element,
                        ).toJson();
                        Response response = await apiGatewayPOST(
                          server: Uri.parse("$endpoint/excel"),
                          payload: ExcelFileData(
                            fileName: fileName,
                            sheets: element,
                          ).toJson(),
                        );
                        if (response.statusCode == 201 || response.statusCode == 200) {
                          await downloadTempExcelFile(fileName: fileName);
                        } else {
                          SchedulerBinding.instance.addPostFrameCallback(
                            (timeStamp) => _sendSnackBarMessage("failed to get loader file"),
                          );
                          break;
                        }
                      }
                      _setLoadingState(false);
                      if (widget.onDownloadFinished != null) {
                        widget.onDownloadFinished!();
                      }
                    },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Loader - Tables"),
                  const SizedBox(
                    width: 5,
                  ),
                  _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(),
                        )
                      : const SizedBox(),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 250),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Auto generate Id's for Columns:"),
                const SizedBox(
                  height: 8,
                ),
                AdaptiveGrid(
                  children: autoIdColumns.entries
                      .map<Widget>(
                        (e) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              key: ValueKey(e.key),
                              value: e.value,
                              onChanged: (b) async {
                                Map<String, bool> tempColumns = {};
                                for (MapEntry<String, bool> col in autoIdColumns.entries) {
                                  if (col.key == e.key) {
                                    tempColumns.addAll({col.key: b ?? true});
                                  } else {
                                    tempColumns.addAll({col.key: col.value});
                                  }
                                }
                                setState(() {
                                  autoIdColumns = tempColumns;
                                });
                              },
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            Text(e.key.splitCamelCase()),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<ExcelSheetData> createExcelSheet(
  ExcelSheetData excelSheetData,
  ModelType<Model> model,
  List<ModelField>? removeFields,
) async {
  String locale = await WebPlugins().getLocalization() ?? "en-US";
  for (ModelSchema schema in ModelProvider.instance.modelSchemas) {
    if (schema.name == model.modelName()) {
      Map<String, ModelField> fields = {};
      schema.fields?.forEach((key, value) {
        if (!(removeFields?.map((rf) => rf.name).contains(key) ?? false)) {
          fields.addAll({key: value});
        }
      });
      for (MapEntry<String, ModelField> fieldEntry in fields.entries) {
        if (fieldEntry.key == "customFields") continue;
        if (!fieldEntry.value.isReadOnly) {
          ModelFieldTypeEnum fieldMoodelType = fieldEntry.value.type.fieldType;
          switch (fieldMoodelType) {
            case ModelFieldTypeEnum.string:
              String? comment;
              excelSheetData.columns.cells.add(
                ExcelCellData(
                  columnName: "${fieldEntry.key}${fieldEntry.value.isRequired ? "!" : ""}",
                  value: "${fieldEntry.key}${fieldEntry.value.isRequired ? "!" : ""}",
                  comment: comment,
                ),
              );
            case ModelFieldTypeEnum.int:
              excelSheetData.columns.cells.add(
                ExcelCellData(
                  columnName: "${fieldEntry.key}${fieldEntry.value.isRequired ? "!" : ""}",
                  value: "${fieldEntry.key}${fieldEntry.value.isRequired ? "!" : ""}",
                  comment: "Whole Numbers Only",
                ),
              );
            case ModelFieldTypeEnum.double:
              excelSheetData.columns.cells.add(
                ExcelCellData(
                  columnName: "${fieldEntry.key}${fieldEntry.value.isRequired ? "!" : ""}",
                  value: "${fieldEntry.key}${fieldEntry.value.isRequired ? "!" : ""}",
                  comment: "A number with an optional decimal point",
                ),
              );
            case ModelFieldTypeEnum.date:
              excelSheetData.columns.cells.add(
                ExcelCellData(
                  columnName: "${fieldEntry.key}${fieldEntry.value.isRequired ? "!" : ""}",
                  value: "${fieldEntry.key}${fieldEntry.value.isRequired ? "!" : ""}",
                  comment: DateFormat.yMd(locale)
                      .pattern
                      ?.replaceAll('y', 'yyyy')
                      .replaceAll('M', 'MM')
                      .replaceAll('d', 'dd'),
                ),
              );
            case ModelFieldTypeEnum.dateTime:
              excelSheetData.columns.cells.add(
                ExcelCellData(
                  columnName: "${fieldEntry.key}${fieldEntry.value.isRequired ? "!" : ""}",
                  value: "${fieldEntry.key}${fieldEntry.value.isRequired ? "!" : ""}",
                  comment: DateFormat.yMd(locale)
                      .add_Hms()
                      .pattern
                      ?.replaceAll('y', 'yyyy')
                      .replaceAll('M', 'MM')
                      .replaceAll('d', 'dd'),
                ),
              );
            case ModelFieldTypeEnum.time:
              excelSheetData.columns.cells.add(
                ExcelCellData(
                  columnName: "${fieldEntry.key}${fieldEntry.value.isRequired ? "!" : ""}",
                  value: "${fieldEntry.key}${fieldEntry.value.isRequired ? "!" : ""}",
                  comment: DateFormat.Hms(locale).pattern,
                ),
              );
            case ModelFieldTypeEnum.timestamp:
              excelSheetData.columns.cells.add(
                ExcelCellData(
                  columnName: "${fieldEntry.key}${fieldEntry.value.isRequired ? "!" : ""}",
                  value: "${fieldEntry.key}${fieldEntry.value.isRequired ? "!" : ""}",
                  comment: "unix epoch in miliseconds",
                ),
              );
            case ModelFieldTypeEnum.bool:
              excelSheetData.columns.cells.add(
                ExcelCellData(
                  columnName: "${fieldEntry.key}${fieldEntry.value.isRequired ? "!" : ""}",
                  value: "${fieldEntry.key}${fieldEntry.value.isRequired ? "!" : ""}",
                  comment: "Acceptable Values:\n\r${["TRUE\n\r", "FALSE\n\r"].join(", ")}",
                  enumData: ["TRUE", "FALSE"],
                ),
              );
            case ModelFieldTypeEnum.enumeration:
              List<String>? enumValues = await gqlQueryEnums(
                enumTypeName: "${model.modelName()}${fieldEntry.key.toFirstUpper()}Enum",
              );
              enumValues = enumValues.map((e) => e.trim()).isEmpty
                  ? null
                  : enumValues
                      .whereNotNull()
                      .whereNot(
                        (e) => e.trim() == "",
                      )
                      .map((e) => e = e.replaceAll(RegExp(r'^_+|_+$'), "").replaceAll("_", " "))
                      .toList();
              excelSheetData.columns.cells.add(
                ExcelCellData(
                  columnName: "${fieldEntry.key}${fieldEntry.value.isRequired ? "!" : ""}",
                  value: "${fieldEntry.key}${fieldEntry.value.isRequired ? "!" : ""}",
                  comment: "Acceptable Values:\n\r${enumValues?.join(", ")}",
                  enumData: enumValues,
                ),
              );
            case ModelFieldTypeEnum.collection:
              ModelFieldTypeEnum? collectionTypeValue = enumFromString<ModelFieldTypeEnum>(
                fieldEntry.value.type.ofModelName,
                ModelFieldTypeEnum.values,
              );
              if (collectionTypeValue != null &&
                  collectionTypeValue != ModelFieldTypeEnum.model &&
                  collectionTypeValue != ModelFieldTypeEnum.collection &&
                  collectionTypeValue != ModelFieldTypeEnum.embedded &&
                  collectionTypeValue != ModelFieldTypeEnum.embeddedCollection) {
                if (collectionTypeValue == ModelFieldTypeEnum.enumeration) {
                  List<String>? enumValues = await gqlQueryEnums(
                    enumTypeName: "${model.modelName()}${fieldEntry.key.toFirstUpper()}Enum",
                  );
                  enumValues = enumValues.map((e) => e.trim()).isEmpty
                      ? null
                      : enumValues
                          .whereNotNull()
                          .whereNot(
                            (e) => e.trim() == "",
                          )
                          .map((e) => e = e.replaceAll(RegExp(r'^_+|_+$'), "").replaceAll("_", " "))
                          .toList();
                  excelSheetData.columns.cells.add(
                    ExcelCellData(
                      columnName: "${fieldEntry.key}${fieldEntry.value.isRequired ? "!" : ""}",
                      value: "${fieldEntry.key}${fieldEntry.value.isRequired ? "!" : ""}",
                      comment:
                          "List separated by ;\n\rAcceptable Values:\n\r${enumValues?.join(", ")}",
                      enumData: enumValues,
                    ),
                  );
                } else {
                  excelSheetData.columns.cells.add(
                    ExcelCellData(
                      columnName: "${fieldEntry.key}${fieldEntry.value.isRequired ? "!" : ""}",
                      value: "${fieldEntry.key}${fieldEntry.value.isRequired ? "!" : ""}",
                      comment: "List separated by ;",
                    ),
                  );
                }
              }
            case ModelFieldTypeEnum.model:
              if (fieldEntry.value.association?.associationType == ModelAssociationEnum.BelongsTo) {
                List<String>? targetNames = fieldEntry.value.association?.targetNames;
                if (targetNames != null) {
                  for (String targetName in targetNames) {
                    excelSheetData.columns.cells.add(
                      ExcelCellData(
                        columnName: targetName,
                        value: targetName,
                        comment: "ID: ${fieldEntry.value.association?.associatedType}",
                      ),
                    );
                  }
                }
              }
            case ModelFieldTypeEnum.embedded:
            case ModelFieldTypeEnum.embeddedCollection:
          }
        }
      }
      break;
    }
  }
  return ExcelSheetData(
    sheetName: excelSheetData.sheetName,
    columns: ExcelRowData(
      cells: excelSheetData.columns.cells
          .map(
            (e) => ExcelCellData(
              columnName: e.columnName.toLowerCase() == "id"
                  ? "ID"
                  : e.columnName.toFirstUpper().splitCamelCase(),
              value: e.columnName.toLowerCase() == "id"
                  ? "ID"
                  : e.columnName.toFirstUpper().splitCamelCase(),
              comment: e.comment,
              enumData: e.enumData?.sorted(),
              floatLimits: e.floatLimits,
            ),
          )
          .toList(),
      rowIndex: 1,
    ),
    rows: excelSheetData.rows,
  );
}
