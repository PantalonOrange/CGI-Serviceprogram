**FREE
//- Copyright (c) 2023 Christian Brunner
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


/INCLUDE QRPGLEH,IMPAUNRG_H


//#########################################################################
DCL-PROC Main;

  DCL-DS InputParmDS LIKEDS(InputParmDS_T) INZ;

  DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

  /INCLUDE QRPGLECPY,SQLOPTIONS

  *INLR = TRUE;

  InputParmDS = getHTTPInput();

  If ( InputParmDS.Method = 'POST' );
    createTempTable();
    handleIncommingPostData(InputParmDS);

  Else;
    // Unsupported method
    yajl_GenOpen(TRUE);
    yajl_BeginObj();

    ErrorMessage = %TrimR(InputParmDS.Method) + ' not allowed. Operation canceled';
    sendMessageToJoblog(ErrorMessage);

    yajl_AddBool('success' :FALSE);
    yajl_AddNum('httpStatus' :%Char(HTTP_CODE_METHOD_NOT_ALLOWED));
    yajl_BeginArray('errorDetails');
    yajl_AddChar('requestedMethod' :%TrimR(InputParmDS.Method));
    yajl_AddChar('errorMessage' :%TrimR(ErrorMessage));
    yajl_EndArray();
    yajl_EndObj();
    yajl_WriteStdOut(HTTP_CODE_METHOD_NOT_ALLOWED :ErrorMessage);
    yajl_GenClose();

  EndIf;

  Return;

END-PROC;


