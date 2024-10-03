import 'dart:convert';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/models/ModelProvider.dart';
import 'package:base/providers/auth_service.dart';
import 'package:base/providers/auth_state.dart';
import 'package:base/providers/explorer_provider.dart';
import 'package:base/utilities/extensions/string.dart';
import 'package:base/utilities/requests/graphql.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart';
import 'package:rms/view/explore/custom_fields/custom_fields_uploader/cf_loader.dart';
import 'package:rms/view/explore/explorer_double_tap.dart';
import 'package:rms/view/explore/explorer_layout.dart';
import 'package:rms/view/explore/explorer_data.dart';
import 'package:rms/view/explore/logic/graphql_search.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class ExplorerGraphQL extends StatefulWidget {
  final ModelType<Model> model;
  final Future<void> Function({
    required ModelType<Model> model,
    required List<Map<String, dynamic>> items,
  })? itemsPostProcess;
  final void Function({
    required ModelType<Model> model,
    required List<Widget> itemOptions,
    required List<DataGridRow> selectedRows,
  })? addItemOptions;
  final List<String>? initialHiddenColumns;
  final List<String>? initialColumnOrder;
  final bool loadAll;
  final bool allowOptions;
  final bool allowActions;
  final bool allowPagination;
  final bool persistChips;
  final String searchTerm;
  final int? insertCustomColumns;
  final List<String> initialChips;
  final List<String> initialOrChips;
  final void Function(
    BuildContext context,
    DataGridCellDoubleTapDetails details,
    ModelType model,
  )? onDoubleTap;
  const ExplorerGraphQL({
    super.key,
    required this.model,
    this.itemsPostProcess,
    this.addItemOptions,
    this.initialHiddenColumns,
    this.allowActions = true,
    this.allowOptions = true,
    this.allowPagination = true,
    this.loadAll = false,
    this.searchTerm = "",
    this.insertCustomColumns,
    this.initialColumnOrder,
    this.initialChips = const <String>[],
    this.initialOrChips = const <String>[],
    this.persistChips = true,
    this.onDoubleTap,
  });

  @override
  State<ExplorerGraphQL> createState() => _ExplorerGraphQLState();
}

class _ExplorerGraphQLState extends State<ExplorerGraphQL> {
  ItemsDataSource? itemsDataSource;
  int _rowsPerPage = 500;
  List<GridColumn> columns = [];
  bool isProcessing = true;
  List<Map<String, dynamic>>? customFields;
  String firstIndex = "id";
  ExplorerStateManagement? explorerStateManagement;
  String? tableSettingId;
  bool initializeData = true;
  Alignment cellAlignment = Alignment.centerRight;
  DataPagerController? dataPagerController;
  List<User> users = [];
  User? selectedUser;
  SelectionMode selectionMode = SelectionMode.single;
  List<Map<String, dynamic>> tableFieldOptionsList = [];
  bool updatingOptions = false;

  @override
  void dispose() async {
    if (explorerStateManagement != null) {
      explorerStateManagement!.clearFilters();
    }
    super.dispose();
  }

  @override
  void initState() {
    _initAdvisorsAndColumns();
    super.initState();
  }

