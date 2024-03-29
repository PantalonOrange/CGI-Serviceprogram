**FREE
//- Copyright (c) 2021, 2022 Christian Brunner
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


// This cgi-exitprogram will return the informations about the selected user
// The following parameters are implemented:
//  - usr = Authorization_Name (user)
//  - usrcls = Userclass (user, secofr, etc)
//  - enabled = Userprofile status (1=enabled, 0=disabled)
//  - grpprf = Group profile
//  - owner = Owner
//  - active = Only active/inactive users (1=active, 0=inactive)
//  - pwdexp = 1=Only users with expired password, 0=Only users with valid password
//  - curlib = Current library name
//  - inimnunam = Initial menu name
//  - inimnulib = Initial menu library name
//  - inipgmnam = Initial program name
//  - inipgmlib = Initial program library name
//  - query = Search with LIKE for autorization description
//  - short = Return only authirzation_name and text_description


/INCLUDE QRPGLEH,GETUSRINFH


//#########################################################################
DCL-PROC Main;

 DCL-DS InputParmDS LIKEDS(InputParmDS_T) INZ;

 DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 /INCLUDE QRPGLECPY,SQLOPTIONS

 *INLR = TRUE;

 InputParmDS = getHTTPInput();

 /IF DEFINED(USE_SERVER_INFO)
 ServerInformationDS = getServerInformations();
 /ENDIF

 If ( InputParmDS.Method = 'GET' );
   readUserInformationAndCreateJSON(InputParmDS);

 Else;
   ErrorMessage = %TrimR(InputParmDS.Method) + ' not allowed';
   writeHTTPOut(%Addr(ErrorMessage) :%Len(%Trim(ErrorMessage)) + 2 :HTTP_BAD_REQUEST);

 EndIf;

 Return;

END-PROC;


