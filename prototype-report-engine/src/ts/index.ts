/**
 * @file prototype-report-engine/src/ts/index.ts
 * @description This file contains the RMS and Advisory Operations report engine. It interfaces with the 
 * report state machine to allow the processing of arbitrary amounts of data and a given time span. 
 * First, the report engine queries the proper databases, handles errors in queries, and determines which
 * report steps must be taken. Then, it sends a segment of the data to be stored in S3 in JSON format. 
 * Finally, it repeats the process until the given query parameters return no new data, passing the finished
 * JSON file to the next step in the state machine process.
 *
 * @method validateInput(inputDataRevenueSources: any, existingData: any, adjustmentData: any, reportName: string, event: any, isFinalSummary: boolean): Promise<any>: 
 * @description Takes the queried data, report options, and boolean isFinalSummary to determine the next step in the report process. It combines any past segments of the report file
 * with the new data, and then posts the updated report to S3. 
 *
 * @method sortByProperty<T>(arr: T[], prop: keyof T,): T[] 
 * @description Sort report data by a given parameter (date, client ID, etc. 
 */



//@ts-ignore
import { S3Client, GetObjectCommand, PutObjectCommand, PutObjectTaggingCommand } from "@aws-sdk/client-s3";
import {
    Context,
    // @ts-ignore
} from "aws-lambda";
import {
    default as fetch, Request,
    // @ts-ignore
} from "node-fetch";
import { PayableBreakdown } from "./payable_breakdown";
import { ForPayrollWeekly } from "./for_payroll_weekly";
import { AdjustmentList } from "./adjustments";
import { TradeReportWeekly } from "./trade_report_weekly";
import { WeeklyReceipts } from "./weekly_receipts";
import { CommissionBasis } from "./commission_basis";
import { CommissionPayableSummary } from "./commission_payable_summary";
import { CommissionPayableSummaryOpenPeriod } from "./commission_payable_summary_open"
import { PayableBreakdownOpenPeriod } from "./payable_breakdown_open_period";
import { HttpReturn } from "./packages/http_return";
import { AdvisorRevenueStatement } from "./advisor_revenue_statement";
/* import { CommissionPayableSummaryFinalProcessing } from "./final_processing_payable_commission"; */

//For Putting/Getting Objects
const fileClient = new S3Client();
//For creating GQL queries
const GRAPHQL_ENDPOINT = process.env.API_PTOLEMY_GRAPHQLAPIENDPOINTOUTPUT;
const GRAPHQL_API_KEY = process.env.API_PTOLEMY_GRAPHQLAPIKEYOUTPUT;

// Function to stream S3 object content to a string
async function streamToString(stream: any) {
    const chunks: any[] = [];
    return new Promise((resolve, reject) => {
        stream.on("data", (chunk: any) => chunks.push(Buffer.from(chunk)));
        stream.on("error", reject);
        stream.on("end", () => resolve(Buffer.concat(chunks).toString("utf-8")));
    });
}

