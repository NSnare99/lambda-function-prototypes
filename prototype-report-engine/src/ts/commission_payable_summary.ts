import { sortByProperty, getGraphQLResults, formatDate, roundToTwoPlaces } from "./index";

const GRAPHQL_ENDPOINT = process.env.API_PTOLEMY_GRAPHQLAPIENDPOINTOUTPUT;
const GRAPHQL_API_KEY = process.env.API_PTOLEMY_GRAPHQLAPIKEYOUTPUT;


export async function CommissionPayableSummary(commissionsInput: any, fileSummary: any, adjustmentData: any, commPeriod: string): Promise<any> {

    let ETFReps: string[] = [];
    let nonETFReps: string[] = [];
    let gross: number = 0;
    let graphQLResponseBody: any;
    let query: string = "";
    let adjustmentsMap: Map<string, any> = new Map<string, any>();
    let advisorsMap: Map<string, any> = new Map<string, any>();
    let ytdMap: Map<string, any> = new Map<string, any>();
    let totalGross: number = 0;
    let totalPayable: number = 0;
    let totalAdjustments: number = 0;
    let balancesMapPrior: Map<string, any> = new Map<string, any>();
    let balancesMapCurrent: Map<string, any> = new Map<string, any>();
    let balancesMapPayable: Map<string, any> = new Map<string, any>();






    let reportOutput: commissionPayableSummaryReport = new commissionPayableSummaryReport(new repSummary("Grand Totals", "", 0, 0, 0, 0, 0, 0, 0), new ETFSummary(new repSummary("ETF", "Total", 0, 0, 0, 0, 0, 0, 0), []), new nonETFSummary(new repSummary("NonETF", "Total", 0, 0, 0, 0, 0, 0, 0), []));
    //Add summary report integration
    if (Object.keys(fileSummary).length != 0) {
        reportOutput.grandTotal = fileSummary.grandTotal;
        reportOutput.ETFSummary.total = fileSummary.ETFSummary.total;
        reportOutput.nonETFSummary.total = fileSummary.nonETFSummary.total;
        let ETFRepSummaries: repSummary[] = [];
        let nonETFRepSummaries: repSummary[] = [];

        for (let ETFIndex = 0; ETFIndex < fileSummary.ETFSummary.repSummaries.length; ETFIndex++) {


            ETFRepSummaries.push(new repSummary(fileSummary.ETFSummary.repSummaries[ETFIndex].repId, fileSummary.ETFSummary.repSummaries[ETFIndex].repName, fileSummary.ETFSummary.repSummaries[ETFIndex].gross, fileSummary.ETFSummary.repSummaries[ETFIndex].prevBalance, fileSummary.ETFSummary.repSummaries[ETFIndex].balance, fileSummary.ETFSummary.repSummaries[ETFIndex].payable, fileSummary.ETFSummary.repSummaries[ETFIndex].YTD1099, fileSummary.ETFSummary.repSummaries[ETFIndex].orgId, fileSummary.ETFSummary.repSummaries[ETFIndex].adjustment,));
            ETFReps.push(fileSummary.ETFSummary.repSummaries[ETFIndex].repId);


        }
        for (let nonETFIndex = 0; nonETFIndex < fileSummary.nonETFSummary.repSummaries.length; nonETFIndex++) {


            nonETFRepSummaries.push(new repSummary(fileSummary.nonETFSummary.repSummaries[nonETFIndex].repId, fileSummary.nonETFSummary.repSummaries[nonETFIndex].repName, fileSummary.nonETFSummary.repSummaries[nonETFIndex].gross, fileSummary.nonETFSummary.repSummaries[nonETFIndex].prevBalance, fileSummary.nonETFSummary.repSummaries[nonETFIndex].balance, fileSummary.nonETFSummary.repSummaries[nonETFIndex].payable, fileSummary.nonETFSummary.repSummaries[nonETFIndex].YTD1099, fileSummary.nonETFSummary.repSummaries[nonETFIndex].orgId, fileSummary.nonETFSummary.repSummaries[nonETFIndex].adjustment,));
            nonETFReps.push(fileSummary.nonETFSummary.repSummaries[nonETFIndex].repId);

        }


        reportOutput.ETFSummary.repSummaries = ETFRepSummaries;
        reportOutput.nonETFSummary.repSummaries = nonETFRepSummaries;



    }

    else {




        for (let typeIndex = 0; typeIndex < adjustmentData["typeSummaries"].length; typeIndex++) {
            for (let commIndex = 0; commIndex < adjustmentData["typeSummaries"][typeIndex]["commSummaries"].length; commIndex++) {
                for (let repIndex = 0; repIndex < adjustmentData["typeSummaries"][typeIndex]["commSummaries"][commIndex]["repSummaries"].length; repIndex++) {
                    const id = adjustmentData["typeSummaries"][typeIndex]["commSummaries"][commIndex]["repSummaries"][repIndex]["id"];
                    const amount = adjustmentData["typeSummaries"][typeIndex]["commSummaries"][commIndex]["repSummaries"][repIndex]["subTotalByRep"];
                    if (adjustmentsMap.has(id)) {
                        adjustmentsMap.set(id, adjustmentsMap.get(id) + amount);
                    }
                    else {
                        adjustmentsMap.set(id, amount);
                    }
                }
            }
        }



        query = `query MyQuery {
        listAdvisors (limit: 1000)  {
          items {
            id
            firstName
            lastName
          }
        }
      }
      `;

        graphQLResponseBody = await getGraphQLResults(query);

        for (let advisorsIndex: number = 0; advisorsIndex < graphQLResponseBody["data"]["listAdvisors"]["items"].length; advisorsIndex++) {
            advisorsMap.set(graphQLResponseBody["data"]["listAdvisors"]["items"][advisorsIndex]["id"], `${graphQLResponseBody["data"]["listAdvisors"]["items"][advisorsIndex]["lastName"]}, ${graphQLResponseBody["data"]["listAdvisors"]["items"][advisorsIndex]["firstName"]}`);
        }






        let currentDate = new Date(commPeriod);
        let gettingBalances: boolean = true;
        let attemptsCounter: number = 0;





        while (gettingBalances && attemptsCounter < 30) {
            attemptsCounter++;
            query = `query MyQuery {
            searchAdvisorBalances(filter: {commPeriod: {match: "${formatDate(currentDate)}"}}, limit: 1000) {
              items {
                repOnTradeID
                balance
                yTD1099
                payable
                
              }
            }
          }
          
                `;

            graphQLResponseBody = await getGraphQLResults(query);



            if (graphQLResponseBody["data"]["searchAdvisorBalances"]["items"].length == 0) {
                currentDate.setDate(currentDate.getDate() - 1);
            }
            else {
                gettingBalances = false;
            }
        }


        for (let balancesIndex: number = 0; balancesIndex < graphQLResponseBody["data"]["searchAdvisorBalances"]["items"].length; balancesIndex++) {
            ytdMap.set(graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][balancesIndex]["repOnTradeID"], graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][balancesIndex]["yTD1099"]);
            balancesMapCurrent.set(graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][balancesIndex]["repOnTradeID"], graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][balancesIndex]["balance"]);
            reportOutput.grandTotal.balance += graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][balancesIndex]["balance"];
            balancesMapPayable.set(graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][balancesIndex]["repOnTradeID"], graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][balancesIndex]["payable"]);



        }
        currentDate.setDate(currentDate.getDate() - 1);
        gettingBalances = true;
        attemptsCounter = 0;

        while (gettingBalances && attemptsCounter < 30) {
            attemptsCounter++;
            query = `query MyQuery {
                searchAdvisorBalances(filter: {commPeriod: {match: "${formatDate(currentDate)}"}}, limit: 1000) {
                  items {
                    repOnTradeID
                    balance
                  }
                }
              }
              
                    `;

            graphQLResponseBody = await getGraphQLResults(query);

            if (graphQLResponseBody["data"]["searchAdvisorBalances"]["items"].length == 0) {
                currentDate.setDate(currentDate.getDate() - 1);
            }
            else {
                console.log("Correct Query: ", query);
                gettingBalances = false;
            }
        }
        for (let balancesIndex: number = 0; balancesIndex < graphQLResponseBody["data"]["searchAdvisorBalances"]["items"].length; balancesIndex++) {
            balancesMapPrior.set(graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][balancesIndex]["repOnTradeID"], graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][balancesIndex]["balance"]);
            reportOutput.grandTotal.prevBalance += graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][balancesIndex]["balance"];

        }




        let grossAdjustmentAddition = 0;

        for (let entry of Array.from(balancesMapCurrent.entries())) {
            let key = entry[0];

            reportOutput.grandTotal.payable += balancesMapPayable.get(key);

            if (advisorsMap.has(key)) {
                if (!adjustmentsMap.has(key)) {
                    adjustmentsMap.set(key, 0);
                }
                if (balancesMapPrior.get(key) == undefined) {
                    balancesMapPrior.set(key, 0);
                }
                if (adjustmentsMap.get(key) > 0) {
                    grossAdjustmentAddition = adjustmentsMap.get(key);

                }
                else {
                    grossAdjustmentAddition = 0;
                }

                reportOutput.grandTotal.YTD1099 += ytdMap.get(key);
                if (key.includes("-LI")) {
                    nonETFReps.push(key);
                    reportOutput.nonETFSummary.repSummaries.push(new repSummary(key, advisorsMap.get(key), grossAdjustmentAddition, balancesMapPrior.get(key), balancesMapCurrent.get(key), balancesMapPayable.get(key), ytdMap.get(key), 2, 0,));
                }
                else {
                    ETFReps.push(key);
                    reportOutput.ETFSummary.repSummaries.push(new repSummary(key, advisorsMap.get(key), grossAdjustmentAddition, balancesMapPrior.get(key), balancesMapCurrent.get(key), balancesMapPayable.get(key), ytdMap.get(key), 3, 0,));
                }
            }
        }
    }


    for (let inputIndex = 0; inputIndex < commissionsInput.length; inputIndex++) {
        gross = 0;
        const currCommission = commissionsInput[inputIndex];
        gross = currCommission["commissionNet"];
        totalGross += gross;
        const repID = currCommission["repOnTradeID"];

        if (repID.includes('-LI')) {
            reportOutput.nonETFSummary.total.gross += gross;
            if (nonETFReps.includes(currCommission["paidRepID"])) {
                //for loop to find relevant ETF rep
                for (let repIndex: number = 0; repIndex < reportOutput.nonETFSummary.repSummaries.length; repIndex++) {
                    if (reportOutput.nonETFSummary.repSummaries[repIndex]["repId"] == currCommission["paidRepID"]) {
                        reportOutput.nonETFSummary.repSummaries[repIndex].gross += gross;
                    }
                }
            }
            else {
                nonETFReps.push(currCommission["paidRepID"]);
                reportOutput.nonETFSummary.repSummaries.push(new repSummary(currCommission["paidRepID"], (currCommission["repName"]), gross, balancesMapPrior.get(currCommission["paidRepID"]), balancesMapCurrent.get(currCommission["paidRepID"]), 0, 0, 2, 0,));
                balancesMapPrior.delete(currCommission["paidRepID"]);
                balancesMapCurrent.delete(currCommission["paidRepID"]);

            }






        }

        else {

            reportOutput.ETFSummary.total.gross += gross;
            if (ETFReps.includes(currCommission["paidRepID"])) {
                //for loop to find relevant ETF rep
                for (let repIndex: number = 0; repIndex < reportOutput.ETFSummary.repSummaries.length; repIndex++) {
                    if (reportOutput.ETFSummary.repSummaries[repIndex]["repId"] == currCommission["paidRepID"]) {

                        reportOutput.ETFSummary.repSummaries[repIndex].gross += gross;

                    }
                }
            }
            else {
                ETFReps.push(currCommission["paidRepID"]);
                reportOutput.ETFSummary.repSummaries.push(new repSummary(currCommission["paidRepID"], (currCommission["repName"]), gross, balancesMapPrior.get(currCommission["paidRepID"]), balancesMapCurrent.get(currCommission["paidRepID"]), 0, 0, 3, 0,));
                balancesMapPrior.delete(currCommission["paidRepID"]);
                balancesMapCurrent.delete(currCommission["paidRepID"]);

            }

        }





    };





    const reportOutputCopy = reportOutput;

    console.log("YTD Map: ", ytdMap);

    for (let summaryIndex: number = 0; summaryIndex < reportOutputCopy.ETFSummary.repSummaries.length; summaryIndex++) {

        if (reportOutput.ETFSummary.repSummaries[summaryIndex].prevBalance == undefined) {
            console.log("Passing Over Payable");
            continue;
        }




        reportOutput.ETFSummary.repSummaries[summaryIndex].adjustment = 0;

        if (adjustmentsMap.has(reportOutput.ETFSummary.repSummaries[summaryIndex].repId)) {
            reportOutput.ETFSummary.repSummaries[summaryIndex].adjustment = adjustmentsMap.get(reportOutput.ETFSummary.repSummaries[summaryIndex].repId);
        }




        reportOutput.ETFSummary.total.YTD1099 += reportOutput.ETFSummary.repSummaries[summaryIndex].YTD1099;
        reportOutput.ETFSummary.total.prevBalance += reportOutput.ETFSummary.repSummaries[summaryIndex].prevBalance;
        reportOutput.ETFSummary.total.balance += reportOutput.ETFSummary.repSummaries[summaryIndex].balance;
        reportOutput.ETFSummary.total.payable += reportOutput.ETFSummary.repSummaries[summaryIndex].payable;

        totalAdjustments += reportOutput.ETFSummary.repSummaries[summaryIndex].adjustment;


    }

    for (let summaryIndex: number = 0; summaryIndex < reportOutputCopy.nonETFSummary.repSummaries.length; summaryIndex++) {
        if (reportOutput.nonETFSummary.repSummaries[summaryIndex].prevBalance == undefined) {
            continue;
        }

        reportOutput.nonETFSummary.repSummaries[summaryIndex].adjustment = 0;
        if (adjustmentsMap.has(reportOutput.nonETFSummary.repSummaries[summaryIndex].repId)) {
            reportOutput.nonETFSummary.repSummaries[summaryIndex].adjustment = adjustmentsMap.get(reportOutput.nonETFSummary.repSummaries[summaryIndex].repId);
        }


        totalAdjustments += reportOutput.nonETFSummary.repSummaries[summaryIndex].adjustment;
        reportOutput.nonETFSummary.total.YTD1099 += reportOutput.nonETFSummary.repSummaries[summaryIndex].YTD1099;
        reportOutput.nonETFSummary.total.prevBalance += reportOutput.nonETFSummary.repSummaries[summaryIndex].prevBalance;
        reportOutput.nonETFSummary.total.balance += reportOutput.nonETFSummary.repSummaries[summaryIndex].balance;
        reportOutput.nonETFSummary.total.payable += reportOutput.nonETFSummary.repSummaries[summaryIndex].payable;


    }
    reportOutput.grandTotal.gross += totalGross;
    reportOutput.grandTotal.adjustment = totalAdjustments;

    const sortedList = sortByProperty(reportOutput.ETFSummary.repSummaries, "repName");

    reportOutput.ETFSummary.repSummaries = sortedList;






    // return jsonResult;



    return JSON.stringify(reportOutput);
}





