import { sortByProperty, getGraphQLResults, formatDate, roundToTwoPlaces } from "./index";

const GRAPHQL_ENDPOINT = process.env.API_PTOLEMY_GRAPHQLAPIENDPOINTOUTPUT;
const GRAPHQL_API_KEY = process.env.API_PTOLEMY_GRAPHQLAPIKEYOUTPUT;


export async function AdvisorRevenueStatement(commissionsInput: any, fileSummary: any, commPeriod: string, repId: string): Promise<any> {



    let adjustmentsMap: Map<string, any> = new Map<string, any>();
    let query: string = "";
    let graphQLResponseBody: any;
    let advisorID: string = commissionsInput[0]["paidRepID"];
    let reportOutput: advisorRevenueStatementReport = new advisorRevenueStatementReport("", repId, commPeriod, [], new periodTotalsSummary(0, 0, 0, 0, 0), [], [], 0);


    if (Object.keys(fileSummary).length != 0) {
        reportOutput.periodSummary = fileSummary.periodSummary;
        reportOutput.productTypeSummaries = fileSummary.productTypeSummaries;
        reportOutput.revenueSummaries = fileSummary.revenueSummaries;
        reportOutput.commPeriod = fileSummary.commPeriod;
        reportOutput.overrides = fileSummary.overrides;
        reportOutput.repId = fileSummary.repId;
        reportOutput.repName = fileSummary.repName;
        reportOutput.overrideGrandTotalNet = fileSummary.overrideGrandTotalNet;


    }




    else {


        query = `query MyQuery {
        getAdvisor(id: "${repId}") {
            id
            firstName
            lastName
  }
}`;

        graphQLResponseBody = await getGraphQLResults(query);
        reportOutput.repName = `${graphQLResponseBody["data"]["getAdvisor"]["firstName"]} ${graphQLResponseBody["data"]["getAdvisor"]["lastName"]}`;


        query = `query MyQuery {
  searchAdvisorBalances(filter: {commPeriod: {lte: "${commPeriod}"}, repOnTradeID: {eq: "${repId}"}}, sort: {field: commPeriod, direction: desc}) {
    items {
      yTD1099
      balance
      payable
    }
  }
}

                    `;



        graphQLResponseBody = await getGraphQLResults(query);
        reportOutput.periodSummary.advisorPriorBalance = graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][1]["balance"];
        reportOutput.periodSummary.advisorEndingBalance = graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][0]["balance"];
        reportOutput.periodSummary.advisorRevenuePaid = graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][0]["payable"];
        reportOutput.periodSummary.advisorYTD1099 = graphQLResponseBody["data"]["searchAdvisorBalances"]["items"][0]["yTD1099"];


        query = `query MyQuery {
                listProductCategories(limit: 1000) {
                    items {
                        id
                        name
                    }
                }
            }`;

        graphQLResponseBody = await getGraphQLResults(query);

        query = `query MyQuery {
                    searchPayoutGrids(filter: { advisorID: { eq: "${repId}" } }) {
                        items {
                            packageName
                            rate
                        }
                    }
                }
            `;

        graphQLResponseBody = await getGraphQLResults(query);

        for (let index = 0; index < graphQLResponseBody["data"]["searchPayoutGrids"]["items"].length; index++) {
            reportOutput.productTypeSummaries.push(new productTypeSummary(graphQLResponseBody["data"]["searchPayoutGrids"]["items"][index]["packageName"], "All", 0, graphQLResponseBody["data"]["searchPayoutGrids"]["items"][index]["rate"], 0));
        }

        reportOutput.productTypeSummaries.push(new productTypeSummary("Overrides", "All", 0, 0, 0));






    }
    let sum = 0;



    //Begin cycling through commissions input
    for (let inputIndex = 0; inputIndex < commissionsInput.length; inputIndex++) {








        const commission = commissionsInput[inputIndex];


        sum += commission["commissionNet"];

        reportOutput.periodSummary.advisorRevenueEarned += commission["commissionNet"];


        for (let typeSummaryIndex = 0; typeSummaryIndex < reportOutput.productTypeSummaries.length; typeSummaryIndex++) {
            if (commission["commissionType"] == "Overrides") {
                if (reportOutput.productTypeSummaries[typeSummaryIndex].productTypeName == "Overrides") {
                    reportOutput.productTypeSummaries[typeSummaryIndex].netAdvisorRevenue += commission["commissionNet"];
                }
            }
            else if (commission["grid"] == reportOutput.productTypeSummaries[typeSummaryIndex].productTypeName) {
                reportOutput.productTypeSummaries[typeSummaryIndex].grossAdvisorRevenue += commission["basis"];
                reportOutput.productTypeSummaries[typeSummaryIndex].netAdvisorRevenue += commission["commissionNet"];
            }
        }
        let newTypeBreakdown = true;
        let newBusinessSourceBreakdown = true;
        let newOverride = true;



        graphQLResponseBody = await getGraphQLResults(`
                                
            query MyQuery {
searchAccounts(filter: {externalAccount: {eq: "${commission["externalAccount"]}"}}) {
items {
displayName1
}
}
}

            
            `);

        let accountHolderName = "";
        if (graphQLResponseBody["data"]["searchAccounts"]["items"].length > 0) {
            accountHolderName = graphQLResponseBody["data"]["searchAccounts"]["items"][0]["displayName1"];
        }



        if (commission["commissionType"] == "Overrides") {
            reportOutput.overrideGrandTotalNet += commission["commissionNet"];
            for (let overrideIndex = 0; overrideIndex < reportOutput.overrides.length; overrideIndex++) {

                if (commission["repOnTradeID"] == reportOutput.overrides[overrideIndex].repId && reportOutput.overrides[overrideIndex].programType.includes(commission["product"])) {
                    newOverride = false;
                    reportOutput.overrides[overrideIndex].grossCommission += commission["basis"];
                    reportOutput.overrides[overrideIndex].netCommission += commission["commissionNet"];
                }

            }
            if (newOverride) {
                graphQLResponseBody = await getGraphQLResults(`query MyQuery {
                    listProducts(limit: 1000, filter: {productName: {eq: "${commission["product"]}"}}) {
                        items {
                            productCategoryID
                        }
                    }
                }
            `);


                const productCategoryID = graphQLResponseBody["data"]["listProducts"]["items"][0]["productCategoryID"];

                graphQLResponseBody = await getGraphQLResults(`query MyQuery {
                listAdvisorOverrides(limit: 1000, filter: {repOnTradeID: {eq: "${commission["repOnTradeID"]}"}, paidRepID: {eq: "${commission["paidRepID"]}"}, applicableProductCategoryID: {eq: "${productCategoryID}"}}) {
                    items {
                        packageName
                        rate
                    }
                }
            }
        `);

                if (graphQLResponseBody["data"]["listAdvisorOverrides"]["items"].length > 0) {

                }


                const rate = graphQLResponseBody["data"]["listAdvisorOverrides"]["items"][0]["rate"];
                let packageName = graphQLResponseBody["data"]["listAdvisorOverrides"]["items"][0]["packageName"];

                if (packageName.includes("Mgr 1")) {
                    packageName = "OR1";
                }
                else if (packageName.includes("Mgr 2")) {
                    packageName = "OR2";
                }
                else if (packageName.includes("Standard")) {
                    packageName = "Standard";
                }

                query = `query MyQuery {
                    getAdvisor(id: "${commission["repOnTradeID"]}") {
                        id
                        firstName
                        lastName
              }
            }`;

                graphQLResponseBody = await getGraphQLResults(query);
                let overrideRepName = `${graphQLResponseBody["data"]["getAdvisor"]["firstName"]} ${graphQLResponseBody["data"]["getAdvisor"]["lastName"]}`;


                reportOutput.overrides.push(new override(commission["repOnTradeID"], overrideRepName, "All", `${commission["product"]} ${packageName}`, commission["basis"], rate, commission["commissionNet"]));

            }
        }

        else {
            let payoutRate = 0;
            for (let ratesIndex = 0; ratesIndex < reportOutput.productTypeSummaries.length; ratesIndex++) {
                if (commission["grid"] == reportOutput.productTypeSummaries[ratesIndex].productTypeName) {
                    payoutRate = reportOutput.productTypeSummaries[ratesIndex].advisorRate;
                }
            }
            let repSourceDescription = "";

            graphQLResponseBody = await getGraphQLResults(`query MyQuery {
               getAdvisorSplit(id: "${commission["repOnTradeID"]}") {
                individualRepOne {
                  firstName
                  lastName
                }
                 individualRepTwo {
                  firstName
                  lastName
                }
                
                individualRepThree {
                  firstName
                  lastName
                  id
                }
                repRateOne
                repRateTwo
                repRateThree
           }
       }
       `);
            if (graphQLResponseBody["data"]["getAdvisorSplit"] != null) {
                if (graphQLResponseBody["data"]["getAdvisorSplit"]["individualRepOne"] != null) {
                    repSourceDescription = `${repSourceDescription}${graphQLResponseBody["data"]["getAdvisorSplit"]["individualRepOne"]["firstName"]} ${graphQLResponseBody["data"]["getAdvisorSplit"]["individualRepOne"]["lastName"]} ${graphQLResponseBody["data"]["getAdvisorSplit"]["repRateOne"]}%`;

                }
                if (graphQLResponseBody["data"]["getAdvisorSplit"]["individualRepTwo"] != null) {
                    repSourceDescription = `${repSourceDescription}/${graphQLResponseBody["data"]["getAdvisorSplit"]["individualRepTwo"]["firstName"]} ${graphQLResponseBody["data"]["getAdvisorSplit"]["individualRepTwo"]["lastName"]} ${graphQLResponseBody["data"]["getAdvisorSplit"]["repRateTwo"]}%`;
                }
                if (graphQLResponseBody["data"]["getAdvisorSplit"]["individualRepThree"] != null) {
                    repSourceDescription = `/${repSourceDescription}${graphQLResponseBody["data"]["getAdvisorSplit"]["individualRepThree"]["firstName"]} ${graphQLResponseBody["data"]["getAdvisorSplit"]["individualRepThree"]["lastName"]} ${graphQLResponseBody["data"]["getAdvisorSplit"]["repRateThree"]}%`;
                }

            }
            else {
                repSourceDescription = commission["repName"];
            }
            for (let typeBreakdownIndex = 0; typeBreakdownIndex < reportOutput.revenueSummaries.length; typeBreakdownIndex++) {

                if (commission["grid"] == reportOutput.revenueSummaries[typeBreakdownIndex].productType) {
                    newTypeBreakdown = false;
                    for (let businessSourceIndex = 0; businessSourceIndex < reportOutput.revenueSummaries[typeBreakdownIndex].accountRevenueSummaries.length; businessSourceIndex++) {
                        if (commission["repOnTradeID"] == reportOutput.revenueSummaries[typeBreakdownIndex].accountRevenueSummaries[businessSourceIndex].idNumber) {
                            newBusinessSourceBreakdown = false;
                            reportOutput.revenueSummaries[typeBreakdownIndex].accountRevenueSummaries[businessSourceIndex].accountsApplicable.push(new accountRevenueSummary(commission["externalAccount"], accountHolderName, `${Math.floor(Math.random() * 100000)}`, commission["tradeDate"], "Account Type", commission["symbol"], "Mode", commission["principal"], commission["basis"], commission["commissionNet"], payoutRate, commission["product"]));
                            reportOutput.revenueSummaries[typeBreakdownIndex].netAdvisorRevenue += commission["commissionNet"];
                            reportOutput.revenueSummaries[typeBreakdownIndex].grossAdvisorRevenue += commission["basis"];
                        }
                    }
                    if (newBusinessSourceBreakdown) {
                        //Get proper calculation for entry id
                        //Currently a random integer


                        reportOutput.revenueSummaries[typeBreakdownIndex].accountRevenueSummaries.push(new businessSourceSummary(commission["repOnTradeID"], repSourceDescription, [new accountRevenueSummary(commission["externalAccount"], accountHolderName, `${Math.floor(Math.random() * 100000)}`, commission["tradeDate"], "Account Type", commission["symbol"], "Mode", commission["principal"], commission["basis"], commission["commissionNet"], payoutRate, commission["product"])]));
                    }

                }
            }
            if (newTypeBreakdown && commission["commissionType"] != "Overrides") {
                reportOutput.revenueSummaries.push(new productTypeRevenueSummary(commission["grid"], [new businessSourceSummary(commission["repOnTradeID"], repSourceDescription, [new accountRevenueSummary(commission["externalAccount"], accountHolderName, `${Math.floor(Math.random() * 100000)}`, commission["tradeDate"], "Account Type", commission["symbol"], "Mode", commission["principal"], commission["basis"], commission["commissionNet"], payoutRate, commission["product"])])], commission["basis"], commission["commissionNet"], 0, 0));
            }
        }



    };



    return JSON.stringify(reportOutput);
}




