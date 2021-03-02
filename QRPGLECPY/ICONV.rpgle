**FREE
//- Copyright (c) 2019 - 2021 Christian Brunner
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

/IF DEFINED (API_ICONV)
/EOF
/ENDIF

/DEFINE API_ICONV

DCL-PR iConv_Open LIKE(ToASCII) EXTPROC('QtqIconvOpen');
  ToCode LIKE(FromDS);
  FromCode LIKE(ToDS);
END-PR;

DCL-PR iConv INT(10) EXTPROC('iconv');
  Descriptor LIKE(ToASCII) VALUE;
  InBuff POINTER;
  InLeft UNS(10);
  OutBuffer POINTER;
  OutLeft UNS(10);
END-PR;

DCL-PR iConv_Close INT(10) EXTPROC('iconv_close');
  Descriptor LIKE(ToASCII) VALUE;
END-PR;

DCL-DS ToASCII QUALIFIED INZ;
  ICORV_A INT(10);
  ICOC_A INT(10) DIM(12);
END-DS;

DCL-DS FromDS QUALIFIED;
  FromCCSID INT(10) INZ;
  CA INT(10) INZ;
  SA INT(10) INZ;
  SS INT(10) INZ;
  IL INT(10) INZ;
  EO INT(10) INZ;
  R CHAR(8) INZ(*ALLX'00');
END-DS;

DCL-DS ToDS QUALIFIED;
  ToCCSID INT(10) INZ;
  CA INT(10) INZ;
  SA INT(10) INZ;
  SS INT(10) INZ;
  IL INT(10) INZ;
  EO INT(10) INZ;
  R CHAR(8) INZ(*ALLX'00');
END-DS;

DCL-DS iConvDS QUALIFIED INZ;
  iConvHandler POINTER;
  Length UNS(10);
END-DS;
