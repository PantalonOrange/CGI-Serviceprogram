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
CTL-OPT MAIN(Main) BNDDIR('CGISRVR1' :'YAJL');

DCL-PR Main EXTPGM('CGITSTRG') END-PR;

/INCLUDE QRPGLEH,CGISRVR1_H
/INCLUDE QRPGLESRC,YAJL_H
/INCLUDE QRPGLECPY,BOOLIC

DCL-DS CustomerDS_T QUALIFIED TEMPLATE;
 ID INT(10);
 Name1 CHAR(30);
 Name2 CHAR(30);
 LastChanged VARCHAR(26);
 LastUser VARCHAR(255);
END-DS;

//#########################################################################
DCL-PROC Main;

 DCL-DS InputParmDS LIKEDS(InputParmDS_T) INZ;
 DCL-DS CustomerDS LIKEDS(CustomerDS_T) INZ;

 DCL-S Index INT(10) INZ;
 DCL-S YajlError VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 /INCLUDE QRPGLECPY,SQLOPTIONS

 *INLR = TRUE;

 InputParmDS = getHTTPInput();

 If ( InputParmDS.Method = 'GET' );
   // submit customer-data to requester
   yajl_GenOpen(TRUE);
   generateJSONCustomerStream(InputParmDS);
   yajl_WriteStdOut(200 :YajlError);
   yajl_GenClose();

 ElseIf ( InputParmDS.Method = 'POST' );
   // add new customer
   parseIncomingJSONStream(InputParmDS :InputParmDS.Method);

 ElseIf ( InputParmDS.Method = 'PUT' );
   // change selected customer
   parseIncomingJSONStream(InputParmDS :InputParmDS.Method);

 ElseIf ( InputParmDS.Method = 'DELETE' );
   // delete selected customer
   Index = %Lookup('id' :InputParmDS.SeperatedKeysDS(*).Field);
   If ( Index > 0 );
     deleteCustomer(Index :InputParmDS);
   EndIf;

 EndIf;

 Return;

END-PROC;


//#########################################################################
// parse selected customer to json and return it
//  if id = 0 all customers will be returned
DCL-PROC generateJSONCustomerStream;
 DCL-PI *N;
  pInputParmDS LIKEDS(InputParmDS_T) CONST;
 END-PI;

 DCL-DS CustomerDS LIKEDS(CustomerDS_T) INZ;

 DCL-S FirstRun IND INZ(TRUE);
 DCL-S ArrayItem IND INZ(FALSE);
 DCL-S YajlError VARCHAR(500) INZ;
 DCL-S CustomerID INT(10) INZ;
 //------------------------------------------------------------------------

 Monitor;
   CustomerID = %Int(getValueByName('id' :pInputParmDS));
   On-Error;
     Reset CustomerID;
 EndMon;

 yajl_BeginObj();

 Exec SQL DECLARE c_customer_reader CURSOR FOR
           SELECT customers.cust_id, customers.name1, customers.name2,
                  timestamp_iso8601(customers.change_stamp), customers.last_user
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
       yajl_AddChar('errorMessage' :%TrimR(YajlError));
     EndIf;
     Exec SQL CLOSE c_customer_reader;
     Leave;
   EndIf;

   If FirstRun;
     FirstRun= FALSE;
     yajl_AddBool('success' :'1');
     yajl_BeginArray('customers');
     ArrayItem = TRUE;
   EndIf;

   yajl_BeginObj();
   yajl_AddNum('customerID' :%Char(CustomerDS.ID));
   yajl_AddChar('customerName1' :%TrimR(CustomerDS.Name1));
   yajl_AddChar('customerName2' :%TrimR(CustomerDS.Name2));
   yajl_AddCHar('lastChanged' :%TrimR(CustomerDS.LastChanged));
   yajl_AddChar('lastUser' :%TrimR(CustomerDS.LastUser));
   yajl_EndObj();

 EndDo;

 If ArrayItem;
   yajl_EndArray();
 EndIf;

 yajl_EndObj();

 Return;

END-PROC;

