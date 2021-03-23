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
//  - jobsts = Job status (msgw etc)
//  - fct = current running function (STRSQL etc)


/INCLUDE QRPGLEH,GETACTJOBH


//#########################################################################
DCL-PROC Main;

 DCL-DS InputParmDS LIKEDS(InputParmDS_T) INZ;
 DCL-DS JobInfoDS LIKEDS(JobInfoDS_T) INZ;

 DCL-S IndexSubSystem INT(5) INZ;
 DCL-S IndexAuthorityName INT(5) INZ;
 DCL-S IndexJobStatus INT(5) INZ;
 DCL-S IndexFunction INT(5) INZ;
 DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 /INCLUDE QRPGLECPY,SQLOPTIONS

 *INLR = TRUE;

 InputParmDS = getHTTPInput();

 If ( InputParmDS.Method = 'GET' );

   yajl_GenOpen(TRUE);

   // read job-information and generate json-stream
   generateJSONStream(InputParmDS);

   // return json stream to http-srv
   yajl_WriteStdOut(200 :ErrorMessage);

   yajl_GenClose();

 Else;
   ErrorMessage = %TrimR(InputParmDS.Method) + ' not allowed';
   writeHTTPOut(%Addr(ErrorMessage) :%Len(%Trim(ErrorMessage)) :HTTP_BAD_REQUEST);

 EndIf;

 Return;

END-PROC;


//#########################################################################
// parse selected jobs to json and return it
DCL-PROC generateJSONStream;
 DCL-PI *N;
  pInputParmDS LIKEDS(InputParmDS_T) CONST;
 END-PI;

 DCL-DS JobInfoDS LIKEDS(JobInfoDS_T) INZ;

 DCL-S FirstRun IND INZ(TRUE);
 DCL-S ArrayItem IND INZ(FALSE);
 DCL-S ErrorMessage VARCHAR(500) INZ;
 DCL-S JobCount INT(10) INZ;
 DCL-S Subsystem CHAR(10) INZ;
 DCL-S AuthorizationName CHAR(10) INZ;
 DCL-S JobName VARCHAR(28) INZ;
 DCL-S JobStatus CHAR(4) INZ;
 DCL-S Function CHAR(10) INZ;
 //------------------------------------------------------------------------

 Subsystem = getValueByName('sbs' :pInputParmDS);
 AuthorizationName = getValueByName('usr' :pInputParmDS);
 JobName = getValueByName('job' :pInputParmDS);
 JobStatus = getValueByName('jobsts' :pInputParmDS);
 Function = getValueByName('fct' :pInputParmDS);

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

            WHERE jobs.subsystem = CASE WHEN :Subsystem = ''
                                        THEN jobs.subsystem
                                        ELSE UPPER(:Subsystem) END

              AND jobs.authorization_name = CASE WHEN :AuthorizationName = ''
                                                 THEN jobs.authorization_name
                                                 ELSE UPPER(:AuthorizationName) END

              AND jobs.job_name = CASE WHEN :JobName = ''
                                       THEN jobs.job_name
                                       ELSE UPPER(:JobName) END

              AND jobs.job_status = CASE WHEN :JobStatus = ''
                                         THEN jobs.job_status
                                         ELSE RTRIM(UPPER(:JobStatus)) END

              AND jobs.function = CASE WHEN :Function = ''
                                       THEN jobs.function
                                       ELSE RTRIM(UPPER(:Function)) END

            ORDER BY jobs.ordinal_position;

 Exec SQL OPEN c_active_jobs_reader;

 Exec SQL GET DIAGNOSTICS :JobCount = DB2_NUMBER_ROWS;

 DoW ( 1 = 1 );
   Exec SQL FETCH NEXT FROM c_active_jobs_reader INTO :JobInfoDS;
   If ( SQLCode <> 0 );
     If FirstRun;
       Exec SQL GET DIAGNOSTICS CONDITION 1 :ErrorMessage = MESSAGE_TEXT;
       yajl_AddBool('success' :FALSE);
       yajl_AddChar('errorMessage' :%Trim(ErrorMessage));
     EndIf;
     Exec SQL CLOSE c_active_jobs_reader;
     Leave;
   EndIf;

   If FirstRun;
     FirstRun= FALSE;
     yajl_AddBool('success' :TRUE);
     yajl_AddNum('jobCount' :%Char(JobCount));
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
