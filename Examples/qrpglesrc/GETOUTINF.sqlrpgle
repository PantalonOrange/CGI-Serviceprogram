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


/INCLUDE QRPGLEH,GETOUTINFH


//#########################################################################
DCL-PROC Main;

 DCL-DS InputParmDS LIKEDS(InputParmDS_T) INZ;

 DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 /INCLUDE QRPGLECPY,SQLOPTIONS

 *INLR = TRUE;

 InputParmDS = getHTTPInput();

 If ( InputParmDS.Method = 'GET' );
   readOutputQueueInformationAndCreateJSON(InputParmDS);

 Else;
   ErrorMessage = %TrimR(InputParmDS.Method) + ' not allowed';
   writeHTTPOut(%Addr(ErrorMessage) :%Len(%Trim(ErrorMessage)) + 2 :HTTP_BAD_REQUEST);

 EndIf;

 Return;

END-PROC;


//#########################################################################
// parse selected output queue informations to json and return it
DCL-PROC readOutputQueueInformationAndCreateJSON;
 DCL-PI *N;
  pInputParmDS LIKEDS(InputParmDS_T) CONST;
 END-PI;

 DCL-DS OutputQueueInfoDS LIKEDS(OutputQueueInfoDS_T) INZ;

 DCL-S FirstRun IND INZ(TRUE);
 DCL-S ArrayItem IND INZ(FALSE);
 DCL-S OutQCount INT(10) INZ;
 DCL-S OutQName CHAR(12) INZ;
 DCL-S OutQLib CHAR(10) INZ;
 DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 // retrieve parameters/values by name
 OutQName = '%' + %TrimR(getValueByName('outq' :pInputParmDS)) + '%';
 OutQLib = getValueByName('outqlib' :pInputParmDS);

 yajl_GenOpen(TRUE);
 yajl_BeginObj();

 Exec SQL DECLARE c_outq_info_reader INSENSITIVE CURSOR FOR

           SELECT outq.output_queue_name,
                  outq.output_queue_library_name,
                  IFNULL(outq.number_of_files, 0),
                  IFNULL(outq.number_of_writers, 0),
                  IFNULL(outq.writers_to_autostart, 0),
                  IFNULL(outq.printer_device_name, ''),
                  IFNULL(outq.operator_controlled, ''),
                  IFNULL(outq.data_queue_library, ''),
                  IFNULL(outq.data_queue_name, ''),
                  IFNULL(outq.output_queue_status, ''),
                  IFNULL(outq.writer_job_name, ''),
                  IFNULL(outq.writer_job_status, ''),
                  IFNULL(outq.writer_type, ''),
                  IFNULL(outq.text_description, ''),
                  IFNULL(outq.message_queue_library, ''),
                  IFNULL(outq.message_queue_name, '')

             FROM qsys2.output_queue_info outq

            WHERE CAST(outq.output_queue_name AS CHAR(12))
                   LIKE TRIM(UPPER(:OutQName))

              AND outq.output_queue_library_name =
                   CASE WHEN :OutQLib = ''
                        THEN outq.output_queue_library_name
                        ELSE UPPER(:OutQLib) END

            ORDER BY outq.output_queue_library_name, outq.output_queue_name;

 Exec SQL OPEN c_outq_info_reader;

 Exec SQL GET DIAGNOSTICS :OutQCount = DB2_NUMBER_ROWS;

 DoW ( 1 = 1 );
   Exec SQL FETCH NEXT FROM c_outq_info_reader INTO :OutputQueueInfoDS;
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
     Exec SQL CLOSE c_outq_info_reader;
     Leave;
   EndIf;

   If FirstRun;
     // fill in the header informations and begin the array
     FirstRun = FALSE;
     yajl_AddBool('success' :TRUE);
     yajl_AddNum('results' :%Char(OutQCount));
     yajl_BeginArray('outputQueueInfo');
     ArrayItem = TRUE;
   EndIf;

   yajl_BeginObj();

   yajl_AddChar('outputQueueName' :%TrimR(OutputQueueInfoDS.OutputQueueName));
   yajl_AddChar('outputQueueLibrary' :%TrimR(OutputQueueInfoDS.OutputQueueLibrary));
   yajl_AddNum('numberOfFiles' :%Char(OutputQueueInfoDS.NumberOfFiles));
   yajl_AddNum('numberOfWriters' :%Char(OutputQueueInfoDS.NumberOfWriters));
   yajl_AddNum('writerToAutostart' :%Char(OutputQueueInfoDS.WritersToAutostart));
   yajl_AddChar('printerDeviceName' :%Trim(OutputQueueInfoDS.PrinterDeviceName));
   yajl_AddBool('operatorControlled' :(OutputQueueInfoDS.OperatorControlled = '*YES'));
   If ( OutputQueueInfoDS.DataQueueName <> '' );
     yajl_AddChar('dataQueueLibrary' :%TrimR(OutputQueueInfoDS.DataQueueLibrary));
     yajl_AddChar('dataQueueName' :%TrimR(OutputQueueInfoDS.DataQueueName));
   EndIf;
   yajl_AddChar('outputQueueStatus' :%TrimR(OutputQueueInfoDS.OutputQueueStatus));
   yajl_AddChar('writerJobName' :%TrimR(OutputQueueInfoDS.WriterJobName));
   yajl_AddChar('writerJobStatus' :%TrimR(OutputQueueInfoDS.WriterJobStatus));
   If ( OutputQueueInfoDS.WriterType <> '' );
     yajl_AddChar('writerType' :%TrimR(OutputQueueInfoDS.WriterType));
   EndIf;
   yajl_AddChar('textDescription' :%TrimR(OutputQueueInfoDS.TextDescription));
   If ( OutputQueueInfoDS.MessageQueueName <> '' );
     yajl_AddChar('messageQueueLibrary' :%TrimR(OutputQueueInfoDS.MessageQueueLibrary));
     yajl_AddChar('messageQueueName' :%TrimR(OutputQueueInfoDS.MessageQueueName));
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
