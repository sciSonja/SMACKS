#pragma rtGlobals=2				//Use modern global access method and strict wave access.
#pragma version = 20181111



//##################################################
//# Set dataID : "don;acc;dir-acc;"
//##################################################

StrConstant dataID = "g_g;r_g;r_r;"


//##################################################
//# Include Proceedures (in curr DF)
//##################################################  

#include ":ascii_io"
#include ":HMM_proc"
#include ":TbT_proc"
#include ":ENS_proc"

#include ":SMACKS_addon"









static Function AfterCompiledHook( )

	Print "SMACKS is up & running."

	Execute/Z/P/Q "CloseProc /NAME=\"PREP_Igor7andHigher.ipf\" /COMP=0"

	return 0							
End


	
