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
import { HttpReturn } from "./packages/http_return";

/* import { CommissionPayableSummaryFinalProcessing } from "./final_processing_payable_commission"; */

//For Putting/Getting Objects
const fileClient = new S3Client();
//For creating GQL queries
const GRAPHQL_ENDPOINT = process.env.API_PTOLEMY_GRAPHQLAPIENDPOINTOUTPUT;
const GRAPHQL_API_KEY = process.env.API_PTOLEMY_GRAPHQLAPIKEYOUTPUT;

let environmentVariable: string | any = process.env.ENV;

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

    event["accessInfo"]["Value"]["fileName"] = `${environmentVariable}/temp/report/${event["accessInfo"]["Value"]["userId"]}/storage/${event["accessInfo"]["Value"]["fileName"]}`;

    console.log("File Name: ", event["accessInfo"]["Value"]["fileName"].replace(".JSON", "_finished.JSON"));

    let content: any;
    let fileRequests: number = 0;
    while (fileRequests < 100) {

        try {
            let getObjectInput: any = {
                "Bucket": "nuworks-production",
                "Key": event["accessInfo"]["Value"]["fileName"].replace(".JSON", "_finished.JSON"),
            };

            let getObjectCommand: any = new GetObjectCommand(getObjectInput);
            let getObjectResponse: any = await fileClient.send(getObjectCommand);

            console.log("Response: ", getObjectResponse);

            content = await streamToString(getObjectResponse.Body);
            break;
        }
        catch (e) {
            fileRequests++;
            await new Promise(f => setTimeout(f, 1000));
        }
    }






    console.log("Content: ", content);

    let ReportSummaryFromS3;


    //Return file contents to JSON format
    ReportSummaryFromS3 = JSON.parse(content as string);

    let statementSectionData = [];

    if(ReportSummaryFromS3.size == 0){

    }



    try {

        let powerPointReplacementData: object = {
            ConvertToPDF: true,
            FileKey: event["accessInfo"]["Value"]["fileName"],
            GroupId: "test",
            //dynamically find appropriate report template
            TemplateName: "feeCommissionStatementReportTemplate.pptx",
            ReplacementList: [
                { "Keyword": "_SECTIONS_", "Data": { "Sections": [], "Separated": true }, "Type": "section" }

            ],
        };

        




        statementSectionData.push(
            {
                "Name": "Report Header", "ReplacementData": {
                    "_REP_ID_": ReportSummaryFromS3["repId"],
                    "_REP_NAME_": ReportSummaryFromS3["repName"],
                    "_DATE_INFO_": ReportSummaryFromS3["commPeriod"]
                }
            },


        );

        statementSectionData.push({
            "Name": "Program Type Header", "ReplacementData": {

            }
        });

        for (let index = 0; index < ReportSummaryFromS3["productTypeSummaries"].length; index++) {
            statementSectionData.push({
                "Name": "Program Type Entry", "ReplacementData": {
                    "_TYPE_": `${ReportSummaryFromS3["productTypeSummaries"][index]["productTypeName"]}`,
                    "_BUSINESS_": `${ReportSummaryFromS3["productTypeSummaries"][index]["businessType"]}`,
                    "_GROSS_FEE_":
                        returnFormattedCurrency(ReportSummaryFromS3["productTypeSummaries"][index]["grossAdvisorRevenue"]),
                    "_RATE_": ReportSummaryFromS3["productTypeSummaries"][index]["advisorRate"] === 0
                        ? "n/a"
                        : `${ReportSummaryFromS3["productTypeSummaries"][index]["advisorRate"]}%`,
                    "_NET_FEE_":
                        returnFormattedCurrency(ReportSummaryFromS3["productTypeSummaries"][index]["netAdvisorRevenue"]),
                }
            })
        }

        statementSectionData.push({
            "Name": "Program Type Subtotal", "ReplacementData": {
                "_NET_EARN_": returnFormattedCurrency(ReportSummaryFromS3["periodSummary"]["advisorRevenueEarned"]),
                "_PRI_BAL_": returnFormattedCurrency(ReportSummaryFromS3["periodSummary"]["advisorPriorBalance"]),
                "_NET_PAID_": returnFormattedCurrency(ReportSummaryFromS3["periodSummary"]["advisorRevenuePaid"]),
                "_END_BAL_": returnFormattedCurrency(ReportSummaryFromS3["periodSummary"]["advisorEndingBalance"]),
                "_YTD_": returnFormattedCurrency(ReportSummaryFromS3["periodSummary"]["advisorYTD1099"])
            }
        });

        for (let summaryIndex = 0; summaryIndex < ReportSummaryFromS3["revenueSummaries"].length; summaryIndex++) {

            statementSectionData.push({
                "Name": "Program Description", "ReplacementData": {
                    "_PROGRAM_TYPE_": `${ReportSummaryFromS3["revenueSummaries"][summaryIndex]["productType"]}`,
                }
            });

            for (let businessSourceIndex = 0;
                businessSourceIndex <
                ReportSummaryFromS3["revenueSummaries"][summaryIndex]["accountRevenueSummaries"].length;
                businessSourceIndex++) {
                statementSectionData.push({
                    "Name": "Business Info", "ReplacementData": {
                        "_BUSINESS_INFO_":
                            `Business from ${ReportSummaryFromS3["revenueSummaries"][summaryIndex]["accountRevenueSummaries"][businessSourceIndex]["idNumber"]}, ${ReportSummaryFromS3["revenueSummaries"][summaryIndex]["accountRevenueSummaries"][businessSourceIndex]["description"]}`
                    }
                });
                for (let lineItemIndex = 0;
                    lineItemIndex <
                    ReportSummaryFromS3["revenueSummaries"][summaryIndex]["accountRevenueSummaries"][businessSourceIndex]
                    ["accountsApplicable"]
                        .length;
                    lineItemIndex++) {

                    statementSectionData.push(

                        {
                            "Name": "Account Header", "ReplacementData": {
                                "_ACCT_NUM_": maskAccountNumber(ReportSummaryFromS3["revenueSummaries"][summaryIndex]
                                ["accountRevenueSummaries"][businessSourceIndex]["accountsApplicable"]
                                [lineItemIndex]["accountNumber"]),
                                "_ACCT_NAME_": ReportSummaryFromS3["revenueSummaries"][summaryIndex]["accountRevenueSummaries"]
                                [businessSourceIndex]["accountsApplicable"][lineItemIndex]["accountHolderName"]
                            }
                        }

                    );
                    statementSectionData
                        .push(
                            {
                                "Name": "Account Subheader", "ReplacementData": {

                                }
                            });

                    statementSectionData
                        .push(
                            {
                                "Name": "Account Entry", "ReplacementData": {
                                    "_ENTRY_": ReportSummaryFromS3["revenueSummaries"][summaryIndex]["accountRevenueSummaries"]
                                    [businessSourceIndex]["accountsApplicable"][lineItemIndex]["entryID"],
                                    "_S_DATE_": ReportSummaryFromS3["revenueSummaries"][summaryIndex]["accountRevenueSummaries"]
                                    [businessSourceIndex]["accountsApplicable"][lineItemIndex]["statementDate"],
                                    "_EXT_ACCT_": maskAccountNumber(ReportSummaryFromS3["revenueSummaries"][summaryIndex]
                                    ["accountRevenueSummaries"][businessSourceIndex]["accountsApplicable"]
                                    [lineItemIndex]["accountNumber"]),
                                    "_TYPE_": ReportSummaryFromS3["revenueSummaries"][summaryIndex]["accountRevenueSummaries"]
                                    [businessSourceIndex]["accountsApplicable"][lineItemIndex]["accountType"],
                                    "_P_CODE_": ReportSummaryFromS3["revenueSummaries"][summaryIndex]["accountRevenueSummaries"]
                                    [businessSourceIndex]["accountsApplicable"][lineItemIndex]["productCode"],
                                    "_MODE_": ReportSummaryFromS3["revenueSummaries"][summaryIndex]["accountRevenueSummaries"]
                                    [businessSourceIndex]["accountsApplicable"][lineItemIndex]["mode"],
                                    "_PRINC_PREM_": returnFormattedCurrency(ReportSummaryFromS3["revenueSummaries"][summaryIndex]
                                    ["accountRevenueSummaries"][businessSourceIndex]["accountsApplicable"]
                                    [lineItemIndex]["principal"]),
                                    "_GROSS_COMM_": returnFormattedCurrency(ReportSummaryFromS3["revenueSummaries"][summaryIndex]
                                    ["accountRevenueSummaries"][businessSourceIndex]["accountsApplicable"]
                                    [lineItemIndex]["grossAdvisorRevenue"]),
                                    "_PAY_": returnFormattedCurrency(ReportSummaryFromS3["revenueSummaries"][summaryIndex]
                                    ["accountRevenueSummaries"][businessSourceIndex]["accountsApplicable"]
                                    [lineItemIndex]["advisorRate"]),
                                    "_NET_FEE_": returnFormattedCurrency(ReportSummaryFromS3["revenueSummaries"][summaryIndex]
                                    ["accountRevenueSummaries"][businessSourceIndex]["accountsApplicable"]
                                    [lineItemIndex]["netAdvisorRevenue"]),
                                    "_DESC_": ReportSummaryFromS3["revenueSummaries"][summaryIndex]["accountRevenueSummaries"]
                                    [businessSourceIndex]["accountsApplicable"][lineItemIndex]["productType"]
                                }
                            });

                    statementSectionData.push({
                        "Name": "Account Subtotal", "ReplacementData": {
                            "_GROSS_COMM_": returnFormattedCurrency(ReportSummaryFromS3["revenueSummaries"][summaryIndex]
                            ["accountRevenueSummaries"][businessSourceIndex]["accountsApplicable"]
                            [lineItemIndex]["grossAdvisorRevenue"]),
                            "_NET_FEE_": returnFormattedCurrency(ReportSummaryFromS3["revenueSummaries"][summaryIndex]
                            ["accountRevenueSummaries"][businessSourceIndex]["accountsApplicable"]
                            [lineItemIndex]["netAdvisorRevenue"])
                        }
                    });


                }
            }

            statementSectionData
                .push(

                    {
                        "Name": "Program Type Second Subtotal", "ReplacementData": {
                            "_BUSINESS_INFO_": "",
                            "_GROSS_COMM_": "",
                            "_NET_FEE_": "",
                            "_PROGRAM_TYPE_": `${ReportSummaryFromS3["revenueSummaries"][summaryIndex]["productType"]}`
                        }
                    }


                );
        }


        statementSectionData.push(
            {
                "Name": "Override Header", "ReplacementData": {

                }
            }

        );
        for (let overrideIndex = 0; overrideIndex < ReportSummaryFromS3["overrides"].length; overrideIndex++) {
            statementSectionData.push(

                {
                    "Name": "Override Line Item", "ReplacementData": {
                        "_REP_NAME_": ReportSummaryFromS3["overrides"][overrideIndex]["repName"],
                        "_BUSINESS_": "All",
                        "_PROGRAM_": ReportSummaryFromS3["overrides"][overrideIndex]["programType"],
                        "_GROSS_": returnFormattedCurrency(ReportSummaryFromS3["overrides"][overrideIndex]["grossCommission"] ?? 0),
                        "_RATE_": `${ReportSummaryFromS3["overrides"][overrideIndex]["rate"]}%`,
                        "_NET_": returnFormattedCurrency(ReportSummaryFromS3["overrides"][overrideIndex]["netCommission"] ?? 0)
                    }
                }

            );
        }

        statementSectionData.push(

            {
                "Name": "Override Grand Total", "ReplacementData": {
                    "_NET_": returnFormattedCurrency(ReportSummaryFromS3["overrideGrandTotalNet"])
                }
            }

        );

        statementSectionData.push(

            {
                "Name": "Grand Total", "ReplacementData": {
                    "_FEE_": "0",
                    "_DEDUCTION_": "0",
                    "_INVOICE_": "0",
                }
            }

        );


        powerPointReplacementData["ReplacementList"][0]["Data"]["Sections"] = statementSectionData;




        const inputPutObjectNewFile = {
            "Body": JSON.stringify(powerPointReplacementData),
            "Bucket": "nuworks-production",
            "Key": event["accessInfo"]["Value"]["fileName"].replace(".JSON", "_finished.JSON")
        };

        const fileCommandNewFile = new PutObjectCommand(inputPutObjectNewFile);
        await fileClient.send(fileCommandNewFile);


        const inputPutObjectTaggingNewFile = {
            "Bucket": "nuworks-production",
            "Key": event["accessInfo"]["Value"]["fileName"].replace(".JSON", "_finished.JSON"),
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
        console.log("Sent Content to PPTX Function");
        return new HttpReturn(200, "PowerPoint Data Generated");
    }

    catch (e) {
        console.log("Failed to Send Content to PPTX Function");
        return new HttpReturn(400, "PowerPoint Data Not Generated");
    }










};






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
                console.log("Status: ", response);
                console.log("Query: ", query);
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

function returnFormattedCurrency(amount: number): string {
    // Create a NumberFormat instance with the desired formatting
    const formatter = new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD',
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
    });

    let returnString = formatter.format(amount);
    if (amount < 0) {
        returnString = `(${returnString.replace('-', '')})`;
    }

    // Format the amount using the NumberFormat instance
    return returnString;
}

function maskAccountNumber(accountNumber: string): string {
    let maskCharCount = 0;
    let maskString = '';

    if (accountNumber.length <= 4) {
        maskCharCount = accountNumber.length - 2;
    } else {
        maskCharCount = accountNumber.length - 4;
    }

    for (let i = 0; i < maskCharCount; i++) {
        maskString += '*';
    }

    return maskString + accountNumber.substring(maskCharCount);
}

