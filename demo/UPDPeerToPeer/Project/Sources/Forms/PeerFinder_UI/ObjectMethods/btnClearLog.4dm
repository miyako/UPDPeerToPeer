// ClearLogButton method

Case of 
	: (FORM Event:C1606.code=On Clicked:K2:4)
		
End case 

Form:C1466.peerCount:=0
Form:C1466.logText:=""
Use (Storage:C1525)
	Storage:C1525.logText:=New shared object:C1526("value"; "")
End use 
ALERT:C41("Log cleared.")