//#########################################################################
// handle incoming data from post method
//  available json-imports:
//   - incomming orders (inhouse-format)
DCL-PROC handleIncommingPostData;
  DCL-PI *N;
    pInputParmDS LIKEDS(InputParmDS_T) CONST;
  END-PI;

  DCL-DS HeaderDS LIKEDS(HeaderDS_T) INZ;
  DCL-DS LinesDS LIKEDS(LinesDS_T) INZ;
  DCL-DS LogEntryDS LIKEDS(LogEntryDS_T) INZ;
  DCL-DS ErrorDS LIKEDS(ErrorDS_T) INZ;

  DCL-S Success IND INZ(TRUE);
  DCL-S ErrorFlag IND;
  DCL-S ReturnCode INT(5) INZ(200);
  DCL-S IndexHeader INT(10) INZ;
  DCL-S IndexOrderDate INT(10) INZ;
  DCL-S IndexSenderRecipient INT(10) INZ;
  DCL-S IndexLines INT(10) INZ;
  DCL-S IndexQuantity INT(10) INZ;
  DCL-S NodeTree LIKE(Yajl_Val) INZ;
  DCL-S OrderTree LIKE(Yajl_Val) INZ;
  DCL-S OrderTreeSave LIKE(Yajl_Val) INZ;
  DCL-S OrderDateTree LIKE(Yajl_Val) INZ;
  DCL-S SenderRecipientTree LIKE(Yajl_Val) INZ;
  DCL-S LinesTree LIKE(Yajl_Val) INZ;
  DCL-S LinesSubTree LIKE(Yajl_Val) INZ;
  DCL-S QuantityTree LIKE(Yajl_Val) INZ;
  DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 yajl_GenOpen(TRUE);
 yajl_BeginObj();

 If ( %Scan(CONTENT_TYPE_JSON :pInputParmDS.ContentType) > 0 ) And ( pInputParmDS.Data <> *NULL );
   // Translate incomming stream from utf8 to local ccsid
   translateData(pInputParmDS.Data :pInputParmDS.DataLength :UTF8 :LOCAL_CCSID);

   // Load json stream from buffer
   NodeTree = yajl_Buf_Load_Tree(pInputParmDS.Data :pInputParmDS.DataLength :ErrorMessage);
   Success = ( NodeTree <> *NULL );

   If Success;

     OrderTree = yajl_Object_Find(NodeTree :'orderInbound');

     If ( OrderTree <> *NULL );

       OrderTreeSave = OrderTree;

       // Common header informations
       HeaderDS.Sender = getValueByKey(OrderTree :'sender');
       HeaderDS.Recipient = getValueByKey(OrderTree :'recipient');
       HeaderDS.EdifactType = getValueByKey(OrderTree :'edifactType');
       HeaderDS.MessageNumber = getValueByKey(OrderTree :'messageNumber');
       HeaderDS.MessageDate = getValueByKey(OrderTree :'messageDate');
       HeaderDS.MessageTime = getValueByKey(OrderTree :'messageTime');
       HeaderDS.MessageType = getValueByKey(OrderTree :'messageType');
       HeaderDS.OrderNumber = getValueByKey(OrderTree :'orderNumber');
       HeaderDS.GHPImportMode = getValueByKey(OrderTree :'ghpMode');
       HeaderDS.Text1 = getValueByKey(OrderTree :'additionalText1');
       HeaderDS.Text2 = getValueByKey(OrderTree :'additionalText2');

       OrderDateTree = yajl_Object_Find(OrderTreeSave :'dtmHeader');
       If ( OrderDateTree <> *NULL );
         // Different order/delivery-dates from order
         ExSR GetOrderDates;

       EndIf;

       OrderTreeSave = OrderTree;
       SenderRecipientTree = yajl_Object_Find(OrderTreeSave :'nadHeader');
       If ( SenderRecipientTree <> *NULL );
         // Different nad-segments - by, dp, su, iv, etc
         ExSR GetNADInformations;
       EndIf;

       If ( HeaderDS.Sender <> '' );
         // Write header-informations to p00iof
         writeHeaderP00IOF(HeaderDS);
         LogEntryDS = writeLogEntryHeader(HeaderDS);
       EndIf;

       // Get the lines/position-informations from the current order
       OrderTreeSave = OrderTree;
       LinesTree = yajl_Object_Find(OrderTree :'lines');

       If ( LinesTree <> *NULL );
         // Get lines from received order
         ExSR GetLinesFromOrder;

       Else;
         // No lines/position found, abort
         Success = FALSE;
         ReturnCode = HTTP_CODE_NOT_EXTENDED;
         ErrorMessage = 'lines Node not found. Operation canceled';
         sendMessageToJoblog(ErrorMessage);
         setErrorStateLogEntry(LogEntryDS :ErrorMessage);

       EndIf;

     Else;
       // No order-node found, abort
       Success = FALSE;
       ReturnCode = HTTP_CODE_NOT_EXTENDED;
       ErrorMessage = 'orderInbound Node not found. Operation canceled';
       sendMessageToJoblog(ErrorMessage);
       setErrorStateLogEntry(writeLogEntryHeader(HeaderDS) :ErrorMessage);

     EndIf;

   Else;
     ReturnCode = HTTP_CODE_UNSUPPORTED_MEDIA_TYPE;
     ErrorMessage = 'Unsupported media-type received. Operation canceled';
     sendMessageToJoblog(ErrorMessage);
     setErrorStateLogEntry(writeLogEntryHeader(HeaderDS) :ErrorMessage);

   EndIf;

 Else;
   Success = FALSE;
   ReturnCode = HTTP_CODE_BAD_REQUEST;
   ErrorMessage = 'No data received. Operation canceled';
   sendMessageToJoblog(ErrorMessage);
   setErrorStateLogEntry(writeLogEntryHeader(HeaderDS) :ErrorMessage);

 EndIf;

 If Success;
   ReturnCode = HTTP_CODE_OK;
   Monitor;
     Select;
       When ( HeaderDS.EdifactType = 'ORDERS' );
         importOrders(HeaderDS.GHPImportMode);
       Other;
         Success = FALSE;
         ReturnCode = HTTP_CODE_NOT_IMPLEMENTED;
         ErrorMessage = %TrimR(HeaderDS.EdifactType) + ' not implemented';
         sendMessageToJoblog(ErrorMessage);
         setErrorStateLogEntry(LogEntryDS :ErrorMessage);
     EndSl;
     On-Error;
       Success = FALSE;
       ReturnCode = HTTP_CODE_INTERNAL_SERVER_ERROR;
       ErrorMessage = 'End of import with internal failure';
       sendMessageToJoblog(ErrorMessage);
       setErrorStateLogEntry(LogEntryDS :ErrorMessage);
   EndMon;

   If Success;
     setFinishStateLogEntry(LogEntryDS);
   EndIf;

 EndIf;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
BegSR GetOrderDates;
 // Get order and delivery dates

 DoW yajl_Array_Loop(OrderDateTree :IndexOrderDate :OrderTreeSave)
  And ( IndexOrderDate <= MAX_ARRAY );
   HeaderDS.OrderDatesDS(IndexOrderDate).Type = getValueByKey(OrderTreeSave :'dtmType');
   HeaderDS.OrderDatesDS(IndexOrderDate).Value = getValueByKey(OrderTreeSave :'dtmDate');

 EndDo;

