import 'dart:convert';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/utilities/extensions/string.dart';
import 'package:base/utilities/validators.dart';
import 'package:collection/collection.dart';
import 'package:dlibphonenumber/dlibphonenumber.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:web_plugins/web_plugins.dart';

String? isValidAWSPhone(String phoneNumber) {
  // Check if the phone number contains a country code
  if (phoneNumber.startsWith('+')) {
    try {
      // Use libphonenumber to validate phone numbers with country code
      var number = PhoneNumberUtil.instance
          .format(PhoneNumberUtil.instance.parse(phoneNumber, null), PhoneNumberFormat.e164);
      if (!PhoneNumberUtil.instance.isViablePhoneNumber(number)) {
        return null;
      }
      if (number.startsWith('+1')) {
        // Validate NANP phone numbers
        final regex = RegExp(r'^\(?([2-9][0-9]{2})\)?[ -.]?([2-9][0-9]{2})[ -.]?([0-9]{4})$');
        return regex.hasMatch(number.replaceAll("+1", "")) ? number.replaceAll("+1", "") : null;
      }
      return number;
    } catch (e) {
      return null;
    }
  } else {
    // Validate NANP phone numbers
    final regex = RegExp(r'^\(?([2-9][0-9]{2})\)?[ -.]?([2-9][0-9]{2})[ -.]?([0-9]{4})$');
    return regex.hasMatch(phoneNumber) ? phoneNumber : null;
  }
}

Future<dynamic> processValue({
  required ModelFieldTypeEnum fieldTypeEnum,
  required ModelField field,
  required String value,
  required String columnName,
  required ModelType<Model> model,
  ModelFieldTypeEnum? collectionType,
  required Map<String, List<String>> enums,
}) async {
  if ((collectionType != null && collectionType == ModelFieldTypeEnum.model) ||
      value.trim() == "") {
    return "";
  }
  switch (fieldTypeEnum) {
    case ModelFieldTypeEnum.string:
      if (RegExp('.*email.*', caseSensitive: false).hasMatch(columnName.toLowerCase())) {
        if (!RegExp(
          r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
        ).hasMatch(value)) {
          throw Exception('Email validation failed.');
        }
      }
      if (RegExp('.*json.*', caseSensitive: false).hasMatch(columnName.toLowerCase())) {
        try {
          jsonDecode(value);
        } catch (_) {
          throw Exception('JSON validation failed.');
        }
      }
      if (RegExp('.*phone.*', caseSensitive: false).hasMatch(columnName.toLowerCase())) {
        String? number = isValidAWSPhone(value);
        if (number == null) {
          throw Exception(
            'Phone number must either follow NANP and or E.164 standards and be a valid phone number',
          );
        }
        value = number;
      }
      if (RegExp('.*ip address.*', caseSensitive: false).hasMatch(columnName.toLowerCase())) {
        if (!FormValidator.isValidIP(value, null)) {
          throw Exception('IP address validation failed.');
        }
      }
      if (RegExp('.*website.*', caseSensitive: false).hasMatch(columnName.toLowerCase())) {
        Uri? tempValue = Uri.tryParse(value);
        if (tempValue == null) {
          throw Exception("Error validating website url.");
        }
        value = tempValue.toString();
      }
      if ((value.trim() == '' || value.trim() == 'null') && field.isRequired) {
        throw Exception("required");
      }
      return value.trim();
    case ModelFieldTypeEnum.int:
      int intValue = int.parse(value);
      return intValue;
    case ModelFieldTypeEnum.double:
      double doubleValue = double.parse(value);
      return doubleValue;
    case ModelFieldTypeEnum.date:
      dynamic tempValue = int.tryParse(value);
      tempValue ??= num.tryParse(value);
      tempValue ??= value;
      var convertedDate = await _convertToDateISO(tempValue);
      return convertedDate;
    case ModelFieldTypeEnum.dateTime:
      dynamic tempValue = int.tryParse(value);
      tempValue ??= num.tryParse(value);
      tempValue ??= value;
      value = await _convertToDateTimeISO(tempValue);
      return value;
    case ModelFieldTypeEnum.time:
      dynamic tempValue = int.tryParse(value);
      tempValue ??= num.tryParse(value);
      tempValue ??= value;
      value = await _convertToTimeISO(tempValue);
      return value;
    case ModelFieldTypeEnum.timestamp:
      dynamic tempValue = int.tryParse(value);
      tempValue ??= num.tryParse(value);
      tempValue ??= value;
      value = _convertToTemporalTimestamp(tempValue).toString();
      return value;
    case ModelFieldTypeEnum.bool:
      if (value.trim().toLowerCase() == "true" || value.trim().toLowerCase() == "false") {
        bool tempValue = bool.parse(value.trim().toLowerCase());
        return tempValue;
      }
      if (field.isRequired) {
        throw Exception("Must be either true or false");
      }
    case ModelFieldTypeEnum.enumeration:
      value = value.replaceAll(" ", "_");
      if (value.startsWith(RegExp('[0-9]'))) {
        value = "_$value";
      }
      String enumTypeName = "${model.modelName()}${columnName.toFirstUpper()}Enum";
      List<String> enumValues = enums[enumTypeName] ?? [];
      if (enumValues.isEmpty || !enumValues.contains(value)) {
        if (field.isRequired || value.trim() != '') {
          throw Exception('"$value" not found in list');
        }
        return null;
      }
      return value;
    case ModelFieldTypeEnum.collection:
      if (collectionType == null && field.isRequired) {
        throw Exception("Collection type not found.");
      }
      List<dynamic> collection = value.split(";");
      List<dynamic> processedCollection = [];
      for (dynamic element in collection) {
        if (collectionType != null) {
          dynamic processedElement = await processValue(
            fieldTypeEnum: collectionType,
            field: field,
            value: element,
            model: model,
            columnName: columnName,
            enums: enums,
          );
          processedCollection.add(processedElement);
        }
      }
      return processedCollection;
    case ModelFieldTypeEnum.model:
    case ModelFieldTypeEnum.embedded:
    case ModelFieldTypeEnum.embeddedCollection:
      break;
  }
}

