import 'dart:async';
import 'dart:convert';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/models/ModelProvider.dart';
import 'package:base/providers/auth_state.dart';
import 'package:base/utilities/extensions/string.dart';
import 'package:base/utilities/requests/graphql.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:rms/view/explore/custom_fields/custom_fields_uploader/cf_upload_layout.dart';
import 'package:rms/view/explore/explorer_data.dart';
import 'package:rms/view/explore/logic/graphql_search.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class ExplorerCustomFieldsSettings extends StatefulWidget {
  final Future<void> Function({
    required TableField tableField,
    required GraphQLMutationType type,
  })? updateCustomFields;
  final ModelType<Model> model;
  final Future<void> Function(bool value) showCustomFieldSettings;
  final ItemsDataSource itemsDataSource;
  const ExplorerCustomFieldsSettings({
    super.key,
    required this.showCustomFieldSettings,
    required this.model,
    required this.itemsDataSource,
    this.updateCustomFields,
  });

  @override
  State<ExplorerCustomFieldsSettings> createState() => _ExplorerCustomFieldsSettingsState();
}

class _ExplorerCustomFieldsSettingsState extends State<ExplorerCustomFieldsSettings> {
  TableField? selectedField;
  bool updating = false;
  bool addMode = false;
  bool showMenu = true;
  bool showUpload = false;
  bool isSavingUpload = false;
  List<String> advisors = [];
  List<User> users = [];
  List<TableField> tableFieldsList = [];
  List<Map<String, dynamic>> tableFieldOptionsList = [];
  User? selectedUser;
  List<ModelField> fields = [];

  @override
  void initState() {
    _getNextCustomFields();
    super.initState();
  }

