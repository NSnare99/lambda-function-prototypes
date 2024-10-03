// ignore_for_file: require_trailing_commas

import 'dart:convert';
import 'package:base/models/Advisor.dart';
import 'package:base/models/ModelProvider.dart';
import 'package:base/utilities/extensions/string.dart';
import 'package:base/utilities/models/api_gateway_models.dart';
import 'package:flutter/material.dart';
import 'package:rms/view/period_close/period_close_calculations.dart';
import 'package:rms/view/report_generation/report_downloader.dart';
import 'package:rms/view/report_generation/report_generator.dart';
import 'package:rms/view/upload/upload_steps/custom_stepper.dart';
import 'package:rms/view/upload/upload_steps/upload_error_view.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

//To add new reports in UI, add option
//to enum. When sending the request to generate
//the report, the name of the enum choice is sent to
//the lambda function (ptolemyReportEngine).
enum Report {
  payableBreakdown,
  adjustmentList,
  commissionBasisSummary,
  forPayrollWeekly,
  tradeReportWeekly,
  weeklyReceipts,
  commissionPayableSummary
}

class PeriodCloseStepper extends StatefulWidget {
  const PeriodCloseStepper({
    super.key,
  });

  @override
  State<PeriodCloseStepper> createState() => _PeriodCloseStepperState();
}

class _PeriodCloseStepperState extends State<PeriodCloseStepper> {
  late Map<String, dynamic> _pdfData;
  List<ExcelError> periodCloseErrors = [];
  //Selection of specific report
  late Report selectedReport;
  late String selectedReportName;
  late List<String> reportNameOptions;
  late Map<String, Report> reportNameToReportEnum;

  int periodCloseProgressPercentage = 0;
  String periodCloseProgressMessage = "";

  //Filters for gql query
  String? idSelection = "";
  String? organizationSelection = "";
  TextEditingController orgController = TextEditingController();
  TextEditingController repIdController = TextEditingController();
  //Variables for report download
  bool isDownloadingPDF = false;
  bool isGeneratingReport = false;
  bool isValidStartDate = false;
  bool isValidEndDate = false;
  bool isRecalculatingPeriodData = false;
  bool isPostingPeriodData = false;

  @override
  void initState() {
    super.initState();
    reportNameOptions = [];
    reportNameToReportEnum = {};
    //Based on enum values, generate UI components for report selection
    for (var value in Report.values) {
      String reportAsString = value.name.splitCamelCase();
      reportNameOptions.add(reportAsString);
      reportNameToReportEnum[reportAsString] = value;
    }
    //Set selected report to the first value in list
    selectedReportName = reportNameOptions[0];
    selectedReport = reportNameToReportEnum[selectedReportName]!;
  }

  void toggleReportGenState() {
    setState(() {
      isDownloadingPDF = !isDownloadingPDF;
    });
  }

