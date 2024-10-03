// ignore_for_file: require_trailing_commas

import 'dart:convert';
import 'package:base/models/Advisor.dart';
import 'package:base/providers/app_state.dart';
import 'package:base/utilities/extensions/string.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rms/view/report_generation/report_downloader.dart';
import 'package:rms/view/report_generation/report_generator.dart';
import 'package:rms/view/upload/upload_steps/custom_stepper.dart';
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

class ReportSteps extends StatefulWidget {
  const ReportSteps({
    super.key,
  });

  @override
  State<ReportSteps> createState() => _ReportStepsState();
}

class _ReportStepsState extends State<ReportSteps> {
  late Map<String, dynamic> _pdfData;

  //Selection of specific report
  late Report selectedReport;
  late String selectedReportName;
  late List<String> reportNameOptions;
  late Map<String, Report> reportNameToReportEnum;
  List<String> dateSelectionOptions = [
    "Comm Period",
    "Entered Date",
    "Trade Date",
    "Broker/Dealer Paid Date"
  ];
  String selectedDateOption = "Comm Period";
  int reportProgressPercentage = 0;
  String reportProgressMessage = "";

  //Filters for gql query
  DateTime startDate = DateUtils.dateOnly(DateTime.now());
  DateTime endDate = DateUtils.dateOnly(DateTime.now());
  String idSelection = "";
  String organizationSelection = "";
  TextEditingController repIdController = TextEditingController();
  TextEditingController orgController = TextEditingController();

  //Variables for report download
  bool isDownloadingPDF = false;
  bool isGeneratingReport = false;
  bool isValidStartDate = false;
  bool isValidEndDate = false;

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
    AppStateManager appStateManager = Provider.of<AppStateManager>(context);
    List<StepContent> steps = [
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
        title: "Select Date Range",
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
                        SizedBox(
                          width: 18.0,
                        ),
                        Text(
                          "Enter the date range for the report to filter by.",
                        ),
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
                          child: Column(
                            children: [
                              SizedBox(
                                  width: constraints.maxWidth * .4,
                                  child: TextFormField(
                                    initialValue: DateFormat('yyyy-MM-dd').format(startDate),
                                    decoration: const InputDecoration(
                                      icon: Icon(Icons.date_range),
                                      labelText: 'Enter Start Date',
                                    ),
                                    onChanged: (value) {
                                      try {
                                        DateTime start = DateTime.parse(dateSeparator(value));
                                        setState(() {
                                          isValidStartDate = true;
                                          startDate = start;
                                        });
                                      } catch (e) {
                                        setState(() {
                                          isValidStartDate = false;
                                        });
                                      }
                                    },
                                  )),
                              const SizedBox(
                                height: 10,
                              ),
                              SizedBox(
                                  width: constraints.maxWidth * .4,
                                  child: TextFormField(
                                    initialValue: DateFormat('yyyy-MM-dd').format(endDate),
                                    decoration: const InputDecoration(
                                      icon: Icon(Icons.date_range),
                                      labelText: 'Enter End Date',
                                    ),
                                    onChanged: (value) {
                                      try {
                                        DateTime end = DateTime.parse(dateSeparator(value));
                                        setState(() {
                                          endDate = end;
                                          isValidEndDate = true;
                                        });
                                      } catch (e) {
                                        setState(() {
                                          isValidEndDate = false;
                                        });
                                      }
                                    },
                                  )),
                              SizedBox(
                                height: 275,
                                child: ListView.builder(
                                  itemCount: dateSelectionOptions.length,
                                  itemBuilder: (context, index) => RadioListTile(
                                    value: dateSelectionOptions[index],
                                    groupValue: selectedDateOption,
                                    onChanged: (value) {
                                      setState(() {
                                        selectedDateOption = value!;
                                      });
                                    },
                                    title: Text(dateSelectionOptions[index]),
                                  ),
                                ),
                              )
                            ],
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
                    padding: const EdgeInsets.all(15.0),
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed:
                          isDisabled || !isValidStartDate || !isValidEndDate ? null : completeStep,
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
                            child: Text("$reportProgressMessage: $reportProgressPercentage%"),
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
                                        "startDate": DateFormat('yyyy-MM-dd').format(startDate),
                                        "endDate": DateFormat('yyyy-MM-dd').format(endDate),
                                        "dateVariable": selectedDateOption
                                      },
                                      selectedReport.name,
                                      ({
                                        required String progressMessage,
                                        required int progressPercentage,
                                      }) {
                                        setState(() {
                                          reportProgressMessage = progressMessage;
                                          reportProgressPercentage = progressPercentage;
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
            ],
          );
        },
      ),
    ];

    if (!appStateManager.showUploaderIntro) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(),
          Column(
            children: [
              Text(
                "Report Generator",
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(
                height: 25,
              ),
              Text(
                "Select 'Begin Workflow' to generate a report.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(
                height: 25,
              ),
              OutlinedButton(
                onPressed: () => {appStateManager.viewedUploaderIntro()},
                child: const Text('Begin Workflow'),
              ),
            ],
          ),
          Container(),
        ],
      );
    }

    return CustomStepper(steps: steps);
  }
}

String dateSeparator(String inputDateString) {
  List<String> dateAsList = [];
  inputDateString = inputDateString.trim();
  if (inputDateString.contains('-')) {
    dateAsList = inputDateString.split('-');
  } else if (inputDateString.contains('\\')) {
    dateAsList = inputDateString.split('\\');
  } else if (inputDateString.contains('/')) {
    dateAsList = inputDateString.split('/');
  } else {
    dateAsList = ["", "", ""];
  }
  if (dateAsList.length != 3) {
    dateAsList = ["", "", ""];
  }

  if (dateAsList[0].length == 4) {
    inputDateString = "${dateAsList[0]}-${dateAsList[1]}-${dateAsList[2]}";
  } else {
    inputDateString = "${dateAsList[2]}-${dateAsList[0]}-${dateAsList[1]}";
  }

  return inputDateString;
}
