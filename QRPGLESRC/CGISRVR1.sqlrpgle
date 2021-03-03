**FREE
//- Copyright (c) 2021 Christian Brunner
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

// Create servieprogram with folloing command:
// CRTSRVPGM SRVPGM(CGISRVR1) MODULE(CGISRVR1) EXPORT(*ALL)
//  SRCFILE(QSRVSRC) USRPRF(*OWNER) REPLACE(*YES) AUT(*USE) STGMDL(*SNGLVL)


/DEFINE CTL_SRVPGM
/INCLUDE QRPGLECPY,H_SPECS
CTL-OPT BNDDIR('QZHBCGI');


/DEFINE COMPILE_CGISRVR1
/INCLUDE QRPGLEH,CGISRVR1_H


//#########################################################################
// get environment variables and handle incomming data
DCL-PROC getHTTPInput EXPORT;
 DCL-PI *N LIKEDS(InputParmDS_T) END-PI;

 /INCLUDE QRPGLECPY,GETENV
 /INCLUDE QRPGLECPY,QTMHRDSTIN

 DCL-DS ErrorDS LIKEDS(ErrorDS_T) INZ;
 DCL-DS InputParmDS LIKEDS(InputParmDS_T) INZ;

 DCL-S Receiver POINTER;
 DCL-S ContentType CHAR(20) INZ;
 DCL-S ContentLength INT(10) INZ;
 DCL-S BytesAvailable INT(10) INZ;
 DCL-S QueryString CHAR(128) INZ;
 //------------------------------------------------------------------------

 /INCLUDE QRPGLECPY,SQLOPTIONS

 Receiver = getEnvironmentVariable('REQUEST_METHOD' :ErrorDS);
 If ( Receiver <> *NULL );
   InputParmDS.Method = %Str(Receiver);
 EndIf;

 Receiver = getEnvironmentVariable('CONTENT_LENGTH' :ErrorDS);
 If ( Receiver <> *NULL );
   ContentLength = %Int(%Str(Receiver));
 EndIf;

 Receiver = getEnvironmentVariable('CONTENT_TYPE' :ErrorDS);
 If ( Receiver <> *NULL );
   ContentType = %Str(Receiver);
   Exec SQL SET :ContentType = LOWER(:ContentType);
   InputParmDS.ContentType = ContentType;
 EndIf;

 Monitor;
   QueryString = %Str(getEnvironmentVariable('QUERY_STRING' :ErrorDS));
   On-Error;
     Clear QueryString;
 EndMon;
 
 Receiver = getEnvironmentVariable('AUTH_TYPE' :ErrorDS);
 If ( Receiver <> *NULL );
   InputParmDS.AuthType = %Str(Receiver);
 EndIf;

 Receiver = getEnvironmentVariable('REMOTE_USER' :ErrorDS);
 If ( Receiver <> *NULL );
   InputParmDS.RemoteUser = %Str(Receiver);
 EndIf;

 Receiver = getEnvironmentVariable('REMOTE_ADDR' :ErrorDS);
 If ( Receiver <> *NULL );
   InputParmDS.RemoteIP = %Str(Receiver);
 EndIf;

 Receiver = getEnvironmentVariable('REMOTE_HOST' :ErrorDS);
 If ( Receiver <> *NULL );
   InputParmDS.RemoteHost = %Str(Receiver);
 EndIf;

 Receiver = getEnvironmentVariable('HTTP_USER_AGENT' :ErrorDS);
 If ( Receiver <> *NULL );
   InputParmDS.UserAgent = %Str(Receiver);
 EndIf;

 Select;
   When ( InputParmDS.Method = 'GET' );
     If ( QueryString <> '' );
       InputParmDS.SeperatedKeysDS = parseQueryString(QueryString);
     EndIf;

   When ( InputParmDS.Method = 'POST' ) Or ( InputParmDS.Method = 'PUT' );
     Select;
       When ( %Scan('text/json' :InputParmDS.ContentType) > 0 ) Or
            ( %Scan('application/json' :InputParmDS.ContentType) > 0 ); // json stream
         InputParmDS.Data = %Alloc(ContentLength);
         readStdIn(InputParmDS.Data :ContentLength :BytesAvailable :ErrorDS);
         InputParmDS.DataLength = BytesAvailable;
         If ( QueryString <> '' );
           InputParmDS.SeperatedKeysDS = parseQueryString(QueryString);
         EndIf;

       When ( %Scan('text/plain' :InputParmDS.ContentType) > 0 ); // plain text
         InputParmDS.Data = %Alloc(ContentLength);
         readStdIn(InputParmDS.Data :ContentLength :BytesAvailable :ErrorDS);
         InputParmDS.DataLength = BytesAvailable;
         If ( QueryString <> '' );
           InputParmDS.SeperatedKeysDS = parseQueryString(QueryString);
         EndIf;

     EndSl;
   When ( InputParmDS.Method = 'DELETE' );
     If ( QueryString <> '' );
       InputParmDS.SeperatedKeysDS = parseQueryString(QueryString);
     EndIf;

 EndSl;

 Return InputParmDS;

END-PROC;


//#########################################################################
DCL-PROC writeHTTPOut EXPORT;
 DCL-PI *N;
  pData POINTER VALUE;
  pDataLength INT(10) CONST;
  pType UNS(3) CONST;
 END-PI;

 /INCLUDE QRPGLECPY,QTMHWRSTOU

 DCL-DS ErrorDS LIKEDS(ErrorDS_T) INZ;

 DCL-S HTTPHeader CHAR(128) INZ;
 //------------------------------------------------------------------------

 HTTPHeader = getHTTPHeader(pType);
 writeStdOut(%Addr(HTTPHeader) :%Len(%TrimR(HTTPHeader)) :ErrorDS);

 If ( pData <> *NULL );
   writeStdOut(pData :pDataLength :ErrorDS);
 EndIf;

