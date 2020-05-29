#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#pragma version = 20160530




//#######################################################
//#                                                     #
//#                 trace-by-trace HMM:                 #
//#                                                     #
//#######################################################


//initialize essential globals and waves:
Function TbT_Init()
	
	String/G root:HMM_inputPath = GetDataFolder(1)
	SVAR HMM_inputPath = root:HMM_inputPath
	NewDataFolder/O/S $UniqueName("TbT_", 11, 0)		
	String/G root:TbT_path = GetDataFolder(1)
	SVAR TbT_path = root:TbT_path

	print "TbT_Init: Data identifier: "+dataID+". Working at "+HMM_inputPath+" ."

	
	//init HMM default globals (in TbT_path)
	Variable /G NumStates = 2 
	Variable /G NumDims = 2
	Variable /G FRETcons = 1
	Variable /G ProdProbFB_MANT = 0
	Variable /G ProdProbFB_EXP = 0
	Variable /G ProbVit_MANT = 0
	Variable /G ProbVit_EXP = 0	
	String /G HMM_inputList = ""
	String /G HMM_currName = ""
	Make/O/N=1 HMM_s = -1	
	Make/O/D/N=0 logWave
		
	SetDataFolder HMM_inputPath
	HMM_inputList = WaveList(StringFromList(0, dataID)+"_*", ";", "" )	
	Variable nTraces = ItemsInList(HMM_inputList)
	if(nTraces==0)	//no input found
		KillDataFolder $TbT_path
		TbT_path = "_NONE_"
		DoWindow/K TbT_GUI
		Abort "TbT_init: No input found."
	endif
	Print "TbT_Init: Found", nTraces, "input traces."
	
	
	HMM_startParam(TbT_path)


	//create windows
	BtnLoadTbt("")
	TbT_prepInput(currListItem=0)
	TbT_prepGUI()
	
	DoWindow /F TbT_GUI
		
End






//################################
//# GUI
//################################