  @override
  Widget build(BuildContext context) {
    String nextText = "Next Step";
    List<StepContent> steps = [
      StepContent(
        title: "Perform Calculations",
        child: ({
          required dynamic Function() completeStep,
          required bool isDisabled,
          required int stepNumber,
        }) {
          return LayoutBuilder(
            builder: (context, BoxConstraints constraints) {
              return Column(
                children: [
                  const Spacer(),
                  isRecalculatingPeriodData
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: () async {
                            setState(() {
                              isRecalculatingPeriodData = true;
                            });
                            List<ExcelError> errors = await recalculatePendingCommissions();

                            setState(() {
                              periodCloseErrors = errors;
                            });

                            setState(() {
                              isRecalculatingPeriodData = false;
                            });

                            completeStep();
                          },
                          child: const Text(
                            "Recalculate Commissions Data",
                          )),
                  const Spacer(),
                ],
              );
            },
          );
        },
      ),
      StepContent(
        title: "Review Errors",
        child: ({
          required dynamic Function() completeStep,
          required bool isDisabled,
          required int stepNumber,
        }) {
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Wrap(
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(
                      width: 8.0,
                    ),
                    Text(
                      'Download and review the errors listed below. Once you have fixed the errors outlined in the list below go back and re-upload error file to move on to the next and fianl step.',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: UploadErrors(
                  model: ModelProvider().getModelTypeByModelName("PendingCommission"),
                  errors: periodCloseErrors,
                ),
              ),
              Expanded(
                flex: 3,
                child: Container(),
              ),
              Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.all(15.0),
                child: ElevatedButton(
                  onPressed: periodCloseErrors.isNotEmpty
                      ? null
                      : () {
                          completeStep();
                        },
                  child: Text(nextText),
                ),
              ),
            ],
          );
        },
      ),
      StepContent(
        title: "Select Report",
        child: ({
          required dynamic Function() completeStep,
          required bool isDisabled,
          required int stepNumber,
        }) {
          return LayoutBuilder(
            builder: (context, BoxConstraints constraints) {
              return Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(0, 10, 0, 30),
                    child: Wrap(
                      children: [
                        Icon(Icons.info_outline),
                        Text('Select the report'),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 7,
                    child: SizedBox(
                      width: constraints.minWidth > 730 ? 400 : constraints.minWidth * .60,
                      child: Card(
                        surfaceTintColor: Theme.of(context).colorScheme.surface,
                        elevation: 20,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 30, 0, 30),
                          child: ListView.builder(
                            itemCount: reportNameOptions.length,
                            itemBuilder: (context, index) => RadioListTile(
                              value: reportNameOptions[index],
                              groupValue: selectedReportName,
                              onChanged: (value) {
                                setState(() {
                                  selectedReportName = value!;
                                  selectedReport = reportNameToReportEnum[value]!;
                                });
                              },
                              title: Text(reportNameOptions[index]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Container(),
                  ),
                  Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.all(15.0),
                    child: ElevatedButton(
                      onPressed: isDisabled
                          ? null
                          : () {
                              completeStep();
                            },
                      child: Text(nextText),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      StepContent(
        title: "Selection Criteria",
        child: ({
          required dynamic Function() completeStep,
          required bool isDisabled,
          required int stepNumber,
        }) {
          return LayoutBuilder(
            builder: (context, BoxConstraints constraints) {
              return Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(0, 10, 0, 30),
                    child: Wrap(
                      children: [
                        Icon(Icons.info_outline),
                        Text('Enter Organization ID'),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 7,
                    child: SizedBox(
                      width: constraints.minWidth > 730 ? 400 : constraints.minWidth * .60,
                      child: Card(
                        surfaceTintColor: Theme.of(context).colorScheme.surface,
                        elevation: 20,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 30, 10, 30),
                          child: TextField(
                            controller: orgController,
                            onChanged: (value) {
                              setState(() {
                                organizationSelection = value;
                              });
                            },
                            decoration: const InputDecoration(labelText: "Organization ID"),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Container(),
                  ),
                  Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.all(15.0),
                    child: ElevatedButton(
                      onPressed: isDisabled
                          ? null
                          : () {
                              completeStep();
                            },
                      child: Text(nextText),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      StepContent(
        title: "Selection Criteria",
        child: ({
          required dynamic Function() completeStep,
          required bool isDisabled,
          required int stepNumber,
        }) {
          return LayoutBuilder(
            builder: (context, BoxConstraints constraints) {
              return isGeneratingReport
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          const SizedBox(
                            height: 100,
                            width: 100,
                            child: CircularProgressIndicator(),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                                "$periodCloseProgressMessage: $periodCloseProgressPercentage%"),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 10, 0, 30),
                          child: Wrap(
                            children: [
                              const Icon(Icons.info_outline),
                              Text('Enter ${Advisor.classType.modelName()} ID'),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 7,
                          child: SizedBox(
                            width: constraints.minWidth > 730 ? 400 : constraints.minWidth * .60,
                            child: Card(
                              surfaceTintColor: Theme.of(context).colorScheme.surface,
                              elevation: 20,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(10, 30, 10, 30),
                                child: TextField(
                                  controller: repIdController,
                                  onChanged: (value) {
                                    setState(() {
                                      idSelection = value;
                                    });
                                  },
                                  decoration: InputDecoration(
                                      labelText: "${Advisor.classType.modelName()} ID"),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Container(),
                        ),
                        Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.all(15.0),
                          child: ElevatedButton(
                            onPressed: isDisabled
                                ? null
                                : () async {
                                    setState(() {
                                      isGeneratingReport = true;
                                    });
                                    Map<String, dynamic> reportData = await generatePDFReportData(
                                      {
                                        "repId": idSelection == "" ? null : idSelection,
                                        "orgID": organizationSelection == ""
                                            ? null
                                            : organizationSelection,
                                      },
                                      selectedReport.name,
                                      ({
                                        required String progressMessage,
                                        required int progressPercentage,
                                      }) {
                                        setState(() {
                                          periodCloseProgressMessage = progressMessage;
                                          periodCloseProgressPercentage = progressPercentage;
                                        });
                                      },
                                    );

                                    setState(() {
                                      isGeneratingReport = false;
                                      _pdfData = reportData;
                                    });
                                    completeStep();
                                  },
                            child: Text(nextText),
                          ),
                        ),
                      ],
                    );
            },
          );
        },
      ),
      StepContent(
        title: "Download Report",
        child: ({
          required dynamic Function() completeStep,
          required bool isDisabled,
          required int stepNumber,
        }) {
          return Column(
            children: [
              isDownloadingPDF
                  ? const CircularProgressIndicator()
                  : _pdfData.isEmpty
                      ? const Center(
                          child: Text("No Data To Display"),
                        )
                      : OutlinedButton(
                          onPressed: () async {
                            toggleReportGenState();
                            await downloadReportPdfFile(
                              contentType: _pdfData["contentType"]!,
                              dataURI: _pdfData["dataURI"]!,
                              fileName: _pdfData["fileName"]!,
                            );
                            toggleReportGenState();
                          },
                          child: const Text("Download Report"),
                        ),
              Expanded(
                //Send pdf memory data to viewer
                child: SfPdfViewer.memory(
                  base64Decode(_pdfData["dataURI"]!),
                ),
              ),
              Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.all(15.0),
                child: ElevatedButton(
                  onPressed: isDisabled
                      ? null
                      : () {
                          completeStep();
                        },
                  child: Text(nextText),
                ),
              ),
            ],
          );
        },
      ),
      StepContent(
        title: "Close Comm Period",
        child: ({
          required dynamic Function() completeStep,
          required bool isDisabled,
          required int stepNumber,
        }) {
          return LayoutBuilder(
            builder: (context, BoxConstraints constraints) {
              return Column(
                children: [
                  const Spacer(),
                  isPostingPeriodData
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: () async {
                            setState(() {
                              isPostingPeriodData = true;
                            });

                            periodCloseErrors = await closePendingCommissionsPeriod();

                            setState(() {
                              isPostingPeriodData = false;
                            });
                            completeStep();
                          },
                          child: const Text("Post Commissions to Database")),
                  const Spacer(),
                ],
              );
            },
          );
        },
      ),
      StepContent(
        title: "Review Errors",
        child: ({
          required dynamic Function() completeStep,
          required bool isDisabled,
          required int stepNumber,
        }) {
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Wrap(
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(
                      width: 8.0,
                    ),
                    Text(
                      'Download and review the errors listed below. Once you have fixed the errors outlined in the list below go back and re-upload error file to move on to the next and fianl step.',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: UploadErrors(
                  model: ModelProvider().getModelTypeByModelName("PendingCommission"),
                  errors: periodCloseErrors,
                ),
              ),
              Expanded(
                flex: 3,
                child: Container(),
              ),
              Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.all(15.0),
                child: ElevatedButton(
                  onPressed: isDisabled
                      ? null
                      : () {
                          completeStep();
                        },
                  child: Text(nextText),
                ),
              ),
            ],
          );
        },
      ),
    ];

    return CustomStepper(steps: steps);
  }
}
