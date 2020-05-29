#pragma rtGlobals=2		// Use modern global access method and strict wave access.

#pragma version = 20181111




//#######################################################
//#                                                     #
//#                 semi-ENSemble HMM:                  #
//#                                                     #
//#######################################################


Function ENS_init()

	DoWindow/K TbT_GUI			//kill TbT win
	DoWindow/K HMM_Output		//kill Viterbi Browser

	String/G root:HMM_inputPath
	SVAR HMM_inputPath = root:HMM_inputPath		
	print "ENS_Init: Data identifier: "+dataID+". Working at "+HMM_inputPath+" ."


	//check if TbT info is ready	
	if(ENS_notReady())	
		DoWindow/K ENS_GUI	//user canceled
		Return 1		
	endif

	//create folder
	NewDataFolder/O/S $HMM_inputPath+UniqueName("ENS_", 11, 0)
	String/G root:ENS_path = GetDataFolder(1)
	SVAR ENS_path = root:ENS_path
	SVAR TbT_path = root:TbT_path


	//init globals	
	String/G myTbT_path = TbT_path
	NVAR NumDimsTbT = $myTbT_path+"NumDims"		//dimensions of the default TbT_path
	Variable/G NumDims = NumDimsTbT
	Variable/G NumStates = 3
	String/G stateConfig = "001"
	Variable/G FRETcons = 1
	Variable/G vDbal = 0
	Variable/G maxIter = 500
	Variable/G convThrshld = 1E-15
	Variable/G vVerbose = 0
	Variable/G ProdProbFB_MANT, ProdProbFB_EXP
	Variable/G ProbVit_MANT, ProbVit_EXP	
	Variable/G logP_FB=0, vBIC=0


	//prep logs
	Make/O/D/N=0 log_BIC = 0, logWave=0, log_logP_FB=0
	Make/O/D/N=(0, 0) log_pi = 0
	Make/O/D/N=(0, 0, 0) log_a = 0
	Make/O/N=0 countStateOcc


	//init ENS params
	HMM_startParam(ENS_path)
	ENS_Params(start=1)	
	if(ENS_prepBnRefs())	
		KillDataFolder $ENS_path	//no B params found
	endif

	
	ENS_prepGUI()		

	SetDataFolder HMM_inputPath

End






//#######################################################
//# GUI
//#######################################################



Function ENS_prepGUI([tab])
	variable tab		//set active tab

	DoWindow/K TbT_GUI			//kill TbT win
	DoWindow/K HMM_Output		//kill Viterbi Browser


	SVAR/Z HMM_inputPath = root:HMM_inputPath	
	SVAR/Z ENS_path = root:ENS_path
	if(!SVAR_Exists(HMM_inputPath) || !SVAR_Exists(ENS_path))
		ENS_init()
		Return 0
	endif
	wave/Z wInputRef = $ENS_path+"wInputRef"		

	//if currDF is a different but valid inputPath
	if(cmpStr(HMM_inputPath, GetDataFolder(1)) && StringMatch(DataFolderDir(1),"*TbT_*") && StringMatch(DataFolderDir(1),"*ENS_*"))
		HMM_inputPath = GetDataFolder(1)		
	endif
	SetDataFolder HMM_inputPath
	
	//check ENS Path consistency:
	if(!StringMatch(ENS_path, HMM_inputPath+"ENS_*") || !DataFolderExists(ENS_path) || !WaveExists(wInputRef) || dimSize(wInputRef,0)==0)
		string DFlist = ListMatch(DataFolderDir(1)[8,strlen(DataFolderDir(1))-3], "ENS_*", ",")

		do	//until proper input found
			ENS_path = HMM_inputPath+StringFromList(0, DFlist, ",")+":"
			wave/Z wInputRef = $ENS_path+"wInputRef"		
			DFlist = RemoveListItem(0, DFlist, ",")
		while(!(WaveExists(wInputRef) || dimSize(wInputRef,0)>0) && ItemsInList(DFlist)>0)
	endif

	if(!WaveExists(wInputRef) || dimSize(wInputRef,0)==0)		//still missing input
		ENS_init()
		Return 0
	endif


	DoWindow/F ENS_GUI
	if(ParamIsDefault(tab))	//default call
		if(V_flag)					// ENS_GUI exists
			KillWindow ENS_GUI
		endif
		NewPanel/N=ENS_GUI/K=1/W=(288,45,1018,664)  as "ENS Win > "+HMM_inputPath	
		ModifyPanel cbRGB=(59367,59367,59367)

		//controls labeled by "_" are not touched by clearGuiEns()
		PopupMenu InPathPop_,pos={26,17},size={73,20},bodyWidth=20,proc=PathProcEns,title="Input Path: "
		PopupMenu InPathPop_,mode=1,value=InPathMenu()	
		TitleBox InPath_,pos={109,21},size={111,12},variable=root:HMM_inputPath,frame=0,anchor=LC

		Button BtnBatchConv_,pos={602,18},size={80,50},proc=BtnBatchConv,title="\f01Batch\rConverge"
		Button newSetup_,pos={458,18},size={90,20},proc=BtnNewSetup,title="New Setup"
		
		ENS_updateSetups()		//updated number of setups

	else								//if called from ToggleSetupsEns
		TabControl setupTab_,win=ENS_GUI,value=tab
		clearGuiEns()		
	endif
	
	
	//General Controls	
	SetDataFolder ENS_path
	NVAR NumDims, FRETcons, vDbal, maxIter, convThrshld, vBIC
	SVAR myTbT_path, StateConfig
	wave logWave, log_logP_FB, countStateOcc, wInputRef
	variable inputCount = dimSize(wInputRef,0)
	SVAR TbT_path = root:TbT_path
	TbT_path = myTbT_path
	
	SetVariable SetNumDims,pos={43,104},size={122,15},bodyWidth=60,title="# Dimensions:"
	SetVariable SetNumDims,limits={1,inf,0},value=NumDims,noedit=1,frame=0
	SetVariable StateConfig,pos={44,131},size={154,15},proc=SetStateConfig,value=_STR:StateConfig,title="State Config.:"
	Button BtnLoadEns,pos={63,168},size={90,20},proc=BtnLoadEns,title="Initialize"
	GroupBox sep1,pos={231,104},size={0,90}
	
	SetVariable maxIter,pos={277,104},size={128,15},bodyWidth=60,limits={0,inf,0},value=maxIter,title="Max. Iterations:"
	SetVariable convThrshld,pos={266,131},size={139,15},bodyWidth=60,title="Conv. Threshhold:"
	SetVariable convThrshld,limits={0,inf,0},value=convThrshld
	CheckBox DBal,pos={272,159},size={89,15},side=1,variable=vDbal,title="Detailed Balance:"
	GroupBox sep2,pos={434,104},size={0,90}

	TitleBox TbTPath,pos={535,105},size={123,12},frame=0,variable=TbT_path,anchor= LC
	PopupMenu TbtPathPop,pos={458,101},size={68,20},bodyWidth=20,proc=PathProcEns,title="TbT Path: "
	PopupMenu TbtPathPop,mode=1,value=TbtPathMenu(pENS=1)
