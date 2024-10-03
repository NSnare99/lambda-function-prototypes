import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/models/ModelProvider.dart';
import 'package:base/utilities/extensions/string.dart';

List<Map<String, dynamic>> parseResult({
  required ModelType<Model> model,
  required Map<String, dynamic> result,
  bool friendlyNames = false,
  bool isSearchable = false,
}) {
  late ModelSchema modelSchema;
  for (ModelSchema schema in ModelProvider.instance.modelSchemas) {
    if (schema.name.toLowerCase() == model.modelName().toLowerCase()) {
      modelSchema = schema;
    }
  }
  List<Map<String, dynamic>> items = [];
  List<dynamic> jsonItems = [];

  try {
    jsonItems =
        result['data']['${isSearchable ? "search" : "list"}${modelSchema.pluralName}']['items'];
    if (jsonItems.isEmpty) return items;
    for (var i = 0; i < jsonItems.length; i++) {
      if (jsonItems[i] is Map<String, dynamic>) {
        Map<String, dynamic> jsonItem = jsonItems[i];
        Map<String, dynamic> item = {};
        modelSchema.fields?.forEach(
          (fieldName, modelField) {
            if (jsonItem[fieldName] != null) {
              item[friendlyNames ? fieldName.toFirstUpper().splitCamelCase() : fieldName] =
                  jsonItem[fieldName];
            }
          },
        );
        if (jsonItem.containsKey("_version")) {
          item[friendlyNames ? "Version" : "_version"] = jsonItem["_version"];
        }
        if (item["_deleted"] != true) {
          items.add(item);
        }
      } else {
        safePrint(jsonItems.length);
        safePrint(i);
        safePrint(jsonItems[i]);
      }
    }
  } catch (e) {
    safePrint(jsonItems);
    return items;
  }

  return items;
}
