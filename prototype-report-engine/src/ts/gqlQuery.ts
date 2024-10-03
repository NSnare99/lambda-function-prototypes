const GRAPHQL_ENDPOINT = process.env.API_PTOLEMY_GRAPHQLAPIENDPOINTOUTPUT;
const GRAPHQL_API_KEY = process.env.API_PTOLEMY_GRAPHQLAPIKEYOUTPUT;

import {
    default as fetch, Request,
    // @ts-ignore
} from "node-fetch";

export async function getQueryResponse(query: string): Promise<any> {




    const options = {
        method: 'POST',
        headers: {
            'x-api-key': GRAPHQL_API_KEY,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ query })
    };




    const graphQLQueryRequest = new Request(GRAPHQL_ENDPOINT as any, options as any);

    let statusCode = 200;
    let graphQLResponseBody: any;
    let response: any;

    try {
        response = await fetch(graphQLQueryRequest);
        graphQLResponseBody = await response.json();
        if (graphQLResponseBody.errors) statusCode = 400;
    } catch (error: any) {
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


    return JSON.parse(graphQLResponseBody);

}