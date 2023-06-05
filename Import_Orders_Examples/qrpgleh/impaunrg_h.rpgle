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

/IF DEFINED (IMPAUNRG_H)
/EOF
/ENDIF

/DEFINE IMPAUNRG_H


/INCLUDE QRPGLECPY,H_SPECS
CTL-OPT MAIN(Main) BNDDIR('CGISRVR1' :'YAJL');

DCL-PR Main EXTPGM('IMPAUNRG') END-PR;

/INCLUDE QRPGLEH,CGISRVR1_H
/INCLUDE QRPGLESRC,YAJL_H
/INCLUDE QRPGLECPY,PSDS
/INCLUDE QRPGLECPY,BOOLIC
/INCLUDE QRPGLECPY,ERRORDS_H
/INCLUDE QRPGLECPY,SYSTEM

DCL-PR importOrders EXTPGM('AUFMD4CL');
 ImportMode CHAR(1) CONST;
END-PR;

DCL-C CONTENT_TYPE_JSON 'application/json';
DCL-C MAX_ARRAY 10;

DCL-DS LogEntryDS_T QUALIFIED TEMPLATE;
 ID INT(20);
 Year PACKED(4 :0);
END-DS;

DCL-DS HeaderDS_T QUALIFIED TEMPLATE;
 Sender CHAR(13);
 Recipient CHAR(13);
 EdifactType CHAR(10);
 MessageDate CHAR(6);
 MessageTime CHAR(6);
 MessageNumber CHAR(128);
 MessageType CHAR(3);
 OrderNumber CHAR(128);
 GHPImportMode CHAR(1);
 OrderDatesDS LIKEDS(OrderDatesDS_T) DIM(MAX_ARRAY);
 SenderRecipientDS LIKEDS(SenderRecipientDS_T) DIM(MAX_ARRAY);
 Text1 CHAR(128);
 Text2 CHAR(128);
END-DS;

DCL-DS LinesDS_T QUALIFIED TEMPLATE;
 LineNumber INT(10);
 GTIN CHAR(14);
 ItemNumber CHAR(10);
 ItemType CHAR(2);
 QuantitiesDS LIKEDS(QuantitiesDS_T) DIM(MAX_ARRAY);
 Reference CHAR(128);
END-DS;

DCL-DS OrderDatesDS_T QUALIFIED TEMPLATE;
 Type CHAR(3);
 Value CHAR(10);
END-DS;

DCL-DS SenderRecipientDS_T QUALIFIED TEMPLATE;
 Type CHAR(3);
 GLN CHAR(13);
END-DS;

DCL-DS QuantitiesDS_T QUALIFIED TEMPLATE;
 Type CHAR(3);
 Quantity PACKED(9 :2);
 Unit CHAR(3);
END-DS;
