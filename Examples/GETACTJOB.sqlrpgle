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
//  - jobsts = Job status (msgw etc)
//  - fct = current running function (STRSQL etc)


/INCLUDE QRPGLECPY,H_SPECS
CTL-OPT MAIN(Main) BNDDIR('CGISRVR1' :'YAJL');

DCL-PR Main EXTPGM('GETACTJOB') END-PR;

/INCLUDE QRPGLEH,CGISRVR1_H
/INCLUDE QRPGLESRC,YAJL_H
/INCLUDE QRPGLECPY,BOOLIC
/INCLUDE QRPGLECPY,SYSTEM

DCL-DS JobInfoDS_T QUALIFIED TEMPLATE;
 OrdinalPosition INT(10);
 Subsystem CHAR(10);
 JobName VARCHAR(28);
 JobType CHAR(3);
 JobStatus CHAR(4);
 AuthorizationName CHAR(10);
 AuthorizationDescription VARCHAR(50);
 FunctionType CHAR(3);
 Function CHAR(10);
 RunPriority INT(10);
 TemporaryStorage INT(10);
END-DS;


//#########################################################################
DCL-PROC Main;

 DCL-DS InputParmDS LIKEDS(InputParmDS_T) INZ;
 DCL-DS JobInfoDS LIKEDS(JobInfoDS_T) INZ;

 DCL-S IndexSubSystem INT(5) INZ;
 DCL-S IndexAuthorityName INT(5) INZ;
 DCL-S IndexJobStatus INT(5) INZ;
 DCL-S IndexFunction INT(5) INZ;
 DCL-S YajlError VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 /INCLUDE QRPGLECPY,SQLOPTIONS

 *INLR = TRUE;

 InputParmDS = getHTTPInput();

 If ( InputParmDS.Method = 'GET' );
   // retrieve parameters from http-srv
   IndexSubSystem = %Lookup('sbs' :InputParmDS.SeperatedKeysDS(*).Field);
   IndexAuthorityName = %Lookup('usr' :InputParmDS.SeperatedKeysDS(*).Field);
   IndexJobStatus = %Lookup('jobsts' :InputParmDS.SeperatedKeysDS(*).Field);
   IndexFunction = %Lookup('fct' :InputParmDS.SeperatedKeysDS(*).Field);

   yajl_GenOpen(TRUE);
   
   // read job-information and generate json-stream
   generateJSONStream(IndexSubSystem 
                      :IndexAuthorityName 
                      :IndexJobStatus 
                      :IndexFunction
                      :InputParmDS);
   
   // return json stream to http-srv
   yajl_WriteStdOut(200 :YajlError);
   
   yajl_GenClose();

 EndIf;

 Return;

END-PROC;