//#########################################################################
// parse selected user to json and return it
DCL-PROC readUserInformationAndCreateJSON;
 DCL-PI *N;
  pInputParmDS LIKEDS(InputParmDS_T) CONST;
 END-PI;

 DCL-DS UserInfoDS LIKEDS(UserInfoDS_T) INZ;

 DCL-S FirstRun IND INZ(TRUE);
 DCL-S ArrayItem IND INZ(FALSE);
 DCL-S UserCount INT(10) INZ;
 DCL-S AuthorizationName CHAR(12) INZ;
 DCL-S UserClass CHAR(10) INZ;
 DCL-S Enabled CHAR(1) INZ;
 DCL-S GroupProfile CHAR(10) INZ;
 DCL-S Owner CHAR(10) INZ;
 DCL-S Active CHAR(1) INZ;
 DCL-S ExpiredPassword CHAR(1) INZ;
 DCL-S CurrentLibrary CHAR(10) INZ;
 DCL-S InitialMenuName CHAR(10) INZ;
 DCL-S InitialMenuLibrary CHAR(10) INZ;
 DCL-S InitialProgramName CHAR(10) INZ;
 DCL-S InitialProgramLibrary CHAR(10) INZ;
 DCL-S NameQuery CHAR(256) INZ;
 DCL-S ReturnShort IND INZ(FALSE);
 DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 // retrieve parameters/values by name
 AuthorizationName = '%' + %Trim(getValueByName('usr' :pInputParmDS)) + '%';
 UserClass = getValueByName('usrcls' :pInputParmDS);
 Enabled = getValueByName('enabled' :pInputParmDS);
 GroupProfile = getValueByName('grpprf' :pInputParmDS);
 Owner = getValueByName('owner' :pInputParmDS);
 Active = getValueByName('active' :pInputParmDS);
 ExpiredPassword = getValueByName('exppwd' :pInputParmDS);
 CurrentLibrary = getValueByName('curlib' :pInputParmDS);
 InitialMenuName = getValueByName('inimnunam' :pInputParmDS);
 InitialMenuLibrary = getValueByName('inimnulib' :pInputParmDS);
 InitialProgramName = getValueByName('inipgmnam' :pInputParmDS);
 InitialProgramLibrary = getValueByName('inipgmlib' :pInputParmDS);
 NameQuery = '%' + %Trim(getValueByName('query' :pInputParmDS)) + '%';
 ReturnShort = ( getValueByName('short' :pInputParmDS) = '1');

 yajl_GenOpen(TRUE);
 yajl_BeginObj();

 Exec SQL DECLARE c_user_info_reader INSENSITIVE CURSOR FOR

           WITH current_running_jobs
             -- get count per user for currently running jobs
             (authorization_name, job_count) AS

           (SELECT jobs.authorization_name, COUNT(*)
              FROM TABLE(qsys2.active_job_info()) AS jobs
             GROUP BY jobs.authorization_name)

           SELECT ROW_NUMBER() OVER() rownumber,
                  user_info.authorization_name,
                  IFNULL(user_info.text_description, ''),
                  IFNULL(timestamp_iso8601(user_info.previous_signon), ''),
                  user_info.sign_on_attempts_not_valid,
                  user_info.status,
                  IFNULL(timestamp_iso8601(user_info.password_change_date), ''),
                  user_info.no_password_indicator,
                  user_info.password_expiration_interval,
                  IFNULL(timestamp_iso8601(user_info.date_password_expires), ''),
                  IFNULL(user_info.days_until_password_expires, 0),
                  user_info.set_password_to_expire,
                  user_info.user_class_name,
                  IFNULL(user_info.special_authorities, ''),
                  IFNULL(user_info.group_profile_name, ''),
                  user_info.owner,
                  user_info.current_library_name,
                  IFNULL(user_info.initial_menu_name, ''),
                  IFNULL(user_info.initial_menu_library_name, ''),
                  IFNULL(user_info.initial_program_name, ''),
                  IFNULL(user_info.initial_program_library_name, ''),
                  user_info.limit_capabilities,
                  user_info.display_signon_information,
                  user_info.limit_device_sessions,
                  user_info.maximum_allowed_storage,
                  user_info.storage_used,
                  IFNULL(timestamp_iso8601(user_info.last_used_timestamp), ''),
                  IFNULL(timestamp_iso8601(user_info.creation_timestamp), ''),
                  IFNULL(current_running_jobs.job_count, 0)

             FROM qsys2.user_info

             LEFT JOIN current_running_jobs
               ON current_running_jobs.authorization_name = user_info.authorization_name

               -- fetch only selected userprofile or all
            WHERE CAST(user_info.authorization_name AS CHAR(12))
                LIKE UPPER(TRIM(:AuthorizationName))

               -- fetch only selected user-class profile or all
              AND REPLACE(user_info.user_class_name, '*', '')
                = CASE WHEN UPPER(:UserClass) IN ('','ALL')
                       THEN REPLACE(user_info.user_class_name, '*', '')
                       ELSE UPPER(:UserClass) END

               -- fetch selected stati for profiles (enabled/disabled) or all
              AND 1 = CASE WHEN :Enabled = '' THEN 1
                           WHEN :Enabled = '1' AND user_info.status = '*ENABLED' THEN 1
                           WHEN :Enabled = '0' AND user_info.status = '*DISABLED' THEN 1
                           ELSE 0 END

               -- fetch profiles for selected groups or all
              AND user_info.group_profile_name
                = CASE WHEN :GroupProfile = ''
                       THEN user_info.group_profile_name
                       ELSE UPPER(:GroupProfile) END

               -- fetch profiles for selected owner-setting or all
              AND user_info.owner
                = CASE WHEN :Owner = ''
                       THEN user_info.owner
                       ELSE UPPER(:Owner) END

               -- fetch only currently running userprofiles or all
              AND 1 = CASE WHEN :Active = '' THEN 1
                           WHEN :Active = '1' AND current_running_jobs.job_count IS NOT NULL THEN 1
                           WHEN :Active = '0' AND current_running_jobs.job_count IS NULL THEN 1
                           ELSE 0 END

               -- fetch only users with or without expired password or all
              AND 1 = CASE WHEN :ExpiredPassword = '' THEN 1
                           WHEN :ExpiredPassword = '1'
                            AND (DATE(user_info.date_password_expires) <= CURRENT_DATE
                                  OR user_info.set_password_to_expire = 'YES') THEN 1
                           WHEN :ExpiredPassword = '0'
                            AND DATE(user_info.date_password_expires) > CURRENT_DATE
                            AND user_info.set_password_to_expire = 'NO' THEN 1
                           ELSE 0 END

               -- fetch only with selected current library name
              AND IFNULL(user_info.current_library_name, '')
                = CASE WHEN :CurrentLibrary = ''
                       THEN IFNULL(user_info.current_library_name, '')
                       ELSE UPPER(:CurrentLibrary) END

               -- fetch only with selected initial menu
              AND IFNULL(user_info.initial_menu_name, '')
                = CASE WHEN :InitialMenuName = ''
                       THEN IFNULL(user_info.initial_menu_name, '')
                       ELSE UPPER(:InitialMenuName) END

               -- ftech only with selected initial menu library
              AND IFNULL(user_info.initial_menu_library_name, '')
                = CASE WHEN :InitialMenuLibrary = ''
                       THEN IFNULL(user_info.initial_menu_library_name, '')
                       ELSE UPPER(:InitialMenuLibrary) END

               -- fetch only with selected initial program
              AND IFNULL(user_info.initial_program_name, '')
                = CASE WHEN :InitialProgramName = ''
                       THEN IFNULL(user_info.initial_program_name, '')
                       ELSE UPPER(:InitialProgramName) END

               -- fetch only with selected initial program library
              AND IFNULL(user_info.initial_program_library_name, '')
                = CASE WHEN :InitialProgramLibrary = ''
                       THEN IFNULL(user_info.initial_program_library_name, '')
                       ELSE UPPER(:InitialProgramLibrary) END

              AND UPPER(user_info.text_description) LIKE TRIM(UPPER(:NameQuery));

 Exec SQL OPEN c_user_info_reader;

 Exec SQL GET DIAGNOSTICS :UserCount = DB2_NUMBER_ROWS;

 DoW ( 1 = 1 );
   Exec SQL FETCH NEXT FROM c_user_info_reader INTO :UserInfoDS;
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
     Exec SQL CLOSE c_user_info_reader;
     Leave;
   EndIf;

   If FirstRun;
     // fill in the header informations and begin the array
     FirstRun = FALSE;
     yajl_AddBool('success' :TRUE);
     yajl_AddNum('results' :%Char(UserCount));
     yajl_BeginArray('userInfo');
     ArrayItem = TRUE;
   EndIf;

   yajl_BeginObj();

   yajl_AddNum('position' :%Char(UserInfoDS.Position));
   yajl_AddChar('authorizationName' :%TrimR(UserInfoDS.AuthorizationName));
   yajl_AddChar('authorizationDescription' :%TrimR(UserInfoDS.AuthorizationDescription));

   If Not ReturnShort;

     yajl_AddBool('isEnabled' :(UserInfoDS.Status = '*ENABLED'));

     If ( UserInfoDS.PreviousSignon <> '' );
       yajl_AddChar('previousSignon' :%TrimR(UserInfoDS.PreviousSignon));
     EndIf;

     If ( UserInfoDS.SignOnAttemptsNotValid > 0 );
       yajl_AddChar('signOnAttemptsNotValid' :%Char(UserInfoDS.SignOnAttemptsNotValid));
     EndIf;

     If ( UserInfoDS.PasswordChangeDate <> '' );
       yajl_AddChar('passwordChangeDate' :%TrimR(UserInfoDS.PasswordChangeDate));
     EndIf;

     yajl_AddBool('noPasswordIndicator' :(UserInfoDS.NoPassWordIndicator = 'YES'));
     yajl_AddNum('passwordExpirationInterval' :%Char(UserInfoDS.PasswordExpirationInterval));

     If ( UserInfoDS.DatePasswordExpires <> '' );
       yajl_AddChar('datePasswordExpires' :%TrimR(UserInfoDS.DatePasswordExpires));
     EndIf;

     If ( UserInfoDS.DaysUntilPasswordExpires > 0 );
       yajl_AddNum('daysUntilPasswordExpires' :%Char(UserInfoDS.DaysUntilPasswordExpires));
     EndIf;

     yajl_AddBool('setPasswordToExpire' :(UserInfoDS.SetPasswordToExpire = 'YES'));
     yajl_AddChar('userClassName' :%TrimR(UserInfoDS.UserClassName));

     If ( UserInfoDS.GroupProfileName <> '' );
       yajl_AddChar('groupProfileName' :%TrimR(UserInfoDS.GroupProfileName));
     EndIf;

     yajl_AddChar('owner' :%TrimR(UserInfoDS.Owner));
     yajl_AddChar('currentLibraryName' :%TrimR(UserInfoDS.CurrentLibraryName));

     If (UserInfoDS.InitialMenuName <> '' );
       yajl_BeginArray('initialMenu');
        yajl_BeginObj();
         yajl_AddChar('menuName' :%TrimR(UserInfoDS.InitialMenuName));
         If ( UserInfoDS.InitialMenuLibrary <> '' );
           yajl_AddChar('menuLibrary' :%TrimR(UserInfoDS.InitialMenuLibrary));
         EndIf;
        Yajl_EndObj();
       yajl_EndArray();
     EndIf;

     If (UserInfoDS.InitialProgramName <> '' );
       yajl_BeginArray('initialProgram');
        yajl_BeginObj();
         yajl_AddChar('programName' :%TrimR(UserInfoDS.InitialProgramName));
         If ( UserInfoDS.InitialProgramLibrary <> '' );
           yajl_AddChar('programLibrary' :%TrimR(UserInfoDS.InitialProgramLibrary));
         EndIf;
        Yajl_EndObj();
       yajl_EndArray();
     EndIf;

     yajl_AddChar('limitCapabilities' :%TrimR(UserInfoDS.LimitCapabilities));
     yajl_AddChar('displaySignonInformations' :%TrimR(UserInfoDS.DisplaySignonInformations));
     yajl_AddChar('limitDeviceSessions' :%TrimR(UserInfoDS.LimitDeviceSessions));
     yajl_AddNum('maximumStorageAllowed' :%Char(UserInfoDS.MaximumStorageAllowed));
     yajl_AddNum('storageUsed' :%Char(UserInfoDS.StorageUsed));

     If ( UserInfoDS.LastUsedTimestamp <> '' );
       yajl_AddChar('lastUsedTimestamp' :%TrimR(UserInfoDS.LastUsedTimestamp));
     EndIf;

     yajl_AddChar('creationTimestamp' :%TrimR(UserInfoDS.CreationTimestamp));
     yajl_AddNum('currentJobsRunning' :%Char(UserInfoDS.CurrentJobsRunning));

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
