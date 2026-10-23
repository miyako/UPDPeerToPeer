
Case of 
	: (FORM Event:C1606.code=On Load:K2:1)
		var $systemInfo : Object:=New object:C1471
		var $nodeID; $nodeIP; $nodeName; $version : Text
		$systemInfo:=System info:C1571
		
		$nodeID:="4D2R10P2P-"+String:C10((Random:C100%29999)+1)  // Replace with actual node unique ID
		$nodeName:=$systemInfo.machineName  // 4D command
		$nodeIP:=$systemInfo.networkInterfaces[0].ipAddresses.filter(Formula:C1597($1.value.type="ipv4")).first().ip  // 4D command
		$version:=$systemInfo.osVersion  // Could come from your app metadata
		
		
		var $line : Text:=Localized string("Peer_LocalInfoLine")
		$line:=Replace string($line; "{id}"; $nodeID)
		$line:=Replace string($line; "{name}"; $nodeName)
		$line:=Replace string($line; "{ip}"; $nodeIP)
		$line:=Replace string($line; "{version}"; $version)
		Form:C1466.lblHeaderLocalInfo:=$line
End case 