EndSR;
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
BegSR GetNADInformations;
 // Get gln for different types (by, dp, iv, ob, su...)

 DoW yajl_Array_Loop(SenderRecipientTree :IndexSenderRecipient :OrderTreeSave)
  And ( IndexSenderRecipient <= MAX_ARRAY );
   HeaderDS.SenderRecipientDS(IndexSenderRecipient).Type = getValueByKey(OrderTreeSave :'nadType');
   HeaderDS.SenderRecipientDS(IndexSenderRecipient).GLN = getValueByKey(OrderTreeSave :'nadGLN');

 EndDo;

EndSR;
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
BegSR GetLinesFromOrder;
 // Get lines from received order

 DoW yajl_Array_Loop(LinesTree :IndexLines :LinesSubTree);
   Monitor;
     LinesDS.LineNumber = %Int(getValueByKey(LinesSubTree :'lineNumber'));
     On-Error;
       LinesDS.LineNumber = IndexLines;
   EndMon;

   LinesDS.GTIN = getValueByKey(LinesSubTree :'gtin');
   LinesDS.ItemNumber = getValueByKey(LinesSubTree :'itemNumber');
   LinesDS.ItemType = getValueByKey(LinesSubTree :'itemType');

   If ( LinesDS.GTIN = '' ) And ( LinesDS.ItemNumber = '' );
     // No gtin and itmnbr found, abort
     Success = FALSE;
     ReturnCode = HTTP_CODE_NOT_EXTENDED;
     ErrorMessage = 'gtin nor itemNumber found. Operation canceled';
     sendMessageToJoblog(ErrorMessage);
     setErrorStateLogEntry(LogEntryDS :ErrorMessage);
     LeaveSR;
   EndIf;

   // Quantities
   OrderTreeSave = OrderTree;
   QuantityTree = yajl_Object_Find(LinesSubTree :'quantityLine');
   If ( QuantityTree <> *NULL );
     // Different quantity-types
     ExSR GetQuantitiesForCurrentLine;
     If Not Success;
       LeaveSR;
     EndIf;

   Else;
     // No qty-segment found, abort
     Success = FALSE;
     ReturnCode = HTTP_CODE_NOT_EXTENDED;
     ErrorMessage = 'quantityLine not found. Operation canceled';
     sendMessageToJoblog(ErrorMessage);
     setErrorStateLogEntry(LogEntryDS :ErrorMessage);
     LeaveSR;

   EndIf;

   LinesDS.Reference = getValueByKey(OrderTree :'referenceLine');

   writePositionP00IOF(LinesDS :IndexLines);
   Clear LinesDS;

 EndDo;

EndSR;
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
BegSR GetQuantitiesForCurrentLine;
 // Get different quantity information for current line

 OrderTreeSave = OrderTree;
 Reset IndexQuantity;

 DoW yajl_Array_Loop(QuantityTree :IndexQuantity :OrderTreeSave)
  And ( IndexQuantity <= MAX_ARRAY );
   LinesDS.QuantitiesDS(IndexQuantity).Type = getValueByKey(OrderTreeSave :'quantityType');

   Monitor;
     LinesDS.QuantitiesDS(IndexQuantity).Quantity =
                %Dec(getValueByKey(OrderTreeSave :'quantityValue') :9 :2);
     On-Error;
       // QTY not valid decimal value
       Success = FALSE;
       ReturnCode = HTTP_CODE_NOT_EXTENDED;
       ErrorMessage = 'quantityValue not valid. Operation canceled';
       sendMessageToJoblog(ErrorMessage);
       LeaveSR;
   EndMon;

   LinesDS.QuantitiesDS(IndexQuantity).Unit = getValueByKey(OrderTreeSave :'quantityUnit');

 EndDo;

EndSR;

