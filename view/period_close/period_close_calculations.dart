import 'dart:convert';
import 'dart:math';
import 'package:base/models/ModelProvider.dart';
import 'package:base/utilities/models/api_gateway_models.dart';
import 'package:base/utilities/requests/api_gateway.dart';
import 'package:base/utilities/requests/graphql.dart';
import 'package:http/http.dart';
import 'package:rms/view/explore/logic/graphql_search.dart';
import 'package:rms/view/period_close/period_close_stepper.dart';
import 'package:rms/view/report_generation/report_generator.dart';

Future<List<ExcelError>> recalculatePendingCommissions() async {
  List<ExcelError> recalculationErrors = [];
  String fileName = "";
  List<String> logFileNamesForRetrieval = [];
  String? nextToken;
  bool continueSearching = true;
  while (continueSearching) {
    await searchGraphql(
      limit: 100,
      model: ModelProvider().getModelTypeByModelName("PendingCommission"),
      isMounted: () => true,
      nextToken: nextToken != null ? Uri.encodeComponent(nextToken!) : null,
    ).then((value) async {
      nextToken = value.nextToken;
      if (value.items != null) {
        if (value.items!.isNotEmpty) {
          fileName = "${DateTime.now().millisecondsSinceEpoch}-period-close-calculation.JSON";
          logFileNamesForRetrieval.add(fileName);
          await apiGatewayPOST(
            server: Uri.parse(
              '$newEndpoint/periodCloseStateMachine',
            ),
            payload: {
              "input": value.items,
              "fileName": fileName,
              "recalculate": true,
              "awaitingNotification": false,
            },
          );
        }
      }
    });
    if (nextToken == null) {
      continueSearching = false;
    }
  }

  late Response logStreamResponse;
  bool responseConfirmation = false;
  Map<String, dynamic> error = {};

  for (int logStreamIndex = 0; logStreamIndex < logFileNamesForRetrieval.length; logStreamIndex++) {
    while (!responseConfirmation) {
      logStreamResponse = await apiGatewayPOST(
        server: Uri.parse(
          '$newEndpoint/periodCloseStateMachine',
        ),
        payload: {
          "awaitingNotification": true,
          "fileName": logFileNamesForRetrieval[logStreamIndex],
        },
      );

      if (logStreamResponse.statusCode == 200) {
        error = jsonDecode(logStreamResponse.body);
        for (int msgIndex = 0; msgIndex < error["events"].length; msgIndex++) {
          recalculationErrors.add(
              ExcelError(sheet: "", row: 0, col: 0, error: error["events"][msgIndex]["message"]));
        }

        responseConfirmation = true;
      }
    }
    responseConfirmation = false;
  }
  return recalculationErrors;
}

