# CGI-Serviceprogram

This is my simple cgi.serviceporgram for my favorit platform IBMi.
This will handle incoming and outgoing streams to std-io.

## Setup HTTP-Server on IBMi
1. Copy sourcefiles and compile them in your own library

2. Start your admin-server: ```STRTCPSVR SERVER(*HTTP) HTTPSVR(*ADMIN)```

3. Create a new HTTP-Server instance

4. Add the following parts to the http-config
```
ScriptAliasMatch /targetlib/(.*)  /qsys.lib/targetlib.lib/$1
<Directory /qsys.lib/targetlib.lib>
  SetEnv QIBM_CGI_LIBRARY_LIST "targetlib;YAJL;QHTTPSVR"
  AuthType Basic
  AuthName "IBMi_Basic_AuthType"
  PasswdFile %%SYSTEM%%
  UserID %%CLIENT%%
  Require valid-user
</Directory>
```
or without ibmi userprofile:
Create a validation list on your IBMi with: CRTVLDL TARGETLIB/TEST
Change the http-conf to the following:
```
<Directory /qsys.lib/targetlib.lib>
  SetEnv QIBM_CGI_LIBRARY_LIST "targetlib;YAJL;QHTTPSVR"
  AuthType Basic
  AuthName "Restricted Area"
  PasswdFile targetlib/test
  Require valid-user
```
Add the allowed users with the hhtp-admin "Advanced" - "Internet-user"

5. Start your new http-server

6. Try it out: ```http://yourIP:port/targetlib/cgitstrg.pgm?id=1```