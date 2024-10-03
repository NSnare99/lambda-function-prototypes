import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/models/ModelProvider.dart';
import 'package:base/utilities/extensions/string.dart';
import 'package:base/utilities/models/api_gateway_models.dart';
import 'package:base/utilities/requests/api_gateway.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:rms/view/explore/logic/graphql_search.dart';
import 'package:rms/view/upload/upload_steps/logic/string_to_scalar.dart';
import 'package:rms/view/upload/upload_steps/logic/upload_logic.dart';

class ExplorerMenu extends StatefulWidget {
  final Future<void> Function(bool value) processing;
  final ModelType<Model> model;
  final Future<void> Function(bool value) showCustomFieldSettings;
  final Future<void> Function(bool value) showTableSettings;
  final Future<String> Function()? getFilter;
  const ExplorerMenu({
    super.key,
    required this.processing,
    required this.model,
    required this.showCustomFieldSettings,
    required this.showTableSettings,
    this.getFilter,
  });

  @override
  State<ExplorerMenu> createState() => _ExplorerMenuState();
}

class _ExplorerMenuState extends State<ExplorerMenu> {
  // This is the type used by the popup menu below.
  List<String> selections = [];
  late ModelSchema? modelSchema;
  late Map<String, ModelField>? fields;
  String modelPluralName = "";
  final List<PopupMenuItem<String>> popupMenuEntries = [];

  @override
  void initState() {
    for (ModelSchema schema in ModelProvider.instance.modelSchemas) {
      if (schema.name == widget.model.modelName()) {
        modelSchema = schema;
        fields = schema.fields;
        modelPluralName = schema.pluralName ?? "";
        break;
      }
    }
    List<String> selectionValues = [
      "Table Settings",
      "Custom Fields",
      "Download All",
    ];
    if (!(fields?.keys.contains("customFields") ?? true)) {
      selectionValues.remove("Custom Fields");
    }
    setState(() {
      selections = selectionValues;
    });
    for (String selection in selections) {
      popupMenuEntries.add(
        PopupMenuItem<String>(
          value: selection,
          child: Text(selection),
        ),
      );
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      child: const Icon(Icons.menu_outlined),
      itemBuilder: (context) {
        return popupMenuEntries;
      },
      onSelected: (item) => _selectedItem(context, item, modelSchema),
    );
  }

  void _selectedItem(BuildContext context, String selection, ModelSchema? schema) async {
    if (selection.toLowerCase() == "custom fields") {
      await widget.showCustomFieldSettings(true);
    } else if (selection.toLowerCase() == "table settings") {
      await widget.showTableSettings(true);
    } else if (selection.toLowerCase() == "download all") {
      await widget.processing(true);
      if (schema != null && context.mounted) {
        await downloadAll(() => context.mounted, schema, widget.getFilter);
      }
    }
    await widget.processing(false);
  }