export async function handler(
    event: any,
    _context: Context


): Promise<any> {



    let commissionTableSelection: string = "";
    let adjustmentTableSelection: string = "";
    let commissionItemsList: string = "";
    let adjustmentItemsList: string = "";
    let query: string = "";
    let statusCode = 200;
    let graphQLResponseBodyCommissions: any;
    let response: any;
    let adjustmentsList: any[] = [];
    let previousSummary: any;
    let repId: string = "";
    let commPeriodFilterAdjustment: string = "";
    let commPeriodFilterCommissions: string = "";
    let orgFilterCommission: string = "";
    let orgFilterAdjustment: string = "";
    let isCalculatingOpenPeriod: boolean = false;
    let queryLimit = "1000";


    if (event["reportName"] == "feeCommissionStatement") {
        queryLimit = "50";
    }

    if (event["orgID"] == 3) {
        orgFilterCommission = `not: {repName: {matchPhrase: "PFG Risk Mgmt"}},`;
        orgFilterAdjustment = `not: {repID: {contains: "-LI"}},`;

    }
    if (event["orgID"] == 2) {
        orgFilterCommission = `repName: {matchPhrase: "PFG Risk Mgmt"}`;
        orgFilterAdjustment = `repID: {contains: "-LI"},`;
    }

    if (event["startDate"] == "" && event["endDate"] == "") {
        isCalculatingOpenPeriod = true;
        commissionTableSelection = "searchPendingCommissions";
        adjustmentTableSelection = "listPendingAdjustments";
    }
    else {
        commissionTableSelection = "searchCommissions";
        adjustmentTableSelection = "listAdjustments";
        commPeriodFilterAdjustment = `commPeriod: {ge: "${event["startDate"]}", le: "${event["endDate"]}"},`;
        commPeriodFilterCommissions = `commPeriod: {gte: "${event["startDate"]}", lte: "${event["endDate"]}"},`;

    }

    if (event["reportName"] == "adjustmentList" || event["createAdjustmentFile"] == true) {

        if (event["repId"] != "") {
            repId = `repID: {eq: "${event["repId"]}"},`
        }

        query = `
        query MyQuery {
            ${adjustmentTableSelection}(limit: ${queryLimit}, filter: {_deleted: {ne: true}, ${commPeriodFilterAdjustment} ${repId} ${orgFilterAdjustment}}) {
                nextToken
              items {
                repID
                repName
                is1099
                description
                commPeriod
                category
                amount
                AdjustmentOrPayment
                type
              }
            
            }
          }`;

        let continueList: boolean = true;
        while (continueList) {
            const optionsAdjustments = {
                method: 'POST',
                headers: {
                    'x-api-key': GRAPHQL_API_KEY,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ query })
            };

            const graphQLQueryRequestAdjustments = new Request(GRAPHQL_ENDPOINT as any, optionsAdjustments as any);

            let statusCodeAdjustments = 200;
            let graphQLResponseBodyAdjustments: any;
            let responseAdjustments: any;

            try {
                response = await fetch(graphQLQueryRequestAdjustments);
                graphQLResponseBodyAdjustments = await response.json();

                if (graphQLResponseBodyAdjustments.errors) statusCode = 400;
            } catch (error: any) {
                statusCode = 400;
                graphQLResponseBodyAdjustments = {
                    errors: [
                        {
                            status: response.status,
                            message: error.message,
                            stack: error.stack
                        }
                    ]
                };
            }


            if (graphQLResponseBodyAdjustments["data"][adjustmentTableSelection]["items"].length > 0) {
                adjustmentsList.push(...graphQLResponseBodyAdjustments["data"][adjustmentTableSelection]["items"]);
            }
            let nextToken: string = "";
            if (graphQLResponseBodyAdjustments["data"][adjustmentTableSelection]["nextToken"] == null || graphQLResponseBodyAdjustments["data"][adjustmentTableSelection]["nextToken"] == "") {
                continueList = false;
            }
            else {
                nextToken = graphQLResponseBodyAdjustments["data"][adjustmentTableSelection]["nextToken"];
                query = `query MyQuery {
                    ${adjustmentTableSelection}(limit: ${queryLimit}, filter: {_deleted: {ne: true}, ${commPeriodFilterAdjustment} ${repId} ${orgFilterAdjustment}}, nextToken: "${nextToken}") {
                        nextToken
                        items {
                        repID
                        repName
                        is1099
                        description
                        commPeriod
                        category
                        amount
                        AdjustmentOrPayment
                        type
                      }
                    }
                  }
                  `;

            }
        }

        const inputPutObjectTaggingOriginalFile = {
            "Bucket": "nuworks-production",
            "Key": event["fileName"],
            "Tagging": {
                "TagSet": [
                    {
                        "Key": "temp",
                        "Value": true
                    }
                ]
            }
        };
        const putObjectTaggingCommandOriginalFile = new PutObjectTaggingCommand(inputPutObjectTaggingOriginalFile);
        await fileClient.send(putObjectTaggingCommandOriginalFile);

        let finishedFileName: string = event["fileName"].replace(".JSON", "_adjustments.JSON");
        if (event["reportName"] == "adjustmentList") {
            finishedFileName = event["fileName"].replace(".JSON", "_finished.JSON")
        }


        if (isCalculatingOpenPeriod) {

            for (let adjustmentsIndex = 0; adjustmentsIndex < adjustmentsList.length; adjustmentsIndex++) {
                adjustmentsList[adjustmentsIndex]["commPeriod"] = getCurrentDateFormatted();
            }

        }

        previousSummary = await validateInput(adjustmentsList, "", "", "adjustmentList", event, isCalculatingOpenPeriod);

        previousSummary = JSON.parse(previousSummary);

        const inputPutObjectNewFile = {
            "Body": JSON.stringify(previousSummary),
            "Bucket": "nuworks-production",
            "Key": finishedFileName
        };

        const fileCommandNewFile = new PutObjectCommand(inputPutObjectNewFile);
        await fileClient.send(fileCommandNewFile);


        const inputPutObjectTaggingNewFile = {
            "Bucket": "nuworks-production",
            "Key": finishedFileName,
            "Tagging": {
                "TagSet": [
                    {
                        "Key": "temp",
                        "Value": true
                    }
                ]
            }
        };
        const putObjectTaggingCommandNewFile = new PutObjectTaggingCommand(inputPutObjectTaggingNewFile);
        await fileClient.send(putObjectTaggingCommandNewFile);
        return { "fileName": event["fileName"], "startDate": event["startDate"], "endDate": event["endDate"], "reportName": event["reportName"], "repId": event["repId"], "orgID": event["orgID"], "nextToken": "" };
    }
    else {
        let getObjectInput: any = {
            "Bucket": "nuworks-production",
            "Key": event["fileName"],
        };

        let getObjectCommand: any = new GetObjectCommand(getObjectInput);
        let getObjectResponse: any = await fileClient.send(getObjectCommand);
        let content: any = await streamToString(getObjectResponse.Body);
        //Return file contents to JSON format
        const ReportSummaryFromS3 = JSON.parse(content as string);
        getObjectInput = {
            "Bucket": "nuworks-production",
            "Key": event["fileName"].replace(".JSON", "_adjustments.JSON"),
        };
        getObjectCommand =
            new GetObjectCommand(getObjectInput);
        getObjectResponse = await fileClient.send(getObjectCommand);
        content = await streamToString(getObjectResponse.Body);
        const AdjustmentsSummaryFromS3 = JSON.parse(content as string);
        if (event["repId"] != "") {
            repId = `paidRepID: {eq: "${event["repId"]}"},`
        }
        //Check if State Machine has passed a nextToken from prior step
        if (event["nextToken"] != "") {
            query =
                `
     query MyQuery {
         ${commissionTableSelection}(limit: ${queryLimit}, filter: {_deleted: {ne: true}, ${commPeriodFilterCommissions} ${repId} ${orgFilterCommission}}, nextToken: "${event["nextToken"]}") {
           nextToken
           items {
            id
            basis
            commPeriod
            commissionNet
            repOnTradeID
            paidRepID
            commissionType
            repName
            vendor
            principal
            bDPaidDate
            symbol
            externalAccount
            product
            grid
            tradeDate
           }
         }
       }
       
     `;
        }
        //if not, get the nextToken in request
        else {
            query = `
     query MyQuery {
         ${commissionTableSelection}(limit: ${queryLimit}, filter: {_deleted: {ne: true}, ${commPeriodFilterCommissions} ${repId} ${orgFilterCommission}}) {
           nextToken
           items {
            id
            basis
            commPeriod
            commissionNet
            repOnTradeID
            paidRepID
            commissionType
            repName
            vendor
            principal
            bDPaidDate
            symbol
            product
            externalAccount
            grid
            tradeDate
           }
         }
       }
       
     `;
        }
        const options = {
            method: 'POST',
            headers: {
                'x-api-key': GRAPHQL_API_KEY,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ query })
        };

        const graphQLQueryRequest = new Request(GRAPHQL_ENDPOINT as any, options as any);

        try {
            response = await fetch(graphQLQueryRequest,);
            graphQLResponseBodyCommissions = await response.json();
            if (graphQLResponseBodyCommissions.errors) statusCode = 400;
        } catch (error: any) {
            statusCode = 400;
            graphQLResponseBodyCommissions = {
                errors: [
                    {
                        status: response.status,
                        message: error.message,
                        stack: error.stack
                    }
                ]
            };
        }
        previousSummary = ReportSummaryFromS3;

        if (isCalculatingOpenPeriod) {

            for (let commissionsIndex = 0; commissionsIndex < graphQLResponseBodyCommissions["data"][commissionTableSelection]["items"].length; commissionsIndex++) {
                graphQLResponseBodyCommissions["data"][commissionTableSelection]["items"][commissionsIndex]["commPeriod"] = getCurrentDateFormatted();
            }

        }
        let finalSummary: any;
        //Pass along file name if no more data to retrieve
        if (graphQLResponseBodyCommissions["data"][commissionTableSelection]["items"] == null || graphQLResponseBodyCommissions["data"][commissionTableSelection]["items"].length == 0) {
            if (event["reportName"] == "commissionPayableSummary" && isCalculatingOpenPeriod) {
                finalSummary = await validateInput([], previousSummary, [], event["reportName"], event, true);
            }
            else {
                finalSummary = JSON.stringify(previousSummary);
            }

            const inputPutObjectTaggingOriginalFile = {
                "Bucket": "nuworks-production",
                "Key": event["fileName"],
                "Tagging": {
                    "TagSet": [
                        {
                            "Key": "temp",
                            "Value": true
                        }
                    ]
                }
            };
            const putObjectTaggingCommandOriginalFile = new PutObjectTaggingCommand(inputPutObjectTaggingOriginalFile);
            await fileClient.send(putObjectTaggingCommandOriginalFile);

            let finishedFileName: string = event["fileName"].replace(".JSON", "_finished.JSON");



            const inputPutObjectNewFile = {
                "Body": finalSummary,
                "Bucket": "nuworks-production",
                "Key": finishedFileName
            };

            const fileCommandNewFile = new PutObjectCommand(inputPutObjectNewFile);
            await fileClient.send(fileCommandNewFile);


            const inputPutObjectTaggingNewFile = {
                "Bucket": "nuworks-production",
                "Key": finishedFileName,
                "Tagging": {
                    "TagSet": [
                        {
                            "Key": "temp",
                            "Value": true
                        }
                    ]
                }
            };
            const putObjectTaggingCommandNewFile = new PutObjectTaggingCommand(inputPutObjectTaggingNewFile);
            await fileClient.send(putObjectTaggingCommandNewFile);


            return { "fileName": event["fileName"], "startDate": "", "endDate": "", "reportName": event["reportName"], "repId": "", "orgID": "", "nextToken": "" };
        }

        else {
            const newSummary = await validateInput(graphQLResponseBodyCommissions["data"][commissionTableSelection], previousSummary, AdjustmentsSummaryFromS3, event["reportName"], event, false);


            const inputPutObject = {
                "Body": newSummary,
                "Bucket": "nuworks-production",
                "Key": event["fileName"]
            };
            const fileCommand = new PutObjectCommand(inputPutObject);
            await fileClient.send(fileCommand);
            return { "nextToken": graphQLResponseBodyCommissions["data"][commissionTableSelection]["nextToken"], "fileName": event["fileName"], "startDate": event["startDate"], "endDate": event["endDate"], "reportName": event["reportName"], "repId": event["repId"], "orgID": event["orgID"] };
        }
    }

};

