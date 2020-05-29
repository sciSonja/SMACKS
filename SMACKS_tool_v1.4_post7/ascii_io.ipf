#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#pragma version = 20160525


//required data format: 
// - ascii files *.dat or *.txt
// - white space between columns
// - 1 to 3 colums (e.g. <donor after donor ex> <acceptor after donor ex> <acc after acc ex>)
// - constant time intervals
Function Importer_ascii()

	DoWindow/K TbT_GUI			//kill TbT win
	DoWindow/K ENS_GUI			//kill ENS win
	DoWindow/K HMM_Output		//kill Viterbi Browser

	//check if dataID is terminated by a ";"
	String endDataID = dataID[strlen(dataID)-1]
	if (cmpStr(endDataID, ";"))
		Print "Importer_ascii: dataID is not terminated by a \";\". Aborting."
		return -1
	endif
	
	
	//get names for waves to load
	String strChanList = ReplaceString(";",dataID,"_x_y_M;")
	
	
	//get data folders right
	string saveDF = GetDataFolder(1)
	SetDataFolder root:
	String/G HMM_inputPath
	NewDataFolder/S $UniqueName("input_traces_", 11, 0)
	HMM_inputPath = GetDataFolder(1)
	
	
	//get paths of files to load
	String LoadPath = Importer_ALEX_OpenFileDialog()		//full path to files in list separated by /r
	
 	
	Variable i, countImport=0
	
	for (i=0; i<ItemsInList(LoadPath, "\r"); i+=1)
		String currFile = StringFromList(i, LoadPath, "\r")
		LoadWave /N /D /G /K=1 /Q currFile
			//N auto load and name, overwrite waves
			//D double precission
			//G general text
			//K=1 numeric data
			//Q quiet
			//S_waveNames -> should be wave0, wave1, ...
			//S_path, S_fileName
		
		
		Variable ExpectedNumCols = ItemsInList(strChanList)
		if (ItemsInList(S_waveNames) != ExpectedNumCols)		//did not find expected number of columns
			Print "Importer_ascii: File", currFile, "seems not to match format of \"dataID\". Skipping this file."
			KillWavesFromList(S_waveNames)
			continue
		endif
		
		
		Variable j, DimCheck = 1
		if (ItemsInList(S_waveNames)>1)
			for (j=1; j<ItemsInList(S_waveNames); j+=1)
				DimCheck *= DimSize($StringFromList(j, S_waveNames), 0) / DimSize($StringFromList(0, S_waveNames), 0)
			endfor
		endif
		
		if (!DimCheck)
			Print "Importer_ascii: File", currFile, "seems to miss some data points. Skipping this file."
			KillWavesFromList(S_waveNames)
			continue
		endif
		
		
		//prepare strings for wave note
		String strPathToFile = "PathToFile=" + currFile
		String strAssocW = "AssociatedWaves=" + ReplaceString(";", strChanList, num2str(i)+";")
		
		
		for (j=0; j<ExpectedNumCols; j+=1)
			Wave currW = $StringFromList(j, S_waveNames)
			
			Note currW, strAssocW
			Note currW, strPathToFile
			
			Duplicate /O currW, $HMM_inputPath+StringFromList(j, strChanList)+num2str(i)
			KillWaves /Z currW
		endfor
		
		countImport += 1	
	endfor
		
	if(countImport==0)
		Print "Import failed."
		KillDataFolder $HMM_inputPath
	else
		Print "Imported", countImport, "of", ItemsInList(LoadPath, "\r"), "files to", HMM_inputPath
	endif
	
End



Function /S Importer_ALEX_OpenFileDialog()
	Variable refNum
	String message = "Select one or multiple ascii files containing ALEX data."
	String outputPath
	String fileFilters = ""
	fileFilters += "Data Files (*.txt,*.dat):.txt,.dat;"
	fileFilters += "All Files:.*;"
	
	Open /D /R /MULT=1 /F=fileFilters /M=message refNum
	outputPath = S_fileName		//full path to file
	
	return outputPath				//will be empty if user canceled
End



//deletes all waves in the ListOfWaves
static Function KillWavesFromList(ListOfWaves)
	String ListOfWaves
	Variable i
	String current

	 for (i=0; i<ItemsInList(ListOfWaves); i+=1)
	 	current = StringFromList(i, ListOfWaves)
	 	KillWaves /Z $current
	endfor
End



