import 'package:base/utilities/models/reports_classes.dart';
import 'package:rms/view/report_generation/report_formatting.dart';

//Complete section replacement based on report chose
Future<List<SectionReplacementDataSection>>? sectionsCreatorByReportName(
  String reportName,
  Map<String, dynamic> data,
  String? startDate,
  String? endDate,
  String? repId,
) {
  switch (reportName) {
    case "feeCommissionStatement":
      return sectionsCreatorFeeCommissionStatement(
        data,
        startDate ?? DateTime.now().toString(),
        endDate ?? DateTime.now().toString(),
      );
    case "adjustmentList":
      return sectionsCreatorAdjustment(
        data,
        startDate ?? DateTime.now().toString(),
        endDate ?? DateTime.now().toString(),
      );
    case "payableBreakdown":
      return sectionsCreatorPayableBreakdown(
        data,
        startDate ?? DateTime.now().toString(),
        endDate ?? DateTime.now().toString(),
      );
    case "commissionBasisSummary":
      return sectionsCreatorCommissionBasis(
        data,
        startDate ?? DateTime.now().toString(),
        endDate ?? DateTime.now().toString(),
      );
    case "forPayrollWeekly":
      return sectionsCreatorForPayrollWeekly(
        data,
        startDate ?? DateTime.now().toString(),
        endDate ?? DateTime.now().toString(),
        repId ?? "",
      );
    case "tradeReportWeekly":
      return sectionsCreatorTradeReportWeekly(
        data,
        startDate ?? DateTime.now().toString(),
        endDate ?? DateTime.now().toString(),
        repId ?? "",
      );
    case "weeklyReceipts":
      return sectionsCreatorWeeklyReceipts(
        data,
        startDate ?? DateTime.now().toString(),
        endDate ?? DateTime.now().toString(),
        repId ?? "",
      );
    case "commissionPayableSummary":
      return sectionsCreatorCommissionPayableSummary(
        data,
        startDate ?? DateTime.now().toString(),
        endDate ?? DateTime.now().toString(),
        repId ?? "",
      );
    default:
      return null;
  }
}