On-Exit ErrorFlag;

 If ErrorFlag;
   // General error occured
   Success = FALSE;
   ReturnCode = HTTP_CODE_SERVICE_UNAVAILABLE;
   ErrorMessage = 'Service Unavailable. Operation canceled';
   If ( LogEntryDS.ID <= 0 );
     LogEntryDS = writeLogEntryHeader(HeaderDS);
   ENdIf;
   setErrorStateLogEntry(LogEntryDS :ErrorMessage);
 EndIf;

 yajl_AddBool('success' :Success);
 yajl_AddNum('httpStatus' :%Char(ReturnCode));

 If Not Success Or ErrorFlag;
   // Write error details
   yajl_BeginArray('errorDetails');
   yajl_AddChar('contentType' :%TrimR(pInputParmDS.ContentType));
   yajl_AddChar('errorMessage' :%TrimR(ErrorMessage));
   yajl_EndArray();
 EndIf;

 yajl_EndObj();
 yajl_WriteStdOut(ReturnCode :ErrorMessage);
 yajl_GenClose();

 yajl_Tree_Free(NodeTree);

END-PROC;

//#########################################################################
DCL-PROC writeHeaderP00IOF;
 DCL-PI *N;
  pHeaderDS LIKEDS(HeaderDS_T) CONST;
 END-PI;

 DCL-S Index INT(5) INZ;
//------------------------------------------------------------------------

 writeField(1 :0 :0: 'SENDER' :pHeaderDS.Sender);
 writeField(1 :0 :0: 'RECIPIENT' :pHeaderDS.Recipient);
 writeField(1 :0 :0: 'MSGDATE' :pHeaderDS.MessageDate);
 writeField(1 :0 :0: 'MSGTIME' :pHeaderDS.MessageTime);
 writeField(1 :0 :0: 'MSGID' :pHeaderDS.MessageNumber);
 writeField(1 :1 :0: 'MSGNBR' :pHeaderDS.MessageNumber);
 writeField(1 :1 :0: 'MSGTYPE' :pHeaderDS.MessageType);
 writeField(1 :1 :0: 'ORDNBR' :pHeaderDS.OrderNumber);
 If ( pHeaderDS.Text1 <> '' );
   writeField(1 :1 :0: 'TEXT1' :pHeaderDS.Text1);
 EndIf;
 If ( pHeaderDS.Text2 <> '' );
   writeField(1 :1 :0: 'TEXT2' :pHeaderDS.Text2);
 EndIf;

 Index = %Lookup('137' :pHeaderDS.OrderDatesDS(*).Type);
 If ( Index > 0 ); // OrderDate
   writeField(1 :1 :0: 'ORDDATE' :pHeaderDS.OrderDatesDS(Index).Value);
 EndIf;

 Index = %Lookup('2' :pHeaderDS.OrderDatesDS(*).Type);
 If ( Index > 0 ); // Deliverydate
   writeField(1 :1 :0: 'DLVDATE' :pHeaderDS.OrderDatesDS(Index).Value);
 Else;
   Index = %Lookup('74' :pHeaderDS.OrderDatesDS(*).Type);
   If ( Index > 0 ); // Deliverydate
     writeField(1 :1 :0: 'DLVDATE' :pHeaderDS.OrderDatesDS(Index).Value);
   EndIf;
 EndIf;

 Index = %Lookup('BY' :pHeaderDS.SenderRecipientDS(*).Type);
 If ( Index > 0 ); // Buyer
   writeField(1 :1 :0: 'BUYER' :pHeaderDS.SenderRecipientDS(Index).GLN);
 EndIf;

 Index = %Lookup('DP' :pHeaderDS.SenderRecipientDS(*).Type);
 If ( Index > 0 ); // Delivery party
   writeField(1 :1 :0: 'DLVPARTY' :pHeaderDS.SenderRecipientDS(Index).GLN);
 EndIf;

 Index = %Lookup('SU' :pHeaderDS.SenderRecipientDS(*).Type);
 If ( Index > 0 ); // Supplier
   writeField(1 :1 :0: 'SUPPLIER' :pHeaderDS.SenderRecipientDS(Index).GLN);
 EndIf;

 Index = %Lookup('IV' :pHeaderDS.SenderRecipientDS(*).Type);
 If ( Index > 0 ); // Invoicee
   writeField(1 :1 :0: 'SALORGSUP' :pHeaderDS.SenderRecipientDS(Index).GLN);
 EndIf;

 Index = %Lookup('OB' :pHeaderDS.SenderRecipientDS(*).Type);
 If ( Index > 0 ); // Ordered by
   writeField(1 :1 :0: 'ORDERER' :pHeaderDS.SenderRecipientDS(Index).GLN);
 EndIf;

END-PROC;