//expects to be in ENS folder from HMM_ENS_GUI_Workflow Sonja
Function Export_Results()

	DoWindow/K TbT_GUI			//kill TbT win
	DoWindow/K ENS_GUI			//kill ENS win
	DoWindow/K HMM_Output		//kill Viterbi Browser

	String/G root:HMM_inputPath
	SVAR HMM_inputPath = root:HMM_inputPath
	String/G root:HMM_outputPath
	SVAR HMM_outputPath = root:HMM_outputPath

	if(export_promptPaths())	//user supplied ENS_path
		Return -1					//user canceled or out paths strings do not exist
	endif
	string saveDF = GetDataFolder(1)	
	SetDataFolder HMM_outputPath
	
	String listHMM = WaveList("HMM_x_y_M*", ";", "")	
	Variable i, V_path = 0
	Variable refNum
	String strCurrW, strCurrWaveHMM
	String strTmp
	

	PathInfo pathSave	
	if (V_flag == 0)		//pathSave does not exist
		//get path to folder from which data was loaded
		strCurrW = StringFromList(0, listHMM)
		Wave currW = $strCurrW
		String strFilePath = StringByKey("PathToFile", note(currW), "=", "\r")
		strFilePath = ParseFilePath(1, strFilePath, ":", 1, 0)		//file path only
		NewPath /O /Q /Z pathSaveTry, strFilePath
	
		if (V_flag != 0)
			Print "Export_Results: Could not find folder of original data."
			NewPath /O /Q /Z pathSaveTry, ""
		endif
	else
		NewPath /O /Q /Z pathSaveTry, S_path
	endif
	
	
	//display dialog to accept or change path to save files
	String strPathSave = DoSaveFileDialog("pathSaveTry", "Viterbi, b_param, ENS_summary")		//returns full path
	strPathSave = ParseFilePath(1, strPathSave, ":", 1, 0)		//file path only
	if (strlen(strPathSave)==0)
		Print "Export_Results: User canceld save dialog. No export."
		SetDataFolder saveDF
		return -1
	endif
	
	NewPath /O /Q /Z pathSave, strPathSave
	if (V_flag != 0)
		Print "Export_Results: Something went wrong when trying to get the data folder for export."
		KillPath /Z pathSave
		SetDataFolder saveDF
		return -1
	endif
	
	Print "Exporting from",HMM_outputPath,"to", strPathSave


	if(StringMatch(HMM_outputPath,"*:ENS_*"))	
	
		//export summary of ensHMM
		String strSummary = ""
							
		strSummary += "# Traces: "
		sprintf strTmp, "%d", ItemsInList(listHMM)
		strSummary += strTmp + "\r\r"

		strSummary += "# Dimensions: "
		NVAR NumDims
		sprintf strTmp, "%d", NumDims
		strSummary += strTmp + "\r\r"
	
		strSummary += "State Config.: "
		SVAR stateConfig
		strSummary += stateConfig + "\r\r"
		
		strSummary += "ln(likelihood): "
		NVAR logP_FB
		sprintf strTmp, "%f", logP_FB
		strSummary += strTmp + "\r\r"
		
		strSummary += "BIC: "
		NVAR vBIC
		sprintf strTmp, "%f", vBIC
		strSummary += strTmp + "\r\r"
		
		strSummary += "State Population:\r"
		Wave countStateOcc
		strSummary += w2str(countStateOcc) + "\r"
	
		strSummary += "HMM_pi_ens:\r"
		Wave HMM_pi_ens
		strSummary += w2str(HMM_pi_ens) + "\r"
		
		strSummary += "HMM_a_ens:\r"
		Wave HMM_a_ens
		strSummary += w2str(HMM_a_ens) + "\r"
	
	
		Open /P=pathSave refNum as  "SMACKS_summary.dat"			// open file for write
		fprintf refNum, "%s", strSummary
		Close refNum
	endif
	
	
 	for (i=0; i<ItemsInList(listHMM); i+=1)
		strCurrWaveHMM = StringFromList(i, listHMM)
		Wave currWaveHMM = $strCurrWaveHMM
		Wave/Z currWaveBparam = $ReplaceString("HMM_", strCurrWaveHMM, "b_")
		String strFileName = StringByKey("PathToFile", note(currWaveHMM), "=", "\r")
		strFileName = ParseFilePath(3, strFileName, ":", 0, 0)		//file name w/o extentions
		
		
		//export Viterbi path
		Save /O /J /P=pathSave currWaveHMM as strFileName + "_viterbi.dat"
		// /P=path
		// /G general text
		//	/J tab delimited
		
		if(!WaveExists(currWaveBparam))	// TbT export
			Continue
		endif
		
		//export b_params
		Variable pp, qq, rr
		Variable maxpp = DimSize(currWaveBparam, 0)
		Variable maxqq = DimSize(currWaveBparam, 1)
		Variable maxrr = DimSize(currWaveBparam, 2)
		String strBparam = ""
		for(rr=0; rr<maxrr; rr+=1)
			strBparam += "state" + num2str(rr) + "\r"
			for(pp=0; pp<maxpp; pp+=1)
				for(qq=0; qq<maxqq; qq+=1)
					sprintf strTmp, "%f", currWaveBparam[pp][qq][rr]
					strBparam += strTmp
					if (qq==maxqq-1)
						strBparam += "\r"
					else
						strBparam += "\t"
					endif
				endfor
			endfor
		endfor
		
		Open /P=pathSave refNum as strFileName + "_b_param.dat"			// open file for write
		fprintf refNum, "%s", strBparam
		Close refNum
	endfor
		

	SetDataFolder saveDF

End



