import 'dart:convert';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/models/TableField.dart';
import 'package:base/models/TableFieldOption.dart';
import 'package:base/models/User.dart';
import 'package:base/utilities/extensions/string.dart';
import 'package:base/utilities/models/api_gateway_models.dart';
import 'package:base/utilities/requests/api_gateway.dart';
import 'package:base/utilities/requests/graphql.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:rms/view/explore/logic/graphql_search.dart';
import 'package:rms/view/upload/upload_steps/logic/upload_logic.dart';

class CustomFieldsLoader extends StatefulWidget {
  final User? selectedUser;
  final ModelType<Model> model;
  final String? filter;
  final List<ModelField> fields;
  final void Function() completeStep;
  final List<ExcelCellData> columnCells;
  const CustomFieldsLoader({
    super.key,
    required this.completeStep,
    required this.model,
    required this.filter,
    required this.selectedUser,
    required this.fields,
    required this.columnCells,
  });

  @override
  State<CustomFieldsLoader> createState() => _CustomFieldsLoaderState();
}

class _CustomFieldsLoaderState extends State<CustomFieldsLoader> {
  bool isLoading = false;
  List<TableField> customFields = [];
  List<ExcelCellData> requiredFields = [];
  void getCustomFieldsLoaderFile() async {
    setState(() {
      isLoading = true;
    });
    ExcelSheetData excelSheetData = ExcelSheetData(
      sheetName: widget.model.modelName().toFirstUpper().splitCamelCase(),
      columns: ExcelRowData(rowIndex: 1, cells: []),
      rows: [],
    );
    // get customField data (names and table options)
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
    for (var field in widget.fields) {
      excelSheetData.columns.cells.add(
        ExcelCellData(
          columnName: field.name.toFirstUpper().splitCamelCase(),
          value: field.name.toFirstUpper().splitCamelCase(),
        ),
      );
    }
    for (TableField tableField in customFields) {
      List<TableFieldOption> options = await getAdvisorTableFieldOptions(
        tableFieldOptionsId: tableField.id,
        selectedUser: widget.selectedUser,
      );
      excelSheetData.columns.cells.add(
        ExcelCellData(
          columnName: tableField.fieldName?.toFirstUpper().splitCamelCase() ?? "",
          value: tableField.fieldName?.toFirstUpper().splitCamelCase() ?? "",
          comment: options.isNotEmpty
              ? "Acceptable Values: ${options.map((o) => o.labelText?.toFirstUpper().splitCamelCase() ?? "").toList().join(", ")}"
              : null,
          enumData: options.isNotEmpty
              ? options.map((o) => o.labelText?.toFirstUpper().splitCamelCase() ?? "").toList()
              : null,
        ),
      );
    }
    widget.columnCells.addAll(excelSheetData.columns.cells);
    List<Map<String, dynamic>> items = [];
    SearchResult searchResults = await searchGraphql(
      model: widget.model,
      isMounted: () => mounted,
      nextToken: null,
      filter: widget.filter,
      limit: 1000,
    );
    items.addAll(searchResults.items ?? []);
    while (searchResults.nextToken != null) {
      searchResults = await searchGraphql(
        model: widget.model,
        isMounted: () => mounted,
        nextToken: Uri.encodeComponent(searchResults.nextToken ?? ""),
        filter: widget.filter,
        limit: 1000,
      );
      items.addAll(searchResults.items ?? []);
    }

    // create excel sheet data
    for (Map<String, dynamic> searchResultItem in items) {
      List<ExcelCellData> rowData = [];
      for (MapEntry<String, dynamic> element in searchResultItem.entries) {
        if (widget.fields.map((f) => f.name).contains(element.key)) {
          rowData.add(
            ExcelCellData(
              columnName: element.key.toFirstUpper().splitCamelCase(),
              value: element.value.toString(),
            ),
          );
        }
      }
      if (searchResultItem.containsKey('customFields')) {
        var customFields = jsonDecode(searchResultItem['customFields'] ?? "");
        if (customFields is Map) {
          Map<String, dynamic> customField = Map<String, dynamic>.from(customFields);
          for (MapEntry<String, dynamic> customFieldEntry in customField.entries) {
            if (excelSheetData.columns.cells
                    .map((c) => c.columnName)
                    .contains(customFieldEntry.key) &&
                customFieldEntry.value is Map &&
                (customFieldEntry.value as Map).containsKey(widget.selectedUser?.id ?? "") &&
                customFieldEntry.value[widget.selectedUser?.id ?? ""].toString().trim() != "") {
              rowData.add(
                ExcelCellData(
                  columnName: customFieldEntry.key.toFirstUpper().splitCamelCase(),
                  value: customFieldEntry.value[widget.selectedUser?.id ?? ""].toString().trim(),
                ),
              );
            }
          }
        }
      }
      excelSheetData.rows
          .add(ExcelRowData(cells: rowData, rowIndex: excelSheetData.rows.length + 1));
    }

    String fileName = '${DateTime.now().millisecondsSinceEpoch}_Loader_Tables.xlsx';

    ExcelFileData(
      fileName: fileName,
      sheets: [excelSheetData],
    ).toJson();
    Response response = await apiGatewayPOST(
      server: Uri.parse("$endpoint/excel"),
      payload: ExcelFileData(
        fileName: fileName,
        sheets: [excelSheetData],
      ).toJson(),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      await downloadTempExcelFile(fileName: fileName);
    } else if (mounted) {
      // SchedulerBinding.instance.addPostFrameCallback(
      //   (timeStamp) => _sendSnackBarMessage("failed to get loader file"),
      // );
      // break;
    }
    setState(() {
      isLoading = false;
    });
    widget.completeStep();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: AppBarTheme.of(context).toolbarHeight,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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
        Expanded(
          child: Center(
            child: ElevatedButton(
              onPressed: isLoading ? null : getCustomFieldsLoaderFile,
              child: const Text("Download Loader File"),
            ),
          ),
        ),
        SizedBox(
          height: AppBarTheme.of(context).toolbarHeight,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: widget.completeStep,
                  child: const Text("Next Step"),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> getCustomColumnsWithId({
  required String id,
  required List<TableField> tableFields,
  required ModelType model,
}) async {
  String query = '''
      query _ {
        list${TableField.schema.pluralName}(filter: {userId: {eq: "$id"}, tableSettingCustomFieldsId: {eq: "${model.modelName()}"}, _deleted: {ne: true}}) {
          items {
              ${generateGraphqlQueryFields(schema: TableField.schema)}
            }
          nextToken
        }
      }''';
  Response columnsResponse = await gqlQuery(query);
  Map<String, dynamic>? columnResponseBody =
      jsonDecode(columnsResponse.body)?['data']?['list${TableField.schema.pluralName}'];
  if (columnsResponse.statusCode != 200 || columnResponseBody == null) {
  } else {
    tableFields.addAll(
      columnResponseBody['items'] is List
          ? (columnResponseBody['items'] as List).where((e) => e['_deleted'] != true).map(
                (e) => TableField.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
          : [],
    );
    String? nextToken = columnResponseBody['nextToken'];
    while (nextToken != null) {
      query = '''
      query _ {
        list${TableField.schema.pluralName}(filter: {userId: {eq: "default"}}, nextToken: "$nextToken") {
          items {
              ${generateGraphqlQueryFields(schema: TableField.schema)}
            }
          nextToken
        }
      }''';
      Response columnsResponse = await gqlQuery(query);
      columnResponseBody =
          jsonDecode(columnsResponse.body)?['data']?['list${TableField.schema.pluralName}'];
      tableFields.addAll(
        columnResponseBody?['items'] is List
            ? (columnResponseBody?['items'] as List).where((e) => e['_deleted'] != true).map(
                  (e) => TableField.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
            : [],
      );
      nextToken = columnResponseBody?['nextToken'];
    }
  }
}

Future<List<TableFieldOption>> getAdvisorTableFieldOptions({
  required User? selectedUser,
  required String tableFieldOptionsId,
}) async {
  List<TableFieldOption> tableFieldOptionsList = [];
  if (selectedUser == null) return tableFieldOptionsList;
  SearchResult tableFieldOptions = await searchGraphql(
    model: TableFieldOption.classType,
    isMounted: () => true,
    filter:
        'filter: {and: [{tableFieldOptionsId: {eq:"$tableFieldOptionsId"}},{or: [{repId: {eq : "default"}} ,{repId: {eq : "${selectedUser.id}"}}]}, {_deleted: {ne: true} }]}',
    limit: 1000,
    nextToken: null,
  );
  tableFieldOptionsList.addAll(
    tableFieldOptions.items?.map(TableFieldOption.fromJson).toList() ?? [],
  );
  while (tableFieldOptions.nextToken != null) {
    tableFieldOptions = await searchGraphql(
      nextToken: Uri.encodeComponent(tableFieldOptions.nextToken ?? ""),
      model: TableFieldOption.classType,
      isMounted: () => true,
      filter:
          'filter: {and: [{tableFieldOptionsId: {eq:"$tableFieldOptionsId"}},{or: [{repId: {eq : "default"}} ,{repId: {eq : "${selectedUser.id}"}}]}, {_deleted: {ne: true} }]}',
      limit: 1000,
    );
    tableFieldOptionsList.addAll(
      tableFieldOptions.items?.map(TableFieldOption.fromJson).toList() ?? [],
    );
  }
  return tableFieldOptionsList.sorted(
    (a, b) {
      if (a.labelText == null || b.labelText == null) {
        return 0;
      }
      return a.labelText?.toString().compareTo(
                b.labelText?.toString() ?? "",
              ) ??
          0;
    },
  );
}
