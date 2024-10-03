
import {
    DynamoDBClient,
    QueryCommand,
    ScanCommand,
}
    // @ts-ignore
    from "@aws-sdk/client-dynamodb";

import { roundToTwoPlaces, sortByProperty } from "./index";


export function ForPayrollWeekly(commissionsInput: any, fileSummary: any): any {




    let reportOutput: ForPayrollWeeklyReport = new ForPayrollWeeklyReport([], new productSummary("Grand Totals", "", 0, 0, 0, 0, 0,), []);

    let vendorCode: string = "";

    if (Object.keys(fileSummary).length != 0) {


        reportOutput.grandTotal.symbol = fileSummary["grandTotal"]["symbol"];
        reportOutput.grandTotal.productName = fileSummary["grandTotal"]["productName"];
        reportOutput.grandTotal.productCount = fileSummary["grandTotal"]["productCount"];
        reportOutput.grandTotal.principal = fileSummary["grandTotal"]["principal"];
        reportOutput.grandTotal.grossRevenue = fileSummary["grandTotal"]["grossRevenue"];
        reportOutput.grandTotal.repGrossCommission = fileSummary["grandTotal"]["repGrossCommission"];
        reportOutput.grandTotal.netRevenue = fileSummary["grandTotal"]["netRevenue"];



        let commPeriodList: commPeriodSummary[] = [];
        for (let commPeriodIndex = 0; commPeriodIndex < fileSummary["commPeriodSummaries"].length; commPeriodIndex++) {

            let repSummaryList: repSummary[] = [];

            let tempCommPeriodSummary: commPeriodSummary = fileSummary["commPeriodSummaries"][commPeriodIndex];

            for (let repSummaryIndex = 0; repSummaryIndex < tempCommPeriodSummary["repSummaries"].length; repSummaryIndex) {
                let vendorSummaryList: vendorSummary[] = [];
                let tempRepSummary: repSummary = tempCommPeriodSummary["repSummaries"][repSummaryIndex];
                for (let vendorSummaryIndex = 0; vendorSummaryIndex < tempRepSummary["vendorSummaries"].length; vendorSummaryIndex++) {
                    let productSummaryList: productSummary[] = [];
                    let tempVendorSummary: vendorSummary = tempRepSummary["vendorSummaries"][vendorSummaryIndex];
                    for (let productSummaryIndex = 0; productSummaryIndex < tempVendorSummary["productSummaries"].length; productSummaryIndex++) {
                        let tempProductSummary = tempVendorSummary["productSummaries"][productSummaryIndex];
                        productSummaryList.push(new productSummary(tempProductSummary["symbol"], tempProductSummary["productName"], tempProductSummary["productCount"], tempProductSummary["principal"], tempProductSummary["grossRevenue"], tempProductSummary["repGrossCommission"], tempProductSummary["netRevenue"],));

                    }
                    let tempProductTotal: productSummary = new productSummary(tempVendorSummary["total"]["symbol"], tempVendorSummary["total"]["productName"], tempVendorSummary["total"]["productCount"], tempVendorSummary["total"]["principal"], tempVendorSummary["total"]["grossRevenue"], tempVendorSummary["total"]["repGrossCommission"], tempVendorSummary["total"]["netRevenue"],);
                    vendorSummaryList.push(new vendorSummary(tempVendorSummary["placedThrough"], tempVendorSummary["vendorName"], productSummaryList, tempProductTotal));
                }
                let tempRepTotal: productSummary = new productSummary(tempRepSummary["total"]["symbol"], tempRepSummary["total"]["productName"], tempRepSummary["total"]["productCount"], tempRepSummary["total"]["principal"], tempRepSummary["total"]["grossRevenue"], tempRepSummary["total"]["repGrossCommission"], tempRepSummary["total"]["netRevenue"],);
                repSummaryList.push(new repSummary(tempRepSummary["repNumber"], tempRepSummary["repName"], vendorSummaryList, tempRepTotal));

            }
            let tempCommPeriodTotal: productSummary = new productSummary(tempCommPeriodSummary["total"]["symbol"], tempCommPeriodSummary["total"]["productName"], tempCommPeriodSummary["total"]["productCount"], tempCommPeriodSummary["total"]["principal"], tempCommPeriodSummary["total"]["grossRevenue"], tempCommPeriodSummary["total"]["repGrossCommission"], tempCommPeriodSummary["total"]["netRevenue"]);
            commPeriodList.push(new commPeriodSummary(tempCommPeriodSummary["commPeriodNumber"], tempCommPeriodSummary["commPeriod"], repSummaryList, tempCommPeriodTotal));
        };
        reportOutput.commPeriodSummaries = commPeriodList;
    };



    for (let inputIndex = 0; inputIndex < commissionsInput.length; inputIndex++) {
        reportOutput.grandTotal.productCount++;
        let commPeriodIndex: number = -1;
        let repIndex: number = -1;
        let vendorIndex: number = -1;
        let productIndex: number = -1;

        let currCommission = commissionsInput[inputIndex];

        currCommission["principal"] = roundToTwoPlaces(currCommission["principal"]);
        currCommission["basis"] = roundToTwoPlaces(currCommission["basis"]);
        currCommission["commissionNet"] = roundToTwoPlaces(currCommission["commissionNet"]);


        if (reportOutput.splitsList.includes(currCommission["repOnTradeID"])) {
            currCommission["principal"] = 0;



        }
        if (currCommission["commissionType"] == "Overrides") {
            currCommission["basis"] = 0;
            currCommission["principal"] = 0;

        }

        /* for (let vendorListIndex: number = 0; vendorListIndex < vendorsInput.length; vendorListIndex++) {
            if (vendorsInput[vendorListIndex]["name"] == currCommission["vendor"]) {
                vendorCode = vendorsInput[vendorListIndex]["id"];
                console.log("Vendor Cord: ", vendorCode);
                console.log("Vendor Name: ", currCommission["vendor"]);
                break;
            }
        } */


        for (let firstindex: number = 0; firstindex < reportOutput.commPeriodSummaries.length; firstindex++) {
            if (reportOutput.commPeriodSummaries[firstindex].commPeriod == currCommission["commPeriod"]) {
                commPeriodIndex = firstindex;
            }
        }


        if (commPeriodIndex > -1) {

            reportOutput.commPeriodSummaries[commPeriodIndex].total.productCount++;
            reportOutput.commPeriodSummaries[commPeriodIndex].total.principal += currCommission["principal"];
            reportOutput.commPeriodSummaries[commPeriodIndex].total.grossRevenue += currCommission["basis"];
            reportOutput.commPeriodSummaries[commPeriodIndex].total.repGrossCommission += currCommission["commissionNet"];
            reportOutput.commPeriodSummaries[commPeriodIndex].total.netRevenue += (currCommission["basis"] - currCommission["commissionNet"]);



            for (let secondIndex: number = 0; secondIndex < reportOutput.commPeriodSummaries[commPeriodIndex].repSummaries.length; secondIndex++) {
                if (reportOutput.commPeriodSummaries[commPeriodIndex].repSummaries[secondIndex].repNumber == currCommission["paidRepID"]) {
                    repIndex = secondIndex;
                }
            }

            if (repIndex > -1) {
                reportOutput.commPeriodSummaries[commPeriodIndex].repSummaries[repIndex].total.productCount++;
                reportOutput.commPeriodSummaries[commPeriodIndex].repSummaries[repIndex].total.principal += currCommission["principal"];
                reportOutput.commPeriodSummaries[commPeriodIndex].repSummaries[repIndex].total.grossRevenue += currCommission["basis"];
                reportOutput.commPeriodSummaries[commPeriodIndex].repSummaries[repIndex].total.repGrossCommission += currCommission["commissionNet"];
                reportOutput.commPeriodSummaries[commPeriodIndex].repSummaries[repIndex].total.netRevenue += (currCommission["basis"] - currCommission["commissionNet"]);
                for (let thirdIndex: number = 0; thirdIndex < reportOutput.commPeriodSummaries[commPeriodIndex].repSummaries[repIndex].vendorSummaries.length; thirdIndex++) {
                    if (reportOutput.commPeriodSummaries[commPeriodIndex].repSummaries[repIndex].vendorSummaries[thirdIndex].vendorName == currCommission["vendor"]) {
                        vendorIndex = thirdIndex;
                    }
                }

                if (vendorIndex > -1) {

                    reportOutput.commPeriodSummaries[commPeriodIndex].repSummaries[repIndex].vendorSummaries[vendorIndex].total.productCount++;
                    reportOutput.commPeriodSummaries[commPeriodIndex].repSummaries[repIndex].vendorSummaries[vendorIndex].total.principal += currCommission["principal"];
                    reportOutput.commPeriodSummaries[commPeriodIndex].repSummaries[repIndex].vendorSummaries[vendorIndex].total.grossRevenue += currCommission["basis"];
                    reportOutput.commPeriodSummaries[commPeriodIndex].repSummaries[repIndex].vendorSummaries[vendorIndex].total.repGrossCommission += currCommission["commissionNet"];
                    reportOutput.commPeriodSummaries[commPeriodIndex].repSummaries[repIndex].vendorSummaries[vendorIndex].total.netRevenue += (currCommission["basis"] - currCommission["commissionNet"]);

                    for (let fourthIndex: number = 0; fourthIndex < reportOutput.commPeriodSummaries[commPeriodIndex].repSummaries[repIndex].vendorSummaries[vendorIndex].productSummaries.length; fourthIndex++) {
                        if (reportOutput.commPeriodSummaries[commPeriodIndex].repSummaries[repIndex].vendorSummaries[vendorIndex].productSummaries[fourthIndex].productName == currCommission["product"]) {
                            productIndex = fourthIndex;
                        }
                    }



                    if (productIndex > -1) {

                        reportOutput.commPeriodSummaries[commPeriodIndex].repSummaries[repIndex].vendorSummaries[vendorIndex].productSummaries[productIndex].productCount++;
                        reportOutput.commPeriodSummaries[commPeriodIndex].repSummaries[repIndex].vendorSummaries[vendorIndex].productSummaries[productIndex].principal += currCommission["principal"];
                        reportOutput.commPeriodSummaries[commPeriodIndex].repSummaries[repIndex].vendorSummaries[vendorIndex].productSummaries[productIndex].grossRevenue += currCommission["basis"];
                        reportOutput.commPeriodSummaries[commPeriodIndex].repSummaries[repIndex].vendorSummaries[vendorIndex].productSummaries[productIndex].repGrossCommission += currCommission["commissionNet"];
                        reportOutput.commPeriodSummaries[commPeriodIndex].repSummaries[repIndex].vendorSummaries[vendorIndex].productSummaries[productIndex].netRevenue += (currCommission["basis"] - currCommission["commissionNet"]);


                        reportOutput.grandTotal.productCount++;
                        reportOutput.grandTotal.principal += currCommission["principal"];
                        reportOutput.grandTotal.grossRevenue += currCommission["basis"];
                        reportOutput.grandTotal.repGrossCommission += currCommission["commissionNet"];
                        reportOutput.grandTotal.netRevenue += (currCommission["basis"] - currCommission["commissionNet"]);

                    }

                    else {
                        const initialProductSummary = new productSummary(currCommission["symbol"], currCommission["product"], 1, currCommission["principal"], currCommission["basis"], currCommission["commissionNet"], currCommission["basis"] - currCommission["commissionNet"]);
                        reportOutput.commPeriodSummaries[commPeriodIndex].repSummaries[repIndex].vendorSummaries[vendorIndex].productSummaries.push(initialProductSummary);



                        reportOutput.grandTotal.productCount++;
                        reportOutput.grandTotal.principal += currCommission["principal"];
                        reportOutput.grandTotal.grossRevenue += currCommission["basis"];
                        reportOutput.grandTotal.repGrossCommission += currCommission["commissionNet"];
                        reportOutput.grandTotal.netRevenue += (currCommission["basis"] - currCommission["commissionNet"]);
                    }

                }

                else {
                    const initialProductSummary = new productSummary(currCommission["symbol"], currCommission["product"], 1, currCommission["principal"], currCommission["basis"], currCommission["commissionNet"], currCommission["basis"] - currCommission["commissionNet"]);


                    const initialVendorSummary = new vendorSummary(vendorCode, currCommission["vendor"], [initialProductSummary], new productSummary("VENDOR TOTAL", currCommission["vendor"], 1, currCommission["principal"], currCommission["basis"], currCommission["commissionNet"], currCommission["basis"] - currCommission["commissionNet"]));

                    reportOutput.commPeriodSummaries[commPeriodIndex].repSummaries[repIndex].vendorSummaries.push(initialVendorSummary);


                    reportOutput.grandTotal.productCount++;
                    reportOutput.grandTotal.principal += currCommission["principal"];
                    reportOutput.grandTotal.grossRevenue += currCommission["basis"];
                    reportOutput.grandTotal.repGrossCommission += currCommission["commissionNet"];
                    reportOutput.grandTotal.netRevenue += (currCommission["basis"] - currCommission["commissionNet"]);
                }

            }

            else {
                const initialProductSummary = new productSummary(currCommission["symbol"], currCommission["product"], 1, currCommission["principal"], currCommission["basis"], currCommission["commissionNet"], currCommission["basis"] - currCommission["commissionNet"]);



                const initialVendorSummary = new vendorSummary(vendorCode, currCommission["vendor"], [initialProductSummary], new productSummary("VENDOR TOTAL", currCommission["vendor"], 1, currCommission["principal"], currCommission["basis"], currCommission["commissionNet"], currCommission["basis"] - currCommission["commissionNet"]));
                const initialRepSummary = new repSummary(currCommission["paidRepID"], currCommission["repName"], [initialVendorSummary], new productSummary("REP TOTAL", currCommission["paidRepID"], 1, currCommission["principal"], currCommission["basis"], currCommission["commissionNet"], currCommission["basis"] - currCommission["commissionNet"]),);

                reportOutput.commPeriodSummaries[commPeriodIndex].repSummaries.push(initialRepSummary);


                reportOutput.grandTotal.productCount++;
                reportOutput.grandTotal.principal += currCommission["principal"];
                reportOutput.grandTotal.grossRevenue += currCommission["basis"];
                reportOutput.grandTotal.repGrossCommission += currCommission["commissionNet"];
                reportOutput.grandTotal.netRevenue += (currCommission["basis"] - currCommission["commissionNet"]);


            }

        }
        else {
            const initialProductSummary = new productSummary(currCommission["symbol"], currCommission["product"], 1, currCommission["principal"], currCommission["basis"], currCommission["commissionNet"], currCommission["basis"] - currCommission["commissionNet"]);


            const initialVendorSummary = new vendorSummary(vendorCode, currCommission["vendor"], [initialProductSummary], new productSummary("VENDOR TOTAL", currCommission["vendor"], 1, currCommission["principal"], currCommission["basis"], currCommission["commissionNet"], currCommission["basis"] - currCommission["commissionNet"]));
            const initialRepSummary = new repSummary(currCommission["paidRepID"], currCommission["repName"], [initialVendorSummary], new productSummary("REP TOTAL", currCommission["paidRepID"], 1, currCommission["principal"], currCommission["basis"], currCommission["commissionNet"], currCommission["basis"] - currCommission["commissionNet"]),);
            const initialCommPeriod = new commPeriodSummary(currCommission["commPeriod"], currCommission["commPeriod"], [initialRepSummary], new productSummary("COMM TOTAL", currCommission["commPeriod"], 1, currCommission["principal"], currCommission["basis"], currCommission["commissionNet"], currCommission["basis"] - currCommission["commissionNet"]));
            reportOutput.commPeriodSummaries.push(initialCommPeriod);
            reportOutput.grandTotal.productCount++;
            reportOutput.grandTotal.principal += currCommission["principal"];
            reportOutput.grandTotal.grossRevenue += currCommission["basis"];
            reportOutput.grandTotal.repGrossCommission += currCommission["commissionNet"];
            reportOutput.grandTotal.netRevenue += (currCommission["basis"] - currCommission["commissionNet"]);


        }


        if (currCommission["commissionType"] != "Overrides" && currCommission["repOnTradeID"] != currCommission["paidRepID"] && !reportOutput.splitsList.includes(currCommission["repOnTradeID"])) {
            reportOutput.splitsList.push(currCommission["repOnTradeID"]);
        }

    };

    // return jsonResult;


    const reportOutputCopy = reportOutput;

    for (let comm = 0; comm < reportOutputCopy.commPeriodSummaries.length; comm++) {
        for (let rep = 0; rep < reportOutputCopy.commPeriodSummaries[comm].repSummaries.length; rep++) {
            for (let vend = 0; vend < reportOutputCopy.commPeriodSummaries[comm].repSummaries[rep].vendorSummaries.length; vend++) {
                const preSortProd = reportOutputCopy.commPeriodSummaries[comm].repSummaries[rep].vendorSummaries[vend].productSummaries;
                const postSortProd = sortByProperty(preSortProd, "productName");
                reportOutput.commPeriodSummaries[comm].repSummaries[rep].vendorSummaries[vend].productSummaries = postSortProd;
            }

            const preSortVend = reportOutputCopy.commPeriodSummaries[comm].repSummaries[rep].vendorSummaries;
            const postSortVend = sortByProperty(preSortVend, "vendorName");
            reportOutput.commPeriodSummaries[comm].repSummaries[rep].vendorSummaries = postSortVend;

        }
        const preSortRep = reportOutputCopy.commPeriodSummaries[comm].repSummaries;
        const postSortRep = sortByProperty(preSortRep, "repName");
        reportOutput.commPeriodSummaries[comm].repSummaries = postSortRep;
    }
    const preSortRep = reportOutputCopy.commPeriodSummaries;
    const postSortRep = sortByProperty(preSortRep, "commPeriod");
    reportOutput.commPeriodSummaries = postSortRep;



    return JSON.stringify(reportOutput);

}