Future<List<SectionReplacementDataSection>> sectionsCreatorFeeCommissionStatement(
  Map<String, dynamic> data,
  String startDate,
  String endDate,
) async {
  List<SectionReplacementDataSection> returnList = [];

  returnList.add(SectionReplacementDataSection(name: "Report Header", replacementData: {
    "_REP_ID_": data["repId"],
    "_REP_NAME_": data["repName"],
    "_DATE_INFO_": data["commPeriod"]
  }));

  returnList.add(SectionReplacementDataSection(name: "Program Type Header", replacementData: {}));

  for (int index = 0; index < data["productTypeSummaries"].length; index++) {
    returnList.add(SectionReplacementDataSection(name: "Program Type Entry", replacementData: {
      "_TYPE_": "${data["productTypeSummaries"][index]["productTypeName"]}",
      "_BUSINESS_": "${data["productTypeSummaries"][index]["businessType"]}",
      "_GROSS_FEE_":
          returnFormattedCurrency(data["productTypeSummaries"][index]["grossAdvisorRevenue"]),
      "_RATE_": data["productTypeSummaries"][index]["advisorRate"] == 0
          ? "n/a"
          : "${data["productTypeSummaries"][index]["advisorRate"]}%",
      "_NET_FEE_":
          returnFormattedCurrency(data["productTypeSummaries"][index]["netAdvisorRevenue"]),
    }));
  }

  returnList.add(SectionReplacementDataSection(name: "Program Type Subtotal", replacementData: {
    "_NET_EARN_": returnFormattedCurrency(data["periodSummary"]["advisorRevenueEarned"]),
    "_PRI_BAL_": returnFormattedCurrency(data["periodSummary"]["advisorPriorBalance"]),
    "_NET_PAID_": returnFormattedCurrency(data["periodSummary"]["advisorRevenuePaid"]),
    "_END_BAL_": returnFormattedCurrency(data["periodSummary"]["advisorEndingBalance"]),
    "_YTD_": returnFormattedCurrency(data["periodSummary"]["advisorYTD1099"])
  }));

  for (int summaryIndex = 0; summaryIndex < data["revenueSummaries"].length; summaryIndex++) {
    returnList.add(SectionReplacementDataSection(name: "Program Description", replacementData: {
      "_PROGRAM_TYPE_": "${data["revenueSummaries"][summaryIndex]["productType"]}",
    }));
    for (int businessSourceIndex = 0;
        businessSourceIndex <
            data["revenueSummaries"][summaryIndex]["accountRevenueSummaries"].length;
        businessSourceIndex++) {
      returnList.add(SectionReplacementDataSection(name: "Business Info", replacementData: {
        "_BUSINESS_INFO_":
            "Business from ${data["revenueSummaries"][summaryIndex]["accountRevenueSummaries"][businessSourceIndex]["idNumber"]}, ${data["revenueSummaries"][summaryIndex]["accountRevenueSummaries"][businessSourceIndex]["description"]}"
      }));
      for (int lineItemIndex = 0;
          lineItemIndex <
              data["revenueSummaries"][summaryIndex]["accountRevenueSummaries"][businessSourceIndex]
                      ["accountsApplicable"]
                  .length;
          lineItemIndex++) {
        returnList.add(SectionReplacementDataSection(name: "Account Header", replacementData: {
          "_ACCT_NUM_": maskAccountNumber(data["revenueSummaries"][summaryIndex]
                  ["accountRevenueSummaries"][businessSourceIndex]["accountsApplicable"]
              [lineItemIndex]["accountNumber"]),
          "_ACCT_NAME_": data["revenueSummaries"][summaryIndex]["accountRevenueSummaries"]
              [businessSourceIndex]["accountsApplicable"][lineItemIndex]["accountHolderName"]
        }));
        returnList
            .add(SectionReplacementDataSection(name: "Account Subheader", replacementData: {}));
        returnList.add(SectionReplacementDataSection(name: "Account Entry", replacementData: {
          "_ENTRY_": data["revenueSummaries"][summaryIndex]["accountRevenueSummaries"]
              [businessSourceIndex]["accountsApplicable"][lineItemIndex]["entryID"],
          "_S_DATE_": data["revenueSummaries"][summaryIndex]["accountRevenueSummaries"]
              [businessSourceIndex]["accountsApplicable"][lineItemIndex]["statementDate"],
          "_EXT_ACCT_": maskAccountNumber(data["revenueSummaries"][summaryIndex]
                  ["accountRevenueSummaries"][businessSourceIndex]["accountsApplicable"]
              [lineItemIndex]["accountNumber"]),
          "_TYPE_": data["revenueSummaries"][summaryIndex]["accountRevenueSummaries"]
              [businessSourceIndex]["accountsApplicable"][lineItemIndex]["accountType"],
          "_P_CODE_": data["revenueSummaries"][summaryIndex]["accountRevenueSummaries"]
              [businessSourceIndex]["accountsApplicable"][lineItemIndex]["productCode"],
          "_MODE_": data["revenueSummaries"][summaryIndex]["accountRevenueSummaries"]
              [businessSourceIndex]["accountsApplicable"][lineItemIndex]["mode"],
          "_PRINC_PREM_": returnFormattedCurrency(data["revenueSummaries"][summaryIndex]
                  ["accountRevenueSummaries"][businessSourceIndex]["accountsApplicable"]
              [lineItemIndex]["principal"]),
          "_GROSS_COMM_": returnFormattedCurrency(data["revenueSummaries"][summaryIndex]
                  ["accountRevenueSummaries"][businessSourceIndex]["accountsApplicable"]
              [lineItemIndex]["grossAdvisorRevenue"]),
          "_PAY_": returnFormattedCurrency(data["revenueSummaries"][summaryIndex]
                  ["accountRevenueSummaries"][businessSourceIndex]["accountsApplicable"]
              [lineItemIndex]["advisorRate"]),
          "_NET_FEE_": returnFormattedCurrency(data["revenueSummaries"][summaryIndex]
                  ["accountRevenueSummaries"][businessSourceIndex]["accountsApplicable"]
              [lineItemIndex]["netAdvisorRevenue"]),
          "_DESC_": data["revenueSummaries"][summaryIndex]["accountRevenueSummaries"]
              [businessSourceIndex]["accountsApplicable"][lineItemIndex]["productType"]
        }));
        returnList.add(SectionReplacementDataSection(name: "Account Subtotal", replacementData: {
          "_GROSS_COMM_": returnFormattedCurrency(data["revenueSummaries"][summaryIndex]
                  ["accountRevenueSummaries"][businessSourceIndex]["accountsApplicable"]
              [lineItemIndex]["grossAdvisorRevenue"]),
          "_NET_FEE_": returnFormattedCurrency(data["revenueSummaries"][summaryIndex]
                  ["accountRevenueSummaries"][businessSourceIndex]["accountsApplicable"]
              [lineItemIndex]["netAdvisorRevenue"])
        }));
      }
    }

    returnList
        .add(SectionReplacementDataSection(name: "Program Type Second Subtotal", replacementData: {
      "_BUSINESS_INFO_": "",
      "_GROSS_COMM_": "",
      "_NET_FEE_": "",
      "_PROGRAM_TYPE_": "${data["revenueSummaries"][summaryIndex]["productType"]}"
    }));
  }

  returnList.add(SectionReplacementDataSection(name: "Override Header", replacementData: {}));
  for (int overrideIndex = 0; overrideIndex < data["overrides"].length; overrideIndex++) {
    returnList.add(SectionReplacementDataSection(name: "Override Line Item", replacementData: {
      "_REP_NAME_": data["overrides"][overrideIndex]["repName"],
      "_BUSINESS_": "All",
      "_PROGRAM_": data["overrides"][overrideIndex]["programType"],
      "_GROSS_": returnFormattedCurrency(data["overrides"][overrideIndex]["grossCommission"] ?? 0),
      "_RATE_": "${data["overrides"][overrideIndex]["rate"]}%",
      "_NET_": returnFormattedCurrency(data["overrides"][overrideIndex]["netCommission"] ?? 0)
    }));
  }

  returnList.add(SectionReplacementDataSection(
      name: "Override Grand Total",
      replacementData: {"_NET_": returnFormattedCurrency(data["overrideGrandTotalNet"])}));

  returnList.add(SectionReplacementDataSection(name: "Grand Total", replacementData: {
    "_FEE_": "0",
    "_DEDUCTION_": "0",
    "_INVOICE_": "0",
  }));

  return returnList;
}

