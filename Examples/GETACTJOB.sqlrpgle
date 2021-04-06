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


// This cgi-exitprogram will retourn the selected job-informations
// The following parameters are implemented:
//  - sbs = Subsystem
//  - usr = Authorization_Name (user)
//  - job = Jobname (format: 000000/user/job)
//  - jobtype = Job type (int, bch etc)
//  - jobsts = Job status (msgw etc)
//  - fct = current running function (STRSQL etc)
//  - clientip = Client ip address


/INCLUDE QRPGLEH,GETACTJOBH


//#########################################################################
DCL-PROC Main;

 DCL-DS InputParmDS LIKEDS(InputParmDS_T) INZ;

 DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 /INCLUDE QRPGLECPY,SQLOPTIONS

 *INLR = TRUE;

 InputParmDS = getHTTPInput();

 If ( InputParmDS.Method = 'GET' );

   yajl_GenOpen(TRUE);

   // read job-information and generate json-stream
   readJobsAndCreateJSON(InputParmDS);

   // return json stream to http-srv
   yajl_WriteStdOut(200 :ErrorMessage);

   yajl_GenClose();

 ElseIf ( InputParmDS.Method = 'POST' );

    yajl_GenOpen(TRUE);

   handleIncommingPostData(InputParmDS);

   yajl_WriteStdOut(200 :ErrorMessage);

   yajl_GenClose();

 ElseIf ( InputParmDS.Method = 'DELETE' );
   yajl_GenOpen(TRUE);

   // end job immed
   endSelectedJob(InputParmDS);

   yajl_WriteStdOut(200 :ErrorMessage);

   yajl_GenClose();

 Else;
   ErrorMessage = %TrimR(InputParmDS.Method) + ' not allowed';
   writeHTTPOut(%Addr(ErrorMessage) :%Len(%Trim(ErrorMessage)) + 2 :HTTP_BAD_REQUEST);

 EndIf;

 Return;

END-PROC;


