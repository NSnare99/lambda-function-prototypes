import { roundToTwoPlaces, sortByProperty } from "./index";


export function TradeReportWeekly(commissionsInput: any, fileSummary: any): any {
    let vendorCode: string;
    let reportOutput: tradeReportWeeklyReport = new tradeReportWeeklyReport([], new commissionSummary("Grand Totals", "", 0, 0, 0, 0, 0,), []);
    if (Object.keys(fileSummary).length != 0) {
        reportOutput.splitsList = fileSummary["splitsList"];
        reportOutput.grandTotal.count += fileSummary["grandTotal"]["count"];
        reportOutput.grandTotal.principal += fileSummary["grandTotal"]["principal"];
        reportOutput.grandTotal.grossRevenue += fileSummary["grandTotal"]["grossRevenue"];
        reportOutput.grandTotal.repGrossCommission += fileSummary["grandTotal"]["repGrossCommission"];
        reportOutput.grandTotal.netRevenue += fileSummary["grandTotal"]["netRevenue"];
        let outerList: BDPaidDateSummary[] = [];
        for (let outerIndex = 0; outerIndex < fileSummary["BDPaidDateSummaries"].length; outerIndex++) {

            let innerList: commissionSummary[] = [];
            for (let innerIndex = 0; innerIndex < fileSummary["BDPaidDateSummaries"][outerIndex]["vendorSummaries"].length; innerIndex++) {
                innerList.push(new commissionSummary(fileSummary["BDPaidDateSummaries"][outerIndex]["vendorSummaries"][innerIndex]["vendorCode"], fileSummary["BDPaidDateSummaries"][outerIndex]["vendorSummaries"][innerIndex]["vendorName"], fileSummary["BDPaidDateSummaries"][outerIndex]["vendorSummaries"][innerIndex]["count"], fileSummary["BDPaidDateSummaries"][outerIndex]["vendorSummaries"][innerIndex]["principal"], fileSummary["BDPaidDateSummaries"][outerIndex]["vendorSummaries"][innerIndex]["grossRevenue"], fileSummary["BDPaidDateSummaries"][outerIndex]["vendorSummaries"][innerIndex]["repGrossCommission"], fileSummary["BDPaidDateSummaries"][outerIndex]["vendorSummaries"][innerIndex]["netRevenue"]))
            }

            outerList.push(new BDPaidDateSummary(new commissionSummary(fileSummary["BDPaidDateSummaries"][outerIndex]["total"]["vendorCode"], fileSummary["BDPaidDateSummaries"][outerIndex]["total"]["vendorName"], fileSummary["BDPaidDateSummaries"][outerIndex]["total"]["count"], fileSummary["BDPaidDateSummaries"][outerIndex]["total"]["principal"], fileSummary["BDPaidDateSummaries"][outerIndex]["total"]["grossRevenue"], fileSummary["BDPaidDateSummaries"][outerIndex]["total"]["repGrossCommission"], fileSummary["BDPaidDateSummaries"][outerIndex]["total"]["netRevenue"],), fileSummary["BDPaidDateSummaries"][outerIndex]["BDPaidDate"], innerList));


        }
        reportOutput.BDPaidDateSummaries = outerList;
    }


    for (let inputIndex = 0; inputIndex < commissionsInput.length; inputIndex++) {







        let BDPaidDateLocationIndex: number = -1;
        let vendorLocationIndex: number = -1;


        let currCommission = commissionsInput[inputIndex];
        currCommission["principal"] = roundToTwoPlaces(currCommission["principal"]);
        currCommission["basis"] = roundToTwoPlaces(currCommission["basis"]);
        currCommission["commissionNet"] = roundToTwoPlaces(currCommission["commissionNet"]);
        let count: number = 1;

        if (reportOutput.splitsList.includes(currCommission["repOnTradeID"])) {
            currCommission["principal"] = 0;
            count = 0;


        }
        if (currCommission["commissionType"] == "Overrides") {
            currCommission["basis"] = 0;
            currCommission["principal"] = 0;
            count = 0;
        }

        reportOutput.grandTotal.count += count;
        reportOutput.grandTotal.principal += currCommission["principal"];
        reportOutput.grandTotal.grossRevenue += currCommission["basis"];
        reportOutput.grandTotal.repGrossCommission += currCommission["commissionNet"];
        reportOutput.grandTotal.netRevenue += (currCommission["basis"] - currCommission["commissionNet"]);
        vendorCode = currCommission["vendor"];

        /*  for (let vendorIndex: number = 0; vendorIndex < vendorsInput.length; vendorIndex++) {
             if (vendorsInput[vendorIndex]["name"] == currCommission["vendor"]) {
                 vendorCode = vendorsInput[vendorIndex]["id"];
             }
         }
  */



        for (let BDPaidDateSeekingIndex: number = 0; BDPaidDateSeekingIndex < reportOutput.BDPaidDateSummaries.length; BDPaidDateSeekingIndex++) {
            if (reportOutput.BDPaidDateSummaries[BDPaidDateSeekingIndex].BDPaidDate == currCommission["bDPaidDate"]) {
                BDPaidDateLocationIndex = BDPaidDateSeekingIndex;
            }
        }

        if (BDPaidDateLocationIndex > -1) {
            reportOutput.BDPaidDateSummaries[BDPaidDateLocationIndex].total.count += count;
            reportOutput.BDPaidDateSummaries[BDPaidDateLocationIndex].total.principal += currCommission["principal"];
            reportOutput.BDPaidDateSummaries[BDPaidDateLocationIndex].total.grossRevenue += currCommission["basis"];
            reportOutput.BDPaidDateSummaries[BDPaidDateLocationIndex].total.repGrossCommission += currCommission["commissionNet"];
            reportOutput.BDPaidDateSummaries[BDPaidDateLocationIndex].total.netRevenue += (currCommission["basis"] - currCommission["commissionNet"]);

            for (let vendorSeekingIndex: number = 0; vendorSeekingIndex < reportOutput.BDPaidDateSummaries[BDPaidDateLocationIndex].vendorSummaries.length; vendorSeekingIndex++) {
                if (reportOutput.BDPaidDateSummaries[BDPaidDateLocationIndex].vendorSummaries[vendorSeekingIndex].vendorCode == vendorCode) {
                    vendorLocationIndex = vendorSeekingIndex;
                }
            }

            if (vendorLocationIndex > -1) {

                reportOutput.BDPaidDateSummaries[BDPaidDateLocationIndex].vendorSummaries[vendorLocationIndex].count += count;
                reportOutput.BDPaidDateSummaries[BDPaidDateLocationIndex].vendorSummaries[vendorLocationIndex].principal += currCommission["principal"];
                reportOutput.BDPaidDateSummaries[BDPaidDateLocationIndex].vendorSummaries[vendorLocationIndex].grossRevenue += currCommission["basis"];
                reportOutput.BDPaidDateSummaries[BDPaidDateLocationIndex].vendorSummaries[vendorLocationIndex].repGrossCommission += currCommission["commissionNet"];
                reportOutput.BDPaidDateSummaries[BDPaidDateLocationIndex].vendorSummaries[vendorLocationIndex].netRevenue += (currCommission["basis"] - currCommission["commissionNet"]);
            }

            else {

                reportOutput.BDPaidDateSummaries[BDPaidDateLocationIndex].vendorSummaries.push(new commissionSummary(vendorCode, currCommission["vendor"], 1, currCommission["principal"], currCommission["basis"], currCommission["commissionNet"], currCommission["basis"] - currCommission["commissionNet"]));

            }



        }



        else {

            reportOutput.BDPaidDateSummaries.push(new BDPaidDateSummary(new commissionSummary(vendorCode, currCommission["vendor"], 1, currCommission["principal"], currCommission["basis"], currCommission["commissionNet"], currCommission["basis"] - currCommission["commissionNet"],), currCommission["bDPaidDate"], [new commissionSummary(vendorCode, currCommission["vendor"], 1, currCommission["principal"], currCommission["basis"], currCommission["commissionNet"], currCommission["basis"] - currCommission["commissionNet"])]));
        }

        if (currCommission["commissionType"] != "Overrides" && currCommission["repOnTradeID"] != currCommission["paidRepID"] && !reportOutput.splitsList.includes(currCommission["repOnTradeID"])) {
            reportOutput.splitsList.push(currCommission["repOnTradeID"]);
        }

    };








    const reportOutputCopy = reportOutput;

    for (let bdPaid = 0; bdPaid < reportOutputCopy.BDPaidDateSummaries.length; bdPaid++) {
        const preSortVend = reportOutputCopy.BDPaidDateSummaries[bdPaid].vendorSummaries;
        const postSortVend = sortByProperty(preSortVend, "vendorName");
        reportOutput.BDPaidDateSummaries[bdPaid].vendorSummaries = postSortVend;
    }
    const preSortBDPaid = reportOutputCopy.BDPaidDateSummaries;
    const postSortBDPaid = sortByProperty(preSortBDPaid, "BDPaidDate");

    reportOutput.BDPaidDateSummaries = postSortBDPaid;




    // return jsonResult;
    return JSON.stringify(reportOutput);

}




