import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/models/User.dart';
import 'package:base/utilities/models/api_gateway_models.dart';
import 'package:flutter/material.dart';
import 'package:rms/view/upload/upload_steps/custom_stepper.dart';
import 'package:rms/view/upload/upload_steps/upload_error_view.dart';

import 'package:rms/view/explore/custom_fields/custom_fields_uploader/cf_loader.dart';

import 'package:rms/view/explore/custom_fields/custom_fields_uploader/cf_upload.dart';

class CustomFieldsUploader extends StatelessWidget {
  final User? selectedUser;
  final String? filter;
  final ModelType<Model> model;
  final List<ModelField> fields;
  final void Function()? back;
  const CustomFieldsUploader({
    super.key,
    required this.back,
    required this.model,
    this.filter,
    required this.selectedUser,
    required this.fields,
  });

  @override
  Widget build(BuildContext context) {
    final List<ExcelError> errors = [];
    final List<ExcelError> uploadErrors = [];
    final List<ExcelCellData> columnCells = [];
    List<StepContent> steps = [
      StepContent(
        title: "Download",
        child: ({required completeStep, required isDisabled, required stepNumber}) =>
            CustomFieldsLoader(
          columnCells: columnCells,
          fields: fields,
          selectedUser: selectedUser,
          filter: filter,
          model: model,
          completeStep: completeStep,
        ),
      ),
      StepContent(
        title: "Upload",
        child: ({required completeStep, required isDisabled, required stepNumber}) {
          return CustomFieldsUpload(
            columnCells: columnCells,
            selectedUser: selectedUser,
            model: model,
            filter: filter,
            errors: errors,
            uploadErrors: uploadErrors,
            completeStep: completeStep,
          );
        },
      ),
      StepContent(
        title: "Check Errors",
        child: ({required completeStep, required isDisabled, required stepNumber}) => Column(
          children: [
            SizedBox(
              height: AppBarTheme.of(context).toolbarHeight,
              width: double.infinity,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    errors.isNotEmpty
                        ? "ERRORS IN PRECHECK - NO DATA UPLOADED: Update the excel sheet and then go back to step $stepNumber and re-upload."
                        : uploadErrors.isNotEmpty
                            ? "Error${uploadErrors.length > 1 ? "s" : ""} occured during upload. Download the errors and upload the error file once it is fixed."
                            : "",
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
            ),
            Expanded(
              child: UploadErrors(
                model: model,
                errors: errors.isEmpty ? uploadErrors : errors,
                columns: ExcelRowData(rowIndex: 1, cells: columnCells),
              ),
            ),
          ],
        ),
      ),
    ];

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: back,
              icon: const Icon(Icons.arrow_back_outlined),
            ),
          ],
        ),
        const SizedBox(
          height: 10,
        ),
        Expanded(
          child: CustomStepper(
            steps: steps,
          ),
        ),
      ],
    );
  }
}