//	SetVariable SetEnsPath,pos={458,130},size={224,15},title="ENS Path:",frame=0,variable=ENS_path,noedit=1
	TitleBox EnsPath,pos={458,130},size={224,15},title="ENS Path:",frame=0
	TitleBox EnsPath2,pos={535,130},size={123,12},frame=0,variable=ENS_path,anchor= LC

	Button BtnDeleteEns,pos={458,168},size={90,20},proc=BtnDeleteEns,title="Delete Setup"
	Button BtnConvEns,pos={602,159},size={80,40},proc=BtnConvEns,title="\f01Converge"
	Button BtnConvStop,pos={602,159},size={80,40},title="\f01Stop",disable=3
	Button BtnConvStop,fColor=(65535,32768,32768),proc=BtnStopEns

	//Param Tabs
	TabControl paramTabs,pos={20,215},size={683,147},proc=ToggleParamsEns
	TabControl paramTabs,tabLabel(0)="Initial Params",tabLabel(1)="Current Params"
	TabControl paramTabs,value= 1
	ToggleParamsEns("",1)


	//log win
	DoWindow/W=ENS_GUI#convLog ENS_GUI
	if(!V_flag)
		Display/N=convLog/W=(18,371,368,595)/HOST=ENS_GUI log_logP_FB
		AppendToGraph/W=ENS_GUI#convLog/R logWave
		ModifyGraph/W=ENS_GUI#convLog log(right)=1,notation(left)=1,rgb(logWave)=(0,0,0),rgb(log_logP_FB)=(1,52428,26586)
		ModifyGraph/W=ENS_GUI#convLog mirror(bottom)=2,gbRGB=(59367,59367,59367),wbRGB=(59367,59367,59367)
		Label right "\Z14Normalized Changes"
		Label bottom "\Z14Iterations"
		Label left "\Z14\K(1,52428,26586)\\f01Log. Likelihood"
		SetActiveSubwindow ##
	endif

	//model cartoon
	DoWindow/W=ENS_GUI#Model ENS_GUI
	if(!V_flag)
		Display/N=Model/W=(375,372,596,596)/HOST=ENS_GUI
		ModifyGraph gbRGB=(59367,59367,59367)
		ENS_drawModel(panel=1)
	endif
	
	if(cmpStr(IgorInfo(2),"Macintosh"))	//different colors on Windows
		ModifyGraph/W=ENS_GUI#convLog gbRGB=(63232,63232,63232),wbRGB=(63232,63232,63232)
		ModifyGraph/W=ENS_GUI#Model gbRGB=(63232,63232,63232),wbRGB=(63232,63232,63232)		
	endif
	
	//further feed back
	SetVariable nTraces,pos={597,384},size={98,19},title="# Traces:",fSize=12
	SetVariable nTraces,frame=0,limits={0,inf,0},value=_NUM:inputCount,noedit=1
	SetVariable vBic,pos={597,404},size={115,19},title="BIC:",fSize=12,frame=0
	SetVariable vBic,limits={0,inf,0},value=vBIC,noedit=1,format="%.5E"
	TitleBox statePop,pos={597,426},size={99,16},title="\\Z12State Population:",frame=0
	Edit/N=pop/W=(597,446,699,587)/HOST=#  countStateOcc
	ModifyTable format(Point)=1,width(Point)=24,width(countStateOcc)=72,showParts=0x48,size=12
	SetActiveSubWindow ENS_GUI


	SetDataFolder HMM_inputPath		
	
End



Function ENS_promptPaths()

	SVAR HMM_inputPath = root:HMM_inputPath
	SVAR TbT_Path = root:TbT_Path

	NewPanel /W=(242,278,558,479)/N=pathPanel
	PopupMenu inPathPop,pos={59,65},size={70,20},bodyWidth=20,proc=PathProcEnsIni,title="Input Path:"
	PopupMenu inPathPop,mode=1,value=InPathMenu()
	TitleBox inPath,pos={135,69},size={91,12},frame=0,variable=HMM_inputPath,anchor= LC
	PopupMenu tbtPathPop,pos={61,100},size={68,20},bodyWidth=20,proc=PathProcEnsIni,title="TbT Path:"
	PopupMenu tbtPathPop,mode=1,value=TbtPathMenu(pENS=1)
	TitleBox tbtPath,pos={135,104},size={108,12},frame=0,variable=TbT_path,anchor= LC
	TitleBox title0,pos={48,30},size={75,16},title="Select consistent paths:",fSize=12,frame=0
	Button btnCncl,pos={48,150},size={80,20},title="Cancel",proc=BtnPathProc
	Button btnCntn,pos={171,150},size={80,20},title="Continue",proc=BtnPathProc

	if(!StringMatch(TbT_path, HMM_inputPath+"TbT_*"))
		Button btnCntn,win=pathPanel,disable=2
	endif

	PauseForUser pathPanel
	NVAR b_Flag
	Return b_Flag
End


Function BtnPathProc(ctrlName) : ButtonControl
	String ctrlName

	KillWindow pathPanel
	strswitch(ctrlName)	
		case "btnCncl":					
			Variable/G b_Flag =1
			break
		case "btnCntn":		
			Variable/G b_Flag =0
			break
	endswitch

End


