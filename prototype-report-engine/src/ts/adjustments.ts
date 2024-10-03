import { roundToTwoPlaces, sortByProperty } from "./index";
export function AdjustmentList(adjustmentsInput: any, fileSummary: any): any {



    let adjtypeSummariesList: typeSummary[] = [];
    let isPushingNewRepSummary: boolean = true;
    let isPushingNewCommPeriodSummary: boolean = true;
    let grandTotal: number = 0;

    let reportOutput: adjustmentReport = new adjustmentReport(grandTotal, []);
    for (let inputIndex = 0; inputIndex < adjustmentsInput.length; inputIndex++) {

        let currAdj = adjustmentsInput[inputIndex];
        currAdj["amount"] = roundToTwoPlaces(currAdj["amount"]);

        grandTotal += roundToTwoPlaces(currAdj["amount"]);

        if (reportOutput.typeSummaries.length == 0 || !adjtypeSummariesList.includes(currAdj["type"])) {



            const tempAdj = new adjustment(currAdj["description"], currAdj["type"],

                currAdj["amount"], currAdj["repID"], currAdj["repName"], currAdj["commPeriod"]);

            const tempRep = new repSummary(currAdj["repID"], currAdj["repName"], currAdj["amount"], [tempAdj], 1);

            const tempComm = new commSummary(currAdj["commPeriod"], [tempRep], currAdj["amount"], 1);

            const temptypeSummary = new typeSummary(currAdj["type"], [tempComm], currAdj["amount"], 1);

            reportOutput.typeSummaries.push(temptypeSummary);

            adjtypeSummariesList.push(currAdj["type"]);
        }

        else {

            for (let typesIndex = 0; typesIndex < reportOutput.typeSummaries.length; typesIndex++) {

                if (reportOutput.typeSummaries[typesIndex].typeName == currAdj["type"]) {

                    for (let commIndex = 0; commIndex < reportOutput.typeSummaries[typesIndex].commSummaries.length; commIndex++) {

                        if (reportOutput.typeSummaries[typesIndex].commSummaries[commIndex].commPeriod == currAdj["commPeriod"]) {
                            isPushingNewCommPeriodSummary = false;
                            reportOutput.typeSummaries[typesIndex].commSummaries[commIndex].countByPeriod++;
                            reportOutput.typeSummaries[typesIndex].commSummaries[commIndex].subTotalByPeriod += currAdj["amount"];


                            for (let repsIndex = 0; repsIndex < reportOutput.typeSummaries[typesIndex].commSummaries[commIndex].repSummaries.length; repsIndex++) {

                                if (reportOutput.typeSummaries[typesIndex].commSummaries[commIndex].repSummaries[repsIndex].id == currAdj["repID"]) {

                                    reportOutput.typeSummaries[typesIndex].commSummaries[commIndex].repSummaries[repsIndex].subTotalByRep += currAdj["amount"];
                                    reportOutput.typeSummaries[typesIndex].commSummaries[commIndex].repSummaries[repsIndex].countByRep++;
                                    isPushingNewRepSummary = false;
                                    const tempAdj = new adjustment(currAdj["description"], currAdj["type"], currAdj["amount"], currAdj["repID"], currAdj["repName"], currAdj["commPeriod"]);
                                    reportOutput.typeSummaries[typesIndex].commSummaries[commIndex].repSummaries[repsIndex].AdjList.push(tempAdj);


                                }
                            }
                            if (isPushingNewRepSummary) {
                                const tempAdj = new adjustment(currAdj["description"], currAdj["type"], currAdj["amount"], currAdj["repID"], currAdj["repName"], currAdj["commPeriod"]);
                                const tempRep = new repSummary(currAdj["repID"], currAdj["repName"], currAdj["amount"], [tempAdj], 1);
                                reportOutput.typeSummaries[typesIndex].commSummaries[commIndex].repSummaries.push(tempRep);
                            }
                            isPushingNewRepSummary = true;
                        }
                    }
                    if (isPushingNewCommPeriodSummary) {

                        const tempAdj = new adjustment(currAdj["description"], currAdj["type"], currAdj["amount"], currAdj["repID"], currAdj["repName"], currAdj["commPeriod"]);
                        const tempRep = new repSummary(currAdj["repID"], currAdj["repName"], currAdj["amount"], [tempAdj], 1);
                        const tempComm = new commSummary(currAdj["commPeriod"], [tempRep], currAdj["amount"], 1);
                        reportOutput.typeSummaries[typesIndex].commSummaries.push(tempComm);

                    }

                    isPushingNewCommPeriodSummary = true;



                    reportOutput.typeSummaries[typesIndex].countBytype++;
                    reportOutput.typeSummaries[typesIndex].subTotalBytype += currAdj["amount"];


                }
            }



        }




    }

    reportOutput.grandTotal = grandTotal;
    const reportOutputCopy = reportOutput;

    for (let types = 0; types < reportOutputCopy.typeSummaries.length; types++) {
        for (let comm = 0; comm < reportOutputCopy.typeSummaries[types].commSummaries.length; comm++) {
            for (let rep = 0; rep < reportOutputCopy.typeSummaries[types].commSummaries[comm].repSummaries.length; rep++) {
                const preSortAdjList = reportOutputCopy.typeSummaries[types].commSummaries[comm].repSummaries[rep].AdjList;
                const postSortAdjList = sortByProperty(preSortAdjList, "description");
                reportOutput.typeSummaries[types].commSummaries[comm].repSummaries[rep].AdjList = postSortAdjList;
            }
            const preSortId = reportOutputCopy.typeSummaries[types].commSummaries[comm].repSummaries;
            const postSortId = sortByProperty(preSortId, "id");
            reportOutput.typeSummaries[types].commSummaries[comm].repSummaries = postSortId;



        }
        const preSortCommPeriod = reportOutputCopy.typeSummaries[types].commSummaries;
        const postSortCommPeriod = sortByProperty(preSortCommPeriod, "commPeriod");
        reportOutput.typeSummaries[types].commSummaries = postSortCommPeriod;
    }
    const preSortAdjType = reportOutputCopy.typeSummaries;
    const postSortAdjType = sortByProperty(preSortAdjType, "typeName");
    reportOutput.typeSummaries = postSortAdjType;







    return JSON.stringify(reportOutput);

}