Future<List<SectionReplacementDataSection>> sectionsCreatorAdjustment(
  Map<String, dynamic> data,
  String startDate,
  String endDate,
) async {
  double grandCount = 0;
  List<SectionReplacementDataSection> returnList = [];

  returnList.add(
    SectionReplacementDataSection(
      name: "AdjustmentReportHeader",
      replacementData: {
        "_COMM_PERIOD_": DateTime.now().toString().substring(0, 19),
        "_DATE_": "$startDate to $endDate",
      },
    ),
  );

  for (int typeIndex = 0; typeIndex < data["typeSummaries"].length; typeIndex++) {
    returnList.add(
      SectionReplacementDataSection(
        name: "AdjustmentTypeHeader",
        replacementData: {
          "_ADJ_TYPE_": data["typeSummaries"][typeIndex]["typeName"],
        },
      ),
    );
    for (int commIndex = 0;
        commIndex < data["typeSummaries"][typeIndex]["commSummaries"].length;
        commIndex++) {
      returnList.add(
        SectionReplacementDataSection(
          name: "CommGroupHeader",
          replacementData: {
            "_COMM_PERIOD_": data["typeSummaries"][typeIndex]["commSummaries"][commIndex]
                ["commPeriod"],
          },
        ),
      );
      for (int repIndex = 0;
          repIndex <
              data["typeSummaries"][typeIndex]["commSummaries"][commIndex]["repSummaries"].length;
          repIndex++) {
        returnList.add(
          SectionReplacementDataSection(
            name: "RepGroupHeader",
            replacementData: {
              "_REP_INFO_": data["typeSummaries"][typeIndex]["commSummaries"][commIndex]
                  ["repSummaries"][repIndex]["id"],
              "_REP_NAME_": data["typeSummaries"][typeIndex]["commSummaries"][commIndex]
                  ["repSummaries"][repIndex]["name"],
            },
          ),
        );
        for (int adjIndex = 0;
            adjIndex <
                data["typeSummaries"][typeIndex]["commSummaries"][commIndex]["repSummaries"]
                        [repIndex]["AdjList"]
                    .length;
            adjIndex++) {
          returnList.add(
            SectionReplacementDataSection(
              name: "RepEntry",
              replacementData: {
                "_REP_INFO_":
                    "${data["typeSummaries"][typeIndex]["commSummaries"][commIndex]["repSummaries"][repIndex]["AdjList"][adjIndex]["repId"]}     ${data["typeSummaries"][typeIndex]["commSummaries"][commIndex]["repSummaries"][repIndex]["AdjList"][adjIndex]["repName"]}",
                "_COMM_PERIOD_": data["typeSummaries"][typeIndex]["commSummaries"][commIndex]
                    ["repSummaries"][repIndex]["AdjList"][adjIndex]["commPeriod"],
                "_COMM_TYPE_": data["typeSummaries"][typeIndex]["commSummaries"][commIndex]
                    ["repSummaries"][repIndex]["AdjList"][adjIndex]["adjtype"],
                "_AMOUNT_": returnFormattedCurrency(
                  data["typeSummaries"][typeIndex]["commSummaries"][commIndex]["repSummaries"]
                      [repIndex]["AdjList"][adjIndex]["amount"],
                ),
                "_DESCRIPTION_": data["typeSummaries"][typeIndex]["commSummaries"][commIndex]
                    ["repSummaries"][repIndex]["AdjList"][adjIndex]["adjtype"],
                "_ADJ_": "Adj",
              },
            ),
          );
        }
        returnList.add(
          SectionReplacementDataSection(
            name: "RepTotalHeader",
            replacementData: {
              "_COUNT_": data["typeSummaries"][typeIndex]["commSummaries"][commIndex]
                      ["repSummaries"][repIndex]["countByRep"]
                  .toString(),
              "_AMOUNT_": returnFormattedCurrency(
                data["typeSummaries"][typeIndex]["commSummaries"][commIndex]["repSummaries"]
                    [repIndex]["subTotalByRep"],
              ),
            },
          ),
        );
      }

      returnList.add(
        SectionReplacementDataSection(
          name: "CommTotalHeader",
          replacementData: {
            "_COUNT_": data["typeSummaries"][typeIndex]["commSummaries"][commIndex]["countByPeriod"]
                .toString(),
            "_AMOUNT_": returnFormattedCurrency(
              data["typeSummaries"][typeIndex]["commSummaries"][commIndex]["subTotalByPeriod"],
            ),
          },
        ),
      );
    }

    returnList.add(
      SectionReplacementDataSection(
        name: "TypeTotalHeader",
        replacementData: {
          "_COUNT_": data["typeSummaries"][typeIndex]["countBytype"].toString(),
          "_AMOUNT_": returnFormattedCurrency(data["typeSummaries"][typeIndex]["subTotalBytype"]),
        },
      ),
    );
    grandCount += data["typeSummaries"][typeIndex]["countBytype"];
  }

  returnList.add(
    SectionReplacementDataSection(
      name: "GrandTotal",
      replacementData: {
        "_COUNT_": grandCount.toString(),
        "_AMOUNT_": returnFormattedCurrency(data["grandTotal"]),
      },
    ),
  );

  return returnList;
}

