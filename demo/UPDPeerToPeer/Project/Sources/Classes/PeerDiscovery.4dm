property listener : 4D:C1709.UDPSocket
property sender : 4D:C1709.UDPSocket
property discoveryPort : Integer
property broadcastAddress : Text
property peers : Collection  // collection of peer objects {id,name,ip,port,lastSeen,info}
property myInfo : Object  // the object we announce about ourselves
property peerTTL : Integer  // seconds after which a peer is considered gone
property running : Boolean
property logText : Text
property probeInterval : Integer  // seconds between announcements (added)
property closingSignal : 4D:C1709.Signal


shared Class constructor($options : Object)
	If (OB Is defined:C1231($options; "port"))
		This:C1470.discoveryPort:=OB Get:C1224($options; "port")
	Else 
		This:C1470.discoveryPort:=54321
	End if 
	If (OB Is defined:C1231($options; "broadcastAddress"))
		This:C1470.broadcastAddress:=OB Get:C1224($options; "broadcastAddress")
	Else 
		This:C1470.broadcastAddress:="255.255.255.255"
	End if 
	If (OB Is defined:C1231($options; "ttl"))
		This:C1470.peerTTL:=OB Get:C1224($options; "ttl")
	Else 
		This:C1470.peerTTL:=30
	End if 
	If (OB Is defined:C1231($options; "probeInterval"))
		This:C1470.probeInterval:=OB Get:C1224($options; "probeInterval")
	Else 
		This:C1470.probeInterval:=5
	End if 
	var $id : Text
	If (OB Is defined:C1231($options; "id"))
		$id:=OB Get:C1224($options; "id")
	Else 
		$id:=Generate UUID:C1066()
	End if 
	var $name : Text
	If (OB Is defined:C1231($options; "name"))
		$name:=OB Get:C1224($options; "name")
	Else 
		$name:=System info:C1571.machineName
	End if 
	var $servicePort : Integer
	If (OB Is defined:C1231($options; "servicePort"))
		$servicePort:=OB Get:C1224($options; "servicePort")
	Else 
		$servicePort:=0
	End if 
	var $version : Text
	If (OB Is defined:C1231($options; "version"))
		$version:=OB Get:C1224($options; "version")
	Else 
		$version:=System info:C1571.osVersion
	End if 
	This:C1470.myInfo:=New shared object:C1526("type"; "ANNOUNCE"; "id"; $id; "name"; $name; "port"; $servicePort; "version"; $version)
	This:C1470.peers:=New shared collection:C1527()
	This:C1470.running:=True:C214
	This:C1470.logText:=""
	This:C1470.closingSignal:=New signal:C1641()
	var $socketHolder : Object:=New shared object:C1526()
	Use ($socketHolder)
		$socketHolder.listener:=Null:C1517
		$socketHolder.sender:=Null:C1517
		$socketHolder.endOfInitialization:=New signal:C1641
	End use 
	CALL WORKER:C1389("p2pworker"; Formula:C1597($1._initSockets($2)); This:C1470; $socketHolder)
	$socketHolder.endOfInitialization.wait()
	This:C1470.listener:=$socketHolder.listener
	This:C1470.sender:=$socketHolder.sender
	
	
Function _initSockets($socketHolder : Object)
	Use ($socketHolder)
		$socketHolder.listener:=4D:C1709.UDPSocket.new(This:C1470.discoveryPort; This:C1470)
		$socketHolder.sender:=4D:C1709.UDPSocket.new(0; This:C1470)
	End use 
	$socketHolder.endOfInitialization.trigger()
	
	
Function sendAnnouncement()
	var $json : Text
	$json:=JSON Stringify:C1217(This:C1470.myInfo)
	var $blob : Blob
	TEXT TO BLOB:C554($json; $blob; UTF8 text without length:K22:17)
	Use (This:C1470)
		This:C1470.logText:=This:C1470.logText+"["+Time string:C180(Current time:C178)+"] Sent ANNOUNCE\n"
	End use 
	This:C1470.sender.send($blob; This:C1470.broadcastAddress; This:C1470.discoveryPort)
	
	
Function sendProbe()
	var $probe:=New shared object:C1526("type"; "PROBE"; "id"; This:C1470.myInfo.id)
	var $json : Text
	$json:=JSON Stringify:C1217($probe)
	var $blob : Blob
	TEXT TO BLOB:C554($json; $blob; UTF8 text without length:K22:17)
	Use (This:C1470)
		This:C1470.logText:=This:C1470.logText+"["+Time string:C180(Current time:C178)+"] Sent PROBE\n"
	End use 
	This:C1470.sender.send($blob; This:C1470.broadcastAddress; This:C1470.discoveryPort)
	
	
