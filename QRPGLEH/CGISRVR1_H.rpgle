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

/IF DEFINED (CGISRVR1_H)
/EOF
/ENDIF

/DEFINE CGISRVR1_H


DCL-PR getHTTPInput LIKEDS(ParmInputDS_T) END-PR;

DCL-PR writeHTTPOut;
 Data POINTER VALUE;
 DataLenth INT(10) CONST;
END-PR;

DCL-PR getHTTPHeader CHAR(128) END-PR;


DCL-DS ParmInputDS_T QUALIFIED TEMPLATE;
 Data POINTER;
 DataLength INT(10);
 Methode CHAR(20);
 ContentType CHAR(128);
 AuthType CHAR(128);
 RemoteUser CHAR(128);
 SeperatedKeysDS LIKEDS(SeperatedKeysDS_T) DIM(MAX_SEP_KEYS);
END-DS;

DCL-C MAX_SEP_KEYS 20;
DCL-DS SeperatedKeysDS_T QUALIFIED TEMPLATE;
 Field CHAR(128);
 ExtractedValue CHAR(128);
END-DS;


/IF DEFINED (COMPILE_CGISRVR1)
/INCLUDE QRPGLECPY,ERRORDS_H
DCL-C CRLF x'0D25';
/ENDIF