async function validateInput(inputDataRevenueSources: any, existingData: any, adjustmentData: any, reportName: string, event: any, isFinalSummary: boolean): Promise<any> {
    switch (reportName) {
        case "feeCommissionStatement":
            if (event["repId"] == "") {
                return new HttpReturn(500, "No specified Advisor ID for Statement Generation");
            }
            return AdvisorRevenueStatement(inputDataRevenueSources["items"], existingData, event["startDate"], event["repId"]);
        case "payableBreakdown":
            if (event["startDate"] == "" && event["endDate"] == "") {
                return PayableBreakdownOpenPeriod(inputDataRevenueSources["items"], existingData, adjustmentData, event["startDate"], event["orgID"])
            }
            return PayableBreakdown(inputDataRevenueSources["items"], existingData, adjustmentData, event["startDate"], event["orgID"]);
        case "adjustmentList":
            return AdjustmentList(inputDataRevenueSources, existingData);
        case "commissionBasisSummary":
            return CommissionBasis(inputDataRevenueSources["items"], existingData, adjustmentData);
        case "forPayrollWeekly":
            return ForPayrollWeekly(inputDataRevenueSources["items"], existingData);
        case "tradeReportWeekly":
            return TradeReportWeekly(inputDataRevenueSources["items"], existingData/*  inputData["VendorsReturn"] */,);
        case "weeklyReceipts":
            return WeeklyReceipts(inputDataRevenueSources["items"], existingData,);
        case "commissionPayableSummary":
            if (event["startDate"] == "" && event["endDate"] == "") {
                return await CommissionPayableSummaryOpenPeriod(inputDataRevenueSources["items"], existingData, adjustmentData, isFinalSummary);
            }
            ///Add check for too wide of comm period (greater than single comm period)
            return await CommissionPayableSummary(inputDataRevenueSources["items"], existingData, adjustmentData, event["startDate"]);
        default:
            return new Map<string, any>;

    }

}


