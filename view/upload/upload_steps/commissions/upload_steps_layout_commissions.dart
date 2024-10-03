import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/models/ModelProvider.dart';
import 'package:base/providers/app_state.dart';
import 'package:base/utilities/models/api_gateway_models.dart';
import 'package:base/utilities/models/join_table_model.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rms/view/upload/loader_tables.dart';
import 'package:rms/view/upload/upload_steps/custom_stepper.dart';
import 'package:rms/view/upload/upload_steps/upload_error_view.dart';
import 'package:rms/view/upload/upload_steps/upload_file_step.dart';
import 'package:provider/provider.dart';

class UploadFileStepsPreProcess extends StatefulWidget {
  final ModelType<Model> model;
  final List<String> existingModels;
  final List<String> stopModels;
  final Map<String, String> excelColumnReplacements;
  final Map<String, List<String>> enumData;
  final Map<String, List<JoinTableData>> joinTableData;
  const UploadFileStepsPreProcess({
    required this.model,
    required this.existingModels,
    super.key,
    required this.excelColumnReplacements,
    required this.enumData,
    required this.stopModels,
    required this.joinTableData,
  });

  @override
  State<UploadFileStepsPreProcess> createState() => _UploadFileStepsPreProcessState();
}

class _UploadFileStepsPreProcessState extends State<UploadFileStepsPreProcess> {
  bool isGenericLoader = true;
  bool includeDaysInBillingCycle = true;
  @override
  Widget build(BuildContext context) {
    List<String> fileNames = <String>[];
    List<ExcelError> excelErrors = <ExcelError>[];
    List<ExcelError> uploadErrors = <ExcelError>[];
    const String nextText = 'Next Step';
    AppStateManager appStateManager = Provider.of<AppStateManager>(context);
    Map<String, String> idNormalization = {};

    List<StepContent> steps = [
      StepContent(
        title: "Loader File",
        child: ({
          required dynamic Function() completeStep,
          required bool isDisabled,
          required int stepNumber,
        }) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                height: 60,
                child: Wrap(
                  children: [
                    const Icon(Icons.info_outline),
                    const SizedBox(
                      width: 8.0,
                    ),
                    const Text('Download the loader template or click '),
                    GestureDetector(
                      onTap: isDisabled ? null : completeStep,
                      child: const Text(nextText),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: LoaderTables(
                    onDownloadFinished: completeStep,
                    model: widget.model,
                    stopModels: widget.stopModels,
                    enumData: widget.enumData,
                    excelColumnReplacements: widget.excelColumnReplacements,
                    joinTableData: widget.joinTableData,
                    removeFields: <ModelField>[
                      for (MapEntry<String, ModelField> field in ModelProvider.instance.modelSchemas
                              .firstWhereOrNull((m) => m.name == widget.model.modelName())
                              ?.fields
                              ?.entries
                              .toList() ??
                          [])
                        if (![
                          PendingCommission.PRODUCT.fieldName,
                          PendingCommission.REPONTRADEID.fieldName,
                          PendingCommission.EXTERNALACCOUNT.fieldName,
                          PendingCommission.TRADEDATE.fieldName,
                          PendingCommission.SETTLEDATE.fieldName,
                          PendingCommission.PRINCIPAL.fieldName,
                          PendingCommission.BASIS.fieldName,
                          PendingCommission.DAYSINBILLINGCYCLE.fieldName
                        ].contains(field.value.name)) // does not contain
                          ModelField(
                            name: field.value.name,
                            type: field.value.type,
                            isRequired: field.value.isRequired,
                          ),
                    ],
                  ),
                ),
              ),
              Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.all(8.0),
                height: 60,
                child: ElevatedButton(
                  onPressed: isDisabled ? null : completeStep,
                  child: const Text(nextText),
                ),
              ),
            ],
          );
        },
      ),
      StepContent(
        title: "Upload File",
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
                      'Upload the completed loader file that was from the first step',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: UploadFileStep(
                  onExcelDataReturn: ({required excelSheetData}) async {
                    if (excelSheetData != null) {
                      ExcelSheetData? newSheet;
                      try {
                        //Attempt to convert from vendor upload file to standard upload file
                        newSheet = await convertToStandardLoader(
                            preProcessedSheetData: excelSheetData,
                            fileName: fileNames.last,
                            includeDaysInBillingCycle: includeDaysInBillingCycle,
                            isGenericLoader: isGenericLoader);
                      } catch (e) {
                        if (excelErrors.isEmpty) {
                          excelErrors.add(
                            ExcelError(
                              sheet: excelSheetData.sheetName,
                              row: 0,
                              col: 0,
                              error: "Conversion from Vendor Loader to Standard Loader Failed",
                            ),
                          );
                        }

                        return null;
                      }

                      try {
                        //If newSheet was successfully created, use standard loader file format
                        //to process upload data in state machine. Retrieve any errors
                        return await getProcessedSheetData(
                          preProcessedSheetData: newSheet ?? excelSheetData,
                          excelErrorsCallback: ({
                            required List<ExcelError> errors,
                          }) {
                            excelErrors.addAll(errors);
                          },
                        );
                      } catch (e) {
                        //If nothing was returned from getProcessedSheetData, but
                        //there are no excel errors, this is due to a processing
                        //error not returned from state machine. Provide generic
                        //error message in this case.
                        if (excelErrors.isEmpty) {
                          excelErrors.add(
                            ExcelError(
                              sheet: excelSheetData.sheetName,
                              row: 0,
                              col: 0,
                              error: "Data validation and processing failed",
                            ),
                          );
                        }

                        return newSheet;
                      }
                    }
                    return null;
                  },
                  model: widget.model,
                  idNormalization: idNormalization,
                  fileNames: fileNames,
                  onUploadFinished: () {
                    completeStep();
                  },
                  excelErrors: excelErrors,
                  uploadErrors: uploadErrors,
                ),
              ),
              Expanded(
                  child: Column(
                children: [
                  const Text("Use generic loader for input:"),
                  const SizedBox(
                    height: 8,
                  ),
                  Checkbox(
                    checkColor: Colors.white,
                    value: isGenericLoader,
                    onChanged: (bool? value) {
                      setState(() {
                        isGenericLoader = value!;
                      });
                    },
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  const Text("Include billing days in loader input:"),
                  const SizedBox(
                    height: 12,
                  ),
                  Checkbox(
                    checkColor: Colors.white,
                    value: includeDaysInBillingCycle,
                    onChanged: (bool? value) {
                      setState(() {
                        includeDaysInBillingCycle = value!;
                      });
                    },
                  ),
                ],
              )),
            ],
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
          String filename = fileNames.isNotEmpty ? fileNames.last : "";
          if (filename == "") {
            return const Center(
              child: Text("No file Found"),
            );
          }
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
                      'Review the errors listed below. Once you have fixed the errors outlined in the list below go back and re-upload the file to move on to the next and fianl step.',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: UploadErrors(
                  model: widget.model,
                  errors: excelErrors.isEmpty ? uploadErrors : excelErrors,
                ),
              ),
            ],
          );
        },
      ),
    ];
    if (!appStateManager.showUploaderIntro) {
      return Column(
        children: [
          Text(
            "Upload Workflow",
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(
            height: 30,
          ),
          Text("This workflow will go over these ${steps.length} steps:"),
          ListView.builder(
            shrinkWrap: true,
            itemCount: steps.length,
            itemBuilder: (context, index) {
              return Text('$index: ${steps[index].title}');
            },
          ),
          const SizedBox(
            height: 30,
          ),
          ElevatedButton(
            onPressed: () {
              appStateManager.viewedUploaderIntro();
            },
            child: const Text('Start Workflow'),
          ),
        ],
      );
    }
    return CustomStepper(steps: steps);
  }
}

class ExistingButton extends StatefulWidget {
  final String label;
  const ExistingButton({
    super.key,
    required this.label,
  });

  @override
  State<ExistingButton> createState() => _ExistingButtonState();
}

class _ExistingButtonState extends State<ExistingButton> {
  bool isHover = false;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onHover: (value) => setState(() {
              isHover = value;
            }),
            borderRadius: BorderRadius.circular(50),
            onTap: () => GoRouter.of(context).go("/rms/${widget.label.toLowerCase()}"),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Icon(
                      Icons.list,
                      color: isHover
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(" ${widget.label}"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
