import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/utilities/extensions/string.dart';
import 'package:base/utilities/models/api_gateway_models.dart';
import 'package:flutter/material.dart';
import 'package:rms/view/adaptive_grid.dart';
import 'package:rms/view/upload/loader_tables.dart';
import 'package:rms/view/upload/upload_steps/logic/upload_logic.dart';
import 'package:rms/view/upload/upload_steps/success_view.dart';

class UploadErrors extends StatefulWidget {
  final ModelType<Model> model;
  final List<ExcelError> errors;
  final ExcelRowData? columns;
  const UploadErrors({
    super.key,
    required this.errors,
    required this.model,
    this.columns,
  });

  @override
  State<UploadErrors> createState() => _UploadErrorsState();
}

class _UploadErrorsState extends State<UploadErrors> {
  ScrollController controller = ScrollController();
  bool noErrorsFound = false;
  bool downloadingExcelFromMemory = false;
  ExcelRowData columns = ExcelRowData(rowIndex: 0, cells: []);
  List<ExcelRowData> rows = [];

  Future<void> _createExcelData() async {
    setState(() {
      downloadingExcelFromMemory = true;
    });
    // columns
    ExcelSheetData excelSheetData = ExcelSheetData(
      sheetName: widget.model.modelName().toFirstUpper().splitCamelCase(),
      columns: ExcelRowData(rowIndex: 0, cells: []),
      rows: [],
    );
    columns =
        widget.columns ?? (await createExcelSheet(excelSheetData, widget.model, null)).columns;
    columns.cells.add(ExcelCellData(columnName: "Error", value: "Error"));
    // rows
    for (ExcelError error in widget.errors) {
      Map<String, dynamic>? data = error.data;
      if (data == null) continue;
      rows.add(
        ExcelRowData(
          rowIndex: error.row,
          cells: data.entries
              .map(
                (e) => ExcelCellData(
                  columnName: e.key.toFirstUpper().splitCamelCase(),
                  value: e.value.toString(),
                ),
              )
              .toList()
            ..add(ExcelCellData(columnName: "Error", value: error.advancedError ?? error.error)),
        ),
      );
    }
    setState(() {
      downloadingExcelFromMemory = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (mounted && widget.errors.isEmpty) {
      return SuccessScreen(onAnimationComplete: () {});
    }

    return Column(
      children: [
        AdaptiveGrid(
          children: [
            Container(),
            Wrap(
              alignment: WrapAlignment.spaceAround,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text("Total Errors: ${widget.errors.length}"),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    "Completed Errors: ${widget.errors.where((ee) => ee.isChecked == true).length}",
                  ),
                ),
              ],
            ),
            Center(
              child: ElevatedButton(
                onPressed: downloadingExcelFromMemory
                    ? null
                    : () async {
                        await _createExcelData();
                        setState(() {
                          downloadingExcelFromMemory = true;
                        });
                        await downloadExcelFromMemory(
                          model: widget.model,
                          columns: columns,
                          rows: rows,
                          fileName: '${DateTime.now().millisecondsSinceEpoch}_errors.xlsx',
                        );
                        setState(() {
                          downloadingExcelFromMemory = false;
                        });
                      },
                child: const Text("Download"),
              ),
            ),
          ],
        ),
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            controller: controller,
            child: ListView.builder(
              prototypeItem: widget.errors.isEmpty
                  ? null
                  : Card(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: widget.errors[0].isChecked
                              ? Theme.of(context).disabledColor
                              : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: CheckboxListTile(
                        title: Wrap(
                          spacing: 40, // space between containers
                          runSpacing: 10, // space between rows
                          children: [
                            SizedBox(
                              width: 300,
                              child: Text('Sheet: ${widget.errors[0].sheet}'),
                            ),
                            SizedBox(
                              width: 100,
                              child: Text('Row: ${widget.errors[0].row}'),
                            ),
                            SizedBox(
                              width: 100,
                              child: Text('Column: ${numberToExcelColumn(widget.errors[0].col)}'),
                            ),
                          ],
                        ),
                        subtitle: Row(
                          children: [
                            Text('Error: ${widget.errors[0].error}'),
                            if (widget.errors[0].advancedError != null)
                              IconButton(
                                onPressed: () => showDialog<void>(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text('Full Error:'),
                                      content: SingleChildScrollView(
                                        child: ListBody(
                                          children: <Widget>[
                                            Text(
                                              widget.errors[0].advancedError ?? "",
                                            ),
                                          ],
                                        ),
                                      ),
                                      actions: <Widget>[
                                        TextButton(
                                          child: const Text('Close'),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                icon: const Icon(Icons.info_outline),
                              ),
                          ],
                        ),
                        value: widget.errors[0].isChecked,
                        onChanged: (newValue) {
                          setState(() {
                            widget.errors[0].isChecked = newValue ?? false;
                          });
                        },
                        secondary: const Icon(Icons.error),
                        controlAffinity: ListTileControlAffinity.trailing,
                      ),
                    ),
              controller: controller,
              itemCount: widget.errors.length,
              itemBuilder: (context, index) {
                final error = widget.errors[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: error.isChecked ? Theme.of(context).disabledColor : Colors.transparent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: CheckboxListTile(
                    title: Wrap(
                      spacing: 40, // space between containers
                      runSpacing: 10, // space between rows
                      children: [
                        SizedBox(
                          width: 300,
                          child: Text(error.sheet),
                        ),
                        if (error.row > 0)
                          SizedBox(
                            width: 100,
                            child: Text('Row: ${error.row}'),
                          ),
                        if (error.col > 0)
                          SizedBox(
                            width: 100,
                            child: Text('Column: ${numberToExcelColumn(error.col)}'),
                          ),
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        Text('Error: ${error.error}'),
                        if (error.advancedError != null)
                          IconButton(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Full Error:'),
                                  content: SingleChildScrollView(
                                    child: ListBody(
                                      children: <Widget>[
                                        Text(
                                          error.advancedError ?? "",
                                        ),
                                      ],
                                    ),
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                      child: const Text('Close'),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                            icon: const Icon(Icons.info_outline),
                          ),
                      ],
                    ),
                    value: error.isChecked,
                    onChanged: (newValue) {
                      setState(() {
                        error.isChecked = newValue ?? false;
                      });
                    },
                    secondary: const Icon(Icons.error),
                    controlAffinity: ListTileControlAffinity.trailing,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
