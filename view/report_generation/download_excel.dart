import 'dart:convert';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/models/ModelProvider.dart';
import 'package:base/utilities/models/api_gateway_models.dart';
import 'package:base/utilities/requests/api_gateway.dart';
import 'package:base/utilities/requests/graphql.dart';
import 'package:collection/collection.dart';
import 'package:http/http.dart';

import 'package:rms/view/explore/logic/graphql_search.dart';
import 'package:rms/view/upload/upload_steps/logic/upload_logic.dart';

Future<void> downloadExcelItems({
  required ModelType<Model> model,
  bool all = false,
  String? customQuery,
  List<String>? includedFields,
  String? nextToken,
}) async {
  List<ExcelCellData> columns = [];
  List<ExcelRowData> rows = [];
  bool areFieldNamesFilled = false;
  //Used for name of downloaded excel file, to ensure unique name
  String dtString = DateTime.now().millisecondsSinceEpoch.toString();
  String? graphqlQuery;
  if (customQuery != null) {
    graphqlQuery = customQuery;
  } else {
    graphqlQuery = await generateGraphqlQuery(
      model: model,
    ); // generate the query with the searchTerm
  }

  if (graphqlQuery != "") {
    Map<String, dynamic> result =
        jsonDecode(await gqlQuery(graphqlQuery!).then((value) => value.body));

    late ModelSchema modelSchema;
    for (ModelSchema schema in ModelProvider.instance.modelSchemas) {
      if (schema.name.toLowerCase() == model.modelName().toLowerCase()) {
        modelSchema = schema;
      }
    }
    // replace with your actual GraphQL client
    // After query complete, expose inside values containing actual data items (id, etc.)

    if (result['data'] != null) {
      List<dynamic> paredResult = result['data']['list${modelSchema.pluralName}']['items'];

      while (all && result['data']['list${modelSchema.pluralName}']['nextToken'] != null) {
        graphqlQuery = await generateGraphqlQuery(
          model: model,
          nextToken:
              Uri.encodeComponent(result['data']['list${modelSchema.pluralName}']['nextToken']),
        );
        result = jsonDecode(await gqlQuery(graphqlQuery!).then((value) => value.body));
        if (result['data'] != null) {
          paredResult = [
            ...paredResult,
            ...result['data']['list${modelSchema.pluralName}']['items'],
          ];
        }
      }

      if (paredResult.isNotEmpty) {
        Map<String, ModelFieldTypeEnum> types = {};
        //Created list of data types of each object
        //Data structure for type is ModelFieldTypeEnum
        modelSchema.fields?.forEach((key, value) {
          types[key] = value.type.fieldType;
        });

        //Real data entries start on column two of the excel sheet, after column headers
        int currentRowNumber = 2;
        //Loop through data items to create excel rows
        for (Map<String, dynamic> jsonItem in paredResult) {
          ExcelRowData row = ExcelRowData(cells: [], rowIndex: currentRowNumber);

          jsonItem.forEach((key, value) {
            //Get type of current data point
            var typeOfEntry = types[key];
            //Only add entry if type isn't null
            if (typeOfEntry != null) {
              //flag for seeing if the column headers row (row 1 in excel sheet) has been populated yet
              if (!areFieldNamesFilled && key != "accessIds") {
                //Creates row of data where columnName and value are the same (for example, the column name of 'id' is 'id')
                columns.add(
                  ExcelCellData(
                    columnName: key,
                    value: key,
                  ),
                );
              }
              //Add actual excel value row
              String tempVal = value.toString();

              if (value.toString() == "null") {
                tempVal = "";
              }
              if (key != "accessIds") {
                row.cells.add(
                  ExcelCellData(
                    columnName: key,
                    value: tempVal,
                  ),
                );
              }
            }
          });
          //After first pass through data, flip flag
          areFieldNamesFilled = true;
          rows.add(row);
          currentRowNumber++;
        }

        ExcelRowData columns0 = ExcelRowData(rowIndex: 1, cells: columns);
        List<ExcelSheetData> sheets = [
          ExcelSheetData(sheetName: "sheet1", columns: columns0, rows: rows),
        ];
        List<ExcelSheetData> newData = sheets;
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
        String fileName = "${dtString}_download_file.xlsx";
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
          }
          // else {
          //   SchedulerBinding.instance.addPostFrameCallback(
          //     (timeStamp) => _sendSnackBarMessage("failed to get loader file"),
          //   );
          //   break;
          // }
        }
      }
    }
  }
}