class commPeriodSummary {

    commPeriodNumber: string; commPeriod: string; repSummaries: repSummary[]; total: productSummary


    constructor(commPeriodNumber: string, commPeriod: string, repSummaries: repSummary[], total: productSummary) {

        this.commPeriodNumber = commPeriodNumber;
        this.commPeriod = commPeriod;
        this.repSummaries = repSummaries;
        this.total = total;

    }

}


class repSummary {

    repNumber: string; repName: string; vendorSummaries: vendorSummary[]; total: productSummary


    constructor(repNumber: string, repName: string, vendorSummaries: vendorSummary[], total: productSummary) {

        this.repNumber = repNumber;
        this.repName = repName;
        this.vendorSummaries = vendorSummaries;
        this.total = total;

    }

}

class vendorSummary {

    placedThrough: string; vendorName: string; productSummaries: productSummary[]; total: productSummary


    constructor(placedThrough: string, vendorName: string, productSummaries: productSummary[], total: productSummary) {

        this.placedThrough = placedThrough;
        this.vendorName = vendorName;
        this.productSummaries = productSummaries;
        this.total = total

    }

}

class productSummary {

    symbol: string; productName: string; productCount: number; principal: number; grossRevenue: number; repGrossCommission: number; netRevenue: number;


    constructor(symbol: string, productName: string, productCount: number, principal: number, grossRevenue: number, repGrossCommission: number, netRevenue: number,) {
        this.symbol = symbol;
        this.productName = productName;
        this.productCount = productCount;
        this.principal = principal;
        this.grossRevenue = grossRevenue;
        this.repGrossCommission = repGrossCommission;
        this.netRevenue = netRevenue;
    }

}


class ForPayrollWeeklyReport {
    splitsList: string[];
    grandTotal: productSummary;
    commPeriodSummaries: commPeriodSummary[];
    constructor(splitsList: string[], grandTotal: productSummary, vendorSummaries: commPeriodSummary[]) {
        this.splitsList = splitsList;
        this.grandTotal = grandTotal;
        this.commPeriodSummaries = vendorSummaries;
    }
}