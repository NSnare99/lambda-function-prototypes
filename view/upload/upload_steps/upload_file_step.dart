import 'dart:convert';
import 'dart:math';
import 'package:base/models/ModelProvider.dart';
import 'package:base/utilities/extensions/string.dart';
import 'package:base/utilities/models/api_gateway_models.dart';
import 'package:base/utilities/requests/api_gateway.dart';
import 'package:base/utilities/requests/graphql.dart';
import 'package:path/path.dart' as path;
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/utilities/files/file_upload_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:rms/view/explore/logic/graphql_search.dart';
import 'package:rms/view/report_generation/report_downloader.dart';
import 'package:rms/view/upload/upload_steps/classes/excel_response.dart';
import 'package:rms/view/upload/upload_steps/logic/upload_logic.dart';
import 'package:rms/view/upload/upload_steps/logic/upload_utilities.dart';

enum LoaderFileType {
  brinker,
  fpFees,
  aws,
  fidelity,
  greatWest,
  loringWard,
  qp,
  sei,
  pacific,
  voya,
  lincoln,
  yingst,
  schwab,
  assetmark,
  genworth,
  multiVendor,
  morningstar,
  ash,
  fpFeesGeneric,
  vicus24
}

class UploadFileStep extends StatefulWidget {
  final ModelType<Model> model;
  final Map<String, String> idNormalization;
  final List<String> fileNames;
  final List<ExcelError> excelErrors;
  final List<ExcelError> uploadErrors;
  final VoidCallback? onUploadFinished;
  final Future<ExcelSheetData?> Function({required ExcelSheetData? excelSheetData})?
      onExcelDataReturn;
  const UploadFileStep({
    super.key,
    required this.model,
    required this.fileNames,
    required this.idNormalization,
    required this.excelErrors,
    this.onUploadFinished,
    required this.uploadErrors,
    this.onExcelDataReturn,
  });

  @override
  State<UploadFileStep> createState() => _UploadFileStepState();
}

class InputRow {
  int rowIndex;
  Map<String, dynamic> input;

  InputRow({required this.rowIndex, required this.input});

