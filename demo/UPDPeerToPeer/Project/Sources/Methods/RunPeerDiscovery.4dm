//%attributes = {}

#DECLARE($options : Object)

var $discovery : cs:C1710.PeerDiscovery
$discovery:=cs:C1710.PeerDiscovery.new($options)


Use (Storage:C1525)
	Storage:C1525.discovery:=$discovery  // Share instance
	Storage:C1525.peers:=New shared collection:C1527
	Storage:C1525.logText:=New shared object:C1526("value"; "")
End use 


While (Not:C34($discovery.closingSignal.wait(5)))
	
	$discovery.sendProbe()
	$discovery.prunePeers()
	Use (Storage:C1525)
		Storage:C1525.peers:=$discovery.getPeers()  //.copy(ck shared)
		Use (Storage:C1525.logText)
			Storage:C1525.logText.value:=$discovery.logText
		End use 
	End use 
	
End while 


Use (Storage:C1525)
	Storage:C1525.discovery:=Null:C1517
	Storage:C1525.peers:=New shared collection:C1527
	Storage:C1525.logText:=New shared object:C1526("value"; "")
End use 

