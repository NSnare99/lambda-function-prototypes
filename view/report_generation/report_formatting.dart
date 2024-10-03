import 'package:intl/intl.dart';

String returnFormattedCurrency(double amount) {
  // Create a NumberFormat instance with the desired formatting
  NumberFormat formatter = NumberFormat.currency(
    locale: 'en_US', // You can change the locale based on your requirements
    symbol: '\$', // Dollar sign
    decimalDigits: 2, // Number of decimal places
  );

  String returnString = formatter.format(amount);
  if (amount < 0) {
    returnString = "(${returnString.replaceAll("-", "")})";
  }

  // Format the amount using the NumberFormat instance
  return returnString;
}
