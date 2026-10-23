//%attributes = {}
#DECLARE($lastSeen : Integer)->$formatted : Text

var $diff : Real:=(Milliseconds:C459-$lastSeen)/1000  // Seconds elapsed

Case of 
	: ($diff<60)
		$formatted:=Replace string(Localized string("Peer_SecondsAgo"); "{n}"; String:C10(Round:C94($diff; 1)))
	: ($diff<3600)
		$formatted:=Replace string(Localized string("Peer_MinutesAgo"); "{n}"; String:C10($diff\60))
	: ($diff<86400)
		$formatted:=Replace string(Localized string("Peer_HoursAgo"); "{n}"; String:C10($diff\3600))
End case 
