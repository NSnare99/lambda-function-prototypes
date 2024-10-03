import 'dart:async';
import 'dart:convert';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/models/ModelProvider.dart';
import 'package:base/utilities/extensions/string.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:rms/view/explore/logic/graphql_search.dart';
import 'package:rms/view/upload/upload_steps/logic/string_to_scalar.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class ItemsDataSource extends DataGridSource {
  ItemsDataSource({
    required this.items,
    required this.columns,
    required this.model,
    required this.getRowsPerPage,
  }) {
    initData();
  }
  List<TableField> tableFields = [];
  Map<String, ModelField>? fields;
  Future<void> initData() async {
    if (fields == null) {
      for (ModelSchema schema in ModelProvider.instance.modelSchemas) {
        if (schema.name.toLowerCase() == model.modelName().toLowerCase()) {
          fields = schema.fields;
        }
      }
    }
    if (fields?.keys.contains("customFields") == true) {
      List<Map<String, dynamic>> tableItems = [];
      SearchResult tableFieldResponse = await searchGraphql(
        model: TableField.classType,
        isMounted: () => true,
        nextToken: null,
      );
      tableItems.addAll(tableFieldResponse.items ?? []);
      while (tableFieldResponse.nextToken != null) {
        tableFieldResponse = await searchGraphql(
          model: TableField.classType,
          isMounted: () => true,
          nextToken: Uri.encodeComponent(tableFieldResponse.nextToken ?? ""),
        );
        tableItems.addAll(tableFieldResponse.items ?? []);
      }
      tableFields = tableItems.map(TableField.fromJson).toList();
    }
    await handleLoadMoreRows();
  }

  List<Map<String, dynamic>> items = [];
  List<GridColumn> columns = [];
  List<DataGridRow> dataGridRows = [];
  ModelType<Model> model;
  dynamic newCellValue;
  StreamController<bool> loadingController = StreamController<bool>();
  Alignment cellAlignment = Alignment.centerLeft;
  Map<ModelField, String> queryFilters = {};
  Map<ModelField, String> orQueryFilters = {};
  Map<ModelField, bool> equalFilters = {};
  Map<ModelField, bool> matchPhraseFilters = {};
  Map<ModelField, bool> wildCardFilters = {};
  String? nextToken;
  int Function() getRowsPerPage;
  User? selectedUser;
  String? sortField;

  Future<void> setUser(User? user) async {
    selectedUser = user;
    await buildDataGridRows();
  }

  Future<void> setSortField(String? value) async {
    sortField = value;
  }

  Future<void> addQueryFilter({
    required ModelField field,
    required String value,
    bool? isEqual,
    bool? isMatchPhrase,
    bool? isWildcard,
    bool? isOrFilter,
  }) async {
    nextToken = null;
    if (isOrFilter != null) {
      orQueryFilters.addAll({field: value});
    } else {
      queryFilters.addAll({field: value});
    }

    if (isEqual != null) {
      equalFilters.addAll({field: isEqual});
    }
    if (isMatchPhrase != null) {
      matchPhraseFilters.addAll({field: isMatchPhrase});
    }
    if (isWildcard != null) {
      wildCardFilters.addAll({field: isWildcard});
    }
  }

  Future<void> removeQueryFilter({required ModelField field}) async {
    nextToken = null;
    queryFilters.removeWhere(
      (key, value) => key == field,
    );
  }

  Future<void> clearQueryFilter() async {
    nextToken = null;
    queryFilters.clear();
  }

  Future<void> clearOrQueryFilter() async {
    nextToken = null;
    orQueryFilters.clear();
  }

  Future<void> setCellAlgnment({required Alignment alignment}) async {
    cellAlignment = alignment;
    await buildDataGridRows();
  }

  Future<void> buildDataGridRows({List<GridColumn>? newColumns}) async {
    if (newColumns != null) {
      columns = newColumns;
    }
    if (fields?.keys.contains("customFields") == true) {
      dataGridRows = items.map<DataGridRow>((item) {
        Map<String, dynamic>? customFieldValues =
            item["Custom Fields"] != null && item["Custom Fields"] != ""
                ? jsonDecode(item['Custom Fields'])
                : null;
        return DataGridRow(
          cells: columns.map<DataGridCell>((column) {
            Map? customJSON = customFieldValues?[tableFields
                        .firstWhereOrNull(
                          (tf) => tf.fieldName?.toLowerCase() == column.columnName.toLowerCase(),
                        )
                        ?.id ??
                    ""] ??
                customFieldValues?[column.columnName];
            return DataGridCell(
              columnName: column.columnName,
              value: customJSON is Map
                  ? (customJSON[selectedUser?.id] ?? "")
                  : (item[column.columnName] ?? customJSON ?? ""),
            );
          }).toList(),
        );
      }).toList();
    } else {
      dataGridRows = items.map<DataGridRow>(
        (item) {
          return DataGridRow(
            cells: columns.map<DataGridCell>((column) {
              return DataGridCell(
                columnName: column.columnName,
                value: item[column.columnName] ?? "",
              );
            }).toList(),
          );
        },
      ).toList();
    }
    if (fields?.keys.contains("customFields") == true) {
      columns.removeWhere(
        (c) => c.columnName.split(RegExp(r'\s+')).join().toFirstLower() == 'customFields',
      );
    }
    notifyListeners();
  }

  @override
  List<DataGridRow> get rows => dataGridRows;

  @override
  DataGridRowAdapter? buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map((dataGridCell) {
        return Container(
          alignment: cellAlignment,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            dataGridCell.value.toString(),
          ),
        );
      }).toList(),
    );
  }

  @override
  Future<void> handleLoadMoreRows() async {
    String filter = await generateFilter(
      model,
      queryFilters,
      orQueryFilters,
      equalValues: equalFilters,
      matchPhraseValues: matchPhraseFilters,
      wildCardValues: wildCardFilters,
    );
    SearchResult searchResult = await searchGraphql(
      limit: getRowsPerPage(),
      model: model,
      isMounted: () => true,
      filter: filter,
      nextToken: nextToken != null ? Uri.encodeComponent(nextToken!) : null,
      friendlyNames: true,
      sortField: sortField,
    );
    items.addAll(searchResult.items ?? []);
    nextToken = searchResult.nextToken;
    await buildDataGridRows();
  }

  bool isSuspend = true;

  @override
  Future<void> performSorting(List<DataGridRow> rows) async {
    if (!isSuspend) return;
    if (sortedColumns.isEmpty || rows.isEmpty) return;
    isSuspend = false;

    for (int i = 0; i < sortedColumns.length; i++) {
      dataGridRows = await _sortRowsAsync(rows, sortedColumns[i]);
      notifyListeners();
    }

    isSuspend = true;
  }

  Future<List<DataGridRow>> _sortRowsAsync(
    List<DataGridRow> rows,
    SortColumnDetails sortColumn,
  ) async {
    // Create a list of tuples with each row and its comparison value
    List<MapEntry<DataGridRow, int>> rowComparisons = [];

    for (var row in rows) {
      int comparisonValue = await _compareRowWithOthers(row, rows, sortColumn);
      rowComparisons.add(MapEntry(row, comparisonValue));
    }

    // Sort the list based on the comparison values
    rowComparisons.sort((a, b) => a.value.compareTo(b.value));

    // Return the sorted rows
    return rowComparisons.map((entry) => entry.key).toList();
  }

  Future<int> _compareRowWithOthers(
    DataGridRow row,
    List<DataGridRow> rows,
    SortColumnDetails sortColumn,
  ) async {
    // Implement your comparison logic here
    // Compare the row against other rows in the list
    // This example just returns 0, but you'll want to use your custom logic
    // Note: This will need to change depending on your specific comparison requirements
    int comparisonResult = 0;

    for (var otherRow in rows) {
      if (row != otherRow) {
        comparisonResult += await _compareDataGrids(row, otherRow, sortColumn);
      }
    }

    return comparisonResult;
  }

  Future<int> _compareDataGrids(
    DataGridRow? a,
    DataGridRow? b,
    SortColumnDetails sortColumn,
  ) async {
    ModelField? field = fields?[sortColumn.name.replaceAll(RegExp(r'\s+'), '').toFirstLower()];
    ModelFieldTypeEnum? modelFieldTypeEnum = field?.type.fieldType;
    dynamic value1 = a
        ?.getCells()
        .firstWhereOrNull((element) => element.columnName == sortColumn.name)
        ?.value
        .toString();
    dynamic value2 = b
        ?.getCells()
        .firstWhereOrNull((element) => element.columnName == sortColumn.name)
        ?.value
        .toString();

    if (modelFieldTypeEnum != null && field != null) {
      value1 = await processValue(
        fieldTypeEnum: modelFieldTypeEnum,
        field: field,
        value: value1 != null ? value1.toString() : "",
        columnName: sortColumn.name.replaceAll(RegExp(r'\s+'), '').toFirstLower(),
        model: model,
        enums: {},
      ).catchError((_) => null);
      value2 = await processValue(
        fieldTypeEnum: modelFieldTypeEnum,
        field: field,
        value: value2 != null ? value2.toString() : "",
        columnName: sortColumn.name.replaceAll(RegExp(r'\s+'), '').toFirstLower(),
        model: model,
        enums: {},
      ).catchError((_) => null);
    }

    if (value1 == null || value2 == null) {
      return 0;
    }

    // Handle String comparison
    if (value1 is String && value2 is String) {
      return _compareString(value1, value2, sortColumn.sortDirection);
    }
    // Handle Number comparison
    else if (value1 is num && value2 is num) {
      return _compareNum(value1, value2, sortColumn.sortDirection);
    }
    // Handle DateTime comparison
    else if (value1 is DateTime && value2 is DateTime) {
      return _compareDateTime(value1, value2, sortColumn.sortDirection);
    }

    // For unsupported types, or if both values are not of the same type, fallback to default.
    return 0;
  }

  int _compareString(String value1, String value2, DataGridSortDirection direction) {
    final comparison = value1.toLowerCase().compareTo(value2.toLowerCase());
    return direction == DataGridSortDirection.ascending ? comparison : -comparison;
  }

  int _compareNum(num value1, num value2, DataGridSortDirection direction) {
    final comparison = value1.compareTo(value2);
    return direction == DataGridSortDirection.ascending ? comparison : -comparison;
  }

  int _compareDateTime(DateTime value1, DateTime value2, DataGridSortDirection direction) {
    final comparison = value1.compareTo(value2);
    return direction == DataGridSortDirection.ascending ? comparison : -comparison;
  }
}