Future<String> getLocalization() async {
  String output = "en-US";
  if (kIsWeb) {
    output = await WebPlugins().getLocalization() ?? output;
  } else {
    final platformDispatcher = WidgetsBinding.instance.platformDispatcher;
    final locale = platformDispatcher.locale;
    output = locale.toLanguageTag();
  }
  return output;
}

Future<String> _convertToDateISO(dynamic value) async {
  // Try interpreting value as Excel date number
  if (int.tryParse(value.toString()) != null) {
    final excelDateAsNumber = int.parse(value.toString());
    final baseDate = DateTime(1899, 12, 30); // Excel's base date
    final isoDate = baseDate.add(Duration(days: excelDateAsNumber));
    return "${isoDate.year.toString().padLeft(4, '0')}-${isoDate.month.toString().padLeft(2, '0')}-${isoDate.day.toString().padLeft(2, '0')}";
  }

  // Try interpreting value as local date string
  if (value is String) {
    try {
      final String locale = await getLocalization();
      final DateFormat dateFormat = DateFormat.yMd(locale);
      final DateTime dateTime = dateFormat.parse(value);
      return "${dateTime.year.toString().padLeft(4, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}";
    } catch (e) {
      // If parsing fails, try to interpret it directly as ISO8601
      final isoRegExp = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      if (isoRegExp.hasMatch(value)) {
        return value;
      } else {
        throw FormatException("Error parsing date: $e");
      }
    }
  }
  throw const FormatException("Unsupported value type for date conversion.");
}