//#########################################################################
// parse selected jobs to json and return it
DCL-PROC readJobsAndCreateJSON;
 DCL-PI *N;
  pInputParmDS LIKEDS(InputParmDS_T) CONST;
 END-PI;

 DCL-DS JobInfoDS LIKEDS(JobInfoDS_T) INZ;

 DCL-S FirstRun IND INZ(TRUE);
 DCL-S ArrayItem IND INZ(FALSE);
 DCL-S JobCount INT(10) INZ;
 DCL-S Subsystem CHAR(10) INZ;
 DCL-S AuthorizationName CHAR(10) INZ;
 DCL-S JobName VARCHAR(28) INZ;
 DCL-S JobType CHAR(3) INZ;
 DCL-S JobStatus CHAR(4) INZ;
 DCL-S Function CHAR(10) INZ;
 DCL-S ClientIPAddress VARCHAR(45) INZ;
 DCL-S Base64EncodedString CHAR(32000) INZ;
 DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 // retrieve parameters/values by name
 Subsystem = getValueByName('sbs' :pInputParmDS);
 AuthorizationName = getValueByName('usr' :pInputParmDS);
 JobName = %TrimR(getValueByName('job' :pInputParmDS));
 JobType = getValueByName('jobtype' :pInputParmDS);
 JobStatus = getValueByName('jobsts' :pInputParmDS);
 Function = getValueByName('fct' :pInputParmDS);
 ClientIPAddress = %TrimR(getValueByName('clientip' :pInputParmDS));

 yajl_BeginObj();

 Exec SQL DECLARE c_active_jobs_reader INSENSITIVE CURSOR FOR

           SELECT jobs.ordinal_position,
                  IFNULL(jobs.subsystem, ''),
                  IFNULL(jobs.job_name, ''),
                  IFNULL(jobs.job_type, ''),
                  IFNULL(jobs.job_status, ''),
                  CASE WHEN jobs.job_status = 'MSGW'
                       THEN IFNULL((SELECT joblog.message_text
                                      FROM TABLE(qsys2.joblog_info(jobs.job_name)) AS joblog
                                     WHERE joblog.message_type = 'SENDER'
                                     ORDER BY joblog.ordinal_position DESC LIMIT 1), '')
                       ELSE '' END,
                  CASE WHEN jobs.job_status = 'MSGW'
                       THEN IFNULL((SELECT CAST(msgq.message_key AS CHAR(4))
                                      FROM qsys2.message_queue_info msgq
                                     WHERE msgq.message_queue_name = 'QSYSOPR'
                                       AND msgq.message_type = 'INQUIRY'
                                       AND msgq.from_job = jobs.job_name
                                     ORDER BY msgq.message_timestamp DESC LIMIT 1), '')
                        ELSE '' END,
                  IFNULL(jobs.authorization_name, ''),
                  IFNULL(user_info.text_description, ''),
                  IFNULL(jobs.function_type, ''),
                  IFNULL(jobs.function, ''),
                  IFNULL(jobs.temporary_storage, 0),
                  IFNULL(jobs.client_ip_address, ''),
                  timestamp_iso8601(IFNULL(jobs.job_active_time, CURRENT_TIMESTAMP))

             FROM TABLE(qsys2.active_job_info(detailed_info => 'ALL')) AS jobs

             LEFT JOIN qsys2.user_info
               ON (user_info.authorization_name = jobs.authorization_name)

               -- fetch with subsystem name or all
            WHERE jobs.subsystem = CASE WHEN :Subsystem = ''
                                        THEN jobs.subsystem
                                        ELSE UPPER(:Subsystem) END

               -- fetch with user name or all
              AND jobs.authorization_name = CASE WHEN :AuthorizationName = ''
                                                 THEN jobs.authorization_name
                                                 ELSE UPPER(:AuthorizationName) END

               -- fetch with job name or all
              AND jobs.job_name = CASE WHEN :JobName = ''
                                       THEN jobs.job_name
                                       ELSE UPPER(:JobName) END

               -- fetch with job type or all
              AND jobs.job_type = CASE WHEN :JobType = ''
                                       THEN jobs.job_type
                                       ELSE UPPER(:JobType) END

               -- fetch with job status or all
              AND jobs.job_status = CASE WHEN :JobStatus = ''
                                         THEN jobs.job_status
                                         ELSE RTRIM(UPPER(:JobStatus)) END

               -- fetch with currently used function or all
              AND IFNULL(jobs.function, '') = CASE WHEN :Function = ''
                                                   THEN IFNULL(jobs.function, '')
                                                   ELSE RTRIM(UPPER(:Function)) END

               -- fetch with client ip address or all
              AND IFNULL(jobs.client_ip_address, '')
                = CASE WHEN :ClientIPAddress = ''
                       THEN IFNULL(jobs.client_ip_address, '')
                       ELSE :ClientIPAddress END

            ORDER BY jobs.ordinal_position;

 Exec SQL OPEN c_active_jobs_reader;

 Exec SQL GET DIAGNOSTICS :JobCount = DB2_NUMBER_ROWS;

 DoW ( 1 = 1 );
   Exec SQL FETCH NEXT FROM c_active_jobs_reader INTO :JobInfoDS;
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
     Exec SQL CLOSE c_active_jobs_reader;
     Leave;
   EndIf;

   If FirstRun;
     // fill in the header informations and begin the array
     FirstRun = FALSE;
     yajl_AddBool('success' :TRUE);
     yajl_AddNum('results' :%Char(JobCount));
     yajl_BeginArray('activeJobInfo');
     ArrayItem = TRUE;
   EndIf;

   yajl_BeginObj();

   yajl_AddNum('ordinalPosition' :%Char(JobInfoDS.OrdinalPosition));
   yajl_AddChar('subSystem' :%TrimR(JobInfoDS.Subsystem));
   yajl_AddChar('jobName' :%TrimR(JobInfoDS.JobName));
   yajl_AddChar('jobType' :%TrimR(JobInfoDS.JobType));
   yajl_AddChar('jobStatus' :%TrimR(JobInfoDS.JobStatus));

   If ( JobInfoDS.JobMessage <> '' );
     yajl_AddChar('jobMessage' :%TrimR(JobInfoDS.JobMessage));

     If ( JobInfoDS.MessageKey <> '' );
       // encode the message key to base64
       Base64EncodedString = encodeBase64(%Addr(JobInfoDS.MessageKey)
                                          :%Len(%TrimR(JobInfoDS.MessageKey)));

       If ( Base64EncodedString <> '' );
         yajl_AddChar('messageKey' :%TrimR(Base64EncodedString));
      EndIf;

     EndIf;

   EndIf;

   yajl_AddChar('authorizationName' :%TrimR(JobInfoDS.AuthorizationName));
   yajl_AddChar('authorizationDescription' :%TrimR(JobInfoDS.AuthorizationDescription));

   If ( JobInfoDS.FunctionType <> '' );
     yajl_AddChar('functionType' :%TrimR(JobInfoDS.FunctionType));
   EndIf;

   If ( JobInfoDS.Function <> '' );
     yajl_AddChar('function' :%TrimR(JobInfoDS.Function));
   EndIf;

   yajl_AddNum('temporaryStorage' :%Char(JobInfoDS.TemporaryStorage));

   If ( JobInfoDS.ClientIPAddress <> '' );
     yajl_AddChar('clientIPAddress' :%TrimR(JobInfoDS.ClientIPAddress));
   EndIf;

   yajl_AddChar('jobActiveTime' :%TrimR(JobInfoDS.JobActiveTime));

   yajl_EndObj();

 EndDo;

 If ArrayItem;
   yajl_EndArray();
 EndIf;

 yajl_EndObj();

 Return;

