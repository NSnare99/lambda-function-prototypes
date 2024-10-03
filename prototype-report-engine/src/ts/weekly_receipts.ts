import { sortByProperty, roundToTwoPlaces } from ".";

export function WeeklyReceipts(commissionsInput: any, fileSummary: any): any {
    let vendorsGroupingList: string[] = [];
    let reportOutput: weeklyReceiptsReport = new weeklyReceiptsReport([], new commissionSummary("Grand Totals", "", 1, 0, 0, 0, 0,), []);
    if (Object.keys(fileSummary).length != 0) {
        reportOutput.grandTotal.count = fileSummary["grandTotal"]["count"];
        reportOutput.grandTotal.principal = fileSummary["grandTotal"]["principal"];
        reportOutput.grandTotal.grossRevenue = fileSummary["grandTotal"]["grossRevenue"];
        reportOutput.grandTotal.repGrossCommission = fileSummary["grandTotal"]["repGrossCommission"];
        reportOutput.grandTotal.netRevenue = fileSummary["grandTotal"]["netRevenue"];
        reportOutput.splitsList = fileSummary["splitsList"];
        let outerList: commissionSummary[] = [];
        for (let outerIndex = 0; outerIndex < fileSummary["vendorSummaries"].length; outerIndex++) {
            outerList.push(new commissionSummary(fileSummary["vendorSummaries"][outerIndex]["vendorCode"], fileSummary["vendorSummaries"][outerIndex]["vendorName"], fileSummary["vendorSummaries"][outerIndex]["count"], fileSummary["vendorSummaries"][outerIndex]["principal"], fileSummary["vendorSummaries"][outerIndex]["grossRevenue"], fileSummary["vendorSummaries"][outerIndex]["repGrossCommission"], fileSummary["vendorSummaries"][outerIndex]["netRevenue"],));
            vendorsGroupingList.push(fileSummary["vendorSummaries"][outerIndex]["vendorName"]);
        }
        reportOutput.vendorSummaries = outerList;
    }
    for (let inputIndex = 0; inputIndex < commissionsInput.length; inputIndex++) {
        let currCommission = commissionsInput[inputIndex];
        currCommission["principal"] = roundToTwoPlaces(currCommission["principal"]);
        currCommission["basis"] = roundToTwoPlaces(currCommission["basis"]);
        currCommission["commissionNet"] = roundToTwoPlaces(currCommission["commissionNet"]);
        let count: number = 1;
        if (currCommission["externalAccount"] != null && reportOutput.splitsList.includes(currCommission["externalAccount"])) {

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
        if (reportOutput.vendorSummaries.length == 0 || !vendorsGroupingList.includes(currCommission["vendor"])) {
            vendorsGroupingList.push(currCommission["vendor"]);
            let vendorCode: string = "";
            /*  for (let vendorIndex: number = 0; vendorIndex < vendorsInput.length; vendorIndex++) {
                 if (vendorsInput[vendorIndex]["name"] == currCommission["vendor"]) {
                     vendorCode = vendorsInput[vendorIndex]["id"];
                 }
             } */
            const initialCommission = new commissionSummary(vendorCode, currCommission["vendor"], 1, currCommission["principal"], currCommission["basis"], currCommission["commissionNet"], currCommission["basis"] - currCommission["commissionNet"],);
            reportOutput.vendorSummaries.push(initialCommission);
        }

        else {

            for (let vendorsIndex = 0; vendorsIndex < reportOutput.vendorSummaries.length; vendorsIndex++) {
                if (reportOutput.vendorSummaries[vendorsIndex].vendorName == currCommission["vendor"]) {
                    reportOutput.vendorSummaries[vendorsIndex].count += count;
                    reportOutput.vendorSummaries[vendorsIndex].principal += currCommission["principal"];
                    reportOutput.vendorSummaries[vendorsIndex].grossRevenue += currCommission["basis"];
                    reportOutput.vendorSummaries[vendorsIndex].repGrossCommission += currCommission["commissionNet"];
                    reportOutput.vendorSummaries[vendorsIndex].netRevenue += (currCommission["basis"] - currCommission["commissionNet"]);


                }
            }
        }




        if (currCommission["repOnTradeID"].substring(0, 1) == "5" && currCommission["externalAccount"] != null && !reportOutput.splitsList.includes(currCommission["externalAccount"])) {
            reportOutput.splitsList.push(currCommission["externalAccount"]);
        }



    };









    const preSortVend = reportOutput.vendorSummaries;
    reportOutput.vendorSummaries = sortByProperty(preSortVend, "vendorName");




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




class weeklyReceiptsReport {
    splitsList: string[];
    grandTotal: commissionSummary;
    vendorSummaries: commissionSummary[];
    constructor(splitsList: string[], grandTotal: commissionSummary, vendorSummaries: commissionSummary[]) {
        this.splitsList = splitsList;
        this.grandTotal = grandTotal;
        this.vendorSummaries = vendorSummaries;



    }
}
