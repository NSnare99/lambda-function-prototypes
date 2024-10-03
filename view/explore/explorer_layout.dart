import 'dart:convert';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/models/ModelProvider.dart';
import 'package:base/providers/auth_service.dart';
import 'package:base/utilities/extensions/string.dart';
import 'package:base/utilities/requests/api_gateway.dart';
import 'package:base/utilities/requests/graphql.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:rms/view/adaptive_grid.dart';
import 'package:rms/view/explore/explorer_data.dart';
import 'package:rms/view/explore/explorer_menu.dart';
import 'package:rms/view/explore/custom_fields/explorer_custom_fields_settings.dart';
import 'package:rms/view/explore/explorer_table_settings.dart';
import 'package:rms/view/explore/logic/graphql_search.dart';
import 'package:rms/view/upload/upload_steps/logic/string_to_scalar.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class GraphQLExplore extends StatefulWidget {
  final SfDataGrid sfDataGrid;
  final ModelType<Model> model;
  final String firstIndex;
  final int Function({int? value}) rowsPerPage;
  final List<Map<String, dynamic>>? customFields;
  final Future<void> Function({
    required TableField tableField,
    required GraphQLMutationType type,
  })? updateCustomFields;
  final Future<void> Function({
    required ModelType<Model> model,
    required List<Map<String, dynamic>> items,
  })? itemsPostProcess;
  final List<Widget>? explorerItemOptions;
  final DataPagerController? dataPagerController;
  final bool? loadAll;
  final bool? allowOptions;
  final bool? allowActions;
  final bool? allowPagination;
  final bool persistChips;
  final Map<ModelField, String>? searchTerms;
  final bool initializeData;
  final List<String> initialChips;
  final List<String> initialOrChips;
  const GraphQLExplore({
    super.key,
    required this.sfDataGrid,
    required this.model,
    required this.rowsPerPage,
    required this.firstIndex,
    this.customFields,
    this.itemsPostProcess,
    this.updateCustomFields,
    this.loadAll = false,
    this.allowOptions = true,
    this.allowActions = true,
    this.allowPagination = true,
    this.searchTerms,
    this.initializeData = true,
    this.persistChips = true,
    this.dataPagerController,
    this.explorerItemOptions,
    this.initialChips = const <String>[],
    this.initialOrChips = const <String>[],
  });

  @override
  State<GraphQLExplore> createState() => _GraphQLExploreState();
}

class _GraphQLExploreState extends State<GraphQLExplore> {
  bool layoutProcessing = false;
  bool loadingMore = false;
  Map<ModelField, String>? searchTerms;
  bool showCustomFieldsSettingsView = false;
  bool showTableSettingsView = false;
  Map<String, ModelField>? fields;
  bool loadAll = false;
  bool isSearchable = false;
  late ItemsDataSource itemsDataSource;
  String? dropdownValue;
  String? sortField;

  @override
  void initState() {
    setState(() {
      itemsDataSource = widget.sfDataGrid.source as ItemsDataSource;
      searchTerms = widget.searchTerms ?? {};
      loadAll = widget.loadAll ?? false;
      textEditingController.text = "";
    });
    fetchItems();
    super.initState();
  }

  @override
  void dispose() {
    if (widget.initialChips.isEmpty) {
      AuthService().userPool.storage.removeItem("${widget.model.modelName()}_chips");
    } else if (widget.persistChips) {
      AuthService()
          .userPool
          .storage
          .setItem("${widget.model.modelName()}_chips", widget.initialChips);
    }
    super.dispose();
  }

  Future<void> fetchItems() async {
    if (mounted) {
      setState(() {
        layoutProcessing = true;
      });
    }
    dropdownValue =
        await AuthService().userPool.storage.getItem("${widget.model.modelName()}_dropDownValue");
    sortField =
        await AuthService().userPool.storage.getItem("${widget.model.modelName()}_sortField");
    if (sortField != null) {
      await itemsDataSource.setSortField(sortField);
    }
    Response tableInfoResponse = await apiGatewayGET(
      server: Uri.parse("$newEndpoint/table"),
      queryParameters: {
        "tableName": widget.model.modelName(),
      },
    );
    var tableInfoBody = jsonDecode(tableInfoResponse.body);
    Map tableInfo = tableInfoBody is Map ? tableInfoBody : {};
    isSearchable = tableInfo.containsKey('isSearchable') && tableInfo['isSearchable'] == true;
    for (var schema in ModelProvider.instance.modelSchemas) {
      if (schema.name == widget.model.modelName()) {
        fields = schema.fields;
        if (fields == null) break;
      }
    }
    if (mounted) {
      setState(() {
        layoutProcessing = false;
        loadAll = false;
      });
    }
    await submitData(itemsDataSource: itemsDataSource);
  }

