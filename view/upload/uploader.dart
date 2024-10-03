import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/models/PendingCommission.dart';
import 'package:base/utilities/models/join_table_model.dart';
import 'package:flutter/material.dart';
import 'package:rms/view/upload/upload_steps/commissions/upload_steps_layout_commissions.dart';
import 'package:rms/view/upload/upload_steps/upload_steps_layout.dart';

class Uploader extends StatefulWidget {
  final ModelType<Model> model;
  final List<String> stopModels;
  const Uploader({super.key, required this.model, required this.stopModels});

  @override
  State<Uploader> createState() => _UploaderState();
}

class _UploaderState extends State<Uploader> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  double? circularValue;
  List<Model> modelList = <Model>[];
  Map<String, String> excelColumnReplacements = {};
  Map<String, List<String>> enumData = {};
  Map<String, List<JoinTableData>> joinTableData = {};
  List<String> existingModels = [];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.model == PendingCommission.classType
        ? UploadFileStepsPreProcess(
            stopModels: widget.stopModels,
            model: widget.model,
            existingModels: existingModels,
            excelColumnReplacements: excelColumnReplacements,
            enumData: enumData,
            joinTableData: joinTableData,
          )
        : UploadFileSteps(
            stopModels: widget.stopModels,
            model: widget.model,
            existingModels: existingModels,
            excelColumnReplacements: excelColumnReplacements,
            enumData: enumData,
            joinTableData: joinTableData,
          );
  }
}

// Future<bool> getInitialInformation({
//   required ModelType<Model> model,
//   required List<String> stopModels,
//   required List<String> existingModels,
//   required Map<String, String> excelColumnReplacements,
//   required Map<String, List<String>> enumData,
//   required Map<String, List<JoinTableData>> joinTableData,
//   void Function({required double uploadProgress})? progressCallback,
// }) async {
//   // get potential excel replacements, We need to look at all connections as the stop models may
//   // not review all external Id references
//   double progress = 0;
//   const int numberOfProgressSteps = 2;
//   await schemaProcessing(
//     model: model,
//     previousModels: [],
//     stopModels: [],
//     excelData: [],
//     excelColumnReplacements: excelColumnReplacements,
//     enumData: {},
//     joinTableData: {},
//     progressCallback: ({required double uploadProgress}) {
//       progress = (progress + uploadProgress) / numberOfProgressSteps;
//       if (progressCallback != null) progressCallback(uploadProgress: progress);
//     },
//   );
//   // gather existing models and enum data
//   List<String> previousModels = [];
//   List<ExcelSheetData> excelData = [];
//   await schemaProcessing(
//     model: model,
//     previousModels: previousModels,
//     stopModels: stopModels,
//     excelData: excelData,
//     excelColumnReplacements: excelColumnReplacements,
//     enumData: enumData,
//     joinTableData: joinTableData,
//     progressCallback: ({required double uploadProgress}) {
//       progress = (progress + uploadProgress) / numberOfProgressSteps;
//       if (progressCallback != null) progressCallback(uploadProgress: progress);
//     },
//   );
//   existingModels.sort();
//   return true;
// }
