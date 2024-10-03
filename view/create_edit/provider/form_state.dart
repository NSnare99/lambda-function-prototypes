import 'package:flutter/material.dart';

class FormState extends ChangeNotifier {
  final Map<String, Map<String, dynamic>> _formState = {};
  Map<String, dynamic>? getFormState(String modelName) => _formState[modelName];

  void updateFormState(String modelName, Map<String, dynamic> updates) {
    Map<String, dynamic> updateMap = _formState[modelName] ?? {};
    for (var entry in updates.entries) {
      updateMap[entry.key] = entry.value;
    }
  }

  void removeFormState(String modelName) {
    _formState.remove(modelName);
    notifyListeners();
  }

  void clearFormStates() {
    _formState.clear();
    notifyListeners();
  }
}
