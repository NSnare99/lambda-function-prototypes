//@ts-ignore
import { S3Client, GetObjectCommand, PutObjectCommand, PutObjectTaggingCommand, DeleteObjectTaggingCommand, CopyObjectCommand } from "@aws-sdk/client-s3";
import {
    Context,
    // @ts-ignore
} from "aws-lambda";
// @ts-ignore
import { LambdaClient, InvokeCommand } from "@aws-sdk/client-lambda"; // ES Modules import
import {
    default as fetch, Request,
    // @ts-ignore
} from "node-fetch";
import { HttpReturn } from "./packages/http_return";

/* import { CommissionPayableSummaryFinalProcessing } from "./final_processing_payable_commission"; */

//For Putting/Getting Objects
const fileClient = new S3Client();
const client = new LambdaClient();
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
    const powerPointFileName = event["accessInfo"]["Value"]["fileName"].replace(".JSON", "reportTemplate.pptx");
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
    event["event"]["body"] = JSON.stringify({ "FileKey": powerPointFileName, "GroupId": "test", "TemplateName": "feeCommissionStatementReportTemplate.pptx", "ReplacementList": JSON.parse(content as string)["ReplacementList"], "ConvertToPDF": true });
    event["event"]["resource"] = "/powerpoint";
    event["event"]["path"] = "/powerpoint";
    event["event"]["requestContext"]["path"] = "/main/powerpoint";
    event["event"]["requestContext"]["resourcePath"] = "/powerpoint";
    event["event"]["headers"]["x-api-key"] = event["accessInfo"]["Value"]["userId"];
    let lambdaRequests: number = 0;
    while (lambdaRequests < 50) {
        try {
            const input = { // InvocationRequest
                FunctionName: `arn:aws:lambda:us-east-2:101196627737:function:atlasPPTX-${environmentVariable}`, // required
                InvocationType: "Event",
                Payload: JSON.stringify(event["event"]), // e.g. Buffer.from("") or new TextEncoder().encode("")
            };
            const command = new InvokeCommand(input);
            const response = await client.send(command);
            break;
        }
        catch (e) {
            lambdaRequests++;
            await new Promise(f => setTimeout(f, 1000));
        }

    }
    await new Promise(f => setTimeout(f, 35000));
    event["event"]["body"] = JSON.stringify({ "fileName": powerPointFileName });

    lambdaRequests = 0;
    while (lambdaRequests < 50) {
        try {
            console.log("Trying PDF");
            const inputPDF = { // InvocationRequest
                FunctionName: `arn:aws:lambda:us-east-2:101196627737:function:atlasPDF-${environmentVariable}`, // required
                InvocationType: "Event",
                Payload: JSON.stringify(event["event"]), // e.g. Buffer.from("") or new TextEncoder().encode("")
            };
            const commandPDF = new InvokeCommand(inputPDF);
            const responsePDF = await client.send(commandPDF);
            console.log("Response PDF: ", responsePDF);
            break;
        }
        catch (e) {
            lambdaRequests++;
            await new Promise(f => setTimeout(f, 1000));
        }

    }

    await new Promise(f => setTimeout(f, 35000));

    let moveFileRequests = 0;

    let displayFileName = `payPeriodStatement_${event["accessInfo"]["Value"]["advisorId"]}_${event["startDate"]}_${powerPointFileName.replace(".pptx", ".pdf")}`;

    while (moveFileRequests < 50) {
        try {
            console.log("Trying Copy File");
            const fileCopyInput = {
                "Bucket": `nuworks-production`,
                "CopySource": `/nuworks-production/${environmentVariable}/temp/pdf/output/${event["accessInfo"]["Value"]["userId"]}/storage/${powerPointFileName.replace(".pptx", ".pdf")}`,
                "Key": `${environmentVariable}/users/${event["accessInfo"]["Value"]["userId"]}/files/storage/${displayFileName}`
            };

            const fileCopyCommand = new CopyObjectCommand(fileCopyInput);
            const fileCopyResponse = await fileClient.send(fileCopyCommand);
            break;
        }
        catch (e) {
            console.log("Error Message: ", e);
            moveFileRequests++;
            await new Promise(f => setTimeout(f, 3000));
        }
    }
    let deleteTaggingRequests = 0;
    while (deleteTaggingRequests < 10) {
        try {
            const inputDeleteObjectTagging = {
                "Bucket": "nuworks-production",
                "Key": `${environmentVariable}/users/${event["accessInfo"]["Value"]["userId"]}/files/storage/${displayFileName}`,

            };
            const deleteObjectTaggingCommand = new DeleteObjectTaggingCommand(inputDeleteObjectTagging);
            await fileClient.send(deleteObjectTaggingCommand);
            break;
        }
        catch (e) {
            console.log("Error Message: ", e);
            deleteTaggingRequests++;
            await new Promise(f => setTimeout(f, 3000));
        }
    }

    return new HttpReturn(200, "PowerPoint Data Generated");
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