Function TbT_prepGUI()		

	DoWindow/K ENS_GUI			//kill TbT win
	DoWindow/K HMM_Output		//kill Viterbi Browser

	SVAR TbT_path = root:TbT_path	
	SVAR HMM_inputPath = root:HMM_inputPath	
	SVAR/Z HMM_inputList = $TbT_path+"HMM_inputList"
	

	//check paths
	if(!StringMatch(TbT_path, HMM_inputPath+"TbT_*:") || !DataFolderExists(TbT_path) || !SVAR_Exists(HMM_inputList) || ItemsInList(HMM_inputList)==0)
		string DFlist = ListMatch(DataFolderDir(1)[8,strlen(DataFolderDir(1))-3], "TbT_*", ",")

		do		//until proper input found
			TbT_path = HMM_inputPath+StringFromList(0, DFlist, ",")+":"
			SVAR/Z HMM_inputList = $TbT_path+"HMM_inputList"
			DFlist = RemoveListItem(0, DFlist, ",")
		while(!(SVAR_Exists(HMM_inputList) && ItemsInList(HMM_inputList)>0) && ItemsInList(DFlist)>0)
	endif
	
	if(!SVAR_Exists(HMM_inputList) || ItemsInList(HMM_inputList)==0)	//still no input found
		TbT_init()
		Return 0
	endif		


	SVAR HMM_currName = $TbT_path+"HMM_currName"
	NVAR NumStates = $TbT_path+"NumStates"
	NVAR NumDims = $TbT_path+"NumDims"
	NVAR FRETcons = $TbT_path+"FRETcons"

	
	DoWindow TbT_GUI
	if(V_flag)
		KillWindow TbT_GUI
	endif
	NewPanel/N=TbT_GUI/K=1/W=(47,45,1398,511) as "TbT Win > "+HMM_inputPath		
	ModifyPanel fixedSize=0,cbRGB=(59367,59367,59367)


	GroupBox group,pos={1028,-5},size={329,484},labelBack=(57346,65535,49151),frame=0

	GroupBox boxSettings,pos={1047,10},size={140,91},title="Settings",frame=0
	SetVariable SetNumStates,pos={1088,30},size={81,15},bodyWidth=40,proc=SetUpdateTbt,title="# States:"
	SetVariable SetNumStates,limits={1,inf,1},value=NumStates,live= 1
	SetVariable SetNumDims,pos={1067,54},size={102,15},bodyWidth=40,proc=SetUpdateTbt,title="# Dimensions:"
	SetVariable SetNumDims,limits={1,inf,1},value=NumDims,live= 1
	CheckBox FRETcons,pos={1082,78},size={87,15},title="FRET Constraint:",variable=FRETcons,side= 1
	if(NumDims!=2)
		CheckBox FRETcons,disable=2
	endif

	GroupBox boxParams,pos={1047,112},size={140,77},title="Params",frame=0
	Button BtnStart,pos={1063,134},size={106,20},proc=BtnLoadTbt,title="Initialize"
	Button BtnStore,pos={1062,160},size={50,20},proc=BtnStoreTbt,title="Store"
	Button BtnStore,help={"Store current Pi, a, b parameters for later use."}
	Button BtnRecall,pos={1122,160},size={50,20},proc=BtnRecallTbt,title="Recall"
	Button BtnRecall,help={"Recall previously stored Pi, a, b parameters."}

	GroupBox boxControls,pos={1220,10},size={111,179},title="Controls",frame=0
	Button BtnGo,pos={1235,33},size={35,25},proc=BtnGoTbT,title="GO"
	Button BtnGo,help={"Perform one iteration through ForwardBackward, BaumWelch & Viterbi."}
	Button BtnViterbi,pos={1280,33},size={35,25},proc=BtnViterbiTbT,title="Vit."
	Button BtnViterbi,help={"Calculate state sequence from current params."}
	Button BtnConv,pos={1235,68},size={80,40},proc=BtnConvTbT,title="\f01Converge"	
	Button BtnConv,help={"Iterate through ForwardBackward, BaumWelch & Viterbi until threshold is reached."}
	Button BtnConvStop,pos={1235,68},size={80,40},title="Stop",proc=BtnStopTbt	
	Button BtnConvStop,fColor=(65535,32768,32768),disable=3
	Button BtnNextInput,pos={1280,118},size={35,25},proc=BtnNextPrevTbt,title=">>"
	Button BtnPrevInput,pos={1235,118},size={35,25},proc=BtnNextPrevTbt,title="<<"
	Button BtnSave,pos={1235,153},size={35,25},proc=BtnSaveTbt,title="Save"
	Button BtnDelete,pos={1280,153},size={35,25},proc=BtnDeleteTbt,title="Del"

	PopupMenu InPathPop,pos={1049,201},size={73,20},bodyWidth=20,proc=PathProcTbt,title="Input Path: "
	PopupMenu InPathPop,mode=1,value=InPathMenu()
	TitleBox InPath,pos={1130,205},size={37,12},frame=0,variable=root:HMM_inputPath,anchor=LC	
	PopupMenu TbtPathPop,pos={1054,231},size={68,20},bodyWidth=20,proc=PathProcTbt,title="TbT Path: "
	PopupMenu TbtPathPop,mode=1,value=TbTPathMenu()
	TitleBox TbTPath,pos={1130,235},size={37,12},frame=0,variable=root:TbT_path,anchor=LC

	TabControl paramTabs,pos={12,304},size={977,144},proc=ToggleParamsTbt,value=1
	TabControl paramTabs,tabLabel(0)="Initial Params",tabLabel(1)="Current Params"
	ToggleParamsTbt("",1)		

	TbT_outputWin()
	SetVariable currData,pos={755,304},size={232,19},bodyWidth=150,title="Current Data:",frame=0
	SetVariable currData,limits={-inf,inf,0},value=HMM_currName,noedit= 1,fSize=12


	//handle log window
	DoWindow/W=TbT_GUI#convLog TbT_GUI
	if(!V_flag)
		Display/N=convLog/W=(1034,257,1351,461)/HOST=TbT_GUI $TbT_path+"logWave"	
		ModifyGraph margin(left)=57,margin(right)=20,wbRGB=(57346,65535,49151),gbRGB=(59367,59367,59367)
		ModifyGraph lblLatPos(left)=13,log(left)=1,mirror=2,rgb=(0,0,0)
		Label bottom "\Z14Iterations"
		Label left "\\Z14Normalized  Changes"
		SetActiveSubwindow ##
	endif

End



