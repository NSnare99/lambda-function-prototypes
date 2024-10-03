import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/providers/data_form_state.dart';
import 'package:base/utilities/extensions/string.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Widget? processFormField({
  required BuildContext context,
  required ModelType<Model> model,
  required Map<String, dynamic> data,
  // required ModelSchema schema,
  required ModelField field,
  required FocusNode node,
  required TextEditingController controller,
  required Map<String, List<String>> enumData,
  required void Function({
    required dynamic value,
    required bool remove,
    TextEditingController? controller,
  })? collectionFunction,
  GlobalKey<FormFieldState>? globalKey,
  String? modelId,
  double maxFieldWidth = 500,
  bool last = false,
  bool fromCollection = false,
  MaterialLocalizations? localizations,
  Map<String, ModelType<Model>>? modelReferences,
}) {
  ModelFieldTypeEnum fieldType = field.type.fieldType;
  String label = field.name.toFirstUpper().splitCamelCase();
  String helperText =
      ((field.isRequired ? 'required' : '') + (fromCollection ? ' (List)' : "")).trim();
  Widget? suffixIconWidget;
  switch (fieldType) {
    case ModelFieldTypeEnum.string:
    case ModelFieldTypeEnum.int:
    case ModelFieldTypeEnum.double:
      if (fieldType == ModelFieldTypeEnum.string) {
        if (field.name.toLowerCase() == "id" && controller.text == "") {
          node.requestFocus();
          controller.text = UUID.getUUID();
        }
        //   // String? fullPath = GoRouterState.of(context).fullPath;
        //   // if (fullPath != null) {
        //   ModelType<Model> otherModel = ModelProvider.instance.getModelTypeByModelName(
        //     field.name.replaceAll("ID", "").replaceAll(schema.pluralName ?? "", ""),
        //   );
        //   if (modelReferences?[field.name] != null) {
        //     // String onPressedRoute =
        //     //     "${fullPath.substring(0, fullPath.toLowerCase().indexOf(model.modelName().toLowerCase()))}${modelReferences?[field.name]?.modelName().toLowerCase()}";

        //     // if (controller.text.trim() != "") {
        //     //   onPressedRoute =
        //     //       "${otherModel.modelName().toLowerCase()}/${controller.text.trim()}?tab=1";
        //     // }
        //     suffixIconWidget = IconButton(
        //       onPressed: () => GoRouter.of(context).go(otherModel.modelName().toLowerCase()),
        //       icon: const Icon(Icons.search_outlined),
        //     );
        //   }
        //   // }
      }
      TextInputType keyboardType = TextInputType.text;
      String? Function(String?) validator = (s) {
        return field.isRequired && s == "" && data[field.name] == null ? "required" : null;
      };
      if (fieldType == ModelFieldTypeEnum.int) {
        helperText = "$helperText (whole number)";
        keyboardType = TextInputType.number;
        validator = (newValue) {
          return field.isRequired && (newValue == null || newValue.isEmpty)
              ? "required"
              : (newValue != null && int.tryParse(newValue) == null && newValue.isNotEmpty)
                  ? "Invalid number"
                  : null;
        };
      }
      if (fieldType == ModelFieldTypeEnum.double) {
        helperText = "$helperText (decimal)";
        keyboardType = const TextInputType.numberWithOptions(decimal: true);
        validator = (newValue) {
          return field.isRequired && (newValue == null || newValue.isEmpty)
              ? "required"
              : (newValue != null && double.tryParse(newValue) == null && newValue.isNotEmpty)
                  ? "Invalid number"
                  : null;
        };
      }
      return TextFormField(
        key: globalKey,
        focusNode: node,
        controller: controller,
        decoration: InputDecoration(
          border: const UnderlineInputBorder(),
          labelText: label,
          labelStyle: const TextStyle(overflow: TextOverflow.fade),
          alignLabelWithHint: true,
          helperText: helperText,
          helperStyle:
              field.isRequired ? TextStyle(color: Theme.of(context).colorScheme.primary) : null,
          suffixIcon: fieldType == ModelFieldTypeEnum.string ? suffixIconWidget : null,
        ),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        autocorrect: false,
        textInputAction: last ? TextInputAction.done : TextInputAction.next,
        keyboardType: keyboardType,
        enableSuggestions: false,
        validator: validator,
      );
    case ModelFieldTypeEnum.date:
      DateTime? dateValue = DateTime.tryParse(controller.text);
      if (localizations != null && dateValue != null) {
        controller.text = localizations.formatCompactDate(dateValue);
      }
      return CustomDatePicker(
        label: label,
        controller: controller,
        node: node,
        formFieldKey: globalKey,
        helperText:
            ((field.isRequired ? 'required' : '') + (fromCollection ? ' (List)' : "")).trim(),
      );
    case ModelFieldTypeEnum.dateTime:
      controller.text = DateTime.tryParse(data[field.name].toString())?.toIso8601String() ?? "";
      return CustomDateTime(
        formFieldKey: globalKey,
        controller: controller,
        label: label,
        node: node,
        field: field,
      );
    case ModelFieldTypeEnum.time:
      return CustomTime(
        formFieldKey: globalKey,
        controller: controller,
        node: node,
        field: field,
        label: label,
      );
    case ModelFieldTypeEnum.timestamp:
      return CustomTimestampPicker(
        label: label,
        controller: controller,
        formFieldKey: globalKey,
        node: node,
      );
    case ModelFieldTypeEnum.bool:
      List<String> enumValues = ["True", "False"];
      if (data[field.name] != "" && data[field.name] != null) {
        controller.text = data[field.name].toString();
      }
      if (enumValues.isNotEmpty) {
        return CustomDropDown(
          formFieldKey: globalKey,
          node: node,
          label: label,
          field: field,
          fromCollection: fromCollection,
          items: enumValues,
          controller: controller,
        );
      }
      return null;
    case ModelFieldTypeEnum.enumeration:
      List<String> enumValues =
          enumData['${model.modelName()}${field.name.toFirstUpper()}Enum'] ?? [];
      if (data[field.name] != "" && data[field.name] != null) {
        controller.text = data[field.name].toString();
      }
      if (enumValues.isNotEmpty) {
        return CustomDropDown(
          formFieldKey: globalKey,
          node: node,
          label: label,
          field: field,
          fromCollection: fromCollection,
          items: enumValues,
          controller: controller,
        );
      }
      return null;
    case ModelFieldTypeEnum.collection:
      ModelFieldTypeEnum? typeEnum =
          enumFromString<ModelFieldTypeEnum>(field.type.ofModelName, ModelFieldTypeEnum.values);
      if (typeEnum != null) {
        Widget? collectionWidget = processFormField(
          context: context,
          globalKey: globalKey,
          model: model,
          data: data,
          // schema: schema,
          field: field.copyWith(
            type: ModelFieldType(typeEnum),
          ),
          node: node,
          controller: controller,
          collectionFunction: collectionFunction,
          fromCollection: true,
          enumData: enumData,
          localizations: localizations,
          last: last,
          maxFieldWidth: maxFieldWidth,
          modelId: modelId,
        );
        if (collectionWidget != null && collectionWidget is TextFormField) {
          return CollectionsWidget(
            field: field,
            collectionWidget: collectionWidget,
            collectionFunction: collectionFunction,
            model: model,
            itemId: modelId,
          );
        }
      }
      return null;
    case ModelFieldTypeEnum.model:
    case ModelFieldTypeEnum.embedded:
    case ModelFieldTypeEnum.embeddedCollection:
      return null;
  }
}

