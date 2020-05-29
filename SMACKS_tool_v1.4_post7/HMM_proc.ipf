#pragma rtGlobals=2		// Use modern global access method and strict wave access.

#pragma version = 20181111




//#######################################################
//#                                                     #
//#                    General HMM:                     #
//#                                                     #
//#######################################################


Function AfterFileOpenHook(refNum, fileNameStr, pathNameStr, fileTypeStr, fileCreatorStr, fileKind )
	variable refNum, fileKind
	string fileNameStr, pathNameStr, fileTypeStr, fileCreatorStr

	DoWindow /H/HIDE=0		//show history/cmd line after start-up.

End


//################################
//# Menu
//################################

Menu "SMACKS", dynamic

	"Import ascii", /Q, Importer_ascii()
	"Export Results", /Q, Export_Results()		
	Submenu "Set Input Path"
		 FolderMenu(), /Q, HandleFolderMenu()		 
	End
	"-------------"
	"Init TbT", /Q, TbT_Init()
	"Recreate TbT Win", /Q, TbT_prepGUI()
	"TbT Batch Converge", /Q, TbT_converge(100, convOnly=1)
	"TbT Apply Means", /Q, TbT_apply_means()
	"-------------"
	"Init ENS", /Q, ENS_init()
	"Recreate ENS Win", /Q, ENS_prepGUI()
	"Viterbi Browser", /Q, HMM_prepOutput()
	End
	
End





//################################
//# GUI
//################################


//browse through output
Function HMM_prepOutput()

	SVAR HMM_inputPath = root:HMM_inputPath
	String/G root:HMM_outputPath
	SVAR HMM_outputPath = root:HMM_outputPath
	if(!StringMatch(HMM_outputPath,HMM_inputPath+"*"))
		HMM_outputPath = HMM_inputPath+"TbT_0:"	//default
	endif


	DoWindow/K TbT_GUI		//kill TbT win
	DoWindow/K ENS_GUI		//kill ENS win

	
	DoWindow HMM_Output
	if(V_flag)
		KillWindow HMM_Output
	endif		
	Display/K=1/W=(44,45,1076,354)/N=HMM_Output as "Viterbi Browser"

	//add controls
	NewPanel/K=2/HOST=#/EXT=0/W=(5,0,303,309)/N=ouputPanel as ""
	ModifyPanel cbRGB=(57346,65535,49151)
	TitleBox currData,pos={47,43},size={78,16},title="Current Data:",fSize=12,frame=0
	TitleBox currData2,pos={131,43},size={77,16},fSize=12,frame=0

	PopupMenu inPathPopVit,pos={54,75},size={74,20},bodyWidth=20,proc=PathProcVit,title="Input Path: "
	PopupMenu inPathPopVit,mode=2,value=InPathMenu()
	TitleBox inPath,pos={135,79},size={79,12},frame=0,variable=HMM_inputPath,anchor=LC
	PopupMenu outPathPopVit,pos={45,110},size={83,20},bodyWidth=20,proc=PathProcVit,title="Output Path: "
	PopupMenu outPathPopVit,mode=3,value=OutPathMenu(pVit=1)
	TitleBox outPath,pos={135,114},size={79,12},frame=0,variable=HMM_outputPath,anchor=LC

	Button BtnFirstHmm,pos={133,164},size={35,35},proc=currDispHmm,title="First"
	Button BtnPrevHmm,pos={99,197},size={35,35},proc=currDispHmm,title="<<"
	Button BtnLastHmm,pos={133,230},size={35,35},proc=currDispHmm,title="Last"
	Button BtnNextHmm,pos={167,197},size={35,35},proc=currDispHmm,title=">>"


	//prepare data
	if(!DataFolderExists(HMM_outputPath))
		print "ENS_prepOutput: Inexistent Output Path:", HMM_outputPath
		Return 1
	endif
	SetDataFolder HMM_outputPath		
	String/G HMM_currName = ""
	TitleBox currData2,variable=HMM_currName

	Make/O/N=0 wDispWaves, HMM_s
	currDispHmm("")		//build traces for display
	variable i, dim
	wave wDispWaves, HMM_s
	dim = DimSize(wDispWaves, 1)
	dim = (dim==0)? 1 : dim


	//plot traces
	for(i=0; i<dim; i+=1)							
		AppendToGraph/W=HMM_Output wDispWaves[][i]
	endfor
	AppendtoGraph/R HMM_s
	ModifyGraph/Z rgb($"#0")=(0,52428,0),rgb($"#1")=(65535,0,0),rgb($"#2")=(32768,0,0)
	ModifyGraph wbRGB=(59367,59367,59367)
	ModifyGraph rgb(HMM_s)=(0,0,0),lSize(HMM_s)=2

	ModifyGraph mirror(bottom)=2,highTrip(left)=1000,notation(left)=1
	Label left "\\Z14Signal"
	Label bottom "\\Z14Time"
	Label right "\\Z14States"
	SetAxis right 0,*

	
	SetDataFolder HMM_inputPath
	
End