Future<List<SectionReplacementDataSection>> sectionsCreatorCommissionBasis(
  Map<String, dynamic> data,
  String startDate,
  String endDate,
) async {
  List<SectionReplacementDataSection> returnList = [];

  returnList.add(
    SectionReplacementDataSection(
      name: "Report Header Section",
      replacementData: {
        "_PERIOD_": DateTime.now().toString().substring(0, 19),
        "_DATE_": "$startDate to $endDate",
      },
    ),
  );

  returnList.add(
    SectionReplacementDataSection(
      name: "Spacer",
      replacementData: {},
    ),
  );

  returnList.add(
    SectionReplacementDataSection(
      name: "Header Section",
      replacementData: {},
    ),
  );

  bool isPrintingRepInfo = true;
  String fullRepInfo = "";
  String repId = "";
  String repName = "";

  for (int outerIndex = 0; outerIndex < data["commissionRepSummaries"].length; outerIndex++) {
    isPrintingRepInfo = true;
    String subTotalRepInfo = "";
    for (int innerIndex = 0;
        innerIndex < data["commissionRepSummaries"][outerIndex]["commPeriodSummaries"].length;
        innerIndex++) {
      if (isPrintingRepInfo) {
        repId = data["commissionRepSummaries"][outerIndex]["repID"];
        repName = data["commissionRepSummaries"][outerIndex]["repName"];
        fullRepInfo = "$repName ($repId)";
        subTotalRepInfo = fullRepInfo;
      } else {
        fullRepInfo = "";
      }
      isPrintingRepInfo = false;

      returnList.add(
        SectionReplacementDataSection(
          name: "Rep Data Section",
          replacementData: {
            "_REP_INFO_": fullRepInfo,
            "_PERIOD_": data["commissionRepSummaries"][outerIndex]["commPeriodSummaries"]
                [innerIndex]["commPeriod"],
            "_AMOUNT_ADJ_": returnFormattedCurrency(
              data["commissionRepSummaries"][outerIndex]["commPeriodSummaries"][innerIndex]
                  ["amount"]["adjustments"],
            ),
            "_BASIS_ADJ_": returnFormattedCurrency(
              data["commissionRepSummaries"][outerIndex]["commPeriodSummaries"][innerIndex]["basis"]
                      ["adjustments"] ??
                  0,
            ),
            "_AMOUNT_TRD_": returnFormattedCurrency(
              data["commissionRepSummaries"][outerIndex]["commPeriodSummaries"][innerIndex]
                  ["amount"]["commissions"],
            ),
            "_BASIS_TRD_": returnFormattedCurrency(
              data["commissionRepSummaries"][outerIndex]["commPeriodSummaries"][innerIndex]["basis"]
                      ["commissions"] ??
                  0,
            ),
            "_AMOUNT_OVR_": returnFormattedCurrency(
              data["commissionRepSummaries"][outerIndex]["commPeriodSummaries"][innerIndex]
                  ["amount"]["overrides"],
            ),
            "_BASIS_OVR_": returnFormattedCurrency(
              data["commissionRepSummaries"][outerIndex]["commPeriodSummaries"][innerIndex]["basis"]
                  ["overrides"],
            ),
            "_A_TOTAL_": returnFormattedCurrency(
              data["commissionRepSummaries"][outerIndex]["commPeriodSummaries"][innerIndex]
                      ["amount"]["total"] ??
                  0,
            ),
            "_B_TOTAL_": returnFormattedCurrency(
              data["commissionRepSummaries"][outerIndex]["commPeriodSummaries"][innerIndex]["basis"]
                      ["total"] ??
                  0,
            ),
          },
        ),
      );
    }

    returnList.add(
      SectionReplacementDataSection(
        name: "Rep Sum Amount",
        replacementData: {
          "_REP_INFO_": subTotalRepInfo,
          "_SUM_ADJ_": returnFormattedCurrency(
            data["commissionRepSummaries"][outerIndex]["subtotalAmount"]["adjustments"] ?? 0,
          ),
          "_SUM_OVR_": returnFormattedCurrency(
            data["commissionRepSummaries"][outerIndex]["subtotalAmount"]["overrides"] ?? 0,
          ),
          "_SUM_TRD_": returnFormattedCurrency(
            data["commissionRepSummaries"][outerIndex]["subtotalAmount"]["commissions"] ?? 0,
          ),
          "_SUM_GD_": returnFormattedCurrency(
            data["commissionRepSummaries"][outerIndex]["subtotalAmount"]["total"] ?? 0,
          ),
        },
      ),
    );

    returnList.add(
      SectionReplacementDataSection(
        name: "Rep Sum Basis",
        replacementData: {
          "_REP_INFO_": subTotalRepInfo,
          "_SUM_ADJ_": returnFormattedCurrency(
            data["commissionRepSummaries"][outerIndex]["subtotalBasis"]["adjustments"],
          ),
          "_SUM_OVR_": returnFormattedCurrency(
            data["commissionRepSummaries"][outerIndex]["subtotalBasis"]["overrides"],
          ),
          "_SUM_TRD_": returnFormattedCurrency(
            data["commissionRepSummaries"][outerIndex]["subtotalBasis"]["commissions"],
          ),
          "_SUM_GD_": returnFormattedCurrency(
            data["commissionRepSummaries"][outerIndex]["subtotalBasis"]["total"],
          ),
        },
      ),
    );
  }
  returnList.add(
    SectionReplacementDataSection(
      name: "Amount Grand Total",
      replacementData: {
        "_SUM_ADJ_": returnFormattedCurrency(
          data["grandTotalAmount"]["adjustments"],
        ),
        "_SUM_OVR_": returnFormattedCurrency(
          data["grandTotalAmount"]["overrides"],
        ),
        "_SUM_TRD_": returnFormattedCurrency(
          data["grandTotalAmount"]["commissions"],
        ),
        "_SUM_GD_": returnFormattedCurrency(
          data["grandTotalAmount"]["total"],
        ),
      },
    ),
  );

  returnList.add(
    SectionReplacementDataSection(
      name: "Basis Grand Total",
      replacementData: {
        "_SUM_ADJ_": returnFormattedCurrency(
          data["grandTotalBasis"]["adjustments"],
        ),
        "_SUM_OVR_": returnFormattedCurrency(
          data["grandTotalBasis"]["overrides"],
        ),
        "_SUM_TRD_": returnFormattedCurrency(
          data["grandTotalBasis"]["commissions"],
        ),
        "_SUM_GD_": returnFormattedCurrency(
          data["grandTotalBasis"]["total"],
        ),
      },
    ),
  );

  return returnList;
}