class CollectionsWidget extends StatefulWidget {
  final ModelType<Model> model;
  final String? itemId;
  final ModelField field;
  final TextFormField collectionWidget;
  final void Function({
    required dynamic value,
    required bool remove,
    TextEditingController? controller,
  })? collectionFunction;
  const CollectionsWidget({
    super.key,
    required this.collectionWidget,
    required this.model,
    this.collectionFunction,
    required this.field,
    this.itemId,
  });

  @override
  State<CollectionsWidget> createState() => _CollectionsWidgetState();
}

class _CollectionsWidgetState extends State<CollectionsWidget> {
  @override
  void initState() {
    widget.collectionWidget.controller?.clear();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var watchList = Provider.of<DataFormState>(context)
        .getFormState(widget.model)?[widget.itemId == null]
        ?.formData[widget.field.name];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        widget.collectionWidget,
        const SizedBox(
          width: 10,
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: Theme.of(context).dividerColor, // Color of the border
                width: 5, // Width of the border
              ),
            ),
          ),
          child: ExcludeFocus(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: watchList is List ? watchList.length : 0,
              itemBuilder: (context, index) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Card(
                        color: AppBarTheme.of(context).backgroundColor,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(watchList[index]),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                if (widget.collectionFunction != null) {
                                  widget.collectionFunction!(
                                    value: watchList[index],
                                    remove: true,
                                  );
                                }
                                setState(() {});
                              },
                              icon: const Icon(Icons.delete_outlined),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class CustomDropDown extends StatefulWidget {
  final String label;
  final ModelField field;
  final List<String> items;
  final TextEditingController controller;
  final bool fromCollection;
  final FocusNode node;
  final GlobalKey<FormFieldState>? formFieldKey;
  const CustomDropDown({
    super.key,
    required this.label,
    required this.field,
    required this.items,
    required this.controller,
    required this.node,
    this.fromCollection = false,
    required this.formFieldKey,
  });

  @override
  State<CustomDropDown> createState() => _CustomDropDownState();
}

class _CustomDropDownState extends State<CustomDropDown> {
  final GlobalKey _menuKey = GlobalKey();
  String? _selectedValue;

  @override
  void initState() {
    _selectedValue = widget.controller.text != "" ? widget.controller.text : null;
    super.initState();
  }

  void _openDropDown() {
    GlobalKey<State<StatefulWidget>> gloabalKey = widget.formFieldKey ?? _menuKey;
    final RenderBox renderBox = gloabalKey.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        // offset.dy + size.height + (const InputDecorationTheme().helperStyle?.height ?? 0),
        offset.dy,
        offset.dx + size.width,
        offset.dy,
      ),
      items: widget.items.map((String value) {
        return PopupMenuItem<String>(
          value: value,
          child: Text(value.split('.').last),
        );
      }).toList(),
    ).then((value) {
      if (value != null) {
        widget.controller.text = value;
        setState(() {
          _selectedValue = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: widget.formFieldKey ?? _menuKey,
      focusNode: widget.node,
      // validator: (s) =>
      //     widget.field.isRequired && s == "" && widget.controller.text != "" ? "required" : null,
      decoration: InputDecoration(
        border: const UnderlineInputBorder(),
        labelText: widget.label,
        labelStyle: const TextStyle(overflow: TextOverflow.fade),
        alignLabelWithHint: true,
        helperText:
            ((widget.field.isRequired ? 'required' : '') + (widget.fromCollection ? ' (List)' : ""))
                .trim(),
        suffixIcon: _selectedValue == null
            ? const Icon(Icons.arrow_drop_down_outlined)
            : IconButton(
                onPressed: _selectedValue != null
                    ? () {
                        widget.node.requestFocus();
                        widget.controller.clear();
                        setState(() {
                          _selectedValue = null;
                        });
                      }
                    : null,
                icon: const Icon(Icons.close_outlined),
              ),
      ),
      controller: widget.controller,
      readOnly: true, // Disable text editing
      enableInteractiveSelection: false, // Disable text selection
      onTap: _openDropDown,
    );
  }
}

class CustomDateTime extends StatefulWidget {
  final String label;
  final ModelField field;
  final TextEditingController controller;
  final GlobalKey<FormFieldState>? formFieldKey;
  final bool fromCollection;
  final FocusNode node;
  const CustomDateTime({
    super.key,
    required this.label,
    required this.field,
    required this.controller,
    required this.node,
    this.fromCollection = false,
    required this.formFieldKey,
  });

  @override
  State<CustomDateTime> createState() => _CustomDateTimeState();
}

class _CustomDateTimeState extends State<CustomDateTime> {
  DateTime? selectedDateTime;

  @override
  void initState() {
    super.initState();
    // Initialize only if initial values are provided
    if (widget.controller.text != "") {
      selectedDateTime = DateTime.tryParse(widget.controller.text);
    }
    _updateController();
  }

  void _updateController() {
    if (selectedDateTime != null) {
      String iso8601String = selectedDateTime!.toIso8601String();
      widget.controller.text = iso8601String;
    } else {
      widget.controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: widget.formFieldKey,
      focusNode: widget.node,
      controller: widget.controller,
      readOnly: true,
      decoration: InputDecoration(
        border: const UnderlineInputBorder(),
        labelText: widget.label,
        labelStyle: const TextStyle(overflow: TextOverflow.fade),
        alignLabelWithHint: true,
        helperText:
            ((widget.field.isRequired ? 'required' : '') + (widget.fromCollection ? ' (List)' : ""))
                .trim(),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: selectedDateTime ?? DateTime.now(),
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2100),
                );
                if (date != null) {
                  setState(() {
                    selectedDateTime = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      selectedDateTime?.hour ?? TimeOfDay.now().hour,
                      selectedDateTime?.minute ?? TimeOfDay.now().minute,
                    );
                    _updateController();
                  });
                }
              },
              icon: const Icon(Icons.date_range_outlined),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: () async {
                final TimeOfDay? pickedTime = await showTimePicker(
                  context: context,
                  initialTime: selectedDateTime != null
                      ? TimeOfDay(hour: selectedDateTime!.hour, minute: selectedDateTime!.minute)
                      : TimeOfDay.now(),
                );
                if (pickedTime != null) {
                  setState(() {
                    selectedDateTime = selectedDateTime != null
                        ? DateTime(
                            selectedDateTime!.year,
                            selectedDateTime!.month,
                            selectedDateTime!.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          )
                        : DateTime(
                            DateTime.now().year,
                            DateTime.now().month,
                            DateTime.now().day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                    _updateController();
                  });
                }
              },
              icon: const Icon(Icons.access_time),
            ),
          ],
        ),
      ),
      autovalidateMode: widget.field.type.fieldType == ModelFieldTypeEnum.string
          ? null
          : AutovalidateMode.onUserInteraction,
      autocorrect: false,
      enableSuggestions: false,
      onChanged: (String? value) {
        widget.controller.text = value ?? "";
      },
    );
  }
}

