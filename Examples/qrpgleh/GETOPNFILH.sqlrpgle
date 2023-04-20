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

/IF DEFINED (GETOPNFIL)
/EOF
/ENDIF

/DEFINE GETOPNFIL


/INCLUDE QRPGLECPY,H_SPECS
CTL-OPT MAIN(Main) BNDDIR('CGISRVR1' :'YAJL');

DCL-PR Main EXTPGM('GETOPNFIL') END-PR;

/INCLUDE QRPGLEH,CGISRVR1_H
/INCLUDE QRPGLESRC,YAJL_H
/INCLUDE QRPGLECPY,BOOLIC

DCL-DS OpenFilesInfoDS_T QUALIFIED TEMPLATE;
 LibraryName VARCHAR(10);
 FileName VARCHAR(10);
 FileType VARCHAR(7);
 MemberName VARCHAR(10);
 DeviceName VARCHAR(10);
 RecordFormat VARCHAR(10);
 ActivationGroupName VARCHAR(10);
 OpenOption VARCHAR(6);
 SharedOpens INT(20);
 WriteCount INT(20);
 ReadCount INT(20);
 WriteReadCount INT(20);
 OtherIOCount INT(20);
 RelativeRecordNumber INT(20);
END-DS;
