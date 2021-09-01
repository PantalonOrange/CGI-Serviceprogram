/* 
- Copyright (c) 2021 Christian Brunner

- Permission is hereby granted, free of charge, to any person obtaining a copy
- of this software and associated documentation files (the "Software"), to deal
- in the Software without restriction, including without limitation the rights
- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
- copies of the Software, and to permit persons to whom the Software is
- furnished to do so, subject to the following conditions:

- The above copyright notice and this permission notice shall be included in all
- copies or substantial portions of the Software.

- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
- SOFTWARE.
*/

CREATE FUNCTION TIMESTAMP_ISO8601 
( 
  PARM_TIMESTAMP TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
  PARM_TIMEZONE DECIMAL(6, 0) DEFAULT CURRENT_TIMEZONE  
) 
 RETURNS VARCHAR(26)   
 LANGUAGE SQL 
 SPECIFIC TS_ISO8601 
 DETERMINISTIC 
 MODIFIES SQL DATA 
 CALLED ON NULL INPUT 
 SET OPTION
 COMMIT = *NONE, 
 DBGVIEW = *SOURCE, 
 DYNUSRPRF = *OWNER 
BEGIN 
  
 DECLARE CONTINUE HANDLER FOR SQLEXCEPTION RETURN '-1' ; 
  
 RETURN 
 ( 
   TRANSLATE ( VARCHAR_FORMAT ( PARM_TIMESTAMP , 'YYYY-MM-DD HH24:MI:SS' ) , 'T' , ' ' ) CONCAT 
     CASE WHEN PARM_TIMEZONE < 0 THEN '-' ELSE '+' END 
	 CONCAT VARCHAR_FORMAT ( '00010101' CONCAT RIGHT ( DIGITS ( PARM_TIMEZONE ) , 6 ) , 'HH24:MI' ) 
  ); 
  
END; 
  
COMMENT ON PARAMETER SPECIFIC FUNCTION TS_ISO8601 ( PARM_TIMEZONE IS 'Timezone (-)HHMMSS' ); 
  
LABEL ON SPECIFIC FUNCTION TS_ISO8601 IS 'Timestamp in ISO8601 (YYYY-MM-DDTHH:MM:SS+/-HH:MM)'; 