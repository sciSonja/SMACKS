#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.


static Function AfterCompiledHook( )
	
	Execute "SetIgorOption FuncOptimize, CatchIllegalPandX=2"
	print "Ready to go!\r startSMACKS.ipf, please!" 

	return 0							
End
