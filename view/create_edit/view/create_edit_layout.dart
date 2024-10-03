import 'dart:convert';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/models/ModelProvider.dart';
import 'package:base/providers/data_form_state.dart';
import 'package:base/utilities/extensions/string.dart';
import 'package:base/utilities/requests/graphql.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:rms/view/create_edit/logic/process_fields.dart';

class CreateEditLayout extends StatelessWidget {
  final ModelType<Model> model;
  final String? itemId;
  const CreateEditLayout({super.key, required this.model, this.itemId});

  @override
  Widget build(BuildContext context) {
    ScrollController scrollController = ScrollController();
    final Map<String, dynamic> formValues = {};
    return Column(
      children: [
        AppBar(
          leading: const SizedBox(),
          leadingWidth: 0,
          title: Text("${itemId != null ? "Edit" : "Create"} ${model.modelName()}"),
          backgroundColor: Theme.of(context).colorScheme.surface,
          surfaceTintColor: Theme.of(context).colorScheme.onSurface,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Scrollbar(
                thumbVisibility: true,
                controller: scrollController,
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: CreateEdit(
                    model: model,
                    formValues: formValues,
                    itemId: itemId,
                    constraints: constraints,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class CreateEdit extends StatefulWidget {
  final ModelType<Model> model;
  final Map<String, dynamic> formValues;
  final String? itemId;
  final BoxConstraints constraints;
  const CreateEdit({
    super.key,
    required this.model,
    required this.formValues,
    required this.constraints,
    this.itemId,
  });

  @override
  State<CreateEdit> createState() => _CreateEditState();
}

class _CreateEditState extends State<CreateEdit> {
  bool processing = false;
  int progress = 0;
  late Future<Map<String, dynamic>> _getData;
  late ModelSchema schema;
  late Map<String, ModelField> fields = <String, ModelField>{};
  final List<String> removeFieldNames = ['customFields'];
  final List<Widget> widgets = [];
  final _minFieldWidth = 280;
  int maxFieldsPerRow = 1;
  int numberOfRows = 0;
  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  Map<String, dynamic> data = {};

  List<FocusNode> _focusNodes = [];
  List<TextEditingController> _controllers = [];
  final Map<String, GlobalKey<FormFieldState>> _gloablKeyMap = {};

  void _onFocusNodeChange(FocusNode focusNode) async {
    if (!focusNode.hasFocus) {
      int nodeIndex = _focusNodes.indexOf(focusNode);
      if (nodeIndex != -1) {
        TextEditingController controller = _controllers[nodeIndex];
        String fieldKey = fields.keys.elementAt(nodeIndex);
        String? fieldValue = controller.text;
        ModelFieldTypeEnum? fieldType = fields[fieldKey]?.type.fieldType;
        switch (fieldType) {
          case ModelFieldTypeEnum.int:
            data[fieldKey] = int.tryParse(fieldValue);
          case ModelFieldTypeEnum.double:
            data[fieldKey] = double.tryParse(fieldValue);
          case ModelFieldTypeEnum.bool:
            if (fieldValue.toLowerCase() == "true") {
              data[fieldKey] = true;
            } else if (fieldValue.toLowerCase() == "false") {
              data[fieldKey] = false;
            } else {
              data[fieldKey] = null;
            }
          case ModelFieldTypeEnum.collection:
            if (fieldValue != "") {
              if (data[fieldKey] == null) {
                data[fieldKey] = [];
              }
              if (data[fieldKey] is List && !(data[fieldKey] as List).contains(fieldValue)) {
                (data[fieldKey] as List).add(fieldValue);
              }
            }
            if (data[fieldKey] == []) {
              data[fieldKey] = null;
            }
            controller.clear();
          case ModelFieldTypeEnum.date:
            final MaterialLocalizations localizations = MaterialLocalizations.of(context);
            DateTime? dateValue = localizations.parseCompactDate(fieldValue);
            if (dateValue != null) {
              data[fieldKey] = DateFormat("yyyy-MM-dd").format(dateValue);
            }
            _gloablKeyMap[fieldKey]?.currentState?.validate();
          case ModelFieldTypeEnum.time:
          case ModelFieldTypeEnum.dateTime:
          case ModelFieldTypeEnum.timestamp:
          case ModelFieldTypeEnum.enumeration:
          case ModelFieldTypeEnum.model:
          case ModelFieldTypeEnum.embedded:
          case ModelFieldTypeEnum.embeddedCollection:
          case ModelFieldTypeEnum.string:
          case null:
            if (fieldValue != "") {
              data[fieldKey] = fieldValue;
            } else if (data[fieldKey] != null && fieldValue == "") {
              data[fieldKey] = null;
            }
        }
        if (widget.itemId == null) {
          DataFormState().setFormState(
            model: widget.model,
            stateData: DataFormStateData(formData: data, id: widget.itemId),
            create: widget.itemId == null,
          );
          setState(() {});
        }
      }
    }
  }

  @override
  void initState() {
    var entries =
        DataFormState().getFormState(widget.model)?[widget.itemId == null]?.formData.entries;
    if (entries != null) {
      for (MapEntry<String, dynamic> dataEntry in entries) {
        data[dataEntry.key] = dataEntry.value;
      }
    }
    for (ModelSchema schema in ModelProvider.instance.modelSchemas) {
      Map<String, ModelField>? schemaFields = schema.fields;
      if (schema.name == widget.model.modelName() && schemaFields != null) {
        schema = schema;
        schema.fields?.forEach((key, value) {
          if (!removeFieldNames.contains(key)) {
            fields.addAll({key: value});
          }
        });
        break;
      }
    }
    maxFieldsPerRow = (widget.constraints.maxWidth / _minFieldWidth).floor() > 0
        ? (widget.constraints.maxWidth / _minFieldWidth).floor()
        : 1;
    _getData = _getGQL();
    // Initialize focus nodes and controllers based on the number of fields
    _focusNodes = List.generate(fields.length, (index) => FocusNode());
    _controllers = List.generate(
      fields.length,
      (index) => TextEditingController(
        text:
            data[fields.keys.toList()[index]] is String ? data[fields.keys.toList()[index]] : null,
      ),
    );
    // Attach listeners to focus nodes
    for (var focusNode in _focusNodes) {
      focusNode.addListener(() => _onFocusNodeChange(focusNode));
    }
    super.initState();
  }

  @override
  void didUpdateWidget(covariant CreateEdit oldWidget) {
    maxFieldsPerRow = widget.constraints.maxWidth ~/ _minFieldWidth;
    maxFieldsPerRow = maxFieldsPerRow > 0 ? maxFieldsPerRow : 1;
    numberOfRows = (widgets.length / maxFieldsPerRow).ceil();
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    // Dispose of the focus nodes and controllers
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  //Determines possible values of enum field for form
  Future<Map<String, List<String>>> getEnums() async {
    List<String>? enumValues;
    Map<String, List<String>> enumData = {};

    for (var i = 0; i < fields.entries.length; i++) {
      if (fields.entries.elementAt(i).value.type.fieldType == ModelFieldTypeEnum.enumeration) {
        //Name conversion to get name of Enum field
        String enumTypeName =
            "${widget.model.modelName().replaceAll("\$", "")}${fields.entries.elementAt(i).key.toFirstUpper()}Enum";
        enumValues = enumData.entries.any((e) => e.key == enumTypeName)
            ? enumData.entries.firstWhere((e) => e.key == enumTypeName).value
            : [];

        enumValues = await gqlQueryEnums(enumTypeName: enumTypeName);
        enumData.addAll({enumTypeName: enumValues});

        setState(() {
          progress = ((i / fields.entries.length) * 50).floor();
        });
      }
    }
    return enumData;
  }

  Future<Map<String, dynamic>> _getGQL() async {
    Map<String, List<String>> enums = await getEnums();
    if (widget.itemId != null) {
      String? query = widget.itemId != null
          ? generateFullGraphQLGetQuery(model: widget.model, itemIndex: widget.itemId!)
          : null;
      if (query != null) {
        var queryResult = jsonDecode((await gqlQuery(query, authorizationType: "")).body)["data"]
            ["get${widget.model.modelName()}"];
        if (queryResult is Map<String, dynamic>) {
          Map<String, dynamic> queryData = queryResult;
          for (MapEntry<String, dynamic> queryEntry in queryData.entries) {
            if (queryEntry.value != null) {
              data[queryEntry.key] = queryEntry.value;
            }
          }
        }
      }
      if (widget.itemId == null) {
        DataFormState().setFormState(
          model: widget.model,
          stateData: DataFormStateData(formData: data, id: widget.itemId),
          create: widget.itemId == null,
        );
        setState(() {});
      }
    }
    List<int> unusedNodes = [];
    Map<String, ModelType<Model>> modelReferences = {};
    for (var i = 0; i < fields.length; i++) {
      ModelField? field = fields.entries.elementAt(i).value;
      if (field.type.fieldType == ModelFieldTypeEnum.model) {
        if (field.association?.associationType == ModelAssociationEnum.BelongsTo) {
          for (String association in field.association!.targetNames!) {
            modelReferences.addAll({
              association:
                  ModelProvider.instance.getModelTypeByModelName(field.type.ofModelName ?? ""),
            });
          }
        } else {
          modelReferences.addAll({
            "${widget.model.modelName().toFirstLower()}${field.type.ofModelName}Id":
                ModelProvider.instance.getModelTypeByModelName(field.type.ofModelName ?? ""),
          });
        }
      } else if (field.isRequired) {
        _gloablKeyMap.addAll({field.name: GlobalKey<FormFieldState>()});
      }
      var value = data[field.name];
      if (value != null) {
        _controllers[i].text = value.toString();
      }
      if (!field.isReadOnly && mounted) {
        Widget? fieldWidget = processFormField(
          context: context,
          globalKey: _gloablKeyMap[field.name],
          model: widget.model,
          data: data,
          // schema: schema,
          field: field,
          node: _focusNodes[i],
          controller: _controllers[i],
          modelId: widget.itemId,
          collectionFunction: ({
            required dynamic value,
            required bool remove,
            TextEditingController? controller,
          }) {
            List<dynamic> values =
                data[field.name] is List ? (data[field.name] as List).toList() : [];
            if (value != null) {
              if (remove) {
                values.remove(value);
              } else {
                values.add(value);
              }
              data.addAll({field.name: values});
            }
            if (values.isEmpty) {
              data.remove(field.name);
            }
            // set state is to update data
            setState(() {});
            controller?.clear();
          },
          enumData: enums,
          localizations: MaterialLocalizations.of(context),
          modelReferences: modelReferences,
        );
        if (fieldWidget != null) {
          widgets.add(fieldWidget);
        } else {
          unusedNodes.add(i);
        }
      }
    }
    numberOfRows = (widgets.length / maxFieldsPerRow).ceil();
    return data;
  }

  void removeItemsFromList(List<dynamic> list, List<int> indicesToRemove) {
    // Sort the indices in descending order
    indicesToRemove.sort((a, b) => b.compareTo(a));

    // Remove the items starting from the highest index
    for (int index in indicesToRemove) {
      if (index >= 0 && index < list.length) {
        list.removeAt(index);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getData,
      builder: (BuildContext context, AsyncSnapshot<Map<String, dynamic>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: widget.constraints.maxHeight,
            width: double.infinity,
            child: const Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasData) {
          ScrollController scrollController = ScrollController();
          var scrollbar = Scrollbar(
            controller: scrollController,
            child: SingleChildScrollView(
              controller: scrollController,
              child: _getBody(context),
            ),
          );
          return widgets.isEmpty
              ? SizedBox(
                  height: widget.constraints.maxHeight,
                  child: const Center(child: CircularProgressIndicator()),
                )
              : scrollbar;
        } else if (snapshot.hasError) {
          return const Center(child: Text("An error has occured."));
        } else {
          return const Center(child: Text("No data found."));
        }
      },
    );
  }

  Widget _getBody(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FocusScope(
          key: formKey,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: numberOfRows,
            itemBuilder: (context, rowIdx) {
              int startIdx = (rowIdx * maxFieldsPerRow).clamp(0, widgets.length);
              int endIdx = (startIdx + maxFieldsPerRow).clamp(0, widgets.length);
              List<Widget> rowFields = widgets.sublist(startIdx, endIdx);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: rowFields.mapIndexed((index, field) {
                    return SizedBox(
                      width:
                          (widget.constraints.maxWidth / maxFieldsPerRow) - (32 / maxFieldsPerRow),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: field,
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
        SizedBox(
          height: AppBar().preferredSize.height,
          width: double.infinity,
          child: Center(
            child: _sendData(context),
          ),
        ),
      ],
    );
  }

  ElevatedButton _sendData(BuildContext context) {
    return ElevatedButton(
      onPressed: processing
          ? null
          : () async {
              List<String> invalidFields = [];
              for (MapEntry<String, GlobalKey<FormFieldState>> gloablKeyEntry
                  in _gloablKeyMap.entries) {
                if (gloablKeyEntry.value.currentState?.validate() != true) {
                  invalidFields.add(gloablKeyEntry.key.splitCamelCase().toFirstUpper());
                }
              }
              if (invalidFields.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: SizedBox(
                          height: MediaQuery.sizeOf(context).height * .1,
                          width: MediaQuery.sizeOf(context).width,
                          child:
                              Center(child: Text("Required Fields: ${invalidFields.join(", ")}")),
                        ),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  },
                );
                return;
              }
              setState(() {
                processing = true;
              });
              if (data != {}) {
                Response response = await gqlMutation(
                  input: data,
                  model: widget.model,
                  mutationType: widget.itemId != null
                      ? GraphQLMutationType.update
                      : GraphQLMutationType.create,
                );
                if (response.statusCode == 200 && jsonDecode(response.body)["data"] != null) {
                  clearData();
                } else {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) {
                      Size mediaSize = MediaQuery.sizeOf(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(days: 1),
                          content: SizedBox(
                            height: mediaSize.height * .1,
                            width: mediaSize.width,
                            child: Row(
                              children: [
                                Expanded(child: Text(response.body)),
                                SizedBox(
                                  width: mediaSize.width * .1,
                                ),
                                ElevatedButton(
                                  onPressed: ScaffoldMessenger.of(context).hideCurrentSnackBar,
                                  child: const Text("X"),
                                ),
                              ],
                            ),
                          ),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                    },
                  );
                }
              }
              setState(() {
                processing = false;
              });
            },
      child: processing
          ? const CircularProgressIndicator()
          : Text(widget.itemId == null ? "Submit" : "Save"),
    );
  }

  void clearData() {
    if (widget.itemId == null) {
      for (FocusNode node in _focusNodes) {
        int nodeIndex = _focusNodes.indexOf(node);
        if (nodeIndex != -1) {
          TextEditingController controller = _controllers[nodeIndex];
          if (RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
          ).hasMatch(controller.text)) {
            controller.text = UUID.getUUID();
            node.requestFocus();
          } else {
            controller.clear();
          }
        }
      }
      DataFormState().clearFormStates(
        model: widget.model,
      );
      setState(() {
        data = {};
      });
      _focusNodes.first.requestFocus();
    }
  }

  String? generateFullGraphQLGetQuery({
    required ModelType<Model> model,
    required String itemIndex,
  }) {
    String graphqlQuery = "query _ {\n";
    graphqlQuery += '  get${model.modelName()} (id: "$itemIndex") {\n';

    fields.forEach(
      (fieldName, modelField) {
        if (!modelField.isReadOnly) {
          switch (modelField.type.fieldType) {
            case ModelFieldTypeEnum.string:
            case ModelFieldTypeEnum.int:
            case ModelFieldTypeEnum.double:
            case ModelFieldTypeEnum.date:
            case ModelFieldTypeEnum.dateTime:
            case ModelFieldTypeEnum.time:
            case ModelFieldTypeEnum.timestamp:
            case ModelFieldTypeEnum.bool:
            case ModelFieldTypeEnum.enumeration:
              graphqlQuery += '      $fieldName,\n';
            case ModelFieldTypeEnum.collection:
              switch (enumFromString<ModelFieldTypeEnum>(
                modelField.type.ofModelName,
                ModelFieldTypeEnum.values,
              )) {
                case ModelFieldTypeEnum.string:
                case ModelFieldTypeEnum.int:
                case ModelFieldTypeEnum.double:
                case ModelFieldTypeEnum.date:
                case ModelFieldTypeEnum.dateTime:
                case ModelFieldTypeEnum.time:
                case ModelFieldTypeEnum.timestamp:
                case ModelFieldTypeEnum.bool:
                  graphqlQuery += '      $fieldName,\n';
                case ModelFieldTypeEnum.collection:
                case ModelFieldTypeEnum.embedded:
                case ModelFieldTypeEnum.embeddedCollection:
                case ModelFieldTypeEnum.enumeration:
                case ModelFieldTypeEnum.model:
                case null:
              }

            case ModelFieldTypeEnum.model:
            case ModelFieldTypeEnum.embedded:
            case ModelFieldTypeEnum.embeddedCollection:
          }
        }
      },
    );
    graphqlQuery += '    }\n';
    graphqlQuery += '  }\n';

    return graphqlQuery;
  }
}
