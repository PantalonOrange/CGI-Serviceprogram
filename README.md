# CGI-Serviceprogram

This is my simple cgi.serviceporgram for my favorit platform IBMi.
This servieprogram handle the incoming and outgoing streams to std-io.

## Setup HTTP-Server on IBMi
1. Copy sourcefiles and compile them in your own library

2. Start your admin-server: ```STRTCPSVR SERVER(*HTTP) HTTPSVR(*ADMIN)```

3. Create a new HTTP-Server instance

4. Add the following parts to the http-config


```ScriptAliasMatch /targetlib/(.*)  /qsys.lib/targetlib.lib/$1```

Auth against the IBMi - Userprofiles:
```
<Directory /qsys.lib/targetlib.lib>
  SetEnv QIBM_CGI_LIBRARY_LIST "targetlib;YAJL;QHTTPSVR"
  AuthType Basic
  AuthName "Restricted Area"
  PasswdFile %%SYSTEM%%
  UserID %%CLIENT%%
  Require valid-user
</Directory>
```
or without IBMi Userprofile with a validation-list:
Create a validation list on your IBMi with: ```CRTVLDL TARGETLIB/TEST```.
Change the http-conf to the following:
```
<Directory /qsys.lib/targetlib.lib>
  SetEnv QIBM_CGI_LIBRARY_LIST "targetlib;YAJL;QHTTPSVR"
  AuthType Basic
  AuthName "Restricted Area"
  PasswdFile targetlib/test
  Require valid-user
</Directory>
```
Add the allowed users with the http-admin "Advanced" - "Internet-user"

5. Start your new http-server

6. Try it out:
.Test customers
```https://yourIP:port/targetlib/cgitstrg.pgm?id=1```
.User informations
```https://yourIP:port/targetlib/getusrinf.pgm?usrcls=secofr&exppwd=1&enabled=0```
.Active jobs:
```https://yourIP:port/targetlib/getactjob.pgm?sbs=qbatch&jobsts=msgw```


## Pocedures within the serviceprogram

1. getHTTPInput:
Reads the stream and fill in the neccessary variables like "REQUEST_METHOD" and so on
These values are written to the "INPUTPARMDS" variable.

2. writeHTTPOut:
Here we can write to the io-std

3. getHTTPHeader:
Simple procedure to determine the HTTP header

4. getValueByName
Get the value by name from parameters

5. vtranslateData:
Convert data between different CCSID's. ICONV is used for translation.

6. parseQueryString:
The "QUERY_STRING" is parsed here.
"id=1&test=5" becomes DS id=1, test=2

7. seperateValues:
The parsed data from "parseQueryString" are simplified here even further. 
"id=1" or "test=5" becomes DS id, 1 or test, 5
