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


// This cgi-exitprogram will return the selected object lock-informations
// The following parameters are implemented:
//  - obj = System object name
//  - lib = System schema name
//  - objtype = Object type


/INCLUDE QRPGLEH,GETOBJINFH


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

   // read object statistics-information and generate json-stream
   readObjectStatisticsAndCreateJSON(InputParmDS);

   // return json stream to http-srv
   yajl_WriteStdOut(200 :ErrorMessage);

   yajl_GenClose();

 Else;
   ErrorMessage = %TrimR(InputParmDS.Method) + ' not allowed';
   writeHTTPOut(%Addr(ErrorMessage) :%Len(%Trim(ErrorMessage)) + 2 :HTTP_BAD_REQUEST);

 EndIf;

 Return;

END-PROC;


//#########################################################################
// parse selected object statistics information to json and return it
DCL-PROC readObjectStatisticsAndCreateJSON;
 DCL-PI *N;
  pInputParmDS LIKEDS(InputParmDS_T) CONST;
 END-PI;

 DCL-DS ObjectStatisticsDS LIKEDS(ObjectStatisticsDS_T) INZ;

 DCL-S FirstRun IND INZ(TRUE);
 DCL-S ArrayItem IND INZ(FALSE);
 DCL-S ObjectCount INT(10) INZ;
 DCL-S ObjectName CHAR(12) INZ;
 DCL-S ObjectSchema CHAR(10) INZ;
 DCL-S ObjectType CHAR(8) INZ;
 DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 // retrieve parameters/values by name
 ObjectName = '%' + %Trim(getValueByName('obj' :pInputParmDS)) + '%';
 ObjectSchema = getValueByName('lib' :pInputParmDS);
 ObjectType = getValueByName('objtype' :pInputParmDS);

 If ( ObjectSchema = '' );
   ObjectSchema = '*ALL';
 EndIf;
 If ( ObjectType = '' );
   ObjectType = 'ALL';
 EndIf;
 ObjectType = '*' + %ScanRpl('*' :'' :ObjectType);

 yajl_BeginObj();

 Exec SQL DECLARE c_object_statistics_reader INSENSITIVE CURSOR FOR

           SELECT ROW_NUMBER() OVER() rownumber,
                  statistics.objname,
                  statistics.objlib,
                  statistics.objtype,
                  IFNULL(statistics.objowner, ''),
                  IFNULL(statistics.objdefiner, ''),
                  IFNULL(timestamp_iso8601(statistics.objcreated), ''),
                  CAST(statistics.objsize AS BIGINT),
                  IFNULL(statistics.objtext, ''),
                  IFNULL(statistics.objlongname, ''),
                  IFNULL(statistics.objlongschema, ''),
                  IFNULL(timestamp_iso8601(statistics.last_used_timestamp), ''),
                  statistics.days_used_count,
                  IFNULL(timestamp_iso8601(statistics.last_reset_timestamp), ''),
                  IFNULL(statistics.objattribute, ''),
                  IFNULL(timestamp_iso8601(statistics.change_timestamp), ''),
                  IFNULL(statistics.source_file, ''),
                  IFNULL(statistics.source_library, ''),
                  IFNULL(statistics.source_member, ''),
                  IFNULL(timestamp_iso8601(statistics.source_timestamp), ''),
                  statistics.created_system,
                  statistics.created_system_version,
                  IFNULL(statistics.licensed_program, ''),
                  IFNULL(statistics.licensed_program_version, ''),
                  IFNULL(statistics.compiler, ''),
                  IFNULL(statistics.compiler_version, ''),
                  IFNULL(timestamp_iso8601(statistics.save_timestamp), ''),
                  IFNULL(timestamp_iso8601(statistics.restore_timestamp), ''),
                  IFNULL(timestamp_iso8601(statistics.save_while_active_timestamp), ''),
                  IFNULL(statistics.save_command, ''),
                  IFNULL(statistics.save_device, ''),
                  IFNULL(statistics.save_file_name, ''),
                  IFNULL(statistics.save_file_library, ''),
                  IFNULL(statistics.journal_name, ''),
                  IFNULL(statistics.journal_library, ''),
                  IFNULL(statistics.journal_images, ''),
                  IFNULL(statistics.omit_journal_entry, '')

             FROM TABLE(qsys2.object_statistics
                         (object_schema => UPPER(RTRIM(:ObjectSchema)),
                          objtypelist => UPPER(RTRIM(:ObjectType)))) AS statistics

            WHERE TRIM(UPPER(statistics.objname)) LIKE TRIM(UPPER(:ObjectName));

 Exec SQL OPEN c_object_statistics_reader;

 Exec SQL GET DIAGNOSTICS :ObjectCount = DB2_NUMBER_ROWS;

 DoW ( 1 = 1 );
   Exec SQL FETCH NEXT FROM c_object_statistics_reader INTO :ObjectStatisticsDS;
   If ( SQLCode <> 0 );
     If FirstRun;
       // EOF or other errors
       yajl_AddBool('success' :FALSE);
       If ( SQLCode = 100 );
         ErrorMessage = 'No object was found for your search';
       Else;
         Exec SQL GET DIAGNOSTICS CONDITION 1 :ErrorMessage = MESSAGE_TEXT;
       EndIf;
       yajl_AddChar('errorMessage' :%Trim(ErrorMessage));
     EndIf;
     Exec SQL CLOSE c_object_statistics_reader;
     Leave;
   EndIf;

   If FirstRun;
     // fill in the header informations and begin the array
     FirstRun = FALSE;
     yajl_AddBool('success' :TRUE);
     yajl_AddNum('objectCount' :%Char(ObjectCount));
     yajl_BeginArray('objectStatistics');
     ArrayItem = TRUE;
   EndIf;

   yajl_BeginObj();

   yajl_AddNum('position' :%Char(ObjectStatisticsDS.Position));
   yajl_AddChar('objectName' :%TrimR(ObjectStatisticsDS.Name));
   yajl_AddChar('objectLibrary' :%TrimR(ObjectStatisticsDS.Library));
   yajl_AddChar('objectType' :%TrimR(ObjectStatisticsDS.Type));
   yajl_AddChar('objectOwner' :%TrimR(ObjectStatisticsDS.Owner));
   yajl_AddChar('objectDefiner' :%TrimR(ObjectStatisticsDS.Definer));
   If ( ObjectStatisticsDS.Created <> '' );
     yajl_AddChar('createdTimestamp' :%TrimR(ObjectStatisticsDS.Created));
   EndIf;
   yajl_AddNum('sizeBytes' :%Char(ObjectStatisticsDS.Size));
   If ( ObjectStatisticsDS.Text <> '' );
     yajl_AddChar('objectText' :%TrimR(ObjectStatisticsDS.Text));
   EndIf;
   If ( ObjectStatisticsDS.LongName <> '' );
     yajl_AddChar('longName' :%TrimR(ObjectStatisticsDS.LongName));
   EndIf;
   If ( ObjectStatisticsDS.LongSchema <> '' );
     yajl_AddChar('longSchema' :%TrimR(ObjectStatisticsDS.LongSchema));
   EndIf;
   If ( ObjectStatisticsDS.LastUsedTimeStamp <> '' );
     yajl_AddChar('lastUsedTimestamp' :%TrimR(ObjectStatisticsDS.LastUsedTimeStamp));
   EndIf;
   If ( ObjectStatisticsDS.DaysUsedCount > 0 );
     yajl_AddNum('daysUsedCount' :%Char(ObjectStatisticsDS.DaysUsedCount));
   EndIf;
   If ( ObjectStatisticsDS.LastResetTimeStamp <> '' );
     yajl_AddChar('lastResetTimestamp' :%TrimR(ObjectStatisticsDS.LastResetTimeStamp));
   EndIf;
   If ( ObjectStatisticsDS.Attribute <> '' );
     yajl_AddChar('attribute' :%TrimR(ObjectStatisticsDS.Attribute));
   EndIf;
   If ( ObjectStatisticsDS.ChangeTimeStamp <> '' );
     yajl_AddChar('changeTimestamp' :%TrimR(ObjectStatisticsDS.ChangeTimeStamp));
   EndIf;
   If ( ObjectStatisticsDS.SourceFile <> '' );
     yajl_AddChar('sourceFile' :%TrimR(ObjectStatisticsDS.SourceFile));
   EndIf;
   If ( ObjectStatisticsDS.SourceLibrary <> '' );
     yajl_AddChar('sourceLibrary' :%TrimR(ObjectStatisticsDS.SourceLibrary));
   EndIf;
   If ( ObjectStatisticsDS.SourceMember <> '' );
     yajl_AddChar('sourceMember' :%TrimR(ObjectStatisticsDS.SourceMember));
   EndIf;
   If ( ObjectStatisticsDS.SourceTimeStamp <> '' );
     yajl_AddChar('sourceTimestamp' :%TrimR(ObjectStatisticsDS.SourceTimeStamp));
   EndIf;
   If ( ObjectStatisticsDS.CreatedSystem <> '' );
     yajl_AddChar('createdSystem' :%TrimR(ObjectStatisticsDS.CreatedSystem));
   EndIf;
   If ( ObjectStatisticsDS.CreatedSystemVersion <> '' );
     yajl_AddChar('createdSystemVersion' :%TrimR(ObjectStatisticsDS.CreatedSystemVersion));
   EndIf;
   If ( ObjectStatisticsDS.LicensedProgram <> '' );
     yajl_AddChar('licensedProgram' :%TrimR(ObjectStatisticsDS.LicensedProgram));
   EndIf;
   If ( ObjectStatisticsDS.LicensedProgramVersion <> '' );
     yajl_AddChar('licensedProgramVersion' :%TrimR(ObjectStatisticsDS.LicensedProgramVersion));
   EndIf;
   If ( ObjectStatisticsDS.Compiler <> '' );
     yajl_AddChar('compiler' :%TrimR(ObjectStatisticsDS.Compiler));
   EndIf;
   If ( ObjectStatisticsDS.CompilerVersion <> '' );
     yajl_AddChar('compilerVersion' :%TrimR(ObjectStatisticsDS.CompilerVersion));
   EndIf;

   If ( ObjectStatisticsDS.SaveTimeStamp <> '' );

     yajl_BeginArray('saveRestoreStatistics');
     yajl_BeginObj();

     If ( ObjectStatisticsDS.SaveTimeStamp <> '' );
       yajl_AddChar('saveTimestamp' :%TrimR(ObjectStatisticsDS.SaveTimeStamp));
     EndIf;
     If ( ObjectStatisticsDS.RestoreTimeStamp <> '' );
       yajl_AddChar('restoreTimestamp' :%TrimR(ObjectStatisticsDS.RestoreTimeStamp));
     EndIf;
     If ( ObjectStatisticsDS.SaveWhileActiveTimeStamp <> '' );
       yajl_AddChar('saveWhileActiveTimestamp'
                    :%TrimR(ObjectStatisticsDS.SaveWhileActiveTimeStamp));
     EndIf;
     If ( ObjectStatisticsDS.SaveCommand <> '' );
       yajl_AddChar('saveCommand' :%TrimR(ObjectStatisticsDS.SaveCommand));
     EndIf;
     If ( ObjectStatisticsDS.SaveDevice <> '' );
       yajl_AddChar('saveDevice' :%TrimR(ObjectStatisticsDS.SaveDevice));
     EndIf;
     If ( ObjectStatisticsDS.SaveFileName <> '' );
       yajl_AddChar('saveFileName' :%TrimR(ObjectStatisticsDS.SaveFileName));
     EndIf;
     If ( ObjectStatisticsDS.SaveFileLibrary <> '' );
       yajl_AddChar('saveFileLibrary' :%TrimR(ObjectStatisticsDS.SaveFileLibrary));
     EndIf;

     yajl_EndObj();
     yajl_EndArray();

   EndIf;

   If ( ObjectStatisticsDS.JournalName <> '' );

     yajl_BeginArray('journalStatistics');
     yajl_BeginObj();

     If ( ObjectStatisticsDS.JournalName <> '' );
       yajl_AddChar('journalName' :%TrimR(ObjectStatisticsDS.JournalName));
     EndIf;
     If ( ObjectStatisticsDS.JournalLibrary <> '' );
       yajl_AddChar('journalLibrary' :%TrimR(ObjectStatisticsDS.JournalLibrary));
     EndIf;
     If ( ObjectStatisticsDS.JournalImages <> '' );
       yajl_AddChar('journalImages' :%TrimR(ObjectStatisticsDS.JournalImages));
     EndIf;
     If ( ObjectStatisticsDS.OmitJournalEntry <> '' );
       yajl_AddChar('omitJournalEntry' :%TrimR(ObjectStatisticsDS.OmitJournalEntry));
     EndIf;

     yajl_EndObj();
     yajl_EndArray();

   EndIf;

   yajl_EndObj();

 EndDo;

 If ArrayItem;
   yajl_EndArray();
 EndIf;

 yajl_EndObj();

 Return;

END-PROC;
