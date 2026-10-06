//%attributes = {}
#DECLARE($form : Object)


If (cs:C1710.Window.me.demoWindow=0) | (cs:C1710.Window.me.demoWindow=Null:C1517)
	
	var $winRef : Integer
	var $win:=cs:C1710.Window.new()
	$winRef:=Open form window:C675("PeerFinder_UI"; Plain form window:K39:10; Horizontally centered:K39:1; Vertically centered:K39:4)
	$win.setDemoWindow($winRef)
	DIALOG:C40("PeerFinder_UI"; $form)
	CLOSE WINDOW:C154($winRef)
	
	$win.setDemoWindow(0)
	
Else 
	
	CALL FORM:C1391(cs:C1710.Window.me.demoWindow; "UpdateP2P"; $form)
	
End if 