class CustomTime extends StatefulWidget {
  final String label;
  final ModelField field;
  final TextEditingController controller;
  final GlobalKey<FormFieldState>? formFieldKey;
  final bool fromCollection;
  final FocusNode node;

  const CustomTime({
    super.key,
    required this.label,
    required this.field,
    required this.controller,
    required this.node,
    this.fromCollection = false,
    required this.formFieldKey,
  });

  @override
  State<CustomTime> createState() => _CustomTimeState();
}

class _CustomTimeState extends State<CustomTime> {
  TimeOfDay? selectedTime;

  @override
  void initState() {
    super.initState();
    DateTime? dateTime = DateTime.tryParse("1970-01-01 ${widget.controller.text}");
    if (dateTime != null) {
      selectedTime = TimeOfDay.fromDateTime(dateTime);
    }
    _updateController();
  }

  void _updateController() {
    if (selectedTime != null) {
      // Format as ISO 8601 time (HH:mm:ss)
      // Note: This will not include seconds or timezone info
      widget.controller.text =
          '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}:00';
    } else {
      widget.controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: widget.formFieldKey,
      focusNode: widget.node,
      controller: widget.controller,
      readOnly: true,
      decoration: InputDecoration(
        // ... [rest of your decoration]
        suffixIcon: IconButton(
          onPressed: () async {
            final TimeOfDay? pickedTime = await showTimePicker(
              context: context,
              initialTime: selectedTime ?? TimeOfDay.now(),
            );
            if (pickedTime != null) {
              setState(() {
                selectedTime = pickedTime;
                _updateController();
              });
            }
          },
          icon: const Icon(Icons.access_time),
        ),
      ),
      validator: (s) => widget.field.isRequired && s == ""
          ? "required"
          : DateTime.tryParse("1970-01-01 $s") == null
              ? "Invalid Time"
              : null,
    );
  }
}