//Weekly report to break down rep commissions and company revenue by vendors and program name
Future<List<SectionReplacementDataSection>> sectionsCreatorForPayrollWeekly(
  Map<String, dynamic> data,
  String startDate,
  String endDate,
  String repId,
) async {
  List<SectionReplacementDataSection> returnList = [];

  returnList.add(
    SectionReplacementDataSection(
      name: "ReportHeader",
      replacementData: {
        "_CURRENT_DATE_": DateTime.now().toString().substring(0, 19),
        "_DATE_INFO_": "$startDate to $endDate",
        "_REP_ID_": repId == "" ? "" : "for rep $repId",
      },
    ),
  );

  returnList.add(
    SectionReplacementDataSection(
      name: "HeaderColumns",
      replacementData: {},
    ),
  );

  List<Map<String, String>> valueMappingsNames = [];
  List<Map<String, String>> valueMappingsObjects = [];
  for (var commPeriod in data["commPeriodSummaries"]) {
    valueMappingsNames.add({
      "name": "CommPeriodHeader",
    });
    valueMappingsObjects.add({"_COMM_PERIOD_": commPeriod["commPeriod"]});

    for (var repSummary in commPeriod["repSummaries"]) {
      valueMappingsNames.add({"name": "RepGroupHeader"});
      valueMappingsObjects
          .add({"_REP_ID_": repSummary["repNumber"], "_REP_NAME_": repSummary["repName"]});
      for (var vendorSummary in repSummary["vendorSummaries"]) {
        valueMappingsNames.add({"name": "PlacedThroughGroupHeader"});
        valueMappingsObjects.add({
          "_VENDOR_ID_": vendorSummary["placedThrough"],
          "_VENDOR_NAME_": vendorSummary["vendorName"],
        });

        for (var programSummary in vendorSummary["productSummaries"]) {
          valueMappingsNames.add({"name": "ProgramEntry"});
          valueMappingsObjects.add({
            "_PROGRAM_CODE_": programSummary["symbol"],
            "_PROGRAM_NAME_": programSummary["productName"],
            "_COUNT_": programSummary["productCount"].toString(),
            "_PRINCIPAL_": returnFormattedCurrency(
              programSummary["principal"],
            ),
            "_GROSS_REV_": returnFormattedCurrency(
              programSummary["grossRevenue"],
            ),
            "_REP_COM_": returnFormattedCurrency(
              programSummary["repGrossCommission"],
            ),
            "_NET_REV_": returnFormattedCurrency(programSummary["netRevenue"]),
          });
        }

        valueMappingsNames.add({"name": "ProgramTotalHeader"});
        valueMappingsObjects.add({
          "_COUNT_": vendorSummary["total"]["productCount"].toString(),
          "_PRINCIPAL_": returnFormattedCurrency(
            vendorSummary["total"]["principal"],
          ),
          "_GROSS_REV_": returnFormattedCurrency(
            vendorSummary["total"]["grossRevenue"],
          ),
          "_REP_COM_": returnFormattedCurrency(
            vendorSummary["total"]["repGrossCommission"],
          ),
          "_NET_REV_": returnFormattedCurrency(
            vendorSummary["total"]["netRevenue"],
          ),
        });
      }

      valueMappingsNames.add({"name": "RepTotalHeader"});
      valueMappingsObjects.add({
        "_COUNT_": repSummary["total"]["productCount"].toString(),
        "_PRINCIPAL_": returnFormattedCurrency(
          repSummary["total"]["principal"],
        ),
        "_GROSS_REV_": returnFormattedCurrency(
          repSummary["total"]["grossRevenue"],
        ),
        "_REP_COM_": returnFormattedCurrency(
          repSummary["total"]["repGrossCommission"],
        ),
        "_NET_REV_": returnFormattedCurrency(
          repSummary["total"]["netRevenue"],
        ),
      });
    }
    valueMappingsNames.add({"name": "CommPeriodTotalHeader"});
    valueMappingsObjects.add({
      "_COUNT_": commPeriod["total"]["productCount"].toString(),
      "_PRINCIPAL_": returnFormattedCurrency(
        commPeriod["total"]["principal"],
      ),
      "_GROSS_REV_": returnFormattedCurrency(
        commPeriod["total"]["grossRevenue"],
      ),
      "_REP_COM_": returnFormattedCurrency(
        commPeriod["total"]["repGrossCommission"],
      ),
      "_NET_REV_": returnFormattedCurrency(
        commPeriod["total"]["netRevenue"],
      ),
    });
  }

  for (int i = 0; i < valueMappingsNames.length; i++) {
    returnList.add(
      SectionReplacementDataSection(
        name: valueMappingsNames[i]["name"]!,
        replacementData: valueMappingsObjects[i],
      ),
    );
  }

  returnList.add(
    SectionReplacementDataSection(
      name: "GrandTotal",
      replacementData: {
        "_COUNT_G_": "4",
        "_COUNT_": data["grandTotal"]["productCount"].toString(),
        "_PRINCIPAL_": returnFormattedCurrency(
          data["grandTotal"]["principal"],
        ),
        "_GROSS_REV_": returnFormattedCurrency(
          data["grandTotal"]["grossRevenue"],
        ),
        "_REP_COM_": returnFormattedCurrency(
          data["grandTotal"]["repGrossCommission"],
        ),
        "_NET_REV_": returnFormattedCurrency(
          data["grandTotal"]["netRevenue"],
        ),
      },
    ),
  );

  return returnList;
}

