//@ts-ignore
import * as AWS from 'aws-sdk';
//@ts-ignore
import { S3Client, PutObjectCommand, PutObjectTaggingCommand } from "@aws-sdk/client-s3";
import { HttpReturn } from "./packages/http_return";
const stepfunctions = new AWS.StepFunctions();

const fileClient = new S3Client();



exports.handler = async (event, context) => {

    let objectInput: any;
    if (event.hasOwnProperty("accessInfo")) {
        objectInput = event;
        objectInput["subId"] = objectInput["accessInfo"]["Value"]["userId"];
        objectInput["fileName"] = objectInput["accessInfo"]["Value"]["fileName"];
        objectInput["repId"] = objectInput["accessInfo"]["Value"]["advisorId"];

    }
    else {
        objectInput = JSON.parse(event.body);
    }

    console.log("Input: ", objectInput);







    let subId: string = "";


    if (objectInput.hasOwnProperty("subId")) {

        subId = objectInput["subId"];


    }

    else {
        subId = event.requestContext.authorizer.sub;
    }


    let environmentVariable: string | any = process.env.ENV;
    let dateTime = (new Date()).getTime();
    let createAdjustmentFile: boolean = false;


    objectInput["fileName"] = `${environmentVariable}/temp/report/${subId}/storage/${objectInput["fileName"]}`;





    let inputPutObject: any = {
        "Body": "{}",
        "Bucket": "nuworks-production",
        "Key": objectInput["fileName"]
    };

    let putObjectCommand: any = new PutObjectCommand(inputPutObject);
    await fileClient.send(putObjectCommand);

    inputPutObject = {
        "Body": "{}",
        "Bucket": "nuworks-production",
        "Key": objectInput["fileName"].replace(".JSON", "_adjustments.JSON")
    };

    putObjectCommand = new PutObjectCommand(inputPutObject);
    await fileClient.send(putObjectCommand);

    if (objectInput["reportName"] == "commissionPayableSummary" || objectInput["reportName"] == "commissionBasisSummary" || objectInput["reportName"] == "payableBreakdown") {
        createAdjustmentFile = true;
    }
    if (!objectInput.hasOwnProperty("startDate")) {
        objectInput["startDate"] = "";
    }
    if (!objectInput.hasOwnProperty("endDate")) {
        objectInput["endDate"] = "";
    }
    if (!objectInput.hasOwnProperty("orgID")) {
        objectInput["orgID"] = "";
    }
    if (!objectInput.hasOwnProperty("repId")) {
        objectInput["repId"] = "";
    }
    try {
        // Construct parameters for starting the state machine execution




        const params = {
            stateMachineArn: `arn:aws:states:us-east-2:101196627737:stateMachine:ptolemyReportStateMachine-${environmentVariable}`,
            input: JSON.stringify({ "fileName": objectInput["fileName"], "startDate": objectInput["startDate"], "endDate": objectInput["endDate"], "reportName": objectInput["reportName"], "createAdjustmentFile": createAdjustmentFile, "repId": objectInput["repId"], "orgID": objectInput["orgID"], "nextToken": "" }), // Optionally, provide input data to the state machine
        };

        // Start the execution of the state machine
        const data = await stepfunctions.startExecution(params).promise();


        console.log(data);

        // Optionally, you can return the execution ARN or any other data
        if (objectInput["eventInfo"].httpMethod) {
            // Define POST method
            if (objectInput["eventInfo"].httpMethod === "POST") {
                return new HttpReturn(200, "Success");
            }
        };
    } catch (error) {
        console.error('Error triggering state machine:', error);
        throw error; // Let Lambda handle the error and return appropriate response
    }
};
