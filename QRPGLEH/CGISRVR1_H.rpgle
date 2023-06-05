**FREE
//- Copyright (c) 2021-2023 Christian Brunner
//-
//- Permission is hereby granted, free of charge, to any person obtaining a copy
//- of this software and associated documentation files (the "Software"), to deal
//- in the Software without restriction, including without limitation the rights
//- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//- copies of the Software, and to permit persons to whom the Software is
//- furnished to do so, subject to the following conditions:

//- The above copyright notice and this permission notice shall be included in all
//- copies or substantial portions of the Software.

//- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//- SOFTWARE.

/IF DEFINED (CGISRVR1_H)
/EOF
/ENDIF

/DEFINE CGISRVR1_H


// Get/Retrieve inputs from http-server
DCL-PR getHTTPInput LIKEDS(InputParmDS_T) END-PR;

// Write data to http-server
DCL-PR writeHTTPOut;
 Data POINTER VALUE;
 DataLenth INT(10) CONST;
 Type UNS(3) CONST OPTIONS(*NOPASS);
END-PR;

// Get http-header depending on input type
DCL-PR getHTTPHeader CHAR(128);
 Type UNS(3) CONST;
END-PR;

// Get retrieved value by name
DCL-PR getValueByName CHAR(128);
 FieldName CHAR(128) CONST;
 InputParmDS LIKEDS(InputParmDS_T) CONST;
END-PR;

// Translate data between different codepages
DCL-PR translateData;
 Data POINTER CONST;
 DataLength INT(10) CONST;
 FromCCSID INT(10) CONST;
 ToCCSID INT(10) CONST;
END-PR;

// Encode string to base64
DCL-PR encodeBase64 CHAR(32000);
 IncomingString POINTER CONST;
 IncomingLength INT(10) CONST;
END-PR;

// Decode base64 encoded string
DCL-PR decodeBase64 CHAR(32000);
 IncomingPointer POINTER CONST;
END-PR;

// get basic server informations
DCL-PR getServerInformations LIKEDS(ServerInformationDS_T) END-PR;

// Send message to joblog
DCL-PR sendMessageToJoblog;
 Message CHAR(256) CONST;
END-PR;


// Constants to get http-header by type
DCL-C HTTP_JSON_OK 0;
DCL-C HTTP_PDF_OK 1;
DCL-C HTTP_OK 2;
DCL-C HTTP_BAD_REQUEST 3;
DCL-C HTTP_UNAUTHORIZED 4;
DCL-C HTTP_FORBIDDEN 5;
DCL-C HTTP_NOT_FOUND 6;

// HTTP_Codes
DCL-C HTTP_CODE_OK 200;
DCL-C HTTP_CODE_CREATED 201;
DCL-C HTTP_CODE_ACCEPTED 202;
DCL-C HTTP_CODE_NO_CONTENT 204;
DCL-C HTTP_CODE_BAD_REQUEST 400;
DCL-C HTTP_CODE_UNAUTHORIZED 401;
DCL-C HTTP_CODE_METHOD_NOT_ALLOWED 405;
DCL-C HTTP_CODE_UNSUPPORTED_MEDIA_TYPE 415;
DCL-C HTTP_CODE_INTERNAL_SERVER_ERROR 500;
DCL-C HTTP_CODE_NOT_IMPLEMENTED 501;
DCL-C HTTP_CODE_SERVICE_UNAVAILABLE 503;
DCL-C HTTP_CODE_NOT_EXTENDED 510;

// Constant fields to translate between codepages
DCL-C UTF8 1208;
DCL-C PCASCII 1252;
DCL-C LOCAL_CCSID 0;

// Template DS to hold data from http-server
DCL-DS InputParmDS_T QUALIFIED TEMPLATE;
 Data POINTER;
 DataLength INT(10);
 Method CHAR(20);
 ContentType CHAR(128);
 AuthType CHAR(128);
 RemoteUser CHAR(128);
 RemoteIP CHAR(15);
 RemoteHost CHAR(128);
 UserAgent CHAR(128);
 PathInfo CHAR(128);
 QueryString CHAR(128);
 SeperatedKeysDS LIKEDS(SeperatedKeysDS_T) DIM(MAX_SEP_KEYS);
END-DS;

// Seperation workfields
DCL-C MAX_SEP_KEYS 20;
DCL-DS SeperatedKeysDS_T QUALIFIED TEMPLATE;
 Field CHAR(128);
 ExtractedValue CHAR(128);
END-DS;

// Server informations
DCL-DS ServerInformationDS_T QUALIFIED TEMPLATE;
 ServerName VARCHAR(128);
 ServerRelease CHAR(10);
END-DS;


/IF DEFINED (COMPILE_CGISRVR1)
/INCLUDE QRPGLECPY,ERRORDS_H
/INCLUDE QRPGLECPY,BOOLIC
/INCLUDE QRPGLECPY,BASE64
/INCLUDE QRPGLECPY,IFS_H
DCL-C CRLF x'0D25';
/ENDIF