class advisorRevenueStatementReport {
    repName: string;
    repId: string;
    commPeriod: string;
    productTypeSummaries: productTypeSummary[];
    periodSummary: periodTotalsSummary;
    revenueSummaries: productTypeRevenueSummary[];
    overrides: override[];
    overrideGrandTotalNet: number;

    constructor(repName: string, repId: string, commPeriod: string, productTypeSummaries: productTypeSummary[], periodSummary: periodTotalsSummary,
        revenueSummaries: productTypeRevenueSummary[], overrides: override[], overrideGrandTotalNet: number,) {
        this.repName = repName;
        this.repId = repId;
        this.commPeriod = commPeriod;
        this.productTypeSummaries = productTypeSummaries;
        this.periodSummary = periodSummary;
        this.revenueSummaries = revenueSummaries;
        this.overrides = overrides;
        this.overrideGrandTotalNet = overrideGrandTotalNet;
    }
}

class productTypeSummary {
    productTypeName: string;
    businessType: string;
    grossAdvisorRevenue: number;
    advisorRate: number;
    netAdvisorRevenue: number;

    constructor(productTypeName: string,
        businessType: string,
        grossAdvisorRevenue: number,
        advisorRate: number,
        netAdvisorRevenue: number) {
        this.productTypeName = productTypeName;
        this.businessType = businessType;
        this.grossAdvisorRevenue = grossAdvisorRevenue;
        this.advisorRate = advisorRate;
        this.netAdvisorRevenue = netAdvisorRevenue;
    }
}

