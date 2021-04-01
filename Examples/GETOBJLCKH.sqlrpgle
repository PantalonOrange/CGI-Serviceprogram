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

/IF DEFINED (GETOBJLCK)
/EOF
/ENDIF

/DEFINE GETOBJLCK


/INCLUDE QRPGLECPY,H_SPECS
CTL-OPT MAIN(Main) BNDDIR('CGISRVR1' :'YAJL');

DCL-PR Main EXTPGM('GETOBJLCK') END-PR;

/INCLUDE QRPGLEH,CGISRVR1_H
/INCLUDE QRPGLESRC,YAJL_H
/INCLUDE QRPGLECPY,BOOLIC

DCL-DS ObjectLockInfoDS_T QUALIFIED TEMPLATE;
 OrdinalPosition INT(10);
 ObjectName CHAR(10);
 ObjectSchema VARCHAR(10);
 MemberName CHAR(10);
 ObjectType CHAR(8);
 SQLObjectType CHAR(9);
 MemberLockType CHAR(10);
 LockState CHAR(7);
 LockStatus CHAR(9);
 LockScope CHAR(10);
 JobName VARCHAR(28);
 LockCount INT(10);
END-DS;