  factory InputRow.fromJson(Map<String, dynamic> json) {
    return InputRow(
      rowIndex: json['rowIndex'],
      input: Map<String, dynamic>.from(json['input']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rowIndex': rowIndex,
      'input': input,
    };
  }
}

class _UploadFileStepState extends State<UploadFileStep> {
  bool isUploadingFile = false;
  bool isProcessing = false;
  bool isUploadingData = false;
  int progress = 0;
  bool criticalError = false;
  int columnRow = 1;
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FileUploadPage(
          clearHistoryOnReUpload: true,
          allowMultiple: true,
          allowedExtensions: const ["xlsx, xls"],
          endpoint: endpoint,
          endpointPath: "/excel",
          onPreUpload: ({List<Map<String, dynamic>>? fileUploadList}) async {
            widget.excelErrors.clear();
            widget.uploadErrors.clear();
            setState(() {
              isUploadingFile = true;
            });
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
            fileUploadList = fileUploadList ?? [];
            int completedValidation = 0;
            widget.fileNames.add(fileUploadList.last['name']);
            if (widget.excelErrors.isNotEmpty) {
              widget.excelErrors.clear();
            }
            setState(() {
              isUploadingFile = false;
              isProcessing = true;
            });
            Response responseJsonFileInfo = await apiGatewayGET(
              server: Uri.parse("$endpoint/excel"),
              queryParameters: {"fileName": fileUploadList.last['name'], "action": "fileInfo"},
            );
            var jsonResponse = jsonDecode(responseJsonFileInfo.body);
            //do processing in lambda here

            if (jsonResponse is List<dynamic> && jsonResponse.isEmpty) {
              widget.excelErrors
                  .add(ExcelError(sheet: "", row: 0, col: 0, error: "No data found!"));
              setState(() {
                progress = 0;
                isUploadingFile = false;
                isProcessing = false;
                criticalError = true;
              });
              if (widget.onUploadFinished != null) {
                widget.onUploadFinished!();
              }
              return;
            }

            if (jsonResponse is List) {
              if (jsonResponse.length > 1) {
                widget.excelErrors.add(
                  ExcelError(
                    sheet: jsonResponse[0]['sheetName'].toString(),
                    row: 0,
                    col: 0,
                    error:
                        "${jsonResponse.length} sheets found when looking for one sheet per upload",
                  ),
                );
                setState(() {
                  progress = 0;
                  criticalError = true;
                });
                if (widget.onUploadFinished != null) {
                  widget.onUploadFinished!();
                }
              }
              for (var sheetCount = 0; sheetCount < jsonResponse.length; sheetCount++) {
                Map<String, List<String>> enums = {};

                List<InputRow> inputList = [];
                if (criticalError) continue;

                if (widget.fileNames.last.toLowerCase().contains("ash")) {
                  columnRow = 5;
                }

                ExcelResponseData? excelResponseData = await getExcelResponseSegment(
                    fileName: widget.fileNames.last,
                    sheetName: jsonResponse[sheetCount]['sheetName'].toString(),
                    batchStartRow: columnRow,
                    columnRow: columnRow);
                ExcelSheetData? excelSheetData;
                if (widget.onExcelDataReturn != null) {
                  excelSheetData = await widget.onExcelDataReturn!(
                    excelSheetData: excelResponseData?.excelSheetData,
                  );
                  if (excelSheetData != null) {
                    excelResponseData = ExcelResponseData(
                      excelSheetData: excelSheetData,
                      lastRowProcessed: excelResponseData?.lastRowProcessed ?? 0,
                    );
                  }
                }
                if (excelResponseData != null) {
                  // get enum data
                  List<ExcelCellData> dataColumnCells = [];
                  for (var schema in ModelProvider.instance.modelSchemas) {
                    if (schema.fields != null) {
                      // Check for mismatch columns
                      if (schema.name == widget.model.modelName()) {
                        dataColumnCells = excelResponseData.excelSheetData.columns.cells
                            .where(
                              (cell) =>
                                  schema.fields?.keys
                                      .map((e) => e.toLowerCase().replaceAll(RegExp(r"\s+"), ""))
                                      .contains(
                                        cell.columnName
                                            .toLowerCase()
                                            .replaceAll(RegExp(r"\s+"), ""),
                                      ) ==
                                  true,
                            )
                            .toList();
                        for (MapEntry<String, ModelField> fieldEntry in schema.fields!.entries) {
                          if (fieldEntry.value.type.fieldType == ModelFieldTypeEnum.enumeration &&
                              !enums.containsKey(
                                "${schema.name}${fieldEntry.key.toFirstUpper()}Enum",
                              )) {
                            enums.addAll({
                              "${schema.name}${fieldEntry.key.toFirstUpper()}Enum":
                                  await gqlQueryEnums(
                                enumTypeName: "${schema.name}${fieldEntry.key.toFirstUpper()}Enum",
                              ),
                            });
                            break;
                          }
                        }
                      }
                    }
                  }
                  bool continueWithDiff = true;
                  if (excelResponseData.excelSheetData.columns.cells.length !=
                      dataColumnCells.length) {
                    List<String> differentColumns = excelResponseData.excelSheetData.columns.cells
                        .map((e) => e.columnName)
                        .toSet()
                        .difference(dataColumnCells.map((e) => e.columnName).toSet())
                        .toList();
                    differentColumns += dataColumnCells
                        .map((e) => e.columnName)
                        .toSet()
                        .difference(
                          excelResponseData.excelSheetData.columns.cells
                              .map((e) => e.columnName)
                              .toSet(),
                        )
                        .toList();
                    if (context.mounted) {
                      await showDialog<bool>(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Different Columns Found:'),
                            content: Text(
                              'These columns will not be uploaded: \n${differentColumns.join(' ,')}\n\nContinue?',
                            ),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('Yes'),
                                onPressed: () {
                                  Navigator.of(context).pop(true); // dialog returns true
                                },
                              ),
                              TextButton(
                                child: const Text('No'),
                                onPressed: () {
                                  Navigator.of(context).pop(false); // dialog returns false
                                },
                              ),
                            ],
                          );
                        },
                      ).then(
                        (value) async {
                          if (value != true) {
                            continueWithDiff = false;
                          }
                        },
                      );
                    }
                    if (!continueWithDiff) {
                      return;
                    }
                  }
                  // process data
                  if (context.mounted) {
                    await validateData(
                      context: context,
                      excelResponseData: excelResponseData,
                      model: widget.model,
                      excelErrors: widget.excelErrors,
                      progressCallback: ({required int currentProgress}) => setState(() {
                        completedValidation += currentProgress;
                        progress =
                            ((completedValidation / (jsonResponse[sheetCount]['rowCount'])) * 100)
                                .floor();
                      }),
                      inputList: inputList,
                    );
                  }
                }
                while (excelResponseData != null &&
                    !criticalError &&
                    excelResponseData.lastRowProcessed < jsonResponse[sheetCount]['rowCount'] - 1) {
                  excelResponseData = await getExcelResponseSegment(
                      fileName: widget.fileNames.last,
                      sheetName: jsonResponse[sheetCount]['sheetName'].toString(),
                      batchStartRow: excelResponseData.lastRowProcessed + 1,
                      columnRow: columnRow);
                  if (excelResponseData != null) {
                    if (widget.onExcelDataReturn != null) {
                      ExcelSheetData? excelSheetData = await widget.onExcelDataReturn!(
                        excelSheetData: excelResponseData.excelSheetData,
                      );
                      if (excelSheetData != null) {
                        excelResponseData = ExcelResponseData(
                          excelSheetData: excelSheetData,
                          lastRowProcessed: excelResponseData.lastRowProcessed,
                        );
                      }
                    }
                    if (context.mounted) {
                      await validateData(
                        context: context,
                        excelResponseData: excelResponseData,
                        model: widget.model,
                        excelErrors: widget.excelErrors,
                        progressCallback: ({required int currentProgress}) => setState(() {
                          completedValidation += currentProgress;
                          progress =
                              ((completedValidation / (jsonResponse[sheetCount]['rowCount'])) * 100)
                                  .floor();
                        }),
                        inputList: inputList,
                      );
                    }
                  }
                }
                // parallel upload inputs
                if (widget.excelErrors.isEmpty) {
                  setState(() {
                    progress = 0;
                    isUploadingData = true;
                  });
                  List<Future> futures = [];
                  int completedFutures = 0;
                  for (int i = 0; i < inputList.length; i++) {
                    if (criticalError) break;
                    InputRow rowInput = inputList[i];
                    futures.add(
                      Future(() async {
                        var value = await gqlMutation(
                          input: rowInput.input,
                          mutationType: GraphQLMutationType.create,
                          model: widget.model,
                        );
                        Map valueBody = jsonDecode(value.body) is Map ? jsonDecode(value.body) : {};
                        if (value.statusCode != 200 || valueBody['data'] == null) {
                          // retries
                          for (var retry = 0; retry < 3; retry++) {
                            await Future.delayed(
                              Duration(milliseconds: Random().nextInt(500), seconds: 1),
                            );
                            value = await gqlMutation(
                              input: rowInput.input,
                              mutationType: GraphQLMutationType.create,
                              model: widget.model,
                            );
                            valueBody = jsonDecode(value.body) is Map ? jsonDecode(value.body) : {};
                            if (value.statusCode == 200 && valueBody['data'] != null) {
                              return;
                            }
                          }
                          List<String> errorMessages = [];
                          if (valueBody['errors'] is List &&
                              (valueBody['errors'] as List).isNotEmpty) {
                            for (var element in valueBody['errors'] as List) {
                              var message = element?['message'];
                              if (message != null) {
                                errorMessages.add(message.toString());
                              }
                            }
                          }
                          widget.uploadErrors.add(
                            ExcelError(
                              sheet: widget.model.modelName(),
                              row: rowInput.rowIndex,
                              col: 0,
                              error: errorMessages.isNotEmpty
                                  ? "(1/${errorMessages.length}) ${errorMessages.first}"
                                  : "An error occurred when uploading.",
                              advancedError:
                                  "Message List: $errorMessages \n\n Full Error: ${value.body}",
                              data: rowInput.input,
                            ),
                          );
                        }
                        completedFutures++;
                      }),
                    );
                    if (futures.length >= 400) {
                      await Future.wait(futures);
                      futures.clear();
                      setState(() {
                        progress = ((completedFutures / inputList.length) * 100).floor();
                      });
                    }
                  }
                  if (!criticalError) {
                    await Future.wait(futures);
                    setState(() {
                      progress = 100;
                    });
                  }
                  widget.uploadErrors.sort((a, b) {
                    return a.row.compareTo(b.row);
                  });
                }
                inputList.clear();
                excelResponseData = null;
              }
            }
            setState(() {
              isUploadingFile = false;
              isProcessing = false;
              isUploadingData = false;
              criticalError = false;
            });
            if (widget.onUploadFinished != null && progress > 0) {
              setState(() {
                progress = 100;
              });
              widget.onUploadFinished!();
            }
          },
        ),
        if (isUploadingFile || isProcessing)
          Opacity(
            opacity: 1.0,
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const CircularProgressIndicator(),
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        isUploadingFile
                            ? "Uploading File"
                            : isUploadingData
                                ? "Uploading Data: $progress %"
                                : "Validation Check: $progress %",
                      ),
                    ),
                    widget.excelErrors.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Text("Current Errors: ${widget.excelErrors.length}"),
                          )
                        : Container(),
                    widget.excelErrors.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: ElevatedButton(
                              onPressed: () => setState(() {
                                criticalError = true;
                              }),
                              child: const Text("Cancel"),
                            ),
                          )
                        : Container(),
                    widget.uploadErrors.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Text("Current Errors: ${widget.uploadErrors.length}"),
                          )
                        : Container(),
                    widget.uploadErrors.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: ElevatedButton(
                              onPressed: () => setState(() {
                                criticalError = true;
                              }),
                              child: const Text("Cancel"),
                            ),
                          )
                        : Container(),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