Function PathProcTbt(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	
	
	if(popNum==1 || StringMatch(popStr, "*<") || StringMatch(popStr, "*_NONE_*"))
		Return 0		//ignore click
	endif


	SVAR HMM_inputPath = root:HMM_inputPath
	SVAR/Z TbT_Path = root:TbT_Path


	strswitch(ctrlName)	
		case "InPathPop":			//TbT Win
			HMM_inputPath = ReplaceString(" ","root:"+popStr+":","")				//remove spaces...
			SetDataFolder HMM_inputPath
			TbT_prepGUI()
			break

		case "TbTPathPop":		//TbT Win
			TbT_path = ReplaceString(" ",HMM_inputPath + popStr + ":","") 		
			TbT_prepGUI()
			break
			
		default:							
			print "PathProcTbt: Unknown call."
	endswitch

End





Function TbT_outputWin()

	SVAR TbT_path = root:TbT_path			
	SVAR HMM_inputPath = root:HMM_inputPath
	DFREF saveDFR = GetDataFolderDFR()
	SetDataFolder TbT_path
	NVAR NumDims, NumStates
	
	DoWindow/W=TbT_GUI#HMM_Output TbT_GUI
	if(V_flag)	//Kill old win.
		KillWindow TbT_GUI#HMM_Output
	endif
	Display/N=HMM_Output/W=(9,0,1020,303)/FG=(,FT,,)/HOST=TbT_GUI	
	
	
	//init waves for display
	wave /Z wDispWaves
	if(!WaveExists(wDispWaves))	//if no input waves were found
		Make/O/N=(100,NumDims) wDispWaves=0
	endif
	wave/Z HMM_s
	if(!WaveExists(HMM_s))
		Make/O/N=100 HMM_s=-1	//just to display...	
	endif
		
		
	//display observable waves
	SetActiveSubwindow TbT_GUI#HMM_Output
	variable i, obsDim = dimSize(wDispWaves, 1)
	obsDim = (obsDim == 0)? 1 : obsDim
	for(i=0; i<obsDim;i+=1)	
		AppendToGraph wDispWaves[][i]
		
		//color
		if(obsDim==1)			
			ModifyGraph rgb(wDispWaves)=(0,0,65535)
			Break
		endif
				
		if(i==0)
			ModifyGraph rgb(wDispWaves)=(0,52428,0)
		elseif(i==1)
			ModifyGraph rgb($"wDispWaves#1")=(65535,0,0)
		elseif(i==2)
			ModifyGraph rgb($"wDispWaves#2")=(32768,0,0)
		endif		
	endfor
	

	//display HMM_s analogue
	AppendToGraph/W=#/R HMM_s
	ModifyGraph rgb(HMM_s)=(0,0,0),lsize(HMM_s)=2

	//nice up
	ReorderTraces wDispWaves,{HMM_s} 
	Label bottom, "\Z14Time" 
	Label right, "\Z14States"
	Label left, "\Z14Signal"	
	ModifyGraph mirror(bottom)=2,highTrip(left)=1000,notation(left)=1
	ModifyGraph wbRGB=(59367,59367,59367),margin(left)=57
	SetAxis bottom *,*
	SetAxis right 0,NumStates-1

	SetActiveSubwindow TbT_GUI
	SetDataFolder saveDFR	
	
End



Function ToggleParamsTbt(name,tab)
	String name
	Variable tab
	
	DFREF saveDFR = GetDataFolderDFR()
	SVAR TbT_path = root:TbT_path	
	SetDataFolder TbT_path

	wave HMM_pi_start, HMM_a_start, HMM_b_param_start
	wave HMM_pi, HMM_a, HMM_b_param


	DoWindow/W=TbT_GUI#paramTable TbT_GUI
	if(V_flag)	//Kill existing/old table.
		KillWindow TbT_GUI#paramTable
	endif

	
	if(tab==0)
		Edit/N=paramTable/W=(11,323,989,448)/HOST=TbT_GUI HMM_pi_start, HMM_a_start, HMM_b_param_start		
		ModifyTable format(Point)=1, width=80,showParts=0x4B, width[0]=40
	elseif(tab==1)
		Edit/N=paramTable/W=(11,323,989,448)/HOST=TbT_GUI HMM_pi, HMM_a, HMM_b_param
		ModifyTable format(Point)=1, width=80,showParts=0x4B, width[0]=40
	endif
	
	SetActiveSubwindow TbT_GUI
	SetDataFolder saveDFR
End



//update params
Function BtnLoadTbt(ctrlName) : ButtonControl
	String ctrlName
	
	SVAR TbT_path = root:TbT_path

	DFREF saveDFR = GetDataFolderDFR()
	SetDataFolder TbT_path
	
	NVAR NumStates, NumDims
	Wave HMM_pi_start, HMM_a_start, HMM_b_param_start
	Wave/Z HMM_pi, HMM_a, HMM_b_param
	Wave/Z wDispWaves
	Wave/Z/T wOutputNames
	Wave/Z collect_pi, collect_a, collect_b_param
	
	Duplicate /O HMM_pi_start, HMM_pi
	Duplicate /O HMM_a_start, HMM_a
	Duplicate /O HMM_b_param_start, HMM_b_param
	Redimension/N=0 $"logWave"

	
	//not from Btn Initialize
	if(!cmpStr(ctrlName, "recall") && WaveExists(wOutputNames))				
		
		if(NumStates!=dimSize(collect_a,0) || NumDims!=dimSize(collect_b_param,0)) 
			SetDataFolder saveDFR	//if settings have changed.
			Return 0
		endif
		
		String sStr = StringByKey("HMMWaves", note(wDispWaves), "=", "\r")
		string matchStr = StringFromList(0, dataID)
		sStr = StringFromList(0, ListMatch(sStr, matchStr+"*"))
		sStr = ReplaceString(matchStr, sStr, "HMM")


		//recall saved params if exist
		FindValue/TEXT=sStr+";" wOutputNames
		if(V_value>=0)		//if found
			HMM_pi = collect_pi[V_value][p]
			HMM_a = collect_a[p][q][V_value]
			HMM_b_param = collect_b_param[p][q][r][V_value]
		endif
	endif
	
	SetDataFolder saveDFR	
	
End



Function SetUpdateTbt(ctrlName,varNum,varStr,varName) : SetVariableControl
	string ctrlName
	Variable varNum
	String varStr
	String varName

	SVAR TbT_path = root:TbT_path
	SVAR HMM_inputPath = root:HMM_inputPath
	SetDataFolder TbT_path	
	NVAR NumDims, FRETcons

	if(NumDims==2)
		CheckBox FRETcons, win=TbT_GUI, value=1, disable=0
	else
		CheckBox FRETcons, win=TbT_GUI, value=0, disable=2
	endif
		
	TbT_prepInput()
	HMM_startParam(TbT_path)
	TbT_outputWin()
	
	SetDataFolder HMM_inputPath
	print "SetUpdateTbT: Modified settings not initialized, yet."

End




//store current params
Function BtnStoreTbt(ctrlName) : ButtonControl
	String ctrlName
	
	SVAR TbT_path = root:TbT_path		
	DFREF saveDFR = GetDataFolderDFR()
	SetDataFolder TbT_path		

	//store params
	Duplicate/O $"HMM_pi" HMM_pi_store
	Duplicate/O $"HMM_a" HMM_a_store
	Duplicate/O $"HMM_b_param" HMM_b_store
	
	SetDataFolder saveDFR

End



//use stored params
Function BtnRecallTbt(ctrlName) : ButtonControl
	String ctrlName
	
	SVAR TbT_path = root:TbT_path	
	
	DFREF saveDFR = GetDataFolderDFR()
	SetDataFolder TbT_path		

	wave/Z HMM_a_store 
	wave/Z HMM_pi_store
	wave/Z HMM_b_store

	if(!WaveExists(HMM_pi_store) || !WaveExists(HMM_a_store) || !WaveExists(HMM_b_store))
		SetDataFolder saveDFR
		Print "HMM_BtnRecallParams: No params to recall!"
	endif

	Duplicate/O HMM_pi_store HMM_pi
	Duplicate/O HMM_a_store HMM_a
	Duplicate/O HMM_b_store HMM_b_param

	SetDataFolder saveDFR
	
End




Function BtnGoTbT(ctrlName) : ButtonControl
	string ctrlName
	
	SVAR TbT_path = root:TbT_path

	variable change = TbT_iterate()

	if(change<0)	//abort			
		print "BtnGoTbT: Numerical error. Abort code:", abs(change)
	elseif(numtype(change))
		print "BtnGoTbT: Numerical error."		//("change" diverges if diagonal transitions get zero.)
		wave HMM_s = $TbT_path+"HMM_s"
		HMM_s = Nan
	endif	

End




Function BtnViterbiTbT(ctrlName) : ButtonControl
	string ctrlName

	SVAR TbT_path = root:TbT_path		
	DFREF saveDFR = GetDataFolderDFR()
	SetDataFolder TbT_path	
	wave HMM_s		
	
	
	try
		HMM_Viterbi_multidim()
	catch
		HMM_s = Nan	
		print "BtnViterbiTbT: Numerical error."	
	endtry
	
	SetDataFolder saveDFR
End



//loop until delta(ProdProbFB) < thrshld
Function BtnConvTbT(ctrlName) : ButtonControl
	String ctrlName
	
	Variable thrshld = 1E-10
	Variable change

	SVAR HMM_inputPath = root:HMM_inputPath
	SVAR TbT_path = root:TbT_path
	SetDataFolder TbT_path
	
	wave/Z HMM_a
	wave logWave, HMM_s
	NVAR NumDims, NumStates
	SVAR HMM_currName
	Variable/G vStop=0


	//check if consistent parames (i.e. if "initialized")
	if(!WaveExists(HMM_a) || dimSize(HMM_a,0) != NumStates)
		SetDataFolder HMM_inputPath
		Print "Initialize params!"
		Abort "BtnConvEns: Inconsistent params. Initialize params first!"
	endif

	//update controls 	
	string ctrlList = RemoveFromList("BtnConvStop;", ControlNameList("TbT_GUI"))
	ModifyControlList ctrlList disable=2	
	Button BtnConvStop,win=TbT_GUI,disable=0
	DoUpdate/W=TbT_GUI /E=1


	//handle log window
	DoWindow/W=TbT_GUI#convLog TbT_GUI
	if(!V_flag)
		Display/N=convLog/W=(1029,262,1343,537)/FG=(,,FR,)/HOST=TbT_GUI logWave
		ModifyGraph wbRGB=(59367,59367,59367),gbRGB=(59367,59367,59367)
		ModifyGraph margin(left)=57,margin(right)=20,mirror=2,log(left)=1
		Label left "\Z14Changes"
		Label bottom "\Z14Iterations"
		SetActiveSubwindow ##
	endif
	
	
	//THE LOOP
	do 			
		change = TbT_iterate()		//<0 if aborted
				
		DoUpdate/W=TbT_GUI	
	while(change > thrshld && vStop==0)
	
	if(change<0)	//abort			
		print "BtnConvTbT: Numerical error @ "+HMM_currName+". Abort code:", abs(change)
	elseif(numtype(change))
		print "BtnConvTbT: Numerical error @ "+HMM_currName+"."		//("change" diverges if diagonal transitions get zero.)
		HMM_s = Nan
	endif


	//update controls
	ModifyControlList/Z ctrlList win=TbT_GUI,disable=0	
	Button BtnConvStop,win=TbT_GUI,disable=3
	if(NumDims!=2)
		CheckBox FRETcons,disable=2
	endif

	SetDataFolder HMM_inputPath
	
End



Function BtnStopTbt(ctrlName) : ButtonControl
	String ctrlName

	NVAR vStop
	vStop=1	

End




Function BtnNextPrevTbT(ctrlName) : ButtonControl
	string ctrlName
		
	SVAR TbT_path = root:TbT_path			
	SVAR HMM_inputPath = root:HMM_inputPath
	
	SVAR HMM_inputList = $TbT_path+"HMM_inputList"
	SVAR HMM_currName = $TbT_path+"HMM_currName"
	NVAR NumDims = $TbT_path+"NumDims"
	
	NextPrevTbt(ctrlName)	
	SetAxis/W=TbT_GUI#HMM_Output bottom *,*	

End



Function NextPrevTbT(ctrlName)
	string ctrlName
		
	SVAR TbT_path = root:TbT_path				
	SVAR HMM_inputList = $TbT_path+"HMM_inputList"	
	SVAR HMM_currName = $TbT_path+"HMM_currName"
	
	variable currListItem
	
	if(StringMatch(ctrlName, "*next*"))
		currListItem = WhichListItem(HMM_currName, HMM_inputList)+1
	elseif(StringMatch(ctrlName, "*prev*"))
		currListItem = WhichListItem(HMM_currName, HMM_inputList)-1
	else
		Print "NextPrevHmm: Unknown input!"
		Return 0
	endif
	
	If(currListItem >= ItemsInList(HMM_inputList))
		Print "NextPrevHmm: Last trace reached!"
		Return 0
	elseif(currListItem<0)
		Print "NextPrevHmm: First trace reached!"
		Return 0
	endif
	
	//new HMM run
	TbT_prepInput(currListItem =currListItem)
	BtnLoadTbt("recall")
	
End



Function BtnSaveTbT(ctrlName) : ButtonControl
	string ctrlName	
	
	SVAR TbT_path = root:TbT_path			
	SVAR HMM_inputPath = root:HMM_inputPath
	DFREF saveDFR = GetDataFolderDFR()
	SetDataFolder TbT_path
	NVAR NumDims, NumStates
	
	wave HMM_s
	variable startP, endP
	string outputStr = StringByKey("HMMWaves", note(HMM_s), "=", "\r")
	outputStr = StringFromList(0, ListMatch(outputStr, StringFromList(0,dataID)+"*"))
	outputStr = ReplaceString(StringFromList(0,dataID), outputStr, "HMM")
	
	duplicate/O HMM_s $outputStr
	
	//notes
	Note $outputStr, "HMM_dim/states="+num2str(NumDims)+"/"+num2str(NumStates)

	//params
	variable verbose = cmpStr(ctrlName, "")	//only verbose if called from button.
	TbT_collectParams(outputStr, verbose=verbose)
	
	SetDataFolder saveDFR
End




//delete parameters saved for current trace.
Function BtnDeleteTbT(ctrlName) : ButtonControl
	string ctrlName	
	
	SVAR TbT_path = root:TbT_path			
	SVAR HMM_inputPath = root:HMM_inputPath
	DFREF saveDFR = GetDataFolderDFR()
	SetDataFolder TbT_path
	
	wave HMM_s
	string outputStr = StringByKey("HMMWaves", note(HMM_s), "=", "\r")
	outputStr = StringFromList(0, ListMatch(outputStr, StringFromList(0,dataID)+"*"))
	outputStr = ReplaceString(StringFromList(0,dataID), outputStr, "HMM")

	wave/Z wOutput = $outputStr
	
	if(!WaveExists(wOutput))
		Print "BtnDeleteTbt: Wave does not exist."
		SetDatafolder saveDFR
		Return 0
	endif

	KillWaves/Z wOutput
	if(WaveExists(wOutput))	
		SetDatafolder saveDFR
		Abort "BtnDeleteTbt: Could not delete: "+outputStr+" !"
	endif

	TbT_deleteParams(outputStr)

	//reset:
	BtnLoadTbt("")
	Redimension/N=1 HMM_s 
	HMM_s = 0
		
	SetDataFolder saveDFR
End






//################################
//# Main: TbT HMM
//################################


Function TbT_iterate()

	SVAR TbT_path = root:TbT_path		
	DFREF saveDFR = GetDataFolderDFR()
	SetDataFolder TbT_path		
	
	
	//check if params are ready:
	wave/Z HMM_pi, HMM_a, HMM_b_param
	if(!WaveExists(HMM_pi) || !WaveExists(HMM_a) || !WaveExists(HMM_b_param))
		SetDataFolder saveDFR
		Abort "BtnGoHmm: Initialise parameters first. \r-> \"Initial Params\""
	endif
	wave logWave, HMM_s
	
	
	try
		HMM_ForwardBackward_parallel(mute=1)
		HMM_BaumWelch_multidim()
		wave HMM_pi, HMM_a, HMM_b_param
		wave HMM_pi_new, HMM_a_new, HMM_b_param_new
		WaveStats/Q/M=1 HMM_b_param_new
		//catch Nans & Infs
		AbortOnValue V_numNaNs+V_numINFs, 33

		//check convergence & update params
		MatrixOP/O/FREE change = Trace(abs(HMM_a - HMM_a_new)/HMM_a_new)	
		HMM_pi = HMM_pi_new																
		HMM_a = HMM_a_new
		HMM_b_param = HMM_b_param_new			

		HMM_Viterbi_multidim(mute=1)
	catch	
		HMM_s = Nan
		Return -V_AbortCode	
	endtry


	//log
	Redimension/N=(numpnts(logWave)+1) logWave
	logWave[numpnts(logWave)-1]=change[0]

	
	SetDataFolder saveDFR	
	Return change[0]
	
End




//batch process dataset in "trace by trace" HMM mode (cont.)
//You are in charge of TbT_Init etc.
Function TbT_CONVERGE(totIter[, convOnly])
	variable totIter		//# of iterations for each input trace
	variable convOnly		//save converged traces only. (ergo no "static" traces)
	
	DoWindow/F TbT_GUI
	if(V_Flag==0)		//TbT win does not exist
		TbT_prepGUI()
	endif

	SVAR HMM_inputPath = root:HMM_inputPath
	SVAR/Z TbT_path = root:TbT_path
	SetDataFolder TbT_path	

	SVAR HMM_inputList	
	wave HMM_pi, HMM_a, HMM_b_param
	wave wObsWaves, logWave, HMM_s

	String/G nonConvList = ""
	Variable/G vStop = 0
	variable i, j
	variable nTraces = ItemsInList(HMM_inputList)
	variable thrshld = 1E-10, count=0


	DoUpdate/W=TbT_progress /E=1
	TbT_prepBatch(nTraces)	
	TbT_prepInput(currListItem=0)


	//over all traces
	for(i=0; i<nTraces; i+=1)	
		BtnLoadTbt("")
	
		//iterations
		j=0
		do	
			try
				HMM_ForwardBackward_parallel(mute=1)
				HMM_BaumWelch_multidim()
				wave HMM_pi_new, HMM_a_new, HMM_b_param_new
				WaveStats/Q/M=1 HMM_b_param_new
				AbortOnValue V_numNaNs+V_numINFs, 44

				MatrixOP/O/FREE change = Trace(abs(HMM_a - HMM_a_new)/HMM_a_new)	//check convergence
				HMM_pi = HMM_pi_new					//update params
				HMM_a = HMM_a_new
				HMM_b_param = HMM_b_param_new
				Redimension/N=(j+1) logWave
				logWave[j] = change[0]
				DoUpdate/W=TbT_GUI#convLog 
			catch	
				string strCurr = StringFromList(i, HMM_inputList)
				print "TbT_CONVERGE: numerical error @ "+strCurr+", code =", V_AbortCode	
				nonConvList = nonConvList+num2str(i)+" "+strCurr+";"	
				Break	
			endtry
						
			
			ValDisplay/Z valdisp0,win=TbT_Progress,value=_NUM:i+1
			if(vStop==1)				
				TbT_postBatch()				
				SetDataFolder HMM_inputPath
				Return 0
			endif

			j+=1
		while(change[0]>thrshld && j<totIter)
				
		
		if(!V_AbortCode)
			try
				HMM_Viterbi_multidim(mute=1)
				DoUpdate/W=TbT_GUI#HMM_Output
			catch
				HMM_s = NaN
				print "TbT_CONVERGE: numerical error @ "+strCurr+", code =", V_AbortCode	
			endtry
		endif
		
		
		if(ParamIsDefault(convOnly))	//save all	(include bad & static traces)
			BtnSaveTbt("")
		elseif(!V_AbortCode)			//save converged only
			BtnSaveTbt("")
			count+=1
		endif
		
		BtnNextPrevTbt("Next")	
		V_AbortCode = 0
	endfor

	TbT_postBatch()
	TbT_prepInput(currListItem=0)
	SetDataFolder HMM_inputPath
	print "TbT_converge: Converged", nTraces-ItemsInList(nonConvList), "of", nTraces, "input traces."
	
End




// includes calc_mean_params & new inputList
Function TbT_apply_means()
	
	DFREF saveDFR = GetDataFolderDFR()	
	SVAR/Z TbT_path = root:TbT_path
	
	if(!SVAR_Exists(TbT_path) || !DataFolderExists(TbT_path))
		Abort "Perform TbT workflow first!"
	endif
	
	SetDataFolder TbT_path	
	wave/Z wOutputNames
	if(!WaveExists(wOutputNames) || dimSize(wOutputNames,0)==0)
		SetDataFolder saveDFR
		Abort "Perform TbT workflow first!"
	endif
		
	
	SVAR HMM_inputList	
	wave HMM_a, HMM_b_param
	wave collect_b_param


	TbT_calcMeanParams()
	wave mean_b_param

	string inputList_new = ""
	variable i, nTraces = ItemsInList(HMM_inputList)
	variable nPrevOut = dimSize(wOutputNames,0)
	print "TbT_apply_means: Found saved parameters for",nPrevOut,"of",nTraces,"input traces."

	//over all traces in HMM_inputList
	for(i=0; i<nTraces; i+=1)	
	
		//skip traces that are already in wOutputNames 
		string sourceName = StringFromList(i, HMM_inputList)
		string currName = ReplaceString(StringFromList(0,dataID),sourceName,"HMM")
		FindValue/TEXT=currName+";" wOutputNames
		if(V_value!=-1)
			Continue
		endif
		
		TbT_prepInput(currListItem=i)
		BtnLoadTbt("")
		HMM_b_param = mean_b_param
		try
			HMM_Viterbi_multidim(mute=1)	
		catch
			Continue		
		endtry	
		BtnSaveTbt("")	
		inputList_new = inputList_new+sourceName+";"
	endfor

	//update inputList for control of the "static" subset only
	String/G HMM_inputList_tot = HMM_inputList
	HMM_inputList = inputList_new
	TbT_prepInput(currListItem=0)

	Edit/K=1/W=(894,534,1399,741)/N=mean_b_params mean_b_param	
	BtnLoadTbt("recall")
	SetDataFolder saveDFR
	
End




//###################
//# Helper Functions
//###################



//create input for HMM (multidim)
Function TbT_prepInput([currListItem])
	Variable currListItem
	
	SVAR TbT_path = root:TbT_path			
	SVAR HMM_inputPath = root:HMM_inputPath
	DFREF saveDFR = GetDataFolderDFR()
	SetDataFolder TbT_path		
		
	NVAR NumStates, NumDims
	SVAR HMM_inputList
	SVAR HMM_currName
	wave HMM_pi, HMM_a, HMM_b_param
	wave/T/Z wOutputNames
	wave/D/Z collect_pi, collect_a, collect_b_param
	
	string currAssocList, currAssocStr
	variable i, nItems, rows


	if(!ParamIsDefault(currListItem)) // HMM_currName is updated
		HMM_currName = StringFromList(currListItem, HMM_inputList)
	endif
	wave/Z currWave = $HMM_inputPath+HMM_currName
	if(!WaveExists(currWave))
		Print "TbT_prepInput: No input waves found!"
		SetDataFolder saveDFR
		Return -1
	endif
	currAssocList = StringByKey("AssociatedWaves" , note(currWave), "=", "\r")
	nItems = ItemsInList(currAssocList)
	if (nItems > 0 && nItems < NumDims)	//if there is input, but not enough dimensions
		SetDataFolder saveDFR
		Print "TbT_prepInput: "+num2str(nItems)+"-dimensional data supplied, but "+num2str(NumDims)+" dimensions set!"
		Return -1
	endif
		
	
	//create displayed copy of observables in TbT_path
	//fill all items of currAssocList into wDispWaves, (in order of currAssocList)
	Duplicate/O currWave wDispWaves	
	Redimension/N=(-1, NumDims) wDispWaves
	string HMMwavesList = ""
	for (i=0; i<NumDims; i+=1)
		currAssocStr = RemoveEnding(ListMatch(currAssocList, StringFromList(i, dataID)+"*"))
		HMMwavesList = HMMwavesList+currAssocStr+";"
		wave currAssocWave = $HMM_inputPath+currAssocStr			
		if(dimSize(currAssocWave,0)<DimSize(wDispWaves, 0))	//ALEX waves can be 1pnt shorter: remove last point
			Redimension/N=(rows, -1) wDispWaves
		endif	
		wDispWaves[][i] = currAssocWave[p]		
	endfor

	//make HMM working copy of observables
	Note wDispWaves, "HMMwaves="+HMMwavesList	//currAssocList
	duplicate/O wDispWaves wObsWaves
	 
	
	//recall saved output if exists
	string sStr = StringByKey("HMMWaves", note(wDispWaves), "=", "\r")
	sStr = StringFromList(0, ListMatch(sStr, StringFromList(0, dataID)+"*" ) )

	Variable posStart = strsearch(sStr, "_x", 0)		//sStr can be "g_g_x123_*" or "FRET_G_b_x123_*", get position of string "_x"
	sStr = "HMM"+sStr[posStart, strlen(sStr)-1]
	if(WaveExists($TbT_path+sStr))
		Duplicate/O $TbT_path+sStr HMM_s 
	else	
		Make/O/N=1 HMM_s = -1	//reset
	endif	
		

	//include single_B params if exists (for evaluation)
	string strCurr_b = "b"+sStr[3, strlen(sStr)-1]
	Wave/Z wCurr_b = $strCurr_b	
	if(WaveExists(wCurr_b))
		Duplicate/O wCurr_b HMM_b_param
	endif
	Make/O/N=0/D logWave
	
	
	SetDataFolder saveDFR	
End


function TbT_collectParams(outputStr[, verbose])
	string outputStr
	variable verbose
	
	NVAR NumStates, NumDims
	wave HMM_pi, HMM_a, HMM_b_param
	wave/T/Z wOutputNames
	wave/D/Z collect_pi, collect_a, collect_b_param

	variable newNum

	//new NumStates/NumDims over-writes existing collect waves.
	if(!WaveExists(wOutputNames) || NumStates!=dimSize(collect_a,0) || NumDims!=dimSize(collect_b_param,0))
		Make/O/T/N=1 wOutputNames
		Make/O/D/N=(1, NumStates) collect_pi = 0
		Make/O/D/N=(NumStates, NumStates, 1) collect_a = 0
		Make/O/D/N=(NumDims, 1+NumDims, NumStates, 1) collect_b_param = 0		
		newNum = 0
	else
	
		//check consistency
		variable a=dimsize($"wOutputNames", 0), b=dimsize($"collect_pi", 0)
		variable c=dimsize($"collect_a", 2), d=dimsize($"collect_b_param", 3)	
		if(numtype(a+b+c+d)==2)	//if nan -> lost a wave
			DoAlert 0, "collectParamsTbt: Incomplete parameter set. Please check!" 
			Return -1
		endif			
		if(a!=b ||  b!=c || c!=d)	//if differing sizes
			DoAlert 0, "collectParamsTbt: Inconsistent parameter set. Please check!" 
			Return -1
		endif
		

		//prepare for update
		FindValue/TEXT=outputStr+";" wOutputNames
		if(V_value==-1)	//string not found
			newNum = dimSize(wOutputNames,0) +1
			Redimension/N=(newNum) wOutputNames
			Redimension/N=(newNum, -1) collect_pi
			Redimension/N=(-1, -1, newNum) collect_a
			Redimension/N=(-1, -1, -1, newNum) collect_b_param
			newNum-=1
		else					//string found
			newNum = V_value
			if(verbose)
				Print "collectParamsTbt: params for "+outputStr+" were replaced."
			endif
		endif		
	endif

	
	//update
	wOutputNames[newNum] = outputStr+";"
	collect_pi[newNum][] = HMM_pi[q]
	collect_a[][][newNum] = HMM_a[p][q]
	collect_b_param[][][][newNum] = HMM_b_param[p][q][r]

end


function TbT_deleteParams(outputStr)
	string outputStr
	
	NVAR NumStates, NumDims
	wave HMM_pi, HMM_a, HMM_b_param
	wave/T/Z wOutputNames
	wave/D/Z collect_pi, collect_a, collect_b_param

	variable newNum

	if(!WaveExists(wOutputNames) || !WaveExists(collect_pi) || !WaveExists(collect_a) || !WaveExists(collect_b_param))
		DoAlert 0, "deleteParamsTbt: Incomplete parameter set. Please check!"
		Return 0
	endif

	FindValue/TEXT=outputStr+";" wOutputNames
	if(V_value==-1)
		Print "deleteParamsTbt: Found no stored params for ",outputStr,"."
		Return 0
	endif
	
	DeletePoints/M=0 V_value, 1, wOutputNames, collect_pi
	DeletePoints/M=2 V_value, 1, collect_a 
	DeletePoints/M=3 V_value, 1, collect_b_param
	Print "deleteParamsTbt: Params for "+outputStr+" were deleted."
	
	Return 1		

end



Function TbT_postBatch()

	string ctrlList = RemoveFromList("BtnConvStop;", ControlNameList("TbT_GUI"))		//enable TbT controls
	ModifyControlList ctrlList disable=0	
	KillWindow TbT_Progress

End



function TbT_prepBatch(nTraces)
	variable nTraces
	
	wave logWave

	NewPanel/K=1/FLT/N=TbT_Progress/W=(1083,169,1398,239)
	SetActiveSubwindow _endfloat_
	ValDisplay valdisp0,win=TbT_Progress,pos={18,23},size={199,13},appearance={native,All}
	ValDisplay valdisp0,win=TbT_Progress,limits={0,nTraces,0},barmisc={0,0},mode= 3,value= _NUM:0.2
	Button bStop,win=TbT_Progress,pos={241,19},size={50,20},title="Stop",fColor=(65535,0,0),proc=BtnStopTbt
	DoUpdate/W=TbT_Progress/E=1		

	//disable TbT controls
	string ctrlList = RemoveFromList("BtnConvStop;", ControlNameList("TbT_GUI"))
	ModifyControlList ctrlList disable=2	

	DoWindow TbT_GUI		//no convLog window if TbT_GUI was closed
	if(!V_flag)
		Return 0
	endif

	DoWindow/W=TbT_GUI#convLog TbT_GUI
	if(!V_flag)
		Display/N=convLog/W=(1027,295,1348,519)/HOST=TbT_GUI logWave
		Label/W=TbT_GUI#convLog left "\Z14Changes"
		Label/W=TbT_GUI#convLog bottom "\Z14Iterations"
		SetActiveSubwindow TbT_GUI
	endif

end




//use converged mean params for statics:
function TbT_calcMeanParams()

	SVAR nonConvList
	wave b_params = collect_b_param, HMM_b_param_start
	wave/T wOutputNames
	variable i, n=dimSize(b_params,3), nDel=0
	
	Duplicate/O HMM_b_param_start mean_b_param
	mean_b_param = 0
	
	//remove nonConv params
	for(i=0;i<n;i+=1)		
		string currStr = StringFromList(0, wOutputNames[i-nDel])
		if(StringMatch(nonConvList, "*"+currStr[3,inf]+";"))			
			TbT_deleteParams(wOutputNames[i-nDel])								//delete nonCons b_params
			Killwaves $currStr
			nDel+=1
		else
			mean_b_param = mean_b_param + b_params[p][q][r][i-nDel] 	//calc mean from optimized b_params
		endif		
	endfor
	n=dimSize(b_params,3)
	mean_b_param/=n	
	
	//mean A
	wave collect_a
	ImageTransform/METH=2 zProjection collect_a
	wave M_zProjection
	duplicate/O M_zProjection mean_a
	
End