Static Function/S DoSaveFileDialog(strPath, strFileName)
	String strPath			//string of IgorPath to use, gives legal IgorPath with $strPath
	String strFileName	//used in dialog
	
	Variable refNum
	String message = "Choose a folder for export. Existing result files will be overwritten."
	String outputPath
	String fileFilters = ""
	fileFilters += "Data Files (*.dat):.dat;"
	fileFilters += "All Files:.*;"

	Open /D /F=fileFilters /M=message /P=$strPath refNum as strFileName
	outputPath = S_fileName
	
	return outputPath		// Will be empty if user canceled
End



Static Function/S w2str(w)
	Wave w
	
	Variable pp, qq, rr
	Variable maxpp = DimSize(w, 0)
	Variable maxqq = DimSize(w, 1)
	Variable maxrr = DimSize(w, 2)
	Variable test
	
	String strTmp, strW = ""
	
	if (maxrr != 0 && maxqq != 0)			//real 3D (rows, cols & layers)
		for(rr=0; rr<maxrr; rr+=1)
			for(pp=0; pp<maxpp; pp+=1)
				for(qq=0; qq<maxqq; qq+=1)
					sprintf strTmp, "%f", w[pp][qq][rr]
					strW += strTmp
					if (qq==maxqq-1)
						strW += "\r"
					else
						strW += "\t"
					endif
				endfor
			endfor
		endfor
	elseif (maxrr == 0 && maxqq != 0)	//real 2D (rows & cols)
		for(pp=0; pp<maxpp; pp+=1)
			for(qq=0; qq<maxqq; qq+=1)
				sprintf strTmp, "%f", w[pp][qq]
				strW += strTmp
				if (qq==maxqq-1)
					strW += "\r"
				else
					strW += "\t"
				endif
			endfor
		endfor
	elseif (maxrr == 0 && maxqq == 0 && maxpp != 0)	//real 1D (rows)
		for(pp=0; pp<maxpp; pp+=1)
			sprintf strTmp, "%f", w[pp]
			strW += strTmp + "\r"
		endfor
	else
		Print "w2str(). Unexpected combination of rows, cols & layers."
		wfprintf strW, "", w
	endif
	
	return strW
End




Function export_promptPaths()

	SVAR HMM_inputPath = root:HMM_inputPath
	SVAR HMM_outputPath = root:HMM_outputPath

	SVAR/Z TbT_Path = root:TbT_Path
	SVAR/Z ENS_Path = root:ENS_Path	
	if(!SVAR_Exists(TbT_path) && !SVAR_Exists(ENS_path))
		Print "Nothing to export, yet."
		Return 1
	endif
	
	NewPanel /W=(242,278,558,479)/N=pathPanel
	PopupMenu InPathPop,pos={59,65},size={70,20},bodyWidth=20,proc=PathProcExport,title="Input Path:"
	PopupMenu InPathPop,mode=1,value=InPathMenu()
	TitleBox InPath,pos={135,69},size={91,12},frame=0,variable=HMM_inputPath,anchor=LC
	PopupMenu OutPathPop,pos={61,100},size={68,20},bodyWidth=20,proc=PathProcExport,title="Output Path:"
	PopupMenu OutPathPop,mode=1,value=OutPathMenu()
	TitleBox OutPath,pos={135,104},size={108,12},frame=0,variable=HMM_outputPath,anchor=LC
	TitleBox title0,pos={48,30},size={75,16},title="Select consistent paths:",fSize=12,frame=0
	Button btnCncl,pos={48,150},size={80,20},title="Cancel",proc=BtnPathProc
	Button btnCntn,pos={171,150},size={80,20},title="Continue",proc=BtnPathProc

	if(!DataFolderExists(HMM_outputPath) || !StringMatch(HMM_outputPath, HMM_inputPath+"ENS_*"))
		Button btnCntn,win=pathPanel,disable=2
	endif

	PauseForUser pathPanel
	NVAR b_Flag
	Return b_Flag
	
End




Function PathProcExport(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr

	if(popNum==1 || StringMatch(popStr, "*_NONE_*"))
		Return 0		//ignore click 
	endif
	
	SVAR HMM_inputPath = root:HMM_inputPath
	SVAR HMM_outputPath = root:HMM_outputPath
	SVAR TbT_Path = root:TbT_Path
	SVAR/Z ENS_Path = root:ENS_Path

	strswitch(ctrlName)	
		case "InPathPop":		
			HMM_inputPath = ReplaceString(" ","root:"+popStr+":","")			//remove spaces...
			HMM_outputPath = "_NONE_"
			break						
		case "OutPathPop":		
			HMM_outputPath = ReplaceString(" ",HMM_inputPath + popStr + ":","") 		
			break
		default:							
			print "PathProcExport: Unknown call."					
	endswitch
	
	if((SVAR_Exists(ENS_Path) && StringMatch(ENS_path, HMM_inputPath+"ENS_*")) || StringMatch(TbT_path, HMM_inputPath+"TbT_*"))
		Button btnCntn,win=pathPanel,disable=0
	else
		Button btnCntn,win=pathPanel,disable=2
	endif
	
End