//Given file name of vendor loader, convert to standard processing loader
Future<ExcelSheetData>? convertToStandardLoader(
    {required ExcelSheetData preProcessedSheetData,
    required String fileName,
    required bool isGenericLoader,
    required bool includeDaysInBillingCycle}) async {
  List<Map<String, dynamic>> dataList = [];
  Map<String, dynamic> item = {};
  String columnName = "";
  dynamic value;
  //Get equivalent names of vendor loader and match them with names in PendingCommission table
  Map<String, String> matchingFieldNames = {};
  if (isGenericLoader) {
    matchingFieldNames = {
      "External Account": "External Account",
      "Commission": "Basis",
      "Rep ID": "Rep On Trade ID",
      "Principal": "Principal",
      "Settle Date": "Settle Date",
      "Trade Date": "Trade Date",
      "Product Code": "Product",
    };
    if (includeDaysInBillingCycle) {
      matchingFieldNames["Order Type"] = "Days In Billing Cycle";
    }
  }
  if (fileName.toLowerCase().contains(LoaderFileType.ash.name.splitCamelCase().toLowerCase())) {
    matchingFieldNames = {
      "Stmt Date": "Trade Date",
      "Policy/Ref #": "External Account",
      "Insco": "Product",
      "Earning": "Basis",
      "Agent": "Rep On Trade ID"
    };
  } else if (fileName
          .toLowerCase()
          .contains(LoaderFileType.assetmark.name.splitCamelCase().toLowerCase()) ||
      fileName
          .toLowerCase()
          .contains(LoaderFileType.genworth.name.splitCamelCase().toLowerCase())) {
    matchingFieldNames = {
      "Custodial Account #": "External Account",
      "Insco": "Product",
      "Billable Amount": "Principal",
      "Total Client Fee": "Basis",
      "Financial Advisor ID - Custodian": "Rep On Trade ID"
    };
  } else if (fileName
      .toLowerCase()
      .contains(LoaderFileType.yingst.name.splitCamelCase().toLowerCase())) {
    matchingFieldNames = {
      "Ext Account": "External Account",
      "Gross Revenue": "Basis",
      "Symbol": "Product",
      "Rep ID": "Rep On Trade ID",
      "Principal": "Principal",
      "Settle Date": "Settle Date",
      "Trade Date": "Trade Date"
    };
  } else if (fileName
      .toLowerCase()
      .contains(LoaderFileType.morningstar.name.splitCamelCase().toLowerCase())) {
    matchingFieldNames = {
      "External Account": "External Account",
      "Commission": "Basis",
      "Rep ID": "Rep On Trade ID",
      "Principal": "Principal",
      "Settle Date": "Settle Date",
      "Trade Date": "Trade Date",
      "Symbol": "Product"
    };
  } else if (fileName
      .toLowerCase()
      .contains(LoaderFileType.multiVendor.name.splitCamelCase().toLowerCase())) {
    matchingFieldNames = {
      "External Account": "External Account",
      "Commission": "Basis",
      "Rep ID": "Rep On Trade ID",
      "Principal": "Principal",
      "Settle Date": "Settle Date",
      "Trade Date": "Trade Date",
      "Cusip": "Product"
    };
  } else if (fileName
      .toLowerCase()
      .contains(LoaderFileType.fpFeesGeneric.name.splitCamelCase().toLowerCase())) {
    matchingFieldNames = {
      "External Account": "External Account",
      "Commission": "Basis",
      "Rep ID": "Rep On Trade ID",
      "Principal": "Principal",
      "Settle Date": "Settle Date",
      "Trade Date": "Trade Date",
      "Product Code": "Product"
    };
  } else if (fileName
      .toLowerCase()
      .contains(LoaderFileType.fpFees.name.splitCamelCase().toLowerCase())) {
    matchingFieldNames = {
      "External Account": "External Account",
      "Gross Revenue": "Basis",
      "Rep ID": "Rep On Trade ID",
      "Principal": "Principal",
      "Settle Date": "Settle Date",
      "Trade Date": "Trade Date",
      "Symbol": "Product"
    };
  } else {
    for (int index = 0; index < LoaderFileType.values.length; index++) {
      if (fileName
          .toLowerCase()
          .contains(LoaderFileType.values[index].name.splitCamelCase().toLowerCase())) {
        matchingFieldNames = {
          "External Account": "External Account",
          "Commission": "Basis",
          "Rep ID": "Rep On Trade ID",
          "Principal": "Principal",
          "Settle Date": "Settle Date",
          "Trade Date": "Trade Date",
          "Product Code": "Product",
        };
        if (includeDaysInBillingCycle) {
          matchingFieldNames["Order Type"] = "Days In Billing Cycle";
        }
      }
    }
  }

  //Convert sheet to list of map items
  for (int rowIndex = 0; rowIndex < preProcessedSheetData.rows.length; rowIndex++) {
    for (int cellIndex = 0;
        cellIndex < preProcessedSheetData.rows[rowIndex].cells.length;
        cellIndex++) {
      if (matchingFieldNames.isEmpty) {
        //If there are no matching field names, continue as standard loader
        item[preProcessedSheetData.rows[rowIndex].cells[cellIndex].columnName
            .toFirstLower()
            .split(" ")
            .join()] = preProcessedSheetData.rows[rowIndex].cells[cellIndex].value;
      } else {
        if (matchingFieldNames
            .containsKey(preProcessedSheetData.rows[rowIndex].cells[cellIndex].columnName)) {
          //Get matching field names
          columnName =
              matchingFieldNames[preProcessedSheetData.rows[rowIndex].cells[cellIndex].columnName]!
                  .toFirstLower()
                  .split(" ")
                  .join();
          value = preProcessedSheetData.rows[rowIndex].cells[cellIndex].value;
        } else {
          //Disregard any field names in vendor loader which don't have a matching value
          continue;
        }
        //Specific to Ash Loader; rep names instead of rep Ids are used
        if (fileName
                .toLowerCase()
                .contains(LoaderFileType.ash.name.splitCamelCase().toLowerCase()) &&
            preProcessedSheetData.rows[rowIndex].cells[cellIndex].columnName == "Agent") {
          for (int accountCellIndex = 0;
              accountCellIndex < preProcessedSheetData.rows[rowIndex].cells.length;
              accountCellIndex++) {
            if (preProcessedSheetData.rows[rowIndex].cells[accountCellIndex].columnName ==
                "Policy/Ref #") {
              value = await getAdvisorIDFromName(
                  preProcessedSheetData.rows[rowIndex].cells[cellIndex].value,
                  preProcessedSheetData.rows[rowIndex].cells[accountCellIndex].value,
                  true);
            }
          }
        }

        item[columnName] = value;
      }

      //Some loaders have incomplete values; fill in the blanks based on these cases

      if (item.containsKey("tradeDate") && !item.containsKey("settleDate")) {
        item["settleDate"] = item["tradeDate"];
      }

      if (!item.containsKey("tradeDate") && !item.containsKey("settleDate")) {
        item["settleDate"] = DateTime.now().toString();
        item["tradeDate"] = DateTime.now().toString();
      }

      if (!item.containsKey("principal")) {
        item["principal"] = 0;
      }

      //Specific to AssetMark loader; all programs are the same, but are not specified in the loader
      if (fileName
          .toLowerCase()
          .contains(LoaderFileType.assetmark.name.splitCamelCase().toFirstLower())) {
        item["product"] = "GENADV";
      }
    }

    dataList.add(item);
    item = {};
  }
  dataList.removeWhere(
    (element) => element.isEmpty,
  );

  //Reconstruct sheet data

  List<Map<String, dynamic>> dataListFriendlyKeys = [];
  Map<String, dynamic> dataListIndividualItem = {};
  List<ExcelCellData> dataCellsForColumns = [];
  List<ExcelRowData> dataRows = [];

  for (int dataListIndex = 0; dataListIndex < dataList.length; dataListIndex++) {
    dataList[dataListIndex].forEach((key, value) {
      dataListIndividualItem[key.toFirstUpper().splitCamelCase()] = value;
    });
    dataListFriendlyKeys.add(dataListIndividualItem);

    dataListIndividualItem = {};
  }
  Map<String, dynamic> currentDataRow = dataListFriendlyKeys[0];

  currentDataRow.forEach((key, value) {
    dataCellsForColumns.add(ExcelCellData(columnName: key, value: key));
  });
  for (int rowIndex = 0; rowIndex < dataListFriendlyKeys.length; rowIndex++) {
    List<ExcelCellData> dataCellsForRows = [];
    currentDataRow = dataListFriendlyKeys[rowIndex];
    currentDataRow.forEach((key, value) {
      dataCellsForRows.add(ExcelCellData(columnName: key, value: value.toString()));
    });
    dataRows.add(ExcelRowData(rowIndex: rowIndex + 2, cells: dataCellsForRows));
  }
  //Return standard sheet data
  return ExcelSheetData(
    sheetName: preProcessedSheetData.sheetName,
    columns: ExcelRowData(rowIndex: 1, cells: dataCellsForColumns),
    rows: dataRows,
  );
}