Function currDispHmm(ctrlName) : ButtonControl
	String ctrlName

	SVAR HMM_inputPath = root:HMM_inputPath
	SVAR HMM_outputPath = root:HMM_outputPath
	string saveDF = GetDataFolder(1)
	SetDataFolder HMM_outputPath
	
	SVAR HMM_currName
	string wList, currS
	variable i, item, tot
	
	
	wList = WaveList("HMM_x*_y*_M*", ";", "" )
	tot = ItemsInList(wList)		
	if(tot==0)
		Print "currDispEns: No Viterbi paths found at "+HMM_outputPath	
		Return 0
	endif
	currS = ReplaceString(StringFromList(0,dataID), HMM_currName, "HMM")
	item = WhichListItem(currS, wList)		//-1 if not found
	item = (item<0)? 0 : item					
	

	if(!cmpStr(ctrlName,"BtnPrevHmm"))				
			item -= 1
	elseif(!cmpStr(ctrlName,"BtnNextHmm"))	
			item += 1
	elseif(!cmpStr(ctrlName,"BtnFirstHmm"))	
			item = 0
	elseif(!cmpStr(ctrlName,"BtnLastHmm"))	
			item = ItemsInList(wList)-1
	endif

	if(item<0)
		print "currDispHmm: First wave reached!"
		Return 0
	elseif(item>=tot)
		print "currDispHmm: Last wave reached!"
		Return 0
	endif


	//get HMM_s
	currS = StringFromList(item, wList)
	Duplicate/O $currS HMM_s, wDispWaves

	//get assoc data
	string assocList = StringByKey("HMMWaves", note(HMM_s), "=", "\r")	//load input wave(s)
	variable dims = ItemsInList(assocList)
	Redimension/D/N=(-1,dims) wDispWaves
	for(i=0; i<dims; i+=1)
		string strObs = StringFromList(i,assocList)
		wave wObs = $HMM_inputPath+strObs
		wDispWaves[][i] = wObs[p]
	endfor
	HMM_currName = StringFromList(0,assocList)
	
	SetDataFolder saveDF

End



Function/S InPathMenu()
	 
	SVAR HMM_inputPath = root:HMM_inputPath

	string DFname, itemList, currDF
 	Variable i, nDF= CountObjects("root:", 4)

	itemList = "root:;" 
 	for(i=0; i<nDF; i+=1 )
		currDF = GetIndexedObjName("root:", 4, i)
		if(!cmpStr(currDF,""))
			Break
		elseif(!StringMatch(currDF,"input_traces*"))			//not an input folder
			Continue
		elseif(!cmpStr("root:"+currDF+":",HMM_inputPath))	//label current input folder
			currDF += " <"
		endif
 		itemList += "  "+currDF+";"
 	endfor
 	if(ItemsInList(itemList)==1)
 		itemList += "  _NONE_;"
 	endif

	return itemList
End



Function/S TbTPathMenu([pENS])
	Variable pENS

	SVAR HMM_inputPath = root:HMM_inputPath
	SVAR TbT_Path = root:TbT_Path	
	
	string itemList, currDF 
 	Variable i, nDF= CountObjects(HMM_inputPath, 4)

	itemList = HMM_inputPath+";"
 	for(i=0; i<nDF; i+=1 )
		currDF = GetIndexedObjName(HMM_inputPath, 4, i)
		SVAR/Z HMM_inputList = $HMM_inputPath+currDF+":HMM_inputList"
		Wave/Z wOutputNames = $HMM_inputPath+currDF+":wOutputNames"

		//no TbT folder
		if(!StringMatch(currDF,"TbT_*"))	
			Continue
		endif
		
		// no input at TbT folder
		if(!SVAR_Exists(HMM_inputList) || ItemsInList(HMM_inputList)==0)
			Continue
		endif
		
		// when called by ENS: no TbT Output found
		if(pENS && (!WaveExists(wOutputNames) || DimSize(wOutputNames,0)==0 ))
			Continue
		endif

		//label current TbT Path
		if(!cmpStr(HMM_inputPath+currDF+":",TbT_path))	
			currDF += " <"
		endif
		
 		itemList += "  "+currDF+";"
 	endfor

 	if(ItemsInList(itemList)==1)
 		itemList += "  _NONE_;"
 		TbT_path = "_NONE_"
 	endif

	return itemList

End


Function/S OutPathMenu([pVit])
	Variable pVit
	 
	SVAR HMM_outputPath = root:HMM_outputPath
	SVAR HMM_inputPath = root:HMM_inputPath
	
	String saveDF = GetDataFolder(1)
	string itemList, currDF
 	Variable i, nDF= CountObjects(HMM_inputPath, 4)

	itemList = HMM_inputPath+";" 
 	for(i=0; i<nDF; i+=1 )
		currDF = GetIndexedObjName(HMM_inputPath, 4, i)

		//only TbT or ENS folders
		if(!StringMatch(currDF,"TbT_*") && !StringMatch(currDF,"ENS_*"))	
			Continue
		endif

		//check for Viterbi Paths
		SetDataFolder $HMM_inputPath+currDF
		string wList = WaveList("HMM_x*_y*_M*",";","")
		SetDataFolder saveDF
		if(ItemsInList(wList)==0)
			Continue
		endif

		//label current TbT Path if called by HMM_output
		if(pVit && !cmpStr(HMM_inputPath+currDF+":",HMM_outputPath))
			currDF += " <"
		endif
 	
 		itemList += "  "+currDF+";"
 	endfor
 	if(ItemsInList(itemList)==1)
 		HMM_outputPath = "_NONE_"
 		itemList += "  _NONE_;"
 	endif

	return itemList
End