Future<List<SectionReplacementDataSection>> sectionsCreatorWeeklyReceipts(
  Map<String, dynamic> data,
  String startDate,
  String endDate,
  String repId,
) async {
  List<SectionReplacementDataSection> returnList = [];

  returnList.add(
    SectionReplacementDataSection(
      name: "ReportHeader",
      replacementData: {
        "_CURRENT_DATE_": DateTime.now().toString().substring(0, 19),
        "_DATE_INFO_": "entry date $startDate to $endDate",
        "_REP_ID_": repId == "" ? "" : "for rep $repId, ",
      },
    ),
  );

  returnList.add(
    SectionReplacementDataSection(
      name: "HeaderColumns",
      replacementData: {},
    ),
  );

  var items = data["vendorSummaries"];
  List<Map<String, String>> valueMappings = [];
  for (var item in items) {
    valueMappings.add({
      "_PROGRAM_CODE_": item["vendorCode"],
      "_PROGRAM_NAME_": item["vendorName"],
      "_COUNT_": item["count"].toString(),
      "_PRINCIPAL_": returnFormattedCurrency(item["principal"]),
      "_GROSS_REV_": returnFormattedCurrency(item["grossRevenue"]),
      "_REP_COMM_": returnFormattedCurrency(item["repGrossCommission"]),
      "_NET_REV_": returnFormattedCurrency(item["netRevenue"]),
    });
  }

  for (int i = 0; i < valueMappings.length; i++) {
    returnList
        .add(SectionReplacementDataSection(name: "TradeEntry", replacementData: valueMappings[i]));
  }

  returnList.add(
    SectionReplacementDataSection(
      name: "GrandTotal",
      replacementData: {
        "_COUNT_G_": valueMappings.length.toString(),
        "_COUNT_": data["grandTotal"]["count"].toString(),
        "_PRINCIPAL_": returnFormattedCurrency(data["grandTotal"]["principal"]),
        "_GROSS_REV_": returnFormattedCurrency(data["grandTotal"]["grossRevenue"]),
        "_REP_COMM_": returnFormattedCurrency(data["grandTotal"]["repGrossCommission"]),
        "_NET_REV_": returnFormattedCurrency(data["grandTotal"]["netRevenue"]),
      },
    ),
  );

  return returnList;
}

