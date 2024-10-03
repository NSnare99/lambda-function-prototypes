/* import { AdvisorRevenueStatement } from "./advisor_revenue_statement";
import { sortByProperty, getGraphQLResults, formatDate, roundToTwoPlaces } from "./index";

const GRAPHQL_ENDPOINT = process.env.API_PTOLEMY_GRAPHQLAPIENDPOINTOUTPUT;
const GRAPHQL_API_KEY = process.env.API_PTOLEMY_GRAPHQLAPIKEYOUTPUT;


export async function CommissionPayableSummaryFinalProcessing(fileSummary: any): Promise<any> {

    let ETFReps: string[] = [];
    let nonETFReps: string[] = [];
    let gross: number = 0;
    let graphQLResponseBody: any;
    let query: string = "";
    let adjustmentsMap: Map<string, any> = new Map<string, any>();
    let advisorsMap: Map<string, any> = new Map<string, any>();
    let totalGross: number = 0;
    let totalAdjustments: number = 0;
    let balancesMapPrior: Map<string, any> = new Map<string, any>();
    let balancesMapYTD: Map<string, any> = new Map<string, any>();
    let reportOutput: commissionPayableSummaryReport = new commissionPayableSummaryReport(new repSummary("Grand Totals", "", 0, 0, 0, 0, 0, 0, 0), new ETFSummary(new repSummary("ETF", "Total", 0, 0, 0, 0, 0, 0, 0), []), new nonETFSummary(new repSummary("NonETF", "Total", 0, 0, 0, 0, 0, 0, 0), [],), []);



    for (let advisorsIndex: number = 0; advisorsIndex < graphQLResponseBody["data"]["listAdvisors"]["items"].length; advisorsIndex++) {
        advisorsMap.set(graphQLResponseBody["data"]["listAdvisors"]["items"][advisorsIndex]["id"], `${graphQLResponseBody["data"]["listAdvisors"]["items"][advisorsIndex]["lastName"]}, ${graphQLResponseBody["data"]["listAdvisors"]["items"][advisorsIndex]["firstName"]}`);
        reportOutput.activeReps.push(graphQLResponseBody["data"]["listAdvisors"]["items"][advisorsIndex]["id"]);
        //If an advisor didn't have adjustments for this period, set their total to 0
        if (!adjustmentsMap.has(graphQLResponseBody["data"]["listAdvisors"]["items"][advisorsIndex]["id"])) {
            adjustmentsMap.set(graphQLResponseBody["data"]["listAdvisors"]["items"][advisorsIndex]["id"], 0);
        }
    }





    //Add summary report integration








    if (Object.keys(fileSummary).length != 0) {
        reportOutput.grandTotal = fileSummary.grandTotal;
        reportOutput.ETFSummary.total = fileSummary.ETFSummary.total;
        reportOutput.nonETFSummary.total = fileSummary.nonETFSummary.total;
        reportOutput.activeReps = fileSummary.activeReps;
        let ETFRepSummaries: repSummary[] = [];
        let nonETFRepSummaries: repSummary[] = [];

        for (let nonETFIndex = 0; nonETFIndex < fileSummary.nonETFSummary.repSummaries.length; nonETFIndex++) {


            graphQLResponseBody = await getGraphQLResults(`query MyQuery {
                searchAdvisorBalances(sort: {direction: desc, field: commPeriod}, filter: {repOnTradeID: {eq: "${reportOutput.nonETFSummary.repSummaries[nonETFIndex].repId}"}}) {
                  items {
                    commPeriod
                    yTD1099
                    balance
                  }
                }
              }
              `);

            const commPeriod = graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][0]["commPeriod"];
            const ytd1099 = graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][0]["yTD1099"];
            const balance = graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][0]["balance"];

            graphQLResponseBody = getGraphQLResults(`query MyQuery {
                listAdjustments(filter: {commPeriod: {eq: ""}, repID: {eq: ""},  is1099: {eq: false}}) {
                  items {
                    amount
                  }
                }
              }`);

            let non1099Amount = balance;

            for (let adjIndex = 0; adjIndex < graphQLResponseBody["data"]["listAdjustments"]["items"].length; adjIndex++) {
                non1099Amount -= graphQLResponseBody["data"]["listAdjustments"]["items"][adjIndex]["amount"];
            }

            fileSummary.nonETFSummary.repSummaries[nonETFIndex].YTD1099 = fileSummary.nonETFSummary.repSummaries[nonETFIndex].gross + non1099Amount + ytd1099;



        }
        for (let ETFIndex = 0; ETFIndex < fileSummary.ETFSummary.repSummaries.length; ETFIndex++) {


            graphQLResponseBody = await getGraphQLResults(`query MyQuery {
                searchAdvisorBalances(sort: {direction: desc, field: commPeriod}, filter: {repOnTradeID: {eq: "${reportOutput.ETFSummary.repSummaries[ETFIndex].repId}"}}) {
                  items {
                    commPeriod
                    yTD1099
                    balance
                  }
                }
              }
              `);

            const commPeriod = graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][0]["commPeriod"];
            const ytd1099 = graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][0]["yTD1099"];
            const balance = graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][0]["balance"];

            graphQLResponseBody = getGraphQLResults(`query MyQuery {
                listAdjustments(filter: {commPeriod: {eq: "${commPeriod}"}, repID: {eq: "${reportOutput.ETFSummary.repSummaries[ETFIndex].repId}"},  is1099: {eq: false}}) {
                  items {
                    amount
                  }
                }
              }`);

            let non1099Amount = balance;

            for (let adjIndex = 0; adjIndex < graphQLResponseBody["data"]["listAdjustments"]["items"].length; adjIndex++) {
                non1099Amount -= graphQLResponseBody["data"]["listAdjustments"]["items"][adjIndex]["amount"];
            }

            fileSummary.ETFSummary.repSummaries[ETFIndex].YTD1099 = fileSummary.ETFSummary.repSummaries[ETFIndex].gross + non1099Amount + ytd1099;



        }


        reportOutput.ETFSummary.repSummaries = ETFRepSummaries;
        reportOutput.nonETFSummary.repSummaries = nonETFRepSummaries;



    }

    else {

        let currentDate = new Date();
        let gettingBalances: boolean = true;
        let attemptsCounter: number = 0;

        while (gettingBalances) {
            attemptsCounter++;
            query = `query MyQuery {
                searchAdvisorBalances(filter: {commPeriod: {match: "${formatDate(currentDate)}"}}, limit: 1000) {
                  items {
                    repOnTradeID
                    balance
                    yTD1099
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
            balancesMapPrior.set(graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][balancesIndex]["repOnTradeID"], graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][balancesIndex]["balance"]);
            balancesMapYTD.set(graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][balancesIndex]["repOnTradeID"], graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][balancesIndex]["yTD1099"]);
            reportOutput.grandTotal.prevBalance += graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][balancesIndex]["balance"];

        }





        for (let entry of Array.from(balancesMapPrior.entries())) {
            let key = entry[0];


            if (advisorsMap.has(key)) {
                if (!adjustmentsMap.has(key)) {
                    adjustmentsMap.set(key, 0);
                }
                if (balancesMapPrior.get(key) == undefined) {
                    balancesMapPrior.set(key, 0);
                }

                if (key.includes("-LI")) {
                    nonETFReps.push(key);
                    reportOutput.nonETFSummary.repSummaries.push(new repSummary(key, advisorsMap.get(key), 0, balancesMapPrior.get(key), 0, 0, balancesMapYTD.get(key), 2, adjustmentsMap.get(key),));
                    reportOutput.nonETFSummary.total.prevBalance += balancesMapPrior.get(key);
                }
                else {
                    ETFReps.push(key);
                    reportOutput.ETFSummary.repSummaries.push(new repSummary(key, advisorsMap.get(key), 0, balancesMapPrior.get(key), 0, 0, balancesMapYTD.get(key), 3, adjustmentsMap.get(key),));
                    reportOutput.ETFSummary.total.prevBalance += balancesMapPrior.get(key);
                }
            }
        }
    }


    for (let inputIndex = 0; inputIndex < commissionsInput.length; inputIndex++) {


        if (reportOutput.activeReps.includes(commissionsInput[inputIndex]["paidRepID"])) {

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
                    reportOutput.nonETFSummary.repSummaries.push(new repSummary(currCommission["paidRepID"], (currCommission["repName"]), gross, balancesMapPrior.get(currCommission["paidRepID"]), 0, 0, 0, 2, 0,));
                    balancesMapPrior.delete(currCommission["paidRepID"]);


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
                    reportOutput.ETFSummary.repSummaries.push(new repSummary(currCommission["paidRepID"], (currCommission["repName"]), gross, balancesMapPrior.get(currCommission["paidRepID"]), 0, 0, 0, 3, 0,));
                    balancesMapPrior.delete(currCommission["paidRepID"]);


                }

            }


        }







    };


    reportOutput.grandTotal.YTD1099 = 0;
    reportOutput.grandTotal.payable = 0;
    reportOutput.grandTotal.balance = 0;

    reportOutput.ETFSummary.total.YTD1099 = 0;
    reportOutput.ETFSummary.total.payable = 0;
    reportOutput.ETFSummary.total.balance = 0;

    reportOutput.nonETFSummary.total.YTD1099 = 0;
    reportOutput.nonETFSummary.total.payable = 0;
    reportOutput.nonETFSummary.total.balance = 0;




    const reportOutputCopy = reportOutput;
    for (let summaryIndex: number = 0; summaryIndex < reportOutputCopy.ETFSummary.repSummaries.length; summaryIndex++) {

        graphQLResponseBody = await getGraphQLResults(`query MyQuery {
  searchAdvisorBalances(sort: {direction: desc, field: commPeriod}, filter: {repOnTradeID: {eq: "${reportOutput.ETFSummary.repSummaries[summaryIndex].repId}"}}) {
    items {
      yTD1099
    }
  }
}
`);

        reportOutput.ETFSummary.repSummaries[summaryIndex].YTD1099 = graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][0]["yTD1099"];
        if (reportOutput.ETFSummary.repSummaries[summaryIndex].prevBalance == undefined) {
            console.log("Passing Over Payable");
            continue;
        }


        if (reportOutput.ETFSummary.repSummaries[summaryIndex].prevBalance + reportOutput.ETFSummary.repSummaries[summaryIndex].gross + reportOutput.ETFSummary.repSummaries[summaryIndex].adjustment < 50) {
            reportOutput.ETFSummary.repSummaries[summaryIndex].payable = 0;
            if (reportOutput.ETFSummary.repSummaries[summaryIndex].gross < 0) {
                reportOutput.ETFSummary.repSummaries[summaryIndex].YTD1099 += reportOutput.ETFSummary.repSummaries[summaryIndex].gross;
            }
            reportOutput.ETFSummary.repSummaries[summaryIndex].balance = reportOutput.ETFSummary.repSummaries[summaryIndex].prevBalance + reportOutput.ETFSummary.repSummaries[summaryIndex].gross + reportOutput.ETFSummary.repSummaries[summaryIndex].adjustment;

        }
        else {
            reportOutput.ETFSummary.repSummaries[summaryIndex].payable = reportOutput.ETFSummary.repSummaries[summaryIndex].gross + reportOutput.ETFSummary.repSummaries[summaryIndex].prevBalance + reportOutput.ETFSummary.repSummaries[summaryIndex].adjustment;
            reportOutput.ETFSummary.repSummaries[summaryIndex].YTD1099 += reportOutput.ETFSummary.repSummaries[summaryIndex].gross;
            reportOutput.ETFSummary.repSummaries[summaryIndex].balance = 0;


        }


        reportOutput.ETFSummary.total.YTD1099 += reportOutput.ETFSummary.repSummaries[summaryIndex].YTD1099;
        reportOutput.ETFSummary.total.balance += reportOutput.ETFSummary.repSummaries[summaryIndex].balance;
        reportOutput.ETFSummary.total.payable += reportOutput.ETFSummary.repSummaries[summaryIndex].payable;

        reportOutput.grandTotal.balance += reportOutput.ETFSummary.repSummaries[summaryIndex].balance;
        reportOutput.grandTotal.payable += reportOutput.ETFSummary.repSummaries[summaryIndex].payable;
        reportOutput.grandTotal.YTD1099 += reportOutput.ETFSummary.repSummaries[summaryIndex].YTD1099;

    }

    for (let summaryIndex: number = 0; summaryIndex < reportOutputCopy.nonETFSummary.repSummaries.length; summaryIndex++) {
        graphQLResponseBody = await getGraphQLResults(`query MyQuery {
            searchAdvisorBalances(sort: {direction: desc, field: commPeriod}, filter: {repOnTradeID: {eq: "${reportOutput.nonETFSummary.repSummaries[summaryIndex].repId}"}}) {
              items {
                yTD1099
              }
            }
          }
          `);

        reportOutput.nonETFSummary.repSummaries[summaryIndex].YTD1099 = graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][0]["yTD1099"];
        if (reportOutput.nonETFSummary.repSummaries[summaryIndex].prevBalance == undefined) {
            continue;
        }

        if (reportOutput.nonETFSummary.repSummaries[summaryIndex].prevBalance + reportOutput.nonETFSummary.repSummaries[summaryIndex].gross + reportOutput.nonETFSummary.repSummaries[summaryIndex].adjustment < 50) {
            reportOutput.nonETFSummary.repSummaries[summaryIndex].payable = 0;
            reportOutput.nonETFSummary.repSummaries[summaryIndex].balance = reportOutput.nonETFSummary.repSummaries[summaryIndex].prevBalance + reportOutput.nonETFSummary.repSummaries[summaryIndex].gross + reportOutput.nonETFSummary.repSummaries[summaryIndex].adjustment;
        }
        else {
            reportOutput.nonETFSummary.repSummaries[summaryIndex].payable = reportOutput.nonETFSummary.repSummaries[summaryIndex].gross + reportOutput.nonETFSummary.repSummaries[summaryIndex].prevBalance + reportOutput.nonETFSummary.repSummaries[summaryIndex].adjustment;
            reportOutput.nonETFSummary.repSummaries[summaryIndex].YTD1099 += reportOutput.nonETFSummary.repSummaries[summaryIndex].gross;
            reportOutput.nonETFSummary.repSummaries[summaryIndex].balance = 0;
        }
        reportOutput.nonETFSummary.total.YTD1099 += reportOutput.nonETFSummary.repSummaries[summaryIndex].YTD1099;
        reportOutput.nonETFSummary.total.balance += reportOutput.nonETFSummary.repSummaries[summaryIndex].balance;
        reportOutput.nonETFSummary.total.payable += reportOutput.nonETFSummary.repSummaries[summaryIndex].payable;

        reportOutput.grandTotal.YTD1099 += reportOutput.nonETFSummary.repSummaries[summaryIndex].YTD1099;
        reportOutput.grandTotal.balance += reportOutput.nonETFSummary.repSummaries[summaryIndex].balance;
        reportOutput.grandTotal.payable += reportOutput.nonETFSummary.repSummaries[summaryIndex].payable;


    }
    reportOutput.grandTotal.gross += totalGross;
    reportOutput.grandTotal.adjustment = totalAdjustments;

    const sortedListEFT = sortByProperty(reportOutput.ETFSummary.repSummaries, "repName");
    const sortedListNonEFT = sortByProperty(reportOutput.nonETFSummary.repSummaries, "repName");

    reportOutput.ETFSummary.repSummaries = sortedListEFT;
    reportOutput.nonETFSummary.repSummaries = sortedListNonEFT;






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
    activeReps: string[];
    constructor(grandTotal: repSummary, ETFSummary: ETFSummary,
        nonETFSummary: nonETFSummary, activeReps: string[]) {
        this.grandTotal = grandTotal;
        this.ETFSummary = ETFSummary;
        this.nonETFSummary = nonETFSummary;
        this.activeReps = activeReps;
    }
}


 */