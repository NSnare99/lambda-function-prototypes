import 'package:flutter/material.dart';

class AdaptiveGrid extends StatelessWidget {
  final double minimumWidgetWidth;
  final List<Widget> children;

  const AdaptiveGrid({super.key, this.minimumWidgetWidth = 100, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Calculate the number of widgets per row considering the available width and padding
        double effectiveWidth = constraints.maxWidth;
        int widgetsPerRow = effectiveWidth ~/ minimumWidgetWidth;
        widgetsPerRow = widgetsPerRow > 0 ? widgetsPerRow : 1;
        widgetsPerRow = children.length < widgetsPerRow ? children.length : widgetsPerRow;

        // Calculate the width for each widget factoring in padding
        double widgetWidth = effectiveWidth / widgetsPerRow;

        // Build grid widgets with dynamic width and padding
        List<Widget> gridWidgets = children.map((widget) {
          return Container(
            width: widgetWidth,
            padding: const EdgeInsets.only(left: 4, bottom: 8, right: 4),
            child: widget,
          );
        }).toList();

        return SingleChildScrollView(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: gridWidgets,
          ),
        );
      },
    );
  }
}
