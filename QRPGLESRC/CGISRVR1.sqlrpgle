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
// CRTSRVPGM SRVPGM(WEDSOCKET/CGISRVR1) MODULE(WEDSOCKET/CGISRVR1) EXPORT(*ALL)
//  SRCFILE(WEDSOCKET/QSRVSRC) USRPRF(*OWNER) REPLACE(*YES) AUT(*USE) STGMDL(*SNGLVL)


/DEFINE CTL_SRVPGM
/INCLUDE QRPGLECPY,H_SPECS
CTL-OPT BNDDIR('QZHBCGI');


/DEFINE COMPILE_CGISRVR1
/INCLUDE QRPGLEH,CGISRVR1_H


//#########################################################################
DCL-PROC getHTTPInput EXPORT;
 DCL-PI *N LIKEDS(ParmInputDS_T) END-PI;

 /INCLUDE QRPGLECPY,GETENV
 /INCLUDE QRPGLECPY,QTMHRDSTIN

 DCL-DS ErrorDS LIKEDS(ErrorDS_T) INZ;
 DCL-DS ParmInputDS LIKEDS(ParmInputDS_T) INZ;

 DCL-S Receiver POINTER;
 DCL-S InputMethode CHAR(20) INZ;
 DCL-S ParmType UNS(3) INZ;
 DCL-S ContentLength INT(10) INZ;
 DCL-S BytesAvailable INT(10) INZ;
 DCL-S ContentType CHAR(20) INZ;
 DCL-S AuthType CHAR(128) INZ;
 DCL-S QueryString CHAR(128) INZ;
 //------------------------------------------------------------------------

 /INCLUDE QRPGLECPY,SQLOPTIONS

 Receiver = getEnvironmentVariable('REQUEST_METHOD' :ErrorDS);
 If ( Receiver <> *NULL );
   InputMethode = %Str(Receiver);
 EndIf;

 Receiver = getEnvironmentVariable('CONTENT_LENGTH' :ErrorDS);
 If ( Receiver <> *NULL );
   ContentLength = %Int(%Str(Receiver));
 EndIf;

 Receiver = getEnvironmentVariable('CONTENT_TYPE' :ErrorDS);
 If ( Receiver <> *NULL );
   ContentType = %Str(Receiver);
 EndIf;

 Exec SQL SET :ContentType = LOWER(:ContentType);

 Monitor;
   QueryString = %Str(getEnvironmentVariable('QUERY_STRING' :ErrorDS));
   On-Error;
     Clear QueryString;
 EndMon;

 Select;
   When ( InputMethode = 'GET' );
     ParmInputDS.Methode = InputMethode;
     If ( QueryString <> '' );
       ParmInputDS.SeperatedKeysDS = parseQueryString(QueryString);
     EndIf;

   When ( InputMethode = 'POST' );
     Select;
       When ( %Scan('text/json' :ContentType) > 0 ) Or
            ( %Scan('application/json' :ContentType) > 0 ); // json stream
         ParmInputDS.Data = %Alloc(ContentLength);
         readStdIn(ParmInputDS.Data :ContentLength :BytesAvailable :ErrorDS);
         ParmInputDS.DataLength = BytesAvailable;
         ParmInputDS.ContentType = ContentType;
         ParmInputDS.Methode = InputMethode;
         If ( QueryString <> '' );
           ParmInputDS.SeperatedKeysDS = parseQueryString(QueryString);
         EndIf;

       When ( %Scan('text/plain' :ContentType) > 0 ); // plain text
         ParmInputDS.Data = %Alloc(ContentLength);
         readStdIn(ParmInputDS.Data :ContentLength :BytesAvailable :ErrorDS);
         ParmInputDS.DataLength = BytesAvailable;
         ParmInputDS.ContentType = ContentType;
         ParmInputDS.Methode = InputMethode;
         If ( QueryString <> '' );
           ParmInputDS.SeperatedKeysDS = parseQueryString(QueryString);
         EndIf;

     EndSl;



 EndSl;

 Return ParmInputDS;

END-PROC;


//#########################################################################
DCL-PROC writeHTTPOut EXPORT;
 DCL-PI *N;
  pData POINTER VALUE;
  pDataLength INT(10) CONST;
 END-PI;

 /INCLUDE QRPGLECPY,QTMHWRSTOU

 DCL-DS ErrorDS LIKEDS(ErrorDS_T) INZ;

 DCL-S HTTPHeader CHAR(128) INZ;
 //------------------------------------------------------------------------

 HTTPHeader = getHTTPHeader();
 writeStdOut(%Addr(HTTPHeader) :%Len(%TrimR(HTTPHeader)) :ErrorDS);

 writeStdOut(pData :pDataLength :ErrorDS);

END-PROC;


//#########################################################################
DCL-PROC getHTTPHeader EXPORT;
 DCL-PI *N CHAR(128) END-PI;

 DCL-S HTTPHeader CHAR(128) INZ;
 //------------------------------------------------------------------------

 HTTPHeader = 'status: 200 OK' + CRLF +
              'Content-type: application/json; charset=utf-8' + CRLF + CRLF;
 Return HTTPHeader;

END-PROC;


//#########################################################################
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
            ORDER BY splitter.ordinal_position;
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
            ORDER BY seperator.ordinal_position;
 Exec SQL OPEN c_seperate_reader;
 Exec SQL FETCH NEXT FROM c_seperate_reader FOR 2 ROWS INTO :ResultDS;
 Exec SQL CLOSE c_seperate_reader;

 SeperatedKeysDS.Field = ResultDS(1).Element;
 SeperatedKeysDS.ExtractedValue = ResultDS(2).Element;

 Return SeperatedKeysDS;

END-PROC;
