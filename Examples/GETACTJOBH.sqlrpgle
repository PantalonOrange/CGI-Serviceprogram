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

/IF DEFINED (GETACTJOBH)
/EOF
/ENDIF

/DEFINE GETACTJOBH


/INCLUDE QRPGLECPY,H_SPECS
CTL-OPT MAIN(Main) BNDDIR('CGISRVR1' :'YAJL');

DCL-PR Main EXTPGM('GETACTJOB') END-PR;

/INCLUDE QRPGLEH,CGISRVR1_H
/INCLUDE QRPGLESRC,YAJL_H
/INCLUDE QRPGLECPY,PSDS
/INCLUDE QRPGLECPY,BOOLIC
/INCLUDE QRPGLECPY,ERRORDS_H

DCL-DS JobInfoDS_T QUALIFIED TEMPLATE;
 OrdinalPosition INT(10);
 Subsystem CHAR(10);
 JobName VARCHAR(28);
 JobType CHAR(3);
 JobStatus CHAR(4);
 JobMessage CHAR(1024);
 MessageKey CHAR(10);
 AuthorizationName CHAR(10);
 AuthorizationDescription VARCHAR(50);
 FunctionType CHAR(3);
 Function CHAR(10);
 TemporaryStorage INT(10);
 ClientIPAddress VARCHAR(45);
 JobActiveTime VARCHAR(26);
END-DS;
