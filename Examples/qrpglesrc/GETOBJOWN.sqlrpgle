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


// This cgi-exitprogram will return the object ownership-informations
//  for the selected authorization name

// The following parameters are implemented:
//  - usr = Authorization name (key)
//  - typ = Object type (optional)


/INCLUDE QRPGLEH,GETOBJOWNH


//#########################################################################
DCL-PROC Main;

 DCL-DS InputParmDS LIKEDS(InputParmDS_T) INZ;

 DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 /INCLUDE QRPGLECPY,SQLOPTIONS

 *INLR = TRUE;

 InputParmDS = getHTTPInput();

 If ( InputParmDS.Method = 'GET' );
   readObjectOwnershipAndCreateJSON(InputParmDS);

 Else;
   ErrorMessage = %TrimR(InputParmDS.Method) + ' not allowed';
   writeHTTPOut(%Addr(ErrorMessage) :%Len(%Trim(ErrorMessage)) + 2 :HTTP_BAD_REQUEST);

 EndIf;

 Return;

END-PROC;


//#########################################################################
// parse selected object onwership information to json and return it
DCL-PROC readObjectOwnershipAndCreateJSON;
 DCL-PI *N;
  pInputParmDS LIKEDS(InputParmDS_T) CONST;
 END-PI;

 DCL-DS ObjectOwnershipInfoDS LIKEDS(ObjectOwnershipInfoDS_T) INZ;

 DCL-S FirstRun IND INZ(TRUE);
 DCL-S ArrayItem IND INZ(FALSE);
 DCL-S ObjectCount INT(10) INZ;
 DCL-S AuthorizationName CHAR(10) INZ;
 DCL-S ObjectType CHAR(7) INZ;
 DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 // retrieve parameters/values by name
 AuthorizationName = getValueByName('usr' :pInputParmDS);
 ObjectType = getValueByName('typ' :pInputParmDS);

 yajl_GenOpen(TRUE);
 yajl_BeginObj();

 Exec SQL DECLARE c_object_ownership_reader INSENSITIVE CURSOR FOR

           SELECT REPLACE(ownership.object_type, '*', ''),
                  IFNULL(ownership.object_library, ''),
                  IFNULL(ownership.object_name, ''),
                  CAST(IFNULL(ownership.path_name, '') AS CHAR(1024)),
                  IFNULL(ownership.object_attribute, ''),
                  IFNULL(ownership.text_description, '')
             FROM qsys2.object_ownership ownership
            WHERE ownership.authorization_name = UPPER(:AuthorizationName)
              AND ownership.object_type =
                   CASE WHEN :ObjectType = '' THEN ownership.object_type
                        ELSE '*' CONCAT UPPER(:ObjectType) END;

 Exec SQL OPEN c_object_ownership_reader;

 Exec SQL GET DIAGNOSTICS :ObjectCount = DB2_NUMBER_ROWS;

 DoW ( 1 = 1 );
   Exec SQL FETCH NEXT FROM c_object_ownership_reader INTO :ObjectOwnershipInfoDS;
   If ( SQLCode <> 0 );
     If FirstRun;
       // EOF or other errors
       yajl_AddBool('success' :FALSE);
       If ( SQLCode = 100 );
         ErrorMessage = 'Your request did not produce a result';
       Else;
         Exec SQL GET DIAGNOSTICS CONDITION 1 :ErrorMessage = MESSAGE_TEXT;
       EndIf;
       yajl_AddChar('errorMessage' :%Trim(ErrorMessage));
     EndIf;
     Exec SQL CLOSE c_object_ownership_reader;
     Leave;
   EndIf;

   If FirstRun;
     // fill in the header informations and begin the array
     FirstRun = FALSE;
     yajl_AddBool('success' :TRUE);
     yajl_AddNum('results' :%Char(ObjectCount));
     yajl_BeginArray('objectOwnershipInfo');
     ArrayItem = TRUE;
   EndIf;

   yajl_BeginObj();

   yajl_AddChar('objectType' :%TrimR(ObjectOwnershipInfoDS.ObjectType));

   If ( ObjectOwnershipInfoDS.ObjectSchema <> '' );
     yajl_AddChar('objectSchema' :%TrimR(ObjectOwnershipInfoDS.ObjectSchema));
     yajl_AddChar('objectName' :%TrimR(ObjectOwnershipInfoDS.ObjectName));
     yajl_AddChar('objectAttribute' :%TrimR(ObjectOwnershipInfoDS.ObjectAttribute));
   Else;
     yajl_AddChar('pathName' :%TrimR(ObjectOwnershipInfoDS.PathName));
   EndIf;

   If ( ObjectOwnershipInfoDS.TextDescription <> '' );
     yajl_AddChar('textDescription' :%TrimR(ObjectOwnershipInfoDS.TextDescription));
   EndIf;

   yajl_EndObj();

 EndDo;

 If ArrayItem;
   yajl_EndArray();
 EndIf;

 yajl_EndObj();
 yajl_WriteStdOut(200 :ErrorMessage);
 yajl_GenClose();

 Return;

END-PROC;
