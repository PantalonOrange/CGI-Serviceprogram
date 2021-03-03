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

CREATE OR REPLACE FUNCTION TIMESTAMP_UNIX ( 
	PARM_TIMESTAMP TIMESTAMP DEFAULT CURRENT_TIMESTAMP  , 
	PARM_TIMEZONE DECIMAL(6, 0) DEFAULT CURRENT_TIMEZONE  ) 
	RETURNS BIGINT   
	LANGUAGE SQL 
	SPECIFIC TS_UNIX 
	DETERMINISTIC 
	MODIFIES SQL DATA 
	CALLED ON NULL INPUT 
	SET OPTION
	COMMIT = *NONE, 
	DBGVIEW = *SOURCE, 
	DYNUSRPRF = *OWNER

BEGIN 
 DECLARE CONTINUE HANDLER FOR SQLEXCEPTION RETURN -1; 
  
 RETURN 
  (BIGINT(DAYS(PARM_TIMESTAMP - PARM_TIMEZONE) - DAYS('1970-01-01')) * 86400) + MIDNIGHT_SECONDS(PARM_TIMESTAMP - PARM_TIMEZONE);

END; 
  
COMMENT ON PARAMETER SPECIFIC FUNCTION TS_UNIX 
( PARM_TIMEZONE IS 'Timezone (-)HHMMSS' ); 
  
LABEL ON SPECIFIC FUNCTION TS_UNIX 
	IS 'Timestamp in unix-format'; 