END-PROC;

//#########################################################################
// handle incoming data from post method
//  available methods:
//   - replyList: reply to message-waits
DCL-PROC handleIncommingPostData;
 DCL-PI *N;
  pInputParmDS LIKEDS(InputParmDS_T) CONST;
 END-PI;

 /INCLUDE QRPGLECPY,QMHSNDRM

 DCL-DS ErrorDS LIKEDS(ErrorDS_T);

 DCL-S NodeTree LIKE(Yajl_Val) INZ;
 DCL-S ReplyList LIKE(Yajl_Val) INZ;
 DCL-S Val Like(Yajl_Val) INZ;
 DCL-S Success IND INZ(TRUE);
 DCL-S Index INT(10) INZ;
 DCL-S MessageKey CHAR(10) INZ;
 DCL-S Reply CHAR(10) INZ;
 DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 If ( pInputParmDS.Data <> *NULL );
   translateData(pInputParmDS.Data :pInputParmDS.DataLength :UTF8 :0);
   NodeTree = yajl_Buf_Load_Tree(pInputParmDS.Data :pInputParmDS.DataLength :ErrorMessage);

   Success = ( NodeTree <> *NULL );

   If Success;
     ReplyList = yajl_Object_Find(NodeTree :'replyList');
    // reply to message waits with submitted message key and reply

     If ( ReplyList <> *NULL );

       DoW yajl_Array_Loop(ReplyList :Index :NodeTree);

         Val = yajl_Object_Find(NodeTree :'messageKey');
         If ( Val <> *NULL );
           MessageKey = yajl_Get_String(Val);
           MessageKey = %TrimR(decodeBase64(%Addr(MessageKey)));
           Success = ( MessageKey <> '' );
         EndIf;

        If Success;
           Val = yajl_Object_Find(NodeTree :'replyMessage');
           If ( Val <> *NULL );
             Reply = yajl_Get_String(Val);
           EndIf;
           Success = ( Reply <> '' );
         EndIf;

         If Success And ( MessageKey <> '' ) And ( Reply <> '' );
           // finaly reply to the selected message
           sendReplyMessage(%SubSt(MessageKey :1 :4) :'QSYSOPR   QSYS'
                            :%Addr(Reply) :%Len(%TrimR(Reply))
                            :'*NO' :ErrorDS);
           If ( ErrorDS.BytesAvailable > 0 );
             Success = FALSE;
             ErrorMessage = %SubSt(ErrorDS.MessageData :1 :ErrorDS.BytesAvailable);
           EndIf;

         Else;
           Success = FALSE;
           ErrorMessage = 'messageKey or replyMessage wrong/empty.';

         EndIf;

       EndDo;

     EndIf;

   EndIf;

 EndIf;

 yajl_BeginObj();

 yajl_AddBool('success' :Success);
 If Not Success;
   yajl_AddChar('errorMessage' :%TrimR(ErrorMessage));
 EndIf;

 yajl_EndObj();

 Return;

END-PROC;


//#########################################################################
// end selected job immed
DCL-PROC endSelectedJob;
 DCL-PI *N;
  pInputParmDS LIKEDS(InputParmDS_T) CONST;
 END-PI;

 /INCLUDE QRPGLECPY,SYSTEM

 DCL-S RC INT(10) INZ(-1);
 DCL-S JobName VARCHAR(28) INZ;
 DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 // retrieve parameters/values by name
 JobName = getValueByName('job' :pInputParmDS);

 If ( JobName <> '' );
   // simple endjob *immed
   RC = system('ENDJOB JOB(' + %TrimR(JobName) + ') OPTION(*IMMED)');
 EndIf;

 yajl_BeginObj();

 yajl_AddBool('success' :(RC = 0));

 If ( RC <> 0 );
   yajl_AddChar('errorMessage' :'Job not found or access denied.');
 EndIf;

 yajl_EndObj();

 Return;

END-PROC;