//From Excel sheet data, get rows/column data, get processed version from Step function,
//and convert to new sheet data
Future<ExcelSheetData>? getProcessedSheetData({
  required ExcelSheetData preProcessedSheetData,
  required void Function({required List<ExcelError> errors}) excelErrorsCallback,
}) async {
  List<Map<String, dynamic>> dataList = [];
  Map<String, dynamic> item = {};
  String columnName = "";
  dynamic value;

  //Convert sheet to list of map items
  for (int rowIndex = 0; rowIndex < preProcessedSheetData.rows.length; rowIndex++) {
    for (int cellIndex = 0;
        cellIndex < preProcessedSheetData.rows[rowIndex].cells.length;
        cellIndex++) {
      //Keys in Excel loader file have friendly name format (i.e. "repOnTradeID" is rendered "Rep On Trade ID")
      //These keys are converted before state machine invocation, and then reverted back to original format
      //when data is returned to client.
      columnName = preProcessedSheetData.rows[rowIndex].cells[cellIndex].columnName
          .toFirstLower()
          .split(" ")
          .join();
      value = preProcessedSheetData.rows[rowIndex].cells[cellIndex].value;

      item[columnName] = value;
    }

    dataList.add(item);
    item = {};
  }

  dataList.removeWhere((item) => item.isEmpty);
  int lengthOfDataSegment = 250;

  int numberOfStateMachineCalls =
      dataList.length ~/ lengthOfDataSegment + (dataList.length % lengthOfDataSegment > 0 ? 1 : 0);

  List<Map<String, dynamic>> finishedDataList = [];

  for (int invocationIndex = 0; invocationIndex < numberOfStateMachineCalls; invocationIndex++) {
    int start = invocationIndex * lengthOfDataSegment;
    int end = start + lengthOfDataSegment;

    await apiGatewayPOST(
      server: Uri.parse(
        '$newEndpoint/feeCalculation',
      ),
      payload: {
        "lineItems":
            (end >= dataList.length) ? dataList.sublist(start) : dataList.sublist(start, end),
      },
    );

    List<Map<String, dynamic>>? processedDataListItems = await getProcessedDataList(
        dataList: (end >= dataList.length) ? dataList.sublist(start) : dataList.sublist(start, end),
        excelErrorsCallback: excelErrorsCallback);

    if (processedDataListItems != null) {
      finishedDataList.addAll(processedDataListItems);
    }
  }

  //Reformat all keys in dataList to have friendly names, to match other Excel upload files
  List<Map<String, dynamic>> dataListFriendlyKeys = [];
  Map<String, dynamic> dataListIndividualItem = {};
  for (int dataListIndex = 0; dataListIndex < finishedDataList.length; dataListIndex++) {
    finishedDataList[dataListIndex].forEach((key, value) {
      dataListIndividualItem[key.toFirstUpper().splitCamelCase()] = value;
    });
    dataListFriendlyKeys.add(dataListIndividualItem);
    dataListIndividualItem = {};
  }

  //Reconstruct sheet data
  List<ExcelCellData> dataCellsForColumns = [];
  List<ExcelRowData> dataRows = [];
  Map<String, dynamic> currentDataRow = dataListFriendlyKeys[0];
  currentDataRow.forEach((key, value) {
    dataCellsForColumns.add(ExcelCellData(columnName: key, value: key));
  });
  for (int rowIndex = 0; rowIndex < dataListFriendlyKeys.length; rowIndex++) {
    List<ExcelCellData> dataCellsForRows = [];
    currentDataRow = dataListFriendlyKeys[rowIndex];
    currentDataRow.forEach((key, value) {
      dataCellsForRows.add(ExcelCellData(columnName: key, value: value.toString()));
    });
    dataRows.add(ExcelRowData(rowIndex: rowIndex + 2, cells: dataCellsForRows));
  }

  return ExcelSheetData(
    sheetName: preProcessedSheetData.sheetName,
    columns: ExcelRowData(rowIndex: 1, cells: dataCellsForColumns),
    rows: dataRows,
  );
}

