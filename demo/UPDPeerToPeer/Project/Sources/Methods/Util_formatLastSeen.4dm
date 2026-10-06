//%attributes = {}
#DECLARE($lastSeen : Integer)->$formatted : Text

var $diff : Real:=(Milliseconds:C459-$lastSeen)/1000  // Seconds elapsed

Case of 
	: ($diff<60)
		$formatted:=String:C10(Round:C94($diff; 1))+" seconds ago"
	: ($diff<3600)
		$formatted:=String:C10($diff\60)+" minutes ago"
	: ($diff<86400)
		$formatted:=String:C10($diff\3600)+" hours ago"
End case 
