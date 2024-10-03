import { roundToTwoPlaces, sortByProperty, getCurrentDateFormatted } from "./index";


export function CommissionBasis(commissionsInput: any, fileSummary: any, adjustmentData: any): any {
    let repsList: string[] = [];
    let repsNameList: string[] = [];
    let isPushingNewRepSummaryIntoPeriod: boolean = true;
    let currentGross: number = 0;
    let currentNet: number = 0;

    let reportOutput: payableBreakdownReport = new payableBreakdownReport(new amountBreakdown(0, 0, 0, 0), new basisBreakdown(0, 0, 0, 0), [],);

    if (Object.keys(fileSummary).length != 0) {
        console.log("File SUmmary: ", fileSummary);
        reportOutput.grandTotalAmount = fileSummary["grandTotalAmount"];
        reportOutput.grandTotalBasis = fileSummary["grandTotalBasis"];



        let outerList: commissionRepSummary[] = [];
        for (let outerIndex = 0; outerIndex < fileSummary.commissionRepSummaries.length; outerIndex++) {

            let tempList: commPeriodSummary[] = [];
            for (let innerIndex = 0; innerIndex < fileSummary.commissionRepSummaries[outerIndex].commPeriodSummaries.length; innerIndex++) {

                tempList.push(new commPeriodSummary(fileSummary.commissionRepSummaries[outerIndex].commPeriodSummaries[innerIndex].commPeriod, fileSummary.commissionRepSummaries[outerIndex].commPeriodSummaries[innerIndex].amount, fileSummary.commissionRepSummaries[outerIndex].commPeriodSummaries[innerIndex].basis));

            }
            let tempSummary = new commissionRepSummary(fileSummary.commissionRepSummaries[outerIndex].repID, fileSummary.commissionRepSummaries[outerIndex].repName, tempList, fileSummary.commissionRepSummaries[outerIndex].subtotalAmount, fileSummary.commissionRepSummaries[outerIndex].subtotalBasis);
            repsList.push(fileSummary.commissionRepSummaries[outerIndex].repID);
            repsNameList.push(fileSummary.commissionRepSummaries[outerIndex].repName);
            outerList.push(tempSummary);
        }

        reportOutput.commissionRepSummaries = outerList;


    }
    let isOverride: boolean = false;
    let overrideAmount: number = 0;
    let overrideBasis: number = 0;
    let commissionAmount: number = 0;
    let commissionBasis: number = 0;
    reportOutput.grandTotalAmount.adjustments = adjustmentData["grandTotal"];
    reportOutput.grandTotalBasis.adjustments = adjustmentData["grandTotal"];
    for (let inputIndex = 0; inputIndex < commissionsInput.length; inputIndex++) {
        let adjustmentAmount: number = 0;
        const currCommission = commissionsInput[inputIndex];
        isOverride = currCommission["commissionType"] == "Overrides";
        currentGross = currCommission["basis"];
        currentNet = currCommission["commissionNet"];
        console.log("Commiddion input: ", currCommission);
        if (currCommission["commPeriod"] == null) {
            currCommission["commPeriod"] = getCurrentDateFormatted();
        }
        if (isOverride) {
            overrideAmount = roundToTwoPlaces(currentNet);
            overrideBasis = roundToTwoPlaces(currentGross);

        }
        else {
            commissionAmount = roundToTwoPlaces(currentNet);
            commissionBasis = roundToTwoPlaces(currentGross);
        }


        reportOutput.grandTotalBasis.overrides += overrideBasis;
        reportOutput.grandTotalAmount.overrides += overrideAmount;
        reportOutput.grandTotalBasis.commissions += commissionBasis;
        reportOutput.grandTotalAmount.commissions += commissionAmount;

        reportOutput.grandTotalAmount.total += (commissionAmount + overrideAmount);
        reportOutput.grandTotalBasis.total += (commissionBasis + overrideBasis);

        if (reportOutput.commissionRepSummaries.length == 0 || !repsList.includes(currCommission["paidRepID"])) {


            let isLast: boolean = true;
            let insertionPlace: number = 0;
            if (repsNameList.length > 0) {
                for (let orderIndex: number = 0; orderIndex < repsList.length; orderIndex++) {
                    if (repsNameList[orderIndex].localeCompare(currCommission["repName"]) == 1) {
                        repsNameList.splice(orderIndex, 0, currCommission["repName"]);
                        isLast = false;
                        insertionPlace = orderIndex;
                        break;
                    }
                }
                if (isLast) {
                    repsNameList.push(currCommission["repName"]);
                    insertionPlace = repsNameList.length - 1;
                }
            }
            repsList.push(currCommission["paidRepID"]);






            for (let typeIndex = 0; typeIndex < adjustmentData["typeSummaries"].length; typeIndex++) {

                for (let commIndex = 0; commIndex < adjustmentData["typeSummaries"][typeIndex]["commSummaries"].length; commIndex++) {

                    if (adjustmentData["typeSummaries"][typeIndex]["commSummaries"][commIndex]["commPeriod"] == currCommission["commPeriod"]) {


                        for (let repIndex = 0; repIndex < adjustmentData["typeSummaries"][typeIndex]["commSummaries"][commIndex]["repSummaries"].length; repIndex++) {
                            if (adjustmentData["typeSummaries"][typeIndex]["commSummaries"][commIndex]["repSummaries"][repIndex]["id"] == currCommission["paidRepID"]) {


                                adjustmentAmount = adjustmentData["typeSummaries"][typeIndex]["commSummaries"][commIndex]["repSummaries"][repIndex]["subTotalByRep"];
                            }
                        }
                    }
                }
            }

            reportOutput.grandTotalAmount.adjustments += adjustmentAmount;
            reportOutput.grandTotalBasis.adjustments += adjustmentAmount;
            const tempComm = new commPeriodSummary(currCommission["commPeriod"], new amountBreakdown(adjustmentAmount, overrideAmount, commissionAmount, overrideAmount + commissionAmount + adjustmentAmount), new basisBreakdown(adjustmentAmount, overrideBasis, commissionBasis, overrideBasis + commissionBasis + adjustmentAmount),);

            const tempRep = new commissionRepSummary(currCommission["paidRepID"], currCommission["repName"], [tempComm], new amountBreakdown(adjustmentAmount, overrideAmount, commissionAmount, overrideAmount + commissionAmount + adjustmentAmount), new basisBreakdown(adjustmentAmount, overrideBasis, commissionBasis, overrideBasis + commissionBasis + adjustmentAmount),);

            reportOutput.commissionRepSummaries.splice(insertionPlace, 0, tempRep);
        }

        else {

            for (let idIndex = 0; idIndex < reportOutput.commissionRepSummaries.length; idIndex++) {
                if (reportOutput.commissionRepSummaries[idIndex].repID == currCommission["paidRepID"]) {
                    reportOutput.commissionRepSummaries[idIndex].subtotalAmount.commissions += commissionAmount;
                    reportOutput.commissionRepSummaries[idIndex].subtotalBasis.commissions += commissionBasis;
                    reportOutput.commissionRepSummaries[idIndex].subtotalAmount.overrides += overrideAmount;
                    reportOutput.commissionRepSummaries[idIndex].subtotalBasis.overrides += overrideBasis;

                    reportOutput.commissionRepSummaries[idIndex].subtotalAmount.total += (commissionAmount + overrideAmount + adjustmentAmount);
                    reportOutput.commissionRepSummaries[idIndex].subtotalBasis.total += (commissionBasis + overrideBasis);

                    for (let commIndex = 0; commIndex < reportOutput.commissionRepSummaries[idIndex].commPeriodSummaries.length; commIndex++) {
                        if (reportOutput.commissionRepSummaries[idIndex].commPeriodSummaries[commIndex].commPeriod == currCommission["commPeriod"]) {
                            reportOutput.commissionRepSummaries[idIndex].commPeriodSummaries[commIndex].amount.commissions += commissionAmount;
                            reportOutput.commissionRepSummaries[idIndex].commPeriodSummaries[commIndex].basis.commissions += commissionBasis;
                            reportOutput.commissionRepSummaries[idIndex].commPeriodSummaries[commIndex].amount.overrides += overrideAmount;
                            reportOutput.commissionRepSummaries[idIndex].commPeriodSummaries[commIndex].basis.overrides += overrideBasis;
                            reportOutput.commissionRepSummaries[idIndex].commPeriodSummaries[commIndex].amount.total += (commissionAmount + overrideAmount + adjustmentAmount);
                            reportOutput.commissionRepSummaries[idIndex].commPeriodSummaries[commIndex].basis.total += (commissionBasis + overrideBasis);
                            isPushingNewRepSummaryIntoPeriod = false;
                        }
                    }
                    if (isPushingNewRepSummaryIntoPeriod) {


                        for (let typeIndex = 0; typeIndex < adjustmentData["typeSummaries"].length; typeIndex++) {

                            for (let commIndex = 0; commIndex < adjustmentData["typeSummaries"][typeIndex]["commSummaries"].length; commIndex++) {

                                if (adjustmentData["typeSummaries"][typeIndex]["commSummaries"][commIndex]["commPeriod"] == currCommission["commPeriod"]) {


                                    for (let repIndex = 0; repIndex < adjustmentData["typeSummaries"][typeIndex]["commSummaries"][commIndex]["repSummaries"].length; repIndex++) {
                                        if (adjustmentData["typeSummaries"][typeIndex]["commSummaries"][commIndex]["repSummaries"][repIndex]["id"] == currCommission["paidRepID"]) {


                                            adjustmentAmount = adjustmentData["typeSummaries"][typeIndex]["commSummaries"][commIndex]["repSummaries"][repIndex]["subTotalByRep"];
                                        }
                                    }
                                }
                            }
                        }


                        reportOutput.grandTotalAmount.adjustments += adjustmentAmount;
                        reportOutput.grandTotalBasis.adjustments += adjustmentAmount;
                        const tempCommission = new commPeriodSummary(currCommission["commPeriod"], new amountBreakdown(adjustmentAmount, overrideAmount, commissionAmount, commissionAmount + overrideAmount + adjustmentAmount), new basisBreakdown(adjustmentAmount, overrideBasis, commissionBasis, commissionBasis + overrideBasis));
                        reportOutput.commissionRepSummaries[idIndex].commPeriodSummaries.push(tempCommission);
                    }
                    isPushingNewRepSummaryIntoPeriod = true;
                }
            }
        }
        overrideAmount = 0;
        overrideBasis = 0;
        commissionAmount = 0;
        commissionBasis = 0;
    };



    const sortedList = sortByProperty(reportOutput.commissionRepSummaries, "repName");

    reportOutput.commissionRepSummaries = sortedList;
    for (let index: number = 0; index < sortedList.length; index++) {
        const sortedComm = sortByProperty(reportOutput.commissionRepSummaries[index].commPeriodSummaries, "commPeriod");
        reportOutput.commissionRepSummaries[index].commPeriodSummaries = sortedComm;
    }




    return JSON.stringify(reportOutput);

}