class repSummary {

    repId: string; repName: string; gross: number; prevBalance: number; balance: number; payable: number; YTD1099: number; orgId: number; adjustment: number;




    constructor(repId: string, repName: string, gross: number, prevBalance: number, balance: number, payable: number, YTD1099: number, orgId: number, adjustment: number,) {
        this.repId = repId;
        this.repName = repName;
        this.gross = gross;
        this.prevBalance = prevBalance;
        this.balance = balance;
        this.payable = payable;
        this.YTD1099 = YTD1099;
        this.orgId = orgId;
        this.adjustment = adjustment;



    }

}



class nonETFSummary {
    total: repSummary;
    repSummaries: repSummary[];
    constructor(total: repSummary, repSummaries: repSummary[]) {
        this.total = total;
        this.repSummaries = repSummaries;
    }
}



class ETFSummary {
    total: repSummary;
    repSummaries: repSummary[];
    constructor(total: repSummary, repSummaries: repSummary[]) {
        this.total = total;
        this.repSummaries = repSummaries;
    }
}



class commissionPayableSummaryReport {
    grandTotal: repSummary;
    ETFSummary: ETFSummary;
    nonETFSummary: nonETFSummary;
    constructor(grandTotal: repSummary, ETFSummary: ETFSummary,
        nonETFSummary: nonETFSummary) {
        this.grandTotal = grandTotal;
        this.ETFSummary = ETFSummary;
        this.nonETFSummary = nonETFSummary;
    }
}


