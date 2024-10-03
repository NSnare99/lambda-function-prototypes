import 'package:flutter/material.dart';

class GraphqlExplorerPerPage extends StatefulWidget {
  final int startingIndex;
  final Future<bool> Function(int oldPageIndex, int newPageIndex) handlePageChange;
  final Future<void> Function(bool value) isProcessing;
  const GraphqlExplorerPerPage({
    super.key,
    required this.handlePageChange,
    required this.startingIndex,
    required this.isProcessing,
  });

  @override
  State<GraphqlExplorerPerPage> createState() => _GraphqlExplorerPerPageState();
}

class _GraphqlExplorerPerPageState extends State<GraphqlExplorerPerPage> {
  late int currentPageIndex;

  @override
  void initState() {
    currentPageIndex = widget.startingIndex;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text("Items per page: "),
        const SizedBox(
          width: 5,
        ),
        DropdownButton<String>(
          value: widget.startingIndex.toString(),
          icon: const Icon(Icons.arrow_drop_down),
          items: [
            for (int multiplier in [1, 2, 3, 5, 10])
              DropdownMenuItem(
                value: (widget.startingIndex * multiplier).toString(),
                child: Text((widget.startingIndex * multiplier).toString()),
              ),
            const DropdownMenuItem(
              value: "All",
              child: Text("All"),
            ),
          ],
          onChanged: (s) async {
            int sValueToInt =
                int.tryParse(s ?? widget.startingIndex.toString()) ?? widget.startingIndex;
            await widget.isProcessing(true);

            if (s == "All") {
              await widget.handlePageChange(currentPageIndex, -1);
            } else {
              await widget.handlePageChange(currentPageIndex, sValueToInt);
            }

            await widget.isProcessing(false);
          },
        ),
      ],
    );
  }
}