//#########################################################################
DCL-PROC writePositionP00IOF;
 DCL-PI *N;
  pLinesDS LIKEDS(LinesDS_T) CONST;
  pLineNumber INT(10) CONST;
 END-PI;

 DCL-S Index INT(5) INZ;
//------------------------------------------------------------------------

 writeField(1 :1 :pLineNumber: 'LINNBR' :%Char(pLinesDS.LineNumber)); // Linenumber
 writeField(1 :1 :pLineNumber: 'EAN' :pLinesDS.GTIN); // GTIN
 If ( pLinesDS.ItemNumber <> '' );
   writeField(1 :1 :pLineNumber: 'ITMNBR' :pLinesDS.ItemNumber); // Itemnumber
   writeField(1 :1 :pLineNumber: 'ITMTYPE' :pLinesDS.ItemType); // Type of itemnumber
 EndIf;

 Index = %Lookup('21' :pLinesDS.QuantitiesDS(*).Type);
 If ( Index > 0 ); // Ordered quantity
   writeField(1 :1 :pLineNumber: 'QTY' :%Char(pLinesDS.QuantitiesDS(Index).Quantity));
 EndIf;

 Index = %Lookup('59' :pLinesDS.QuantitiesDS(*).Type);
 If ( Index > 0 ); // Package content
   writeField(1 :1 :pLineNumber: 'QTY_VIN' :%Char(pLinesDS.QuantitiesDS(Index).Quantity));
 EndIf;

 Index = %Lookup('192' :pLinesDS.QuantitiesDS(*).Type);
 If ( Index > 0 ); // Ordered quantity - for free
   writeField(1 :1 :pLineNumber: 'QTY_FREE' :%Char(pLinesDS.QuantitiesDS(Index).Quantity));
 EndIf;

 If ( pLinesDS.Reference <> '' );
   writeField(1 :1 :pLineNumber: 'REFERENCE' :pLinesDS.Reference); // Pos-reference
 EndIf;

END-PROC;

//#########################################################################
DCL-PROC writeField;
 DCL-PI *N;
  pHier3 PACKED(5: 0) CONST;
  pHier2 PACKED(5 :0) CONST;
  pHier1 PACKED(5 :0) CONST;
  pFieldName CHAR(10) CONST;
  pFieldValue CHAR(128) CONST;
 END-PI;
//------------------------------------------------------------------------

 Exec SQL insert into qtemp.p00iof
            (fil_hier3, fil_hier2, fil_hier1, fld_name, fld_value)
            values(:pHier3, :pHier2, :pHier1, :pFieldName, :pFieldValue);

END-PROC;

//#########################################################################
DCL-PROC getValueByKey;
 DCL-PI *N CHAR(128);
  pNodeTree LIKE(Yajl_Val) CONST;
  pKey CHAR(128) CONST;
 END-PI;

 DCL-S ValueTree LIKE(Yajl_Val) INZ;
 DCL-S ReturnValue CHAR(128) INZ;
//------------------------------------------------------------------------

 ValueTree = yajl_Object_find(pNodeTree :%Trim(pKey));
 If ( ValueTree <> *NULL );
   ReturnValue = yajl_Get_String(ValueTree);
 Else;
   Clear ReturnValue;
 EndIf;

 Return ReturnValue;

END-PROC;

//#########################################################################
DCL-PROC createTempTable;
//------------------------------------------------------------------------

 Exec SQL drop table qtemp.p00iof if exists;
 System('CRTDUPOBJ OBJ(P00IOF) FROMLIB(CCDATEN) OBJTYPE(*FILE) TOLIB(QTEMP) DATA(*NO)');

END-PROC;

//#########################################################################
DCL-PROC writeLogEntryHeader;
 DCL-PI *N LIKEDS(LogEntryDS_T);
  pHeaderDS LIKEDS(HeaderDS_T) CONST;
 END-PI;

 DCL-DS LogEntryDS LIKEDS(LogEntryDS_T) INZ;

 DCL-S Index INT(5) INZ;
 DCL-S OrderDate CHAR(8) INZ;
 DCL-S DeliveryDate CHAR(8) INZ;
 DCL-S Buyer CHAR(13) INZ;
 DCL-S Supplier CHAR(13) INZ;
 DCL-S DeliveryParty CHAR(13) INZ;
 DCL-S Invoicee CHAR(13) INZ;
 DCL-S OrderedBy CHAR(13) INZ;
