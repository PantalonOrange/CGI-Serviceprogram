CREATE OR REPLACE TABLE CUSTOMERS ( 
	CUST_ID INTEGER GENERATED ALWAYS AS IDENTITY ( 
	  START WITH 1 INCREMENT BY 1 
	  NO MINVALUE NO MAXVALUE CYCLE NO ORDER CACHE 20 ) , 
	NAME1 VARCHAR(128) DEFAULT NULL , 
	NAME2 VARCHAR(128) DEFAULT NULL , 
	CHANGE_STAMP FOR COLUMN CHGTSTP TIMESTAMP GENERATED ALWAYS FOR EACH ROW ON UPDATE AS ROW CHANGE TIMESTAMP NOT NULL , 
	LAST_USER FOR COLUMN USR VARCHAR(128) DEFAULT USER )   
	RCDFMT CUS00; 
  
ALTER TABLE CUSTOMERS 
	ADD CONSTRAINT CUTOMER_TABLE_PRIMARY_KEY 
	UNIQUE( CUST_ID ) ; 
  
LABEL ON TABLE CUSTOMERS 
	IS 'Testtable customers' ; 
  
LABEL ON COLUMN CUSTOMERS 
( CUST_ID IS 'ID                   ' , 
	NAME1 IS 'Name1                ' , 
	NAME2 IS 'Name2                ' , 
	CHANGE_STAMP IS 'Change               ' , 
	LAST_USER IS 'Last                User' ) ; 
  
LABEL ON COLUMN CUSTOMERS 
( CUST_ID TEXT IS 'Customer ID' , 
	NAME1 TEXT IS 'Customername 1' , 
	NAME2 TEXT IS 'Customername 2' , 
	CHANGE_STAMP TEXT IS 'Change' , 
	LAST_USER TEXT IS 'Last User' ) ; 