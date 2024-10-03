import 'dart:convert';
import 'dart:ui';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/utilities/models/reports_classes.dart';
import 'package:base/utilities/requests/api_gateway.dart';
import 'package:http/http.dart';
import 'package:path/path.dart' as path;
import 'package:rms/view/report_generation/report_downloader.dart';
import 'package:rms/view/report_generation/report_section_generator.dart';

Future<Map<String, dynamic>> generatePDFReportData(
  Map<String, dynamic> filters,
  String selectedReport,
  void Function({
    required int progressPercentage,
    required String progressMessage,
  }) progressUpdateCallback,
) async {
  String fileName = "${UUID.getUUID()}reportTemplate.pptx";
  //Retrieve input data for report engine step function
  //Two file names; one for step function read/write, one for final retrieval upon completion

  progressUpdateCallback(progressMessage: "Calculating report data", progressPercentage: 0);

  //Decode JSON data return
  Map<String, dynamic> reportDataObject =
      jsonDecode(await generateReportMapData(filters, selectedReport));

  if (reportDataObject.isEmpty) {
    return {};
  }

  progressUpdateCallback(
      progressMessage: "Converting report data into Powerpoint Template", progressPercentage: 25);

  //Generate replacements data

  await apiGatewayPOST(
    server: Uri.parse("$endpoint/powerpoint"),
    payload: ReplacementsPayload(
      convertToPDF: true,
      fileKey: fileName,
      groupId: "test",
      //dynamically find appropriate report template
      templateName: "${selectedReport}ReportTemplate.pptx",
      replacementList: [
        Replacement(
          keyword: "_SECTIONS_",
          data: SectionReplacementData(
            separated: true,
            //Create sections based on report

            sections: await sectionsCreatorByReportName(
              selectedReport,
              reportDataObject,
              filters["startDate"],
              filters["endDate"],
              filters["repId"],
            )!,
          ),
          type: "section",
        ),
      ],
    ).toJson(),
  );

  progressUpdateCallback(
      progressMessage: "Converting Powerpoint report into PDF", progressPercentage: 50);

  late Response pdfResponse;

  //Generate PDF
  //Loop through

  pdfResponse = await apiGatewayPOST(
    server: Uri.parse("$endpoint/pdf"),
    payload: {"fileName": fileName},
  );
  if (pdfResponse.statusCode != 504 && pdfResponse.statusCode != 200) {
    for (int pdfIndex = 0; pdfIndex < 20; pdfIndex++) {
      await Future.delayed(const Duration(seconds: 15));
      pdfResponse = await apiGatewayPOST(
        server: Uri.parse("$endpoint/pdf"),
        payload: {"fileName": fileName},
      );
      if (pdfResponse.statusCode == 504 || pdfResponse.statusCode == 200) {
        break;
      }
    }
  }
  //Loop through

  progressUpdateCallback(progressMessage: "Retrieving PDF Report", progressPercentage: 75);

  Map<String, String> reportPDFData = await getPdfData(
    fileName: path.basename(fileName).replaceAll(".pptx", ".pdf"),
  );

  if (reportPDFData.isEmpty) {
    for (int dataResponse = 0; dataResponse < 20; dataResponse++) {
      await Future.delayed(const Duration(seconds: 15));
      reportPDFData = await getPdfData(
        fileName: path.basename(fileName).replaceAll(".pptx", ".pdf"),
      );
      if (reportPDFData.isNotEmpty) {
        break;
      }
    }
  }

  return reportPDFData;
}

Future<String> generateReportMapData(
  Map<String, dynamic> filters,
  String selectedReport,
) async {
  String initialFileName = "${UUID.getUUID()}.JSON";
  String finishedFileName = initialFileName.replaceAll(".JSON", "_finished.JSON");

  Map<String, dynamic> stepFunctionInputData = {
    "fileName": initialFileName,
    "reportName": selectedReport,
  };

  if (filters["repId"] != null) {
    stepFunctionInputData["repId"] = filters["repId"];
  }
  if (filters["orgID"] != null) {
    stepFunctionInputData["orgID"] = filters["orgID"];
  }
  if (filters["startDate"] != null) {
    stepFunctionInputData["startDate"] = filters["startDate"];
  }
  if (filters["endDate"] != null) {
    stepFunctionInputData["endDate"] = filters["endDate"];
  }
  if (filters["dateVariable"] != null) {
    stepFunctionInputData["dateVariable"] = filters["dateVariable"];
  }

  stepFunctionInputData["nextToken"] = "";
  //Invoke step function
  await apiGatewayPOST(
    server: Uri.parse(
      '$newEndpoint/reportStateMachine',
    ),
    payload: stepFunctionInputData,
  );
  //Query completion of report file
  String reportDataText = await getJSONData(fileName: finishedFileName);
  //Make 5 attempts every five seconds if file doesn't exist
  if (reportDataText == "") {
    for (int attemptsCount = 0; attemptsCount < 20; attemptsCount++) {
      await Future.delayed(const Duration(seconds: 15));
      reportDataText = await getJSONData(fileName: finishedFileName);
      if (reportDataText != "") {
        return reportDataText;
      }
    }
  }
  return reportDataText;
}
