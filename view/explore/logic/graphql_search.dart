import 'dart:convert';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/models/ModelProvider.dart';
import 'package:base/utilities/extensions/string.dart';
import 'package:base/utilities/models/join_table_model.dart';
import 'package:base/utilities/models/model_services.dart';
import 'package:base/utilities/requests/api_gateway.dart';
import 'package:base/utilities/requests/graphql.dart';
import 'package:http/http.dart';
import 'package:rms/view/explore/utilities/explorer_utilites.dart';

class SearchResult {
  final List<Map<String, dynamic>>? items;
  final String? nextToken;

  SearchResult({
    this.items,
    this.nextToken,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      items: (json['items'] as List<dynamic>?)
          // ignore: unnecessary_lambdas
          ?.map((item) => Map<String, dynamic>.from(item))
          .toList(),
      nextToken: json['nextToken'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items,
      'nextToken': nextToken,
    };
  }

  SearchResult copyWith({
    List<Map<String, dynamic>>? items,
    String? nextToken,
  }) {
    return SearchResult(
      items: items ?? this.items,
      nextToken: nextToken ?? this.nextToken,
    );
  }

  @override
  String toString() {
    return 'SearchResult(items: $items, nextToken: $nextToken)';
  }
}

Future<SearchResult> searchGraphql({
  required ModelType model,
  required bool Function() isMounted,
  required String? nextToken,
  bool requiredOnly = false,
  bool deleted = false,
  bool friendlyNames = false,
  String? filter,
  int? limit,
  List<List<String>> nestedModelsList = const [],
  String? sortField,
}) async {
  bool isSearchable = false;
  Response tableInfoResponse = await apiGatewayGET(
    server: Uri.parse("$newEndpoint/table"),
    queryParameters: {
      "tableName": model.modelName(),
    },
  );
  var tableInfoBody = jsonDecode(tableInfoResponse.body);
  Map tableInfo = tableInfoBody is Map ? tableInfoBody : {};
  isSearchable = tableInfo.containsKey('isSearchable') && tableInfo['isSearchable'] == true;
  late ModelSchema modelSchema;
  for (ModelSchema schema in ModelProvider.instance.modelSchemas) {
    if (schema.name.toLowerCase() == model.modelName().toLowerCase()) {
      modelSchema = schema;
      break;
    }
  }
  List<Map<String, dynamic>> items = [];
  Map<String, dynamic> result = {};
  String? graphqlQuery = await generateGraphqlQuery(
    requiredOnly: requiredOnly,
    isSearchable: isSearchable,
    model: model,
    filter: filter,
    limit: limit,
    deleted: deleted,
    nestedModelsList: nestedModelsList,
    nextToken: nextToken,
    sortField: sortField,
  );
  if (graphqlQuery != null) {
    result = jsonDecode((await gqlQuery(graphqlQuery, authorizationType: "")).body);
    items.addAll(
      parseResult(
        isSearchable: isSearchable,
        model: model,
        result: result,
        friendlyNames: friendlyNames,
      ),
    );
  }
  return SearchResult(
    items: items,
    nextToken: result['data']?['${isSearchable ? "search" : "list"}${modelSchema.pluralName}']
        ?['nextToken'],
  );
}

Future<String?> generateGraphqlQuery({
  required ModelType<Model> model,
  bool requiredOnly = false,
  bool isSearchable = false,
  String? filter,
  int? limit,
  bool deleted = false,
  String? nextToken,
  String queryName = "_",
  List<List<String>> nestedModelsList = const [],
  String? sortField,
}) async {
  for (ModelSchema schema in ModelProvider.instance.modelSchemas) {
    if (schema.name.toLowerCase() == model.modelName().toLowerCase()) {
      bool additionalArguments =
          limit != null || filter != null || nextToken != null || deleted != true;

      String graphqlQuery = "query $queryName {\n";
      graphqlQuery +=
          '${isSearchable ? "search" : "list"}${schema.pluralName}${additionalArguments ? "(" : ""}${nextToken != null ? 'nextToken: "$nextToken" ,' : ""}${limit != null ? "limit: $limit, " : ""}${isSearchable && sortField != null ? ", sort: {direction: asc,  field: $sortField}" : ""},${filter ?? (!deleted ? ", filter: {_deleted: {ne: true} }" : "")}${additionalArguments ? ")" : ""} {\n';
      graphqlQuery += 'items{\n';

      graphqlQuery += generateGraphqlQueryFields(
        schema: schema,
        nestedModelsList: nestedModelsList,
        requiredOnly: requiredOnly,
      );
      graphqlQuery += '_version\n';
      graphqlQuery += '}\n';
      graphqlQuery += 'nextToken\n';
      graphqlQuery += '}\n';
      graphqlQuery += '}\n';
      return graphqlQuery == "" ? null : graphqlQuery;
    }
  }
  return null;
}

String generateGraphqlQueryFields({
  required ModelSchema schema,
  bool requiredOnly = false,
  int nestedCount = 0,
  List<List<String>> nestedModelsList = const [],
}) {
  String returnString = "";
  schema.fields?.entries
      .where(
    (element) =>
        !element.value.isReadOnly && (requiredOnly ? element.value.isRequired == true : true),
  )
      .forEach(
    (entry) {
      switch (entry.value.type.fieldType) {
        case ModelFieldTypeEnum.string:
        case ModelFieldTypeEnum.int:
        case ModelFieldTypeEnum.double:
        case ModelFieldTypeEnum.date:
        case ModelFieldTypeEnum.dateTime:
        case ModelFieldTypeEnum.time:
        case ModelFieldTypeEnum.timestamp:
        case ModelFieldTypeEnum.bool:
        case ModelFieldTypeEnum.enumeration:
          returnString += '${entry.key},\n';
        case ModelFieldTypeEnum.collection:
          switch (enumFromString<ModelFieldTypeEnum>(
            entry.value.type.ofModelName,
            ModelFieldTypeEnum.values,
          )) {
            case ModelFieldTypeEnum.string:
            case ModelFieldTypeEnum.int:
            case ModelFieldTypeEnum.double:
            case ModelFieldTypeEnum.date:
            case ModelFieldTypeEnum.dateTime:
            case ModelFieldTypeEnum.time:
            case ModelFieldTypeEnum.timestamp:
            case ModelFieldTypeEnum.bool:
              returnString += '${entry.key},\n';
            case ModelFieldTypeEnum.model:
            case ModelFieldTypeEnum.collection:
            case ModelFieldTypeEnum.embedded:
            case ModelFieldTypeEnum.embeddedCollection:
            case ModelFieldTypeEnum.enumeration:
              break;
            case null:
              String? nestedCollectionOfModelName = entry.value.type.ofModelName;
              if (nestedCount < nestedModelsList.length &&
                  nestedCollectionOfModelName != null &&
                  nestedModelsList[nestedCount].isNotEmpty) {
                JoinTableData? secondaryModel;
                secondaryModel = getJoinTableData(
                  model:
                      ModelProvider.instance.getModelTypeByModelName(nestedCollectionOfModelName),
                  knownModel: ModelProvider.instance.getModelTypeByModelName(schema.name),
                );
                if (secondaryModel?.secondaryModel != null) {
                  nestedCollectionOfModelName = secondaryModel?.secondaryModel?.modelName();
                }
                if (nestedModelsList[nestedCount].contains(nestedCollectionOfModelName)) {
                  for (ModelSchema nestedSchema in ModelProvider.instance.modelSchemas) {
                    if (nestedSchema.name == nestedCollectionOfModelName) {
                      if (secondaryModel != null) {
                        returnString +=
                            "${entry.key} { items { ${secondaryModel.secondaryModel?.modelName().toFirstLower()} {${generateGraphqlQueryFields(schema: nestedSchema, nestedCount: nestedCount + 1, nestedModelsList: nestedModelsList)}}}}";
                      } else {
                        returnString +=
                            "${entry.key} { ${generateGraphqlQueryFields(schema: nestedSchema, nestedCount: nestedCount + 1, nestedModelsList: nestedModelsList)}}";
                      }
                      break;
                    }
                  }
                }
              }
          }
        case ModelFieldTypeEnum.model:
          if (nestedCount < nestedModelsList.length &&
              nestedModelsList[nestedCount].contains(entry.value.type.ofModelName)) {
            for (ModelSchema nestedSchema in ModelProvider.instance.modelSchemas) {
              if (nestedSchema.name == entry.value.type.ofModelName) {
                returnString +=
                    "${entry.key} { ${generateGraphqlQueryFields(schema: nestedSchema, nestedCount: nestedCount + 1, nestedModelsList: nestedModelsList)}}";
                break;
              }
            }
          }
        case ModelFieldTypeEnum.embedded:
        case ModelFieldTypeEnum.embeddedCollection:
      }
    },
  );
  return returnString;
}

Future<String> generateFilter(
  ModelType<Model> model,
  Map<ModelField, String> filterValues,
  Map<ModelField, String>? orFilterValues, {
  Map<ModelField, bool>? equalValues,
  Map<ModelField, bool>? matchPhraseValues,
  Map<ModelField, bool>? wildCardValues,
}) async {
  bool isSearchable = false;
  Response tableInfoResponse = await apiGatewayGET(
    server: Uri.parse("$newEndpoint/table"),
    queryParameters: {
      "tableName": model.modelName(),
    },
  );
  var tableInfoBody = jsonDecode(tableInfoResponse.body);
  Map tableInfo = tableInfoBody is Map ? tableInfoBody : {};
  isSearchable = tableInfo.containsKey('isSearchable') && tableInfo['isSearchable'] == true;
  List<String> searchFilters = [];

  String orQueryFilterString = "";
  String andQueryFilterString = "";

  if (orFilterValues != null) {
    if (orFilterValues.entries.length + filterValues.entries.length > 10) {
      return "";
    }
  } else {
    if (filterValues.entries.length > 10) {
      return "";
    }
  }

  searchFilters = await getSearchFilters(
    model,
    isSearchable,
    filterValues,
    equalValues,
    matchPhraseValues,
    wildCardValues,
  );
  if (searchFilters.isNotEmpty) {
    andQueryFilterString = "and:[${searchFilters.map((e) => e.trim()).toList().join(',')}],";
  }
  searchFilters.clear();

  if (orFilterValues != null) {
    searchFilters = await getSearchFilters(
      model,
      isSearchable,
      orFilterValues,
      equalValues,
      matchPhraseValues,
      wildCardValues,
    );
  }

  if (searchFilters.isNotEmpty) {
    orQueryFilterString = "or:[${searchFilters.map((e) => e.trim()).toList().join(',')}],";
  }

  return "filter: {$andQueryFilterString $orQueryFilterString _deleted: {ne: true}, }";
}

Future<List<String>> getSearchFilters(
  ModelType<Model> model,
  bool isSearchable,
  Map<ModelField, String> filterValues,
  Map<ModelField, bool>? equalValues,
  Map<ModelField, bool>? matchPhraseValues,
  Map<ModelField, bool>? wildCardValues,
) async {
  List<String> searchFilters = [];
  for (MapEntry<ModelField, String> filter in filterValues.entries) {
    bool equals = false;
    if (equalValues != null && equalValues[filter.key] == true) {
      equals = true;
    }
    bool matchPhrase = false;
    if (matchPhraseValues != null && matchPhraseValues[filter.key] == true) {
      matchPhrase = true;
    }
    bool wildcard = false;
    if (wildCardValues != null && wildCardValues[filter.key] == true) {
      wildcard = true;
    }
    String fieldName = filter.key.name;
    switch (filter.key.type.fieldType) {
      case ModelFieldTypeEnum.string:
      case ModelFieldTypeEnum.time:
      case ModelFieldTypeEnum.timestamp:
        searchFilters.add(
          '{$fieldName: { ${isSearchable ? (equals ? "eq:" : wildcard ? "wildcard:" : matchPhrase ? "matchPhrase:" : "match:") : "contains:"} ${wildcard ? '"*${filter.value}*"' : '"${filter.value}"'}}}',
        );

        break;
      case ModelFieldTypeEnum.int:
        if (filter.value.endsWith("and Up") ||
            filter.value.contains("-") && filter.value.split("-").length == 2) {
          List<String> values = filter.value
              .split("-")
              .map(
                (v) =>
                    RegExp(r"\d+\.\d+").firstMatch(v)?.group(0) ??
                    RegExp(r"\d+").firstMatch(v)?.group(0) ??
                    "",
              )
              .toList();
          searchFilters.add(
            '{$fieldName: {${isSearchable ? "gte" : "gt"}: ${values.first}, ${values.length > 1 ? "${isSearchable ? "lte" : "lt"}: ${values.last}" : ''}}}',
          );
        } else {
          int? value = int.tryParse(RegExp(r"\d+").firstMatch(filter.value)?.group(0) ?? "");
          if (value != null) {
            searchFilters.add('{$fieldName: { eq: $value }}');
          }
        }
        break;
      case ModelFieldTypeEnum.double:
        if (filter.value.endsWith("and Up") ||
            filter.value.contains("-") && filter.value.split("-").length == 2) {
          List<String> values = filter.value
              .split("-")
              .map(
                (v) =>
                    RegExp(r"\d+\.\d+").firstMatch(v)?.group(0) ??
                    RegExp(r"\d+").firstMatch(v)?.group(0) ??
                    "",
              )
              .toList();
          searchFilters.add(
            '{$fieldName: {${isSearchable ? "gte" : "gt"}: ${values.first}, ${values.length > 1 ? "${isSearchable ? "lte" : "lt"}: ${values.last}" : ''}}}',
          );
        } else {
          double? value = double.tryParse(RegExp(r"\d+").firstMatch(filter.value)?.group(0) ?? "");
          if (value != null) {
            searchFilters.add('{$fieldName: { eq: $value }}');
          }
        }
        break;
      case ModelFieldTypeEnum.date:
      case ModelFieldTypeEnum.dateTime:
        String dateValue = filter.value;
        if (filter.value.endsWith("and Up") ||
            filter.value.contains("-") && filter.value.split("-").length == 2) {
          DateTime now = DateTime.now();
          List<int> values = filter.value
              .split("-")
              .map(
                (v) =>
                    int.tryParse(
                      RegExp(r"\d+\.\d+").firstMatch(v)?.group(0) ??
                          RegExp(r"\d+").firstMatch(v)?.group(0) ??
                          "",
                    ) ??
                    0,
              )
              .toList();
          searchFilters.add(
            '{$fieldName: {${values.length > 1 ? '${isSearchable ? "gte" : "gt"}: "${(now.year - values.last).toString().padLeft(4, "0")}-${now.month.toString().padLeft(2, "0")}-${now.day.toString().padLeft(2, "0")}",' : ''} ${isSearchable ? "lte" : "lt"}: "${(now.year - values.first).toString().padLeft(4, "0")}-${now.month.toString().padLeft(2, "0")}-${now.day.toString().padLeft(2, "0")}"}}',
          );
        } else if (filter.value.toLowerCase().contains("to") &&
            filter.value.split("to").length == 2) {
          bool isValidDate = true;
          List<String> dates = filter.value.split("to");
          for (String date in dates) {
            DateTime? validDate = DateTime.tryParse(date.trim());
            if (validDate == null) {
              isValidDate = false;
              break;
            }
          }
          if (!isValidDate) break;
          searchFilters.add(
            '{$fieldName: {${isSearchable ? "gte" : "gt"}: "${dates[0].trim()}", ${isSearchable ? "lte" : "lt"}: "${dates[1].trim()}"}}',
          );
        } else if (int.tryParse(RegExp(r'^\d+$').firstMatch(filter.value)?.group(0) ?? "") !=
            null) {
          int year = int.parse(RegExp(r'^\d+$').firstMatch(filter.value)?.group(0) ?? "");
          searchFilters.add(
            '{$fieldName: {${isSearchable ? "gte" : "gt"}: "$year-01-01", ${isSearchable ? "lte" : "lt"}: "$year-12-31"}}',
          );
        } else {
          searchFilters.add(
            '{$fieldName: { ${isSearchable ? (equals ? "eq:" : matchPhrase ? "matchPhrase:" : "match:") : "contains:"} "$dateValue" }}',
          );
        }
        break;
      case ModelFieldTypeEnum.bool:
        bool? value = bool.tryParse(filter.value, caseSensitive: false);
        if (value != null) {
          searchFilters.add('{$fieldName: { eq: $value }}');
        }
        break;
      case ModelFieldTypeEnum.enumeration:
        List<String> enums = await gqlQueryEnums(
          enumTypeName: "${model.modelName()}${fieldName.toFirstUpper()}Enum",
        );
        if (enums.contains(filter.value)) {
          searchFilters.add('{$fieldName: { eq: "${filter.value}" }}');
        }
        break;
      case ModelFieldTypeEnum.collection:
        ModelFieldTypeEnum? collectionType = enumFromString<ModelFieldTypeEnum>(
          filter.key.type.ofModelName,
          ModelFieldTypeEnum.values,
        );
        switch (collectionType) {
          case ModelFieldTypeEnum.string:
          case ModelFieldTypeEnum.time:
          case ModelFieldTypeEnum.timestamp:
            searchFilters.add(
              '{$fieldName: { ${isSearchable ? (equals ? "eq:" : matchPhrase ? "matchPhrase:" : wildcard ? "wildcard:" : "matchPhrase:") : "contains:"} "${wildcard ? '"*${filter.value}*"' : '"${filter.value}"'}" }}',
            );

            break;
          case ModelFieldTypeEnum.int:
            if (filter.value.endsWith("and Up") ||
                filter.value.contains("-") && filter.value.split("-").length == 2) {
              List<String> values = filter.value
                  .split("-")
                  .map(
                    (v) =>
                        RegExp(r"\d+\.\d+").firstMatch(v)?.group(0) ??
                        RegExp(r"\d+").firstMatch(v)?.group(0) ??
                        "",
                  )
                  .toList();
              searchFilters.add(
                '{$fieldName: {${isSearchable ? "gte" : "gt"}: ${values.first}, ${values.length > 1 ? "${isSearchable ? "lte" : "lt"}: ${values.last}" : ''}}}',
              );
            } else {
              int? value = int.tryParse(RegExp(r"\d+").firstMatch(filter.value)?.group(0) ?? "");
              if (value != null) {
                searchFilters.add('{$fieldName: { eq: $value }}');
              }
            }
            break;
          case ModelFieldTypeEnum.double:
            if (filter.value.endsWith("and Up") ||
                filter.value.contains("-") && filter.value.split("-").length == 2) {
              List<String> values = filter.value
                  .split("-")
                  .map(
                    (v) =>
                        RegExp(r"\d+\.\d+").firstMatch(v)?.group(0) ??
                        RegExp(r"\d+").firstMatch(v)?.group(0) ??
                        "",
                  )
                  .toList();
              searchFilters.add(
                '{$fieldName: {${isSearchable ? "gte" : "gt"}: ${values.first}, ${values.length > 1 ? "${isSearchable ? "lte" : "lt"}: ${values.last}" : ''}}}',
              );
            } else {
              double? value =
                  double.tryParse(RegExp(r"\d+").firstMatch(filter.value)?.group(0) ?? "");
              if (value != null) {
                searchFilters.add('{$fieldName: { eq: $value }}');
              }
            }
            break;
          case ModelFieldTypeEnum.date:
          case ModelFieldTypeEnum.dateTime:
            String dateValue = filter.value;
            if (filter.value.endsWith("and Up") ||
                filter.value.contains("-") && filter.value.split("-").length == 2) {
              DateTime now = DateTime.now();
              List<int> values = filter.value
                  .split("-")
                  .map(
                    (v) =>
                        int.tryParse(
                          RegExp(r"\d+\.\d+").firstMatch(v)?.group(0) ??
                              RegExp(r"\d+").firstMatch(v)?.group(0) ??
                              "",
                        ) ??
                        0,
                  )
                  .toList();
              searchFilters.add(
                '{$fieldName: {${values.length > 1 ? '${isSearchable ? "gte" : "gt"}: "${(now.year - values.last).toString().padLeft(4, "0")}-${now.month.toString().padLeft(2, "0")}-${now.day.toString().padLeft(2, "0")}",' : ''} ${isSearchable ? "lte" : "lt"}: "${(now.year - values.first).toString().padLeft(4, "0")}-${now.month.toString().padLeft(2, "0")}-${now.day.toString().padLeft(2, "0")}"}}',
              );
            } else if (filter.value.toLowerCase().contains("to") &&
                filter.value.split("to").length == 2) {
              bool isValidDate = true;
              List<String> dates = filter.value.split("to");
              for (String date in dates) {
                DateTime? validDate = DateTime.tryParse(date.trim());
                if (validDate == null) {
                  isValidDate = false;
                  break;
                }
              }
              if (!isValidDate) break;
              searchFilters.add(
                '{$fieldName: {${isSearchable ? "gte" : "gt"}: "${dates[0].trim()}", ${isSearchable ? "lte" : "lt"}: "${dates[1].trim()}"}}',
              );
            } else if (int.tryParse(RegExp(r'^\d+$').firstMatch(filter.value)?.group(0) ?? "") !=
                null) {
              int year = int.parse(RegExp(r'^\d+$').firstMatch(filter.value)?.group(0) ?? "");
              searchFilters.add(
                '{$fieldName: {${isSearchable ? "gte" : "gt"}: "$year-01-01", ${isSearchable ? "lte" : "lt"}: "$year-12-31"}}',
              );
            } else {
              searchFilters.add(
                '{$fieldName: { ${isSearchable ? (equals ? "eq:" : matchPhrase ? "matchPhrase:" : "match:") : "contains:"} "$dateValue" }}',
              );
            }
            break;
          case ModelFieldTypeEnum.bool:
            bool? value = bool.tryParse(filter.value, caseSensitive: false);
            if (value != null) {
              searchFilters.add('{$fieldName: { eq: $value }}');
            }
            break;
          case ModelFieldTypeEnum.enumeration:
            List<String> enums = await gqlQueryEnums(
              enumTypeName: "${model.modelName()}${fieldName.toFirstUpper()}Enum",
            );
            if (enums.contains(filter.value)) {
              searchFilters.add('{$fieldName: { eq: "${filter.value}" }}');
            }
            break;
          case ModelFieldTypeEnum.model:
          case ModelFieldTypeEnum.collection:
          case ModelFieldTypeEnum.embedded:
          case ModelFieldTypeEnum.embeddedCollection:
          case null:
            break;
        }
      case ModelFieldTypeEnum.model:
      case ModelFieldTypeEnum.embedded:
      case ModelFieldTypeEnum.embeddedCollection:
        break;
    }
  }
  return searchFilters;
}
