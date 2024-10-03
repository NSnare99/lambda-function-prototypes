import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/providers/app_state.dart';
import 'package:base/utilities/models/api_gateway_models.dart';
import 'package:base/utilities/models/join_table_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rms/view/upload/loader_tables.dart';
import 'package:rms/view/upload/upload_steps/custom_stepper.dart';
import 'package:rms/view/upload/upload_steps/upload_error_view.dart';
import 'package:rms/view/upload/upload_steps/upload_file_step.dart';
import 'package:provider/provider.dart';

class UploadFileSteps extends StatelessWidget {
  final ModelType<Model> model;
  final List<String> existingModels;
  final List<String> stopModels;
  final Map<String, String> excelColumnReplacements;
  final Map<String, List<String>> enumData;
  final Map<String, List<JoinTableData>> joinTableData;
  const UploadFileSteps({
    required this.model,
    required this.existingModels,
    super.key,
    required this.excelColumnReplacements,
    required this.enumData,
    required this.stopModels,
    required this.joinTableData,
  });

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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LoaderTables(
                        onDownloadFinished: completeStep,
                        model: model,
                        stopModels: stopModels,
                        enumData: enumData,
                        excelColumnReplacements: excelColumnReplacements,
                        joinTableData: joinTableData,
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
                  model: model,
                  idNormalization: idNormalization,
                  fileNames: fileNames,
                  onUploadFinished: () {
                    completeStep();
                  },
                  excelErrors: excelErrors,
                  uploadErrors: uploadErrors,
                ),
              ),
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
                      'Download and review the errors listed below. Once you have fixed the errors outlined in the list below go back and re-upload error file to move on to the next and fianl step.',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: UploadErrors(
                  model: model,
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