  Future<void> _initAdvisorsAndColumns() async {
    itemsDataSource ??= ItemsDataSource(
      getRowsPerPage: rowsPerPage,
      items: [],
      columns: [],
      model: widget.model,
    );
    dataPagerController ??= DataPagerController();
    var storageChips =
        await AuthService().userPool.storage.getItem("${widget.model.modelName()}_chips") ?? [];
    if (widget.initialChips.isNotEmpty || (storageChips is List && storageChips.isNotEmpty)) {
      if (storageChips is List<String> && storageChips.isNotEmpty) {
        for (String chip in storageChips) {
          String chipName = chip.split(":").first;
          if (widget.initialChips.any((c) => c.contains('$chipName:'))) {
            widget.initialChips.removeWhere((ic) => ic.startsWith('$chipName:'));
            setState(() {
              widget.initialChips.add(chip);
            });
          } else if (widget.initialChips.length <= 8) {
            setState(() {
              widget.initialChips.add(chip);
            });
          }
        }
      }
    }
    setState(() {
      isProcessing = true;
    });
    List<String>? groups = AuthState().groups;
    if ([...?AuthState().groups].contains("rms")) {
      SearchResult usersResult = await searchGraphql(
        model: User.classType,
        isMounted: () => mounted,
        nextToken: null,
      );
      users = usersResult.items
              ?.map(User.fromJson)
              .where((u) => u.advisorIds != null && u.advisorIds != [])
              .toList() ??
          [];
      while (usersResult.nextToken != null) {
        usersResult = await searchGraphql(
          model: User.classType,
          isMounted: () => mounted,
          nextToken: Uri.encodeComponent(usersResult.nextToken ?? ""),
        );
        users.addAll(
          usersResult.items
                  ?.map(User.fromJson)
                  .where((u) => u.advisorIds != null && u.advisorIds != [])
                  .toList() ??
              [],
        );
      }
    } else {
      List<Future> futures = [];
      if (groups != null) {
        for (String group in groups) {
          String query = '''
      query _ {
        get${User.schema.name}(${User.ID.fieldName}: "$group") {
          ${generateGraphqlQueryFields(schema: User.schema)}
        }
      }''';
          futures.add(
            gqlQuery(query).then((result) {
              Map? resultMap = jsonDecode(result.body) is Map
                  ? ((jsonDecode(result.body) as Map)['data']?['get${User.schema.name}'])
                  : null;
              if (resultMap != null &&
                  resultMap.containsKey(User.ID.fieldName) &&
                  resultMap.containsKey(User.EMAIL.fieldName) &&
                  resultMap.containsKey(User.ADVISORIDS.fieldName) &&
                  resultMap[User.ADVISORIDS.fieldName] != null &&
                  resultMap[User.ADVISORIDS.fieldName] != []) {
                users.add(User.fromJson(Map<String, dynamic>.from(resultMap)));
              }
            }),
          );
        }
      }
      await Future.wait(futures);
    }
    setState(() {
      selectedUser = users.sorted((a, b) => a.email?.compareTo(b.email ?? "") ?? 0).firstOrNull;
    });
    await itemsDataSource?.setUser(selectedUser);
    if (widget.model == Account.classType) {
      itemsDataSource?.clearFilters(
        columnName: Account.REPID.fieldName.toFirstUpper().splitCamelCase(),
      );
    }
    for (var chip in widget.initialChips) {
      String chipName = chip.split(":").first.trim();
      ModelField? field = ModelProvider.instance.modelSchemas
              .firstWhereOrNull((s) => s.name == widget.model.modelName())
              ?.fields?[
          chipName.split(RegExp(r"\s+")).map((c) => c == "ID" ? "Id" : c).join().toFirstLower()];
      field ??= ModelProvider.instance.modelSchemas
          .firstWhereOrNull((s) => s.name == widget.model.modelName())
          ?.fields?[chipName.split(RegExp(r"\s+")).join().toFirstLower()];
      if (field != null && !{...?itemsDataSource?.queryFilters}.containsKey(field)) {
        await itemsDataSource?.addQueryFilter(
          field: field,
          value: chip.split(":").last.trim(),
        );
      }
    }
    ModelSchema? schema = ModelProvider.instance.modelSchemas
        .firstWhereOrNull((sc) => sc.name.toLowerCase() == widget.model.modelName().toLowerCase());
    if (schema != null) {
      columns = schema.fields?.entries
              .where(
                (e) =>
                    e.value.type.fieldType != ModelFieldTypeEnum.model &&
                    e.value.isReadOnly != true,
              )
              .map<GridColumn>(
                (e) => GridColumn(
                  allowFiltering: e.value.type.fieldType == ModelFieldTypeEnum.string,
                  visible: widget.initialHiddenColumns != null
                      ? !widget.initialHiddenColumns!.contains(e.key)
                      : true,
                  label: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      e.key.toFirstUpper().splitCamelCase(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  columnName: e.key.toFirstUpper().splitCamelCase(),
                ),
              )
              .toList() ??
          [];
      columns.add(
        GridColumn(
          visible: false,
          label: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            alignment: Alignment.centerLeft,
            child: const Text(
              "Version",
              overflow: TextOverflow.ellipsis,
            ),
          ),
          columnName: "Version",
        ),
      );
      if (widget.initialColumnOrder != null) {
        for (String columnName in widget.initialColumnOrder!.reversed) {
          GridColumn? column = columns.firstWhereOrNull(
            (element) =>
                element.columnName.toFirstLower().replaceAll(RegExp(r'\s+'), '') == columnName,
          );
          if (column != null) {
            columns.remove(column);
            columns.insert(0, column);
          }
        }
      }
      List<ModelIndex>? modelIndexes = schema.indexes;
      if (modelIndexes != null) {
        firstIndex = modelIndexes.first.fields.first;
      }
      List<TableField> tableFields = [];
      await getCustomColumnsWithId(id: "default", tableFields: tableFields, model: widget.model);
      if (selectedUser != null) {
        await getCustomColumnsWithId(
          id: selectedUser?.id ?? "",
          tableFields: tableFields,
          model: widget.model,
        );
      }
      for (TableField tableField in tableFields) {
        if (!columns
            .map((c) => c.columnName)
            .contains(tableField.fieldName?.toFirstUpper().splitCamelCase())) {
          GridColumn gridColumn = GridColumn(
            allowFiltering: tableField.fieldType == TableFieldFieldTypeEnum.Text ||
                tableField.fieldType == TableFieldFieldTypeEnum.SingleSelect,
            label: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              alignment: Alignment.centerLeft,
              child: Text(
                tableField.fieldName?.toFirstUpper().splitCamelCase() ?? "",
                overflow: TextOverflow.ellipsis,
              ),
            ),
            columnName: tableField.fieldName?.toFirstUpper().splitCamelCase() ?? "",
          );
          columns.insert(widget.insertCustomColumns ?? columns.length, gridColumn);
          if (customFields == null) {
            customFields = [tableField.toJson()];
          } else {
            customFields?.add(tableField.toJson());
          }
        }
      }
    }
    await itemsDataSource?.buildDataGridRows(newColumns: columns);
    setState(() {
      isProcessing = false;
    });
  }

  Future<void> updateCustomFields({
    required TableField tableField,
    required GraphQLMutationType type,
  }) async {
    switch (type) {
      case GraphQLMutationType.create:
        if (customFields == null) {
          customFields = [tableField.toJson()];
        } else {
          customFields?.add(tableField.toJson());
        }
        GridColumn gridColumn = GridColumn(
          allowFiltering: tableField.fieldType == TableFieldFieldTypeEnum.Text ||
              tableField.fieldType == TableFieldFieldTypeEnum.SingleSelect,
          label: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            alignment: Alignment.centerLeft,
            child: Text(
              tableField.fieldName?.toFirstUpper().splitCamelCase() ?? "",
              overflow: TextOverflow.ellipsis,
            ),
          ),
          columnName: tableField.fieldName?.toFirstUpper().splitCamelCase() ?? "",
        );
        columns.insert(widget.insertCustomColumns ?? columns.length, gridColumn);
        break;
      case GraphQLMutationType.update:
        if (customFields != null) {
          int customFieldIndex =
              customFields?.indexWhere((cf) => cf[TableField.ID.fieldName] == tableField.id) ?? -1;
          if (customFieldIndex >= 0) {
            customFields?[customFieldIndex] = tableField.toJson();
          }
        }
        await itemsDataSource?.initData();
        break;
      case GraphQLMutationType.delete:
        columns
            .removeWhere((c) => c.columnName.toLowerCase() == tableField.fieldName?.toLowerCase());
        customFields?.removeWhere(
          (cf) =>
              cf[TableField.FIELDNAME.fieldName].toString().toLowerCase() ==
              tableField.fieldName?.toLowerCase(),
        );
        break;
    }
    await itemsDataSource?.buildDataGridRows(newColumns: columns);
  }

  int rowsPerPage({int? value}) {
    if (value != null) {
      setState(() {
        _rowsPerPage = value;
      });
    }
    return _rowsPerPage;
  }

  final DataGridController _dataGridController = DataGridController();
  final ScrollController _verticalScrollControllerSFGrid = ScrollController();

  List<Widget> _buildItemWidgets() {
    List<Widget> returnWidgets = [];
    if (widget.addItemOptions != null) {
      widget.addItemOptions!(
        model: widget.model,
        itemOptions: returnWidgets,
        selectedRows: _dataGridController.selectedRows,
      );
    }

    if (AuthState().groups?.contains("rms") ?? false) {
      returnWidgets.add(
        IconButton(
          onPressed: _dataGridController.selectedRows.length == 1
              ? () {
                  List<DataGridCell> cells = _dataGridController.selectedRows.first.getCells();
                  String elementId = "";
                  for (var cell in cells) {
                    if (cell.columnName.toLowerCase() == firstIndex.toLowerCase()) {
                      elementId = cell.value.toString();
                    }
                  }
                  if (context.mounted && elementId != "") {
                    String fullPath = GoRouterState.of(context).fullPath ?? "";
                    String newPath = "$fullPath/$elementId";
                    if (fullPath.endsWith(":iid")) {
                      newPath = fullPath.replaceFirst(':iid', elementId);
                    }
                    GoRouter.of(context).go(newPath);
                    DefaultTabController.of(context).animateTo(1);
                  }
                }
              : null,
          icon: const Icon(Icons.edit_outlined),
        ),
      );
      returnWidgets.add(
        IconButton(
          onPressed: _dataGridController.selectedRows.isNotEmpty == true
              ? () {
                  List<DataGridRow> selectedRows = _dataGridController.selectedRows;
                  showDialog<bool>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Delete Items:'),
                        content: SingleChildScrollView(
                          child: ListBody(
                            children: <Widget>[
                              Text(
                                'Delete ${selectedRows.length == 1 ? 'this item?' : 'these ${selectedRows.length} items?'}',
                              ),
                            ],
                          ),
                        ),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('Cancel'),
                            onPressed: () {
                              Navigator.of(context).pop<bool>(false);
                            },
                          ),
                          TextButton(
                            child: const Text('Confirm'),
                            onPressed: () {
                              Navigator.of(context).pop<bool>(true);
                            },
                          ),
                        ],
                      );
                    },
                  ).then((value) async {
                    if (value == true) {
                      List<Future<void>> futures = [];
                      for (DataGridRow selectedRow in selectedRows) {
                        futures.add(
                          gqlMutation(
                            input: {
                              firstIndex:
                                  '${selectedRow.getCells().firstWhereOrNull((c) => c.columnName.toLowerCase() == firstIndex.toLowerCase())?.value}',
                              "_version": int.tryParse(
                                '${selectedRow.getCells().firstWhereOrNull(
                                      (c) => c.columnName == "Version",
                                    )?.value}',
                              ),
                            },
                            model: widget.model,
                            mutationType: GraphQLMutationType.delete,
                          ).then(
                            (response) {
                              var gqlDataFound = jsonDecode(response.body)['data'] != null;
                              if (response.statusCode == 200 && gqlDataFound) {
                                itemsDataSource?.rows.remove(selectedRow);
                              }
                            },
                          ),
                        );
                        if (futures.length >= 100) {
                          await Future.wait(futures);
                          futures.clear();
                        }
                      }
                      await Future.wait(futures);
                    }
                  });
                }
              : null,
          icon: const Icon(Icons.delete_outline),
        ),
      );
    }
    if (widget.model == Account.classType) {
      returnWidgets.add(
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: PopupMenuButton(
            initialValue: selectedUser?.email ?? "",
            onSelected: (value) async {
              setState(() {
                selectedUser = users.firstWhereOrNull((u) => u.id == value);
              });
              await itemsDataSource?.setUser(selectedUser);
              itemsDataSource?.clearFilters(
                columnName: Account.REPID.fieldName.toFirstUpper().splitCamelCase(),
              );
              for (String id in selectedUser?.advisorIds ?? []) {
                itemsDataSource?.addFilter(
                  Account.REPID.fieldName.toFirstUpper().splitCamelCase(),
                  FilterCondition(
                    type: FilterType.equals,
                    value: id,
                  ),
                );
              }
            },
            tooltip: selectedUser?.email ?? "",
            itemBuilder: (context) {
              List<PopupMenuItem> items = [];
              for (User user in users.sorted((a, b) => a.email?.compareTo(b.email ?? "") ?? 0)) {
                items.add(
                  PopupMenuItem(
                    value: user.id,
                    child: Text(user.email ?? ""),
                  ),
                );
              }
              return items;
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_drop_down_outlined),
                Icon(Icons.business_outlined),
              ],
            ),
          ),
        ),
      );
    }
    if (widget.model == Commission.classType) {
      returnWidgets.add(
        IconButton(
          onPressed: _dataGridController.selectedRows.isNotEmpty == true
              ? () {
                  List<DataGridRow> selectedRows = _dataGridController.selectedRows;
                  showDialog<bool>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Cancel and Rebill Items:'),
                        content: SingleChildScrollView(
                          child: ListBody(
                            children: <Widget>[
                              Text(
                                'Cancel and Rebill ${selectedRows.length == 1 ? 'this item?' : 'these ${selectedRows.length} items?'}',
                              ),
                            ],
                          ),
                        ),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('Cancel'),
                            onPressed: () {
                              Navigator.of(context).pop<bool>(false);
                            },
                          ),
                          TextButton(
                            child: const Text('Confirm'),
                            onPressed: () {
                              Navigator.of(context).pop<bool>(true);
                            },
                          ),
                        ],
                      );
                    },
                  ).then((value) async {
                    if (value == true) {
                      List<Future<void>> futures = [];
                      String columnName = "";
                      dynamic columnValue;
                      for (DataGridRow selectedRow in selectedRows) {
                        Map<String, dynamic> rebilledPendingCommissionItem = {};
                        rebilledPendingCommissionItem[firstIndex] = UUID.getUUID();
                        for (int rowContentsIndex = 0;
                            rowContentsIndex < selectedRow.getCells().length;
                            rowContentsIndex++) {
                          columnName = selectedRow
                              .getCells()[rowContentsIndex]
                              .columnName
                              .toFirstLower()
                              .split(" ")
                              .join();
                          columnValue = selectedRow.getCells()[rowContentsIndex].value;
                          //Check if column is _version, id, or if the value is empty
                          if (selectedRow.getCells()[rowContentsIndex].columnName.toLowerCase() !=
                                  firstIndex &&
                              selectedRow.getCells()[rowContentsIndex].columnName != "Version" &&
                              columnValue != "") {
                            //Copy all values from original commission, except for negating the net commission value
                            rebilledPendingCommissionItem[columnName] =
                                (columnName == Commission.COMMISSIONNET.fieldName)
                                    ? -columnValue
                                    : columnValue;
                          }
                        }
                        futures.add(gqlMutation(
                          input: rebilledPendingCommissionItem,
                          model: ModelProvider().getModelTypeByModelName("PendingCommission"),
                          mutationType: GraphQLMutationType.create,
                        ));
                        if (futures.length >= 100) {
                          await Future.wait(futures);
                          futures.clear();
                        }
                      }
                      await Future.wait(futures);
                    }
                  });
                }
              : null,
          icon: const Icon(Icons.build_outlined),
        ),
      );
    }
    if (ModelProvider.instance.modelSchemas
            .firstWhereOrNull((ms) => ms.name == widget.model.modelName())
            ?.fields
            ?.keys
            .contains("customFields") ==
        true) {
      returnWidgets.add(
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: PopupMenuButton(
            initialValue: selectedUser?.email ?? "",
            onSelected: (value) async {
              setState(() {
                selectedUser = users.firstWhereOrNull((u) => u.id == value);
              });
              await itemsDataSource?.setUser(selectedUser);
            },
            tooltip: selectedUser?.email ?? "",
            itemBuilder: (context) {
              List<PopupMenuItem> items = [];
              for (User user in users.sorted((a, b) => a.email?.compareTo(b.email ?? "") ?? 0)) {
                items.add(
                  PopupMenuItem(
                    value: user.id,
                    child: Text(user.email ?? ""),
                  ),
                );
              }
              return items;
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_drop_down_outlined),
                Icon(Icons.discount_outlined),
              ],
            ),
          ),
        ),
      );
    }
    returnWidgets.add(
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: PopupMenuButton(
          onSelected: (value) => setState(() {
            selectionMode =
                enumFromString<SelectionMode>(value, SelectionMode.values) ?? SelectionMode.none;
          }),
          tooltip: "Selection Mode",
          itemBuilder: (context) {
            List<PopupMenuItem> items = [];
            for (SelectionMode mode in [
              SelectionMode.single,
              SelectionMode.multiple,
            ]) {
              items.add(
                PopupMenuItem(
                  value: mode.name,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(mode.name.toFirstUpper()),
                      const SizedBox(
                        width: 4,
                      ),
                      Icon(selectionMode == mode ? Icons.check_outlined : null),
                    ],
                  ),
                  onTap: () {
                    setState(
                      () {
                        selectionMode = mode;
                      },
                    );
                  },
                ),
              );
            }
            items.add(
              PopupMenuItem(
                value: "Clear",
                onTap: () => setState(() {
                  _dataGridController.selectedRows.clear();
                  _dataGridController.selectedRow = null;
                }),
                child: const Text("Clear"),
              ),
            );
            return items;
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_drop_down_outlined),
              Icon(Icons.check_box_outlined),
            ],
          ),
        ),
      ),
    );
    return returnWidgets;
  }

  @override
  Widget build(BuildContext context) {
    return isProcessing
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                Text("checking for custom columns"),
              ],
            ),
          )
        : itemsDataSource != null
            ? GraphQLExplore(
                persistChips: widget.persistChips,
                explorerItemOptions: _buildItemWidgets(),
                initializeData: initializeData,
                loadAll: widget.loadAll,
                allowOptions: widget.allowOptions,
                allowActions: widget.allowActions,
                allowPagination: widget.allowPagination,
                updateCustomFields: updateCustomFields,
                itemsPostProcess: widget.itemsPostProcess,
                customFields: customFields,
                firstIndex: firstIndex,
                rowsPerPage: rowsPerPage,
                dataPagerController: dataPagerController,
                sfDataGrid: SfDataGrid(
                  verticalScrollController: _verticalScrollControllerSFGrid,
                  rowHeight: 30,
                  gridLinesVisibility: GridLinesVisibility.both,
                  headerGridLinesVisibility: GridLinesVisibility.both,
                  groupCaptionTitleFormat: '{ColumnName} : {Key} - {ItemsCount}',
                  allowExpandCollapseGroup: true,
                  controller: _dataGridController,
                  rowsPerPage: _rowsPerPage,
                  source: itemsDataSource!,
                  columns: columns,
                  onSelectionChanged: (addedRows, removedRows) => setState(() {}),
                  columnWidthMode: ColumnWidthMode.auto,
                  showColumnHeaderIconOnHover: true,
                  allowColumnsDragging: true,
                  allowSorting: true,
                  allowFiltering: true,
                  isScrollbarAlwaysShown: true,
                  selectionMode: selectionMode,
                  onColumnDragging: onColumnDragging,
                  allowColumnsResizing: true,
                  columnResizeMode: ColumnResizeMode.onResizeEnd,
                  onColumnResizeUpdate: onColumnResizeUpdate,
                  onCellDoubleTap: (details) => onCellDoubleTap(details, context),
                  loadMoreViewBuilder: (BuildContext context, LoadMoreRows loadMoreRows) {
                    if (itemsDataSource?.nextToken == null) return null;
                    Future<String> loadRows() async {
                      await loadMoreRows();
                      setState(() {});
                      return Future<String>.value('Completed');
                    }

                    return FutureBuilder<String>(
                      initialData: 'loading',
                      future: loadRows(),
                      builder: (context, snapShot) {
                        if (snapShot.data == 'loading') {
                          return Container(
                            height: 60.0,
                            width: double.infinity,
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(),
                          );
                        } else {
                          return SizedBox.fromSize(size: Size.zero);
                        }
                      },
                    );
                  },
                ),
                model: widget.model,
                initialChips: widget.initialChips,
                initialOrChips: widget.initialOrChips,
              )
            : const Text("Unable to load data");
  }

  void onCellDoubleTap(DataGridCellDoubleTapDetails details, BuildContext context) async {
    if (details.rowColumnIndex.rowIndex <= 0) return;
    GridColumn column = details.column;
    TableField? tableField = customFields?.map(TableField.fromJson).lastWhereOrNull(
          (tf) => tf.fieldName?.toLowerCase() == details.column.columnName.toLowerCase(),
        );
    List<String> customFieldNames = [];
    for (Map customFieldMap in customFields ?? <Map>[]) {
      if (customFieldMap.containsKey("fieldName")) {
        customFieldNames.add(customFieldMap["fieldName"].toString().toLowerCase());
      }
    }
    if (tableField != null) {
      DataGridRow? row = itemsDataSource?.rows[details.rowColumnIndex.rowIndex - 1];
      Map<String, dynamic> item = {};
      if (row != null) {
        item.addEntries(
          row.getCells().map((cell) => MapEntry(cell.columnName, cell.value)),
        );
      }

      dynamic result = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Edit: ${details.column.columnName}'),
            content: Container(
              constraints: const BoxConstraints(maxHeight: 130, maxWidth: 300),
              child: ExplorerDoubleTap(
                item: item,
                selectedUser: selectedUser,
                details: details,
                tableField: tableField,
              ),
            ),
          );
        },
      );

      if (result != null) {
        List<String> customFieldNames = [];
        for (var element in customFields ?? <Map>[]) {
          if (element.containsKey("fieldName")) {
            customFieldNames.add(element["fieldName"].toString().toLowerCase());
          }
        }
        ModelSchema? schema = ModelProvider.instance.modelSchemas
            .firstWhereOrNull((ms) => ms.name == widget.model.modelName());
        if (schema != null) {
          String query = '''
      query _ {
        get${widget.model.modelName()}($firstIndex: "${item[firstIndex.toFirstUpper().splitCamelCase()]}") {
          ${generateGraphqlQueryFields(schema: schema)}
        }
      }''';
          Response getResult = await gqlQuery(query);
          var getResultBody = jsonDecode(getResult.body);
          if (getResultBody is Map &&
              getResultBody['data'] != null &&
              getResultBody['data'] is Map &&
              getResultBody['data']?['get${widget.model.modelName()}'] != null) {
            Map<String, dynamic> getItem =
                Map<String, dynamic>.from(getResultBody['data']?['get${widget.model.modelName()}']);
            if (getItem.containsKey('customFields') &&
                jsonDecode(getItem['customFields'].toString()) is Map) {
              Map customFields = jsonDecode(getItem['customFields'].toString());
              if (customFields.containsKey(tableField.id) && customFields[tableField.id] is Map) {
                customFields[tableField.id][selectedUser?.id] = result;
              } else {
                customFields[tableField.id] = {
                  selectedUser?.id: result,
                };
              }
              getItem['customFields'] = customFields;
            } else {
              getItem['customFields'] = {
                tableField.id: {
                  selectedUser?.id: result,
                },
              };
            }
            getItem['customFields'] = jsonEncode(getItem['customFields']);
            int currentVersion = 1;
            GraphQLMutationType graphQLMutationType = GraphQLMutationType.update;
            Response response = await gqlMutation(
              input: getItem,
              model: widget.model,
              mutationType: graphQLMutationType,
            );
            var gqlDataFound = jsonDecode(response.body)['data'] != null;
            if (response.statusCode == 200 && gqlDataFound) {
              row?.getCells()[details.rowColumnIndex.columnIndex] =
                  DataGridCell(columnName: column.columnName, value: result);
              try {
                currentVersion = int.tryParse(
                      jsonDecode(response.body)['data']
                              ['${graphQLMutationType.name}${widget.model.modelName()}']['_version']
                          .toString(),
                    ) ??
                    1;
              } catch (e) {
                safePrint(e);
              }
              DataGridCell? versionCell =
                  row?.getCells().firstWhereOrNull((r) => r.columnName == "Version");
              if (versionCell != null) {
                row?.getCells()[row.getCells().indexOf(versionCell)] =
                    DataGridCell(columnName: "Version", value: currentVersion);
              }
            }
          }
        }
        if (row != null) {
          itemsDataSource?.items[details.rowColumnIndex.rowIndex - 1] = {
            for (var c in row.getCells()) c.columnName: c.value,
          };
          itemsDataSource?.notifyListeners();
        }
      }
    } else if (widget.onDoubleTap != null && context.mounted) {
      widget.onDoubleTap!(context, details, widget.model);
    }
  }

  bool onColumnResizeUpdate(ColumnResizeUpdateDetails args) {
    List<GridColumn> tempColumns = [];
    for (GridColumn column in columns) {
      if (column.columnName == args.column.columnName &&
          column.columnName != 'null' &&
          column.columnName.trim() != '') {
        tempColumns.add(
          GridColumn(
            width: args.width,
            columnName: column.columnName,
            label: column.label,
            allowEditing: column.allowEditing,
            allowFiltering: column.allowEditing,
            visible: column.visible,
            allowSorting: column.allowSorting,
            autoFitPadding: column.autoFitPadding,
            columnWidthMode: column.columnWidthMode,
            filterIconPadding: column.filterIconPadding,
            filterIconPosition: column.filterIconPosition,
            filterPopupMenuOptions: column.filterPopupMenuOptions,
            maximumWidth: column.maximumWidth,
            minimumWidth: column.minimumWidth,
            sortIconPosition: column.sortIconPosition,
          ),
        );
      } else {
        tempColumns.add(column);
      }
    }
    itemsDataSource?.buildDataGridRows(newColumns: tempColumns);
    setState(() {
      columns = tempColumns;
    });
    return true;
  }

  bool onColumnDragging(DataGridColumnDragDetails details) {
    if (details.action == DataGridColumnDragAction.dropped && details.to != null) {
      final GridColumn rearrangeColumn = columns[details.from];
      columns.removeAt(details.from);
      columns.insert(details.to!, rearrangeColumn);
      itemsDataSource?.buildDataGridRows(newColumns: columns);
      itemsDataSource?.notifyListeners();
    }
    return true;
  }
}