  TextEditingController textEditingController = TextEditingController();

  Future<void> openCustomFieldsView(bool value) async {
    if (mounted) {
      setState(() {
        showTableSettingsView = false;
        showCustomFieldsSettingsView = value;
      });
    }
  }

  Future<void> openTableSettingsView(bool value) async {
    if (mounted) {
      setState(() {
        showTableSettingsView = value;
        showCustomFieldsSettingsView = false;
      });
    }
  }

  Future<void> addOrChips(List<String> addedOrChips) async {
    if (mounted) {
      setState(() {
        widget.initialOrChips.addAll(addedOrChips);
      });
    }
  }

  final FocusNode _node = FocusNode();

  final List<PopupMenuItem<String>> popupMenuEntries = [];
  final GlobalKey _searchDropdown = GlobalKey();

  Future<void> submitData({required ItemsDataSource? itemsDataSource}) async {
    if (mounted) {
      setState(() {
        loadingMore = true;
      });
    }
    if (widget.initialChips.isNotEmpty) {
      if (widget.persistChips) {
        await AuthService().userPool.storage.setItem(
              "${widget.model.modelName()}_chips",
              widget.initialChips,
            );
      }
    } else {
      await AuthService().userPool.storage.removeItem("${widget.model.modelName()}_chips");
    }
    await itemsDataSource?.clearQueryFilter();
    await itemsDataSource?.clearOrQueryFilter();
    itemsDataSource?.items.clear();
    List<String>? customFieldNames = widget.customFields
        ?.map((cf) => cf['fieldName'].toString().trim().split(" ").join().toLowerCase())
        .toList();

    for (String chip in widget.initialChips) {
      String chipValue = chip.split(":").last.trim();
      String chipFieldName = chip
          .split(":")
          .first
          .split(" ")
          .map((w) => w == "ID" ? "Id" : w)
          .join()
          .toFirstLower()
          .trim();
      ModelField? field = fields?[chipFieldName];
      field ??= fields?[chip.split(":").first.split(" ").join().toFirstLower().trim()];
      if (field != null) {
        await itemsDataSource?.addQueryFilter(
          field: field,
          value: chipValue,
        );
      } else if (customFieldNames?.contains(chipFieldName.trim().toLowerCase()) == true) {
        await itemsDataSource?.addQueryFilter(
          field: const ModelField(
            name: "customFields",
            type: ModelFieldType(ModelFieldTypeEnum.string),
            isRequired: false,
          ),
          value: '\\"${itemsDataSource.selectedUser?.id}\\": \\"$chipValue\\"',
          isMatchPhrase: true,
        );
      }
    }

    if (dropdownValue == null && textEditingController.text.isNotEmpty) {
      for (String orChip in widget.initialOrChips) {
        for (var schema in ModelProvider.instance.modelSchemas) {
          if (schema.name == widget.model.modelName()) {
            if (schema.fields != null) {
              if (schema.fields!.containsKey(orChip.split(RegExp(r"\s+")).join().toFirstLower())) {
                await itemsDataSource?.addQueryFilter(
                  field: schema.fields![orChip.split(RegExp(r"\s+")).join().toFirstLower()]!,
                  value: textEditingController.text,
                  isOrFilter: true,
                  isWildcard: true,
                );
              } else if (customFieldNames
                      ?.map((cf) => cf.split(" ").join().toLowerCase().trim())
                      .contains(orChip.split(" ").join().toLowerCase().trim()) ??
                  false) {
                await itemsDataSource?.addQueryFilter(
                  field: const ModelField(
                    name: "customFields",
                    type: ModelFieldType(ModelFieldTypeEnum.string),
                    isRequired: false,
                  ),
                  value:
                      '\\"${itemsDataSource.selectedUser?.id ?? ""}\\": \\"${textEditingController.text}\\"',
                  isMatchPhrase: true,
                  isOrFilter: true,
                );
              }
            }
          }
        }
      }
    }

    await itemsDataSource?.handleLoadMoreRows();
    if (mounted) {
      setState(() {
        loadingMore = false;
      });
    }
    _node.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    void addChip() {
      if (textEditingController.text.isNotEmpty &&
          dropdownValue != null &&
          widget.initialChips.length + widget.initialOrChips.length <= 8) {
        if (widget.initialChips.any((c) => c.contains('$dropdownValue:'))) {
          widget.initialChips.removeWhere((ic) => ic.startsWith('$dropdownValue:'));
          setState(() {
            widget.initialChips.add(
              '${dropdownValue!}: ${textEditingController.text}',
            );
          });
        } else {
          setState(() {
            widget.initialChips.add(
              '${dropdownValue!}: ${textEditingController.text}',
            );
            textEditingController.clear();
          });
        }
      }
    }

    Future<void> addDateRangeChip({ModelField? field}) async {
      if (field == null) return;
      if (dropdownValue != null) {
        if (widget.initialChips.length <= 8) {
          await showDateRangePicker(
            initialEntryMode: DatePickerEntryMode.inputOnly,
            context: context,
            firstDate: DateTime(0),
            lastDate: DateTime(DateTime.now().year * 2),
            currentDate: DateTime.now(),
            initialDateRange: DateTimeRange(
              start: DateTime.tryParse(textEditingController.text) ?? DateTime.now(),
              end: DateTime.now(),
            ),
          ).then(
            (value) async {
              if (value != null) {
                String? value1 = await processValue(
                  fieldTypeEnum: field.type.fieldType,
                  field: field,
                  value:
                      "${value.start.year}-${value.start.month.toString().padLeft(2, '0')}-${value.start.day.toString().padLeft(2, '0')}",
                  columnName: field.name.toFirstUpper().splitCamelCase(),
                  model: widget.model,
                  enums: {},
                ).catchError((_) => null);
                String? value2 = await processValue(
                  fieldTypeEnum: field.type.fieldType,
                  field: field,
                  value:
                      "${value.end.year}-${value.end.month.toString().padLeft(2, '0')}-${value.end.day.toString().padLeft(2, '0')}",
                  columnName: field.name.toFirstUpper().splitCamelCase(),
                  model: widget.model,
                  enums: {},
                ).catchError((_) => null);
                if (widget.initialChips.any((c) => c.contains('$dropdownValue:'))) {
                  widget.initialChips.removeWhere((ic) => ic.startsWith('${dropdownValue!}:'));
                  setState(() {
                    widget.initialChips.add(
                      '${dropdownValue!}: $value1 to $value2',
                    );
                  });
                } else {
                  setState(() {
                    widget.initialChips.add(
                      '${dropdownValue!}: $value1 to $value2',
                    );
                    textEditingController.clear();
                  });
                }
              }
              await submitData(itemsDataSource: itemsDataSource);
            },
          );
        }
      }
    }

    Future<String> getFilter() async {
      String filter = await generateFilter(
        widget.model,
        itemsDataSource.queryFilters,
        itemsDataSource.orQueryFilters,
        equalValues: itemsDataSource.equalFilters,
        matchPhraseValues: itemsDataSource.matchPhraseFilters,
        wildCardValues: itemsDataSource.wildCardFilters,
      );
      return filter;
    }

    if (layoutProcessing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            Text("loading data"),
          ],
        ),
      );
    } else if (showCustomFieldsSettingsView && widget.customFields != null) {
      return ExplorerCustomFieldsSettings(
        updateCustomFields: widget.updateCustomFields,
        model: widget.model,
        itemsDataSource: widget.sfDataGrid.source as ItemsDataSource,
        showCustomFieldSettings: openCustomFieldsView,
      );
    } else if (showTableSettingsView) {
      return ExplorerTableSettings(
        itemsDataSource: widget.sfDataGrid.source as ItemsDataSource,
        showTableSettings: openTableSettingsView,
        initialOrChips: widget.initialOrChips,
      );
    } else {
      return Column(
        children: [
          widget.allowOptions == true
              ? AdaptiveGrid(
                  minimumWidgetWidth: 200,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                focusNode: _node,
                                controller: textEditingController,
                                onSubmitted: (value) async {
                                  setState(() {});
                                  addChip();

                                  await submitData(itemsDataSource: itemsDataSource);
                                },
                                onEditingComplete: () async {
                                  setState(() {});
                                },
                                onChanged: (v) async {
                                  setState(() {});
                                },
                                decoration: InputDecoration(
                                  alignLabelWithHint: true,
                                  hintText: 'Search: ${dropdownValue ?? ""}',
                                  helperStyle: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.apply(color: Theme.of(context).colorScheme.onSurface),
                                  isDense: true,
                                  suffix: (fields?[dropdownValue?.toFirstLower().split(" ").join()]
                                                  ?.type
                                                  .fieldType ==
                                              ModelFieldTypeEnum.date ||
                                          fields?[dropdownValue?.toFirstLower().split(" ").join()]
                                                  ?.type
                                                  .fieldType ==
                                              ModelFieldTypeEnum.dateTime)
                                      ? IconButton(
                                          onPressed: () {
                                            ModelField? modelField = fields?[
                                                dropdownValue?.toFirstLower().split(" ").join()];
                                            modelField ??= fields?[dropdownValue
                                                ?.toFirstLower()
                                                .split(" ")
                                                .map((w) => w == "ID" ? "Id" : w)
                                                .join()];
                                            if (modelField != null) {
                                              if (modelField.type.fieldType ==
                                                      ModelFieldTypeEnum.date ||
                                                  modelField.type.fieldType ==
                                                      ModelFieldTypeEnum.dateTime) {
                                                addDateRangeChip(
                                                  field: fields?[dropdownValue
                                                      ?.toFirstLower()
                                                      .split(" ")
                                                      .join()],
                                                );
                                              } else {
                                                addChip();
                                              }
                                            }
                                          },
                                          icon: const Icon(Icons.date_range_outlined),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              key: _searchDropdown,
                              itemBuilder: (context) {
                                return itemsDataSource.columns
                                    .where((c) => c.visible == true)
                                    .map((c) => c.columnName)
                                    .toList()
                                    .map(
                                      (c) => PopupMenuItem<String>(
                                        value: c,
                                        child: Text(c),
                                      ),
                                    )
                                    .toList();
                              },
                              onSelected: (item) async {
                                await AuthService().userPool.storage.setItem(
                                      "${widget.model.modelName()}_dropDownValue",
                                      item,
                                    );
                                if (mounted) {
                                  setState(() {
                                    dropdownValue = item;
                                  });
                                }
                              },
                              icon: const Icon(Icons.arrow_drop_down_outlined),
                            ),
                            Align(
                              child: IconButton(
                                onPressed: () async {
                                  await AuthService()
                                      .userPool
                                      .storage
                                      .removeItem("${widget.model.modelName()}_dropDownValue");
                                  if (mounted) {
                                    setState(() {
                                      dropdownValue = null;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.cancel),
                              ),
                            ),
                            Align(
                              child: IconButton(
                                onPressed: widget.initialChips.isNotEmpty
                                    ? () async {
                                        addChip();
                                        await submitData(itemsDataSource: itemsDataSource);
                                      }
                                    : null,
                                icon: const Icon(Icons.search),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Spacer(),
                        for (var item in widget.explorerItemOptions ?? [])
                          widget.allowActions == true
                              ? Align(
                                  alignment: Alignment.centerRight,
                                  child: item,
                                )
                              : Container(),
                        const Spacer(),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: UnconstrainedBox(
                            child: ExplorerMenu(
                              getFilter: getFilter,
                              processing: (value) async {
                                if (mounted) {
                                  setState(() {
                                    layoutProcessing = value;
                                  });
                                }
                              },
                              model: widget.model,
                              showCustomFieldSettings: (value) async {
                                if (mounted) {
                                  setState(() {
                                    showCustomFieldsSettingsView = value;
                                  });
                                }
                              },
                              showTableSettings: (value) async {
                                if (mounted) {
                                  setState(() {
                                    showTableSettingsView = value;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Container(),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                spacing: 8.0,
                children: [
                  if (widget.initialChips.isNotEmpty) Text("${widget.initialChips.length} / 8"),
                  ...widget.initialChips.map((chip) {
                    ModelField? modelField =
                        fields?[chip.split(":").first.trim().split(" ").join().toFirstLower()];
                    modelField ??= fields?[chip
                        .split(":")
                        .first
                        .trim()
                        .split(" ")
                        .map((w) => w == "ID" ? "Id" : w)
                        .join()
                        .toFirstLower()];
                    return InkWell(
                      onTap: () async {
                        if (modelField == null ||
                            ![
                              ModelFieldTypeEnum.string,
                              ModelFieldTypeEnum.int,
                              ModelFieldTypeEnum.double,
                              ModelFieldTypeEnum.date,
                            ].contains(
                              modelField.type.fieldType,
                            )) {
                          return;
                        }
                        if (mounted) {
                          setState(() {
                            sortField = sortField == modelField?.name ? null : modelField?.name;
                          });
                        }
                        if (modelField.name.endsWith("ID")) {
                          modelField.name.replaceAll("ID", "Id");
                        }
                        if (sortField == null) {
                          await AuthService().userPool.storage.removeItem(
                                "${widget.model.modelName()}_sortField",
                              );
                        } else {
                          await AuthService().userPool.storage.setItem(
                                "${widget.model.modelName()}_sortField",
                                modelField.name,
                              );
                        }
                        await itemsDataSource
                            .setSortField(sortField == null ? null : modelField.name);
                        itemsDataSource.nextToken = null;
                        itemsDataSource.items.clear();
                        if (sortField != null) {
                          await itemsDataSource.handleLoadMoreRows();
                        }
                      },
                      child: Chip(
                        shadowColor: modelField?.name != null && modelField?.name == sortField
                            ? Theme.of(context).textTheme.bodyLarge?.color
                            : null,
                        elevation:
                            modelField?.name != null && modelField?.name == sortField ? 2 : null,
                        label: Text(
                          chip,
                          style: const TextStyle(fontSize: 12),
                        ),
                        padding: const EdgeInsets.all(4.0),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        onDeleted: () async {
                          setState(() {
                            widget.initialChips.remove(chip);
                          });
                          if (modelField?.name != null && sortField == modelField?.name) {
                            setState(() {
                              sortField = null;
                            });
                            await itemsDataSource.setSortField(null);
                            await AuthService()
                                .userPool
                                .storage
                                .removeItem("${widget.model.modelName()}_sortField");
                          }
                          if (widget.initialChips.isNotEmpty) {
                            if (widget.persistChips) {
                              await AuthService().userPool.storage.setItem(
                                    "${widget.model.modelName()}_chips",
                                    widget.initialChips,
                                  );
                            }
                          } else {
                            await AuthService()
                                .userPool
                                .storage
                                .removeItem("${widget.model.modelName()}_chips");
                          }
                          if (modelField?.name == null || modelField?.name != sortField) {
                            await submitData(itemsDataSource: itemsDataSource);
                          }
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: widget.sfDataGrid,
            ),
          ),
          widget.allowPagination == true
              ? AdaptiveGrid(
                  minimumWidgetWidth: 200,
                  children: [
                    // Row(
                    //   mainAxisSize: MainAxisSize.min,
                    //   children: [
                    //     const Text("Items per page: "),
                    //     const SizedBox(
                    //       width: 5,
                    //     ),
                    //     DropdownButtonHideUnderline(
                    //       child: DropdownButton<String>(
                    //         value: widget.rowsPerPage().toString(),
                    //         icon: const Icon(Icons.arrow_drop_down),
                    //         items: [
                    //           for (int multiple in [50, 100, 200, 300, 500])
                    //             DropdownMenuItem(
                    //               value: multiple.toString(),
                    //               child: Text(multiple.toString()),
                    //             ),
                    //         ],
                    //         onChanged: (s) async {
                    //           int sValueToInt = int.tryParse(s ?? "50") ?? 50;
                    //           widget.rowsPerPage(value: sValueToInt);
                    //         },
                    //       ),
                    //     ),
                    //   ],
                    // ),
                    // SizedBox(
                    //   height: AppBarTheme.of(context).toolbarHeight,
                    //   child: SfDataPager(
                    //     controller: widget.dataPagerController,
                    //     visibleItemsCount: 2,
                    //     pageCount: widget.sfDataGrid.source.rows.isEmpty
                    //         ? 1
                    //         : (widget.sfDataGrid.source.rows.length / widget.rowsPerPage())
                    //             .ceil()
                    //             .toDouble(),
                    //     delegate: widget.sfDataGrid.source,
                    //   ),
                    // ),
                    Wrap(
                      alignment: WrapAlignment.spaceAround,
                      children: [
                        UnconstrainedBox(
                          child: ElevatedButton(
                            onPressed: itemsDataSource.items.isNotEmpty &&
                                    itemsDataSource.nextToken != null
                                ? () async {
                                    setState(() {
                                      loadingMore = true;
                                    });
                                    await itemsDataSource.handleLoadMoreRows();
                                    setState(() {
                                      loadingMore = false;
                                    });
                                  }
                                : null,
                            child: loadingMore
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(),
                                  )
                                : const Text("Load More"),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Text("Loaded: ${widget.sfDataGrid.source.rows.length}"),
                        ),
                      ],
                    ),
                  ],
                )
              : Container(),
        ],
      );
    }
  }
}
