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


/INCLUDE QRPGLECPY,H_SPECS
CTL-OPT MAIN(Main) BNDDIR('CGISRVR1' :'WEDYAJL/YAJL');

DCL-PR Main EXTPGM('CGITSTRG') END-PR;

/INCLUDE QRPGLEH,CGISRVR1_H
/INCLUDE WEDYAJL/QRPGLESRC,YAJL_H


//#########################################################################
DCL-PROC Main;

 DCL-DS InputParmDS LIKEDS(ParmInputDS_T) INZ;

 DCL-S Index INT(10) INZ;
 DCL-S YajlError VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 /INCLUDE QRPGLECPY,SQLOPTIONS

 *INLR = *ON;

 InputParmDS = getHTTPInput();

 If ( InputParmDS.Methode = 'GET' );
   Index = %Lookup('knr' :InputParmDS.SeperatedKeysDS(*).Field);

   yajl_GenOpen(*ON);
   generateJSONStream(Index :InputParmDS);
   yajl_WriteStdOut(200 :YajlError);
   yajl_GenClose();

 EndIf;

 Return;

END-PROC;


//#########################################################################
DCL-PROC generateJSONStream;
 DCL-PI *N;
  pIndex INT(10) CONST;
  pInputParmDS LIKEDS(ParmInputDS_T) CONST;
 END-PI;

 DCL-DS CustomerDS QUALIFIED INZ;
  Number CHAR(10);
  Name1 CHAR(30);
  Name2 CHAR(30);
  Name3 CHAR(30);
  Street CHAR(30);
  ZiP CHAR(10);
  City CHAR(30);
  Country CHAR(2);
 END-DS;

 DCL-S FirstRun IND INZ(*ON);
 DCL-S ArrayItem IND INZ(*OFF);
 DCL-S YajlError VARCHAR(500) INZ;
 DCL-S CustomerNumber CHAR(10) INZ;
 //------------------------------------------------------------------------

 If ( pIndex > 0 );
   CustomerNumber = pInputParmDS.SeperatedKeysDS(pIndex).ExtractedValue;
 EndIf;

 yajl_BeginObj();

 Exec SQL DECLARE c_customer_reader CURSOR FOR
           SELECT k00.k00knr, k00.k00na1, k00.k00na2, k00.k00na3,
                  k00.k00str, k00.k00zip, k00.k00cit, k00.k00lnd
             FROM ccdaten.k00
            WHERE k00.k00knr = CASE WHEN :CustomerNumber = '' THEN k00.k00knr
                                    ELSE :CustomerNumber END
              AND k00.k00del = '' AND k00.k00spl = ''
            ORDER BY k00.k00div, k00.k00knr LIMIT 10;
 Exec SQL OPEN c_customer_reader;

 DoW ( 1 = 1 );
   Exec SQL FETCH NEXT FROM c_customer_reader INTO :CustomerDS;
   If ( SQLCode <> 0 );
     If FirstRun;
       Exec SQL GET DIAGNOSTICS CONDITION 1 :YajlError = MESSAGE_TEXT;
       yajl_AddBool('success' :'0');
       yajl_AddChar('errmsg' :%TrimR(YajlError));
     EndIf;
     Exec SQL CLOSE c_customer_reader;
     Leave;
   EndIf;

   If FirstRun;
     FirstRun= *OFF;
     yajl_AddBool('success' :'1');
     yajl_BeginArray('items');
     ArrayItem = *ON;
   EndIf;

   yajl_BeginObj();
   yajl_AddChar('customerNumber' :%TrimR(CustomerDS.Number));
   yajl_AddChar('customerName1' :%TrimR(CustomerDS.Name1));
   yajl_AddChar('customerName2' :%TrimR(CustomerDS.Name2));
   yajl_AddChar('customerName3' :%TrimR(CustomerDS.Name3));
   yajl_AddChar('street' :%TrimR(CustomerDS.Street));
   yajl_AddChar('zip' :%TrimR(CustomerDS.ZiP));
   yajl_AddChar('city' :%TrimR(CustomerDS.City));
   yajl_AddChar('country' :%TrimR(CustomerDS.Country));
   yajl_EndObj();

 EndDo;

 If ArrayItem;
   yajl_EndArray();
 EndIf;

 yajl_EndObj();

 Return;

END-PROC;