//Given initial list of Map items, get additional fields and line items from
//data processing Step Function
Future<List<Map<String, dynamic>>>? getProcessedDataList({
  required List<Map<String, dynamic>> dataList,
  required void Function({required List<ExcelError> errors}) excelErrorsCallback,
}) async {
  //Step function limit for bytes input
  int awsStepFunctionInputBytesLimit = 32768;
  //AWS Step function input bytes limit, with buffer room for payload characters.
  int upperDataLimit = (awsStepFunctionInputBytesLimit * .90).floor();
  //String length of single line item in payload
  int lengthOfSingleItem = jsonEncode(dataList[0]).length;
  //Number of line items which can be input in a single step
  int numberOfInputItemsPerStep = upperDataLimit ~/ lengthOfSingleItem;
  //Number of iterations for input process
  int numberOfSteps = (dataList.length / numberOfInputItemsPerStep).ceil();

  List<ExcelError> uploadProcessingErrors = [];

  //File names for gathering from S3 bucket
  String fileName = "${DateTime.now().millisecondsSinceEpoch}dataProcess_iteration_.JSON";
  List<String> fileNamesForRetrieval = [];

  List<Map<String, dynamic>> processedDataList = [];

  for (int dataProcessingBatchNumber = 0;
      dataProcessingBatchNumber < numberOfSteps;
      dataProcessingBatchNumber++) {
    fileNamesForRetrieval.add(fileName.replaceAll(".JSON", "$dataProcessingBatchNumber.JSON"));
    int start = dataProcessingBatchNumber * numberOfInputItemsPerStep;
    int end = start + numberOfInputItemsPerStep;

    await apiGatewayPOST(
      server: Uri.parse(
        '$newEndpoint/periodCloseStateMachine',
      ),
      payload: {
        "input": (end >= dataList.length) ? dataList.sublist(start) : dataList.sublist(start, end),
        "fileName": fileName.replaceAll(".JSON", "$dataProcessingBatchNumber.JSON"),
        "recalculate": false,
      },
    );
  }

  for (int index = 0; index < fileNamesForRetrieval.length; index++) {
    List<Map<String, dynamic>> items = [];
    late Response logStreamResponse;
    Map<String, dynamic> error = {};
    //Attempt to retrieve LogStream from state machine results.
    //Retry query until LogStream is prepared and check for any errors
    for (int logStreamRetry = 0; logStreamRetry < 20; logStreamRetry++) {
      await Future.delayed(const Duration(seconds: 15));
      logStreamResponse = await apiGatewayPOST(
        server: Uri.parse(
          '$newEndpoint/periodCloseStateMachine',
        ),
        payload: {
          "awaitingNotification": true,
          "fileName": fileNamesForRetrieval[index],
        },
      );

      //Log Stream Exists
      if (logStreamResponse.statusCode == 200) {
        error = jsonDecode(logStreamResponse.body);
        //Add any errors from LogStream
        for (int msgIndex = 0; msgIndex < error["events"].length; msgIndex++) {
          uploadProcessingErrors.add(
              ExcelError(sheet: "", row: 0, col: 0, error: error["events"][msgIndex]["message"]));
        }
        break;
      }
    }
    //if errors exist after processing, update excel errors list with details
    if (uploadProcessingErrors.isNotEmpty) {
      excelErrorsCallback(errors: uploadProcessingErrors);
    }

    for (int retry = 0; retry < 20; retry++) {
      await Future.delayed(const Duration(seconds: 15));
      items = await getProcessedDataConcurrently(fileNamesForRetrieval[index]);
      if (items.isNotEmpty) {
        break;
      }
    }
    for (int i = 0; i < items.length; i++) {
      processedDataList.add(items[i]);
    }
  }
  return processedDataList;
}