Function PathProcEnsIni(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr

	if(popNum==1 || StringMatch(popStr, "*<") || StringMatch(popStr, "*_NONE_*"))
		Return 0		//ignore click 
	endif
	
	SVAR HMM_inputPath = root:HMM_inputPath
	SVAR TbT_Path = root:TbT_Path

	strswitch(ctrlName)	
		case "inPathPop":		
			HMM_inputPath = ReplaceString(" ","root:"+popStr+":","")		
			break						
		case "tbtPathPop":		
			TbT_path = ReplaceString(" ",HMM_inputPath + popStr + ":","") 		//remove spaces...
			break
		default:							
			print "PathProcEns: Unknown call."					
	endswitch
	
	if(StringMatch(TbT_path, HMM_inputPath+"TbT_*"))
		Button btnCntn,win=pathPanel,disable=0
	else
		Button btnCntn,win=pathPanel,disable=2
	endif
	
End


Function PathProcEns(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	
	
	if(popNum==1 || StringMatch(popStr, "*<") || StringMatch(popStr, "*_NONE_*"))
		Return 0		//ignore click
	endif

	//String/G root:HMM_outputPath
	SVAR HMM_inputPath = root:HMM_inputPath
	SVAR/Z HMM_outputPath = root:HMM_outputPath
	SVAR/Z ENS_Path = root:ENS_Path
	SVAR/Z TbT_Path = root:TbT_Path

	strswitch(ctrlName)	
		case "InPathPop_":	//ENS Win
			HMM_inputPath = ReplaceString(" ","root:"+popStr+":","")		
			SetDataFolder HMM_inputPath			
			ENS_prepGUI()
			break

		case "TbTPathPop":	//ENS Win
			SVAR myTbT_path = $ENS_path+"myTbT_path"							
			string prevTbT = myTbT_path
			myTbT_path = ReplaceString(" ",HMM_inputPath + popStr + ":","") 	//mod. myTbT in current ENS DF
			TbT_path = myTbT_path

			//adjust # dimensions
			NVAR NumDims = $ENS_path+"NumDims"				
			NVAR TbTNumDims = $myTbT_path+"NumDims"
			NumDims = TbTNumDims
			
			//prepare new B and input refs
			if(ENS_prepBnRefs())	//if no TbT info found: reset path
				TbT_path = prevTbT
				myTbT_path = prevTbT
			endif		
			break

		default:							
			print "PathProc: Unknown call."
	endswitch

End







Function ENS_updateSetups()

	SVAR HMM_inputPath = root:HMM_inputPath
	SVAR ENS_path = root:ENS_path
	SVAR TbT_path = root:TbT_path
	
	variable i=0, j=0
	do
		string currDF = GetIndexedObjName(HMM_inputPath, 4, i)
		i+=1
				
		if(!cmpStr(currDF, ""))
			Break
		elseif(StringMatch(currDF, "ENS_*"))
			TabControl setupTab_,win=ENS_GUI,tabLabel(j)="Setup"+num2str(j)			
			string lastDF = currDF	
			j+=1
		endif
	while(1)
	TabControl setupTab_,pos={7,67},size={707,537},proc=ToggleSetupsEns,value=j-1
	
	//update ENS_path -> last tab
	ENS_path = HMM_inputpath+lastDF+":"	
	SVAR myTbT_path = $ENS_path+"myTbT_path"
	TbT_path = myTbT_path

End


Function ToggleSetupsEns(name,tab) : TabControl
	String name
	Variable tab
	
	DFREF saveDFR = GetDataFolderDFR()
	SVAR HMM_inputPath = root:HMM_inputPath
	SVAR ENS_path = root:ENS_path	
	SVAR TbT_path = root:TbT_path	
	SetDataFolder HMM_inputPath		//just in case...


	//update ENS_path
	string dfList = ListMatch( StringFromList(0, DataFolderDir(1)) , "ENS_*", ",")
	ENS_path = HMM_inputpath+StringFromList(tab, dfList, ",")+":"	

	SVAR myTbT_path = $ENS_path+"myTbT_path"
	TbT_path = myTbT_path

	//update GUI
	ENS_prepGUI(tab=tab)
	
End



Function BtnDeleteEns(ctrlName) : ButtonControl
	String ctrlName
	
	SVAR ENS_path = root:ENS_path
	
	ControlInfo/W=ENS_GUI setupTab_
	variable tab = V_Value
	string tabInfo = S_Recreation
	string msg = "Are you sure you want to delete all information stored in "+S_Value+"?\r"
	msg = msg + "Input data and TbT info are not affected. Proceed?"


	DoAlert/T="Delete Setup" 1, msg	
	if(V_flag!=1)		//no clicked
		Return 0
	endif

	clearGuiEns()		//prepare to kill DF
	DoWindow/W=ENS_GUI#ENS_output ENS_GUI
	if(V_flag)
		KillWindow ENS_GUI#ENS_output
	endif
	
	KillDataFolder/Z ENS_path
	if(V_flag)
		Print "BtnDeleteEns: Could not delete "+ENS_path+" because content is in use, e.g. in graphs."
	endif		
	if(StringMatch(tabInfo, "*tabLabel(1)*"))	//if other setups exist
		ENS_prepGUI()
	else														//this was the only setup
		ENS_init()
	endif
	
End



//create new setup
Function BtnNewSetup(ctrlName) : ButtonControl
	String ctrlName
	
	ENS_init()

End



Function clearGuiEns()

	do		//kill all except setup related controls
		KillControl/W=ENS_GUI $StringFromList(0, ControlNameList("ENS_GUI", ";", "!*_"))
	while(ItemsInList(ControlNameList("ENS_GUI", ";", "!*_")))
	
	do		//kill all subwins
		KillWindow $"ENS_GUI#"+StringFromList(0, ChildWindowList("ENS_GUI"))
	while(ItemsInList(ChildWindowList("ENS_GUI")))
	
End



//handle state configuration changes
Function SetStateConfig(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr	
	String varName


	SVAR ENS_path = root:ENS_path
	SVAR myTbT_path = $ENS_path+"myTbT_path"
	SVAR stateConfig = $ENS_path+"stateConfig"
	NVAR NumStates = $ENS_path+"NumStates"
	NVAR NumStatesOrig = $myTbT_path+"NumStates"

	variable i, currState

	//check if desired states exist
	for(i=0;i<strlen(varStr);i+=1)	
		currState = str2num(varStr[i])
		if(currState>= NumStatesOrig)
			Print "SetStateConfig: Entered state", currState, "is undefined at ", myTbT_path
			SetVariable StateConfig,win=ENS_GUI,value=_STR:stateConfig	//reset display
			Return -1
		endif
	endfor

	//update params
	NumStates = strlen(varStr)
	stateConfig = varStr
	HMM_startParam(ENS_path)				//fetch default start params
	ENS_prepBnRefs()	

	print "SetStateConfig: Modified State Config. not initialized, yet."
	
End




//update all params
Function BtnLoadEns(ctrlName) : ButtonControl
	String ctrlName

	SVAR ENS_path = root:ENS_path
	Make/O/D/N=0 $ENS_path+"logWave", $ENS_path+"log_logP_FB"
	
	ENS_Params(start=1)
	ENS_drawModel(panel=1)
	Print "BtnLoadEns: Initialized Params."

End



Function BtnConvENS(ctrlName) : ButtonControl
	String ctrlName

	SVAR ENS_path = root:ENS_path
	NVAR NumStates = $ENS_path+"NumStates"
	wave/Z HMM_a_ens = $ENS_path+"HMM_a_ens"
	
	//check if consistent params (i.e. if "initialized")
	if(!WaveExists(HMM_a_ens) || dimSize(HMM_a_ens,0)!=NumStates)
		Print "Initialize params!"
		Abort "BtnConvEns: Inconsistent params. Initialize first!"
	endif

	//update controls 	
	string ctrlList = RemoveFromList("BtnConvStop;", ControlNameList("ENS_GUI"))
	ModifyControlList ctrlList disable=2
	Button BtnConvStop,win=ENS_GUI,disable=0
	DoUpdate/W=ENS_GUI	
	killtimer()

	//run
	ENS_converge()

	//update controls
	ModifyControlList/Z ctrlList win=ENS_GUI,disable=0
	Button BtnConvStop,win=ENS_GUI,disable=3

End



//batch converge all setups
Function BtnBatchConv(ctrlName) : ButtonControl
	String ctrlName
	
	variable i=0	
	variable setupCount = ItemsInList( ListMatch(DataFolderDir(1), "ENS_*", ","), ",")

	for(i=0;i<setupCount;i+=1)	
		ToggleSetupsEns("",i)	
		BtnConvEns("batch")		
	endfor

End




Function BtnStopEns(ctrlName) : ButtonControl
	String ctrlName

	NVAR vStop
	vStop=1	
	Print "BtnStopEns: Stops when all threads have finished."

End




Function ToggleParamsEns(name,tab) : TabControl
	String name
	Variable tab
	
	DFREF saveDFR = GetDataFolderDFR()
	SVAR ENS_path = root:ENS_path	
	SetDataFolder ENS_path

	wave HMM_pi_start, HMM_a_start
	wave HMM_pi_ens, HMM_a_ens
	
	DoWindow/W=ENS_GUI#paramTable ENS_GUI
	if(V_flag)	//Kill existing/old table.
		KillWindow ENS_GUI#paramTable
	endif
	
	if(tab==0)
		Edit/N=paramTable/W=(18,234,703,362)/HOST=ENS_GUI HMM_pi_start, HMM_a_start
		ModifyTable/W=ENS_GUI#paramTable format(Point)=1,width(HMM_a_start)=122,showParts=0x4B
	elseif(tab==1)
		Edit/N=paramTable/W=(18,234,703,362)/HOST=ENS_GUI HMM_pi_ens, HMM_a_ens
		ModifyTable/W=ENS_GUI#paramTable format(Point)=1,width(HMM_a_ens)=122,showParts=0x4B
	endif
	
	SetActiveSubwindow ENS_GUI
	SetDataFolder saveDFR
End




//#######################################################
//# MAIN: HMM Functions for ENSemble & MThread 
//#######################################################


//MASTER FUNCTION:
Function ENS_CONVERGE()
	
	SVAR HMM_inputPath = root:HMM_inputPath
	SVAR ENS_path = root:ENS_path		
	SetDataFolder ENS_path	

	Wave/WAVE wInputRef
	if(dimSize(wInputRef,0)==0)
		Print "ENS_converge: No Input found at", ENS_path
		SetDataFolder HMM_inputPath
		Return -1
	endif

	Variable timerRefNum = startMSTimer	
	Variable i, change
							

	//INIT
	NVAR maxIter, vVerbose, convThrshld, vDbal
	Variable/G vStop=0
	ENS_Params()
	print "ENS_CONVERGE: Calculations running."
	DoUpdate/W=ENS_GUI /E=1



	//MAIN LOOP
	i = 0
	do
		//ITERATE (FB & BW)
		ENS_iterate_MThread()
		
		//OPTIMIZE
		change = ENS_opt()

		//REPORT
		ENS_calcBIC()
		ENS_log_update(change)
		ENS_drawModel(panel=1)


		if(vVerbose)
			NVAR logP_FB
			print "   log(ProdProb_FB) = ", logP_FB
		endif

		DoUpdate/W=ENS_GUI
		i+=1
	while(change > convThrshld && i < maxIter && vStop==0)


	ENS_Viterbi_MThread()
	ENS_getStatePop()


	SetDataFolder HMM_inputPath
	Print "ENS_CONVERGE:", i, "iterations completed in", stopMSTimer(timerRefNum) / 6e7, "min."

End





//MThread master function
//handles ForwardBackward & BaumWelch
Function ENS_iterate_MThread([skipBW])
	Variable skipBW				//skip Baum-Welch when != 0
	
	skipBW = (ParamIsDefault(skipBW)) ? 0 : skipBW
	
	NVAR NumStates, NumDims
	NVAR ProdProbFB_MANT, ProdProbFB_EXP
	Wave/WAVE wInputRef
	Wave HMM_pi, HMM_a
	Wave HMM_b_param

	SVAR/Z strExcludeB
	String/G idStr = ""

	Variable i, j, count=0, nExclude=0
	String single_b=""
	Variable nTraces=dimSize(wInputRef,0)
	Variable nthreads = ThreadProcessorCount
	Variable/G threadGroupID = ThreadGroupCreate(nthreads)
	Variable threadIndex

	
	//start threads	
	for(i=0; i<nthreads; i+=1)
		ThreadStart threadGroupID,i,ENS_ForwardBackward_Worker()		//thread is waiting for data...
	endfor
			
	//fill input queue
	for(i=0; i<nTraces; i+=1)
		Wave currSource = wInputRef[i][0]
		Duplicate/O currSource, wObsWaves
		
		ENS_Params()		//set current ensemble params
		
		single_b = ENS_get_singleB(currSource)	//keep track of b_params
		if(!cmpStr(single_b, ""))
			Continue		//single_b excluded -> skip
		endif
		
		if(NumDims>1)
			Redimension/N=(-1, NumDims) wObsWaves
			for (j=1; j<NumDims; j+=1)
				Wave currSource = wInputRef[i][j]
				wObsWaves[][j] = currSource[p]
			endfor
		endif
		
		
		//prepare input queue:
		NewDataFolder inDF
		String/G $":inDF:idStr" = single_b
		Variable/G $":inDF:NumStates"=NumStates, $":inDF:NumDims"=NumDims
		Duplicate HMM_pi $":inDF:HMM_pi_"
		Duplicate HMM_a $":inDF:HMM_a_"
		Duplicate HMM_b_param $":inDF:HMM_b_param_"
		Duplicate wObsWaves $":inDF:wObsWaves_"
		
		ThreadGroupPutDF threadGroupID,inDF										// Send current data folder to input queue. (it no longer belongs to main thread hierarchy)
		count += 1		//track skipped traces in cont. mode
	endfor	


	//prepare collection waves [count] (w/o excluded traces).
	Make/O/D/N=(count) collect_logP_FB = Nan										
	Make/O/D/N=(NumStates, count) collect_pi = Nan							//collect_pi[i][n]
	Make/O/D/N=(NumStates, NumStates, count) collect_a_numer = Nan		//collect_a_numer[i][j][n]
	Make/O/D/N=(NumStates, count) collect_a_denom = Nan						//collect_a_denom[i][n]
	
	
	//wait for output to be ready
	j=0
	do
		DFREF outDFR= ThreadGroupGetDFR(threadGroupID,10)					// Get results in free data folder
		if ( DatafolderRefStatus(outDFR) == 0 )
			Continue
		endif	
		//fetch output
		SVAR idStr_ = outDFR:idStr_
		String strCurr_b = idStr_
		NVAR/SDFR=outDFR ProdProbFB_MANT_, ProdProbFB_EXP_
		ProdProbFB_MANT = ProdProbFB_MANT_
		ProdProbFB_EXP = ProdProbFB_EXP_
		Duplicate/O outDFR:$"HMM_alpha_MANT_" HMM_alpha_MANT
		Duplicate/O outDFR:$"HMM_alpha_EXP_" HMM_alpha_EXP
		Duplicate/O outDFR:$"HMM_beta_MANT_" HMM_beta_MANT
		Duplicate/O outDFR:$"HMM_beta_EXP_" HMM_beta_EXP
		Duplicate/O outDFR:$"wObsWaves_" wObsWaves
		
		//cleanUp output queue (No WAVErefs to be cleared here.)
		KillDataFolder outDFR														// Redundant because dfr refers to a free data folder		
	
					
		if(StringMatch(strCurr_b, "*not" ) )
			print "ENS_iterate_MThread: excluded from BW: "+strCurr_b
			
			DeletePoints j-nExclude, 1, collect_logP_FB
			DeletePoints/M=1 j-nExclude, 1, collect_pi, collect_a_denom
			DeletePoints/M=2 j-nExclude, 1, collect_a_numer
			nExclude +=1
			strCurr_b = ReplaceString("not", strCurr_b, "")
			if(!StringMatch(strExcludeB, "*"+strCurr_b+"*" ))
				strExcludeB = strExcludeB+strCurr_b+";"
			endif
		else
			collect_logP_FB[j-nExclude] = (log(ProdProbFB_MANT) + ProdProbFB_EXP*log(k_renorm))*ln(10) //natural log.
			if (!skipBW)
				ENS_BaumWelch(j-nExclude, strCurr_b)
			endif
		endif

		j += 1
	while(j < count)	
	

	// This terminates the thread by setting an abort flag
	Variable tstatus= ThreadGroupRelease(threadGroupID)
	if( tstatus == -2 )
		Print "Thread would not quit normally, had to force kill it. Restart Igor."
	endif
	
	KillWaves/Z HMM_alpha_MANT, HMM_alpha_EXP, HMM_beta_MANT, HMM_beta_EXP
End




//MThread worker function
ThreadSafe Function ENS_ForwardBackward_Worker()
	
	do	//forever
		//catch input DF from queue
		do
			DFREF inDFR = ThreadGroupGetDFR(0,10)		//Get free data folder from input queue
			if (DataFolderRefStatus(inDFR) != 0)		//if invalid
				break
			endif
		while(1)
	
	
		//retrieve input:
		SVAR idStr = inDFR:idStr
		NVAR NumStates = inDFR:NumStates, NumDims = inDFR:NumDims
		Wave HMM_pi = inDFR:HMM_pi_, HMM_a = inDFR:HMM_a_
		Wave HMM_b_param = inDFR:HMM_b_param_
		Wave wObsWaves = inDFR:wObsWaves_
		
		//local stuff
		Variable Tmax = DimSize(wObsWaves, 0)
		Variable t, t_inv, sj, si, b
		Variable temp_renorm_max = 0
			
			
		
		//create output in outDF:
		NewDataFolder/S outDF
		String/G idStr_ = idStr
		Variable/G ProdProbFB_MANT_ = 0, ProdProbFB_EXP_ = 0  
		Make /D  /N=(Tmax, NumStates) HMM_alpha_MANT_ = 0, HMM_beta_MANT_ = 0				//mantissa[t][i]
		Make /I  /N=(Tmax) HMM_alpha_EXP_ = 0, HMM_beta_EXP_ = 0									//exponent[t] (one exp. for ALL states ->summing...)
		Wave HMM_alpha_MANT = HMM_alpha_MANT_
		Wave HMM_alpha_EXP = HMM_alpha_EXP_
		Wave HMM_beta_MANT = HMM_beta_MANT_
		Wave HMM_beta_EXP = HMM_beta_EXP_
		Duplicate wObsWaves $"wObsWaves_"
		
		
		
		//initialize alpha, beta
		//######################
		HMM_alpha_MANT[0][] = HMM_pi[q] * HMM_b_multithread(q, 0, wObsWaves, HMM_b_param)
		//renormalize:
		MatrixOP /FREE /O temp_alpha = row(HMM_alpha_MANT,0)
		//Wavestats /Q /M=1 temp_alpha
		//HMM_alpha_MANT[0][] = (V_max < 1/k_renorm)? (HMM_alpha_MANT[0][q] * k_renorm) : (HMM_alpha_MANT[0][q])	//catch small value limit
		//HMM_alpha_EXP = (V_max < 1/k_renorm)? -1 : 0
		//HMM_alpha_MANT[0][] = (V_max > k_renorm)? (HMM_alpha_MANT[0][q] / k_renorm) : (HMM_alpha_MANT[0][q])	//catch large value limit (cont. emissions issue)
		//HMM_alpha_EXP = (V_max > k_renorm)? +1 : 0
		Variable aregsum, rn
		aregsum = sum(temp_alpha)
		rn = trunc(log(aregsum)/log(k_renorm))		//==n if max_temp > (k_renorm)^n, ==-n if max_temp < (1/k_renorm)^n
		HMM_alpha_MANT[0][] = HMM_alpha_MANT[0][q] / (k_renorm)^rn
		HMM_alpha_EXP[0] = rn
		
		HMM_beta_MANT[Tmax-1][] = 1
	
		
		//recursion: alpha & beta in parallel
		//##########
		HMM_alpha_loop(HMM_alpha_MANT, HMM_alpha_EXP, HMM_a, HMM_b_param, wObsWaves)
		HMM_beta_loop(HMM_beta_MANT, HMM_beta_EXP, HMM_a, HMM_b_param, wObsWaves)	
		
		
		//termination: production probability	
		//############
		MatrixOP /FREE /O temp_sum = sum( row(HMM_alpha_MANT,Tmax-1) )
		ProdProbFB_MANT_ = temp_sum[0]
		ProdProbFB_EXP_ = HMM_alpha_EXP[Tmax-1]
		
		
		//check for Nans
		if(numtype(ProdProbFB_MANT_))
			idStr_ = idStr+"_not"
		endif
			
			
		
		//handle output, clear WAVErefs
		WAVEClear HMM_alpha_MANT, HMM_beta_MANT, HMM_alpha_EXP, HMM_beta_EXP
		WAVEClear HMM_alpha_MANT_, HMM_beta_MANT_, HMM_alpha_EXP_, HMM_beta_EXP_
		ThreadGroupPutDF 0,:		// Put current data folder in output queue
		
		//cleanUp input queue
		WAVEClear HMM_pi, HMM_a
		WAVEClear HMM_b_param
		WaveClear wObsWaves 
		KillDataFolder inDFR		// We are done with the input data folder
	
	while(1)

End





//collect optimized single-trace params
Function ENS_BaumWelch(j, strCurr_b)
	Variable j		//j^th trace
	String strCurr_b
	
	Wave collect_pi
	Wave collect_a_numer, collect_a_denom
	Wave/Z wCurr_b = $strCurr_B


	if(WaveExists(wCurr_b))
		Duplicate/O wCurr_b HMM_b_param
	else
		Print "No single_b found!\rstrCurr_b = "+strCurr_b
		Return 0
	endif

	HMM_BaumWelch_multidim()
		
	Wave HMM_pi_new
	Wave HMM_a_numer, HMM_a_denom
	Wave/Z HMM_b_param_new
	collect_pi[][j] = HMM_pi_new[p]										//collect_pi[j][n]
	collect_a_numer[][][j] = HMM_a_numer[p][q]						//collect_a_numer[j][j][n]
	collect_a_denom[][j] = HMM_a_denom[p]								//collect_a_denom[j][n]

End




//ENSemble optimize params using collection
Function ENS_opt()

	Wave collect_pi
	Wave collect_a_numer, collect_a_denom
	Wave collect_logP_FB
	Wave HMM_a_ens
	NVAR logP_FB, vDbal
	

	//store old params for comparison
	Duplicate/FREE HMM_a_ens HMM_a_old	
 
	
	MatrixOP /FREE /O aux = sum(collect_logP_FB)		//natural log
	logP_FB = aux[0]
	
	//calc new pi_ens: sum individual pi, normalize by # of traces
	MatrixOP /O HMM_pi_ens = sumRows(collect_pi)/numCols(collect_pi)

	//calc new a_ens from *ensemble sum* of gamma_sumT and gamma_trans_sumT 
	MatrixOP /O /FREE sum_denom = sumRows(collect_a_denom)					//collect_a_denom[i][n]
	MatrixOP /O HMM_a_ens = sumBeams(collect_a_numer) 						//collect_a_numer[i][j][n]
	HMM_a_ens /= sum_denom[p]		


	//enforce detailed balance (optional); average with time reverse.
	if(vDbal)	
		ENS_detBal(HMM_pi_ens, HMM_a_ens)
	endif
	
	
	//determine "change" for convergence criterion
	MatrixOP/O/FREE change = Trace(abs(HMM_a_old - HMM_a_ens)/HMM_a_ens)		//sum of normalized changes of diagonal.
	
	Return change[0]	
	
End

 


Function ENS_Viterbi_MThread()
	
	NVAR NumStates, NumDims
	NVAR ProbVit_MANT, ProbVit_EXP
	Wave/WAVE wInputRef
	Wave HMM_pi, HMM_a
	Wave HMM_b_param
	
	Variable i, j, count=0
	Variable nTraces=dimSize(wInputRef,0)
	Variable nthreads = ThreadProcessorCount
	Variable/G threadGroupID = ThreadGroupCreate(nthreads)
	Variable threadIndex
	Make/O/D/N=(nTraces) collect_logP_Vit = Nan	


	//output win
	DoWindow ENS_Output
	if(V_flag)
		KillWindow ENS_Output
	endif
	Display/K=1/N=ENS_Output/W=(1021,45,1658,832) as "Viterbi > "+GetDataFolder(0)


	//start threads	
	for(i=0; i<nthreads; i+=1)
		ThreadStart threadGroupID,i,ENS_Viterbi_Worker()		//thread is waiting for data...
	endfor


	//prepare input
	for(i=0; i<nTraces; i+=1)
		ENS_Params()									//set current ensemble params
		Wave currSource = wInputRef[i][0]
		Duplicate/O currSource, wObsWaves		//make working copy of observables
		
		String newNotes = note(wObsWaves)		//remove note HMMwaves if existing, add HMMwaves note
		newNotes = RemoveByKey("HMMwaves", newNotes, "=", "\r")
		Note/K wObsWaves, newNotes+"\rHMMwaves="+NameOfWave(currSource)+";"
		
		if(NumDims>1)
			Redimension/N=(-1, NumDims) wObsWaves
			for (j=1; j<NumDims; j+=1)
				Wave currSource2 = wInputRef[i][j]
				wObsWaves[][j] = currSource2[p]
				Note/NOCR wObsWaves, NameOfWave(currSource2)+";"
			endfor
		endif
		
		
		String single_b = ENS_get_singleB(currSource)	//keep track of b_params
		if(!cmpStr(single_b, ""))
			Continue		//single_b excluded -> skip
		endif


		//fill input queue:
		NewDataFolder inDF
		Variable/G $":inDF:NumStates"=NumStates, $":inDF:NumDims"=NumDims
		Duplicate HMM_pi $":inDF:HMM_pi_"
		Duplicate HMM_a $":inDF:HMM_a_"
		Duplicate HMM_b_param $":inDF:HMM_b_param_"
		Duplicate wObsWaves $":inDF:wObsWaves_"
		
		ThreadGroupPutDF threadGroupID,inDF										// Send current data folder to input queue. (it no longer belongs to main thread hierarchy)

		count += 1		//track skipped traces in cont. mode	
	endfor	


	//wait for output to be ready
	j=0
	do
		DFREF outDFR= ThreadGroupGetDFR(threadGroupID,10)					// Get results in free data folder
		if ( DatafolderRefStatus(outDFR) == 0 )
			Continue
		endif		
		//fetch output
		NVAR/SDFR=outDFR ProbVit_MANT_
		NVAR/SDFR=outDFR ProbVit_EXP_
		ProbVit_MANT = ProbVit_MANT_
		ProbVit_EXP = ProbVit_EXP_
		Duplicate/O outDFR:$"wObsWaves_" wObsWaves
		Duplicate/O outDFR:$"HMM_s_" HMM_s

		//cleanUp output queue (No WAVErefs to be cleared here.)
		KillDataFolder outDFR														// Redundant because dfr refers to a free data folder		
	

		ENS_Wins_B(j)	
		DoUpdate/W=ENS_Output
		
		j += 1
	while(j < count)
	print "ENS_Viterbi_MThread: ", count," of ", nTraces, "input traces converged."


	// This terminates the thread by setting an abort flag
	Variable tstatus= ThreadGroupRelease(threadGroupID)
	if( tstatus == -2 )
		Print "Thread would not quit normally, had to force kill it. Restart Igor."
	endif

	
End




ThreadSafe Function ENS_Viterbi_Worker()	
		
	do	//forever
		//catch input DF from queue
		do
			DFREF inDFR = ThreadGroupGetDFR(0,10)	// Get free data folder from input queue
			if (DataFolderRefStatus(inDFR) != 0)			//if invalid
				break
			endif
		while(1)
	
	
		//retrieve input:
		NVAR NumStates = inDFR:NumStates, NumDims = inDFR:NumDims
		Wave HMM_pi = inDFR:HMM_pi_, HMM_a = inDFR:HMM_a_
		Wave HMM_b_param = inDFR:HMM_b_param_
		Wave wObsWaves = inDFR:wObsWaves_

		
		//local stuff
		Variable t, sj, temp_renorm_max
		Variable Tmax = DimSize(wObsWaves, 0)				
			
		
		//create output in outDF:
		NewDataFolder/S outDF
		Variable/G ProbVit_MANT_ = 0, ProbVit_EXP_ = 0  
		Make /D  /N=(Tmax, NumStates) HMM_delta_MANT_ = 0, HMM_psi_ = 0				//mantissa[t][i]
		Make /I  /N=(Tmax) HMM_delta_EXP_ = 0														//exponent[t] (one exp. for ALL states ->summing...)
		Wave HMM_delta_MANT = HMM_delta_MANT_
		Wave HMM_delta_EXP = HMM_delta_EXP_
		Wave HMM_psi = HMM_psi_
		Duplicate wObsWaves $"wObsWaves_"
		Duplicate /O /R=[][0] wObsWaves $"HMM_s_"/WAVE=HMM_s 								//[t]; keep input wave scaling		
		Redimension/I /N=(-1) HMM_s																	//make truly 1D
		


		//initiation
		//##########
		HMM_delta_MANT[0] = HMM_pi[q] * HMM_b_multithread(q, 0, wObsWaves, HMM_b_param)	
		HMM_psi[0] = 0
	
		//renormalize:
		MatrixOP /FREE /O max_temp = maxVal( row(HMM_delta_MANT,0) )
//		HMM_delta_MANT[0][] = (max_temp[0] < 1/k_renorm)? (HMM_delta_MANT[0][q] * k_renorm) : (HMM_delta_MANT[0][q])
//		Multithread HMM_delta_EXP = (max_temp[0] < 1/k_renorm)? -1 : 0
//		HMM_delta_MANT[0][] = (max_temp[0] > k_renorm)? (HMM_delta_MANT[0][q] / k_renorm) : (HMM_delta_MANT[0][q])
//		Multithread HMM_delta_EXP = (max_temp[0] > k_renorm)? +1 : 0
		Variable rn
		rn = trunc(log(max_temp[0])/log(k_renorm))		//==n if max_temp > (k_renorm)^n, ==-n if max_temp < (1/k_renorm)^n
		HMM_delta_MANT[0][] = HMM_delta_MANT[0][q] / (k_renorm)^rn
		HMM_delta_EXP[0] = rn
		
		
		//recursion
		//##########
		for (t=1; t<Tmax; t+=1)																		
			temp_renorm_max = 0
			for (sj=0; sj<NumStates; sj+=1)															
				Make /FREE /D /N=(NumStates) delta_temp = HMM_delta_MANT[t-1][p] * HMM_a[p][sj]		
				WaveStats/Q/M=1 delta_temp
				HMM_delta_MANT[t][sj] = V_max * HMM_b_multithread(sj, t, wObsWaves, HMM_b_param)		//V_max ^= max( delta[t-1]*a ) over all si			
				HMM_psi[t][sj] = V_maxLoc																//V_maxloc ^= state si that maximises( delta[t-1]*a ); ->ARGmax(...)			
				temp_renorm_max = max(temp_renorm_max, HMM_delta_MANT[t][sj])			//renorm if maximum is "already" < k_renorm (min or max is arbitrary here.)
				//MatrixOP /FREE /O temp_max = maxVal( row(HMM_delta_MANT,t) )
			endfor
	
			//renormalize
//			HMM_delta_MANT[t][] = (temp_renorm_max < 1/k_renorm)? (HMM_delta_MANT[t][q] * k_renorm) : (HMM_delta_MANT[t][q])
//			Multithread HMM_delta_EXP[t,*] = (temp_renorm_max < 1/k_renorm)? (HMM_delta_EXP-1) : HMM_delta_EXP
//			HMM_delta_MANT[t][] = (temp_renorm_max > k_renorm)? (HMM_delta_MANT[t][q] / k_renorm) : (HMM_delta_MANT[t][q])
//			Multithread HMM_delta_EXP[t,*] = (temp_renorm_max > k_renorm)? (HMM_delta_EXP+1) : HMM_delta_EXP
			rn = trunc(log(temp_renorm_max)/log(k_renorm))		//==n if max_temp > (k_renorm)^n, ==-n if max_temp < (1/k_renorm)^n
			HMM_delta_MANT[t][] = HMM_delta_MANT[t][q] / (k_renorm)^rn
			HMM_delta_EXP[t] = HMM_delta_EXP[t-1] + rn
		endfor
		
		
		//termination
		//###########
		delta_temp = HMM_delta_MANT[Tmax-1][p]													//delta_temp[i]
		WaveStats /M=1 /Q delta_temp																	//V_max of delta[Tmax-1] ^= P* (maxProdProb)
		HMM_s[Tmax-1] = V_maxRowLoc																	//q_T* ^=V_maxColLoc of delta[Tmax-1]
		ProbVit_MANT_ = V_max															
		ProbVit_EXP_ = HMM_delta_EXP[Tmax-1]
		

		//backtracking																						//only now the maximised state sequence is entirely known.
		//###########
		for (t=Tmax-2; t>=0; t-=1)
			HMM_s[t] = HMM_psi[t+1][HMM_s[t+1]]
		endfor	


		
		//handle output, clear WAVErefs
		WAVEClear HMM_delta_MANT, HMM_delta_EXP, HMM_psi, HMM_s
		WAVEClear HMM_delta_MANT_, HMM_delta_EXP_, HMM_psi_
		ThreadGroupPutDF 0,:		// Put current data folder in output queue
		
		//cleanUp input queue
		WAVEClear HMM_pi, HMM_a
		WAVEClear HMM_b_param
		WaveClear wObsWaves 
		KillDataFolder inDFR		// We are done with the input data folder
	
	while(1)
		
End






//#######################################################
//# Helper Functions
//#######################################################




//check for TbT info & consistent paths.
Function ENS_notReady()

	SVAR HMM_inputPath = root:HMM_inputPath
	SVAR/Z TbT_path = root:TbT_path
	
	//if globals not set
	if(!SVAR_Exists(TbT_path))
		Abort "ENS_notReady: Run TbT workflow first."
	endif


	//search for input
	wave/Z/T wOutputNames = $TbT_path+"wOutputNames"
	if(!StringMatch(TbT_path, HMM_inputPath+"TbT_*:") || !DataFolderExists(TbT_path) || !WaveExists(wOutputNames) || dimSize(wOutputNames,0)==0)
		string DFlist = ListMatch(DataFolderDir(1)[8,strlen(DataFolderDir(1))-3], "TbT_*", ",")

		do		//until proper input found
			TbT_path = HMM_inputPath+StringFromList(0, DFlist, ",")+":"
			wave/Z/T wOutputNames = $TbT_path+"wOutputNames"
			DFlist = RemoveListItem(0, DFlist, ",")
		while(!(WaveExists(wOutputNames) || dimSize(wOutputNames,0)>0) && ItemsInList(DFlist)>0)
	endif
	
	// input found
	if(WaveExists(wOutputNames) && dimSize(wOutputNames,0)>0)
		Return 0
	endif		
	
	// otherwise ask for paths
	if(ENS_promptPaths())	
		Return -1				// user canceled
	endif
	
End



//prepare individual B parameters & wInputRef
Function ENS_prepBnRefs()
	
	SVAR HMM_inputPath = root:HMM_inputPath
	SVAR TbT_path = root:TbT_path
	SVAR ENS_path = root:ENS_path


	SetDataFolder ENS_path
	NVAR NumStates	, NumDims
	SVAR stateConfig		


	//check for individual b_params
	wave/Z collect_b_param = $TbT_path+"collect_b_param"
	if(!WaveExists(collect_b_param) || dimSize(collect_b_param,3)==0)
		SetDataFolder HMM_inputPath
		DoAlert 0, "ENS_prepBnRefs: No individual b_params found at "+TbT_path
		Return 1
	endif 
	wave/T wOutputNames = $TbT_path+"wOutputNames"


	//init input refs (in order of wOutputNames)
	Variable i, j, nTraces
	nTraces = DimSize(wOutputNames, 0)
	SetVariable/Z nTraces,win=ENS_GUI,value=_NUM:nTraces
	Make/WAVE/O/N=(nTraces,NumDims) wInputRef	
	SetDataFolder HMM_inputPath
	for (i=0; i<nTraces; i+=1)
		Wave currW = $TbT_path+RemoveEnding(wOutputNames[i])		//corresponding Vit wave

		String strAssoc = StringByKey("AssociatedWaves", note(currW), "=", "\r")
		if (ItemsInList(strAssoc) < NumDims)
			SetDataFolder HMM_inputPath		
			Abort "ENS_prepBnRefs: Too few AssociatedWaves for"+ num2str(NumDims) +"dimensions."
		endif

		for (j=0; j<NumDims; j+=1)
			string currStr = ListMatch(strAssoc, StringFromList(j, dataID)+"*")
			if(!cmpStr(currStr, ""))
				SetDataFolder HMM_inputPath		
				Abort "ENS_prepBnRefs: dataID ("+dataID+") does not match input names ("+strAssoc+")."
			endif
			wInputRef[i][j] = $RemoveEnding(currStr)
		endfor
	endfor


	//prep b_params
	SetDataFolder ENS_path
	for(i=0; i<nTraces;i+=1)	
		string strObs = NameOfWave(wInputRef[i][0])	
		string strCurr_b = ReplaceString(StringFromList(0, dataID), strObs, "b")		
		
		duplicate/O/R=[*][*][*][i] collect_b_param $strCurr_b/WAVE=new_b
		duplicate/FREE new_b orig_b
		Variable nStatesOrig = dimSize(orig_b,2)
		Redimension/N=(-1, -1, NumStates) new_b
		
		for(j=0; j<NumStates; j+=1)
			variable currState = str2num(stateConfig[j])
			if(currState > nStatesOrig)
				Print ""
			endif
			new_b[][][j] = orig_b[p][q][ currState ]
		endfor						
	endfor

	SetDataFolder HMM_inputPath
	Return 0
	
End



//prepare params
Function ENS_Params([start])
	variable start
	
	SVAR ENS_path = root:ENS_path
	DFREF saveDFR = GetDataFolderDFR()
	SetDataFolder ENS_path
	
	Wave/Z HMM_pi_ens, HMM_a_ens, HMM_b_param_ens
	Wave HMM_pi_start, HMM_a_start, HMM_b_param_start
	
	if(ParamIsDefault(start))
		Duplicate /O HMM_pi_ens, HMM_pi
		Duplicate /O HMM_a_ens, HMM_a
		Duplicate /O HMM_b_param_ens, HMM_b_param
	else
		Duplicate /O HMM_pi_start HMM_pi_ens
		Duplicate /O HMM_a_start HMM_a_ens
		Duplicate /O HMM_b_param_start HMM_b_param_ens			
		String/G strExcludeB = ""		
	endif		
	
	SetDataFolder saveDFR
		
End




//update log waves
Function ENS_log_update(change)
	variable change
		
	NVAR NumDims, NumStates
	NVAR logP_FB, vBIC

	Wave HMM_pi_ens, HMM_a_ens
	Wave log_pi, log_a
	Wave logWave, log_logP_FB, log_BIC

	
	//redimension log waves
	variable nCurr = numpnts(logWave) +1
	Redimension/N=(nCurr) logWave, log_logP_FB, log_BIC
	Redimension/N=(nCurr, NumStates) log_pi
	Redimension/N=(NumStates, NumStates, nCurr) log_a


	//update logs
	nCurr-= 1
	logWave[nCurr] = change
	log_logP_FB[nCurr] = logP_FB
	log_BIC[nCurr] = vBIC
	log_pi[nCurr][] = HMM_pi_ens[q]
	log_a[][][nCurr] = HMM_a_ens[p][q]
		
End
	
 


// single_b follow HMM_x*_y*_M* nomenclature
Function/S ENS_get_singleB(obsCurr)
	Wave obsCurr
	
	SVAR strExcludeB
	Wave HMM_b_param, HMM_b_param_start	
	string strObs = NameOfWave(obsCurr)	
//	string strCurr_b = "b"+strObs[3, strlen(strObs)-1]
	string strCurr_b = ReplaceString(StringFromList(0, dataID), strObs, "b")
	Wave/Z wCurr_b = $strCurr_b		

	if(WaveExists(wCurr_b))
		if(StringMatch(strExcludeB, "*"+strCurr_b+"_*" ))	//if single_b was excluded
			Return ""
		endif	
		Duplicate/O wCurr_b HMM_b_param
	else
		Duplicate/O HMM_b_param_start $strCurr_b
	endif

	Return strCurr_b

End



//complete (Viterbi) win
//in random order due to multi-threading...
Function ENS_Wins_B(i)
	Variable i		// i^th wObsWaves
	
	SVAR HMM_inputPath = root:HMM_inputPath
	NVAR NumStates, NumDims
	SVAR/Z strExcludeB		//excluded singleB's
	wave wObsWaves, HMM_s, HMM_b_param

	Variable j, yOffset = NumStates+2, mulY = 0

	//scaling of continuous output
	Duplicate/FREE/R=[][0][] HMM_b_param tot_mu
	MatrixOP/FREE/O maxObs = maxVal(tot_mu)
	yOffset = (3)*maxObs[0]+2
	mulY = 2* maxObs[0]/(NumStates)


	string inputList = StringByKey("HMMWaves", note(wObsWaves), "=", "\r")
	string strObs = StringFromList(0, inputList)
	Variable posStart = strsearch(strObs, "_x", 0)		//strObs can be "g_g_x123_*" or "FRET_G_b_x123_*", get position of string "_x"
	string strS = "HMM"+strObs[posStart, strlen(strObs)-1]
	
	wave waveObs = $HMM_inputPath+strObs
	Duplicate/O HMM_s $strS/WAVE=waveS
	
	
	String testStr = TraceNameList("ENS_Output", ";", 1)
	if(!StringMatch(testStr, "*"+strObs+"*" ))				//append trace if not on graph, yet

		AppendToGraph/W=ENS_Output waveObs
		ModifyGraph/W=ENS_Output offset($strObs)={0, yOffset*i}, rgb($strObs)=(3,52428,1)
		
		for (j=1; j<NumDims; j+=1)							//is skipped when only 1D
			strObs = StringFromList(j, inputList)
			wave waveObs = $HMM_inputPath+strObs
			AppendToGraph/W=ENS_Output waveObs
			ModifyGraph/W=ENS_Output offset($strObs)={0, yOffset*i}
		endfor
		
		//state wave
		AppendToGraph/W=ENS_Output waveS
		string tList = TraceNameList("ENS_Output", ";", 1 )
		strS = StringFromList(ItemsInList(tList)-1, tList)
		ModifyGraph offset($strS)={0, yOffset*i}, rgb($strS)=(0,0,0), muloffset($strS)={0,mulY}
	endif
		
End



Function ENS_detBal(wPi, wA)
	Wave wPi, wA
	
	MatrixEigenV /L wA		//new stationary pi:
	Wave W_eigenValues, M_L_eigenVectors
	Make /D /O /N=(DimSize(W_eigenValues,0)) W_eigenValues_real = real(W_eigenValues[p])
	W_eigenValues_real = round(1e5*W_eigenValues_real)/1e5		//W_eigenValues is not precise, so eigenvalue is actually close to 1 and not 1
	variable j
	for (j=0; j<DimSize(W_eigenValues,0)+1; j+=1)
		if ( j == DimSize(W_eigenValues,0) )
			Print j, "no eigenvalue == 1 found"
			return -1
		elseif ( W_eigenValues_real[j] == 1 && imag(W_eigenValues[j]) == 0 )
			break
		endif
	endfor	
	wPi = M_L_eigenVectors[p][j]
	MatrixOP/O wPi = wPi / sum(wPi)	

	Duplicate/O wA HMM_a_rev
	HMM_a_rev = wA[q][p] * wPi[q] / wPi[p]
	MatrixOP /FREE /O aux = sumRows(HMM_a_rev)
	HMM_a_rev = HMM_a_rev[p][q] / aux[p]
	wA = (wA + HMM_a_rev)/2

End



//###################
//# AddOns
//###################



Function ENS_calcBIC()
	
	SVAR ENS_path = root:ENS_path
	DFREF saveDFR = GetDataFolderDFR()
	SetDataFolder ENS_path
	
	NVAR NumStates, NumDims
	NVAR logP_FB, vDbal, vBIC
	Wave/WAVE wInputRef
	Wave HMM_pi_start, HMM_a_start	
		
	Variable nLocked=0					//# of locked params
	Variable nBannedPairs=0			//if dbal: # of forbidden transition PAIRS
	Variable nLockedDbal=0
	Variable dof=0							//degrees of freedom
	variable totPnts=0, j=0
	Variable n = NumStates, d = NumDims	
	
	
	//# degrees of freedom:	
	dof = (n-1) + n*(n-1)

	
	//count locked params, i.e. zeros in start params
	Duplicate/FREE HMM_pi_start temp
	temp = (temp==0)? Nan : temp
	WaveStats/Q/M=1 temp
	nLocked += V_numNans
	Duplicate/FREE HMM_a_start temp
	temp = (temp==0)? Nan : temp
	WaveStats/Q/M=1 temp
	nBannedPairs=V_numNans/2			
	dof-= nLocked
	
	
	//if detailed balance
	if(vDbal==1)
		if(mod(nBannedPairs,1)!=0)
			SetDataFolder saveDFR
			Abort "Detailed balance requires forbidden transitions to be SYMMETRIC!"
		endif
		nLockedDbal = (n^2 - 3*n)/2 + 1 - nBannedPairs	 		// after Greenfeld et al. PlosONE (2012)
	endif
	dof-= nLockedDbal


	//# datapnts:
	do
		totPnts += dimSize(wInputRef[j][0], 0)
		j+=1
	while(j<dimSize(wInputRef,0))
	

	vBIC = dof*ln(totPnts) - 2*logP_FB	
		
	SetDataFolder saveDFR

End




Function ENS_drawModel([panel])
	variable panel

	DFREF saveDFR = GetDataFolderDFR()
	SVAR ENS_path = root:ENS_path
	if(DataFolderExists(ENS_path))
		SetDataFolder ENS_path
	else
		print "ENS_drawModel() CurrDF = "+GetDataFolder(1)
	endif

	
	NVAR NumStates
	Wave HMM_a_ens, HMM_pi_ens
	Duplicate/O/FREE HMM_a_ens, a_width, a_arrow, a_dummy
	Duplicate/O/FREE HMM_pi_ens, pi_pop
	Duplicate/O HMM_pi_ens HMM_pi_stat
	ENS_detBal(HMM_pi_stat, a_dummy)	//get stationary pi

	//tune arrow size
	Variable vWidth=10, vArrow=4			//4 is max for arrowfat
	a_width = (p==q) ? 0 : a_width
	WaveStats /Q a_width
	a_width /= V_max
	a_arrow = a_width * vArrow
	a_arrow = (a_arrow<0.1)? 0.1 : a_arrow	
	a_arrow = (a_arrow>4)? 4 : a_arrow
	a_width *= vWidth

	//tune state size
	Variable vFont = 100, minFont = 9, maxFont = 100, relC		//relC for cycle size
	pi_pop = round(HMM_pi_stat*vFont)
	pi_pop = (pi_pop[p] < minFont)? minFont : pi_pop
	pi_pop = (pi_pop[p] > maxFont)? maxFont : pi_pop

	
	Wave u = a_width, v = a_arrow, w = pi_pop
	
	string winStr
	if(ParamIsDefault(panel))
		DoWindow Model
		if(!V_flag)
			Display/K=1/N=Model /W=(1300,555,1650,905)		//keep it quadratic if you want round circles!
		endif
		winStr = "Model"
	else
		winStr = "ENS_GUI#Model"
	endif
	SetDrawLayer/W=$winStr/K UserFront
	SetDrawLayer/W=$winStr  UserFront
	 

	switch(NumStates)	
		case 2:		
			SetDrawEnv/W=$winStr fsize= w[0]
			DrawText/W=$winStr 0.184540767874101,0.508964201877934,"0"
			SetDrawEnv/W=$winStr fsize= w[1]
			DrawText/W=$winStr 0.73931623931624,0.513644366197183,"1"			
			
			//0->1
			SetDrawEnv/W=$winStr linethick=u[0][1],arrow= 1,arrowfat=v[0][1] 
			DrawLine/W=$winStr 0.316849826783924,0.44375,0.650183170051365,0.44375

			//1->0
			SetDrawEnv/W=$winStr linethick=u[1][0],arrow= 1,arrowfat=v[1][0]
			DrawLine/W=$winStr 0.650183170051365,0.509375,0.316849826783924,0.509375
				
			Break

		case 3:
			SetDrawEnv/W=$winStr fsize= w[0]
			DrawText/W=$winStr 0.154320987654321,0.737089201877934,"0"
			SetDrawEnv/W=$winStr fsize= w[1]
			DrawText/W=$winStr 0.777777777777778,0.732394366197183,"1"
			SetDrawEnv/W=$winStr fsize= w[2]
			DrawText/W=$winStr 0.440329218106996,0.2981220657277,"2"			
			 
			//0->1
			SetDrawEnv/W=$winStr linethick=u[0][1],arrow= 1,arrowfat=v[0][1] 
			DrawLine/W=$winStr 0.290123456790123,0.687793427230047,0.646090534979424,0.687793427230047
			 
			//1->0
			SetDrawEnv/W=$winStr linethick=u[1][0],arrow= 2,arrowfat=v[1][0]
			DrawLine/W=$winStr 0.277777777777778,0.737089201877934,0.635802469135803,0.737089201877934
			 
			//0->2
			SetDrawEnv/W=$winStr linethick=u[0][2],arrow= 2,arrowfat=v[0][2]
			DrawLine/W=$winStr 0.360082304526749,0.326291079812207,0.201646090534979,0.556338028169014
			 
			//2->0
			SetDrawEnv/W=$winStr linethick=u[2][0],arrow= 1,arrowfat=v[2][0]
			DrawLine/W=$winStr 0.397119341563786,0.349765258215962,0.238683127572016,0.57981220657277
			 
			//1->2
			SetDrawEnv/W=$winStr linethick=u[1][2],arrow= 2,arrowfat=v[1][2]
			DrawLine/W=$winStr 0.506172839506173,0.363849765258216,0.672839506172839,0.589201877934272
			 
			//2->1
			SetDrawEnv/W=$winStr linethick=u[2][1],arrow= 1,arrowfat=v[2][1]
			DrawLine/W=$winStr 0.545267489711934,0.323943661971831,0.711934156378601,0.549295774647887
			
			Break
			
		case 4:
			//state 0
			relC = 0.5*(0.06 + 0.2*w[0]/100)
			SetDrawEnv/W=$winStr linethick= 2
			DrawOval/W=$winStr 0.187288020621354-relC,0.741011918505569-relC,0.187288020621354+relC,0.741011918505569+relC
			SetDrawEnv/W=$winStr textxjust= 1,textyjust= 1, fsize=15
			DrawText/W=$winStr 0.187288020621354,0.741011918505569,"0"
			//state 1
			relC = 0.5*(0.06 + 0.2*w[1]/100)
			SetDrawEnv/W=$winStr linethick= 2
			DrawOval/W=$winStr 0.799795450826379-relC,0.741011918505569-relC,0.799795450826379+relC,0.741011918505569+relC
			SetDrawEnv/W=$winStr textxjust= 1,textyjust= 1, fsize=15
			DrawText/W=$winStr 0.799795450826379,0.741011918505569,"1"
			//state 2
			relC = 0.5*(0.06 + 0.2*w[2]/100)
			SetDrawEnv/W=$winStr linethick= 2
			DrawOval/W=$winStr 0.799795450826379-relC,0.164493312333014-relC,0.799795450826379+relC,0.164493312333014+relC
			SetDrawEnv/W=$winStr textxjust= 1,textyjust= 1, fsize=15
			DrawText/W=$winStr 0.799795450826379,0.164493312333014,"2"
			//state 3
			relC = 0.5*(0.06 + 0.2*w[3]/100)
			SetDrawEnv/W=$winStr linethick= 2
			DrawOval/W=$winStr 0.187288020621354-relC,0.164493312333014-relC,0.187288020621354+relC,0.164493312333014+relC
			SetDrawEnv/W=$winStr textxjust= 1,textyjust= 1, fsize=15
			DrawText/W=$winStr 0.187288020621354,0.164493312333014,"3"

			//0->1
			SetDrawEnv/W=$winStr linethick=u[0][1],arrow= 1,arrowfat=v[0][1] 
			DrawLine/W=$winStr 0.314102574036672,0.703125,0.647435917304112,0.703125
				
			//1->0
			SetDrawEnv/W=$winStr linethick=u[1][0],arrow= 1,arrowfat=v[1][0]
			DrawLine/W=$winStr 0.647435917304112,0.76875,0.314102574036672,0.76875
			 
			//0->2
			SetDrawEnv/W=$winStr linethick=u[0][2],arrow= 2,arrowfat=v[0][2]
			DrawLine/W=$winStr 0.596153846153846,0.279705796252927,0.318681318681319,0.598455796252927
			
			//2->0
			SetDrawEnv/W=$winStr linethick=u[2][0],arrow= 1,arrowfat=v[2][0]
			DrawLine/W=$winStr 0.634615384615385,0.326580796252927,0.357142857142857,0.645330796252927
			 
			//0->3
			SetDrawEnv/W=$winStr linethick=u[0][3],arrow= 2,arrowfat=v[0][3]
			DrawLine/W=$winStr 0.157359238699446,0.282830796252927,0.157359238699446,0.616164129582927
			
			//3->0
			SetDrawEnv/W=$winStr linethick=u[3][0],arrow= 1,arrowfat=v[3][0]
			DrawLine/W=$winStr 0.215820777160984,0.282830796252927,0.215820777160984,0.616164129582927
			 
			//1->2
			SetDrawEnv/W=$winStr linethick=u[1][2],arrow= 2,arrowfat=v[1][2]
			DrawLine/W=$winStr 0.770659340659341,0.282830796252927,0.770659340659341,0.616164129582927
			
			//2->1
			SetDrawEnv/W=$winStr linethick=u[2][1],arrow= 1,arrowfat=v[2][1]
			DrawLine/W=$winStr 0.829120879120879,0.282830796252927,0.829120879120879,0.616164129582927
		
			//1->3
			SetDrawEnv/W=$winStr linethick=u[1][3],arrow= 2,arrowfat=v[1][3]
			DrawLine/W=$winStr 0.351648351648352,0.267205796252927,0.642857142857143,0.595330796252927
			
			//3->1
			SetDrawEnv/W=$winStr linethick=u[3][1],arrow= 1,arrowfat=v[3][1]
			DrawLine/W=$winStr 0.310439560439561,0.310955796252927,0.601648351648352,0.639080796252927
		
			//2->3
			SetDrawEnv/W=$winStr linethick=u[2][3],arrow= 1,arrowfat=v[2][3]
			DrawLine/W=$winStr 0.647435917304112,0.2,0.314102574036672,0.2

			//3->2
			SetDrawEnv/W=$winStr linethick=u[3][2],arrow= 1,arrowfat=v[3][2]
			DrawLine/W=$winStr 0.314102574036672,0.134375,0.647435917304112,0.134375
			
			Break
			
		default:
			DrawText/W=$winStr 0.187288020621354,0.164493312333014,"No cartoon available."
	endswitch

	if(ParamIsDefault(panel))
		DoUpdate/W=Model
	else
		SetActiveSubwindow ENS_GUI 
	endif	
		
	SetDataFolder saveDFR
End


Function ENS_getStatePop()
	DFREF saveDFR = GetDataFolderDFR()
	SVAR ENS_path = root:ENS_path
	if(DataFolderExists(ENS_path))
		SetDataFolder ENS_path
	else
		print "getStateOccupation_OUT: proceeds in currDF."
	endif
	
	NVAR NumStates	
	Variable i, j, sumP
	
	Make /O /N=(NumStates) countStateOcc = 0
	String wList = WaveList("HMM_x*_y*", ";", "")
	
	for (i=0; i<ItemsInList(wList); i+=1)
		Wave currW = $StringFromList(i, wList)
		
		for (j=0; j<DimSize(currW, 0); j+=1)
			countStateOcc[currW[j]] += 1
		endfor
	endfor
	sumP = sum(countStateOcc)
	countStateOcc/=sumP
	
	SetDataFolder saveDFR
	
End