Future<List<SectionReplacementDataSection>> sectionsCreatorTradeReportWeekly(
  Map<String, dynamic> data,
  String startDate,
  String endDate,
  String repId,
) async {
  List<SectionReplacementDataSection> returnList = [];

  returnList.add(
    SectionReplacementDataSection(
      name: "ReportHeader",
      replacementData: {
        "_CURRENT_DATE_": DateTime.now().toString().substring(0, 19),
        "_DATE_INFO_": "entry date $startDate to $endDate",
        "_REP_ID_": repId == "" ? "" : "for rep $repId, ",
      },
    ),
  );

  returnList.add(
    SectionReplacementDataSection(
      name: "HeaderColumns",
      replacementData: {},
    ),
  );

  List<Map<String, String>> valueMappingsNames = [];
  List<Map<String, String>> valueMappingsObjects = [];
  for (var bdPaidDate in data["BDPaidDateSummaries"]) {
    valueMappingsNames.add({
      "name": "CommPeriodHeader",
    });
    valueMappingsObjects.add({"_COMM_PERIOD_": bdPaidDate["BDPaidDate"]});
    for (var vendorSummary in bdPaidDate["vendorSummaries"]) {
      valueMappingsNames.add({"name": "TradeEntry"});
      valueMappingsObjects.add({
        "_PROGRAM_CODE_": vendorSummary["vendorCode"],
        "_PROGRAM_NAME_": vendorSummary["vendorName"],
        "_COUNT_": vendorSummary["count"].toString(),
        "_PRINCIPAL_": returnFormattedCurrency(
          vendorSummary["principal"],
        ),
        "_GROSS_REV_": returnFormattedCurrency(
          vendorSummary["grossRevenue"],
        ),
        "_REP_COMM_": returnFormattedCurrency(
          vendorSummary["repGrossCommission"],
        ),
        "_NET_REV_": returnFormattedCurrency(vendorSummary["netRevenue"]),
      });
    }

    valueMappingsNames.add({"name": "CommPeriodSubtotal"});
    valueMappingsObjects.add({
      "_COUNT_P_": bdPaidDate["total"]["count"].toString(),
      "_COUNT_": bdPaidDate["total"]["count"].toString(),
      "_PRINCIPAL_": returnFormattedCurrency(
        bdPaidDate["total"]["principal"],
      ),
      "_GROSS_REV_": returnFormattedCurrency(
        bdPaidDate["total"]["grossRevenue"],
      ),
      "_REP_COMM_": returnFormattedCurrency(
        bdPaidDate["total"]["repGrossCommission"],
      ),
      "_NET_REV_": returnFormattedCurrency(bdPaidDate["total"]["netRevenue"]),
    });
  }

  for (int i = 0; i < valueMappingsNames.length; i++) {
    returnList.add(
      SectionReplacementDataSection(
        name: valueMappingsNames[i]["name"]!,
        replacementData: valueMappingsObjects[i],
      ),
    );
  }

  returnList.add(
    SectionReplacementDataSection(
      name: "GrandTotal",
      replacementData: {
        "_COUNT_G_": data["grandTotal"]["count"].toString(),
        "_COUNT_": data["grandTotal"]["count"].toString(),
        "_PRINCIPAL_": returnFormattedCurrency(
          data["grandTotal"]["principal"],
        ),
        "_GROSS_REV_": returnFormattedCurrency(
          data["grandTotal"]["grossRevenue"],
        ),
        "_REP_COMM_": returnFormattedCurrency(
          data["grandTotal"]["repGrossCommission"],
        ),
        "_NET_REV_": returnFormattedCurrency(data["grandTotal"]["netRevenue"]),
      },
    ),
  );

  return returnList;
}

Future<List<SectionReplacementDataSection>> sectionsCreatorPayableBreakdown(
  Map<String, dynamic> data,
  String startDate,
  String endDate,
) async {
  List<SectionReplacementDataSection> returnList = [];
  returnList.add(
    SectionReplacementDataSection(
      name: "ReportHeader",
      replacementData: {
        "_COMM_PERIOD_": DateTime.now().toString().substring(0, 19),
        "_DATE_": "$startDate to $endDate",
      },
    ),
  );

  returnList.add(
    SectionReplacementDataSection(
      name: "RepHeader",
      replacementData: {},
    ),
  );

  for (int summaryIndex = 0; summaryIndex < data["summaries"].length; summaryIndex++) {
    returnList.add(
      SectionReplacementDataSection(
        name: "RepBreakdown",
        replacementData: {
          "_REP_INFO_":
              "${data["summaries"][summaryIndex]["repName"]} (${data["summaries"][summaryIndex]["repId"]})",
          "_GROSS_REV_": returnFormattedCurrency(
            data["summaries"][summaryIndex]["gross"] ?? 0,
          ),
          "_OVERRIDES_": returnFormattedCurrency(
            data["summaries"][summaryIndex]["override"] ?? 0,
          ),
          "_GROSS_COMM_": returnFormattedCurrency(
            data["summaries"][summaryIndex]["net"] ?? 0,
          ),
          "_ADJUSTMENTS_": returnFormattedCurrency(
            data["summaries"][summaryIndex]["adjustment"] ?? 0,
          ),
          "_PRIOR_BALANCE_": returnFormattedCurrency(
            data["summaries"][summaryIndex]["prevBalance"] ?? 0,
          ),
          "_REP_PAYABLE_": returnFormattedCurrency(
            data["summaries"][summaryIndex]["payable"] ?? 0,
          ),
          "_ENDING_BALANCE_": returnFormattedCurrency(
            data["summaries"][summaryIndex]["balance"] ?? 0,
          ),
        },
      ),
    );
  }

  returnList.add(
    SectionReplacementDataSection(
      name: "GrandTotal",
      replacementData: {
        "_GROSS_REV_": returnFormattedCurrency(data["grandTotal"]["gross"] ?? 0),
        "_OVERRIDES_": returnFormattedCurrency(data["grandTotal"]["override"] ?? 0),
        "_GROSS_COMM_": returnFormattedCurrency(data["grandTotal"]["net"] ?? 0),
        "_ADJUSTMENTS_": returnFormattedCurrency(data["grandTotal"]["adjustment"] ?? 0),
        "_PRIOR_BALANCE_": returnFormattedCurrency(data["grandTotal"]["prevBalance"] ?? 0),
        "_REP_PAYABLE_": returnFormattedCurrency(data["grandTotal"]["payable"] ?? 0),
        "_ENDING_BALANCE_": returnFormattedCurrency(data["grandTotal"]["balance"] ?? 0),
      },
    ),
  );

  return returnList;
}

