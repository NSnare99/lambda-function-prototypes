

import {
  APIGatewayProxyEvent,
  Context,
  // @ts-ignore
} from "aws-lambda";
import { getQueryResponse } from "./packages/gqlQuery";
import { HttpReturn } from "./packages/http_return";
// @ts-ignore
import { CloudWatchLogsClient, PutLogEventsCommand } from "@aws-sdk/client-cloudwatch-logs";



export async function handler(
  event: APIGatewayProxyEvent,
  _context: Context


): Promise<any> {


  const client = new CloudWatchLogsClient();
  let objectInput: any;
  let responseBody: any;
  let programCategoryCode: string = "";
  objectInput = event["lineItem"];
  let objectInputId: any = objectInput["id"];
  let originalPaidRepId: string = objectInput["paidRepID"];


  if (objectInput["paidRepID"].includes("-LI") && !objectInput["repName"].includes("- PFG Risk Mgmt")) {
    objectInput["repName"] = `${objectInput["repName"]} - PFG Risk Mgmt`;
  }


  responseBody = await getQueryResponse(`
    
    query _ {
  getAdvisor(id: "${objectInput["paidRepID"]}") {
    lastName
  }
}


    `, "getAdvisor");

  if (responseBody["data"]["getAdvisor"] == null) {
    console.log("Failed");
    await sendErrorLogMessage(client, event["fileName"], `Advisor With ID ${objectInput["repOnTradeID"]} Does Not Exist`);
    return new HttpReturn(200, "Request is complete").toJson();
  }

  console.log("Item didn't fail check");





  responseBody = await getQueryResponse(`query MyQuery {
  listProducts(filter: {productName: {eq: "${objectInput["product"]}"}}, limit: 1000  ) {
    items {
      productCategoryID
      vendorID
    }
  }
}

        `, "listProducts");

  programCategoryCode = responseBody["data"]["listProducts"]["items"][0]["productCategoryID"];

  responseBody = await getQueryResponse(`query MyQuery {
                getProductCategory(id: "${programCategoryCode}") {
                  name
                }
              }
              `, "getProductCategory");



  objectInput["grid"] = responseBody["data"]["getProductCategory"]["name"];

  responseBody = await getQueryResponse(`query _ {
    searchAccounts(filter: {externalAccount: {eq: "${objectInput["externalAccount"]}"}}) {
        items {
          clientID
          displayName1
        }
      }
    }`, "searchAccounts");
  if (responseBody["data"]["searchAccounts"]["items"].length == 0) {
    objectInput["clientID"] = "";
    objectInput["clientName"] = "";
    objectInput["sortName"] = "";


  }
  else {
    objectInput["clientID"] = responseBody["data"]["searchAccounts"]["items"][0]["clientID"];
    objectInput["clientName"] = responseBody["data"]["searchAccounts"]["items"][0]["displayName1"];
    let names: string[] = objectInput["clientName"].split(" ");
    objectInput["sortName"] = `${names[names.length - 1].toLocaleUpperCase()}${names[0].charAt(0).toLocaleUpperCase()}`;
  }

  if (objectInput["commissionType"] == "Overrides") {
    //If updating an override line item, there are two possiblities: updating or deleting
    //If no advisor override which matches this line item can be found, it has been
    //deleted from the overrides DB and thus the line item should be deleted.
    //Otherwise, get the most recent override rate and update the line. 
    //Either way, this is the return point for the recalculation, and nothing else need be done


    responseBody = await getQueryResponse(`         query MyQuery { listAdvisorOverrides(limit: 1000, filter: { and: [
        { repOnTradeID: { eq: "${objectInput["repOnTradeID"]}" } },
        {paidRepID: {eq: "${objectInput["paidRepID"]}"}}
        {
          or: [
            { applicableProductCategoryID: { eq: "${programCategoryCode}" } },
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
                     `, "listAdvisorOverrides"
    );
    //If overrides query returns nothing, override no longer exists
    if (responseBody["data"]["listAdvisorOverrides"]["items"].length == 0) {
      await getQueryResponse(`mutation MyMutation {
          deletePendingCommission(input: {_version: ${objectInput["_version"]}, id: "${objectInput["id"]}"}) {
            id
            _version
            _deleted
       } 
            }`, "deletePendingCommission");
      return new HttpReturn(200, "Request is complete").toJson();
    }

    else {

      //Recalculate rates
      objectInput["commissionRate"] = responseBody["data"]["listAdvisorOverrides"]["items"][0]["rate"];
      objectInput["commissionNet"] = objectInput["commissionRate"] * objectInput["basis"] * .01;
      // Convert object to custom JSON format
      const response = await getQueryResponse(`mutation MyMutation {
        updatePendingCommission(input: ${confirmGraphQLUpdate(objectInput)}){
            id
            _version
          }
        } 
      `, "updatePendingCommission");

      if (!response.hasOwnProperty("errors")) {
        return new HttpReturn(200, "Request is complete").toJson();
      }
      else {
        return new HttpReturn(500, "Retry").toJson();
      }


    }
  }

  //If item is a split, do the same as with an override; simply update or delete, and exit
  else if (objectInput["paidRepID"] != objectInput["repOnTradeID"]) {
    const response = await getQueryResponse(`mutation MyMutation {
      updatePendingCommission(input: ${confirmGraphQLUpdate(objectInput)}){
          id
          _version
      }
    } 
  `, "updatePendingCommission");
    if (!response.hasOwnProperty("errors")) {
      return new HttpReturn(200, "Request is complete").toJson();
    }
    else {
      return new HttpReturn(500, "Retry").toJson();
    }

  }
  //Firstly, get initial payout rate from grid and save for later calculation
  responseBody = await getQueryResponse(`query _ {
      searchPayoutGrids(limit: 1000, filter: {advisorID: {eq: "${objectInput["repOnTradeID"]}"}, productCategoryID: {eq: "${programCategoryCode}"}}) {
        items {
          rate
          advisor {
            firstName
            lastName  
          }
          }
        }
      }`, "searchPayoutGrids");

  let commissionRate: number = 0;

  commissionRate = responseBody["data"]["searchPayoutGrids"]["items"][0]["rate"];

  //If there are no splits, move onto overrides
  responseBody = await getQueryResponse(` 
      query MyQuery { listAdvisorOverrides(filter: {applicableProductCategoryID: {eq: "${programCategoryCode}"}, 
          repOnTradeID: {eq: "${objectInput["repOnTradeID"]}"}}) {
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


  if (responseBody["data"]["listAdvisorOverrides"]["items"].length != 0) {
    //If overrides exist, get the override rate
    const overrideCommissionRate = responseBody["data"]["listAdvisorOverrides"]["items"][0]["rate"];
    for (let overridesIndex = 0; overridesIndex < responseBody["data"]["listAdvisorOverrides"]["items"].length; overridesIndex++) {
      //Subtract override from trade commission rat
      commissionRate -= responseBody["data"]["listAdvisorOverrides"]["items"][overridesIndex]["rate"];
    }
    //Advisor who is receiving trade
    let paidRepID: string = responseBody["data"]["listAdvisorOverrides"]["items"][0]["paidRep"]["id"];

    //Check if override line item exists yet in Pending Commissions
    //If it doesn't, then the overrides DB was updated after 
    //original loader file was uploaded. Thus, a new line item needs to be created

    //This pending commission is uniquely identified by account number and rep ids. One commission per account number
    //per period. 
    responseBody = await getQueryResponse(`
          
          query MyQuery {
            searchPendingCommissions(filter: {commissionType: {eq: "Overrides"}, externalAccount: {eq: "${objectInput["externalAccount"]}"}, paidRepID: {eq: "${paidRepID}"}, repOnTradeID: {eq: "${objectInput["repOnTradeID"]}"}}) {
             items {
              id
              commissionNet
              _version
            }
          }
        }
          `, "searchPendingCommissions");


    //If query doesn't find a corresponding override line item, it must be created
    if (responseBody["data"]["searchPendingCommissions"]["items"].length == 0) {
      //Create copy of current object, but as an override
      let newOverrideLineItemObject: any = objectInput;
      //Remove ID for create mutation
      delete newOverrideLineItemObject["id"];
      newOverrideLineItemObject["paidRepID"] = paidRepID;
      newOverrideLineItemObject["commissionType"] = "Overrides";
      newOverrideLineItemObject["commissionRate"] = overrideCommissionRate;
      newOverrideLineItemObject["commissionNet"] = overrideCommissionRate * newOverrideLineItemObject["basis"] * .01;
      await getQueryResponse(`mutation MyMutation {
          createPendingCommission(input: ${confirmGraphQLUpdate(newOverrideLineItemObject)}){
              id
          }
        }
        
        `, "createPendingCommission");
    }


    //Check if pendingCommission for each split item exists; whatever doesn't, create it 



  }

  /* responseBody = await getQueryResponse(`query MyQuery {
    getAdvisorSplit(id: "${objectInput["repOnTradeID"]}") {
      repRateOne
      repRateTwo
      repRateThree
      individualRepOneID
      individualRepTwoID
      individualRepThreeID

    }
  }
  
  `);

  console.log("Split: ", responseBody);
  if (responseBody["data"]["getAdvisorSplit"] != null) {
    const originalBasisValue = objectInput["basis"];

    responseBody = await getQueryResponse(`
          
      query MyQuery {
        searchPendingCommissions(filter: {externalAccount: {eq: "${objectInput["externalAccount"]}"}, paidRepID: {eq: "${objectInput["paidRepID"]}"}, repOnTradeID: {eq: "${objectInput["repOnTradeID"]}"}}) {
         items {
          id
          commissionNet
          _version
        }
      }
    }
      `);

       if(responseBody["data"]["searchPendingCommissions"]["items"].length == 0)





}
 */


  //Re-insert original id for updating the trade commission line item
  objectInput["id"] = objectInputId;
  objectInput["commissionRate"] = commissionRate;
  objectInput["commissionNet"] = commissionRate * objectInput["basis"] * .01;
  objectInput["commissionType"] = "Trades";
  objectInput["paidRepID"] = originalPaidRepId;

  //Update with new override rate
  const response = await getQueryResponse(`mutation MyMutation {
    updatePendingCommission(input: ${confirmGraphQLUpdate(objectInput)}){
        id
        _version
    }
  } 
`, "updatePendingCommission");
  if (!response.hasOwnProperty("errors")) {
    return new HttpReturn(200, "Request is complete").toJson();
  }
  else {
    return new HttpReturn(500, "Retry").toJson();
  }

}




export async function getAdvisorPayoutGrids(repId: string): Promise<any> {
  return getQueryResponse(`
    query MyQuery {
      searchPayoutGrids(limit: 1000, filter: {advisorID: {eq: "${repId}"}}) {
        items {
          rate
          productCategoryID
        }
      }
    }
            `, "searchPayoutGrids");
}

function confirmGraphQLUpdate(objectInput: any): any {

  for (let key in objectInput) {
    // Check if the value of the key is an empty string
    if (objectInput[key] === "") {
      // If the value is empty string, delete the key from the object
      delete objectInput[key];
    }
  }



  // Convert object to custom JSON format
  let jsonOutput = "{" + Object.entries(objectInput).map(([key, value]) => {
    // Convert keys to strings without quotes
    let formattedKey = key.toString();

    // Convert values to strings with quotes only if not empty
    let formattedValue = JSON.stringify(value);
    return `${formattedKey}:${formattedValue}`;
  }).join(",") + "}";

  return jsonOutput;




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