Future<List<ExcelError>> closePendingCommissionsPeriod() async {
  String? nextToken;
  List<ExcelError> periodClosePostingErrors = [];
  bool continueSearching = true;
  String commPeriod =
      '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

  List<Map<String, dynamic>> queriedPendingCommissions = [];
  List<Map<String, dynamic>> queriedPendingAdjustments = [];
  Map<String, dynamic> reportData =
      jsonDecode(await generateReportMapData({}, Report.commissionPayableSummary.name));
  for (int balancesIndexETF = 0;
      balancesIndexETF < reportData["ETFSummary"]["repSummaries"].length;
      balancesIndexETF++) {
    await gqlMutation(
      input: {
        "commPeriod": commPeriod,
        "orgID": reportData["ETFSummary"]["repSummaries"][balancesIndexETF]["orgId"],
        "payable": reportData["ETFSummary"]["repSummaries"][balancesIndexETF]["payable"],
        "repOnTradeID": reportData["ETFSummary"]["repSummaries"][balancesIndexETF]["repId"],
        "yTD1099": reportData["ETFSummary"]["repSummaries"][balancesIndexETF]["YTD1099"],
        "balance": reportData["ETFSummary"]["repSummaries"][balancesIndexETF]["balance"],
      },
      model: AdvisorBalance.classType,
      mutationType: GraphQLMutationType.create,
    );
  }

  for (int balancesIndexNonETF = 0;
      balancesIndexNonETF < reportData["nonETFSummary"]["repSummaries"].length;
      balancesIndexNonETF++) {
    await gqlMutation(
      input: {
        "commPeriod": commPeriod,
        "orgID": reportData["nonETFSummary"]["repSummaries"][balancesIndexNonETF]["orgId"],
        "payable": reportData["nonETFSummary"]["repSummaries"][balancesIndexNonETF]["payable"],
        "repOnTradeID": reportData["nonETFSummary"]["repSummaries"][balancesIndexNonETF]["repId"],
        "yTD1099": reportData["nonETFSummary"]["repSummaries"][balancesIndexNonETF]["YTD1099"],
        "balance": reportData["nonETFSummary"]["repSummaries"][balancesIndexNonETF]["balance"],
      },
      model: AdvisorBalance.classType,
      mutationType: GraphQLMutationType.create,
    );
  }

  while (continueSearching) {
    //Invoke step function
    await searchGraphql(
      limit: 100,
      model: ModelProvider().getModelTypeByModelName("PendingCommission"),
      isMounted: () => true,
      nextToken: nextToken != null ? Uri.encodeComponent(nextToken ?? "") : null,
    ).then((value) async {
      nextToken = value.nextToken;
      if (value.items != null) {
        for (int index = 0; index < value.items!.length; index++) {
          queriedPendingCommissions.add(value.items![index]);
        }
      }
    });

    if (nextToken == null) {
      continueSearching = false;
    }
  }

  for (int index = 0; index < queriedPendingCommissions.length; index++) {
    Map<String, dynamic> itemWithCommPeriod = queriedPendingCommissions[index];
    int versionNumber = itemWithCommPeriod["_version"];
    itemWithCommPeriod["commPeriod"] = commPeriod;
    itemWithCommPeriod.removeWhere((key, value) => value == "" || key == "_version");
    Response response = await gqlMutation(
      input: itemWithCommPeriod,
      model: Commission.classType,
      mutationType: GraphQLMutationType.create,
    );
    Map responseBody = jsonDecode(response.body) is Map ? jsonDecode(response.body) : {};
    if (response.statusCode != 200 || responseBody['data'] == null) {
      // retries
      for (var retry = 0; retry < 3; retry++) {
        await Future.delayed(
          Duration(milliseconds: Random().nextInt(500), seconds: 1),
        );
        response = await gqlMutation(
          input: itemWithCommPeriod,
          model: Commission.classType,
          mutationType: GraphQLMutationType.create,
        );
        responseBody = jsonDecode(response.body) is Map ? jsonDecode(response.body) : {};
        if (response.statusCode == 200 && responseBody['data'] != null) {
          break;
        }
      }

      periodClosePostingErrors
          .add(ExcelError(sheet: "", row: index, col: 0, error: "Error Posting Commission Item"));
    }

    response = await gqlMutation(
      input: {
        "id": queriedPendingCommissions[index]["id"],
        "_version": versionNumber,
      },
      model: PendingCommission.classType,
      mutationType: GraphQLMutationType.delete,
    );
    responseBody = jsonDecode(response.body) is Map ? jsonDecode(response.body) : {};
    if (response.statusCode != 200 || responseBody['data'] == null) {
      // retries
      for (var retry = 0; retry < 3; retry++) {
        await Future.delayed(
          Duration(milliseconds: Random().nextInt(500), seconds: 1),
        );
        response = await gqlMutation(
          input: {
            "id": queriedPendingCommissions[index]["id"],
            "_version": versionNumber,
          },
          model: PendingCommission.classType,
          mutationType: GraphQLMutationType.delete,
        );
        responseBody = jsonDecode(response.body) is Map ? jsonDecode(response.body) : {};
        if (response.statusCode == 200 && responseBody['data'] != null) {
          break;
        }
      }
      periodClosePostingErrors.add(ExcelError(
          sheet: "", row: index, col: 0, error: "Error Deleting Pending Commission Item"));
    }
  }

  continueSearching = true;

  while (continueSearching) {
    //Invoke step function
    await searchGraphql(
      limit: 250,
      model: ModelProvider().getModelTypeByModelName("PendingAdjustment"),
      isMounted: () => true,
      nextToken: nextToken != null ? Uri.encodeComponent(nextToken ?? "") : null,
    ).then((value) async {
      nextToken = value.nextToken;
      if (value.items != null) {
        for (int index = 0; index < value.items!.length; index++) {
          queriedPendingAdjustments.add(value.items![index]);
        }
      }
    });

    if (nextToken == null) {
      continueSearching = false;
    }
  }

  for (int index = 0; index < queriedPendingAdjustments.length; index++) {
    Map<String, dynamic> itemWithCommPeriod = queriedPendingAdjustments[index];
    int versionNumber = itemWithCommPeriod["_version"];
    itemWithCommPeriod["commPeriod"] = commPeriod;
    itemWithCommPeriod.removeWhere((key, value) => value == "" || key == "_version");
    Response response = await gqlMutation(
      input: itemWithCommPeriod,
      model: Adjustment.classType,
      mutationType: GraphQLMutationType.create,
    );
    Map responseBody = jsonDecode(response.body) is Map ? jsonDecode(response.body) : {};
    if (response.statusCode != 200 || responseBody['data'] == null) {
      // retries
      for (var retry = 0; retry < 3; retry++) {
        await Future.delayed(
          Duration(milliseconds: Random().nextInt(500), seconds: 1),
        );
        response = await gqlMutation(
          input: itemWithCommPeriod,
          model: Adjustment.classType,
          mutationType: GraphQLMutationType.create,
        );
        responseBody = jsonDecode(response.body) is Map ? jsonDecode(response.body) : {};
        if (response.statusCode == 200 && responseBody['data'] != null) {
          break;
        }
      }
      periodClosePostingErrors
          .add(ExcelError(sheet: "", row: index, col: 0, error: "Error Posting Adjustment Item"));
    }

    response = await gqlMutation(
      input: {
        "id": queriedPendingAdjustments[index]["id"],
        "_version": versionNumber,
      },
      model: PendingAdjustment.classType,
      mutationType: GraphQLMutationType.delete,
    );
    responseBody = jsonDecode(response.body) is Map ? jsonDecode(response.body) : {};
    if (response.statusCode != 200 || responseBody['data'] == null) {
      // retries
      for (var retry = 0; retry < 3; retry++) {
        await Future.delayed(
          Duration(milliseconds: Random().nextInt(500), seconds: 1),
        );
        response = await gqlMutation(
          input: {
            "id": queriedPendingAdjustments[index]["id"],
            "_version": versionNumber,
          },
          model: PendingAdjustment.classType,
          mutationType: GraphQLMutationType.delete,
        );
        responseBody = jsonDecode(response.body) is Map ? jsonDecode(response.body) : {};
        if (response.statusCode == 200 && responseBody['data'] != null) {
          break;
        }
      }
      periodClosePostingErrors.add(ExcelError(
          sheet: "", row: index, col: 0, error: "Error Deleting Pending Adjustment Item"));
    }
  }
  return periodClosePostingErrors;
}