END-PROC;


//#########################################################################
DCL-PROC getHTTPHeader EXPORT;
 DCL-PI *N CHAR(128);
  pType UNS(3) CONST;
 END-PI;

 DCL-S HTTPHeader CHAR(128) INZ;
 //------------------------------------------------------------------------

 Select;
   When ( pType = HTTP_JSON_OK );
     HTTPHeader = 'status: 200 OK' + CRLF +
                   'content-type: application/json; charset=utf-8' + CRLF + CRLF;
   When ( pType = HTTP_OK );
     HTTPHeader = 'status: 200 OK' + CRLF +
                   'content-type: text/plain' + CRLF + CRLF;
   When ( pType = HTTP_BAD_REQUEST );
     HTTPHeader = 'status: 400' + CRLF +
                   'content-type: text/plain' + CRLF + CRLF;
   When ( pType = HTTP_UNAUTHORIZED );
     HTTPHeader = 'status: 401' + CRLF +
                   'content-type: text/plain' + CRLF + CRLF;
   When ( pType = HTTP_FORBIDDEN );
     HTTPHeader = 'status: 403' + CRLF +
                   'content-type: text/plain' + CRLF + CRLF;
   When ( pType = HTTP_NOT_FOUND );
     HTTPHeader = 'status: 404' + CRLF +
                   'content-type: text/plain' + CRLF + CRLF;
 EndSl;

 Return HTTPHeader;

END-PROC;

//#########################################################################
DCL-PROC translateData EXPORT;
 DCL-PI *N;
  pData POINTER CONST;
  pDataLength INT(10) CONST;
  pFromCCSID INT(10) CONST;
  pToCCSID INT(10) CONST;
 END-PI;

 /INCLUDE QRPGLECPY,ICONV
 //------------------------------------------------------------------------

 iConvDS.iConvHandler = pData;
 iConvDS.Length = pDataLength;
 FromDS.FromCCSID = pFromCCSID;
 ToDS.ToCCSID = pToCCSID;
 ToASCII = iConv_Open(ToDS :FromDS);
 If ( ToASCII.ICORV_A >= 0 );
   iConv(ToASCII :iConvDS.iConvHandler :iConvDS.Length :iConvDS.iConvHandler :iConvDS.Length);
 EndIf;
 iConv_Close(ToASCII);

END-PROC;


//#########################################################################
// split incomming querystring (id=1&name=5 -> id=1 and name=5 etc)
DCL-PROC parseQueryString;
 DCL-PI *N LIKEDS(SeperatedKeysDS_T) DIM(MAX_SEP_KEYS);
  pQueryString CHAR(128) CONST;
  pSeperator CHAR(1) CONST OPTIONS(*NOPASS);
 END-PI;

 DCL-DS SeperatedKeysDS LIKEDS(SeperatedKeysDS_T) DIM(MAX_SEP_KEYS) INZ;
 DCL-DS ResultDS QUALIFIED DIM(MAX_SEP_KEYS) INZ;
  Element CHAR(128);
 END-DS;

 DCL-S Index INT(5) INZ;
 DCL-S RowsFetched INT(5) INZ;
 DCL-S Seperator CHAR(1) INZ;
 //------------------------------------------------------------------------

 If ( %Parms() = 1 );
   Seperator = '&';
 Else;
   Seperator = pSeperator;
 EndIf;

 Exec SQL DECLARE c_split_reader CURSOR FOR
           SELECT CAST(splitter.element AS VARCHAR(128))
             FROM TABLE(systools.split(:pQueryString, :Seperator)) AS splitter
            ORDER BY splitter.ordinal_position
            LIMIT :MAX_SEP_KEYS;
 Exec SQL OPEN c_split_reader;
 Exec SQL FETCH NEXT FROM c_split_reader FOR :MAX_SEP_KEYS ROWS INTO :ResultDS;
 RowsFetched = SQLEr3;
 Exec SQL CLOSE c_split_reader;

 For Index = 1 To RowsFetched;
   SeperatedKeysDS(Index) = seperateValues(ResultDS(Index) :'=');
 EndFor;

 Return SeperatedKeysDS;

END-PROC;

//#########################################################################
// split single query (id=1 -> id and 1 etc)
DCL-PROC seperateValues;
 DCL-PI *N LIKEDS(SeperatedKeysDS_T);
  pValues CHAR(128) CONST;
  pSeperator CHAR(1) CONST OPTIONS(*NOPASS);
 END-PI;

 DCL-DS SeperatedKeysDS LIKEDS(SeperatedKeysDS_T) INZ;
 DCL-DS ResultDS QUALIFIED DIM(2) INZ;
  Element CHAR(128);
 END-DS;

 DCL-S Seperator CHAR(1) INZ;
 //------------------------------------------------------------------------

 If ( %Parms() = 1 );
   Seperator = '=';
 Else;
   Seperator = pSeperator;
 EndIf;

 Exec SQL DECLARE c_seperate_reader CURSOR FOR
           SELECT CAST(seperator.element AS VARCHAR(128))
             FROM TABLE(systools.split(:pValues, :Seperator)) AS seperator
            ORDER BY seperator.ordinal_position
            LIMIT 2;
 Exec SQL OPEN c_seperate_reader;
 Exec SQL FETCH NEXT FROM c_seperate_reader FOR 2 ROWS INTO :ResultDS;
 Exec SQL CLOSE c_seperate_reader;

 SeperatedKeysDS.Field = ResultDS(1).Element;
 SeperatedKeysDS.ExtractedValue = ResultDS(2).Element;

 Return SeperatedKeysDS;

END-PROC;