class CustomTimestampPicker extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final GlobalKey<FormFieldState>? formFieldKey;
  final FocusNode node;
  final String? helperText;

  const CustomTimestampPicker({
    super.key,
    required this.label,
    required this.controller,
    required this.node,
    required this.formFieldKey,
    this.helperText,
  });

  @override
  State<CustomTimestampPicker> createState() => _CustomTimestampPickerState();
}

class _CustomTimestampPickerState extends State<CustomTimestampPicker> {
  DateTime? selectedDateTime;

  @override
  void initState() {
    super.initState();
    selectedDateTime = DateTime.tryParse(widget.controller.text) ?? DateTime.now();
    _updateController();
  }

  void _updateController() {
    if (selectedDateTime != null) {
      int timestamp = selectedDateTime!.millisecondsSinceEpoch ~/ 1000;
      widget.controller.text = timestamp.toString();
    } else {
      widget.controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: widget.formFieldKey,
      focusNode: widget.node,
      controller: widget.controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_today),
          onPressed: () async {
            DateTime? pickedDate = await showDatePicker(
              context: context,
              initialDate: selectedDateTime ?? DateTime.now(),
              firstDate: DateTime(DateTime.now().year - 100),
              lastDate: DateTime(DateTime.now().year + 100),
            );
            if (mounted && pickedDate != null) {
              TimeOfDay? pickedTime = await showTimePicker(
                // ignore: use_build_context_synchronously
                context: context,
                initialTime: TimeOfDay.fromDateTime(selectedDateTime ?? DateTime.now()),
              );
              if (mounted && pickedTime != null) {
                setState(() {
                  selectedDateTime = DateTime(
                    pickedDate.year,
                    pickedDate.month,
                    pickedDate.day,
                    pickedTime.hour,
                    pickedTime.minute,
                  );
                  _updateController();
                  widget.node.requestFocus();
                  widget.formFieldKey?.currentState?.validate();
                });
              }
            }
          },
        ),
      ),
      validator: (s) {
        String? helperText = widget.helperText;
        return helperText != null &&
                helperText.contains("required") &&
                s == "" &&
                widget.controller.text == ""
            ? "required"
            : null;
      },
    );
  }
}