Future<List<SectionReplacementDataSection>> sectionsCreatorCommissionPayableSummary(
  Map<String, dynamic> data,
  String startDate,
  String endDate,
  String? repId,
) async {
  List<SectionReplacementDataSection> returnList = [];
  returnList.add(
    SectionReplacementDataSection(
      name: "ReportHeader",
      replacementData: {
        "_CURRENT_DATE_": DateTime.now().toString().substring(0, 19),
        "_DATE_INFO_": "$startDate to $endDate",
        "_REP_ID_": repId == "" ? "" : "for rep $repId",
      },
    ),
  );

  List<Map<String, String>> valueMappingsNames = [];
  List<Map<String, String>> valueMappingsObjects = [];

  returnList.add(
    SectionReplacementDataSection(
      name: "NonETFHeader",
      replacementData: {},
    ),
  );

  returnList.add(
    SectionReplacementDataSection(
      name: "RepHeader",
      replacementData: {},
    ),
  );

  for (var repSummary in data["nonETFSummary"]["repSummaries"]) {
    valueMappingsNames.add({"name": "SummaryLine"});
    valueMappingsObjects.add({
      "_REP_ID_": repSummary["repId"],
      "_REP_NAME_": repSummary["repName"],
      "_GROSS_": returnFormattedCurrency(repSummary["gross"] ?? 0),
      "_PREV_BAL_": returnFormattedCurrency(repSummary["prevBalance"] ?? 0),
      "_BALANCE_": returnFormattedCurrency(repSummary["balance"] ?? 0),
      "_PAYABLE_": returnFormattedCurrency(repSummary["payable"] ?? 0),
      "_1099_YTD_": returnFormattedCurrency(repSummary["YTD1099"] ?? 0),
    });
  }

  valueMappingsNames.add({"name": "Subtotal"});
  valueMappingsObjects.add({
    "_GROSS_": returnFormattedCurrency(data["nonETFSummary"]["total"]["gross"] ?? 0),
    "_PREV_BAL_": returnFormattedCurrency(data["nonETFSummary"]["total"]["prevBalance"] ?? 0),
    "_BALANCE_": returnFormattedCurrency(data["nonETFSummary"]["total"]["balance"] ?? 0),
    "_PAYABLE_": returnFormattedCurrency(data["nonETFSummary"]["total"]["payable"] ?? 0),
    "_1099_YTD_": returnFormattedCurrency(data["nonETFSummary"]["total"]["YTD1099"] ?? 0),
  });

  valueMappingsNames.add({"name": "ETFHeader"});
  valueMappingsObjects.add({});

  valueMappingsNames.add({"name": "RepHeader"});
  valueMappingsObjects.add({});

  for (var repSummary in data["ETFSummary"]["repSummaries"]) {
    valueMappingsNames.add({"name": "SummaryLine"});
    valueMappingsObjects.add({
      "_REP_ID_": repSummary["repId"],
      "_REP_NAME_": repSummary["repName"],
      "_GROSS_": returnFormattedCurrency(repSummary["gross"] ?? 0),
      "_PREV_BAL_": returnFormattedCurrency(repSummary["prevBalance"] ?? 0),
      "_BALANCE_": returnFormattedCurrency(repSummary["balance"] ?? 0),
      "_PAYABLE_": returnFormattedCurrency(repSummary["payable"] ?? 0),
      "_1099_YTD_": returnFormattedCurrency(repSummary["YTD1099"] ?? 0),
    });
  }

  valueMappingsNames.add({"name": "Subtotal"});
  valueMappingsObjects.add({
    "_GROSS_": returnFormattedCurrency(data["ETFSummary"]["total"]["gross"] ?? 0),
    "_PREV_BAL_": returnFormattedCurrency(data["ETFSummary"]["total"]["prevBalance"] ?? 0),
    "_BALANCE_": returnFormattedCurrency(data["ETFSummary"]["total"]["balance"] ?? 0),
    "_PAYABLE_": returnFormattedCurrency(data["ETFSummary"]["total"]["payable"] ?? 0),
    "_1099_YTD_": returnFormattedCurrency(data["ETFSummary"]["total"]["YTD1099"] ?? 0),
  });

  for (int i = 0; i < valueMappingsObjects.length; i++) {
    returnList.add(
      SectionReplacementDataSection(
        name: valueMappingsNames[i]["name"]!,
        replacementData: valueMappingsObjects[i],
      ),
    );
  }

  returnList.add(
    SectionReplacementDataSection(
      name: "GrandTotal",
      replacementData: {
        "_GROSS_": returnFormattedCurrency(data["grandTotal"]["gross"] ?? 0),
        "_PREV_BAL_": returnFormattedCurrency(data["grandTotal"]["prevBalance"] ?? 0),
        "_BALANCE_": returnFormattedCurrency(data["grandTotal"]["balance"] ?? 0),
        "_PAYABLE_": returnFormattedCurrency(data["grandTotal"]["payable"] ?? 0),
        "_1099_YTD_": returnFormattedCurrency(data["grandTotal"]["YTD1099"] ?? 0),
      },
    ),
  );

  return returnList;
}

String maskAccountNumber(String accountNumber) {
  int maskCharCount = 0;
  String maskString = "";
  if (accountNumber.length <= 4) {
    maskCharCount = accountNumber.length - 2;
  } else {
    maskCharCount = accountNumber.length - 4;
  }

  for (int index = 0; index < maskCharCount; index++) {
    maskString = "$maskString*";
  }

  return "$maskString${accountNumber.substring(maskCharCount)}";
}
