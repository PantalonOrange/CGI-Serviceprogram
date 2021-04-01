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
//  - mbr = System member name
//  - objtype = Object type
//  - mbrlcktype = Member lock type (member, data)
//  - lckstate = Lock state (shrrd, excl, etc)
//  - lcksts = Lock status (held, requested, etc)
//  - lckscope = Lock scope (job, thread, etc)
//  - job = Jobname (format: 000000/user/job)


/INCLUDE QRPGLEH,GETOBJLCKH


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

   // read object lock-information and generate json-stream
   generateJSONStream(InputParmDS);

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
// parse selected object lock information to json and return it
DCL-PROC generateJSONStream;
 DCL-PI *N;
  pInputParmDS LIKEDS(InputParmDS_T) CONST;
 END-PI;

 DCL-DS ObjectLockInfoDS LIKEDS(ObjectLockInfoDS_T) INZ;

 DCL-S FirstRun IND INZ(TRUE);
 DCL-S ArrayItem IND INZ(FALSE);
 DCL-S LockCount INT(10) INZ;
 DCL-S ObjectName CHAR(10) INZ;
 DCL-S ObjectSchema CHAR(10) INZ;
 DCL-S MemberName CHAR(10) INZ;
 DCL-S ObjectType CHAR(8) INZ;
 DCL-S MemberLockType CHAR(10) INZ;
 DCL-S LockState CHAR(7) INZ;
 DCL-S LockStatus CHAR(9) INZ;
 DCL-S LockScope CHAR(10) INZ;
 DCL-S JobName VARCHAR(28) INZ;
 DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 // retrieve parameters/values by name
 ObjectName = getValueByName('obj' :pInputParmDS);
 ObjectSchema = getValueByName('lib' :pInputParmDS);
 MemberName = getValueByName('mbr' :pInputParmDS);
 ObjectType = getValueByName('objtype' :pInputParmDS);
 MemberLockType = getValueByName('mbrlcktype' :pInputParmDS);
 LockState = getValueByName('lckstate' :pInputParmDS);
 LockStatus = getValueByName('lcksts' :pInputParmDS);
 LockScope = getValueByName('lckscope' :pInputParmDS);
 JobName = getValueByName('job' :pInputParmDS);

 yajl_BeginObj();

 Exec SQL DECLARE c_object_lock_reader INSENSITIVE CURSOR FOR

           SELECT ROW_NUMBER() OVER() rownumber,
                  locks.system_object_name,
                  locks.system_object_schema,
                  IFNULL(locks.system_table_member, ''),
                  locks.object_type,
                  IFNULL(locks.sql_object_type, ''),
                  IFNULL(locks.member_lock_type, ''),
                  REPLACE(locks.lock_state, '*', ''),
                  locks.lock_status,
                  locks.lock_scope,
                  IFNULL(locks.job_name, ''),
                  locks.lock_count

             FROM qsys2.object_lock_info locks

            WHERE locks.system_object_name
                = CASE WHEN :ObjectName = ''
                       THEN locks.system_object_name
                       ELSE UPPER(:ObjectName) END

              AND locks.system_object_schema
                = CASE WHEN :ObjectSchema = ''
                       THEN locks.system_object_schema
                       ELSE UPPER(:ObjectSchema) END

              AND IFNULL(locks.system_table_member, '')
                = CASE WHEN :MemberName = ''
                       THEN IFNULL(locks.system_table_member, '')
                       ELSE UPPER(:MemberName) END

              AND locks.object_type
                = CASE WHEN :ObjectType = ''
                       THEN locks.object_type
                       ELSE UPPER(:ObjectType) END

              AND locks.member_lock_type
                = CASE WHEN :MemberLockType = ''
                       THEN locks.member_lock_type
                       ELSE UPPER(:MemberLockType) END

              AND REPLACE(locks.lock_state, '*', '')
                = CASE WHEN :LockState = ''
                       THEN REPLACE(locks.lock_state, '*', '')
                       ELSE UPPER(:LockState) END

              AND locks.lock_status
                = CASE WHEN :LockStatus = ''
                       THEN locks.lock_status
                       ELSE UPPER(:LockStatus) END

              AND locks.lock_scope
                = CASE WHEN :LockScope = ''
                       THEN locks.lock_scope
                       ELSE UPPER(:LockScope) END

              AND IFNULL(locks.job_name, '')
                = CASE WHEN :JobName = ''
                       THEN IFNULL(locks.job_name, '')
                       ELSE UPPER(:JobName) END;

 Exec SQL OPEN c_object_lock_reader;

 Exec SQL GET DIAGNOSTICS :LockCount = DB2_NUMBER_ROWS;

 DoW ( 1 = 1 );
   Exec SQL FETCH NEXT FROM c_object_lock_reader INTO :ObjectLockInfoDS;
   If ( SQLCode <> 0 );
     If FirstRun;
       // EOF or other errors
       yajl_AddBool('success' :FALSE);
       If ( SQLCode = 100 );
         ErrorMessage = 'No object lock was found for your search';
       Else;
         Exec SQL GET DIAGNOSTICS CONDITION 1 :ErrorMessage = MESSAGE_TEXT;
       EndIf;
       yajl_AddChar('errorMessage' :%Trim(ErrorMessage));
     EndIf;
     Exec SQL CLOSE c_object_lock_reader;
     Leave;
   EndIf;

   If FirstRun;
     // fill in the header informations and begin the array
     FirstRun = FALSE;
     yajl_AddBool('success' :TRUE);
     yajl_AddNum('lockCount' :%Char(LockCount));
     yajl_BeginArray('objectLockInfo');
     ArrayItem = TRUE;
   EndIf;

   yajl_BeginObj();

   yajl_AddNum('ordinalPosition' :%Char(ObjectLockInfoDS.OrdinalPosition));
   yajl_AddChar('systemObjectName' :%TrimR(ObjectLockInfoDS.ObjectName));
   yajl_AddChar('systemSchemaName' :%TrimR(ObjectLockInfoDS.ObjectSchema));

   If ( ObjectLockInfoDS.MemberName <> '' );
     yajl_AddChar('memberName' :%TrimR(ObjectLockInfoDS.MemberName));
   EndIf;

   yajl_AddChar('objectType' :%TrimR(ObjectLockInfoDS.ObjectType));

   If ( ObjectLockInfoDS.SQLObjectType <> '' );
     yajl_AddChar('sqlObjectType' :%TrimR(ObjectLockInfoDS.SQLObjectType));
   EndIf;

   yajl_AddChar('memberLockType' :%TrimR(ObjectLockInfoDS.MemberLockType));
   yajl_AddChar('lockState' :%TrimR(ObjectLockInfoDS.LockState));
   yajl_AddChar('lockStatus' :%TrimR(ObjectLockInfoDS.LockStatus));
   yajl_AddChar('lockScope' :%TrimR(ObjectLockInfoDS.LockScope));
   yajl_AddChar('jobName' :%TrimR(ObjectLockInfoDS.JobName));
   yajl_AddNum('lockCount' :%Char(ObjectLockInfoDS.LockCount));

   yajl_EndObj();

 EndDo;

 If ArrayItem;
   yajl_EndArray();
 EndIf;

 yajl_EndObj();

 Return;

END-PROC;
