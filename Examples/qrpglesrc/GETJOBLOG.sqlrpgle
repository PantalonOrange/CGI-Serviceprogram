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


// This cgi-exitprogram will return the selected job log for the selected job
// The following parameters are implemented:
//  - job = Jobname (format: 000000/user/sessionname)
//  - msgid = MessageID
//  - msgtyp = Messagetype (informational etc)
//  - sev = Severity (0 to 99)
//  - frmpgm = Program
//  - limit = Number of rows to fetch (default = 10)


/INCLUDE QRPGLEH,GETJOBLOGH


//#########################################################################
DCL-PROC Main;

 DCL-DS InputParmDS LIKEDS(InputParmDS_T) INZ;

 DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 /INCLUDE QRPGLECPY,SQLOPTIONS

 *INLR = TRUE;

 InputParmDS = getHTTPInput();

 If ( InputParmDS.Method = 'GET' );
   readJobLogInfosAndCreateJSON(InputParmDS);

 Else;
   ErrorMessage = %TrimR(InputParmDS.Method) + ' not allowed';
   writeHTTPOut(%Addr(ErrorMessage) :%Len(%Trim(ErrorMessage)) + 2 :HTTP_BAD_REQUEST);

 EndIf;

 Return;

END-PROC;


//#########################################################################
// parse selected job log information to json and return it
DCL-PROC readJobLogInfosAndCreateJSON;
 DCL-PI *N;
  pInputParmDS LIKEDS(InputParmDS_T) CONST;
 END-PI;

 DCL-DS JobLogInfoDS LIKEDS(JobLogInfoDS_T) INZ;

 DCL-S FirstRun IND INZ(TRUE);
 DCL-S ArrayItem IND INZ(FALSE);
 DCL-S JobLogCount INT(10) INZ;
 DCL-S LimitFetch INT(10) INZ(10);
 DCL-S JobName CHAR(28);
 DCL-S MessageID CHAR(7) INZ;
 DCL-S MessageType CHAR(13) INZ;
 DCL-S Severity INT(10) INZ(-1);
 DCL-S FromProgram CHAR(256) INZ;
 DCL-S Base64EncodedString CHAR(32000) INZ;
 DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 // retrieve parameters/values by name
 JobName = getValueByName('job' :pInputParmDS);
 If ( JobName = '' );
   JobName = '*';
 EndIf;
 MessageID = getValueByName('msgid' :pInputParmDS);
 MessageType = getValueByName('msgtyp' :pInputParmDS);
 Monitor;
   Severity = %Int(getValueByName('sev' :pInputParmDS));
   On-Error;
     Reset Severity;
 EndMon;
 FromProgram = getValueByName('frmpgm' :pInputParmDS);

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

 Exec SQL DECLARE c_joblog_info_reader INSENSITIVE CURSOR FOR

           SELECT joblog.ordinal_position,
                  IFNULL(joblog.message_id, ''),
                  IFNULL(joblog.message_type, ''),
                  IFNULL(joblog.message_subtype, ''),
                  joblog.severity,
                  IFNULL(timestamp_iso8601(joblog.message_timestamp), ''),
                  IFNULL(joblog.from_library, ''),
                  IFNULL(joblog.from_program, ''),
                  IFNULL(joblog.from_module, ''),
                  IFNULL(joblog.from_procedure, ''),
                  IFNULL(joblog.from_instruction, ''),
                  IFNULL(joblog.to_library, ''),
                  IFNULL(joblog.to_program, ''),
                  IFNULL(joblog.to_module, ''),
                  IFNULL(joblog.to_procedure, ''),
                  IFNULL(joblog.to_instruction, ''),
                  IFNULL(joblog.from_user, ''),
                  CAST(IFNULL(joblog.message_text, '') AS VARCHAR(1024)),
                  CAST(IFNULL(joblog.message_second_level_text, '') AS VARCHAR(4096)),
                  IFNULL(CAST(joblog.message_key AS CHAR(10)), '')

             FROM TABLE(qsys2.joblog_info
                         (job_name => TRIM(:JobName))) AS joblog

            WHERE joblog.message_id =
                   CASE WHEN :MessageID = '' THEN joblog.message_id
                        ELSE :MessageID END
              AND joblog.message_type =
                   CASE WHEN :MessageType = '' THEN joblog.message_type
                        ELSE :MessageType END
              AND joblog.severity =
                   CASE WHEN :Severity = -1 THEN joblog.severity
                        ELSE :Severity END
              AND joblog.from_program =
                   CASE WHEN :FromProgram = '' THEN joblog.from_program
                        ELSE :FromProgram END
            ORDER BY joblog.ordinal_position DESC
            LIMIT :LimitFetch;

 Exec SQL OPEN c_joblog_info_reader;

 Exec SQL GET DIAGNOSTICS :JobLogCount = DB2_NUMBER_ROWS;

 DoW ( 1 = 1 );
   Exec SQL FETCH NEXT FROM c_joblog_info_reader INTO :JobLogInfoDS;
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
     Exec SQL CLOSE c_joblog_info_reader;
     Leave;
   EndIf;

   If FirstRun;
     // fill in the header informations and begin the array
     FirstRun = FALSE;
     yajl_AddBool('success' :TRUE);
     yajl_AddNum('results' :%Char(JobLogCount));
     yajl_BeginArray('jobLogInfo');
     ArrayItem = TRUE;
   EndIf;

   yajl_BeginObj();

   yajl_AddNum('position' :%Char(JobLogInfoDS.Position));

   If ( JobLogInfoDS.MessageID <> '' );
     yajl_AddChar('messageID' :%TrimR(JobLogInfoDS.MessageID));
   EndIf;

   If ( JobLogInfoDS.MessageType <> '' );
     yajl_AddChar('messageType' :%TrimR(JobLogInfoDS.MessageType));
   EndIf;

   If ( JobLogInfoDS.MessageSubType <> '' );
     yajl_AddChar('messageSubType' :%TrimR(JobLogInfoDS.MessageID));
   EndIf;

   If ( JobLogInfoDS.Severity <> -1 );
     yajl_AddNum('severity' :%Char(JobLogInfoDS.Severity));
   EndIf;

   If ( JobLogInfoDS.MessageTimestamp <> '' );
     yajl_AddChar('messageTimestamp' :%TrimR(JobLogInfoDS.MessageTimestamp));
   EndIf;

   If ( JobLogInfoDS.FromLibrary <> '' );
     yajl_AddChar('fromLibrary' :%TrimR(JobLogInfoDS.FromLibrary));
   EndIf;

   If ( JobLogInfoDS.FromProgram <> '' );
     yajl_AddChar('fromProgram' :%TrimR(JobLogInfoDS.FromProgram));
   EndIf;

   If ( JobLogInfoDS.FromModule <> '' );
     yajl_AddChar('fromModule' :%TrimR(JobLogInfoDS.FromModule));
   EndIf;

   If ( JobLogInfoDS.FromProcedure <> '' );
     yajl_AddChar('fromProcedure' :%TrimR(JobLogInfoDS.FromProcedure));
   EndIf;

   If ( JobLogInfoDS.FromInstruction <> '' );
     yajl_AddChar('fromInstruction' :%TrimR(JobLogInfoDS.FromInstruction));
   EndIf;

   If ( JobLogInfoDS.ToLibrary <> '' );
     yajl_AddChar('toLibrary' :%TrimR(JobLogInfoDS.ToLibrary));
   EndIf;

   If ( JobLogInfoDS.ToProgram <> '' );
     yajl_AddChar('toProgram' :%TrimR(JobLogInfoDS.ToProgram));
   EndIf;

   If ( JobLogInfoDS.ToModule <> '' );
     yajl_AddChar('toModule' :%TrimR(JobLogInfoDS.ToModule));
   EndIf;

   If ( JobLogInfoDS.ToProcedure <> '' );
     yajl_AddChar('toProcedure' :%TrimR(JobLogInfoDS.ToProcedure));
   EndIf;

   If ( JobLogInfoDS.ToInstruction <> '' );
     yajl_AddChar('toInstruction' :%TrimR(JobLogInfoDS.ToInstruction));
   EndIf;

   If ( JobLogInfoDS.FromUser <> '' );
     yajl_AddChar('fromUser' :%TrimR(JobLogInfoDS.FromUser));
   EndIf;

   If ( JobLogInfoDS.MessageText <> '' );
     yajl_AddChar('messageText' :%TrimR(JobLogInfoDS.MessageText));
   EndIf;

   If ( JobLogInfoDS.MessageTextSecondLevel <> '' );
     yajl_AddChar('messageTextSecondLevel' :%TrimR(JobLogInfoDS.MessageTextSecondLevel));
   EndIf;

   If ( JobLogInfoDS.MessageKey <> '' );
     // encode the message key to base64
     Base64EncodedString = encodeBase64(%Addr(JobLogInfoDS.MessageKey)
                                        :%Len(%TrimR(JobLogInfoDS.MessageKey)));
     If ( Base64EncodedString <> '' );
       yajl_AddChar('messageKey' :%TrimR(Base64EncodedString));
     EndIf;

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
