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


// This cgi-exitprogram will return the informations about the selected output queues
// The following parameters are implemented:
//  - outq = Output Queue Name
//  - outqlib = Output Queue Library
//  - usr = Authorization name for spoolfile owner
//  - splf = Name for spooled file
//  - nbr = Spooled file number
//  - job = Jobname (format: 000000/user/sessionname)
//  - limit = Maximum rows to fetch


/INCLUDE QRPGLEH,GETOUTENTH


//#########################################################################
DCL-PROC Main;

 DCL-DS InputParmDS LIKEDS(InputParmDS_T) INZ;

 DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 /INCLUDE QRPGLECPY,SQLOPTIONS

 *INLR = TRUE;

 InputParmDS = getHTTPInput();

 If ( InputParmDS.Method = 'GET' );
   readOutputQueueEntriesAndCreateJSON(InputParmDS);

 Else;
   ErrorMessage = %TrimR(InputParmDS.Method) + ' not allowed';
   writeHTTPOut(%Addr(ErrorMessage) :%Len(%Trim(ErrorMessage)) + 2 :HTTP_BAD_REQUEST);

 EndIf;

 Return;

END-PROC;


//#########################################################################
// parse selected output queue informations to json and return it
DCL-PROC readOutputQueueEntriesAndCreateJSON;
 DCL-PI *N;
  pInputParmDS LIKEDS(InputParmDS_T) CONST;
 END-PI;

 DCL-DS OutputQueueEntryDS LIKEDS(OutputQueueEntryDS_T) INZ;

 DCL-S FirstRun IND INZ(TRUE);
 DCL-S ArrayItem IND INZ(FALSE);
 DCL-S EntryCount INT(10) INZ;
 DCL-S SpooledFileNumber INT(10) INZ;
 DCL-S LimitFetch INT(10) INZ(100);
 DCL-S OutQName CHAR(10) INZ;
 DCL-S OutQLib CHAR(10) INZ;
 DCL-S AuthorizationName CHAR(10);
 DCL-S SpooledFileName CHAR(12);
 DCL-S JobnameLong CHAR(28) INZ;
 DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 // retrieve parameters/values by name
 OutQName = getValueByName('outq' :pInputParmDS);
 OutQLib = getValueByName('outqlib' :pInputParmDS);
 AuthorizationName = getValueByName('usr' :pInputParmDS);
 SpooledFileName = '%' + %Trim(getValueByName('splf' :pInputParmDS)) + '%';
 JobnameLong = getValueByName('job' :pInputParmDS);

 Monitor;
   SpooledFileNumber = %Int(getValueByName('nbr' :pInputParmDS));
   On-Error;
     Reset SpooledFileNumber;
 EndMon;

 Monitor;
   LimitFetch = %Int(getValueByName('limit' :pInputParmDS));
   If ( LimitFetch <= 0 );
     Reset LimitFetch;
   EndIf;
   On-Error;
     Reset LimitFetch;
 EndMon;

 yajl_GenOpen(TRUE);
 yajl_BeginObj();

 Exec SQL DECLARE c_outq_entry_reader INSENSITIVE CURSOR FOR

           SELECT entry.output_queue_name,
                  entry.output_queue_library_name,
                  IFNULL(timestamp_iso8601(entry.create_timestamp), ''),
                  entry.spooled_file_name,
                  IFNULL(entry.user_name, ''),
                  IFNULL(entry.user_data, ''),
                  entry.status,
                  IFNULL(entry.size, 0),
                  IFNULL(entry.total_pages, 0),
                  IFNULL(entry.copies, 0),
                  IFNULL(entry.form_type, ''),
                  IFNULL(entry.job_name, ''),
                  entry.device_type,
                  entry.output_priority,
                  entry.file_number,
                  IFNULL(entry.system, '')

             FROM qsys2.output_queue_entries entry

            WHERE entry.output_queue_name =
                   CASE WHEN :OutQName = ''
                        THEN entry.output_queue_name
                        ELSE UPPER(:OutQName) END

              AND entry.output_queue_library_name =
                   CASE WHEN :OutQLib = ''
                        THEN entry.output_queue_library_name
                        ELSE UPPER(:OutQLib) END

              AND entry.user_name =
                   CASE WHEN :AuthorizationName = ''
                        THEN entry.user_name
                        ELSE UPPER(:AuthorizationName) END

              AND CAST(entry.spooled_file_name AS CHAR(12))
                   LIKE TRIM(UPPER(:SpooledFileName))

              AND entry.file_number =
                   CASE WHEN :SpooledFileNumber = 0
                        THEN entry.file_number
                        ELSE :SpooledFileNumber END

              AND entry.job_name =
                   CASE WHEN :JobnameLong = ''
                        THEN entry.job_name
                        ELSE UPPER(:JobnameLong) END

            ORDER BY entry.output_queue_library_name,
                     entry.output_queue_name,
                     CASE WHEN entry.status = 'PENDING' THEN 0
                          WHEN entry.status = 'READY' THEN 1
                          WHEN entry.status = 'HELD' THEN 2
                          ELSE 9 END,
                     entry.create_timestamp DESC

            LIMIT :LimitFetch;

 Exec SQL OPEN c_outq_entry_reader;

 Exec SQL GET DIAGNOSTICS :EntryCount = DB2_NUMBER_ROWS;

 DoW ( 1 = 1 );
   Exec SQL FETCH NEXT FROM c_outq_entry_reader INTO :OutputQueueEntryDS;
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
     Exec SQL CLOSE c_outq_entry_reader;
     Leave;
   EndIf;

   If FirstRun;
     // fill in the header informations and begin the array
     FirstRun = FALSE;
     yajl_AddBool('success' :TRUE);
     yajl_AddNum('results' :%Char(EntryCount));
     yajl_BeginArray('outputQueueEntries');
     ArrayItem = TRUE;
   EndIf;

   yajl_BeginObj();

   yajl_AddChar('outputQueueName' :%TrimR(OutputQueueEntryDS.OutputQueueName));
   yajl_AddChar('outputQueueLibrary' :%TrimR(OutputQueueEntryDS.OutputQueueLibrary));
   yajl_AddChar('createTimestamp' :%TrimR(OutputQueueEntryDS.CreateTimestamp));
   yajl_AddChar('spooledFileName' :%TrimR(OutputQueueEntryDS.SpooledFileName));
   yajl_AddChar('userName' :%TrimR(OutputQueueEntryDS.UserName));

   If ( OutputQueueEntryDS.UserData <> '' );
     yajl_AddChar('userData' :%TrimR(OutputQueueEntryDS.UserData));
   EndIf;

   yajl_AddChar('status' :%TrimR(OutputQueueEntryDS.Status));
   yajl_AddNum('size' :%Char(OutputQueueEntryDS.Size));
   yajl_AddNum('totalPages' :%Char(OutputQueueEntryDS.TotalPages));
   yajl_AddNum('copies' :%Char(OutputQueueEntryDS.Copies));

   If ( OutputQueueEntryDS.FormType <> '' );
     yajl_AddChar('formType' :%TrimR(OutputQueueEntryDS.FormType));
   EndIf;

   If ( OutputQueueEntryDS.JobName <> '' );
     yajl_AddChar('jobName' :%TrimR(OutputQueueEntryDS.JobName));
   EndIf;

   yajl_AddChar('deviceType' :%TrimR(OutputQueueEntryDS.DeviceType));
   yajl_AddNum('outputPriority' :%Char(OutputQueueEntryDS.OutputPriority));
   yajl_AddNum('fileNumber' :%Char(OutputQueueEntryDS.FileNumber));

   If ( OutputQueueEntryDS.System <> '' );
     yajl_AddChar('system' :%TrimR(OutputQueueEntryDS.System));
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
