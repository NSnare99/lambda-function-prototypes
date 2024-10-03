import 'package:base/utilities/extensions/string.dart';
import 'package:flutter/material.dart';
import 'package:rms/view/explore/explorer_data.dart';

class ExplorerTableSettings extends StatefulWidget {
  final ItemsDataSource itemsDataSource;

  final List<String> initialOrChips;
  final Future<void> Function(bool value) showTableSettings;

  const ExplorerTableSettings({
    super.key,
    required this.itemsDataSource,
    this.initialOrChips = const <String>[],
    required this.showTableSettings,
  });

  @override
  State<ExplorerTableSettings> createState() => _ExplorerTableSettingsState();
}

class _ExplorerTableSettingsState extends State<ExplorerTableSettings> {
  Alignment cellAlignment = Alignment.centerLeft;
  double _currentSliderValue = 0;
  List<Alignment> alignmentValues = [Alignment.centerLeft, Alignment.center, Alignment.centerRight];
  ScrollController scrollController = ScrollController();

  @override
  void initState() {
    _currentSliderValue =
        alignmentValues.indexOf(widget.itemsDataSource.cellAlignment).toDouble() <= 0
            ? 0
            : alignmentValues.indexOf(widget.itemsDataSource.cellAlignment).toDouble();

    super.initState();
  }

  @override
  void dispose() {
    widget.itemsDataSource.setCellAlgnment(alignment: alignmentValues[_currentSliderValue.floor()]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: scrollController,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 730),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => widget.showTableSettings(false),
                    icon: const Icon(Icons.arrow_back_outlined),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      height: 24,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Global Settings:",
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("Cell Alignment:"),
                          const Spacer(),
                          Slider(
                            value: _currentSliderValue,
                            max: 2,
                            divisions: 2,
                            label: alignmentValues[_currentSliderValue.floor()]
                                .toString()
                                .split(".")
                                .last
                                .toFirstUpper()
                                .splitCamelCase()
                                .split(" ")
                                .last,
                            onChanged: (double value) {
                              setState(() {
                                _currentSliderValue = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Default Search Tags:",
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PopupMenuButton<String>(
                            itemBuilder: (context) {
                              return widget.itemsDataSource.columns
                                  .where((c) => c.visible == true)
                                  .map((c) => c.columnName)
                                  .toList()
                                  .map(
                                    (c) => PopupMenuItem<String>(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList();
                            },
                            onSelected: (item) async {
                              setState(() {
                                widget.initialOrChips.add(item);
                              });
                            },
                            icon: const Icon(Icons.arrow_drop_down_outlined),
                          ),
                          ...widget.initialOrChips.map((chip) {
                            return Chip(
                              label: Text(
                                chip,
                                style: const TextStyle(fontSize: 12),
                              ),
                              padding: const EdgeInsets.all(4.0),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              onDeleted: () async {
                                if (chip != "External Account" && chip != "Display Name 1") {
                                  setState(() {
                                    widget.initialOrChips.remove(chip);
                                  });
                                }
                              },
                            );
                          }),
                          const Spacer(),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Current Table Settigns:",
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    // const Divider(),
                    // Padding(
                    //   padding: const EdgeInsets.all(8.0),
                    //   child: Column(
                    //     mainAxisSize: MainAxisSize.min,
                    //     crossAxisAlignment: CrossAxisAlignment.start,
                    //     children: [
                    //       const Text("Hide Columns: "),
                    //       GridView.builder(
                    //         itemCount: widget.itemsDataSource.columns.length,
                    //         shrinkWrap: true,
                    //         gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    //           crossAxisCount: 4, // number of items in each row
                    //           mainAxisSpacing: 0.5, // spacing between rows
                    //           crossAxisSpacing: 0.5, // spacing between columns
                    //         ),
                    //         itemBuilder: (context, index) {
                    //           GridColumn gridColumn = widget.itemsDataSource.columns[index];
                    //           return Row(
                    //             mainAxisSize: MainAxisSize.min,
                    //             children: [
                    //               Checkbox(
                    //                 value: widget.itemsDataSource.columns[index].visible,
                    //                 onChanged: (value) => widget.itemsDataSource.buildDataGridRows(
                    //                   newColumns: widget.itemsDataSource.columns.map((wic) {
                    //                     if (wic.columnName == gridColumn.columnName) {
                    //                       return GridColumn(
                    //                         columnName: wic.columnName,
                    //                         label: wic.label,
                    //                         allowEditing: wic.allowEditing,
                    //                         allowFiltering: wic.allowFiltering,
                    //                         allowSorting: wic.allowSorting,
                    //                         autoFitPadding: wic.autoFitPadding,
                    //                         columnWidthMode: wic.columnWidthMode,
                    //                         filterIconPadding: wic.filterIconPadding,
                    //                         filterIconPosition: wic.filterIconPosition,
                    //                         filterPopupMenuOptions: wic.filterPopupMenuOptions,
                    //                         maximumWidth: wic.maximumWidth,
                    //                         minimumWidth: wic.minimumWidth,
                    //                         sortIconPosition: wic.sortIconPosition,
                    //                         visible: value ?? false,
                    //                         width: wic.width,
                    //                       );
                    //                     } else {
                    //                       return wic;
                    //                     }
                    //                   }).toList(),
                    //                 ),
                    //               ),
                    //               Text(gridColumn.columnName),
                    //             ],
                    //           );
                    //         },
                    //       ),
                    //     ],
                    //   ),
                    // ),
                    Container(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