class adjustment {
    repId: string;
    repName: string;
    commPeriod: string;
    description: string;
    adjtype: string;
    amount: number;

    constructor(description: string, adjtype: string, amount: number, repId: string,
        repName: string,
        commPeriod: string,) {
        this.repId = repId;
        this.repName = repName;
        this.commPeriod = commPeriod;

        this.description = description;
        this.adjtype = adjtype;
        this.amount = amount;



    }





}



class repSummary {
    id: string;
    name: string;
    subTotalByRep: number;
    countByRep: number;
    AdjList: adjustment[];
    constructor(id: string, name: string, subTotal: number, AdjList: adjustment[], count: number) {
        this.id = id, this.subTotalByRep = subTotal, this.AdjList = AdjList, this.countByRep = count, this.name = name;
    }
}

class commSummary {
    commPeriod: string;
    repSummaries: repSummary[];
    subTotalByPeriod: number;
    countByPeriod: number;
    constructor(commPeriod: string,
        repSummaries: repSummary[],
        subTotalByPeriod: number,
        countByPeriod: number,) {
        this.commPeriod = commPeriod, this.repSummaries = repSummaries, this.subTotalByPeriod = subTotalByPeriod, this.countByPeriod = countByPeriod;
    }
}

class typeSummary {
    typeName: string;
    commSummaries: commSummary[];
    subTotalBytype: number;
    countBytype: number;
    constructor(typeName: string, commSummaries: commSummary[], subTotal: number, count: number) {
        this.typeName = typeName, this.commSummaries = commSummaries, this.subTotalBytype = subTotal, this.countBytype = count;
    }

}

class adjustmentReport {
    grandTotal: number;
    typeSummaries: typeSummary[];
    constructor(grandTotal: number, typeSummaries: typeSummary[]) {
        this.grandTotal = grandTotal, this.typeSummaries = typeSummaries;
    }

}