Future<String> _convertToTimeISO(dynamic value) async {
  // Try interpreting string directly as ISO8601 time format
  if (value is String) {
    final isoRegExp =
        RegExp(r'^[0-2][0-9]:[0-5][0-9](:[0-5][0-9])?(Z|(\+|-)[0-2][0-9]:[0-5][0-9])?$');
    if (isoRegExp.hasMatch(value)) {
      return value;
    }
  }

  // Try interpreting value as Excel time fraction
  double? parsedDouble = double.tryParse(value.toString());
  if (parsedDouble != null) {
    const totalSecondsInDay = 24 * 60 * 60;
    final totalSeconds = (parsedDouble * totalSecondsInDay).round();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}Z";
  }

  // Try interpreting value as local time string
  if (value is String) {
    try {
      final String locale = await getLocalization();
      final DateFormat timeFormat = DateFormat.Hms(locale);
      final DateTime dateTime = timeFormat.parse(value);
      return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}Z";
    } catch (e) {
      throw FormatException("Error parsing time: $e");
    }
  }
  throw const FormatException("Unsupported value type for time conversion.");
}

Future<String> _convertToDateTimeISO(dynamic value) async {
  // Check if value is already in the expected ISO8601 datetime format
  final isoRegExp = RegExp(
    r'^\d{4}-\d{2}-\d{2}T[0-2][0-9]:[0-5][0-9](:[0-5][0-9](\.\d{1,9})?)?(Z|(\+|-)[0-2][0-9]:[0-5][0-9])?$',
  );
  if (value is String && isoRegExp.hasMatch(value)) {
    return value;
  }

  String? datePart;
  String? timePart;

  // Handle Excel date+time (assuming Excel date+time is a decimal, where the integer is the date and the fraction is the time)
  double? parsedDouble = double.tryParse(value.toString());
  if (parsedDouble != null) {
    datePart = await _convertToDateISO(parsedDouble.floor().toString());
    timePart = await _convertToTimeISO((parsedDouble - parsedDouble.floor()).toString());
  }

  // If not an Excel date+time, handle as local datetime string (e.g., "MM/DD/YYYY HH:mm:ss")
  else if (value is String) {
    try {
      final String locale = await getLocalization();
      final DateFormat datetimeFormat = DateFormat.yMd(locale).add_Hms();
      final DateTime dateTime = datetimeFormat.parse(value);
      datePart = await _convertToDateISO(dateTime.toIso8601String().split('T')[0]);
      timePart = await _convertToTimeISO(dateTime.toIso8601String().split('T')[1].split('.')[0]);
    } catch (e) {
      throw FormatException("Error parsing datetime: $e");
    }
  }

  if (datePart != null && timePart != null) {
    return "${datePart}T${timePart}Z";
  }

  throw const FormatException("Unsupported value type for datetime conversion.");
}

TemporalTimestamp _convertToTemporalTimestamp(dynamic value) {
  DateTime dateTime;

  // Handle value if it's already a Unix timestamp
  if (value is int) {
    dateTime = DateTime.fromMillisecondsSinceEpoch(value * 1000);
  }

  // Handle value if it's in ISO8601 format
  else if (value is String) {
    final isoRegExp = RegExp(
      r'^\d{4}-\d{2}-\d{2}T[0-2][0-9]:[0-5][0-9](:[0-5][0-9](\.\d{1,9})?)?(Z|(\+|-)[0-2][0-9]:[0-5][0-9])?$',
    );
    if (isoRegExp.hasMatch(value)) {
      dateTime = DateTime.parse(value);
    }

    // Handle value if it's in local datetime format
    else {
      try {
        final locale = getLocalization();
        final datetimeFormat = DateFormat.yMd(locale).add_Hms();
        dateTime = datetimeFormat.parse(value);
      } catch (e) {
        throw FormatException("Error parsing datetime: $e");
      }
    }
  }

  // Handle Excel date+time
  else if (value is num) {
    final dateFromExcel = DateTime(1899, 12, 30).add(Duration(days: value.floor()));
    final timeFromExcel = Duration(seconds: ((value - value.floor()) * 86400).round());
    dateTime = dateFromExcel.add(timeFromExcel);
  } else {
    throw const FormatException("Unsupported value type for TemporalTimestamp conversion.");
  }

  return TemporalTimestamp(dateTime);
}