Function PathProcVit(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	
	
	if(popNum==1 || StringMatch(popStr, "*<") || StringMatch(popStr, "*_NONE_*"))
		Return 0		//ignore click
	endif

	SVAR HMM_inputPath = root:HMM_inputPath
	SVAR/Z HMM_outputPath = root:HMM_outputPath
	SVAR/Z ENS_Path = root:ENS_Path
	SVAR/Z TbT_Path = root:TbT_Path


	strswitch(ctrlName)	
		case "InPathPopVit":		//Viterbi Browser
			HMM_inputPath = ReplaceString(" ","root:"+popStr+":","")		
		
			SetDataFolder HMM_inputPath
			HMM_prepOutput()		
			break		
							
		case "OutPathPopVit":		//Viterbi Browser
			HMM_outputPath = ReplaceString(" ",HMM_inputPath+popStr+":","")
			HMM_prepOutput()		
			break
			
		default:							
			print "PathProc: Unknown call."
	endswitch


End



Function/S FolderMenu()
 
	String/G root:HMM_inputPath
	SVAR HMM_inputPath = root:HMM_inputPath
	String itemList = ""
 	Variable i,nDF= CountObjects("root:", 4)

 	for(i=0; i<nDF; i+=1)
		String fName = GetIndexedObjName("root:", 4, i)
		if(!StringMatch(fName,"input_traces_*"))
			Continue
		elseif(!cmpStr("root:"+fName+":", HMM_inputPath))
			itemList += "\\M0root:"+fName+": <;"
		else
 			itemList += "root:"+fName+":;"
 		endif
 	endfor
 	if(!cmpStr(itemList,""))
 		itemList = "_NONE_"
 	endif
 	
	return itemList
End
 
Function HandleFolderMenu()

	SVAR HMM_inputPath = root:HMM_inputPath	
	GetLastUserMenuInfo
	if(StringMatch(S_Value, "*<")|| StringMatch(S_Value, "_NONE_"))		//if user clicked on current path...
		Return 0
	endif 
	DoWindow/K TbT_GUI			//kill TbT win
	DoWindow/K ENS_GUI			//kill ENS win
	DoWindow/K HMM_Output		//kill Viterbi Browser
	HMM_inputPath = S_Value
	Print "SMACKS Input Path set to "+HMM_inputPath

	SetDataFolder HMM_inputPath

End






//################################
//# MAIN: HMM
//################################


Function HMM_ForwardBackward_parallel([mute])
	Variable mute		
	
	NVAR NumStates, NumDims
	NVAR ProdProbFB_MANT, ProdProbFB_EXP
	Wave HMM_pi, HMM_a, HMM_b_param
	Wave wObsWaves
	
	Variable Tmax = DimSize(wObsWaves, 0)
	Variable t, t_inv, sj, si, b
	Variable rn, temp_renorm_max = 0
		
	
	//avoid over/under flow: complete value = mantissa * ( k_renorm )^exponent
	Make /D /O /N=(Tmax, NumStates) HMM_alpha_MANT = 0, HMM_beta_MANT = 0			//mantissa[t][i]
	Make /I /O /N=(Tmax) HMM_alpha_EXP = 0, HMM_beta_EXP = 0							//exponent[t] (one exp. for ALL states ->summing...)
	
	
	
	//initialize alpha, beta
	//######################
		HMM_alpha_MANT[0][] = HMM_pi[q] * HMM_b_multithread(q, 0, wObsWaves, HMM_b_param)
	//renormalize:
	MatrixOP /FREE /O temp_alpha = maxVal( row(HMM_alpha_MANT,0) )
	rn = trunc(log(temp_alpha[0])/log(k_renorm))		//==n if max_temp > (k_renorm)^n, ==-n if max_temp < (1/k_renorm)^n
	HMM_alpha_MANT[0][] = HMM_alpha_MANT[0][q] / (k_renorm)^rn
	HMM_alpha_EXP[0] = rn	
	
	HMM_beta_MANT[Tmax-1][] = 1


	
	//recursion: alpha & beta in parallel
	//##########
	Variable nthreads, threadGroupID, threadGroupStatus, dummy

	nthreads= ThreadProcessorCount
	if(nthreads>=2)	//if >= 2 CPUs
		threadGroupID= ThreadGroupCreate(2)
		ThreadStart threadGroupID,0,HMM_alpha_loop(HMM_alpha_MANT, HMM_alpha_EXP, HMM_a, HMM_b_param, wObsWaves)
		ThreadStart threadGroupID,1,HMM_beta_loop(HMM_beta_MANT, HMM_beta_EXP, HMM_a, HMM_b_param, wObsWaves)
		do
			threadGroupStatus = ThreadGroupWait(threadGroupID,100)
		while( threadGroupStatus != 0 )
		dummy= ThreadGroupRelease(threadGroupID)
	else	//only 1 CPU available
		HMM_alpha_loop(HMM_alpha_MANT, HMM_alpha_EXP, HMM_a, HMM_b_param, wObsWaves)
		HMM_beta_loop(HMM_beta_MANT, HMM_beta_EXP, HMM_a, HMM_b_param, wObsWaves)
	endif

	
	//termination: production probability	
	//############
	MatrixOP /FREE /O temp_sum = sum( row(HMM_alpha_MANT,Tmax-1) )
	ProdProbFB_MANT = temp_sum[0]
	ProdProbFB_EXP = HMM_alpha_EXP[Tmax-1]
	
	AbortOnValue numtype(ProdProbFB_MANT), 55
	
	//print ProdProbFB per time step in exp notation:
	Variable stepP_mant10 = ProdProbFB_MANT^(1/Tmax)									//Tmax-root of ProdProbFB_MANT and ..._EXP
	Variable stepP_exp10 = log(k_renorm) * ProdProbFB_EXP / Tmax 
	Variable aux1 = trunc(log(stepP_mant10))
	stepP_mant10 = stepP_mant10 * 10^(mod(stepP_exp10,1) - aux1)
	stepP_exp10 = trunc(stepP_exp10) + aux1
	if(ParamIsDefault(mute))
		Print "ForwardBackward: P(O, s | lambda) / Tmax = ", stepP_mant10, "E", stepP_exp10
	endif

End





ThreadSafe Function HMM_b_multithread(state, t, wObsWaves, b_params)
	Variable state, t
	Wave wObsWaves, b_params
	
	Variable b, numdims = DimSize(b_params, 0)
	Duplicate /FREE /R=[t] wObsWaves, wVectorVar
	Redimension /N=(numdims) wVectorVar	
	
	//extract means Mu and covariance matrix
	Duplicate /FREE /R=[0,*][0][state] b_params, wVectorMu
	Redimension /N=(-1) wVectorMu		
	Duplicate /FREE /R=[0,*][1, *][state] b_params, wMatrixCoVar
	Redimension /N=(-1, -1) wMatrixCoVar	
	
	//multidim gauss with vectors and covariance matrix
	MatrixOP /FREE /O intermediate1 = exp(-1/2 * ( (wVectorVar -wVectorMu)^t x Inv(wMatrixCoVar) x (wVectorVar -wVectorMu) ))
	MatrixOP /FREE /O intermediate2 = intermediate1 * 1/(sqrt( powR(2*pi, numdims) * Det(wMatrixCoVar) ))
	b = intermediate2[0]
	
	if (b < 1e-200)
		//String info = StringFromList(0, StringByKey("AssociatedWaves", note(wObsWaves), "=", "\r"))
		b = 1e-200		//1e-312 is limit for ~10 digit precission, 1e-325 seems to be absolute Igor limit
	endif
	
	Return b
End







ThreadSafe Function HMM_alpha_loop(alpha_MANT, alpha_EXP, trans, b_params, wObsWaves)
	Wave alpha_MANT, alpha_EXP, trans, b_params, wObsWaves
	
	Variable numstates = DimSize(trans, 0), numdims = DimSize(b_params, 0), Tmax = DimSize(wObsWaves, 0)
	Variable t, alpha_sum, rn
	
	for (t=1; t<Tmax; t+=1)
		Make /FREE /D /O /N=(numstates) b_vec = HMM_b_multithread(p, t, wObsWaves, b_params)
		MatrixOP /FREE /O new_alpha = row(alpha_MANT, t-1) x trans * b_vec^t
		alpha_MANT[t][] = new_alpha[0][q]

		//renormalize:
		alpha_sum = sum(new_alpha)
		rn = trunc(log(alpha_sum)/log(k_renorm))				//==n if max_temp > (k_renorm)^n, ==-n if max_temp < (1/k_renorm)^n
		alpha_MANT[t][] = alpha_MANT[t][q] / (k_renorm)^rn
		alpha_EXP[t] = alpha_EXP[t-1] + rn
	endfor
	
End




ThreadSafe Function HMM_beta_loop(beta_MANT, beta_EXP, trans, b_params, wObsWaves)
	Wave beta_MANT, beta_EXP, trans, b_params, wObsWaves
	
	Variable numstates = DimSize(trans, 0), numdims = DimSize(b_params, 0), Tmax = DimSize(wObsWaves, 0)
	Variable t_inv, beta_sum, rn
	
	for (t_inv=Tmax-2; t_inv>=0; t_inv-=1)
		Make /FREE /D /O /N=(numstates) b_vec = HMM_b_multithread(p, t_inv+1, wObsWaves, b_params)
		MatrixOP /FREE /O new_beta = trans x (b_vec * row(beta_MANT, t_inv+1)^t)
		beta_MANT[t_inv][] = new_beta[q]

		//renormalize:
		beta_sum = sum(new_beta)
		rn = trunc(log(beta_sum)/log(k_renorm))		//==n if max_temp > (k_renorm)^n, ==-n if max_temp < (1/k_renorm)^n
		beta_MANT[t_inv][] = beta_MANT[t_inv][q] / (k_renorm)^rn
		beta_EXP[t_inv] = beta_EXP[t_inv+1] + rn
	endfor

End





Function HMM_BaumWelch_multidim()
		
	NVAR NumStates, NumDims
	NVAR ProdProbFB_MANT, ProdProbFB_EXP
	NVAR FRETcons
	Wave HMM_pi, HMM_a, HMM_b_param
	Wave wObsWaves
	Wave HMM_alpha_MANT, HMM_alpha_EXP
	Wave HMM_beta_MANT, HMM_beta_EXP
	
	Variable ti
	Variable Tmax = DimSize(wObsWaves, 0)
	
	
	
	//____AUX PROBS:
	//################	

	//gamma[t][i]
	MatrixOP /NTHR=0 /FREE HMM_gamma_MANT = (HMM_alpha_MANT * HMM_beta_MANT) / ProdProbFB_MANT	
	Make /FREE /I /N=(Tmax) HMM_gamma_EXP
	HMM_gamma_EXP = HMM_alpha_EXP + HMM_beta_EXP - ProdProbFB_EXP
	Make /FREE /D /N=(Tmax, NumStates) HMM_gamma
	Multithread HMM_gamma = HMM_gamma_MANT * (k_renorm)^(HMM_gamma_EXP[p])

		
	//gamma_trans[i][j][t]   (t=1,...,Tmax-1)!
	Make /FREE /D /N=(NumStates, NumStates, Tmax-1) HMM_gamma_trans, HMM_gamma_trans_MANT
	Make /FREE /I /N=(Tmax-1) HMM_gamma_trans_EXP
	Multithread HMM_gamma_trans_MANT = HMM_alpha_MANT[r][p] * HMM_a[p][q] * HMM_b_multithread(q, r+1, wObsWaves, HMM_b_param) * HMM_beta_MANT[r+1][q] / ProdProbFB_MANT	
	Multithread HMM_gamma_trans_EXP = HMM_alpha_EXP[p] + HMM_beta_EXP[p+1] - ProdProbFB_EXP
	Multithread HMM_gamma_trans = HMM_gamma_trans_MANT * (k_renorm)^(HMM_gamma_trans_EXP[r])
	Duplicate/FREE HMM_gamma, HMM_xi
				
	

	//____UPDATE:
	//################	
	
	//update HMM_pi
	Make /D /O /N=(NumStates) HMM_pi_new = HMM_gamma[0][p]
	HMM_pi_new = (HMM_pi_new < 1/k_renorm)? 0 : HMM_pi_new																//set pi to 0 if too small	
	
	
	//update HMM_a
	Duplicate /FREE /O /R=[0, Tmax-2][] HMM_gamma HMM_gamma_short														//(t=1,...,Tmax-1) -> cf. HMM_gamma_trans...
	MatrixOP /NTHR=0 /O HMM_a_denom = sumCols(HMM_gamma_short)^t														//[i]; keep for ensemble opt.	
	MatrixOP /NTHR=0 /O HMM_a_numer = sumBeams(HMM_gamma_trans)														//[i][j]; keep for ensemble opt
	Make /D /O /N=(NumStates, NumStates) HMM_a_new = HMM_a_numer[p][q] / HMM_a_denom[p]

	
	//update HMM_b

	//update mu
	// -numerator:
	Make /FREE /D /N=(Tmax, NumStates, NumDims) HMM_xi_Obs												//xi_Obs[t][i][d]
	Multithread HMM_xi_Obs = HMM_xi[p][q] * wObsWaves[p][r]
	MatrixOP /NTHR=0 /FREE HMM_xi_Obs_transposed = transposeVol(HMM_xi_Obs, 3)						//mode=3: output=w[r][q][p] ^= [d][i][t] (needed for sumBeams etc.)
	MatrixOP /NTHR=0 /FREE meanSumObs = ( sum(wObsWaves) )/numRows(wObsWaves)
	// keep for ENS: 
	MatrixOP /O HMM_xiObs_SumT = sumBeams(HMM_xi_Obs_transposed)										//HMM_xi_Obs_SumT[d][i] == numerator of new mu
	MatrixOP /O HMM_xiObs_SumT_cons = meanSumObs[0] * HMM_xiObs_SumT									//in constrained mode: <A>+<I>=<Itot>

	// -denominator:
	Duplicate /FREE HMM_xi HMM_xi_sumObs
	MatrixOP /NTHR=0 /FREE sumObs = sumRows(wObsWaves)
	Multithread HMM_xi_sumObs = HMM_xi[p][q][r] * sumObs[p][0]
	// keep for ENS:
	MatrixOP /O HMM_xi_SumT = sumCols(HMM_xi)						//std version						// keep for ENS: HMM_xi_SumT[0][i] == denominator of new mu (1d in y)
	MatrixOP /O HMM_xi_SumT_cons = sumCols(HMM_xi_sumObs)		//cons version						// keep for ENS: HMM_xi_SumT[0][i] == denominator of new mu (1d in y)

	// single trace mu:
	Make /D /O /N=(NumDims, NumStates) HMM_mu_new, HMM_mu_cons
	HMM_mu_new = HMM_xiObs_SumT[p][q] / HMM_xi_SumT[0][q]												//HMM_mu_new[d][i]
	HMM_mu_cons = HMM_xiObs_SumT_cons[p][q] / HMM_xi_SumT_cons[0][q]									//HMM_mu_cons[d][i]; constrained to <A>+<I>=<Itot>

	
	//update (co)variance
	// keep for ENS: 
	Make /D /O /N=(NumDims, NumDims, NumStates) HMM_xi_ObsSquare_SumT = 0							//HMM_xi_ObsSquare[d][d][i]
	Make/WAVE/N=(Tmax) ww
	Multithread ww = fill_xi_ObsSquare_temp(p, NumDims, NumStates, wObsWaves, HMM_xi)
	
	for (ti=0; ti<Tmax; ti+=1)
		Wave w = ww[ti]
		HMM_xi_ObsSquare_SumT += w
	endfor
	KillWaves ww
	
	// single trace var:
	Make /FREE /D /N=(NumDims, NumDims, NumStates) mu_Square_tot, HMM_CovarMatrix		
	MatrixOP /FREE mu_trans = HMM_mu_new^t
	mu_Square_tot = HMM_mu_new[p][r] * mu_trans[r][q]													//mu_Square_tot[d][d][i]
	HMM_CovarMatrix = HMM_xi_ObsSquare_sumT / HMM_xi_SumT[0][r] - mu_Square_tot					//HMM_CovarMatrix[d][d][i]	


	//update HMM_b_...[d][mu,CoVar][i]
	// single trace b_param: 
	Duplicate/O HMM_b_param HMM_b_param_new																//"duplicate" required to keep notes. 		HMM_b_param_new[][0][] = HMM_mu_new[p][r]
	HMM_b_param_new[][0][] = HMM_mu_new[p][r]
	if(FRETcons)
		HMM_b_param_new[][0][] = HMM_mu_cons[p][r]				//constrained to <A>+<D>=<Itot>
	endif																		
	HMM_b_param_new[][1,*][] = HMM_CovarMatrix[p][q-1][r]

End





ThreadSafe Function/WAVE fill_xi_ObsSquare_temp(ti, NumDims, NumStates, wObsWaves, HMM_xi)
	Variable ti, NumDims, NumStates
	Wave wObsWaves, HMM_xi

	//Create a free data folder to hold the extracted and filtered plane
	DFREF dfSav= GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()
	
	Make /D /N=(NumDims, NumDims, NumStates) xi_ObsSquare_temp													//xi_ObsSquare_temp[d][d][s]
	
	Duplicate /FREE /R=[ti] wObsWaves, vectorCurrObs																//gives row vector, so don't Redimension!
	MatrixOP /FREE matrixObsSquare = (vectorCurrObs^t) x vectorCurrObs										//matrixObsSquare[d][d] = (vector^t)^t x vector^t
	xi_ObsSquare_temp = HMM_xi[ti][r] * matrixObsSquare[p][q]													// xi@t_curr in z-dim, matrixObsSquare in x-y-dim

	//Return a reference to the free data folder containing xi_ObsSquare_temp
	SetDataFolder dfSav
	return xi_ObsSquare_temp
End





Function HMM_Viterbi_multidim([mute])
	Variable mute
	
		
	NVAR NumStates, NumDims
	NVAR ProbVit_MANT, ProbVit_EXP
	Wave HMM_pi, HMM_a, HMM_b_param
	Wave wObsWaves	

	Variable ti, sj, temp_renorm_max
	Variable Tmax = DimSize(wObsWaves, 0)
	Variable rn
	
	
	Make /FREE /D /O /N=(Tmax, NumStates) HMM_delta_MANT, HMM_psi					//[t][i]
	Make /FREE /I /O /N=(Tmax) HMM_delta_EXP = 0		
	Duplicate /O /R=[][0] wObsWaves HMM_s												//[t]; keep input wave scaling
	Redimension/I /N=(-1) HMM_s															//make truly 1D
	

	//initiation
	//##########
	HMM_delta_MANT[0] = HMM_pi[q] * HMM_b_multithread(q, 0, wObsWaves, HMM_b_param)	
	HMM_psi[0] = 0

	//renormalize:
	MatrixOP /FREE /O max_temp = maxVal( row(HMM_delta_MANT,0) )
	rn = trunc(log(max_temp[0])/log(k_renorm))		//==n if max_temp > (k_renorm)^n, ==-n if max_temp < (1/k_renorm)^n
	HMM_delta_MANT[0][] = HMM_delta_MANT[0][q] / (k_renorm)^rn
	HMM_delta_EXP[0] = rn		
	
	
	
	//recursion
	//##########
	for (ti=1; ti<Tmax; ti+=1)																		
		temp_renorm_max = 0
		for (sj=0; sj<NumStates; sj+=1)															
			Make /FREE /D /N=(NumStates) delta_temp = HMM_delta_MANT[ti-1][p] * HMM_a[p][sj]		
			WaveStats/Q/M=1 delta_temp
			HMM_delta_MANT[ti][sj] = V_max * HMM_b_multithread(sj, ti, wObsWaves, HMM_b_param)		//V_max ^= max( delta[t-1]*a ) over all si			
			HMM_psi[ti][sj] = V_maxLoc																			//V_maxloc ^= state si that maximises( delta[t-1]*a ); ->ARGmax(...)			
			temp_renorm_max = max(temp_renorm_max, HMM_delta_MANT[ti][sj])								//renorm if maximum is "already" < k_renorm (min or max is arbitrary here.)
		endfor

		//renormalize
		rn = trunc(log(temp_renorm_max)/log(k_renorm))		//==n if max_temp > (k_renorm)^n, ==-n if max_temp < (1/k_renorm)^n
		HMM_delta_MANT[ti][] = HMM_delta_MANT[ti][q] / (k_renorm)^rn
		HMM_delta_EXP[ti] = HMM_delta_EXP[ti-1] + rn
	endfor
	
	
	//termination
	//###########
	delta_temp = HMM_delta_MANT[Tmax-1][p]														//delta_temp[i]
	WaveStats /M=1 /Q delta_temp																	//V_max of delta[Tmax-1] ^= P* (maxProdProb)
	HMM_s[Tmax-1] = V_maxRowLoc																	//q_T* ^=V_maxColLoc of delta[Tmax-1]
	ProbVit_MANT = V_max															
	ProbVit_EXP = HMM_delta_EXP[Tmax-1]
	AbortOnValue numtype(ProbVit_MANT), 66


	//print maxProdProb per time step in exp notation:
	Variable stepP_mant10 = ProbVit_MANT^(1/Tmax)												//Tmax-root of ProbVit_MANT and ..._EXP
	Variable stepP_exp10 = log(k_renorm) * ProbVit_EXP / Tmax 
	Variable aux1 = floor(log(stepP_mant10))
	stepP_mant10 = stepP_mant10 * 10^(mod(stepP_exp10,1) - aux1)
	stepP_exp10 = floor(stepP_exp10) + aux1
	if(ParamIsDefault(mute))
		Print "Viterbi: P(O, s* | lambda) / Tmax = ", stepP_mant10, "E", stepP_exp10	
	endif

	
	//backtracking																					//only now the maximised state sequence is entirely known.
	//###########
	for (ti=Tmax-2; ti>=0; ti-=1)
		HMM_s[ti] = HMM_psi[ti+1][HMM_s[ti+1]]
	endfor
		
End





//################################
//# Helper Functions
//################################


//threshold for logarithmic renormalization: 
Constant k_renorm = 1e50



//store frequent start parameters
Function HMM_startParam(currPath)
	string currPath

	DFREF saveDFR = GetDataFolderDFR()
	SetDataFolder currPath		

	NVAR NumStates, NumDims
	Make /D /O /N=(NumStates) HMM_pi_start			
	Make /D /O /N=(NumStates, NumStates) HMM_a_start
	Make /D /O /N=(NumDims, NumDims+1, NumStates) HMM_b_param_start
	

	switch(NumStates)	
		case 2:		
			
			HMM_pi_start = {0.5 , 0.5}
			HMM_a_start = {{0.8 , 0.2}, {0.2 , 0.8}}
			if(NumDims==1)	
				HMM_b_param_start = { { {0.1} , {5e-3} } , { {0.8} , {5e-3} } }
			elseif(NumDims==2)	
				HMM_b_param_start[][][0] = { {1e4 , 1e3} , {1e6 , 0} , {0 , 1e6} }
				HMM_b_param_start[][][1] = { {1e3 , 1e4} , {1e6 , 0} , {0 , 1e6} }
			endif
			break						

		case 3:		

			HMM_pi_start = {0.333 , 0.333 , 0.333}
			HMM_a_start[][0] = {0.9  , 0.1 , 0.1}
			HMM_a_start[][1] = {0.05 , 0.8 , 0.1} 
			HMM_a_start[][2] = {0.05 , 0.1 , 0.8}
			if(NumDims==1)	
				HMM_b_param_start[][][0] = { {0.1} , {5e-3} }
				HMM_b_param_start[][][1] = { {0.8} , {5e-3} } 
				HMM_b_param_start[][][2] = { {0.8} , {5e-3} }
			elseif(NumDims==2)	
				HMM_b_param_start[][][0] = { {1e4 , 1e3} , {1e6 , 0} , {0 , 1e6} } 
				HMM_b_param_start[][][1] = { {1e4 , 1e3} , {1e6 , 0} , {0 , 1e6} } 
				HMM_b_param_start[][][2] = { {1e3 , 1e4} , {1e6 , 0} , {0 , 1e6} }
			endif
			break

		case 4:		

			HMM_pi_start = {0.25 , 0.25 , 0.25 , 0.25}
			HMM_a_start[][0] = {0.7 , 0.1 , 0.1 , 0.1}
			HMM_a_start[][1] = {0.1 , 0.6 , 0.1 , 0.1}
			HMM_a_start[][2] = {0.1 , 0.2 , 0.7 , 0.1} 
			HMM_a_start[][3] = {0.1 , 0.1 , 0.1 , 0.7} 
			if(NumDims==1)	
					HMM_b_param_start[][][0] = { {0.1} , {5e-3} } 
					HMM_b_param_start[][][1] = { {0.2} , {5e-3} }
					HMM_b_param_start[][][2] = { {0.8} , {5e-3} } 
					HMM_b_param_start[][][3] = { {0.9} , {5e-3} } 
			elseif(NumDims==2)	
					HMM_b_param_start[][][0] = { {1e4 , 1e3} , {1e6 , 0} , {0 , 1e6} } 
					HMM_b_param_start[][][1] = { {1e4 , 1e3} , {1e6 , 0} , {0 , 1e6} }
					HMM_b_param_start[][][2] = { {1e3 , 1e4} , {1e6 , 0} , {0 , 1e6} }
					HMM_b_param_start[][][3] = { {1e3 , 1e4} , {1e6 , 0} , {0 , 1e6} }
			endif
			break

		case 5:		

			HMM_pi_start = {0.2 , 0.2 , 0.2 , 0.2, 0.2}
			HMM_a_start[][0] = {0.9,		0.05,		0.05,		0.05,		0.01}
			HMM_a_start[][1] = {0.05,		0.8,		0.1,		0.05,		0.02}
			HMM_a_start[][2] = {0.02,		0.05,		0.7,		0.05,		0.05}
			HMM_a_start[][3] = {0.01,		0.05,		0.05,		0.8,		0.02}
			HMM_a_start[][4] = {0.02,		0.05,		0.1,		0.05,		0.9}
			if(NumDims==1)	
					HMM_b_param_start[][][0] = { {0.05} , {5e-3} } 
					HMM_b_param_start[][][1] = { {0.1} , {5e-3} }
					HMM_b_param_start[][][2] = { {0.2} , {5e-3} }
					HMM_b_param_start[][][3] = { {0.8} , {5e-3} } 
					HMM_b_param_start[][][4] = { {0.9} , {5e-3} } 
			elseif(NumDims==2)	
					HMM_b_param_start[][][0] = { {1e4 , 1e3} , {1e6 , 0} , {0 , 1e6} } 
					HMM_b_param_start[][][1] = { {1e4 , 1e3} , {1e6 , 0} , {0 , 1e6} } 
					HMM_b_param_start[][][2] = { {1e4 , 1e3} , {1e6 , 0} , {0 , 1e6} }
					HMM_b_param_start[][][3] = { {1e3 , 1e4} , {1e6 , 0} , {0 , 1e6} } 
					HMM_b_param_start[][][4] = { {1e3 , 1e4} , {1e6 , 0} , {0 , 1e6} } 
			endif
			break
			
		case 6:		

			HMM_pi_start = {0.16, 0.16,	0.16,	0.16,	0.16,	0.16}
			HMM_a_start[][0] = {0.9,		0.04,		0.06,		0.06,		0.04,		0.02}
			HMM_a_start[][1] = {0.02,		0.8,		0.06,		0.06,		0.04,		0.02}
			HMM_a_start[][2] = {0.02,		0.04,		0.7,		0.06,		0.04,		0.02}
			HMM_a_start[][3] = {0.02,		0.04,		0.06,		0.7,		0.04,		0.02}
			HMM_a_start[][4] = {0.02,		0.04,		0.06,		0.06,		0.8,		0.02}
			HMM_a_start[][5] = {0.02,		0.04,		0.06,		0.06,		0.04,		0.9}
			if(NumDims==1)	
					HMM_b_param_start[][][0] = { {0.05} , {5e-3} } 
					HMM_b_param_start[][][1] = { {0.1} , {5e-3} }
					HMM_b_param_start[][][2] = { {0.2} , {5e-3} }
					HMM_b_param_start[][][3] = { {0.8} , {5e-3} } 
					HMM_b_param_start[][][4] = { {0.9} , {5e-3} } 
					HMM_b_param_start[][][5] = { {0.95} , {5e-3} } 
			elseif(NumDims==2)	
					HMM_b_param_start[][][0] = { {1e4 , 1e3} , {1e6 , 0} , {0 , 1e6} } 
					HMM_b_param_start[][][1] = { {1e4 , 1e3} , {1e6 , 0} , {0 , 1e6} } 
					HMM_b_param_start[][][2] = { {1e4 , 1e3} , {1e6 , 0} , {0 , 1e6} }
					HMM_b_param_start[][][3] = { {1e3 , 1e4} , {1e6 , 0} , {0 , 1e6} } 
					HMM_b_param_start[][][4] = { {1e3 , 1e4} , {1e6 , 0} , {0 , 1e6} } 
					HMM_b_param_start[][][5] = { {1e3 , 1e4} , {1e6 , 0} , {0 , 1e6} } 
			endif
	endswitch
	
	SetDataFolder saveDFR
End



function HMM_totOutputWin(titleStr)
	string titleStr

	DFREF saveDFR = GetDataFolderDFR()
	SVAR HMM_inputPath = root:HMM_inputPath
	SVAR TbT_path = root:TbT_path

	if(StringMatch(titleStr, "TbT*"))
		SetDataFolder TbT_path
	elseif(StringMatch(titleStr, "ENS*"))
		SVAR ENS_path = root:ENS_path
		SetDataFolder ENS_path
	else
		print "totOutputWin: unknown titleStr. Proceeds in "+GetDataFolder(1)
	endif
	
	SVAR/Z strExcludeB, nonConvList
	NVAR NumStates, NumDims
	wave HMM_b_param

	string wList = WaveList("HMM_x*_y*", ";", "")
	variable nTraces=ItemsInList(wList)
	Variable yOffset = NumStates+2, mulY = 0
	Variable i, j


	if(nTraces==0)
		SetDataFolder saveDFR
		Abort "totOutputWin: No input found!"
	endif
	
	DoWindow/K $titleStr
	Display/K=1/W=(1021,45,1658,832)/N=$titleStr as "Viterbi Paths > "+GetDataFolder(0)


	//scaling of continuous output
	Duplicate/FREE/R=[][0][] HMM_b_param tot_mu
	MatrixOP/FREE/O maxObs = maxVal(tot_mu)
	yOffset = (4)*maxObs[0]+2
	mulY = 2* maxObs[0]/(NumStates-1)

	
	for(i=0; i<nTraces; i+=1)
		//get waves in output order
		string strS = StringFromList(i, wList)
		wave/Z wS = $strS
		if(!WaveExists(wS))
			Continue
		endif
		string assocList = StringByKey("HMMWaves", note(wS), "=", "\r")	//load input wave(s)
		string strObs = StringFromList(0,assocList)
		wave wObs = $HMM_inputPath+strObs


		//plot input wave(s)
		AppendToGraph/W=$titleStr wObs
		ModifyGraph/W=$titleStr offset($strObs)={0, yOffset*i}, rgb($strObs)=(3,52428,1)

		for (j=1; j<NumDims; j+=1)							//is skipped when only 1D
			string strObs2 = StringFromList(j, assocList)
			wave wObs2 = $HMM_inputPath+strObs2
			AppendToGraph/W=$titleStr wObs2
			ModifyGraph/W=$titleStr offset($strObs2)={0, yOffset*i}	
			if(j==2)
				ModifyGraph/W=$titleStr rgb($strObs2)=(32768,0,0)	//adjust 3rd dim's color
			endif
		endfor


		//plot Viterbi path
		AppendToGraph/W=$titleStr wS
		ModifyGraph/W=$titleStr offset($strS)={0, yOffset*i}, rgb($strS)=(0,0,0), muloffset($strS)={0,mulY}


		//label excluded (ENS) or nonConv (TbT) traces:
		if(Exists("strExcludeB"))
			string strCurr_b = "b"+strObs[3, strlen(strObs)-1]
			if(StringMatch(strExcludeB, "*"+strCurr_b+"_*"))
				ModifyGraph rgb($strS)=(0,65535,65535)
			endif
		endif
		if(Exists("nonConvList"))
			if(StringMatch(nonConvList, "*"+strObs+"*") )
				ModifyGraph rgb($strS)=(0,65535,65535)
			endif
		endif
		
	endfor
	
	SetDataFolder saveDFR
End




Function KillTimer()
	Variable i
	for (i=0; i<10; i+=1)
		variable t = stopMSTimer(i)
	endfor
End