//------------------------------------------------------------------------

 Index = %Lookup('137' :pHeaderDS.OrderDatesDS(*).Type);
 If ( Index > 0 ); // OrderDate
   OrderDate = pHeaderDS.OrderDatesDS(Index).Value;
 EndIf;

 Index = %Lookup('2' :pHeaderDS.OrderDatesDS(*).Type);
 If ( Index > 0 ); // Deliverydate
   DeliveryDate = pHeaderDS.OrderDatesDS(Index).Value;
 Else;
   Index = %Lookup('74' :pHeaderDS.OrderDatesDS(*).Type);
   If ( Index > 0 ); // Deliverydate
     DeliveryDate = pHeaderDS.OrderDatesDS(Index).Value;
   EndIf;
 EndIf;

 Index = %Lookup('BY' :pHeaderDS.SenderRecipientDS(*).Type);
 If ( Index > 0 ); // Buyer
   Buyer = pHeaderDS.SenderRecipientDS(Index).GLN;
 EndIf;

 Index = %Lookup('DP' :pHeaderDS.SenderRecipientDS(*).Type);
 If ( Index > 0 ); // Delivery party
   DeliveryParty = pHeaderDS.SenderRecipientDS(Index).GLN;
 EndIf;

 Index = %Lookup('SU' :pHeaderDS.SenderRecipientDS(*).Type);
 If ( Index > 0 ); // Supplier
   Supplier = pHeaderDS.SenderRecipientDS(Index).GLN;
 EndIf;

 Index = %Lookup('IV' :pHeaderDS.SenderRecipientDS(*).Type);
 If ( Index > 0 ); // Invoicee
   Invoicee = pHeaderDS.SenderRecipientDS(Index).GLN;
 EndIf;

 Index = %Lookup('OB' :pHeaderDS.SenderRecipientDS(*).Type);
 If ( Index > 0 ); // Ordered by
   OrderedBy = pHeaderDS.SenderRecipientDS(Index).GLN;
 EndIf;

 Exec SQL select in_id, in_year into :LogEntryDS from final table
          (insert into lobster.lobsterin_header
            (in_year, in_edifact_type, in_sender, in_recipient, in_message_date,
              in_message_time, in_message_number, in_message_type, in_order_number,
              in_ghp_mode, in_order_date, in_delivery_date, in_buyer, in_delivery_party,
              in_supplier, in_invoicee, in_ordered_by)
            values(decimal(year(current_date), 4), nullif(:pHeaderDS.EdifactType, ''),
                    nullif(:pHeaderDS.Sender, ''), nullif(:pHeaderDS.Recipient, ''),
                    nullif(:pHeaderDS.MessageDate, ''), nullif(:pHeaderDS.MessageTime, ''),
                    nullif(:pHeaderDS.MessageNumber, ''), nullif(:pHeaderDS.MessageType, ''),
                    trim(nullif(:pHeaderDS.OrderNumber, '')), nullif(:pHeaderDS.GHPImportMode, ''),
                    nullif(:OrderDate, ''), nullif(:DeliveryDate, ''), nullif(:Buyer, ''),
                    nullif(:DeliveryParty, ''), nullif(:Supplier, ''), nullif(:Invoicee, ''),
                    nullif(:OrderedBy, '')));
 If ( SQLCode <> 0 );
   LogEntryDS.ID = -1;
 EndIf;

 Return LogEntryDS;

END-PROC;
//#########################################################################
DCL-PROC setErrorStateLogEntry;
 DCL-PI *N;
  pLogEntryDS LIKEDS(LogEntryDS_T) CONST;
  pErrorMessage CHAR(128) CONST;
 END-PI;
//------------------------------------------------------------------------

 Exec SQL update lobster.lobsterin_header header
             set header.in_success = 'E',
                  header.in_error_message = trim(:pErrorMessage)
           where header.in_id = :pLogEntryDS.ID
              and header.in_year = :pLogEntryDS.Year;

END-PROC;
//#########################################################################
DCL-PROC setFinishStateLogEntry;
 DCL-PI *N;
  pLogEntryDS LIKEDS(LogEntryDS_T) CONST;
 END-PI;
//------------------------------------------------------------------------

 Exec SQL update lobster.lobsterin_header header
             set header.in_success = 'F'
           where header.in_id = :pLogEntryDS.ID
              and header.in_year = :pLogEntryDS.Year;

END-PROC;
