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
/INCLUDE QRPGLESRC,YAJL_H


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
   Index = %Lookup('id' :InputParmDS.SeperatedKeysDS(*).Field);

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
  ID INT(10);
  Name1 CHAR(30);
  Name2 CHAR(30);
 END-DS;

 DCL-S FirstRun IND INZ(*ON);
 DCL-S ArrayItem IND INZ(*OFF);
 DCL-S YajlError VARCHAR(500) INZ;
 DCL-S CustomerID INT(10) INZ;
 //------------------------------------------------------------------------

 If ( pIndex > 0 );
   CustomerID = %Int(pInputParmDS.SeperatedKeysDS(pIndex).ExtractedValue);
 EndIf;

 yajl_BeginObj();

 Exec SQL DECLARE c_customer_reader CURSOR FOR
           SELECT customers.cust_id, customers.name1, customers.name2
             FROM customers
            WHERE customers.cust_id = CASE WHEN :CustomerID = 0 THEN customers.cust_id
                                           ELSE :CustomerID END
            ORDER BY customers.cust_id LIMIT 10;
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
     yajl_BeginArray('customers');
     ArrayItem = *ON;
   EndIf;

   yajl_BeginObj();
   yajl_AddNum('customerID' :%Char(CustomerDS.ID));
   yajl_AddChar('customerName1' :%TrimR(CustomerDS.Name1));
   yajl_AddChar('customerName2' :%TrimR(CustomerDS.Name2));
   yajl_EndObj();

 EndDo;

 If ArrayItem;
   yajl_EndArray();
 EndIf;

 yajl_EndObj();

 Return;

END-PROC;
