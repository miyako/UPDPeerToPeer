property demoWindow : Integer

shared singleton Class constructor()
	
shared Function setDemoWindow($winRef : Integer)
	This:C1470.demoWindow:=$winRef
	
shared Function closeDemoWindow()
	If ((This:C1470.demoWindow=0) | (This:C1470.demoWindow=Null:C1517))
		return   // nothing to do
	End if 
	CLOSE WINDOW:C154(This:C1470.demoWindow)