class commissionSummary {

    vendorCode: string; vendorName: string; count: number; principal: number; grossRevenue: number; repGrossCommission: number; netRevenue: number;




    constructor(vendorCode: string, vendorName: string, count: number, principal: number, grossRevenue: number, repGrossCommission: number, netRevenue: number) {
        this.vendorCode = vendorCode;
        this.vendorName = vendorName;
        this.count = count;
        this.principal = principal;
        this.grossRevenue = grossRevenue;
        this.repGrossCommission = repGrossCommission;
        this.netRevenue = netRevenue;

    }





}



class BDPaidDateSummary {
    total: commissionSummary;
    BDPaidDate: string;
    vendorSummaries: commissionSummary[];
    constructor(total: commissionSummary, BDPaidDate: string, vendorSummaries: commissionSummary[]) {
        this.total = total;
        this.BDPaidDate = BDPaidDate;
        this.vendorSummaries = vendorSummaries;
    }
}


class tradeReportWeeklyReport {
    splitsList: string[];
    grandTotal: commissionSummary;
    BDPaidDateSummaries: BDPaidDateSummary[];
    constructor(splitsList: string[], grandTotal: commissionSummary, BDPaidDateSummaries: BDPaidDateSummary[]) {
        this.splitsList = splitsList;
        this.grandTotal = grandTotal;
        this.BDPaidDateSummaries = BDPaidDateSummaries;




    }
}

