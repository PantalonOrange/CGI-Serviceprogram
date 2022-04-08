**FREE
//- Copyright (c) 2022 Christian Brunner
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

/IF DEFINED (GETOUTINFH)
/EOF
/ENDIF

/DEFINE GETOUTINFH

/INCLUDE QRPGLECPY,H_SPECS
CTL-OPT MAIN(Main) BNDDIR('CGISRVR1' :'YAJL');

DCL-PR Main EXTPGM('GETOUTINF') END-PR;

/INCLUDE QRPGLEH,CGISRVR1_H
/INCLUDE QRPGLESRC,YAJL_H
/INCLUDE QRPGLECPY,BOOLIC

DCL-DS OutputQueueInfoDS_T QUALIFIED TEMPLATE;
 OutputQueueName CHAR(10);
 OutputQueueLibrary CHAR(10);
 NumberOfFiles INT(10);
 NumberOfWriters INT(10);
 WritersToAutostart INT(10);
 PrinterDeviceName CHAR(10);
 OperatorControlled CHAR(4);
 DataQueueLibrary CHAR(10);
 DataQueueName CHAR(10);
 OutputQueueStatus CHAR(8);
 WriterJobName VARCHAR(28);
 WriterJobStatus CHAR(4);
 WriterType CHAR(7);
 TextDescription VARCHAR(50);
 MessageQueueLibrary CHAR(10);
 MessageQueueName CHAR(10);
END-DS;