Function onData($socket : 4D:C1709.UDPSocket; $event : 4D:C1709.UDPEvent)
	var $text : Text
	$text:=BLOB to text:C555($event.data; UTF8 text without length:K22:17)
	var $obj : Object
	$obj:=New object:C1471
	$obj:=JSON Parse:C1218($text)
	If (Type:C295($obj)=Is object:K8:27)
		var $msgType : Text
		If (OB Is defined:C1231($obj; "type"))
			$msgType:=OB Get:C1224($obj; "type")
		Else 
			$msgType:=""
		End if 
		var $senderId : Text
		If (OB Is defined:C1231($obj; "id"))
			$senderId:=OB Get:C1224($obj; "id")
			Use (This:C1470)
				This:C1470.logText:=This:C1470.logText+"["+Time string:C180(Current time:C178)+"] Received "+$msgType+" from "+$event.address+":"+String:C10($event.port)+"\n"
			End use 
		Else 
			$senderId:=""
		End if 
		If ($senderId=This:C1470.myInfo.id)
			return 
		End if 
		If ($msgType="ANNOUNCE")
			This:C1470.addOrRefreshPeer($obj; $event.address; $event.port)
		Else 
			If ($msgType="PROBE")
				var $json : Text
				$json:=JSON Stringify:C1217(This:C1470.myInfo)
				var $blob : Blob
				TEXT TO BLOB:C554($json; $blob; UTF8 text without length:K22:17)
				This:C1470.sender.send($blob; $event.address; $event.port)
			Else 
				If ($msgType="BYE")
					This:C1470.removePeerById($senderId)
				End if 
			End if 
		End if 
	End if 
	
	
Function addOrRefreshPeer($peerObj : Object; $ip : Text; $port : Integer)
	var $id : Text
	If (OB Is defined:C1231($peerObj; "id"))
		$id:=OB Get:C1224($peerObj; "id")
	Else 
		$id:=""
	End if 
	If ($id="")
		return 
	End if 
	var $idx : Integer
	$idx:=-1
	var $i : Integer
	For ($i; 0; This:C1470.peers.length-1)
		If (This:C1470.peers[$i].id=$id)
			$idx:=$i
			break
		End if 
	End for 
	var $peerName : Text
	If (OB Is defined:C1231($peerObj; "name"))
		$peerName:=OB Get:C1224($peerObj; "name")
	Else 
		$peerName:=""
	End if 
	Use (This:C1470.peers)
		var $entry : Object
		$entry:=New shared object:C1526("id"; $id; "name"; $peerName; "ip"; $ip; "port"; $peerObj.port; "lastSeen"; Milliseconds:C459)
		If ($idx#-1)
			This:C1470.peers[$idx]:=$entry
		Else 
			This:C1470.peers.push($entry)
		End if 
		var $info : Object
		$info:=New shared object:C1526("type"; $peerObj.type; "id"; $id; "name"; $peerName; "port"; $peerObj.port; "version"; $peerObj.version)
		$entry.info:=$info
	End use 
	
	
Function removePeerById($id : Text)
	If ($id="")
		return 
	End if 
	var $i : Integer
	Use (This:C1470.peers)
		For ($i; 0; This:C1470.peers.length-1)
			If (This:C1470.peers[$i].id=$id)
				This:C1470.peers.remove($i; 1)
				break
			End if 
		End for 
	End use 
	
	
Function prunePeers()
	var $now : Integer
	$now:=Milliseconds:C459
	var $stillAlive : Collection
	$stillAlive:=New shared collection:C1527
	Use (This:C1470.peers)
		var $i : Integer
		For ($i; 0; This:C1470.peers.length-1)
			var $diff : Real
			$diff:=($now-This:C1470.peers[$i].lastSeen)/1000
			If ($diff<This:C1470.peerTTL)
				var $old : Object
				$old:=This:C1470.peers[$i]
				
				var $newInfo : Object
				$newInfo:=New shared object:C1526("type"; $old.info.type; "id"; $old.id; "name"; $old.name; "port"; $old.port; "version"; $old.info.version)
				
				var $newEntry : Object
				$newEntry:=New shared object:C1526("id"; $old.id; "name"; $old.name; "ip"; $old.ip; "port"; $old.port; "lastSeen"; $old.lastSeen; "info"; $newInfo)
				$stillAlive.push(OB Copy:C1225($newEntry; ck shared:K85:29; $stillAlive))
			End if 
		End for 
		Use (This:C1470)
			This:C1470.peers:=$stillAlive.copy(ck shared:K85:29; This:C1470)
		End use 
	End use 
	
	
Function stop()
	var $bye:=New shared object:C1526("type"; "BYE"; "id"; This:C1470.myInfo.id)
	var $json : Text
	$json:=JSON Stringify:C1217($bye)
	var $blob : Blob
	TEXT TO BLOB:C554($json; $blob; UTF8 text without length:K22:17)
	If (This:C1470.sender#Null:C1517)
		This:C1470.sender.send($blob; This:C1470.broadcastAddress; This:C1470.discoveryPort)
		Use (This:C1470)
			This:C1470.logText:=This:C1470.logText+"["+String:C10(Current time:C178)+"] Sent BYE\n"
		End use 
	Else 
		Use (This:C1470)
			This:C1470.logText:=This:C1470.logText+"["+String:C10(Current time:C178)+"] Skipped BYE send (sender not initialized)\n"
		End use 
	End if 
	This:C1470.closingSignal:=New signal:C1641()
	
	
Function getPeers() : Collection
	return This:C1470.peers.copy(ck shared:K85:29)
	
	
Function start()
	CALL WORKER:C1389("ProberWorker"; "proberMethod"; This:C1470)