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

/IF DEFINED (GETOUTENTH)
/EOF
/ENDIF

/DEFINE GETOUTENTH

/INCLUDE QRPGLECPY,H_SPECS
CTL-OPT MAIN(Main) BNDDIR('CGISRVR1' :'YAJL');

DCL-PR Main EXTPGM('GETOUTENT') END-PR;

/INCLUDE QRPGLEH,CGISRVR1_H
/INCLUDE QRPGLESRC,YAJL_H
/INCLUDE QRPGLECPY,BOOLIC

DCL-DS OutputQueueEntryDS_T QUALIFIED TEMPLATE;
 OutputQueueName CHAR(10);
 OutputQueueLibrary CHAR(10);
 CreateTimestamp VARCHAR(26);
 SpooledFileName CHAR(10);
 UserName CHAR(10);
 UserData CHAR(10);
 Status VARCHAR(15);
 Size INT(10);
 TotalPages INT(10);
 Copies INT(10);
 FormType CHAR(10);
 JobName VARCHAR(28);
 DeviceType CHAR(10);
 OutputPriority INT(10);
 FileNumber INT(10);
 System CHAR(8);
END-DS;
