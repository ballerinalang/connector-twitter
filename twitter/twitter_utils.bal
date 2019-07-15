//
// Copyright (c) 2018, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
//

import ballerina/crypto;
import ballerina/encoding;
import ballerina/http;
import ballerina/io;
import ballerina/system;
import ballerina/time;
import ballerina/internal;

string timeStamp = "";
string nonceString = "";

function constructOAuthParams(string consumerKey, string accessToken) returns string {
    nonceString = system:uuid();
    time:Time time = time:currentTime();
    int currentTimeMills = time.time;
    timeStamp = io:sprintf("%s", currentTimeMills / 1000);
    string paramStr = "oauth_consumer_key=" + consumerKey + "&oauth_nonce=" + nonceString +
        "&oauth_signature_method=HMAC-SHA1&oauth_timestamp=" + timeStamp + "&oauth_token=" + accessToken
        + "&oauth_version=1.0&";
    return paramStr;
}

function constructRequestHeaders(http:Request request, string httpMethod, string serviceEP, string consumerKey,
        string consumerSecret, string accessToken, string accessTokenSecret, string paramStr) returns error? {
    string serviceEndpoint = "https://api.twitter.com" + serviceEP;
    string paramString = paramStr.substring(0, paramStr.length() - 1);
    string encodedServiceEPValue = check http:encode(serviceEndpoint, "UTF-8");
    string encodedParamStrValue = check http:encode(paramString, "UTF-8");
    string encodedConsumerSecretValue = check http:encode(consumerSecret, "UTF-8");
    string encodedAccessTokenSecretValue = check http:encode(accessTokenSecret, "UTF-8");

    string baseString = httpMethod + "&" + encodedServiceEPValue + "&" + encodedParamStrValue;
    byte[] baseStringByte = internal:toByteArray(baseString, "UTF-8");
    string keyStr = encodedConsumerSecretValue + "&" + encodedAccessTokenSecretValue;
    byte[] keyArrByte = internal:toByteArray(keyStr, "UTF-8");
    string signature = encoding:encodeBase64(crypto:hmacSha1(baseStringByte, keyArrByte));

    string encodedSignatureValue = check http:encode(signature, "UTF-8");
    string encodedaccessTokenValue = check http:encode(accessToken, "UTF-8");

    string oauthHeaderString = "OAuth oauth_consumer_key=\"" + consumerKey +
        "\",oauth_signature_method=\"HMAC-SHA1\",oauth_timestamp=\"" + timeStamp +
        "\",oauth_nonce=\"" + nonceString + "\",oauth_version=\"1.0\",oauth_signature=\"" +
        encodedSignatureValue + "\",oauth_token=\"" + encodedaccessTokenValue + "\"";
    request.setHeader("Authorization", internal:unescape(oauthHeaderString));
    return ();
}

function setResponseError(json jsonResponse) returns error {
    json|error errors = check jsonResponse.errors;
    error err;
    if (errors is json[]) {
        err = error(TWITTER_ERROR_CODE, message = errors[0].message.toString());
    } else if (errors is error) {
        err = errors;
    } else {
        err = error(TWITTER_ERROR_CODE);
    }
    return err;
}
