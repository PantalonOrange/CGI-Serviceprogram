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


// This cgi-exitprogram will return the informations about jobqueues
// The following parameters are implemented:
//  - jobq - Jobqueue name
//  - jobqlib - Jobqueue library
//  - sbs - Corresponding subsystem


/INCLUDE QRPGLEH,GETJOBQUIH


//#########################################################################
DCL-PROC Main;

 DCL-DS InputParmDS LIKEDS(InputParmDS_T) INZ;

 DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 /INCLUDE QRPGLECPY,SQLOPTIONS

 *INLR = TRUE;

 InputParmDS = getHTTPInput();

 If ( InputParmDS.Method = 'GET' );
   readJobQueueInfosAndCreateJSON(InputParmDS);

 Else;
   ErrorMessage = %TrimR(InputParmDS.Method) + ' not allowed';
   writeHTTPOut(%Addr(ErrorMessage) :%Len(%Trim(ErrorMessage)) + 2 :HTTP_BAD_REQUEST);

 EndIf;

 Return;

END-PROC;


//#########################################################################
// parse selected job queue informations to json and return it
DCL-PROC readJobQueueInfosAndCreateJSON;
 DCL-PI *N;
  pInputParmDS LIKEDS(InputParmDS_T) CONST;
 END-PI;

 DCL-DS JobQueueInfoDS LIKEDS(JobQueueInfoDS_T) INZ;

 DCL-S FirstRun IND INZ(TRUE);
 DCL-S ArrayItem IND INZ(FALSE);
 DCL-S JobQueueCount INT(10) INZ;
 DCL-S JobQueueName CHAR(10) INZ;
 DCL-S JobQueueLibrary CHAR(10) INZ;
 DCL-S CorrespondingSubsystem CHAR(10) INZ;
 DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 // retrieve parameters/values by name
 JobQueueName = getValueByName('jobq' :pInputParmDS);
 JobQueueLibrary = getValueByName('jobqlib' :pInputParmDS);
 CorrespondingSubsystem = getValueByName('sbs' :pInputParmDS);

 yajl_GenOpen(TRUE);
 yajl_BeginObj();

 Exec SQL declare c_jobqueue_info_reader insensitive cursor for

           select row_number() over() rownumber,
                    jobq.job_queue_name,
                    jobq.job_queue_library,
                    jobq.job_queue_status,
                    jobq.number_of_jobs,
                    ifnull(jobq.subsystem_name, ''),
                    ifnull(jobq.subsystem_library_name, ''),
                    ifnull(jobq.sequence_number, 0),
                    ifnull(jobq.maximum_active_jobs, 0),
                    ifnull(jobq.active_jobs, 0),
                    jobq.held_jobs,
                    jobq.released_jobs,
                    jobq.scheduled_jobs,
                    ifnull(jobq.text_description, '')

             from qsys2.job_queue_info jobq

            where jobq.job_queue_name =
                    case when :JobqueueName = '' then jobq.job_queue_name
                          else upper(:JobqueueName) end
              and jobq.job_queue_library =
                    case when :JobQueueLibrary = '' then jobq.job_queue_library
                          else upper(:JobQueueLibrary) end
              and jobq.subsystem_name =
                    case when :CorrespondingSubsystem = '' then jobq.subsystem_name
                          else upper(:CorrespondingSubsystem) end
            order by jobq.sequence_number;

 Exec SQL open c_jobqueue_info_reader;

 Exec SQL get diagnostics :JobQueueCount = db2_number_rows;

 DoW ( 1 = 1 );
   Exec SQL fetch next from c_jobqueue_info_reader into :JobQueueInfoDS;
   If ( SQLCode <> 0 );
     If FirstRun;
       // EOF or other errors
       yajl_AddBool('success' :FALSE);
       If ( SQLCode = 100 );
         ErrorMessage = 'Your request did not produce a result';
       Else;
         Exec SQL get diagnostics condition 1 :ErrorMessage = message_text;
       EndIf;
       yajl_AddChar('errorMessage' :%Trim(ErrorMessage));
     EndIf;
     Leave;
   EndIf;

   If FirstRun;
     // fill in the header informations and begin the array
     FirstRun = FALSE;
     yajl_AddBool('success' :TRUE);
     yajl_AddNum('results' :%Char(JobQueueCount));
     yajl_BeginArray('jobQueueInfo');
     ArrayItem = TRUE;
   EndIf;

   yajl_BeginObj();

   yajl_AddNum('position' :%Char(JobQueueInfoDS.Position));
   yajl_AddChar('jobQueueName' :%TrimR(JobQueueInfoDS.JobQueueName));
   yajl_AddChar('jobQueueLibrary' :%TrimR(JobQueueInfoDS.JobQueueLibrary));
   yajl_AddChar('jobQueueStatus' :%TrimR(JobQueueInfoDS.JobQueueStatus));
   yajl_AddNum('numberOfJobs' :%Char(JobQueueInfoDS.NumberOfJobs));

   If ( JobQueueInfoDS.SubsystemName <> '' );
     yajl_AddChar('subsystemName' :%TrimR(JobQueueInfoDS.SubsystemName));
     yajl_AddChar('subsystemLibraryName' :%TrimR(JobQueueInfoDS.SubsystemLibraryName));
   EndIf;

   yajl_AddNum('sequenceNumber' :%Char(JobQueueInfoDS.SequenceNumber));

   If ( JobQueueInfoDS.MaximumActiveJobs > 0 );
     yajl_AddNum('maximumActiveJobs' :%Char(JobQueueInfoDS.MaximumActiveJobs));
   EndIf;

   If ( JobQueueInfoDS.ActiveJobs > 0 );
     yajl_AddNum('activeJobs' :%Char(JobQueueInfoDS.ActiveJobs));
   EndIf;

   yajl_AddNum('heldJobs' :%Char(JobQueueInfoDS.HeldJobs));
   yajl_AddNum('realeasedJobs' :%Char(JobQueueInfoDS.ReleasedJobs));
   yajl_AddNum('scheduledJobs' :%Char(JobQueueInfoDS.ScheduledJobs));

   If ( JobQueueInfoDS.TextDescription <> '' );
     yajl_AddChar('textDescription' :%TrimR(JobQueueInfoDS.TextDescription));
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

On-Exit;
 Exec SQL close c_jobqueue_info_reader;

END-PROC;