export function sortByProperty<T>(arr: T[], prop: keyof T,): T[] {
    return arr.sort((a, b) => {
        if (a[prop] < b[prop]) {
            return -1;
        }
        if (a[prop] > b[prop]) {
            return 1;
        }
        return 0;
    });
}

export async function getGraphQLResults(query: string): Promise<any> {
    let statusCode: any = 200;
    let graphQLResponseBody: any;
    let response: any = undefined;
    let graphQLQueryRequest: any;
    let options: any;


    options = {
        method: 'POST',
        headers: {
            'x-api-key': GRAPHQL_API_KEY,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ query })
    };

    graphQLQueryRequest = new Request(GRAPHQL_ENDPOINT as any, options as any);

    statusCode = 200;



    while (response == undefined) {
        try {
            response = await fetch(graphQLQueryRequest);
            graphQLResponseBody = await response.json();

            if (graphQLResponseBody.errors) statusCode = 400;
        } catch (error: any) {
            if (response == undefined) {
                continue;
            }
            else {
                statusCode = 400;
                graphQLResponseBody = {
                    errors: [
                        {
                            status: response.status,
                            message: error.message,
                            stack: error.stack
                        }
                    ]
                };
            }

        }
    }

    return graphQLResponseBody;
}

export function formatDate(date: Date): string {

    // Get the year, month, and day from the Date object
    const year = date.getFullYear();
    const month = ('0' + (date.getMonth() + 1)).slice(-2); // Months are zero-based
    const day = ('0' + date.getDate()).slice(-2);

    // Concatenate them in the desired format
    return `${year}-${month}-${day}`;
}

export function roundToTwoPlaces(numb: number): number {
    return parseFloat((Math.round((numb + Number.EPSILON) * 100) / 100).toFixed(2));
}



export function getCurrentDateFormatted(): string {
    const currentDate: Date = new Date();
    const year: number = currentDate.getFullYear();
    const month: number = currentDate.getMonth() + 1; // Months are zero-based
    const day: number = currentDate.getDate();

    // Pad single-digit months and days with leading zeros
    const formattedMonth: string = month < 10 ? `0${month}` : `${month}`;
    const formattedDay: string = day < 10 ? `0${day}` : `${day}`;

    // Formatted date string in YYYY-MM-DD format
    const formattedDate: string = `${year}-${formattedMonth}-${formattedDay}`;

    return formattedDate;
}