//#########################################################################
// parse selected jobs to json and return it
DCL-PROC generateJSONStream;
 DCL-PI *N;
  pIndexSubsystem INT(5) CONST;
  pIndexAuthorityName INT(5) CONST;
  pIndexJobStatus INT(5) CONST;
  pIndexFunction INT(5) CONST;
  pInputParmDS LIKEDS(InputParmDS_T) CONST;
 END-PI;

 DCL-DS JobInfoDS LIKEDS(JobInfoDS_T) INZ;

 DCL-S FirstRun IND INZ(TRUE);
 DCL-S ArrayItem IND INZ(FALSE);
 DCL-S YajlError VARCHAR(500) INZ;
 DCL-S Subsystem CHAR(10) INZ;
 DCL-S AuthorizationName CHAR(10) INZ;
 DCL-S JobStatus CHAR(4) INZ;
 DCL-S Function CHAR(10) INZ;
 //------------------------------------------------------------------------

 If ( pIndexSubsystem > 0 );
   Subsystem = pInputParmDS.SeperatedKeysDS(pIndexSubSystem).ExtractedValue;
 EndIf;

 If ( pIndexAuthorityName > 0 );
   AuthorizationName = pInputParmDS.SeperatedKeysDS(pIndexAuthorityName).ExtractedValue;
 EndIf;

 If ( pIndexJobStatus > 0 );
   JobStatus = pInputParmDS.SeperatedKeysDS(pIndexJobStatus).ExtractedValue;
 EndIf;

 If ( pIndexFunction > 0 );
   Function = pInputParmDS.SeperatedKeysDS(pIndexFunction).ExtractedValue;
 EndIf;

 yajl_BeginObj();

 Exec SQL DECLARE c_active_jobs_reader CURSOR FOR

           SELECT jobs.ordinal_position,
                  IFNULL(jobs.subsystem, ''),
                  IFNULL(jobs.job_name, ''),
                  IFNULL(jobs.job_type, ''),
                  IFNULL(jobs.job_status, ''),
                  IFNULL(jobs.authorization_name, ''),
                  IFNULL(user_info.text_description, ''),
                  IFNULL(jobs.function_type, ''),
                  IFNULL(jobs.function, ''),
                  IFNULL(jobs.run_priority, 0),
                  IFNULL(jobs.temporary_storage, 0)

             FROM TABLE(qsys2.active_job_info()) AS jobs

             LEFT JOIN qsys2.user_info
               ON (user_info.authorization_name = jobs.authorization_name)

            WHERE jobs.subsystem = CASE WHEN :Subsystem = ''
                                        THEN jobs.subsystem
                                        ELSE UPPER(:Subsystem) END

              AND jobs.authorization_name = CASE WHEN :AuthorizationName = ''
                                                 THEN jobs.authorization_name
                                                 ELSE UPPER(:AuthorizationName) END

              AND jobs.job_status = CASE WHEN :JobStatus = ''
                                         THEN jobs.job_status
                                         ELSE RTRIM(UPPER(:JobStatus)) END
              
              AND jobs.function = CASE WHEN :Function = ''
                                       THEN jobs.function
                                       ELSE RTRIM(UPPER(:Function)) END

            ORDER BY jobs.ordinal_position;

 Exec SQL OPEN c_active_jobs_reader;

 DoW ( 1 = 1 );
   Exec SQL FETCH NEXT FROM c_active_jobs_reader INTO :JobInfoDS;
   If ( SQLCode <> 0 );
     If FirstRun;
       Exec SQL GET DIAGNOSTICS CONDITION 1 :YajlError = MESSAGE_TEXT;
       yajl_AddBool('success' :'0');
       yajl_AddChar('errorMessage' :%TrimR(YajlError));
     EndIf;
     Exec SQL CLOSE c_active_jobs_reader;
     Leave;
   EndIf;

   If FirstRun;
     FirstRun= FALSE;
     yajl_AddBool('success' :'1');
     yajl_BeginArray('activeJobInfo');
     ArrayItem = TRUE;
   EndIf;

   yajl_BeginObj();
   yajl_AddNum('ordinalPosition' :%Char(JobInfoDS.OrdinalPosition));
   yajl_AddChar('subSystem' :%TrimR(JobInfoDS.Subsystem));
   yajl_AddChar('jobName' :%TrimR(JobInfoDS.JobName));
   yajl_AddChar('jobType' :%TrimR(JobInfoDS.JobType));
   yajl_AddChar('jobStatus' :%TrimR(JobInfoDS.JobStatus));
   yajl_AddChar('authorizationName' :%TrimR(JobInfoDS.AuthorizationName));
   yajl_AddChar('authorizationDescription' :%TrimR(JobInfoDS.AuthorizationDescription));
   If ( JobInfoDS.FunctionType <> '' );
     yajl_AddChar('functionType' :%TrimR(JobInfoDS.FunctionType));
   EndIf;
   If ( JobInfoDS.Function <> '' );
     yajl_AddChar('function' :%TrimR(JobInfoDS.Function));
   EndIf;
   yajl_AddNum('runPriority' :%Char(JobInfoDS.RunPriority));
   yajl_AddNum('temporaryStorage' :%Char(JobInfoDS.TemporaryStorage));
   yajl_EndObj();

 EndDo;

 If ArrayItem;
   yajl_EndArray();
 EndIf;

 yajl_EndObj();

 Return;

END-PROC;