  Future<void> downloadAll(
    bool Function() isMounted,
    ModelSchema schema,
    Future<String> Function()? getFilter,
  ) async {
    String? filter = getFilter != null ? await getFilter() : null;
    int limit = 100;
    String fileName = '${DateTime.now().millisecondsSinceEpoch}_download_file.xlsx';
    SearchResult searchResult = await searchGraphql(
      model: ModelProvider.instance.getModelTypeByModelName(schema.name),
      isMounted: isMounted,
      nextToken: null,
      limit: limit,
      filter: filter,
    );
    Map<String, List<String>> enums = {};
    if (fields != null && searchResult.items != null) {
      // upload to excel
      for (int i = 0; i < [...?searchResult.items].length; i++) {
        Map<String, dynamic> item = searchResult.items?[i] ?? {};
        for (MapEntry<String, dynamic> itemEntry in item.entries) {
          if (fields!.containsKey(itemEntry.key) == true && itemEntry.value != null) {
            var processedValue = await processValue(
              fieldTypeEnum: fields![itemEntry.key]!.type.fieldType,
              field: fields![itemEntry.key]!,
              value: itemEntry.value.toString(),
              columnName: itemEntry.key,
              model: widget.model,
              collectionType:
                  fields![itemEntry.key]!.type.fieldType == ModelFieldTypeEnum.collection
                      ? enumFromString<ModelFieldTypeEnum>(
                          fields![itemEntry.key]!.type.ofModelName,
                          ModelFieldTypeEnum.values,
                        )
                      : null,
              enums: enums,
            ).catchError((_) => null);
            if (processedValue != null) {
              searchResult.items?[i][itemEntry.key] = processedValue ?? "";
            }
          }
        }
      }

      await apiGatewayPOST(
        server: Uri.parse("$endpoint/excel"),
        payload: ExcelFileData(
          fileName: fileName,
          sheets: [
            ExcelSheetData(
              sheetName: widget.model.modelName(),
              columns: ExcelRowData(
                rowIndex: 1,
                cells: schema.fields?.values
                        .map(
                          (v) => ExcelCellData(
                            columnName: v.name.toFirstUpper().splitCamelCase(),
                            value: v.name.toFirstUpper().splitCamelCase(),
                          ),
                        )
                        .toList() ??
                    [],
              ),
              rows: [...?searchResult.items]
                  .mapIndexed(
                    (index, i) => ExcelRowData(
                      rowIndex: index,
                      cells: i.entries
                          .where((element) => element.value != null)
                          .map(
                            (e) => ExcelCellData(
                              columnName: e.key.toFirstUpper().splitCamelCase(),
                              value: e.value.toString(),
                            ),
                          )
                          .toList(),
                    ),
                  )
                  .toList(),
            ),
          ],
        ).toJson(),
      );
      int totalKB = (([...?searchResult.items]
                  .map((i) => i.entries.map((e) => "${e.key}${e.value}").toList())
                  .toList()
                  .toString()
                  .length) /
              4096)
          .floor();
      if (totalKB < 800) {
        limit = ((limit * (800 / totalKB)) > 1000 ? 1000 : (limit * (800 / totalKB))).floor();
      }
      while (searchResult.nextToken != null) {
        searchResult = await searchGraphql(
          model: ModelProvider.instance.getModelTypeByModelName(schema.name),
          isMounted: isMounted,
          nextToken: Uri.encodeComponent(searchResult.nextToken ?? ""),
          limit: limit,
          filter: filter,
        );
        for (int i = 0; i < [...?searchResult.items].length; i++) {
          Map<String, dynamic> item = searchResult.items?[i] ?? {};
          for (MapEntry<String, dynamic> itemEntry in item.entries) {
            if (fields!.containsKey(itemEntry.key) == true && itemEntry.value != null) {
              var processedValue = await processValue(
                fieldTypeEnum: fields![itemEntry.key]!.type.fieldType,
                field: fields![itemEntry.key]!,
                value: itemEntry.value.toString(),
                columnName: itemEntry.key,
                model: widget.model,
                collectionType:
                    fields![itemEntry.key]!.type.fieldType == ModelFieldTypeEnum.collection
                        ? enumFromString<ModelFieldTypeEnum>(
                            fields![itemEntry.key]!.type.ofModelName,
                            ModelFieldTypeEnum.values,
                          )
                        : null,
                enums: enums,
              ).catchError((_) => null);
              if (processedValue != null) {
                searchResult.items?[i][itemEntry.key] = processedValue ?? "";
              }
            }
          }
        }
        await apiGatewayPUT(
          server: Uri.parse("$endpoint/excel"),
          payload: ExcelFileData(
            fileName: fileName,
            sheets: [
              ExcelSheetData(
                sheetName: widget.model.modelName(),
                columns: ExcelRowData(
                  rowIndex: 1,
                  cells: schema.fields?.values
                          .map(
                            (v) => ExcelCellData(
                              columnName: v.name.toFirstUpper().splitCamelCase(),
                              value: v.name.toFirstUpper().splitCamelCase(),
                            ),
                          )
                          .toList() ??
                      [],
                ),
                rows: [...?searchResult.items]
                    .mapIndexed(
                      (index, i) => ExcelRowData(
                        rowIndex: index,
                        cells: i.entries
                            .where((element) => element.value != null)
                            .map(
                              (e) => ExcelCellData(
                                columnName: e.key.toFirstUpper().splitCamelCase(),
                                value: e.value.toString(),
                              ),
                            )
                            .toList(),
                      ),
                    )
                    .toList(),
              ),
            ],
          ).toJson(),
        );
      }
      await downloadTempExcelFile(fileName: fileName);
    }
  }
}
