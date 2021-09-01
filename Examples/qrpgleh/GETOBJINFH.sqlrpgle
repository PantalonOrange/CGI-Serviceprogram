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

/IF DEFINED (GETOBJINF)
/EOF
/ENDIF

/DEFINE GETOBJINF


/INCLUDE QRPGLECPY,H_SPECS
CTL-OPT MAIN(Main) BNDDIR('CGISRVR1' :'YAJL');

DCL-PR Main EXTPGM('GETOBJINF') END-PR;

/INCLUDE QRPGLEH,CGISRVR1_H
/INCLUDE QRPGLESRC,YAJL_H
/INCLUDE QRPGLECPY,BOOLIC

DCL-DS ObjectStatisticsDS_T QUALIFIED TEMPLATE;
 Position INT(10);
 Name CHAR(10);
 Library CHAR(10);
 Type CHAR(8);
 Owner CHAR(10);
 Definer CHAR(10);
 Created CHAR(28);
 Size INT(20);
 Text VARCHAR(50);
 LongName VARCHAR(128);
 LongSchema VARCHAR(128);
 LastUsedTimeStamp CHAR(28);
 DaysUsedCount INT(10);
 LastResetTimeStamp CHAR(28);
 Attribute CHAR(10);
 ChangeTimeStamp CHAR(28);
 SourceFile CHAR(10);
 SourceLibrary CHAR(10);
 SourceMember CHAR(10);
 SourceTimeStamp CHAR(28);
 CreatedSystem CHAR(8);
 CreatedSystemVersion CHAR(9);
 LicensedProgram CHAR(7);
 LicensedProgramVersion CHAR(9);
 Compiler CHAR(7);
 CompilerVersion CHAR(9);
 SaveTimeStamp CHAR(28);
 RestoreTimeStamp CHAR(28);
 SaveWhileActiveTimeStamp CHAR(28);
 SaveCommand CHAR(10);
 SaveDevice CHAR(5);
 SaveFileName CHAR(10);
 SaveFileLibrary CHAR(10);
 JournalName CHAR(10);
 JournalLibrary CHAR(10);
 JournalImages CHAR(6);
 OmitJournalEntry CHAR(7);
END-DS;