//#########################################################################
DCL-PROC parseIncomingJSONStream;
 DCL-PI *N;
  pInputParmDS LIKEDS(InputParmDS_T) CONST;
  pMethod CHAR(10) CONST;
 END-PI;

 DCL-DS CustomerDS LIKEDS(CustomerDS_T) INZ;

 DCL-S Success IND INZ(TRUE);
 DCL-S Index INT(10) INZ;
 DCL-S NodeTree LIKE(yajl_Val) INZ;
 DCL-S CustList LIKE(yajl_Val) INZ;
 DCL-S Val Like(yajl_Val) INZ;
 DCL-S YajlError VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 If ( pInputParmDS.Data <> *NULL );
   translateData(pInputParmDS.Data :pInputParmDS.DataLength :UTF8 :0);
   YajlError = %Str(pInputParmDS.Data);
   NodeTree = yajl_Buf_Load_Tree(pInputParmDS.Data :pInputParmDS.DataLength :YajlError);

   Success = ( NodeTree <> *NULL );

   If Success;
     CustList = yajl_Object_Find(NodeTree :'customers');

     If ( CustList <> *NULL );

       DoW yajl_Array_Loop(CustList :Index :NodeTree);

         Val = yajl_Object_Find(NodeTree :'customerID');
         If ( Val <> *NULL );
           CustomerDS.ID = %Int(yajl_Get_Number(Val));
         EndIf;

         Val = yajl_Object_Find(NodeTree :'customerName1');
         If ( Val <> *NULL );
           CustomerDS.Name1 = yajl_Get_String(Val);
         EndIf;

         Val = yajl_Object_Find(NodeTree :'customerName2');
         If ( Val <> *NULL );
           CustomerDS.Name2 = yajl_Get_String(Val);
         EndIf;

         If ( CustomerDS.Name1 <> '' ) Or ( CustomerDS.Name2 <> '' );
           If ( pMethod = 'POST' );
             insertCustomer(CustomerDS :pInputParmDS.RemoteUser);
           ElseIf ( pMethod = 'PUT' );
             updateCustomer(CustomerDS :pInputParmDS.RemoteUser);
           EndIf;

         Else;
           Success = FALSE;
           YajlError = 'No valid data received.';

         EndIf;

       EndDo;

     Else;
       Success = FALSE;
       YajlError = 'No valid json stream received.';

     EndIf;

     yajl_Tree_Free(NodeTree);

   EndIf;

 Else;
   Success = FALSE;

 EndIf;

 If Not Success;
   writeHTTPOut(%Addr(YajlError) :%Len(%Trim(YajlError)) :HTTP_BAD_REQUEST);
 EndIf;

END-PROC;

//#########################################################################
// insert new customer
DCL-PROC insertCustomer;
 DCL-PI *N;
  pCustomerDS LIKEDS(CustomerDS_T) CONST;
  pLastUser VARCHAR(128) CONST;
 END-PI;

 DCL-S Success IND INZ(TRUE);
 DCL-S NewCustomerID INT(10) INZ;
 DCL-S YajlError VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 Exec SQL SELECT cust_id INTO :NewCustomerID FROM FINAL TABLE
          (
           INSERT INTO customers (name1, name2, last_user)
           VALUES(RTRIM(:pCustomerDS.Name1), RTRIM(:pCustomerDS.Name2), RTRIM(:pLastUser))
          );
 Success = ( SQLCode = 0 );

 yajl_GenOpen(TRUE);
 yajl_BeginObj();
 yajl_AddBool('success' :Success);
 If Success;
   yajl_AddNum('newCustomerID' :%Char(NewCustomerID));
 Else;
   Exec SQL GET DIAGNOSTICS CONDITION 1 :YajlError = MESSAGE_TEXT;
   yajl_AddChar('errorMessage' :%TrimR(%Char(YajlError)));
 EndIf;
 yajl_EndObj();
 yajl_WriteStdOut(200 :YajlError);
 yajl_GenClose();

END-PROC;

//#########################################################################
// update existing customer
DCL-PROC updateCustomer;
 DCL-PI *N;
  pCustomerDS LIKEDS(CustomerDS_T) CONST;
  pLastUser VARCHAR(128) CONST;
 END-PI;

 DCL-S Success IND INZ(TRUE);
 DCL-S YajlError VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 Exec SQL UPDATE customers
             SET customers.name1 = RTRIM(:pCustomerDS.Name1),
                 customers.name2 = RTRIM(:pCustomerDS.Name2),
                 customers.last_user = RTRIM(:pLastUser)
           WHERE customers.cust_id = :pCustomerDS.ID
             AND (RTRIM(customers.name1) <> RTRIM(:pCustomerDS.Name1) OR
                  RTRIM(customers.name2) <> RTRIM(:pCustomerDS.Name2));
 Success = ( SQLCode = 0 );

 yajl_GenOpen(TRUE);
 yajl_BeginObj();
 yajl_AddBool('success' :Success);
 If Not Success;
   Exec SQL GET DIAGNOSTICS CONDITION 1 :YajlError = MESSAGE_TEXT;
   yajl_AddChar('errorMessage' :%TrimR(%Char(YajlError)));
 EndIf;
 yajl_EndObj();
 yajl_WriteStdOut(200 :YajlError);
 yajl_GenClose();

END-PROC;

//#########################################################################
// delete selected customer from table
DCL-PROC deleteCustomer;
 DCL-PI *N;
  pIndex INT(10) CONST;
  pInputParmDS LIKEDS(InputParmDS_T) CONST;
 END-PI;

 DCL-S Success IND INZ(TRUE);
 DCL-S CustomerID INT(10) INZ;
 DCL-S YajlError VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 CustomerID = %Int(pInputParmDS.SeperatedKeysDS(pIndex).ExtractedValue);
 Exec SQL DELETE FROM customers WHERE customers.cust_id = :CustomerID;
 Success = ( SQLCode = 0 );

 yajl_GenOpen(TRUE);
 yajl_BeginObj();
 yajl_AddBool('success' :Success);
 If Not Success;
   Exec SQL GET DIAGNOSTICS CONDITION 1 :YajlError = MESSAGE_TEXT;
   yajl_AddChar('errorMessage' :%TrimR(%Char(YajlError)));
 EndIf;
 yajl_EndObj();
 yajl_WriteStdOut(200 :YajlError);
 yajl_GenClose();

END-PROC;
