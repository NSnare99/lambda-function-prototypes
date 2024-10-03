import 'package:base/models/TableField.dart';
import 'package:base/models/TableFieldFieldTypeEnum.dart';
import 'package:base/models/TableFieldOption.dart';
import 'package:base/models/User.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:rms/view/explore/logic/graphql_search.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class ExplorerDoubleTap extends StatefulWidget {
  final Map<String, dynamic> item;
  final TableField tableField;
  final User? selectedUser;
  final DataGridCellDoubleTapDetails details;

  const ExplorerDoubleTap({
    super.key,
    required this.details,
    required this.tableField,
    required this.selectedUser,
    required this.item,
  });

  @override
  State<ExplorerDoubleTap> createState() => _ExplorerDoubleTapState();
}

class _ExplorerDoubleTapState extends State<ExplorerDoubleTap> {
  bool isLoading = false;
  List<TableFieldOption> tableFieldOptionsList = [];
  List<DropdownMenuItem<String>> dropdownMenuItems = [];
  dynamic value;

  @override
  void initState() {
    setState(() {
      value = widget.item[widget.details.column.columnName];
    });
    _init();
    super.initState();
  }

  Future<void> _getAdvisorTableFieldOptions() async {
    setState(() {
      isLoading = true;
    });
    SearchResult tableFieldOptions = await searchGraphql(
      model: TableFieldOption.classType,
      isMounted: () => true,
      filter:
          'filter: {and: [{tableFieldOptionsId: {eq:"${widget.tableField.id}"}},{or: [{repId: {eq : "default"}} ,{repId: {eq : "${widget.selectedUser?.id}"}}]}, {_deleted: {ne: true} }]}',
      limit: 1000,
      nextToken: null,
    );
    tableFieldOptionsList.addAll(
      tableFieldOptions.items?.map(TableFieldOption.fromJson).toList() ?? [],
    );
    while (tableFieldOptions.nextToken != null) {
      tableFieldOptions = await searchGraphql(
        nextToken: Uri.encodeComponent(tableFieldOptions.nextToken ?? ""),
        model: TableFieldOption.classType,
        isMounted: () => true,
        filter:
            'filter: {and: [{tableFieldOptionsId: {eq:"${widget.tableField.id}"}},{or: [{repId: {eq : "default"}} ,{repId: {eq : "${widget.selectedUser?.id}"}}]}, {_deleted: {ne: true} }]}',
        limit: 1000,
      );
      tableFieldOptionsList.addAll(
        tableFieldOptions.items?.map(TableFieldOption.fromJson).toList() ?? [],
      );
    }
    dropdownMenuItems.addAll(
      tableFieldOptionsList.map(
        (tfo) => DropdownMenuItem(
          value: tfo.labelText ?? "",
          child: Text(tfo.labelText ?? ""),
        ),
      ),
    );
    setState(() {
      tableFieldOptionsList = tableFieldOptionsList.sorted(
        (a, b) {
          if (a.labelText == null || b.labelText == null) {
            return 0;
          }
          return a.labelText?.toString().compareTo(
                    b.labelText?.toString() ?? "",
                  ) ??
              0;
        },
      );
      isLoading = false;
    });
  }

  Future<void> _init() async {
    if (widget.tableField.fieldType == TableFieldFieldTypeEnum.SingleSelect) {
      await _getAdvisorTableFieldOptions();
    }
  }

  Widget inputWidget() {
    TableFieldFieldTypeEnum? tableFieldFieldTypeEnum = widget.tableField.fieldType;
    if (tableFieldFieldTypeEnum != null) {
      switch (tableFieldFieldTypeEnum) {
        case TableFieldFieldTypeEnum.Text:
          return Container(
            constraints: const BoxConstraints(maxWidth: 230),
            child: TextFormField(
              initialValue: value,
              maxLength: 100,
              onChanged: (v) {
                setState(() {
                  value = v;
                });
              },
            ),
          );
        case TableFieldFieldTypeEnum.Number:
          return TextFormField(
            maxLength: 100,
            initialValue: double.tryParse(value)?.toString(),
            onChanged: (v) {
              setState(() {
                value = double.tryParse(v).toString();
              });
            },
          );
        case TableFieldFieldTypeEnum.Date:
          return TextFormField(
            maxLength: 100,
            onChanged: (v) {
              setState(() {
                value = DateTime.parse(v).toIso8601String();
              });
            },
            decoration: InputDecoration(
              labelText: widget.details.column.columnName,
              helperText: "(${MaterialLocalizations.of(context).dateHelpText})",
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today_outlined),
                onPressed: () => showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(DateTime.now().year - 100),
                  lastDate: DateTime(DateTime.now().year + 100),
                ).then((inputValue) {
                  value =
                      inputValue?.toLocal().toIso8601String() ?? DateTime.now().toIso8601String();
                }),
              ),
            ),
          );
        case TableFieldFieldTypeEnum.SingleSelect:
          setState(() {
            value = (tableFieldOptionsList.isNotEmpty &&
                    (value == "" ||
                        value == null ||
                        !tableFieldOptionsList
                            .map((tfol) => tfol.labelText)
                            .toList()
                            .contains(value)))
                ? tableFieldOptionsList.first.labelText ?? ""
                : value;
          });
          return dropdownMenuItems.isNotEmpty
              ? DropdownButtonFormField<String>(
                  items: dropdownMenuItems,
                  onChanged: (v) {
                    setState(() {
                      value = v ?? "";
                    });
                  },
                  value: value,
                )
              : const Center(
                  child: Text("Please add dropdown options!"),
                );
      }
    }
    return TextFormField(
      onChanged: (v) {
        setState(() {
          value = v;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Form(
                child: inputWidget(),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      child: const Text('Close'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    TextButton(
                      onPressed: value == widget.item[widget.details.column.columnName] ||
                              value?.toString().trim() == ""
                          ? null
                          : () {
                              Navigator.of(context).pop(value);
                            },
                      child: const Text('Confirm'),
                    ),
                  ],
                ),
              ),
            ],
          );
  }
}
