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


// This cgi-exitprogram will return the informations from netstat_job_info()
// The following parameters are implemented:
//  - raddr = Remote address
//  - usr = Authorizationname
//  - job = Job name


/INCLUDE QRPGLEH,GETNETSTJH


//#########################################################################
DCL-PROC Main;

 DCL-DS InputParmDS LIKEDS(InputParmDS_T) INZ;

 DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 /INCLUDE QRPGLECPY,SQLOPTIONS

 *INLR = TRUE;

 InputParmDS = getHTTPInput();

 If ( InputParmDS.Method = 'GET' );
   readNetstatJobInformationAndCreateJSON(InputParmDS);

 Else;
   ErrorMessage = %TrimR(InputParmDS.Method) + ' not allowed';
   writeHTTPOut(%Addr(ErrorMessage) :%Len(%Trim(ErrorMessage)) + 2 :HTTP_BAD_REQUEST);

 EndIf;

 Return;

END-PROC;


//#########################################################################
// parse selected netstat job informations to json and return it
DCL-PROC readNetstatJobInformationAndCreateJSON;
 DCL-PI *N;
  pInputParmDS LIKEDS(InputParmDS_T) CONST;
 END-PI;

 DCL-DS NetStatJobInfoDS LIKEDS(NetStatJobInfoDS_T) INZ;

 DCL-S FirstRun IND INZ(TRUE);
 DCL-S ArrayItem IND INZ(FALSE);
 DCL-S JobCount INT(10) INZ;
 DCL-S RemoteAddress CHAR(45) INZ;
 DCL-S AuthorizationName CHAR(10) INZ;
 DCL-S JobName CHAR(28) INZ;
 DCL-S ErrorMessage VARCHAR(500) INZ;
 //------------------------------------------------------------------------

 // retrieve parameters/values by name
 RemoteAddress = getValueByName('raddr' :pInputParmDS);
 AuthorizationName = getValueByName('usr' :pInputParmDS);
 JobName = getValueByName('job' :pInputParmDS);

 yajl_GenOpen(TRUE);
 yajl_BeginObj();

 Exec SQL DECLARE c_netstat_info_reader INSENSITIVE CURSOR FOR

           SELECT IFNULL(netstat.remote_address, ''),
                  IFNULL(netstat.remote_port, 0),
                  IFNULL(netstat.local_address, ''),
                  IFNULL(netstat.local_port, 0),
                  IFNULL(netstat.authorization_name, ''),
                  IFNULL(usr.text_description, ''),
                  IFNULL(netstat.job_name, '')

             FROM qsys2.netstat_job_info netstat

             LEFT JOIN qsys2.user_info usr
               ON (usr.authorization_name = netstat.authorization_name)

            WHERE netstat.remote_address =
                   CASE WHEN :RemoteAddress = ''
                        THEN netstat.remote_address
                        ELSE :RemoteAddress END
              AND netstat.authorization_name =
                   CASE WHEN :AuthorizationName = ''
                        THEN netstat.authorization_name
                        ELSE UPPER(:AuthorizationName) END
              AND netstat.job_name =
                   CASE WHEN :JobName = ''
                        THEN netstat.job_name
                        ELSE UPPER(:JobName) END

            ORDER BY netstat.authorization_name, netstat.remote_address,
                      netstat.job_name;

 Exec SQL OPEN c_netstat_info_reader;

 Exec SQL GET DIAGNOSTICS :JobCount = DB2_NUMBER_ROWS;

 DoW ( 1 = 1 );
   Exec SQL FETCH NEXT FROM c_netstat_info_reader INTO :NetStatJobInfoDS;
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
     Exec SQL CLOSE c_netstat_info_reader;
     Leave;
   EndIf;

   If FirstRun;
     // fill in the header informations and begin the array
     FirstRun = FALSE;
     yajl_AddBool('success' :TRUE);
     yajl_AddNum('results' :%Char(JobCount));
     yajl_BeginArray('netStatJobInfo');
     ArrayItem = TRUE;
   EndIf;

   yajl_BeginObj();

   yajl_AddChar('remoteAddress' :%TrimR(NetStatJobInfoDS.RemoteAddress));
   yajl_AddNum('remotePort' :%Char(NetStatJobInfoDS.RemotePort));

   yajl_AddChar('localAddress' :%TrimR(NetStatJobInfoDS.LocalAddress));
   yajl_AddNum('localPort' :%Char(NetStatJobInfoDS.LocalPort));

   If ( NetStatJobInfoDS.AuthorizationName <> '' );
     yajl_AddChar('authorizationName' :%TrimR(NetStatJobInfoDS.AuthorizationName));
     yajl_AddChar('authorizationDescription'
            :%TrimR(NetStatJobInfoDS.AuthorizationDescription));
   EndIf;

   yajl_AddChar('jobName' :%TrimR(NetStatJobInfoDS.JobName));

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