//Stream file from S3
Future<List<Map<String, dynamic>>> getProcessedDataConcurrently(String fileName) async {
  //Wait for state machine outputs to finish before trying to get file

  String reportDataText = await getJSONData(fileName: fileName);

  //Make 2 attempts every five seconds if file doesn't exist
  if (reportDataText.trim() == "") {
    for (int attemptsCount = 0; attemptsCount < 20; attemptsCount++) {
      await Future.delayed(const Duration(seconds: 15));
      reportDataText = await getJSONData(fileName: fileName);

      if (reportDataText.trim() != "") {
        break;
      }
    }
  }

  if (reportDataText.trim() == "") {
    return [];
  }

  Map<String, dynamic> jsonData = jsonDecode(reportDataText);
  //Get nested items list in JSON output
  List<Map<String, dynamic>> dataReturn = [];
  for (int row = 0; row < jsonData["input"].length; row++) {
    for (int column = 0; column < jsonData["input"][row].length; column++) {
      dataReturn.add(jsonData["input"][row][column]);
    }
  }
  return dataReturn;
}

Future<String> getAdvisorIDFromName(String name, String accountNumber, bool isInsurance) async {
  bool continueSearching = true;
  String advisorId = "";
  String? nextToken;
  //Rep is Split ID if name contains percentage
  //Account number must be used to identify the split
  if (name.contains("%")) {
    while (continueSearching) {
      //Invoke step function
      await searchGraphql(
        limit: 100,
        filter: 'filter: {externalAccount: {eq: "$accountNumber"}}',
        model: ModelProvider().getModelTypeByModelName("Account"),
        isMounted: () => true,
        nextToken: nextToken != null ? Uri.encodeComponent(nextToken ?? "") : null,
      ).then((value) async {
        nextToken = value.nextToken;
        if (value.items != null) {
          for (int itemsIndex = 0; itemsIndex < value.items!.length; itemsIndex++) {
            if (value.items![itemsIndex]["repID"] != null) {
              advisorId = value.items![itemsIndex]["repID"];
              continueSearching = false;
            }
          }
        }
      });

      if (nextToken == null) {
        continueSearching = false;
      }
    }
  }

  while (continueSearching) {
    //Invoke step function
    await searchGraphql(
      limit: 100,
      filter:
          'filter: {lastName: {contains: "${name.split(", ")[0]}"}, firstName: {contains: "${name.split(", ")[1].split(" ")[0]}"}, id: {contains: "-LI"}}',
      model: ModelProvider().getModelTypeByModelName("Advisor"),
      isMounted: () => true,
      nextToken: nextToken != null ? Uri.encodeComponent(nextToken ?? "") : null,
    ).then((value) async {
      nextToken = value.nextToken;
      if (value.items != null && value.items!.length == 1) {
        advisorId = value.items!.first["id"];
        continueSearching = false;
      }
    });

    if (nextToken == null) {
      continueSearching = false;
    }
  }

  return advisorId;
}