class CustomDatePicker extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final GlobalKey<FormFieldState>? formFieldKey;
  final FocusNode node;
  final String? helperText;

  const CustomDatePicker({
    super.key,
    required this.label,
    required this.controller,
    required this.node,
    required this.formFieldKey,
    this.helperText,
  });

  @override
  State<CustomDatePicker> createState() => _CustomDatePickerState();
}

class _CustomDatePickerState extends State<CustomDatePicker> {
  DateTime? selectedDateTime;

  @override
  void initState() {
    super.initState();
  }

  void _updateController() {
    if (selectedDateTime != null) {
      final MaterialLocalizations localizations = MaterialLocalizations.of(context);
      final String inputText = localizations.formatCompactDate(selectedDateTime!);
      widget.controller.text = inputText;
    }
  }

  Future<void> getDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDateTime ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 100),
      lastDate: DateTime(DateTime.now().year + 100),
    );
    if (mounted && pickedDate != null) {
      setState(() {
        selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
        );
      });
      _updateController();
      widget.node.requestFocus();
      widget.formFieldKey?.currentState?.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      validator: (s) {
        String? helperText = widget.helperText;
        return (helperText != null &&
                helperText.contains("required") &&
                s == "" &&
                widget.controller.text == "")
            ? "required (${MaterialLocalizations.of(context).dateHelpText})"
            : null;
      },
      key: widget.formFieldKey,
      focusNode: widget.node,
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText?.contains("required") == true
            ? "${widget.helperText} (${MaterialLocalizations.of(context).dateHelpText})"
            : "(${MaterialLocalizations.of(context).dateHelpText})",
        suffixIcon: IconButton(icon: const Icon(Icons.calendar_today_outlined), onPressed: getDate),
      ),
    );
  }
}
