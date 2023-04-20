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


// This cgi-exitprogram will return the open files for the selected job

// The following parameters are implemented:
//  - job = Qualified job name


/INCLUDE QRPGLEH,GETOPNFILH


//#########################################################################
DCL-PROC Main;

 DCL-DS InputParmDS LIKEDS(InputParmDS_T) INZ;

 DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 /INCLUDE QRPGLECPY,SQLOPTIONS

 *INLR = TRUE;

 InputParmDS = getHTTPInput();

 If ( InputParmDS.Method = 'GET' );
   readOpenFilesAndCreateJSON(InputParmDS);

 Else;
   ErrorMessage = %TrimR(InputParmDS.Method) + ' not allowed';
   writeHTTPOut(%Addr(ErrorMessage) :%Len(%Trim(ErrorMessage)) + 2 :HTTP_BAD_REQUEST);

 EndIf;

 Return;

END-PROC;


//#########################################################################
// parse selected open files information to json and return it
DCL-PROC readOpenFilesAndCreateJSON;
 DCL-PI *N;
  pInputParmDS LIKEDS(InputParmDS_T) CONST;
 END-PI;

 DCL-DS OpenFilesInfoDS LIKEDS(OpenFilesInfoDS_T) INZ;

 DCL-S FirstRun IND INZ(TRUE);
 DCL-S ArrayItem IND INZ(FALSE);
 DCL-S OpenFilesCount INT(10) INZ;
 DCL-S JobName CHAR(27) INZ;
 DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 // retrieve parameters/values by name
 JobName = getValueByName('job' :pInputParmDS);
 If ( JobName = '' );
   JobName = '*';
 EndIf;

 yajl_GenOpen(TRUE);
 yajl_BeginObj();

 Exec SQL DECLARE c_open_files_reader INSENSITIVE CURSOR FOR

           SELECT openfiles.library_name,
                  openfiles.file_name,
                  openfiles.file_type,
                  IFNULL(openfiles.member_name, ''),
                  IFNULL(openfiles.device_name, ''),
                  IFNULL(openfiles.record_format, ''),
                  IFNULL(openfiles.activation_group_name, ''),
                  openfiles.open_option,
                  IFNULL(openfiles.shared_opens, 0),
                  openfiles.write_count,
                  openfiles.read_count,
                  openfiles.write_read_count,
                  openfiles.other_io_count,
                  IFNULL(openfiles.relative_record_number, 0)
             FROM TABLE(qsys2.open_files(job_name => TRIM(:JobName))) openfiles;

 Exec SQL OPEN c_open_files_reader;

 Exec SQL GET DIAGNOSTICS :OpenFilesCount = DB2_NUMBER_ROWS;

 DoW ( 1 = 1 );
   Exec SQL FETCH NEXT FROM c_open_files_reader INTO :OpenFilesInfoDS;
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
     Exec SQL CLOSE c_open_files_reader;
     Leave;
   EndIf;

   If FirstRun;
     // fill in the header informations and begin the array
     FirstRun = FALSE;
     yajl_AddBool('success' :TRUE);
     yajl_AddNum('results' :%Char(OpenFilesCount));
     yajl_BeginArray('openFilesInfo');
     ArrayItem = TRUE;
   EndIf;

   yajl_BeginObj();

   yajl_AddChar('objectSchema' :%TrimR(OpenFilesInfoDS.LibraryName));
   yajl_AddChar('objectName' :%TrimR(OpenFilesInfoDS.FileName));
   yajl_AddChar('objectType' :%TrimR(OpenFilesInfoDS.FileType));

   If ( OpenFilesInfoDS.MemberName <> '' );
     yajl_AddChar('memberName' :%TrimR(OpenFilesInfoDS.MemberName));
   EndIf;

   If ( OpenFilesInfoDS.DeviceName <> '' );
     yajl_AddChar('deviceName' :%TrimR(OpenFilesInfoDS.DeviceName));
   EndIf;

   If ( OpenFilesInfoDS.RecordFormat <> '' );
     yajl_AddChar('recordFormat' :%TrimR(OpenFilesInfoDS.RecordFormat));
   EndIf;

   If ( OpenFilesInfoDS.ActivationGroupName <> '' );
     yajl_AddChar('activationGroupName' :%TrimR(OpenFilesInfoDS.ActivationGroupName));
   EndIf;

   yajl_AddChar('openOption' :%TrimR(OpenFilesInfoDS.OpenOption));
   yajl_AddNum('sharedOpens' :%Char(OpenFilesInfoDS.SharedOpens));
   yajl_AddNum('writeCount' :%Char(OpenFilesInfoDS.WriteCount));
   yajl_AddNum('readCount' :%Char(OpenFilesInfoDS.ReadCount));
   yajl_AddNum('writeReadCount' :%Char(OpenFilesInfoDS.WriteReadCount));
   yajl_AddNum('otherIOCount' :%Char(OpenFilesInfoDS.OtherIOCount));
   yajl_AddNum('relativeRecordNumber' :%Char(OpenFilesInfoDS.RelativeRecordNumber));

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