class commPeriodSummary {
    commPeriod: string;
    amount: amountBreakdown;
    basis: basisBreakdown;
    constructor(commPeriod: string,
        amount: amountBreakdown,
        basis: basisBreakdown,) {
        this.commPeriod = commPeriod;
        this.amount = amount;
        this.basis = basis;
    }
}




class commissionRepSummary {

    repID: string;
    repName: string;
    commPeriodSummaries: commPeriodSummary[];
    subtotalAmount: amountBreakdown;
    subtotalBasis: basisBreakdown;
    constructor(repID: string,
        repName: string,
        commPeriodSummaries: commPeriodSummary[],
        subtotalAmount: amountBreakdown,
        subtotalBasis: basisBreakdown,) {
        this.repID = repID;
        this.repName = repName;
        this.commPeriodSummaries = commPeriodSummaries;
        this.subtotalAmount = subtotalAmount;
        this.subtotalBasis = subtotalBasis;
    }
}

class payableBreakdownReport {
    grandTotalAmount: amountBreakdown;
    grandTotalBasis: basisBreakdown;
    commissionRepSummaries: commissionRepSummary[];
    constructor(grandTotalAmount: amountBreakdown, grandTotalBasis: basisBreakdown, commissionRepSummaries: commissionRepSummary[]) {

        this.grandTotalAmount = grandTotalAmount;
        this.grandTotalBasis = grandTotalBasis;
        this.commissionRepSummaries = commissionRepSummaries;



    }
}


class amountBreakdown {
    adjustments: number;
    overrides: number;
    commissions: number;
    total: number;
    constructor(adjustments: number, overrides: number, commissions: number, total: number) {
        this.adjustments = adjustments;
        this.overrides = overrides;
        this.commissions = commissions;
        this.total = total;
    }
}

class basisBreakdown {
    adjustments: number;
    overrides: number;
    commissions: number;
    total: number;
    constructor(adjustments: number, overrides: number, commissions: number, total: number) {
        this.adjustments = adjustments;
        this.overrides = overrides;
        this.commissions = commissions;
        this.total = total;
    }
}


