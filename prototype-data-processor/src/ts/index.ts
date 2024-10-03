

import {
  APIGatewayProxyEvent,
  Context,
  // @ts-ignore
} from "aws-lambda";
import { HttpReturn } from "./packages/http_return";
import { getQueryResponse } from "./packages/gqlQuery";
// @ts-ignore
import { CloudWatchLogsClient, PutLogEventsCommand } from "@aws-sdk/client-cloudwatch-logs";



export async function handler(
  event: APIGatewayProxyEvent,
  _context: Context


): Promise<any> {

  const client = new CloudWatchLogsClient();
  //Check whether the event is from client side HTTP request 
  //Or whether Lambda has been triggered by state machine execution
  let objectInput: any;
  let returnData: any[] = [];
  let responseBody: any;





  objectInput = event["lineItem"];



  responseBody = await getQueryResponse(`query MyQuery {
    getAdvisor(id: "${objectInput["repOnTradeID"]}") {
      status
    }
  }
  
  `, "getAdvisor");

  if (responseBody["data"]["getAdvisor"] != null && responseBody["data"]["getAdvisor"]["status"] == "Terminated") {
    await sendErrorLogMessage(client, event["fileName"], `Advisor with ID ${objectInput["repOnTradeID"]} Is Terminated`);
    return new HttpReturn(200, "Request is complete").toJson();
  }


  objectInput["bDPaidDate"] = getCurrentDateFormatted();
  objectInput["enteredDate"] = getCurrentDateFormatted();
  objectInput["tradeType"] = "Advisory Fees";
  console.log("Item", objectInput);
  if (objectInput["repOnTradeID"].includes("-LI")) {
    objectInput["businessType"] = "Insurance";
  }
  else {
    objectInput["businessType"] = "All";
  }
  objectInput["symbol"] = objectInput["product"];
  responseBody = await getQueryResponse(`query MyQuery {
            getProduct(id: "${objectInput["product"]}") {
              productCategoryID
              vendorID
              productName
            }
          }
        `, "getProduct");

  if (responseBody["data"]["getProduct"] == null) {
    await sendErrorLogMessage(client, event["fileName"], `Product with ID ${objectInput["product"]} Does Not Exist`);
    return new HttpReturn(200, "Request is complete").toJson();
  }

  objectInput["programCategoryCode"] = responseBody["data"]["getProduct"]["productCategoryID"];
  objectInput["vendorID"] = responseBody["data"]["getProduct"]["vendorID"];
  objectInput["product"] = responseBody["data"]["getProduct"]["productName"];


  responseBody = await getQueryResponse(`query MyQuery {
                getProductCategory(id: "${objectInput["programCategoryCode"]}") {
                  name
                }
              }
              `, "getProductCategory");



  objectInput["productCategoryName"] = responseBody["data"]["getProductCategory"]["name"];

  // Seemingly new issue where vendorID from getProduct has comma within UUID string
  // (i.e. "aaa-bbb-ccc,"). 
  // --Noah          
  responseBody = await getQueryResponse(`query MyQuery {
                getVendor(id: "${objectInput["vendorID"].replaceAll(",", "")}") {
                  name
                }
              }
              `, "getVendor");

  objectInput["vendorName"] = responseBody["data"]["getVendor"]["name"];


  responseBody = await getQueryResponse(`query _ {
    searchAccounts(filter: {externalAccount: {eq: "${objectInput["externalAccount"]}"}}) {
        items {
          clientID
          displayName1
          repID
          clientStatus
        }
      }
    }`, "searchAccounts");






  if (responseBody["data"]["searchAccounts"]["items"].length >= 1) {
    if (objectInput["repOnTradeID"] != responseBody["data"]["searchAccounts"]["items"][0]["repID"]) {
      await sendErrorLogMessage(client, event["fileName"], `Advisor with ID ${objectInput["repOnTradeID"]} Does Not Match Advisor ID ${responseBody["data"]["searchAccounts"]["items"][0]["repID"]} on Account with Number ${objectInput["externalAccount"]}`);
      return new HttpReturn(200, "Request is complete").toJson();
    }
    if (responseBody["data"]["searchAccounts"]["items"][0]["clientStatus"] == "Closed") {
      await sendErrorLogMessage(client, event["fileName"], `Account with Number ${objectInput["externalAccount"]} has Status "Closed"`);
      return new HttpReturn(200, "Request is complete").toJson();
    }
    objectInput["clientID"] = responseBody["data"]["searchAccounts"]["items"][0]["clientID"];
    objectInput["clientName"] = responseBody["data"]["searchAccounts"]["items"][0]["displayName1"];
    let names: string[] = objectInput["clientName"].split(" ");
    objectInput["sortName"] = `${names[names.length - 1].toLocaleUpperCase()}${names[0].charAt(0).toLocaleUpperCase()}`;
  }







  const splits = await getSplitLineItems(objectInput);

  console.log("Got splits: ", splits);

  if (splits.length > 0) {
    const splitsCopy = splits;
    for (let splitsIndex = 0; splitsIndex < splitsCopy.length; splitsIndex++) {

      responseBody = await getQueryResponse(` 
              
                      query MyQuery { listAdvisorOverrides(limit: 1000, filter: { and: [
        { repOnTradeID: { eq: "${splitsCopy[splitsIndex]["paidRepID"]}" } },
        {
          or: [
            { applicableProductCategoryID: { eq: "${objectInput["programCategoryCode"]}" } },
            { applicableToAllBusiness: { eq: true } }
          ]
        }
      ]}) {
                              items {
                                  rate
                                      paidRep {
                                          id
                                          firstName
                                      }
                                  }
                              }
                          }
                      `, "listAdvisorOverrides");
      if (responseBody["data"]["listAdvisorOverrides"] != null) {
        let commissionRateSplit = splits[splitsIndex]["commissionRate"];
        for (let overridesIndex = 0; overridesIndex < responseBody["data"]["listAdvisorOverrides"]["items"].length; overridesIndex++) {
          if (responseBody["data"]["listAdvisorOverrides"]["items"][overridesIndex]["paidRep"]["id"].includes("-LI")) {
            objectInput["repName"] = `${objectInput["repName"]} - PFG Risk Mgmt`;
          }
          returnData.push({ "repOnTradeID": splits[splitsIndex]["paidRepID"], "paidRepID": responseBody["data"]["listAdvisorOverrides"]["items"][overridesIndex]["paidRep"]["id"], "externalAccount": objectInput["externalAccount"], "principal": objectInput["principal"], "basis": splits[splitsIndex]["basis"], "commissionGross": splits[splitsIndex]["basis"], "commissionNet": responseBody["data"]["listAdvisorOverrides"]["items"][overridesIndex]["rate"] * splits[splitsIndex]["basis"] * .01, "commissionRate": responseBody["data"]["listAdvisorOverrides"]["items"][overridesIndex]["rate"], "settleDate": objectInput["settleDate"], "tradeDate": objectInput["tradeDate"], "product": objectInput["product"], "placedThrough": objectInput["vendorName"], "repName": objectInput["repName"], "clientId": objectInput["clientID"], "clientAlternateID": objectInput["externalAccount"], "clientName": objectInput["clientName"], "commissionType": "Overrides", "productType": objectInput["productCategoryName"], "vendor": objectInput["vendorName"], "grid": objectInput["productCategoryName"], "sortName": objectInput["sortName"], "symbol": objectInput["symbol"], "enteredDate": objectInput["enteredDate"], "businessType": objectInput["businessType"], "fee": 0, "bDPaidDate": objectInput["bDPaidDate"], "daysInBillingCycle": objectInput["daysInBillingCycle"] });
        }
        if (splits[splitsIndex]["paidRepID"].includes("-LI")) {
          objectInput["repName"] = `${objectInput["repName"]} - PFG Risk Mgmt`;
        }
        returnData.push({ "repOnTradeID": splits[splitsIndex]["repOnTradeID"], "paidRepID": splits[splitsIndex]["paidRepID"], "externalAccount": objectInput["externalAccount"], "principal": objectInput["principal"], "basis": splits[splitsIndex]["basis"], "commissionGross": splits[splitsIndex]["basis"], "commissionNet": commissionRateSplit * splits[splitsIndex]["basis"] * .01, "commissionRate": commissionRateSplit, "settleDate": objectInput["settleDate"], "tradeDate": objectInput["tradeDate"], "product": objectInput["product"], "placedThrough": objectInput["vendorName"], "repName": objectInput["repName"], "clientID": objectInput["clientID"], "clientAlternateID": objectInput["externalAccount"], "clientName": objectInput["clientName"], "commissionType": "Trades", "productType": objectInput["productCategoryName"], "vendor": objectInput["vendorName"], "grid": objectInput["productCategoryName"], "businessType": objectInput["businessType"], "fee": 0, "bDPaidDate": objectInput["bDPaidDate"], "sortName": objectInput["sortName"], "symbol": objectInput["symbol"], "enteredDate": objectInput["enteredDate"], "daysInBillingCycle": objectInput["daysInBillingCycle"] });
      }

    }


  }
  else {

    responseBody = await getQueryResponse(`query _ {
      searchPayoutGrids(limit: 1000, filter: {advisorID: {eq: "${objectInput["repOnTradeID"]}"}, productCategoryID: {eq: "${objectInput["programCategoryCode"]}"}}) {
        items {
          rate
          advisor {
            firstName
            lastName
            }
          }
        }
      }`, "searchPayoutGrids");


    console.log(`Query: query _ {
      searchPayoutGrids(limit: 1000, filter: {advisorID: {eq: "${objectInput["repOnTradeID"]}"}, productCategoryID: {eq: "${objectInput["programCategoryCode"]}"}}) {
        items {
          rate
          advisor {
            firstName
            lastName
            }
          }
        }
      }`);




    console.log("error point ", responseBody);


    objectInput["repName"] = `${responseBody["data"]["searchPayoutGrids"]["items"][0]["advisor"]["firstName"]} ${responseBody["data"]["searchPayoutGrids"]["items"][0]["advisor"]["lastName"]}`;





    let commissionRate: number = responseBody["data"]["searchPayoutGrids"]["items"][0]["rate"];
    console.log("Beginning Rate", commissionRate);


    responseBody = await getQueryResponse(` 
              
                      query MyQuery { listAdvisorOverrides(limit: 1000, filter: { and: [
        { repOnTradeID: { eq: "${objectInput["repOnTradeID"]}" } },
        {
          or: [
            { applicableProductCategoryID: { eq: "${objectInput["programCategoryCode"]}" } },
            { applicableToAllBusiness: { eq: true } }
          ]
        }
      ]}) {
                              items {
                                  rate
                                      paidRep {
                                          id
                                          firstName
                                      }
                                  }
                              }
                          }
                      `, "listAdvisorOverrides");
    if (responseBody["data"]["listAdvisorOverrides"] != null) {



      for (let overridesIndex = 0; overridesIndex < responseBody["data"]["listAdvisorOverrides"]["items"].length; overridesIndex++) {
        if (responseBody["data"]["listAdvisorOverrides"]["items"][overridesIndex]["paidRep"]["id"].includes("-LI")) {
          objectInput["repName"] = `${objectInput["repName"]} - PFG Risk Mgmt`;
        }
        returnData.push({ "repOnTradeID": objectInput["repOnTradeID"], "paidRepID": responseBody["data"]["listAdvisorOverrides"]["items"][overridesIndex]["paidRep"]["id"], "externalAccount": objectInput["externalAccount"], "principal": objectInput["principal"], "basis": objectInput["basis"], "commissionGross": objectInput["basis"], "commissionNet": responseBody["data"]["listAdvisorOverrides"]["items"][overridesIndex]["rate"] * objectInput["basis"] * .01, "commissionRate": responseBody["data"]["listAdvisorOverrides"]["items"][overridesIndex]["rate"], "settleDate": objectInput["settleDate"], "tradeDate": objectInput["tradeDate"], "product": objectInput["product"], "placedThrough": objectInput["vendorName"], "repName": objectInput["repName"], "clientID": objectInput["clientID"], "clientAlternateID": objectInput["externalAccount"], "clientName": objectInput["clientName"], "commissionType": "Overrides", "productType": objectInput["productCategoryName"], "vendor": objectInput["vendorName"], "grid": objectInput["productCategoryName"], "businessType": objectInput["businessType"], "fee": 0, "bDPaidDate": objectInput["bDPaidDate"], "sortName": objectInput["sortName"], "symbol": objectInput["symbol"], "enteredDate": objectInput["enteredDate"], "daysInBillingCycle": objectInput["daysInBillingCycle"] });
      }
      if (objectInput["repOnTradeID"].includes("-LI")) {
        objectInput["repName"] = `${objectInput["repName"]} - PFG Risk Mgmt`;
      }
      returnData.push({ "repOnTradeID": objectInput["repOnTradeID"], "paidRepID": objectInput["repOnTradeID"], "externalAccount": objectInput["externalAccount"], "principal": objectInput["principal"], "basis": objectInput["basis"], "commissionGross": objectInput["basis"], "commissionNet": commissionRate * objectInput["basis"] * .01, "commissionRate": commissionRate, "settleDate": objectInput["settleDate"], "tradeDate": objectInput["tradeDate"], "product": objectInput["product"], "placedThrough": objectInput["vendorName"], "repName": objectInput["repName"], "clientID": objectInput["clientID"], "clientAlternateID": objectInput["externalAccount"], "clientName": objectInput["clientName"], "commissionType": "Trades", "productType": objectInput["productCategoryName"], "grid": objectInput["productCategoryName"], "vendor": objectInput["vendorName"], "businessType": objectInput["businessType"], "fee": 0, "bDPaidDate": objectInput["bDPaidDate"], "sortName": objectInput["sortName"], "symbol": objectInput["symbol"], "enteredDate": objectInput["enteredDate"], "daysInBillingCycle": objectInput["daysInBillingCycle"] });
    }




    else {
      if (objectInput["repOnTradeID"].includes("-LI")) {
        objectInput["repName"] = `${objectInput["repName"]} - PFG Risk Mgmt`;
      }
      returnData.push({ "repOnTradeID": objectInput["repOnTradeID"], "paidRepID": objectInput["repOnTradeID"], "externalAccount": objectInput["externalAccount"], "principal": objectInput["principal"], "basis": objectInput["basis"], "commissionGross": objectInput["basis"], "commissionNet": commissionRate * objectInput["basis"] * .01, "commissionRate": commissionRate, "settleDate": objectInput["settleDate"], "tradeDate": objectInput["tradeDate"], "product": objectInput["product"], "placedThrough": objectInput["vendorName"], "repName": objectInput["repName"], "clientID": objectInput["clientID"], "clientAlternateID": objectInput["externalAccount"], "clientName": objectInput["clientName"], "commissionType": "Trades", "vendor": objectInput["vendorName"], "productType": objectInput["productCategoryName"], "grid": objectInput["productCategoryName"], "businessType": objectInput["businessType"], "fee": 0, "bDPaidDate": objectInput["bDPaidDate"], "sortName": objectInput["sortName"], "symbol": objectInput["symbol"], "enteredDate": objectInput["enteredDate"], "daysInBillingCycle": objectInput["daysInBillingCycle"] });
    }

  }
  return returnData;
}

