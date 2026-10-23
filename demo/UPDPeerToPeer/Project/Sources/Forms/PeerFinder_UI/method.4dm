
Case of 
	: (Form event code:C388=On Load:K2:1)
		//Form.signal:=Null
		Form:C1466.peers:=New collection:C1472
		Form:C1466.workerRunning:=False:C215
		Form:C1466.autoRefresh:=False:C215
		Form:C1466.peerCount:=0
		Form:C1466.logText:=""
		Use (Storage:C1525)
			Storage:C1525.peers:=New shared collection:C1527
			Storage:C1525.logText:=New shared object:C1526("value"; "")
		End use 
		CALL WORKER:C1389("PeerDiscoveryWorker"; Formula:C1597(RunPeerDiscovery($1)); Form:C1466)
		SET TIMER:C645(60)
		
		
	: (Form event code:C388=On Timer:K2:25)
		Try
			Use (Storage:C1525)
				If (OB Is defined:C1231(Storage:C1525; "peers"))
					Form:C1466.peers:=Storage:C1525.peers.copy()
					Form:C1466.peerCount:=Form:C1466.peers.length
				Else 
					Form:C1466.peers:=New collection:C1472
					Form:C1466.peerCount:=0
				End if 
				If (OB Is defined:C1231(Storage:C1525; "logText"))
					Form:C1466.logText:=Storage:C1525.logText.value
				Else 
					Form:C1466.logText:=""
				End if 
			End use 
		Catch
			TRACE:C157
		End try
		
	: (Form event code:C388=On Close Box:K2:21)
		If (Form:C1466.signal#Null:C1517)
			Form:C1466.signal.wait(5)
			If (Form:C1466.signal.trigger())
				ALERT:C41(Localized string("Peer_AlertStoppedCleanly"))
			Else 
				KILL WORKER:C1390("PeerDiscoveryWorker")
				ALERT:C41(Localized string("Peer_AlertWorkerKilled"))
			End if 
			Form:C1466.signal:=Null:C1517
			Form:C1466.workerRunning:=False:C215
			SET TIMER:C645(0)
			Form:C1466.peers:=New collection:C1472
			Form:C1466.peerCount:=0
			Form:C1466.logText:=""
		End if 
		
	: (Form event code:C388=On Unload:K2:2)
		cs:C1710.Window.me.setDemoWindow(0)
		KILL WORKER:C1390("PeerDiscoveryWorker")
		KILL WORKER:C1390("p2pworker")
		
End case 