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


// This cgi-exitprogram will return the selected history logs
// The following parameters are implemented:
//  - start = Start date
//  - end = End date
//  - msgid = message id
//  - query = string for a like query


/INCLUDE QRPGLEH,GETHSTLOGH


//#########################################################################
DCL-PROC Main;

 DCL-DS InputParmDS LIKEDS(InputParmDS_T) INZ;

 DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 /INCLUDE QRPGLECPY,SQLOPTIONS

 *INLR = TRUE;

 InputParmDS = getHTTPInput();

 If ( InputParmDS.Method = 'GET' );
   readHistoryLogInfosAndCreateJSON(InputParmDS);

 Else;
   ErrorMessage = %TrimR(InputParmDS.Method) + ' not allowed';
   writeHTTPOut(%Addr(ErrorMessage) :%Len(%Trim(ErrorMessage)) + 2 :HTTP_BAD_REQUEST);

 EndIf;

 Return;

END-PROC;


//#########################################################################
// parse selected history log information to json and return it
DCL-PROC readHistoryLogInfosAndCreateJSON;
 DCL-PI *N;
  pInputParmDS LIKEDS(InputParmDS_T) CONST;
 END-PI;

 DCL-DS HistoryLogInfoDS LIKEDS(HistoryLogInfoDS_T) INZ;

 DCL-S FirstRun IND INZ(TRUE);
 DCL-S ArrayItem IND INZ(FALSE);
 DCL-S HistoryCount INT(10) INZ;
 DCL-S StartDate TIMESTAMP INZ(*LOVAL);
 DCL-S EndDate TIMESTAMP INZ(*HIVAL);
 DCL-S MessageID CHAR(7) INZ;
 DCL-S Query CHAR(128) INZ;
 DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 // retrieve parameters/values by name
 Monitor;
   StartDate = %Timestamp(getValueByName('start' :pInputParmDS));
   On-Error;
     Reset StartDate;
 EndMon;
 Monitor;
   EndDate = %Timestamp(getValueByName('end' :pInputParmDS)) + %Days(1);
   On-Error;
     Reset EndDate;
 EndMon;
 MessageID = getValueByName('msgid' :pInputParmDS);
 Query = '%' + %TrimR(getValueByName('query' :pInputParmDS)) + '%';

 yajl_GenOpen(TRUE);
 yajl_BeginObj();

 Exec SQL DECLARE c_history_log_info_reader INSENSITIVE CURSOR FOR

           SELECT history.ordinal_position,
                  IFNULL(history.message_id, ''),
                  history.message_type,
                  history.severity,
                  IFNULL(timestamp_iso8601(history.message_timestamp), ''),
                  history.from_user,
                  history.from_job,
                  history.from_program,
                  CAST(IFNULL(history.message_text, '') AS VARCHAR(1024)),
                  CAST(IFNULL(history.message_second_level_text, '') AS VARCHAR(4096))

             FROM TABLE(qsys2.history_log_info
                         (start_time => :StartDate,
                          end_time => :EndDate)) AS history

            WHERE history.message_id =
                   CASE WHEN :MessageID = '' THEN history.message_id
                        ELSE :MessageID END
              AND LOWER(history.message_text) LIKE LOWER(TRIM(:Query));

 Exec SQL OPEN c_history_log_info_reader;

 Exec SQL GET DIAGNOSTICS :HistoryCount = DB2_NUMBER_ROWS;

 DoW ( 1 = 1 );
   Exec SQL FETCH NEXT FROM c_history_log_info_reader INTO :HistoryLogInfoDS;
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
     Exec SQL CLOSE c_history_log_info_reader;
     Leave;
   EndIf;

   If FirstRun;
     // fill in the header informations and begin the array
     FirstRun = FALSE;
     yajl_AddBool('success' :TRUE);
     yajl_AddNum('results' :%Char(HistoryCount));
     yajl_BeginArray('historyLogInfo');
     ArrayItem = TRUE;
   EndIf;

   yajl_BeginObj();

   yajl_AddNum('position' :%Char(HistoryLogInfoDS.Position));

   If ( HistoryLogInfoDS.MessageID <> '' );
     yajl_AddChar('messageID' :%TrimR(HistoryLogInfoDS.MessageID));
   EndIf;

   yajl_AddChar('messageType' :%TrimR(HistoryLogInfoDS.MessageType));
   yajl_AddNum('severity' :%Char(HistoryLogInfoDS.Severity));
   yajl_AddChar('messageTimestamp' :%TrimR(HistoryLogInfoDS.MessageTimestamp));
   yajl_AddChar('fromUser' :%TrimR(HistoryLogInfoDS.FromUser));
   yajl_AddChar('fromJob' :%TrimR(HistoryLogInfoDS.FromJob));
   yajl_AddChar('fromProgram' :%TrimR(HistoryLogInfoDS.FromProgram));

   If ( HistoryLogInfoDS.MessageText <> '' );
     yajl_AddChar('messageText' :%TrimR(HistoryLogInfoDS.MessageText));
   EndIf;

   If ( HistoryLogInfoDS.MessageTextSecondLevel <> '' );
     yajl_AddChar('messageTextSecondLevel' :%TrimR(HistoryLogInfoDS.MessageTextSecondLevel));
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
