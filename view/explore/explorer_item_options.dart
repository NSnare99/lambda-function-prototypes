import 'dart:convert';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/utilities/requests/graphql.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class ExplorerItemOptions extends StatelessWidget {
  final SfDataGrid sfDataGrid;
  final String firstIndex;
  final ModelType<Model> model;
  final Future<void> Function(bool) isProcessing;
  final bool allowEditing;
  const ExplorerItemOptions({
    super.key,
    required this.sfDataGrid,
    required this.firstIndex,
    required this.model,
    required this.isProcessing,
    this.allowEditing = false,
  });

  @override
  Widget build(BuildContext context) {
    List<Widget> editingWidgets = [
      IconButton(
        onPressed: sfDataGrid.controller?.selectedRows.length == 1
            ? () {
                List<DataGridCell> cells = sfDataGrid.controller!.selectedRows.first.getCells();
                String elementId = "";
                for (var cell in cells) {
                  if (cell.columnName.toLowerCase() == firstIndex.toLowerCase()) {
                    elementId = cell.value.toString();
                  }
                }
                if (context.mounted && elementId != "") {
                  String fullPath = GoRouterState.of(context).fullPath ?? "";
                  String newPath = "$fullPath/$elementId";
                  if (fullPath.endsWith(":iid")) {
                    newPath = fullPath.replaceFirst(':iid', elementId);
                  }
                  GoRouter.of(context).go(newPath);
                  DefaultTabController.of(context).animateTo(1);
                }
              }
            : null,
        icon: const Icon(Icons.edit_outlined),
      ),
      IconButton(
        onPressed: sfDataGrid.controller?.selectedRows.isNotEmpty == true
            ? () {
                List<DataGridRow> selectedRows = sfDataGrid.controller!.selectedRows;
                showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Delete Items:'),
                      content: SingleChildScrollView(
                        child: ListBody(
                          children: <Widget>[
                            Text(
                              'Delete ${selectedRows.length == 1 ? 'this item?' : 'these ${selectedRows.length} items?'}',
                            ),
                          ],
                        ),
                      ),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('Cancel'),
                          onPressed: () {
                            Navigator.of(context).pop<bool>(false);
                          },
                        ),
                        TextButton(
                          child: const Text('Confirm'),
                          onPressed: () {
                            Navigator.of(context).pop<bool>(true);
                          },
                        ),
                      ],
                    );
                  },
                ).then((value) async {
                  if (value == true) {
                    await isProcessing(true);
                    List<Future<void>> futures = [];
                    for (DataGridRow selectedRow in selectedRows) {
                      futures.add(
                        gqlMutation(
                          input: {
                            firstIndex:
                                '${selectedRow.getCells().firstWhereOrNull((c) => c.columnName.toLowerCase() == firstIndex.toLowerCase())?.value}',
                            "_version": int.tryParse(
                              '${selectedRow.getCells().firstWhereOrNull(
                                    (c) => c.columnName == "Version",
                                  )?.value}',
                            ),
                          },
                          model: model,
                          mutationType: GraphQLMutationType.delete,
                        ).then(
                          (response) {
                            var gqlDataFound = jsonDecode(response.body)['data'] != null;
                            if (response.statusCode == 200 && gqlDataFound) {
                              sfDataGrid.source.rows.remove(selectedRow);
                            }
                          },
                        ),
                      );
                      if (futures.length >= 100) {
                        await Future.wait(futures);
                        futures.clear();
                      }
                    }
                    await Future.wait(futures);
                    await isProcessing(false);
                  }
                });
              }
            : null,
        icon: const Icon(Icons.delete_outline),
      ),
    ];
    return Wrap(
      children: [if (allowEditing) ...editingWidgets],
    );
  }
}