class periodTotalsSummary {
    advisorRevenueEarned: number;
    advisorPriorBalance: number;
    advisorRevenuePaid: number;
    advisorEndingBalance: number;
    advisorYTD1099: number;

    constructor(advisorRevenueEarned: number,
        advisorPriorBalance: number,
        advisorRevenuePaid: number,
        advisorEndingBalance: number,
        advisorYTD1099: number) {
        this.advisorRevenueEarned = advisorRevenueEarned;
        this.advisorPriorBalance = advisorPriorBalance;
        this.advisorRevenuePaid = advisorRevenuePaid;
        this.advisorEndingBalance = advisorEndingBalance;
        this.advisorYTD1099 = advisorYTD1099;
    }

}

class businessSourceSummary {
    idNumber: string;
    description: string;
    accountsApplicable: accountRevenueSummary[];
    constructor(idNumber: string,
        description: string,
        accountsApplicable: accountRevenueSummary[],) {
        this.idNumber = idNumber;
        this.description = description;
        this.accountsApplicable = accountsApplicable
    }
}

class accountRevenueSummary {
    accountNumber: string;
    accountHolderName: string;
    entryID: string;
    statementDate: string;
    accountType: string;
    productCode: string;
    mode: string;
    principal: number;
    grossAdvisorRevenue: number;
    netAdvisorRevenue: number;
    advisorRate: number;
    productType: string;
    constructor(accountNumber: string,
        accountHolderName: string,
        entryID: string,
        statementDate: string,
        accountType: string,
        productCode: string,
        mode: string,
        principal: number,
        grossAdvisorRevenue: number,
        netAdvisorRevenue: number,
        advisorRate: number,
        productType: string,) {
        this.accountNumber = accountNumber;
        this.accountHolderName = accountHolderName;
        this.entryID = entryID;
        this.statementDate = statementDate;
        this.accountType = accountType;
        this.productCode = productCode;
        this.mode = mode;
        this.principal = principal;
        this.grossAdvisorRevenue = grossAdvisorRevenue;
        this.netAdvisorRevenue = netAdvisorRevenue;
        this.advisorRate = advisorRate;
        this.productType = productType;
    }

}

class productTypeRevenueSummary {
    productType: string;
    accountRevenueSummaries: businessSourceSummary[];
    grossAdvisorRevenue: number;
    netAdvisorRevenue: number;
    deduction: number;
    invoice: number;
    constructor(productType: string,
        accountRevenueSummaries: businessSourceSummary[],
        grossAdvisorRevenue: number,
        netAdvisorRevenue: number,
        deduction: number,
        invoice: number,) {
        this.productType = productType;
        this.accountRevenueSummaries = accountRevenueSummaries;
        this.grossAdvisorRevenue = grossAdvisorRevenue;
        this.netAdvisorRevenue = netAdvisorRevenue;
        this.deduction = deduction;
        this.invoice = invoice;
    }
}


class override {
    repId: string;
    repName: string
    businessType: string;
    programType: string;
    grossCommission: number;
    rate: number;
    netCommission: number;
    constructor(
        repId: string,
        repName: string,
        businessType: string,
        programType: string,
        grossCommission: number,
        rate: number,
        netCommission: number,) {
        this.repId = repId;
        this.repName = repName;
        this.businessType = businessType;
        this.programType = programType;
        this.grossCommission = grossCommission;
        this.rate = rate;
        this.netCommission = netCommission;
    }
}



