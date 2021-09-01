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

/IF DEFINED (GETJOBLOG)
/EOF
/ENDIF

/DEFINE GETJOBLOG


/INCLUDE QRPGLECPY,H_SPECS
CTL-OPT MAIN(Main) BNDDIR('CGISRVR1' :'YAJL');

DCL-PR Main EXTPGM('GETJOBLOG') END-PR;

/INCLUDE QRPGLEH,CGISRVR1_H
/INCLUDE QRPGLESRC,YAJL_H
/INCLUDE QRPGLECPY,BOOLIC

DCL-DS JobLogInfoDS_T QUALIFIED TEMPLATE;
 Position INT(10);
 MessageID VARCHAR(7);
 MessageType VARCHAR(13);
 MessageSubType VARCHAR(22);
 Severity INT(10);
 MessageTimestamp VARCHAR(26);
 FromLibrary VARCHAR(10);
 FromProgram VARCHAR(256);
 FromModule VARCHAR(10);
 FromProcedure VARCHAR(4096);
 FromInstruction VARCHAR(10);
 ToLibrary VARCHAR(10);
 ToProgram VARCHAR(10);
 ToModule VARCHAR(10);
 ToProcedure VARCHAR(4096);
 ToInstruction VARCHAR(10);
 FromUser VARCHAR(10);
 MessageText VARCHAR(1024);
 MessageTextSecondLevel VARCHAR(4096);
 MessageKey CHAR(10);
END-DS;