function getCurrentDateFormatted(): string {
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

async function getSplitLineItems(objectInput: any): Promise<any[]> {
  let responseBody: any = await getQueryResponse(`
          query MyQuery {
              getAdvisorSplit(id: "${objectInput["repOnTradeID"]}") {
                  
                individualRepOne {
                  firstName
                  lastName
                  id
                  
                }
                individualRepThree {
                  firstName
                  lastName
                  id
                  
                }
                individualRepTwo {
                  firstName
                  lastName
                  id
                  
                }
                repRateOne
                repRateTwo
                repRateThree
              }
            }
            
          `, "getAdvisorSplit");
  if (responseBody["data"]["getAdvisorSplit"] == null) {
    return [];
  }
  let firstId = responseBody["data"]["getAdvisorSplit"]["individualRepOne"]["id"];
  let firstBasis = objectInput["basis"] * responseBody["data"]["getAdvisorSplit"]["repRateOne"] * .01;
  let firstPayoutGrids: any[] = await getAdvisorPayoutGrids(firstId);
  let firstRate: number = 0;
  let firstRepFullName: string = "";

  for (let gridIndex = 0; gridIndex < firstPayoutGrids["data"]["searchPayoutGrids"]["items"].length; gridIndex++) {
    if (firstPayoutGrids["data"]["searchPayoutGrids"]["items"][gridIndex]["productCategoryID"] == objectInput["programCategoryCode"]) {
      console.log("Payout Grid 1: ", firstPayoutGrids["data"]["searchPayoutGrids"]["items"][gridIndex]);
      firstRate = firstPayoutGrids["data"]["searchPayoutGrids"]["items"][gridIndex]["rate"];
      firstRepFullName = objectInput["repName"] = `${firstPayoutGrids["data"]["searchPayoutGrids"]["items"][gridIndex]["advisor"]["firstName"]} ${firstPayoutGrids["data"]["searchPayoutGrids"]["items"][gridIndex]["advisor"]["lastName"]}`;
    }

  }
  let secondId = responseBody["data"]["getAdvisorSplit"]["individualRepTwo"]["id"];
  let secondBasis = objectInput["basis"] * responseBody["data"]["getAdvisorSplit"]["repRateTwo"] * .01;
  let secondPayoutGrids = await getAdvisorPayoutGrids(secondId);


  let secondRate: number = 0;
  let secondRepFullName: string = "";

  for (let gridIndex = 0; gridIndex < secondPayoutGrids["data"]["searchPayoutGrids"]["items"].length; gridIndex++) {
    if (secondPayoutGrids["data"]["searchPayoutGrids"]["items"][gridIndex]["productCategoryID"] == objectInput["programCategoryCode"]) {
      console.log("Payout Grid 2: ", secondPayoutGrids["data"]["searchPayoutGrids"]["items"][gridIndex]);
      secondRate = secondPayoutGrids["data"]["searchPayoutGrids"]["items"][gridIndex]["rate"];
      secondRepFullName = `${secondPayoutGrids["data"]["searchPayoutGrids"]["items"][gridIndex]["advisor"]["firstName"]} ${secondPayoutGrids["data"]["searchPayoutGrids"]["items"][gridIndex]["advisor"]["lastName"]}`;
    }
  }

  let thirdId = "";
  let thirdBasis = 0;
  let thirdPayoutGrids;
  let thirdRate = 0;
  let thirdRepFullName = "";

  if (responseBody["data"]["getAdvisorSplit"]["individualRepThree"] != null) {
    thirdBasis = objectInput["basis"] * responseBody["data"]["getAdvisorSplit"]["repRateThree"] * .01;
    thirdId = responseBody["data"]["getAdvisorSplit"]["individualRepThree"]["id"];
    thirdPayoutGrids = await getAdvisorPayoutGrids(thirdId);
    for (let gridIndex = 0; gridIndex < thirdPayoutGrids["data"]["searchPayoutGrids"]["items"].length; gridIndex++) {
      if (thirdPayoutGrids["data"]["searchPayoutGrids"]["items"][gridIndex]["productCategoryID"] == objectInput["programCategoryCode"]) {
        console.log("Payout Grid 3: ", thirdPayoutGrids["data"]["searchPayoutGrids"]["items"][gridIndex]);
        thirdRate = thirdPayoutGrids["data"]["searchPayoutGrids"]["items"][gridIndex]["rate"];
        thirdRepFullName = `${thirdPayoutGrids["data"]["searchPayoutGrids"]["items"][gridIndex]["advisor"]["firstName"]} ${thirdPayoutGrids["data"]["searchPayoutGrids"]["items"][gridIndex]["advisor"]["lastName"]}`;
      }
    }
  }







  let firstItem = { "repOnTradeID": objectInput["repOnTradeID"], "paidRepID": firstId, "externalAccount": objectInput["externalAccount"], "principal": objectInput["principal"], "basis": firstBasis, "commissionGross": firstBasis, "commissionNet": firstRate * firstBasis * .01, "commissionRate": firstRate, "settleDate": objectInput["settleDate"], "tradeDate": objectInput["tradeDate"], "product": objectInput["product"], "placedThrough": objectInput["vendorName"], "repName": firstRepFullName, "clientID": objectInput["clientID"], "clientAlternativeID": objectInput["externalAccount"], "clientName": objectInput["clientName"], "commissionType": "Trades", "productType": objectInput["productCategoryName"], "vendor": objectInput["vendorName"], "grid": objectInput["productCategoryName"], "bDPaidDate": objectInput["bDPaidDate"], "businessType": objectInput["businessType"], "fee": 0, };

  let secondItem = { "repOnTradeID": objectInput["repOnTradeID"], "paidRepID": secondId, "externalAccount": objectInput["externalAccount"], "principal": objectInput["principal"], "basis": secondBasis, "commissionGross": secondBasis, "commissionNet": secondRate * secondBasis * .01, "commissionRate": secondRate, "settleDate": objectInput["settleDate"], "tradeDate": objectInput["tradeDate"], "product": objectInput["product"], "placedThrough": objectInput["vendorName"], "repName": secondRepFullName, "clientID": objectInput["clientID"], "clientAlternativeID": objectInput["externalAccount"], "clientName": objectInput["clientName"], "commissionType": "Trades", "productType": objectInput["productCategoryName"], "vendor": objectInput["vendorName"], "grid": objectInput["productCategoryName"], "bDPaidDate": objectInput["bDPaidDate"], "businessType": objectInput["businessType"], "fee": 0, };

  let thirdItem = {};

  if (responseBody["data"]["getAdvisorSplit"]["individualRepThree"] != null) {
    thirdItem = { "repOnTradeID": objectInput["repOnTradeID"], "paidRepID": thirdId, "externalAccount": objectInput["externalAccount"], "principal": objectInput["principal"], "basis": thirdBasis, "commissionGross": thirdBasis, "commissionNet": thirdRate * thirdBasis * .01, "commissionRate": thirdRate, "settleDate": objectInput["settleDate"], "tradeDate": objectInput["tradeDate"], "product": objectInput["product"], "placedThrough": objectInput["vendorName"], "repName": thirdRepFullName, "clientID": objectInput["clientID"], "clientAlternativeID": objectInput["externalAccount"], "clientName": objectInput["clientName"], "commissionType": "Trades", "productType": objectInput["productCategoryName"], "vendor": objectInput["vendorName"], "grid": objectInput["productCategoryName"], "bDPaidDate": objectInput["bDPaidDate"], "businessType": objectInput["businessType"], "fee": 0, };
    console.log("Return Split Items: ", [firstItem, secondItem, thirdItem]);
    return [firstItem, secondItem, thirdItem];
  }


  console.log("Return Split Items: ", [firstItem, secondItem]);


  return [firstItem, secondItem];

}


export async function getAdvisorPayoutGrids(repId: string): Promise<any> {
  console.log("Query: ", `
  query MyQuery {
    searchPayoutGrids(limit: 1000, filter: {advisorID: {eq: "${repId}"}}) {
      items {
        rate
        productCategoryID
        advisor {
          firstName
          lastName
        }
      }
    }
  }
          `);
  return getQueryResponse(`
  query MyQuery {
    searchPayoutGrids(limit: 1000, filter: {advisorID: {eq: "${repId}"}}) {
      items {
        rate
        productCategoryID
        advisor {
          firstName
          lastName
        }
      }
    }
  }
          `, "searchPayoutGrids");
}




async function sendErrorLogMessage(client: any, logName: string, message: string): Promise<any> {

  console.log(`Environment Check: ${process.env.ENV}`);

  const errorLoggingInput = { // PutLogEventsRequest
    logGroupName: `/aws/lambda/ptolemyPeriodCloseStateMachineStart-${process.env.ENV}`, // required
    logStreamName: logName, // required
    logEvents: [ // InputLogEvents // required
      { // InputLogEvent
        timestamp: Math.round((new Date()).getTime()), // required
        message: message, // required
      },
    ],
  };
  const errorLoggingCommand = new PutLogEventsCommand(errorLoggingInput);
  return await client.send(errorLoggingCommand);
}


