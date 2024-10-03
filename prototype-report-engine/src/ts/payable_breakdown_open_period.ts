
import { sortByProperty, getGraphQLResults, formatDate, roundToTwoPlaces } from "./index";

const GRAPHQL_ENDPOINT = process.env.API_PTOLEMY_GRAPHQLAPIENDPOINTOUTPUT;
const GRAPHQL_API_KEY = process.env.API_PTOLEMY_GRAPHQLAPIKEYOUTPUT;


export async function PayableBreakdownOpenPeriod(commissionsInput: any, fileSummary: any, adjustmentData: any, commPeriod: any, orgID: number): Promise<any> {
    //Initialized empty report
    let reportOutput: payableBreakdownReport = new payableBreakdownReport(new repSummary("Grand Totals", "", 0, 0, 0, 0, 0, 0, 0), [], [],);
    //Values for each chunk of commissions data and running totals
    let gross: number = 0;
    let override: number = 0;
    let net: number = 0;
    //Maps for matching advisor data, adjustment data, and balances/YTD data 
    let adjustmentsMap: Map<string, any> = new Map<string, any>();
    let advisorsMap: Map<string, any> = new Map<string, any>();
    let repsList: string[] = [];
    let balancesMapPrior: Map<string, any> = new Map<string, any>();
    //Query variables
    let graphQLResponseBody: any;
    let query: string = "";

    let orgFilter: string = "";



    //If fileSummary is a valid object with keys, this is not the first invocation of report engine
    //Work through prior calculated data from previous chunk of data
    if (Object.keys(fileSummary).length != 0) {
        //Add previous values to reportObject
        reportOutput.grandTotal = fileSummary.grandTotal;
        reportOutput.activeReps = fileSummary.activeReps;

        let repSummaries: repSummary[] = [];
        for (let index = 0; index < fileSummary.summaries.length; index++) {
            //Keep running count of previously appearing reps, to avoid double printing of rep info/totals
            if (!repsList.includes(fileSummary.summaries[index].repId)) {
                repsList.push(fileSummary.summaries[index].repId);
            }
            //Push each rep summary
            repSummaries.push(new repSummary(fileSummary.summaries[index].repId, fileSummary.summaries[index].repName, fileSummary.summaries[index].gross, fileSummary.summaries[index].prevBalance, fileSummary.summaries[index].balance, fileSummary.summaries[index].payable, fileSummary.summaries[index].adjustment, fileSummary.summaries[index].override, fileSummary.summaries[index].net));
        }
        //Set report value of summaries to repSummaries
        reportOutput.summaries = repSummaries;
    }
    //If there is no prior data batch, initialize adjustments and balances data
    else {
        console.log("Adjustments: ", adjustmentData);
        //Create map for connecting total adjustment sum to repID
        for (let typeIndex = 0; typeIndex < adjustmentData["typeSummaries"].length; typeIndex++) {
            for (let commIndex = 0; commIndex < adjustmentData["typeSummaries"][typeIndex]["commSummaries"].length; commIndex++) {
                for (let repIndex = 0; repIndex < adjustmentData["typeSummaries"][typeIndex]["commSummaries"][commIndex]["repSummaries"].length; repIndex++) {
                    const id = adjustmentData["typeSummaries"][typeIndex]["commSummaries"][commIndex]["repSummaries"][repIndex]["id"];
                    const amount = adjustmentData["typeSummaries"][typeIndex]["commSummaries"][commIndex]["repSummaries"][repIndex]["subTotalByRep"];

                    reportOutput.grandTotal.adjustment += amount;


                    if (adjustmentsMap.has(id)) {
                        adjustmentsMap.set(id, adjustmentsMap.get(id) + amount);

                    }
                    else {
                        adjustmentsMap.set(id, amount);
                    }

                }
            }
        }

        if (orgID == 3) {
            orgFilter = `not: {id: {contains: "-LI"}},`;
        }
        if (orgID == 2) {
            orgFilter = `id: {contains: "-LI"}`; let currentDate = new Date();
        }

        //Get all advisors; every advisor has a line item in the report, even if they didn't have 
        //commissions
        query = `query MyQuery {
            listAdvisors (filter: {_deleted: {ne: true}, status: {ne: Terminated}, ${orgFilter}}, limit: 1000)  {
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
            reportOutput.activeReps.push(graphQLResponseBody["data"]["listAdvisors"]["items"][advisorsIndex]["id"]);
            //If an advisor didn't have adjustments for this period, set their total to 0
            if (!adjustmentsMap.has(graphQLResponseBody["data"]["listAdvisors"]["items"][advisorsIndex]["id"])) {
                adjustmentsMap.set(graphQLResponseBody["data"]["listAdvisors"]["items"][advisorsIndex]["id"], 0);
            }
        }

        console.log("Adjustments Map: ", adjustmentsMap);
        //When getting past and current balances for a specific comm period, follow this logic:
        // Step One: Turn commPeriod input into Date format
        // Step Two: Try to query balances with this date as input. 
        // Step Three: Continue trying to find valid balances date, going back at most a week prior to commPeriod
        // Step Four: Once valid date found, repeat a week prior to find previous balance. Previous date will either
        // be exactly a week before, or within a day of the week before (in case of holidays)
        let currentDate = new Date();
        let gettingBalances: boolean = true;
        let attemptsCounter: number = 0;


        if (orgID == 3) {
            orgFilter = `not: {repOnTradeID: {matchPhrase: "-LI"}},`;
        }
        if (orgID == 2) {
            orgFilter = `repOnTradeID: {matchPhrase: "-LI"}`;
        }


        gettingBalances = true;
        attemptsCounter = 0;
        while (gettingBalances) {

            console.log("Candidate Date, balances Past: ", currentDate.getDate());

            attemptsCounter++;
            query = `query MyQuery {
            searchAdvisorBalances(filter: {commPeriod: {match: "${formatDate(currentDate)}"}, ${orgFilter}}, limit: 1000) {
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
                gettingBalances = false;
                console.log("Correct Date, balances Past: ", currentDate.getDate());
            }
        }

        //Set previous balance map values
        for (let balancesIndex: number = 0; balancesIndex < graphQLResponseBody["data"]["searchAdvisorBalances"]["items"].length; balancesIndex++) {
            balancesMapPrior.set(graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][balancesIndex]["repOnTradeID"], graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][balancesIndex]["balance"]);
            reportOutput.grandTotal.prevBalance += graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][balancesIndex]["balance"];

        }
        //Push each balance, payable, and adjustment total from map to rep summaries
        for (let entry of Array.from(balancesMapPrior.entries())) {
            let key = entry[0];
            if (advisorsMap.has(key)) {
                repsList.push(key);
                reportOutput.summaries.push(new repSummary(key, advisorsMap.get(key), 0, balancesMapPrior.get(key), 0, 0, adjustmentsMap.get(key), 0, 0));
            }
        }
    }

    //Begin cycling through commissions input

    console.log("Advisors Map: ", advisorsMap);
    for (let inputIndex = 0; inputIndex < commissionsInput.length; inputIndex++) {
        if (reportOutput.activeReps.includes(commissionsInput[inputIndex]["paidRepID"])) {
            net = 0;
            gross = 0;
            override = 0;
            const currCommission = commissionsInput[inputIndex];
            if (currCommission["commissionType"] == "Overrides") {
                override = currCommission["commissionNet"];
                reportOutput.grandTotal.override += override;
            }
            else {
                gross = currCommission["basis"];
                reportOutput.grandTotal.gross += gross;
                net = currCommission["commissionNet"];
                reportOutput.grandTotal.net += net;
            }

            let indexForInsertion = -1;
            for (let repsIndex = 0; repsIndex < reportOutput.summaries.length; repsIndex++) {
                if (reportOutput.summaries[repsIndex].repId == currCommission["paidRepID"]) {
                    indexForInsertion = repsIndex;
                }
            }
            if (indexForInsertion == -1) {
                reportOutput.summaries.push(new repSummary(currCommission["paidRepID"], advisorsMap.get(currCommission["paidRepID"]), gross, balancesMapPrior.get(currCommission["paidRepID"]), 0, 0, 0, override, net));
            }
            else {
                reportOutput.summaries[indexForInsertion].gross += gross;
                reportOutput.summaries[indexForInsertion].net += net;
                reportOutput.summaries[indexForInsertion].override += override;
            }
        }


    };
    reportOutput.grandTotal.payable = 0;
    reportOutput.grandTotal.balance = 0;
    for (let summaryIndex: number = 0; summaryIndex < reportOutput.summaries.length; summaryIndex++) {

        if (reportOutput.summaries[summaryIndex].prevBalance == undefined) {
            continue;
        }

        if (reportOutput.summaries[summaryIndex].prevBalance + reportOutput.summaries[summaryIndex].net + reportOutput.summaries[summaryIndex].adjustment + reportOutput.summaries[summaryIndex].override < 50) {
            reportOutput.summaries[summaryIndex].payable = 0;
            reportOutput.summaries[summaryIndex].balance = reportOutput.summaries[summaryIndex].prevBalance + reportOutput.summaries[summaryIndex].net + reportOutput.summaries[summaryIndex].adjustment + reportOutput.summaries[summaryIndex].override;

        }
        else {
            reportOutput.summaries[summaryIndex].payable = reportOutput.summaries[summaryIndex].net + reportOutput.summaries[summaryIndex].prevBalance + reportOutput.summaries[summaryIndex].adjustment + reportOutput.summaries[summaryIndex].override;
            reportOutput.summaries[summaryIndex].balance = 0;
        }




        reportOutput.grandTotal.balance += reportOutput.summaries[summaryIndex].balance;
        reportOutput.grandTotal.payable += reportOutput.summaries[summaryIndex].payable;

    }
    const sortedList = sortByProperty(reportOutput.summaries, "repName");

    reportOutput.summaries = sortedList;
    return JSON.stringify(reportOutput);
}

class repSummary {

    repId: string; repName: string; gross: number; prevBalance: number; balance: number; payable: number; adjustment: number; override: number; net: number;
    constructor(repId: string, repName: string, gross: number, prevBalance: number, balance: number, payable: number, adjustment: number, override: number, net: number) {
        this.repId = repId;
        this.repName = repName;
        this.gross = gross;
        this.prevBalance = prevBalance;
        this.balance = balance;
        this.payable = payable;
        this.adjustment = adjustment;
        this.override = override;
        this.net = net;
    }
}

class payableBreakdownReport {
    grandTotal: repSummary;
    summaries: repSummary[];
    activeReps: string[];

    constructor(grandTotal: repSummary, summaries: repSummary[], activeReps: string[],
    ) {
        this.grandTotal = grandTotal;
        this.summaries = summaries;
        this.activeReps = activeReps;

    }
}

class adjustment {
    repId: string;
    amount: number;
    constructor(repId: string, amount: number) {
        this.amount = amount;
        this.repId = repId;
    }
}