  Future<void> _getNextCustomFields() async {
    setState(() {
      updating = true;
    });
    List<String>? groups = AuthState().groups;
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
                resultMap.containsKey(User.ADVISORIDS.fieldName)) {
              users.add(User.fromJson(Map<String, dynamic>.from(resultMap)));
            }
          }),
        );
      }
    }
    await Future.wait(futures);
    setState(() {
      selectedUser = users.sorted((a, b) => a.email?.compareTo(b.email ?? "") ?? 0).firstOrNull;
      updating = false;
    });
    if (widget.model == Client.classType) {
      fields = Client.schema.fields?.values
              .where(
                (f) => [
                  Client.ID.fieldName,
                  Client.FIRSTNAME.fieldName,
                  Client.LASTNAME.fieldName,
                  Client.BIRTHDATE.fieldName,
                ].contains(f.name),
              )
              .toList() ??
          [];
    } else {
      ModelSchema? schema = ModelProvider.instance.modelSchemas
          .firstWhereOrNull((ms) => ms.name == widget.model.modelName());
      fields = schema?.fields?.values
              .where((mf) => mf.name == schema.indexes?.first.fields.first)
              .toList() ??
          [];
    }
    await _getTableField();
  }

  Future<void> _getAdvisorTableFieldOptions() async {
    setState(() {
      updating = true;
    });
    SearchResult tableFieldOptions = await searchGraphql(
      model: TableFieldOption.classType,
      isMounted: () => true,
      filter:
          'filter: {and: [{tableFieldOptionsId: {eq:"${selectedField?.id}"}},{or: [{repId: {eq : "default"}} ,{repId: {eq : "${selectedUser?.id}"}}]}, {_deleted: {ne: true} }]}',
      limit: 1000,
      nextToken: null,
    );
    setState(() {
      tableFieldOptionsList = tableFieldOptions.items?.sorted(
            (a, b) {
              if (a[TableFieldOption.LABELTEXT.fieldName] == null ||
                  b[TableFieldOption.LABELTEXT.fieldName] == null) {
                return 0;
              }
              return a[TableFieldOption.LABELTEXT.fieldName]?.toString().compareTo(
                        b[TableFieldOption.LABELTEXT.fieldName]?.toString() ?? "",
                      ) ??
                  0;
            },
          ) ??
          [];
      updating = false;
    });
  }

  Future<void> _getTableField({bool stateUpdate = true, TableField? selectedTableField}) async {
    if (stateUpdate && mounted) {
      setState(() {
        updating = true;
      });
    }
    tableFieldsList.clear();
    SearchResult tableFieldResult = await searchGraphql(
      model: TableField.classType,
      isMounted: () => true,
      limit: 1000,
      filter:
          'filter: {userId: {eq: "default"}, tableSettingCustomFieldsId: {eq: "${widget.model.modelName()}"},_deleted: {ne: true} }',
      nextToken: null,
    );
    tableFieldsList.addAll(tableFieldResult.items?.map(TableField.fromJson) ?? []);
    while (tableFieldResult.nextToken != null) {
      tableFieldResult = await searchGraphql(
        model: TableField.classType,
        isMounted: () => true,
        limit: 1000,
        filter:
            'filter: {userId: {eq: "default"}, tableSettingCustomFieldsId: {eq: "${widget.model.modelName()}"},_deleted: {ne: true} }',
        nextToken: null,
      );
      tableFieldsList.addAll(tableFieldResult.items?.map(TableField.fromJson) ?? []);
    }
    tableFieldResult = await searchGraphql(
      model: TableField.classType,
      isMounted: () => true,
      limit: 1000,
      filter:
          'filter: {userId: {eq: "${selectedUser?.id}"}, tableSettingCustomFieldsId: {eq: "${widget.model.modelName()}"},_deleted: {ne: true} }',
      nextToken: null,
    );
    tableFieldsList.addAll(tableFieldResult.items?.map(TableField.fromJson) ?? []);
    while (tableFieldResult.nextToken != null) {
      tableFieldResult = await searchGraphql(
        model: TableField.classType,
        isMounted: () => true,
        limit: 1000,
        filter:
            'filter: {userId: {eq: "${selectedUser?.id}"}, tableSettingCustomFieldsId: {eq: "${widget.model.modelName()}"},_deleted: {ne: true} }',
        nextToken: null,
      );
      tableFieldsList.addAll(tableFieldResult.items?.map(TableField.fromJson) ?? []);
    }
    tableFieldsList.sort((a, b) => a.fieldName?.compareTo(b.fieldName ?? "") ?? 0);
    if (mounted) {
      setState(() {
        selectedField =
            selectedTableField ?? (tableFieldsList.isNotEmpty ? tableFieldsList.first : null);
        updating = false;
        addMode = false;
      });
    }
    await _getAdvisorTableFieldOptions();
  }

  @override
  Widget build(BuildContext context) {
    ScrollController sideBarScrollController = ScrollController();
    return showUpload
        ? CustomFieldsUploader(
            selectedUser: selectedUser,
            model: widget.model,
            back: isSavingUpload
                ? null
                : () async {
                    if (mounted) {
                      setState(() {
                        isSavingUpload = true;
                      });
                    }
                    widget.itemsDataSource.items.clear();
                    widget.itemsDataSource.nextToken = null;
                    await widget.itemsDataSource.handleLoadMoreRows();
                    if (mounted) {
                      setState(() {
                        isSavingUpload = false;
                        showUpload = !showUpload;
                      });
                    }
                  },
            fields: fields,
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    height: AppBarTheme.of(context).toolbarHeight,
                    child: IconButton(
                      onPressed: () {
                        setState(() {
                          showMenu = !showMenu;
                        });
                      },
                      icon: const Icon(Icons.menu_outlined),
                    ),
                  ),
                  const SizedBox(
                    width: 16,
                  ),
                  IconButton(
                    onPressed: () async {
                      await widget.showCustomFieldSettings(false);
                    },
                    icon: const Icon(Icons.arrow_back_outlined),
                  ),
                  const Spacer(),
                  IconButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: showUpload ? AppBarTheme.of(context).backgroundColor : null,
                    ),
                    onPressed: () {
                      setState(() {
                        showUpload = !showUpload;
                      });
                    },
                    icon: const Icon(Icons.file_upload_outlined),
                  ),
                ],
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    showMenu
                        ? Container(
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  width: 2,
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                ),
                              ),
                            ),
                            width: 280,
                            child: Column(
                              children: [
                                Expanded(
                                  child: Scrollbar(
                                    controller: sideBarScrollController,
                                    thumbVisibility: true,
                                    child: SingleChildScrollView(
                                      controller: sideBarScrollController,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: PopupMenuButton(
                                                onSelected: (value) async {
                                                  setState(() {
                                                    selectedUser = users
                                                        .firstWhereOrNull((u) => u.id == value);
                                                  });
                                                },
                                                tooltip: selectedUser?.email ?? "",
                                                enabled: (advisors.length + users.length) > 1,
                                                itemBuilder: (context) {
                                                  List<PopupMenuItem> items = [];
                                                  for (User user in users) {
                                                    items.add(
                                                      PopupMenuItem(
                                                        value: user.id,
                                                        child: Text(user.email ?? user.id),
                                                      ),
                                                    );
                                                  }
                                                  for (String advisor in advisors) {
                                                    items.add(
                                                      PopupMenuItem(
                                                        value: advisor,
                                                        child: Text(advisor),
                                                      ),
                                                    );
                                                  }
                                                  return items;
                                                },
                                                child: Wrap(
                                                  children: [
                                                    const Icon(Icons.arrow_drop_down_outlined),
                                                    const Icon(Icons.person_outline_outlined),
                                                    const SizedBox(
                                                      width: 10,
                                                    ),
                                                    Text(
                                                      selectedUser?.email ?? "",
                                                      overflow: TextOverflow.visible,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const Divider(),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text("Default Fields:"),
                                                SizedBox(
                                                  height: 25,
                                                  width: 25,
                                                  child: updating
                                                      ? const CircularProgressIndicator()
                                                      : Container(),
                                                ),
                                              ],
                                            ),
                                            for (TableField tableField in tableFieldsList.where(
                                              (tf) =>
                                                  tf.tableSettingCustomFieldsId ==
                                                      widget.model.modelName() &&
                                                  tf.userId == "default",
                                            ))
                                              Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: _ExplorerCustomFieldsSettingsFieldSelector(
                                                  tableField: tableField,
                                                  setTableField: () async {
                                                    setState(() {
                                                      addMode = false;
                                                      selectedField = tableField;
                                                    });
                                                    if (tableField.fieldType ==
                                                        TableFieldFieldTypeEnum.SingleSelect) {
                                                      await _getAdvisorTableFieldOptions();
                                                    }
                                                  },
                                                ),
                                              ),
                                            const Divider(),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  "Custom Fields: (${tableFieldsList.where(
                                                        (tf) =>
                                                            tf.tableSettingCustomFieldsId ==
                                                                widget.model.modelName() &&
                                                            tf.userId == selectedUser?.id,
                                                      ).toList().length} / 3)",
                                                ),
                                                ElevatedButton(
                                                  onPressed: updating ||
                                                          tableFieldsList
                                                                  .where(
                                                                    (tf) =>
                                                                        tf.userId ==
                                                                        selectedUser?.id,
                                                                  )
                                                                  .toList()
                                                                  .length >=
                                                              3
                                                      ? null
                                                      : () => setState(() {
                                                            addMode = true;
                                                          }),
                                                  child: const Text("Add"),
                                                ),
                                              ],
                                            ),
                                            for (TableField tableField in tableFieldsList.where(
                                              (tf) => tf.userId?.toLowerCase() == selectedUser?.id,
                                            ))
                                              Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child:
                                                          _ExplorerCustomFieldsSettingsFieldSelector(
                                                        tableField: tableField,
                                                        setTableField: () async {
                                                          setState(() {
                                                            addMode = false;
                                                            selectedField = tableField;
                                                          });
                                                          if (tableField.fieldType ==
                                                              TableFieldFieldTypeEnum
                                                                  .SingleSelect) {
                                                            await _getAdvisorTableFieldOptions();
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                    IconButton(
                                                      onPressed: () => showDialog<bool>(
                                                        context: context,
                                                        builder: (context) {
                                                          return AlertDialog(
                                                            title: const Text('Delete:'),
                                                            content: SingleChildScrollView(
                                                              child: ListBody(
                                                                children: <Widget>[
                                                                  Text(
                                                                    'Please confirm that you want to delete ${tableField.fieldName ?? "this"}?',
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            actions: <Widget>[
                                                              TextButton(
                                                                child: const Text('Cancel'),
                                                                onPressed: () {
                                                                  Navigator.of(context)
                                                                      .pop<bool>(false);
                                                                },
                                                              ),
                                                              TextButton(
                                                                child: const Text('Confirm'),
                                                                onPressed: () {
                                                                  Navigator.of(context)
                                                                      .pop<bool>(true);
                                                                },
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      ).then(
                                                        (value) async {
                                                          if (value == true) {
                                                            setState(() {
                                                              updating = true;
                                                            });
                                                            var response = await gqlQuery(
                                                              gqlMinQueryString('''
                                                            query _ {
                                                              get${TableField.schema.name}(${TableField.ID.fieldName}: "${tableField.id}") {
                                                                ${generateGraphqlQueryFields(schema: TableField.schema)}
                                                              }
                                                            }'''),
                                                            );
                                                            var tableFieldBody = jsonDecode(
                                                              response.body,
                                                            )['data']
                                                                ?['get${TableField.schema.name}'];
                                                            response = await gqlMutation(
                                                              input: tableFieldBody is Map
                                                                  ? Map<String,
                                                                      dynamic>.fromEntries(
                                                                      Map<String, dynamic>.from(
                                                                        tableFieldBody,
                                                                      ).entries.where(
                                                                            (entry) => [
                                                                              TableField
                                                                                  .ID.fieldName,
                                                                              "_version",
                                                                            ].contains(
                                                                              entry.key,
                                                                            ),
                                                                          ),
                                                                    )
                                                                  : {},
                                                              model: ModelProvider.instance
                                                                  .getModelTypeByModelName(
                                                                TableField.schema.name,
                                                              ),
                                                              mutationType:
                                                                  GraphQLMutationType.delete,
                                                            );
                                                            if (response.statusCode == 200 &&
                                                                jsonDecode(response.body)['data']?[
                                                                        'delete${TableField.schema.name}'] !=
                                                                    null) {
                                                              tableFieldsList.removeWhere(
                                                                (tf) => tf.id == tableField.id,
                                                              );
                                                              widget.itemsDataSource.columns
                                                                  .removeWhere(
                                                                (c) =>
                                                                    c.columnName.toLowerCase() ==
                                                                    tableField.fieldName
                                                                        ?.toLowerCase(),
                                                              );
                                                              await widget.itemsDataSource
                                                                  .buildDataGridRows();
                                                              setState(() {
                                                                selectedField = tableFieldsList
                                                                    .where(
                                                                      (tf) =>
                                                                          tf.userId
                                                                              ?.toLowerCase() ==
                                                                          "default",
                                                                    )
                                                                    .firstOrNull;
                                                              });
                                                              Future<void> Function({
                                                                required TableField tableField,
                                                                required GraphQLMutationType type,
                                                              })? update =
                                                                  widget.updateCustomFields;
                                                              if (update != null) {
                                                                await update(
                                                                  tableField: tableField,
                                                                  type: GraphQLMutationType.delete,
                                                                );
                                                              }
                                                            }
                                                            setState(() {
                                                              updating = false;
                                                            });
                                                          }
                                                        },
                                                      ),
                                                      icon: const Icon(Icons.delete_outline),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: addMode && selectedUser != null && selectedUser?.id != ""
                            ? _ExplorerCustomFieldsAdd(
                                updateTableFields: _getTableField,
                                updateCustomFields: widget.updateCustomFields,
                                selectedUser: selectedUser,
                                model: widget.model,
                                itemsDataSource: widget.itemsDataSource,
                              )
                            : selectedField == null
                                ? Container()
                                : ExplorerCustomFieldsSettingsFieldOptions(
                                    key: UniqueKey(),
                                    updateTableFields: _getTableField,
                                    updateCustomFields: widget.updateCustomFields,
                                    itemsDataSource: widget.itemsDataSource,
                                    isUpdating: updating,
                                    tableFieldOptionsList: tableFieldOptionsList,
                                    selectedUser: selectedUser,
                                    tableField: selectedField,
                                  ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
  }
}

class _ExplorerCustomFieldsSettingsFieldSelector extends StatefulWidget {
  final TableField? tableField;
  final void Function() setTableField;
  const _ExplorerCustomFieldsSettingsFieldSelector({
    required this.tableField,
    required this.setTableField,
  });

  @override
  State<_ExplorerCustomFieldsSettingsFieldSelector> createState() =>
      _ExplorerCustomFieldsSettingsFieldSelectorState();
}

class _ExplorerCustomFieldsSettingsFieldSelectorState
    extends State<_ExplorerCustomFieldsSettingsFieldSelector> {
  bool isHover = false;
  IconData? _icon;

  @override
  void initState() {
    TableFieldFieldTypeEnum? tableFieldFieldTypeEnum = widget.tableField?.fieldType;
    if (tableFieldFieldTypeEnum != null) {
      switch (tableFieldFieldTypeEnum) {
        case TableFieldFieldTypeEnum.Text:
          setState(() {
            _icon = Icons.text_fields_outlined;
          });
          break;
        case TableFieldFieldTypeEnum.Number:
          setState(() {
            _icon = Icons.numbers_outlined;
          });
          break;
        case TableFieldFieldTypeEnum.Date:
          setState(() {
            _icon = Icons.date_range_outlined;
          });
          break;
        case TableFieldFieldTypeEnum.SingleSelect:
          setState(() {
            _icon = Icons.arrow_drop_down_outlined;
          });
          break;
      }
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.setTableField,
      onHover: (val) {
        setState(() {
          isHover = val;
        });
      },
      child: Row(
        children: [
          _icon == null ? Container() : Icon(_icon),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              widget.tableField?.fieldName?.toString().toFirstUpper().splitCamelCase() ?? '',
            ),
          ),
        ],
      ),
    );
  }
}

class ExplorerCustomFieldsSettingsFieldOptions extends StatefulWidget {
  final bool isUpdating;
  final TableField? tableField;
  final List<Map<String, dynamic>> tableFieldOptionsList;
  final User? selectedUser;
  final ItemsDataSource itemsDataSource;
  final Future<void> Function({bool stateUpdate})? updateTableFields;
  final Future<void> Function({
    required TableField tableField,
    required GraphQLMutationType type,
  })? updateCustomFields;

  const ExplorerCustomFieldsSettingsFieldOptions({
    super.key,
    required this.tableField,
    required this.selectedUser,
    required this.tableFieldOptionsList,
    required this.isUpdating,
    required this.itemsDataSource,
    required this.updateTableFields,
    this.updateCustomFields,
  });

  @override
  State<ExplorerCustomFieldsSettingsFieldOptions> createState() =>
      _ExplorerCustomFieldsSettingsFieldOptionsState();
}

class _ExplorerCustomFieldsSettingsFieldOptionsState
    extends State<ExplorerCustomFieldsSettingsFieldOptions> {
  final ScrollController scrollController = ScrollController();
  Map<String, dynamic> updatedTableField = {};
  TextEditingController textEditingController = TextEditingController();

  BoxConstraints fieldContraints = const BoxConstraints(
    maxWidth: 350,
    minWidth: 300,
  );

  bool updatingName = false;

  @override
  void initState() {
    setState(() {
      textEditingController.text = widget.tableField?.fieldName.toString().toTitleCase() ?? '';
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 36.0),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 730),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: fieldContraints,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Edit:",
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    SizedBox(
                      height: 20,
                      width: 20,
                      child: updatingName
                          ? const Center(
                              child: CircularProgressIndicator(),
                            )
                          : Container(),
                    )
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      constraints: fieldContraints,
                      child: TextFormField(
                        maxLength: 100,
                        readOnly: widget.tableField?.userId != widget.selectedUser?.id,
                        style: Theme.of(context).textTheme.bodyMedium,
                        controller: textEditingController,
                        onChanged: (v) {
                          if (textEditingController.text == "") {
                            updatedTableField['fieldName'] =
                                widget.tableField?.fieldName?.toString().toTitleCase();
                            textEditingController.text =
                                widget.tableField?.fieldName?.toString().toTitleCase() ?? '';
                          } else {
                            updatedTableField['fieldName'] = v.toTitleCase();
                          }
                        },
                        onEditingComplete: () async {
                          setState(() {
                            updatingName = true;
                          });
                          var response = await gqlQuery(
                            gqlMinQueryString('''
                                                            query _ {
                                                              get${TableField.schema.name}(${TableField.ID.fieldName}: "${widget.tableField?.id}") {
                                                                ${generateGraphqlQueryFields(schema: TableField.schema)}
                                                              }
                                                            }'''),
                          );
                          var tableFieldBody = jsonDecode(
                            response.body,
                          )['data']?['get${TableField.schema.name}'];
                          response = await gqlMutation(
                            input: (widget.tableField
                                    ?.copyWith(fieldName: updatedTableField['fieldName'])
                                    .toJson() ??
                                {})
                              ..addAll({
                                "_version": tableFieldBody["_version"],
                              }),
                            model: ModelProvider.instance.getModelTypeByModelName(
                              TableField.schema.name,
                            ),
                            mutationType: GraphQLMutationType.update,
                          );
                          if (response.statusCode == 200 &&
                              jsonDecode(response.body)['data']
                                      ?['update${TableField.schema.name}'] !=
                                  null) {
                            widget.itemsDataSource.columns.add(
                              GridColumn(
                                columnName: updatedTableField['fieldName'] ?? "",
                                label: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    updatedTableField['fieldName'] ?? "",
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            );
                            widget.itemsDataSource.columns.removeWhere(
                              (c) =>
                                  c.columnName.toLowerCase() ==
                                  widget.tableField?.fieldName?.toLowerCase(),
                            );
                            Future<void> Function({
                              required TableField tableField,
                              required GraphQLMutationType type,
                            })? update = widget.updateCustomFields;
                            Future<void> Function({bool stateUpdate})? updateTable =
                                widget.updateTableFields;
                            if (update != null && updateTable != null) {
                              await update(
                                tableField: widget.tableField
                                        ?.copyWith(fieldName: updatedTableField['fieldName']) ??
                                    TableField(),
                                type: GraphQLMutationType.update,
                              );
                              await updateTable();
                            }
                            await widget.itemsDataSource.initData();
                          }
                          if (mounted) {
                            setState(() {
                              updatingName = false;
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          border: UnderlineInputBorder(),
                          labelText: "Name",
                          labelStyle: TextStyle(overflow: TextOverflow.fade),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Container(
                        constraints: fieldContraints,
                        child: DropdownButtonFormField<TableFieldFieldTypeEnum>(
                          style: Theme.of(context).textTheme.bodyMedium,
                          value:
                              widget.tableField?.fieldType ?? TableFieldFieldTypeEnum.values.first,
                          items: TableFieldFieldTypeEnum.values
                              .map(
                                (e) => DropdownMenuItem<TableFieldFieldTypeEnum>(
                                  value: TableFieldFieldTypeEnum.values
                                          .firstWhereOrNull((t) => t.name == e.name) ??
                                      TableFieldFieldTypeEnum.values.first,
                                  child: Text(e.name),
                                ),
                              )
                              .toList(),
                          onChanged: null,
                        ),
                      ),
                    ),
                    if (widget.tableField?.fieldType == TableFieldFieldTypeEnum.SingleSelect)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Container(
                          constraints: fieldContraints,
                          child: widget.isUpdating
                              ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                              : CustomFieldOptions(
                                  selectedUser: widget.selectedUser,
                                  customFields: widget.tableFieldOptionsList,
                                  tableFieldOptionsId: widget.tableField?.id ?? "",
                                ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomFieldOptions extends StatefulWidget {
  final List<Map<String, dynamic>>? customFields;
  final String tableFieldOptionsId;
  final User? selectedUser;
  const CustomFieldOptions({
    super.key,
    this.customFields,
    required this.tableFieldOptionsId,
    required this.selectedUser,
  });

  @override
  State<CustomFieldOptions> createState() => _CustomFieldOptionsState();
}

class _CustomFieldOptionsState extends State<CustomFieldOptions> {
  bool updatingItem = false;
  bool loadingItems = false;
  List<Map<String, dynamic>> filteredCustomFields = [];

  void _addItemToList() async {
    setState(() {
      updatingItem = true;
    });
    if (_textController.text.isNotEmpty) {
      var createItem = TableFieldOption(
        labelText: _textController.text,
        tableFieldOptionsId: widget.tableFieldOptionsId,
        repId: widget.selectedUser?.id,
      ).toJson();
      createItem.removeWhere((key, value) => value == null);
      var result = await gqlMutation(
        input: createItem,
        model: ModelProvider.instance.getModelTypeByModelName(TableFieldOption.schema.name),
        mutationType: GraphQLMutationType.create,
      );
      if (result.statusCode == 200 &&
          jsonDecode(result.body)?['data']?['createTableFieldOption'] != null) {
        filteredCustomFields.add(
          createItem,
        );
        setState(_textController.clear);
      }
    }
    if (mounted) {
      setState(() {
        updatingItem = false;
      });
    }
  }

  @override
  void initState() {
    _removeDefaultCustomFields();
    super.initState();
  }

  Future<void> _removeDefaultCustomFields() async {
    setState(() {
      loadingItems = true;
    });
    filteredCustomFields.clear();
    User? selectedUser = widget.selectedUser;
    for (Map<String, dynamic> customField in widget.customFields ?? []) {
      if (customField[TableFieldOption.REPID.fieldName].toString().trim().toLowerCase() ==
              "default" ||
          customField[TableFieldOption.REPID.fieldName].toString().trim() == selectedUser?.id) {
        filteredCustomFields.add(customField);
      }
    }
    filteredCustomFields.sort((a, b) {
      String labelA = a['labelText'] ?? '';
      String labelB = b['labelText'] ?? '';
      return labelA.compareTo(labelB);
    });
    setState(() {
      loadingItems = false;
    });
  }

  ScrollController scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return loadingItems
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        maxLength: 100,
                        controller: _textController,
                        decoration: const InputDecoration(
                          labelText: 'Add a new item',
                        ),
                        onEditingComplete: _addItemToList,
                      ),
                    ),
                    updatingItem
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : IconButton(
                            icon: const Icon(Icons.add_outlined),
                            onPressed: _addItemToList,
                          ),
                  ],
                ),
              ),
              Scrollbar(
                controller: scrollController,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: scrollController,
                  primary: false,
                  shrinkWrap: true,
                  itemCount: filteredCustomFields.length,
                  itemBuilder: (context, index) {
                    Map<String, dynamic>? item = filteredCustomFields[index];
                    String itemRepId =
                        item[TableFieldOption.REPID.fieldName].toString().trim().toLowerCase();
                    String extractedRepId = widget.selectedUser?.id.toLowerCase() ?? "";
                    return itemRepId == 'default' || itemRepId == extractedRepId
                        ? ListTile(
                            key: ValueKey(item),
                            title: Text(item['labelText'] ?? ''),
                            trailing: IconButton(
                              icon: Icon(itemRepId == 'default' ? null : Icons.delete_outline),
                              onPressed: widget.selectedUser == null && itemRepId != 'default'
                                  ? null
                                  : () async {
                                      if (context.mounted) {
                                        setState(() {
                                          updatingItem = true;
                                        });
                                        Map<String, dynamic> tabelFieldOption = {};
                                        String? firstIndex =
                                            TableFieldOption.schema.indexes?.first.fields.first;
                                        if (firstIndex != null) {
                                          tabelFieldOption.addAll({firstIndex: item[firstIndex]});
                                          tabelFieldOption.addAll({"_version": item['_version']});
                                          var response = await gqlMutation(
                                            input: tabelFieldOption,
                                            model: ModelProvider.instance.getModelTypeByModelName(
                                              TableFieldOption.schema.name,
                                            ),
                                            mutationType: GraphQLMutationType.delete,
                                          );
                                          if (response.statusCode == 200 &&
                                              jsonDecode(response.body)['data']
                                                      ?['deleteTableFieldOption'] !=
                                                  null) {
                                            filteredCustomFields.removeAt(index);
                                          }
                                        }
                                        if (mounted) {
                                          setState(() {
                                            updatingItem = false;
                                          });
                                        }
                                      }
                                    },
                            ),
                          )
                        : Container();
                  },
                ),
              ),
            ],
          );
  }
}

class _ExplorerCustomFieldsAdd extends StatefulWidget {
  final Future<void> Function({bool stateUpdate, TableField? selectedTableField})?
      updateTableFields;
  final Future<void> Function({
    required TableField tableField,
    required GraphQLMutationType type,
  })? updateCustomFields;
  final ItemsDataSource itemsDataSource;
  final ModelType<Model> model;
  final User? selectedUser;
  const _ExplorerCustomFieldsAdd({
    required this.selectedUser,
    required this.model,
    required this.itemsDataSource,
    required this.updateCustomFields,
    this.updateTableFields,
  });

  @override
  State<_ExplorerCustomFieldsAdd> createState() => __ExplorerCustomFieldsAddState();
}

class __ExplorerCustomFieldsAddState extends State<_ExplorerCustomFieldsAdd> {
  final BoxConstraints fieldContraints = const BoxConstraints(maxWidth: 350, minWidth: 250);
  TextEditingController textEditingController = TextEditingController();
  bool addingField = false;
  Map<String, dynamic> updatedTableField = {};
  final String initialId = UUID.getUUID();

  FocusNode focusNode = FocusNode();

  void onFocusChange() {
    if (textEditingController.text != '') {
      textEditingController.text =
          textEditingController.text.split(" ").map((w) => w.toFirstUpper()).join(" ");
      setState(() {
        updatedTableField[TableField.FIELDNAME.fieldName] = textEditingController.text;
      });
    }
  }

  @override
  void initState() {
    updatedTableField.addAll({TableField.ID.fieldName: initialId});
    updatedTableField.addAll(
      {TableField.TABLESETTINGCUSTOMFIELDSID.fieldName: widget.model.modelName()},
    );
    updatedTableField.addAll({TableField.FIELDTYPE.fieldName: TableFieldFieldTypeEnum.Text.name});
    updatedTableField.addAll({TableField.USERID.fieldName: widget.selectedUser?.id});
    updatedTableField.addAll({"_version": 1});
    focusNode.addListener(onFocusChange);
    focusNode.requestFocus();
    super.initState();
  }

  @override
  void dispose() {
    focusNode.removeListener(onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 36.0),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 730),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text("Create:", style: Theme.of(context).textTheme.bodyLarge),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      constraints: fieldContraints,
                      child: TextFormField(
                        focusNode: focusNode,
                        style: Theme.of(context).textTheme.bodyMedium,
                        controller: textEditingController,
                        onChanged: (v) {
                          setState(() {
                            updatedTableField['fieldName'] = v;
                          });
                        },
                        maxLength: 100,
                        decoration: const InputDecoration(
                          helperText: "(required)",
                          border: UnderlineInputBorder(),
                          labelText: "Name",
                          labelStyle: TextStyle(overflow: TextOverflow.fade),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Container(
                        constraints: fieldContraints,
                        child: DropdownButtonFormField<TableFieldFieldTypeEnum>(
                          style: Theme.of(context).textTheme.bodyMedium,
                          value: TableFieldFieldTypeEnum.values.first,
                          items: TableFieldFieldTypeEnum.values
                              .map(
                                (e) => DropdownMenuItem<TableFieldFieldTypeEnum>(
                                  value: TableFieldFieldTypeEnum.values
                                          .firstWhereOrNull((t) => t.name == e.name) ??
                                      TableFieldFieldTypeEnum.values.first,
                                  child: Text(e.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              updatedTableField[TableField.FIELDTYPE.fieldName] = value?.name;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton(
                  onPressed: updatedTableField['fieldName'] != null &&
                          updatedTableField['fieldName'] != "" &&
                          !addingField
                      ? () async {
                          setState(() {
                            addingField = true;
                          });
                          var response = await gqlMutation(
                            input: updatedTableField,
                            model: TableField.classType,
                            mutationType: GraphQLMutationType.create,
                            authorizationType: "",
                          );
                          var responseBody = jsonDecode(response.body);
                          if (response.statusCode == 200 &&
                              responseBody is Map &&
                              responseBody['data']?['create${TableField.schema.name}'] != null) {
                            TableField tableField = TableField.fromJson(updatedTableField);
                            await widget.itemsDataSource.buildDataGridRows(
                              newColumns: [
                                ...widget.itemsDataSource.columns,
                                GridColumn(
                                  columnName: tableField.fieldName ?? '',
                                  label: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      tableField.fieldName?.toFirstUpper().splitCamelCase() ?? "",
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            );
                            Future<void> Function({
                              required TableField tableField,
                              required GraphQLMutationType type,
                            })? update = widget.updateCustomFields;
                            Future<void> Function({
                              bool stateUpdate,
                              TableField? selectedTableField,
                            })? updateTable = widget.updateTableFields;
                            if (update != null && updateTable != null) {
                              await update(
                                tableField: tableField,
                                type: GraphQLMutationType.create,
                              );
                              await updateTable(stateUpdate: false, selectedTableField: tableField);
                            }
                          }
                          setState(() {
                            addingField = false;
                          });
                        }
                      : null,
                  child: addingField
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(),
                        )
                      : const Text("Create"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
