#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#pragma IgorVersion = 6.3.0.1

#pragma version = 20170529


// addOns rely on the currently selected setup.
Menu "SMACKS"

	"-------------"
	"Confidence Intervals", loop_getCI()
	SubMenu "AddOns"	
		"Compare BICs", dispBIC()
		"Random Start", randomStart()
		"Random Subset", randomSubset(2/3)
		SubMenu 	"Show Output Traces" 
			"TbT", HMM_totOutputWin("TbT")
			"ENS", HMM_totOutputWin("ENS")
		End
		"Plot µ's 2D", TbT_plot_emi_obs()
		"Show B params", TbT_plotSingleB()
		
//		"Get Results", Results("")
//		"Get Final Waves Hist", getHMMwaves()
//		"Kill Timers", killTimer()
//		"Kill Threads", killThreads()
	End

End



Function killThreads()

	SVAR/Z ENS_path = root:ENS_path	
	NVAR/Z tgID = $ENS_path+"threadGroupID"
	
	variable flag = ThreadGroupRelease(tgID)
//	if(flag==0)
	if(NVAR_Exists(tgID) && ThreadGroupRelease(tgID))
		print "killThreads(): Thread ", tgID, " was successfully killed."
//	elseif(flag==-1)
	else
		print "killThreads(): No threads to kill."
//	else
//		print "killThreads(): Unknown flag: ", flag
	endif

End




function getHMMwaves()

	SVAR ENS_path = root:ENS_path
	string saveDF = GetDataFolder(1)
	if(DatafolderExists(ENS_path))
		SetDataFolder ENS_path
	else
		Print "getHMMwaves: Staying in", saveDF
	endif
	
	wave/WAVE wInputRef
	string assocList
	SetDataFolder :://FRET:offset 
	NewDataFolder/S HMMwaves
	
	variable i,j
	for(i=0; i<dimSize(wInputRef,0); i+=1)
		assocList = StringByKey("AssociatedWaves", note(wInputRef[i]), "=", "\r")
		j=0
		do
			duplicate ::$StringFromList(j, assocList) $StringFromList(j, assocList)
			j+=1
		while(j<3)
	endfor
	
	print i
	if(cmpStr(FunctionInfo("prepSEpanel"),""))	//function exists
		Execute "prepSEpanel()"
	else
		SetDataFolder saveDF
	endif
	
End




//plot individual mu's & var's
Function TbT_plotSingleB()

	SVAR TbT_path = root:TbT_path
	DFREF saveDFR = GetDataFolderDFR()
	if(DataFolderExists(TbT_path))
		SetDataFolder TbT_path
	else
		print "TbT_plotSingleB() CurrDF = "+GetDataFolder(1)
	endif
	
	wave b_params = collect_b_param
	Make/O/N=(DimSize(b_params, 3 )) mu_0 = Nan
	Duplicate/O mu_0 mu_1, mu_0_d2, mu_1_d2, var_0, var_1, var_0_d2, var_1_d2
	
	//1st dim
	mu_0 = b_params[0][0][0][p]
	mu_1 = b_params[0][0][1][p]
	var_0 = b_params[0][1][0][p]
	var_1 = b_params[0][1][1][p]

	Display/K=1/N=single_mu/W=(580,45,975,253) mu_0, mu_1
	ModifyGraph rgb(mu_1)=(1,16019,65535)
	wave/Z offset_0 = ::offset_0, offset_1 = ::offset_1		//from simKin...
	if(waveExists(offset_0) && waveExists(offset_1))
		AppendToGraph offset_0, offset_1
		ModifyGraph offset(offset_1)={0,1}, rgb(offset_1)=(0,0,0), rgb(offset_0)=(0,0,0)
	endif

	Display/K=1/N=single_var/W=(978,45,1373,253) var_0, var_1
	ModifyGraph rgb(var_1)=(1,16019,65535)


	NVAR/Z NumDims
	if(NumDims==2)
		//2nd dim
		mu_0_d2 = b_params[1][0][0][p]
		mu_1_d2 = b_params[1][0][1][p]
		var_0_d2 = b_params[1][2][0][p]
		var_1_d2 = b_params[1][2][1][p]	
		Display/K=1/N=single_mu_d2/W=(580,276,975,484) mu_0_d2, mu_1_d2
		ModifyGraph rgb(mu_1_d2)=(1,16019,65535)
		Display/K=1/N=single_var_d2/W=(978,276,1373,484) var_0_d2, var_1_d2
		ModifyGraph rgb(var_1_d2)=(1,16019,65535)
	endif

	SetDataFolder saveDFR
End



//plot emissions onto observables
Function TbT_plot_emi_obs([allEmi])
	variable allEmi

	SVAR HMM_inputPath = root:HMM_inputPath
	SVAR TbT_path = root:TbT_path
	
	DFREF saveDFR = GetDataFolderDFR()	
	variable i, j, wmax=0

//	string cList = "acontour;bcontour;ccontour;dcontour;econtour;fcontour;gcontour;"
	string winStr = UniqueName("obs_emi_2D_", 6, 0 )
	print winStr
	Display/K=1/N=$winStr

	//DF flexibility (allows pointing at renamed "HMM-folder")
	string currHmmPath = TbT_path
	if(!DataFolderExists(TbT_path))
		currHmmPath = ":"
	endif

	SetDataFolder currHmmPath
	NVAR n=NumStates	//dimSize(b_param, 2)
	NVAR d=NumDims		//dimSize(b_param, 0)
	wave collect_b_param
	variable nTraces = DimSize(collect_b_param, 3 )


	//get observable hist 2D
	if(DataFolderExists(":emiPlot"))
		SetDataFolder :emiPlot
	else		
//		wave conc_acc = concat("r_g*")
//		wave conc_don = concat("o_g*")
		wave conc_acc = concat(StringFromList(1, dataID)+"*")
		wave conc_don = concat(StringFromList(0, dataID)+"*")

		NewDataFolder/O/S :emiPlot

		MatrixOP/FREE/O meanSumObs = (sum(conc_acc)+sum(conc_don))/numRows(conc_acc)
		Make/O/N=2 wConsItot 
		SetScale/I x, 0, 1E4, wConsItot
		wConsItot = meanSumObs[0] -x

		fluo_hist2d(conc_don, conc_acc, "obs2D", 50, 50)	
	endif

	wave wConsItot
	wave obs2D
	wave obs2D_X
	wave obs2D_Y
//	obs2d/=wavemax(obs2D)	//normalize to max=1

	AppendImage/W=$winStr obs2D
	ModifyImage/W=$winStr obs2D ctab= {1,*,Grays,0}
	ModifyImage obs2D minRGB=NaN,maxRGB=0
	ModifyGraph/W=$winStr height={Aspect,1}
	

	//state dependent color (up to 5states)
	Make/O/N=(3,4) wRGB = {{65535,0,0}, {0,65535,0}, {0,0,65535}, {65535,0,65535}, {0,65535,65535}}


	//get emissions hist 2D
	for(i=0; i<n; i+=1)	//states
		//store tot. emissions & single_mu's
		duplicate/O obs2D $"totemi2D_"+num2str(i)/WAVE=totemi2D
		totemi2D=0
		Make/O/N=(nTraces,2) $"all_muXY_"+num2str(i)/WAVE=muXY

		for(j=0; j<nTraces; j+=1)	//traces	
			duplicate/O/FREE/R=[][][][j] collect_b_param b_param	
			muXY[j][] = b_param[q][0][i]

			string sCurr = "emi2D_"+num2str(i)+"_"+num2str(j)
			if(ParamIsDefault(allEmi))
				duplicate/FREE/O obs2D emi
			else
				duplicate/O obs2D $sCurr/WAVE=emi
				AppendMatrixContour/W=$winStr emi
				ModifyContour/W=$winStr $sCurr update=0, labels=0, autoLevels= {*, *, 3 }
				ModifyContour/W=$winStr $sCurr rgbLines=(wRGB[0][i],wRGB[1][i],wRGB[2][i])
			endIF

			Multithread emi = plot_b(i, b_param, {x,y})
			WaveStats/M=1/Q emi
			if(V_numNans!=0)
				Continue
			endif
			totemi2D+=emi
		endfor

		if(ParamIsDefault(allEmi))
			AppendMatrixContour/W=$winStr totemi2D
			ModifyContour/W=$winStr $NameOfWave(totemi2D) update=0, labels=0, autoLevels= {*, *, 3 }
			ModifyContour/W=$winStr $NameOfWave(totemi2D) rgbLines=(wRGB[0][i],wRGB[1][i],wRGB[2][i])
			
			AppendToGraph/W=$winStr muXY[][1] vs muXY[][0]
			ModifyGraph/W=$winStr rgb($NameOfWave(muXY))=(wRGB[0][i],wRGB[1][i],wRGB[2][i])
			ModifyGraph/W=$winStr mode($NameOfWave(muXY))=3
		endif
	endfor
//	totemi2D/=wavemax(totemi2D)
	
	
	//append constraint if available
	wave/Z wConsItot = $currHmmPath+"wConsItot"
	if(WaveExists(wConsItot))
		AppendToGraph wConsItot
	endif
	
	SetAxis bottom pnt2x(obs2D_X,0), pnt2x(obs2D_X,50)
	SetAxis left  pnt2x(obs2D_Y,0), pnt2x(obs2D_Y,50)
	
	SetDataFolder saveDFR

End




//emissions = plot_b(0, HMM_b_param_ens, {x,y})
ThreadSafe Function plot_b(state, b_params, wVectorVar)
	Variable state
	Wave b_params, wVectorVar
	
	Variable b, numdims = DimSize(b_params, 0)
		
	//extract means Mu and covariance matrix
	Duplicate /FREE /R=[0,*][0][state] b_params, wVectorMu
	Redimension /N=(-1) wVectorMu		
	Duplicate /FREE /R=[0,*][1, *][state] b_params, wMatrixCoVar
	Redimension /N=(-1, -1) wMatrixCoVar	
	
	//multidim gauss with vectors and covariance matrix
	MatrixOP /FREE /O intermediate1 = exp(-1/2 * ( (wVectorVar -wVectorMu)^t x Inv(wMatrixCoVar) x (wVectorVar -wVectorMu) ))
	MatrixOP /FREE /O intermediate2 = intermediate1 * 1/(sqrt( powR(2*pi, numdims) * Det(wMatrixCoVar) ))
	b = intermediate2[0]
	
	Return b
End



function/WAVE concat(matchStr)
	string matchStr
		
	DFREF saveDFR = GetDataFolderDFR()
	SVAR HMM_inputPath = root:HMM_inputPath
	if(DataFolderExists(HMM_inputPath))
		SetDataFolder HMM_inputPath
	else
		print "concat(): proceeds in currDF."
	endif

		
	string wList = WaveList(matchStr, ";", "" )
	wList = RemoveFromList(WaveList("*_X",";",""), wList)
	string destStr = "conc_"+ReplaceString("*", matchStr, "")

	if(WaveExists($destStr))
		wave wConc = $destStr
		SetDataFolder saveDFR	
		Return wConc
	endif		

	Concatenate/O  wList, $destStr
	wave wConc = $destStr
	
	SetDataFolder saveDFR	
	Return wConc	
End





//plots selected multidim. parameters separately in 1d.
//call from any DF.
Function ENS_paramLog()
	
	SVAR ENS_path = root:ENS_path
	DFREF saveDFR = GetDataFolderDFR()
	if(DataFolderExists(ENS_path))
		SetDataFolder ENS_path
	else
		print "ENS_plaramLog() CurrDF = "+GetDataFolder(1)
	endif
	
	
	NVAR NumStates
	wave/Z log_pi, log_a, log_emit
	
	Variable i, j
	variable iter = DimSize(log_a, 2)
	
	Display/N=A_paramLog
	for(i=0; i<NumStates; i+=1)
		for(j=0; j<NumStates; j+=1)
			string axisStr = "L"+num2str(round(abs(enoise(1000))))
			AppendToGraph/L=$axisStr log_a[i][j][0,(iter-1)]
			ModifyGraph freePos($axisStr)={0,bottom}
//			AppendToGraph log_emit[i][j][0,(iter-1)]
//			Display/K=1 log_a[i][j][0,(iter-1)]
		endfor
	endfor
	ModifyGraph margin(left)=57
	
	SetDataFolder saveDFR
End





//compare input (sim.) & output (HMM) of single b_params
//(relies on simKin...)
//single_b's are in order of wInputRef! :-)
Function ENS_plotSingleB()

	SVAR ENS_path = root:ENS_path
	DFREF saveDFR = GetDataFolderDFR()
	if(DataFolderExists(ENS_path))
		SetDataFolder ENS_path
	else
		print "ENS_plotSingleB() CurrDF = "+GetDataFolder(1)
	endif
	
	NVAR/Z NumDims
	SVAR/Z strExcludeB
	wave/Z offset_0 = ::offset_0, offset_1 = ::offset_1		//from simKin...
	string bList = WaveList("b_x*_y*", ";", "" )
	variable i
//	Make/O/N=(ItemsInList(bList)) mu_0, mu_1, mu_0_d2, mu_1_d2, var_0, var_1, var_0_d2, var_1_d2
	Make/O/N=(ItemsInList(bList)) mu_0 = Nan
	Duplicate/O mu_0 mu_1, mu_0_d2, mu_1_d2, var_0, var_1, var_0_d2, var_1_d2
	
	for(i=0;i<ItemsInList(bList); i+=1)
		string currStr = StringFromList(i, bList)
		if(StringMatch(strExcludeB, "*"+currStr+"_*" ))
			Continue
		endif
		wave curr_b = $currStr
		mu_0[i] = curr_b[0][0][0]
		mu_1[i] = curr_b[0][0][1]
		var_0[i] = curr_b[0][1][0]
		var_1[i] = curr_b[0][1][1]	
//		mu_1[i] = curr_b[0][0][2]
//		var_1[i] = curr_b[0][1][2]	

		//2nd dimension
		mu_0_d2[i] = curr_b[1][0][0]
		mu_1_d2[i] = curr_b[1][0][1]
		var_0_d2[i] = curr_b[1][2][0]
		var_1_d2[i] = curr_b[1][2][1]	
//		mu_1_d2[i] = curr_b[1][0][2]
//		var_1_d2[i] = curr_b[1][2][2]	
	endfor
	
	WaveTransform/O zapNans mu_0
	WaveTransform/O zapNans mu_1
	WaveTransform/O zapNans var_0
	WaveTransform/O zapNans var_1
	WaveTransform/O zapNans mu_0_d2
	WaveTransform/O zapNans mu_1_d2
	WaveTransform/O zapNans var_0_d2
	WaveTransform/O zapNans var_1_d2

	Display/K=1/N=single_mu/W=(580,45,975,253) mu_0, mu_1
	ModifyGraph rgb(mu_0)=(3,52428,1)
	if(waveExists(offset_0) && waveExists(offset_1))
		AppendToGraph offset_0, offset_1
		ModifyGraph offset(offset_1)={0,1}, rgb(offset_1)=(0,0,0), rgb(offset_0)=(0,0,0)
	endif

	Display/K=1/N=single_var/W=(978,45,1373,253) var_0, var_1
	ModifyGraph rgb(var_0)=(3,52428,1)	

	if(NumDims==2)
		Display/K=1/N=single_mu_d2/W=(580,276,975,484) mu_0_d2, mu_1_d2
		ModifyGraph rgb(mu_0_d2)=(3,52428,1)	
		Display/K=1/N=single_var_d2/W=(978,276,1373,484) var_0_d2, var_1_d2
		ModifyGraph rgb(var_0_d2)=(3,52428,1)	
	endif

	SetDataFolder saveDFR
End






//plot emissions onto observables
Function plot_emi_obs([allEmi])
	variable allEmi

	SVAR HMM_inputPath = root:HMM_inputPath
	SVAR ENS_path = root:ENS_path
	
	DFREF saveDFR = GetDataFolderDFR()	
	variable i, j, wmax=0

//	string cList = "acontour;bcontour;ccontour;dcontour;econtour;fcontour;gcontour;"
	string winStr = UniqueName("obs_emi_2D_", 6, 0 )
	print winStr
	Display/K=1/N=$winStr

	//DF flexibility (allows pointing at renamed "HMM-folder")
	string currHmmPath = ENS_path
	if(!DataFolderExists(ENS_path))
		currHmmPath = ":"
	endif


	//get observable hist 2D
	SetDataFolder currHmmPath
	wave/Z obs2D
	if(!WaveExists(obs2D))
	
//		wave conc_acc = concat("r_g*")
//		wave conc_don = concat("o_g*")
		wave conc_acc = concat(StringFromList(1, dataID)+"*")
		wave conc_don = concat(StringFromList(0, dataID)+"*")

		MatrixOP/FREE/O meanSumObs = (sum(conc_acc)+sum(conc_don))/numRows(conc_acc)
		Make/O/N=2 wConsItot 
		SetScale/I x, 0, 1E4, wConsItot
		wConsItot = meanSumObs[0] -x

		//SetDataFolder currHmmPath
		fluo_hist2d(conc_don, conc_acc, "obs2D", 50, 50)	
		wave obs2D
	endif
//	obs2d/=wavemax(obs2D)	//normalize to max=1

	AppendImage/W=$winStr obs2D
	ModifyImage/W=$winStr obs2D ctab= {1,*,Grays,0}
	ModifyImage obs2D minRGB=NaN,maxRGB=0
	ModifyGraph/W=$winStr height={Aspect,1}
	

	//get emissions hist 2D
	NVAR n=NumStates	//dimSize(b_param, 2)
	NVAR d=NumDims		//dimSize(b_param, 0)
	SVAR strExcludeB
	string skipBList = strExcludeB
	skipBList = ReplaceString("_;", skipBList, ";")
	string bList = WaveList("b_x*_y*", ";", "" )
	bList = RemoveFromList(skipBList, bList)
	variable nTraces = ItemsInList(bList)
	
	
	//state dependent color (up to 5states)
	Make/O wRGB = {{65535,0,0}, {0,65535,0}, {0,0,65535}, {65535,0,65535}, {0,65535,65535}}

	for(i=0; i<n; i+=1)	//states
		//store tot. emissions & single_mu's
		duplicate/O obs2D $"totemi2D_"+num2str(i)/WAVE=totemi2D
		totemi2D=0
		Make/O/N=(nTraces,2) $"all_muXY_"+num2str(i)/WAVE=muXY

		for(j=0; j<nTraces; j+=1)	//traces
			wave b_param = $StringFromList(j,bList)	
			muXY[j][] = b_param[q][0][i]

			string sCurr = "emi2D_"+num2str(i)+"_"+num2str(j)
			duplicate/O obs2D $sCurr/WAVE=emi
			
			Multithread emi = plot_b(i, b_param, {x,y})
			WaveStats/M=1/Q emi
			if(V_numNans!=0)
				Continue
			endif
			totemi2D+=emi
	
			if(!ParamIsDefault(allEmi))
				AppendMatrixContour/W=$winStr emi
				ModifyContour/W=$winStr $sCurr update=0, labels=0, autoLevels= {*, *, 3 }
				ModifyContour/W=$winStr $sCurr rgbLines=(wRGB[0][i],wRGB[1][i],wRGB[2][i])
			endif
		endfor

		if(ParamIsDefault(allEmi))
			AppendMatrixContour/W=$winStr totemi2D
			ModifyContour/W=$winStr $NameOfWave(totemi2D) update=0, labels=0, autoLevels= {*, *, 3 }
			ModifyContour/W=$winStr $NameOfWave(totemi2D) rgbLines=(wRGB[0][i],wRGB[1][i],wRGB[2][i])
			
			AppendToGraph/W=$winStr muXY[][1] vs muXY[][0]
			ModifyGraph/W=$winStr rgb($NameOfWave(muXY))=(wRGB[0][i],wRGB[1][i],wRGB[2][i])
			ModifyGraph/W=$winStr mode($NameOfWave(muXY))=3
		endif
	endfor
//	totemi2D/=wavemax(totemi2D)
	
	
	//append constraint if available
	wave/Z wConsItot = $currHmmPath+"wConsItot"
	if(WaveExists(wConsItot))
		AppendToGraph wConsItot
	endif
	
	SetDataFolder saveDFR

End







// plot everything based on data segmentation (dwell-times).
// includes: FRETvsDT, DThist, TDP, transOcc
function getViterbiPlots()

	DFREF saveDFR = GetDataFolderDFR()
	SVAR ENS_path = root:ENS_path
	if(DataFolderExists(ENS_path))
		SetDataFolder ENS_path
	else
		print "getViterbiPlots(): proceeds in currDF."
	endif
	NVAR NumStates
	wave HMM_pi_ens, HMM_a_ens

	//remove record waves
	string list2kill = WaveList("w*record*", ";", "" )
	do
		string s = StringFromList(0, list2kill)
		KillWaves/Z $s
		if(WaveExists($s))
			SetDataFolder saveDFR
			Abort "getFRETvsDT(): Could not kill record waves!"
		endif
		list2kill = RemoveFromList(s, list2kill)
	while(ItemsInList(list2kill))
	Make/O/N=(NumStates, NumStates) transOcc=0, transOccCalc=0	
	

	//chop data into pieces: compute dwelltimes & average FRET/DT
	string wList = WaveList("HMM_x*_y*", ";", "" )
	variable i
	for(i=0;i<ItemsInList(wList);i+=1)
		wave currS = $StringFromList(i, wList)
		string strAssocSE = StringByKey("assocSEwaves", note(currS), "=", "\r")
		string strFret=StringFromList(0, strAssocSE)
		//	string strFret=StringFromList(1, StringByKey("HMMwaves", note(wS), "=", "\r"))

		wave/Z currFRET = ::FRET:SEtraces:$strFret
		if(!WaveExists(currFRET))
			wave/Z currFRET = :::FRET:SEtraces:$strFret		//second chance; if working in TbT DF
		endif
		
		if(!WaveExists(currFRET))
			wave/Z currFRET = ::::FRET:SEtraces:$strFret		//third chance; if working in TbT DF
		endif
		
		if (!WaveExists(currFRET))		//maybe this is imported data
			string strAssocSignal = StringByKey("AssociatedWaves", note(currS), "=", "\r")
			string strSignal=StringFromList(0, strAssocSignal)
			Wave/Z currFRET = ::$strSignal
		endif

		if(WaveExists(currFRET))
			getDataSegments(currS, currFRET)
		else
			getSegments(currS)		//if raw data is missing; TransOcc is inlcuded in calcFRETvsDT...
		endif		
	endfor


	//calc expected number of transitions: transOccCalc
	Duplicate/FREE HMM_pi_ens statPi
	Duplicate/FREE HMM_a_ens a_aux
	ENS_detBal(statPi, a_aux)	// calculates stationary pi of given A
	transOccCalc = statPi[q][0] * HMM_a_ens[q][p]	//y vs x...
	transOccCalc = (p==q)? 0 : transOccCalc
	MatrixOP/O transOccCalc = transOccCalc/sum(transOccCalc)*sum(transOcc)	//scale according to # of transitions found


	//get XYZ waves fro transOcc & transOccCalc
	fMatrixToXYZ("transOcc")
	Wave transOccX, transOccY, transOccZ
	Variable totalTransOcc = sum(transOccZ)
	Note transOccZ, "SumTrans=" + num2str(totalTransOcc)
	transOccZ = transOccZ[p] == 0 ? NaN : transOccZ[p]
	fMatrixToXYZ("transOccCalc")
	Wave transOccCalcX, transOccCalcY, transOccCalcZ
	transOccCalcZ = round(transOccCalcZ[p])
	Variable totalTransOccCalc = sum(transOccCalcZ)
	Note transOccCalcZ, "SumTrans=" + num2str(totalTransOccCalc)
	transOccCalcZ = transOccCalcZ[p] == 0 ? NaN : transOccCalcZ[p]


	//display transOcc, transOccCalc
	Display/K=1/N=transOccWin /W=(611,383,932,614)
	AppendImage transOcc
	ModifyImage transOcc ctab= {1,*,Rainbow,0},minRGB=NaN,log=1
	ModifyGraph mirror=2,nticks=2,manTick={0,1,0,0}//,manMinor={0,50}
	Appendtograph transOccY vs transOccX
	ModifyGraph mode=3,textMarker(transOccY)={transOccZ,"default",0,0,5,0.00,0.00}
	ModifyGraph rgb=(0,0,0)
	Label left "\\Z14State IN"
	Label bottom "\\Z14State OUT"
	ColorScale/C/N=text0/A=RC/E image=transOcc, log=1
	TextBox/C/N=text1/F=0/A=RT/X=10/Y=5/E=2 "transOcc"
	TextBox/C/N=text2/F=2/A=RB/X=5/Y=5/E=2 "#Trans\r"+num2str(totalTransOcc)
	
	Display/K=1/N=transOccCalcWin /W=(933,383,1254,614)
	AppendImage transOccCalc
	ModifyImage transOccCalc ctab= {1,*,Rainbow,0},minRGB=NaN,log=1
	ModifyGraph mirror=2,nticks=2,manTick={0,1,0,0}//,manMinor={0,50}
	Appendtograph transOccCalcY vs transOccCalcX
	ModifyGraph mode=3,textMarker(transOccCalcY)={transOccCalcZ,"default",0,0,5,0.00,0.00}
	ModifyGraph rgb=(0,0,0)
	Label left "\\Z14State IN"
	Label bottom "\\Z14State OUT"
	ColorScale/C/N=text0/A=RC/E image=transOccCalc, log=1
	TextBox/C/N=text1/F=0/A=RT/X=10/Y=5/E=2 "transOccCalc"
	TextBox/C/N=text2/F=2/A=RB/X=5/Y=5/E=2 "#Trans\r"+num2str(totalTransOccCalc)
	

	//display DT histograms
	Make/O wRGB = {{65535,0,0}, {0,65535,0}, {0,0,65535}, {65535,0,65535}, {0,65535,65535}, {65280,43520,0}}
	string winStr = "DThist"	//UniqueName("DThist", 6, 0)
	Display/K=1/N=$winStr
	TextBox/F=0/N=tau/B=1/A=RC
	for(i=0;i<NumStates;i+=1)
		wave wDT = $"wDTrecord"+num2str(i)

		//calc histograms
		variable currTau = calcDThist(wDT, mute=2)
		if(currTau!=0)		//if there were enough dwell times to fit
			string strHist = "wDThist"+num2str(i)
			string strCum = strHist+"Cum"
			string strFit = "fit_"+strCum

			//display
			AppendToGraph/W=$winStr $strCum
			ModifyGraph/W=$winStr rgb($strCum)=(wRGB[0][i],wRGB[1][i],wRGB[2][i])
			ModifyGraph/W=$winStr mode($strCum)=3,marker($strCum)=17
			AppendToGraph/W=$winStr $strFit
			ModifyGraph/W=$winStr rgb($strFit)=(0,0,0)
			AppendText/W=$winStr/N=tau "\s("+strCum+") tau"+num2str(i)+"="+num2str(currTau)

			AppendToGraph/W=$winStr/R $strHist
			ModifyGraph/W=$winStr rgb($strHist)=(wRGB[0][i],wRGB[1][i],wRGB[2][i])
			ModifyGraph/W=$winStr mode($strHist)=3, marker($strHist)=19
		endif
		
	endfor
	ModifyGraph/W=$winStr log(right)=1, msize=2, mirror(bottom)=1
	Label/W=$winStr left "\\Z14Int. Probability"
	Label/W=$winStr right "\\Z14Occurrence"
	Label/W=$winStr bottom "\\Z14dwell time [frames]"
	


	//stop if there are no FRET traces
	wave/Z wFretINrecord
	if(!WaveExists(wFretINrecord))
		SetDataFolder saveDFR
		Print "getViterbiPlots() No FRET traces found."
		Return 0
	endif


	//display FRETvsDT
	display/N=FRETvsDT
	for(i=0;i<NumStates;i+=1)
		wave wFRET = $"wFRETrecord"+num2str(i)
		wave wDT = $"wDTrecord"+num2str(i)
		AppendToGraph wFRET vs wDT
		ModifyGraph rgb($NameOfWave(wFRET))=(wRGB[0][i],wRGB[1][i],wRGB[2][i])
	endfor
	ModifyGraph mode=3, marker=8, log(bottom)=1, mirror=1
	SetAxis left -0.5,1.5
	Label left "\\Z14FRET E"
	Label bottom "\\Z14Dwell Time [frames]"
	
	//display fretIN vs fretOUT
	wave wFretINrecord, wFretOUTrecord, wtotSTATEinRecord
	Make/O/N=(5,3) stateColorWave
	stateColorWave[0][0]= {65535,0,0,65535,0}
	stateColorWave[0][1]= {0,65535,0,0,65535}
	stateColorWave[0][2]= {0,0,65535,65535,65535}
	Display /W=(938,45,1199,279)/N=fretInOut
	AppendToGraph wFretINrecord vs wFretOUTrecord
	ModifyGraph mode=3,marker=19,msize=1,mirror=2
	ModifyGraph zColor(wFretINrecord)={wtotSTATEinRecord,*,*,cindexRGB,0,stateColorWave}	
	Label left "\\Z14Initial FRET"
	Label bottom "\\Z14Final FRET"
	SetAxis left -0.5,1.5
	SetAxis bottom -0.5,1.5
	ModifyGraph height={Aspect,1}	
		
	//display fretIN vs fretOUT histogram
	Duplicate/O wFretINrecord wFret_Y
	Duplicate/O wFretOUTrecord wFret_X
	wFret_X = (wFRET_X<-1 || wFRET_X>2)? Nan : wFRET_X
	wFret_Y = (wFRET_Y<-1 || wFRET_Y>2)? Nan : wFRET_Y
	wFret_X = (numtype(wFRET_Y)==2)? Nan : wFRET_X
	wFret_Y = (numtype(wFRET_X)==2)? Nan : wFRET_Y
	WaveTransform/O zapNaNs  wFret_X						
	WaveTransform/O zapNaNs  wFret_Y						
	fluo_hist2d(wFret_X, wFret_Y, "tdp", 50, 50)
//	hist2d_maker(wFretOUTrecord, wFretINrecord, "tdp", 50, 50)	
	wave tdp
//	Display/N=TDPhist /W=(938,45,1199,279)
//	AppendImage tdp
//	ModifyImage tdp ctab= {1,*,Rainbow,1}, minRGB=NaN
//	ModifyGraph height={Aspect,1},mirror=2
//	Label left "\\Z14Initial FRET"
//	Label bottom "\\Z14Final FRET"
//	SetAxis left -0.5,1.5
//	SetAxis bottom -0.5,1.5
	
	//display in contours
//	Display/N=TDPcontour /W=(938,45,1199,279)
//	AppendMatrixContour tdp
//	ModifyContour tdp ctabLines={*,*,Rainbow,1}, labels=0
//	ModifyGraph height={Aspect,1},lSize=2,mirror=2
//	Label left "\\Z14Initial FRET"
//	Label bottom "\\Z14Final FRET"
//	SetAxis left -0.5,1.5
//	SetAxis bottom -0.5,1.5
	
	SetDataFolder saveDFR

End
	


Function getSegments(wS)
	wave wS			//"HMM_s" analogue

	Variable i = 0, startP = 0, dwell
	NVAR NumStates	
	wave transOcc, transOccCalc
	Make/WAVE/FREE refDT
	for(i=0;i<NumStates;i+=1)
		Make/N=0 $"wDT"+num2str(i)
		refDT[i] = $"wDT"+num2str(i)
	endfor
	
	i=0
	do
		if ( (wS[i] != wS[i+1]) && startP==0 )		//first transition, startP == 0	
			startP = i+1			
			transOcc[wS[i+1]][wS[i]] +=1					//y vs x...			
		elseif ( (wS[i] != wS[i+1]) && startP>0 )	//after first trans., start counting dwells, startP > 0
			dwell = i - startP +1			
			Wave currDT = refDT[wS[i]]
			InsertPoints 0, 1, currDT
			currDT[0] = dwell									//store dwelltime
			transOcc[wS[i+1]][wS[i]] +=1					//y vs x...			
			startP = i+1										//update startP
		endif
		
		i += 1
	while (i < dimSize(wS,0)-1)	

	
	//store
	for(i=0;i<NumStates;i+=1)
		Concatenate {refDT[i]}, $"wDTrecord"+num2str(i)
		KillWaves $"wDT"+num2str(i)
	endfor	
	
End



//extract mean FRET during each dwell time
Function getDataSegments(wS, wFRET)
	wave wS, wFRET		//"HMM_s" analogue
		
	NVAR NumStates	
	Variable i = 0, startP = 0, dwell
	Variable x1, x2, meanFRET
	wave transOcc, transOccCalc	
	
	Make/WAVE/FREE refDT, refFRET
	for(i=0;i<NumStates;i+=1)
		Make/N=0/O $"wDT"+num2str(i)
		refDT[i] = $"wDT"+num2str(i)
		Make/N=0/O $"wFRET"+num2str(i)
		refFRET[i]=$"wFRET"+num2str(i)
	endfor
	Make/FREE/N=0 fretIN, fretOUT, totSTATEin, totSTATEout	//, totDT
	
	i=0
	do
		if ( (wS[i] != wS[i+1]) && startP==0 )		//first transition		
			InsertPoints 0, 1, fretIN, totSTATEin, totSTATEout
			x1 = pnt2x(wFRET, 0)
			x2 = pnt2x(wFRET, i)
			fretIN[0] = sum(wFRET, x1, x2 )/(i+1)		//from start til transition
			totSTATEin[0] = wS[i]
			totSTATEout[0] = wS[i+1]
			transOcc[wS[i+1]][wS[i]] +=1					//y vs x...
	
			startP = i+1			
		elseif ( (wS[i] != wS[i+1]) && startP>0 )	//after first trans., start counting dwells, startP > 0
			dwell = i - startP +1
			x1 = pnt2x(wFRET, startP)
			x2 = pnt2x(wFRET, i)
			meanFRET = sum(wFRET, x1, x2 )/dwell	

			Wave currDT = refDT[wS[i]]
			Wave currFRET = refFRET[wS[i]]
			InsertPoints 0, 1, currDT, currFRET
			currDT[0] = dwell									//store dwelltime
			currFRET[0] = meanFRET							//store mean FRET of dwell
			
			InsertPoints 0, 1, fretIN, fretOUT, totSTATEin, totSTATEout	//totDT
//			totDT[0] = dwell
			totSTATEin[0] = wS[i]
			totSTATEout[0] = wS[i+1]
			fretOUT[0] = meanFRET
			fretIN[0] = meanFRET							//fretIN is one ahead			
			transOcc[wS[i+1]][wS[i]] +=1					//y vs x...
			
			startP = i+1										//update startP
		endif
		
		i += 1
	while (i < dimSize(wS,0)-1)	

	if(startP>0)												//termination if there was a transition
		dwell = i - startP +1
		x1 = pnt2x(wFRET, startP)
		x2 = pnt2x(wFRET, i)
		meanFRET = sum(wFRET, x1, x2 )/dwell	
		InsertPoints 0, 1, fretOUT						//fret value til the end
		fretOUT[0] = meanFRET
	endif	

	
	//store
	for(i=0;i<NumStates;i+=1)
		Concatenate {refDT[i]}, $"wDTrecord"+num2str(i)
		Concatenate {refFRET[i]}, $"wFRETrecord"+num2str(i)
	endfor
	Concatenate {fretIN}, $"wFretINrecord"
	Concatenate {fretOUT}, $"wFretOUTrecord"
//	Concatenate {totDT}, $"wtotDTrecord"
	Concatenate {totSTATEin}, $"wtotSTATEinRecord"
	Concatenate {totSTATEout}, $"wtotSTATEoutRecord"

End




//set NVAR frameTime > 0 to work in [seconds]; if not provided, time is in [frames]
Function calcDThist(wDT [, mute])	
	wave wDT							//contains dwell times
	variable mute					//if set!=2 -> no printing to history; if set ==2 -> no graphs
		
	variable numDT = numpnts(wDT)						//number of dwell times recieved
	if(numDT<3)
		Return 0
	endif
	
	variable DTmax = WaveMax(wDT)+1						//biggest dwell time found
	string histStr = ReplaceString("record", NameOfWave(wDT), "hist")
	string infoStr
	Make/O/N=(DTmax) $histStr, $histStr+"Cum"
	wave wHist = $histStr, wHistCum = $histStr+"Cum"
	if(ParamIsDefault(mute))
		print "n(DT)=", numpnts(wDT)
	endif
			
	//calc histograms
	Histogram/B=2 wDT, wHist	
	Histogram/B=2/P/CUM wDT, wHistCum	
	wHist = (wHist > 0)? wHist : NaN
	wHistCum = (numtype(wHist)==0)? wHistCum : NaN
	
		
	//display if not "mute"
	if(mute!=2)
		//DoWindow/K DTdistRAW_Plot
		Display/N=DThistRAW_Plot
		AppendToGraph/R/C=(0,0,0) wHist 
		AppendToGraph/L wHistCum
		ModifyGraph mode($histStr)=3,marker($histStr)=19,msize($histStr)=2
		ModifyGraph mode($histStr+"Cum")=3
		Label left, "\\Z18\\K(65535,0,0)Integrated Prob"
		Label right, "\\Z18Occurrence"
		Label bottom, "\\Z18 Time"
		SetAxis bottom 0,*
		ModifyGraph log(right)=1
	endif
	
	// calc. weighting wave
	string strWeight = ReplaceString("record", NameOfWave(wDT), "weight")
	duplicate/O wHist $strWeight/WAVE=wWeight
	wWeight = sqrt(wHist)

	//fit: dblexp_XOffset
	K0=1 	///TBOX=272
	//CurveFit/Q/W=2/L=(DTmax)/H="10000" /NTHR=0 dblexp_XOffset  wHistCum /D
	CurveFit/Q/W=2/L=(DTmax)/H="100" /NTHR=0 exp_XOffset  wHistCum /W=wWeight /D
	wave W_coef
		
	
	//build infoStr
	infoStr = "\r\ttau1 = " + num2str(W_coef[2]) + " frames"//\r\ttau2 = " + num2Str(W_coef[4]) + " frames"
//	infoStr = infoStr + "\r\tchi^2 = " + num2Str(V_chisq) + "\r\tn(dt)  = " + num2Str(numDT) + "\r\tn(traces) = "+num2Str(evaCount)
	if(mute!=2)
		Textbox/F=0/B=1/A=RC "\f01ExpFit: "+histStr+"\f00"+infoStr		//transparent: /B=1
		ModifyGraph rgb($"#2")=(0,0,0)		
	endif
			
	if(ParamIsDefault(mute))
		print "RAW "+histStr+infoStr
	endif
	
	Return W_coef[2]	//i.e.: tau
End



// adapted from include <MatrixToXYZ>
// MatrixToXYZ converts a 2-D matrix of Z values into three waves containing X, Y, and Z values
// that spans the min and max X and Y.
// The output waves are named by appending "X", "Y", and "Z" to the given basename.
static Function fMatrixToXYZ(mat)
	String mat
	String base=mat

	if( WaveDims($mat) != 2)
		Abort mat+" is not a two-dimensional wave!"
	endif
	
	// Determine full X and Y Ranges
	Variable rows=DimSize($mat,0)
	Variable cols=DimSize($mat,1)
	Variable xmin,ymin,dx,dy
	xmin=DimOffset($mat,0)
	dx=DimDelta($mat,0)
	ymin=DimOffset($mat,1)
	dy=DimDelta($mat,1)
	
	// Make X, Y, and Z waves
	String sx=base+"X"
	String sy=base+"Y"
	String sz=base+"Z"
	Make/O/N=(rows*cols) $sx,$sy,$sz
	Wave wx=$sx, wy=$sy, wz=$sz, wmat=$mat
	wx= xmin + dx * mod(p,rows)		// X varies quickly
	wy= ymin + dy * floor(p/rows)		// Y varies slowly
	wz= wmat(wx[p])(wy[p])
End







//############################
//# Further Stuff 
//############################



Function Results(setName) 
	string setName
	
	SVAR ENS_path = root:ENS_path
	DFREF saveDFR = GetDataFolderDFR()
	SetDataFolder ENS_path

	NVAR NumStates
	string strDF = GetDataFolder(0)
	string layoutStr = setName+"_"+ReplaceString("HMM_", strDF, "")
	String titleStr = layoutStr
	if ( strlen(layoutStr)>30 || CheckName(layoutStr, 8)!=0 )
		//Abort "layoutStr too long\r\r" + layoutStr + "\rnumber of characters " + num2str(strlen(layoutStr))
		layoutStr = "x" + layoutStr[strlen(layoutStr)-28, strlen(layoutStr)-1]
		layoutStr = UniqueName(layoutStr, 8, 0)
	endif
	
	Variable oldPrefState
	Preferences 1; // Turn preferences on and
	oldPrefState = V_Flag // save the old state.
	
	NewLayout/N=$layoutStr/W=(754,45,1421,959) as layoutStr
	ModifyLayout mag=1, units=2
	TextBox/C/N=text0/F=0/B=1/A=LB/X=36.09/Y=96.03 "\\Z24\\f01"+titleStr
	TextBox/C/N=text1/F=0/B=1/A=LB/X=36.09/Y=51.34 "\\Z18Viterbi-Plots:"
	TextBox/C/N=text2/F=0/B=1/A=LB/X=36.09/Y=90.27 "\\Z18HMM Params:"
	
	Preferences oldPrefState // Restore old prefs state.
	
	getViterbiPlots()
	//transOcc:
	AppendLayoutObject/F=0/R=(20,568,215,683)/W=$layoutStr graph transOccWin			

	//transOccCalc:
	AppendLayoutObject/F=0/R=(20,684,215,799)/W=$layoutStr graph transOccCalcWin			

	//FRETvsDT:
	AppendLayoutObject/F=0/R=(216,618,574,799)/W=$layoutStr graph FRETvsDT 			

	//DThist
	AppendLayoutObject/F=0/R=(216,448,574,617)/W=$layoutStr graph DThist			

	//tdp:
	AppendLayoutObject/F=0/R=(21,400,215,566)/W=$layoutStr graph fretInOut	//TDPcontour 			
	
	//Model:
	ENS_drawModel()
	AppendLayoutObject/F=0/R=(-3,80,245,305)/W=$layoutStr graph Model			

	//log_A
	ENS_paramLog()
	AppendLayoutObject/F=0/R=(350,127,577,259)/W=$layoutStr graph A_paramLog			
	
	//dispA
	dispA()	
	AppendLayoutObject/F=0/R=(221,119,383,264)/W=$layoutStr graph A_win			
	
	//pi, A, ...
	wave HMM_a_ens,HMM_pi_ens,HMM_pi_stat
	Edit/N=kinParams/W=(272,306,777,513) HMM_a_ens,HMM_pi_ens,HMM_pi_stat
	ModifyTable format(Point)=1,width(Point)=20,width(HMM_a_ens)=72,width(HMM_pi_ens)=70
	ModifyTable width(HMM_pi_stat)=70
	ModifyTable showParts=0xFE
	AppendLayoutObject/F=0/R=(18,260,552,352)/W=$layoutStr table kinParams			



	//state occupation:
	wave countStateOcc
	duplicate/O countStateOcc stateOccLine
	redimension/N=(1,NumStates) stateoccLine
	Edit/N=Occ  stateOccLine
	ModifyTable format(Point)=1,width(Point)=24,width(stateOccLine)=46
	ModifyTable showParts=0x74
	AppendLayoutObject/F=0/R=(220,409,488,441)/W=$layoutStr table Occ			


	Dowindow/F $layoutStr
	SetDataFolder saveDFR
	
End




function dispA()
	DFREF saveDFR = GetDataFolderDFR()
	SVAR ENS_path = root:ENS_path
	if(DataFolderExists(ENS_path))
		SetDataFolder ENS_path
	else
		print "dispA(): proceeds in currDF."
	endif

	wave HMM_a_ens	
	display/N=A_win
	AppendImage HMM_a_ens
	ModifyImage HMM_a_ens log=1;DelayUpdate
	ModifyImage HMM_a_ens minRGB=NaN,maxRGB=(0,0,0)
	ModifyImage HMM_a_ens ctab= {1e-7,0.5,Rainbow,0}
	ModifyGraph height={Aspect,1}
//	TextBox/C/N=text0/F=0/B=0/A=RC/X=92.79/Y=-58.62/E=0 "\\Z14"+GetDataFolder(0)

	SetDataFolder saveDFR
end




function checkDbal()


	NVAR NumStates
	wave a = HMM_a_ens
	wave p_ = HMM_pi_stat

	variable deltaG
	
	duplicate/O a a1, a2, diff, lnBigK

	//calc fluxes
	a1 = p_[p][0]*a[p][q]
	a2 = p_[q][0]*a[q][p]	
	diff = a1[p][q] - a2[p][q]
	MatrixOP/O sumFluxes = sum(abs(diff))/2
	
	print GetDataFolder(1)
	print "sum(fluxes) =",sumFluxes[0]
	
	//calc deltaG	
	lnBigK = ln(a[p][q]/a[q][p])
//	lnBigK = (p>q)? lnBigK : 0
	lnBigK = (numtype(lnBigK)==2)? 0 : lnBigK
	if(NumStates==2)
		deltaG = - lnBigK[1][1]
		print "deltaG =", deltaG, "kT"
	elseif(NumStates==3)
//		deltaG = lnBigK[1][0]+lnBigK[2][1]-lnBigK[2][0]
		deltaG = -(lnBigK[1][0]+lnBigK[2][1]+lnBigK[0][2])
		print "deltaG(cycle) =", deltaG, "kT"
	elseif(NumStates==4)
//		deltaG = lnBigK[1][0]+lnBigK[2][1]+lnBigK[3][2]-lnBigK[3][0]
		deltaG = -(lnBigK[1][0]+lnBigK[2][1]+lnBigK[3][2]+lnBigK[0][3])
		print "deltaG(main cycle) =", deltaG, "kT"
	endif
	
End


//if something went wrong during calculation
// in :HMM...
function postCorrIC([cont, dbal, consItot])
	variable cont, dbal, consItot
	
//	NVAR NumStates, NumDims, NumSymb
	NVAR logP_FB, vBIC, vAIC, vAICc
	wave log_logP_FB, log_BIC, log_AIC, log_AICc

	variable i
	for(i=0; i<numpnts(log_logP_FB); i+=1)
	
		logP_FB = log_logP_FB[i]
		ENS_calcBIC()//dbal=dbal)//, consItot=consItot)
		
		log_BIC[i] = vBIC
//		log_AIC[i] = vAIC
//		log_AICc[i] = vAICc	
	endfor

	ENS_calcBIC()//verbose=1, cont=cont, dbal=dbal, consItot=consItot)
end




function dispBIC()

	variable i=0, j=0
	Make/O/D wLogs=Nan, deltaBIC=Nan
	Make/O/T wLogNames=""
	Make/O/N=(3,4) wRGB = {{65535,0,0}, {0,65535,0}, {0,0,65535}, {65535,0,65535}, {0,65535,65535}}
	
	Display/N=BICplot/K=1
	do
		string currDF = GetIndexedObjName("", 4, i )
		if(!cmpStr(currDF, ""))
			print i
			Break
		endif
//		if(!StringMatch(currDF, "HMM_*sB*") || StringMatch(currDF, "*sub*"))
		if(!StringMatch(currDF, "ENS_*") )//|| StringMatch(currDF, "*sub*"))
			i+=1
			Continue
		endif
		
		wave currLog = $":"+currDF+":log_BIC" 
		wLogs[j] = currLog[dimSize(currLog,0)-1]

		NVAR NumStates = $":"+currDF+":NumStates" 
		wLogNames[j] = num2str(NumStates)	//currDF[4,inf]

		wave HMM_a_start = $":"+currDF+":HMM_a_start"
		FindValue/V=0 HMM_a_start
		if(V_value!=-1)	//if non-canonical model
			wLogNames[j]+="*"
		endif 

		AppendToGraph currLog
		ModifyGraph rgb($"#"+num2str(j))=(wRGB[0][NumStates-2],wRGB[1][NumStates-2],wRGB[2][NumStates-2])


		i+=1
		j+=1
	while(1)
	ModifyGraph mirror=2
	Label left "\\Z18BIC"
	Label bottom "\\Z18Iterations"
	
	WaveTransform/O zapNans wLogs
	Redimension/N=(dimSize(wLogs, 0)) wLogNames
	Duplicate/O wLogs deltaBIC, dummy

	deltaBIC -= wavemin(wLogs)
	dummy = p 

	Display/T/K=1 deltaBIC
	ModifyGraph mode=8,marker=19,msize=3,lsize=1
	ModifyGraph userticks(top)={dummy,wLogNames},standoff(top)=0
	ModifyGraph gbRGB=(56797,56797,56797)
	ModifyGraph width=85.0394
	//ModifyGraph mode=1, lSize=10,hbFill=2
	//ModifyGraph useBarStrokeRGB=1, barStrokeRGB=(65535,0,0)
	ModifyGraph mirror=2
	ModifyGraph fSize(top)=14//, tkLblRot(top)=70
	Label left "\\Z18dBIC"
	Label top "\\Z18States"
	SetAxis/A/R left
	
end





//generate random start params
//call for existing setup
function randomStart()

	SVAR ENS_path = root:ENS_path
	string saveDF = GetDataFolder(1)
	SetDataFolder ENS_path	
	
	wave HMM_pi_start, HMM_a_start
	
	HMM_pi_start = abs(enoise(1))
	MatrixOP/O HMM_pi_start = HMM_pi_start/sum(HMM_pi_start)	

	HMM_a_start =  abs(enoise(1))
	MatrixOP/O normRows = sumRows(HMM_a_start)
	HMM_a_start /= normRows[p]
	
	SetDataFolder saveDF
	BtnLoadEns("")		//"Initialize"
end



//optimize on randomly picked subset
//call for existing setup
//attention: removes at least one trace from data set, even if SubSetFactor=1
Function randomSubset(SubSetFactor)
	Variable SubSetFactor		//e.g. 2/3; 
	

	SVAR ENS_path = root:ENS_path
	string saveDF = GetDataFolder(1)
	SetDataFolder ENS_path	

	
	Wave wInputRef
	Variable nTraces = dimSize(wInputRef, 0)
	Variable SubSetSize = nTraces*SubSetFactor
	
	do
		Variable removeThis = abs(round(enoise(nTraces)))
		DeletePoints/M=0 removeThis, 1, wInputRef
	while(dimSize(wInputRef, 0) > SubSetSize)

	SetDataFolder saveDF
End




Function ColorizeMe()

	variable i, minStates=2, maxStates=6	
	Make/O/N=(3,4) wRGB = {{65535,0,0}, {0,65535,0}, {0,0,65535}, {65535,0,65535}, {0,65535,65535}}
	
	for(i=minStates; i<=maxStates; i+=1)
		string traceName = StringFromList(i-minStates, TraceNameList("", ";", 1))
		ModifyGraph rgb($traceName)=(wRGB[0][i-minStates],wRGB[1][i-minStates],wRGB[2][i-minStates])
	endfor	

End





function fluo_hist2d(origX, origY, histName, numBinsX, numBinsY)	//,dimX, dimY)
	wave origX, origY
	string histName
	variable numBinsX, numBinsY
		
	duplicate/O origX waveX
	duplicate/O origY waveY
	
	//Check if lengths of waves fit together.
	if (numpnts(waveX)!=numpnts(waveY)) 
		Abort "hist2d() : numpnts("+NameOfWave(origX)+") NOT equal numpnts("+NameOfWave(origY)+") !"	
	endif		
	
	//define histogram limits, bins, ...
	variable VstartX = wavemin(waveX)
	variable VendX = wavemax(waveX)
	variable VstartY = wavemin(waveY)
	variable VendY = wavemax(waveY)
	variable binsizeX= (VendX-VstartX)/(numBinsX-1)		//include start & end point
	variable binsizeY= (VendY-VstartY)/(numBinsY-1)	

	//set outliers to NaN and kill points that are NaNs
//	waveX = (waveX>Vstart && waveX<Vend && waveY>Vstart && waveY<Vend) ? waveX : NaN		
//	waveY = (waveX>Vstart && waveX<Vend && waveY>Vstart && waveY<Vend) ? waveY : NaN		
//	WaveTransform/O zapNaNs  waveX						
//	WaveTransform/O zapNaNs  waveY						
	
	//fill 2dHistograms with XYpairs
	make/O/N=(numBinsX,numBinsY) $histName = 0
	wave hist2d = $histName

	variable i
	for(i=0;i<numpnts(waveX);i+=1)
		variable currX = waveX[i]
		variable currY = waveY[i]
		variable binnumX= floor((currX-VstartX)/binsizeX)		//corresponding bin number
		variable binnumY= floor((currY-VstartY)/binsizeY)
		variable currVal=hist2d[binnumX][binnumY]
		hist2d[binnumX][binnumY]+=1
	endfor
	print "hist2d() i = "+num2str(i)
//	SetScale/I x, VstartX, VendX, hist2d						//scale accordingly
//	SetScale/I y, VstartY, VendY, hist2d	
	SetScale/P x, VstartX+binsizeX/2, binsizeX, hist2d						//scale accordingly  
	SetScale/P y, VstartY+binsizeY/2, binsizeY, hist2d	

	//sum up 1d projections
	imagetransform sumallrows hist2d			//get total 1dHist 
	imagetransform sumallcols hist2d			//no NaNs allowed!!!
	Duplicate/O $"W_sumrows" $(histName+"_X")	//keep copy for display
	Duplicate/O $"W_sumcols" $(histName+"_Y")
	SetScale/P x, DimOffset(hist2d, 0), DimDelta(hist2d,0), $(histName+"_X")
	SetScale/P x, DimOffset(hist2d, 1), DimDelta(hist2d,1), $(histName+"_Y")

	//kill temp waves
	Killwaves waveX, waveY									
	
end






//works from current data folder which has to be an HMM folder
Function loop_getCI()
	
	SVAR ENS_path = root:ENS_path
	string saveDF = GetDataFolder(1)
	SetDataFolder ENS_path
	NewDataFolder/O ::CIwork			//temp working DF
	NewDataFolder/O ::CIresult		//holding temp results

	
	Variable timerRefNum = startMSTimer			//debug
	Variable V_return
	Wave HMM_a_ens
	
	Variable i, j
	for (i=0; i<DimSize(HMM_a_ens,0); i+=1)
		for (j=0; j<DimSize(HMM_a_ens,1); j+=1)
			if (i==j || HMM_a_ens[i][j] == 0)		//omit rates that are 0
				continue
			endif
			Print "####################"
			Print "i=",i,"j=",j
//			V_return = getCI(i, j, 3, datapnts=3)		//debug version only
			V_return = getCI(i, j, 3, datapnts=111)
			if (V_return == 1)				//if relRange was too small, try larger one
				getCI(i, j, 500, datapnts=111)
			endif
		endfor
	endfor	
	Print "loop_getCI():", stopMSTimer(timerRefNum) / 6e7, "min passed (timer " + num2str(timerRefNum) +  ")"
	
	
	///finalize: CIresult gets stored in CI_ENS_*
	KillDataFolder ::CIwork
	NewDataFolder/S ::$("CI_"+GetDataFolder(0))
	MoveDataFolder ::CIresult, :
	SetDataFolder CIresult 
	Duplicate HMM_a_ens $"HMM_a_ens"
	string preStr = ParseFilePath(0, ENS_path, ":", 1, 0)		//provide ENS DF as prefix for results waves
	reportCI(preStr)		


	//plot
	cd ::
	CI_plot(preStr)

	SetDataFolder saveDF

End



///start in ENS
//get confidence interval based on dependance of
//production probability from parameter of ensHMM
//works from current data folder which has to be an HMM folder
Function getCI(HMM_ax, HMM_ay, relRange, [datapnts])
	Variable HMM_ax, HMM_ay	// row, col position of rate in HMM_a that is to be sampled
	Variable relRange			// expect to be from interval ]1;inf[; sample around [MLE/relRange; MLE*relRange]
	Variable datapnts			// more data pnts -> finer sampling but more time needed
	
	//set optional parameters
	datapnts	= (ParamIsDefault(datapnts)) ? 31 : datapnts		//31 data pnts should be reasonable with relRange of 2

	Variable timerRefNum = startMSTimer			//debug
		
	
	//get paths and DF
	SVAR ENS_path = root:ENS_path	
	

	//get working directory
	KillDataFolder/Z ::CIwork
	DuplicateDataFolder $ENS_path, ::CIwork
	SetDataFolder ::CIwork
	
	//work from curr DF & keep ENS_path unaffected:
	String ENS_path_backup = ENS_path
	ENS_path = GetDataFolder(1)
	
	
	//get copy of HMM_a_ens as backup, this should also be the MLE
	//(HMM_a_ens will get duplicated to HMM_a later on)
	//also get logP_FB of the MLE
	NVAR logP_FB
	Wave HMM_a_ens
	Duplicate /O HMM_a_ens, HMM_a_ens_MLE
	Variable MLE = HMM_a_ens_MLE[HMM_ax][HMM_ay]
	Variable logP_FB_MLE = logP_FB
	
	
	//try to rescue a logP_FB==0 (this seems to occur sometimes)
	if (logP_FB_MLE == 0)
		Print "Global variable logP_FB was zero. Trying to use log_logP_FB."
		Wave log_logP_FB	
		logP_FB_MLE = log_logP_FB[DimSize(log_logP_FB,0)-1]
	endif
	
	
	//1D sampling only
	String strID = num2str(HMM_ax) + "_" + num2str(HMM_ay) + "_range" + num2str(relRange) + "_pnts" + num2str(datapnts)
	Make /D /O /N=(datapnts) $("logP_FB_" + strID), $("xlogP_FB_" + strID)
	Wave wRange = $("logP_FB_" + strID)
	Wave wxRange = $("xlogP_FB_" + strID)
	wxRange = MLE*10^( log(1/relRange) + p*2*log(relRange)/(datapnts-1) )		
	//SetScale /P x, (1-relRange)*MLE, 2*relRange*MLE/(numpnts(wRange)-1), wRange
	wRange = getCI_Helper(wxRange[p], HMM_ax, HMM_ay)		//getCI_Helper returns log naturalis of ProdProb_FB
	
	
	//likelyhood ratio
	//renorm to ProdProb_FB of MLE and ln instead of log_10 and factor of 2 in order to directly compare with Chi^2
	Duplicate wRange, $("LR_" + strID)/WAVE=wLR
	Note wLR, "LR = 2*( ln(p(data|model_MLE)) - ln(p(data|model)) )"
	wLR = 2*( logP_FB_MLE - wRange )
	//wLR *= 2*ln(10)					//logP_FB is log naturalis in SMACKS world
	
	
	//manage return code; FindLevels for bounds of CI
	Variable Chi2_Cutoff = 3.841		//Chi^2(0.95, df=1)=3.841; Chi^2(0.95, df=2)=5.991 when doing 2D sampling
	Variable V_return = 0				//0->everything is fine, 1->try larger relRange, 2->fail
	
	Make /O/N=2 wCI=0
	
	if (WaveMax(wLR) < 0.01)
		//this is probably due to a very small rate mapping no transitions at all
		Print "getCI. Rate is probably insignificant for HMM."
		V_return = 2
	elseif (wLR[0]<Chi2_Cutoff || wLR[numpnts(wLR)-1]<Chi2_Cutoff)
		Print "getCI. Border of sampled range does not exceed Chi2_Cutoff", Chi2_Cutoff
		Print "LR borders", wLR[0], wLR[1], "...", wLR[numpnts(wLR)-2], wLR[numpnts(wLR)-1]
		V_return = 1
	else
		FindLevels /Q /D=wCI wLR, Chi2_Cutoff
	endif
	
	
	//translate row number to rate
	if (V_return == 0)
		wCI = wxRange[wCI[p]]
	else
		wCI = 0
	endif
	
	
	Print "MLE", MLE, "wCI= {", wCI[0], wCI[1], "}"//", sampled with DimDelta", DimDelta(wLR, 0)	
	Print "sec passed:", stopMSTimer(timerRefNum) / 1e6, "(timer " + num2str(timerRefNum) +  ")"
	
	
	
	//Duplicate waves to result folder
	Duplicate /O wCI, $("wCI_" + strID)/WAVE=wCI
	Duplicate /O wRange, ::CIresult:$(NameOfWave(wRange))
	Duplicate /O wxRange, ::CIresult:$(NameOfWave(wxRange))
	Duplicate /O wLR, ::CIresult:$(NameOfWave(wLR))
	Duplicate /O wCI, ::CIresult:$(NameOfWave(wCI))
	
	
	//clean up
	ENS_path = ENS_path_backup
	SetDataFolder ENS_path		//saveDFR	
	KillDataFolder /Z CIwork
	
	
	//and done...
	return V_return
End



Function getCI_Helper(x, HMM_ax, HMM_ay)
	Variable x						// is iterated over range
	Variable HMM_ax, HMM_ay		// row, col position of rate in HMM_a that is to be sampled
	
	
	Wave HMM_a_ens, HMM_a_ens_MLE, collect_logP_FB
	
//	Print time(), x, y
//	Wave logP_FB_region
//	WaveStats /Q /M=1 logP_FB_region
//	if (!mod(V_numNaNs,50))
//		Print time(), V_numNaNs
//	endif
	
	
	//HMM_a_ens gets copied to HMM_a by ENS_Params() in ENS_iterate_MThread later on
	HMM_a_ens = HMM_a_ens_MLE		//just to be safe
	HMM_a_ens[HMM_ax][HMM_ay] = x
	HMM_a_ens[HMM_ax][HMM_ax] = 0
	MatrixOP /FREE /O M_Sum = sumRows(HMM_a_ens)
	HMM_a_ens[HMM_ax][HMM_ax] = 1 - M_Sum[HMM_ax][0]
	
	ENS_iterate_MThread(skipBW=1)//ToDo: consItot??? -> ignore since only FB for now
//	ENS_iterate_MThread_gB(cont, skipBW=1)		//actually non-globalB version works nevertheless, 3D-PF mod
	
	
	MatrixOP /FREE /O aux = sum(collect_logP_FB)
	Variable logP_FB_local = aux[0]
	
	
	return logP_FB_local
End



Function getCI_Helper_Reestimate(x, HMM_ax, HMM_ay)
	Variable x						// is iterated over range
	Variable HMM_ax, HMM_ay		// row, col position of rate in HMM_a that is to be sampled
	
	
	Wave HMM_a_ens, HMM_a_ens_MLE, collect_logP_FB
	
//	Print time(), x, y
//	Wave logP_FB_region
//	WaveStats /Q /M=1 logP_FB_region
//	if (!mod(V_numNaNs,50))
//		Print time(), V_numNaNs
//	endif
	
	
	//HMM_a_ens gets copied to HMM_a by ENS_Params() in ENS_iterate_MThread later on
	HMM_a_ens = HMM_a_ens_MLE		//just to be safe
	
	
	Variable logP_FB_prev = 0
	Variable i = 0
	do
		//force HMM_a to test value before ENS_iterate_MThread -> logP_FB is with this values, stored in collect_logP_FB, get summed up in ENS_opt()
		HMM_a_ens[HMM_ax][HMM_ay] = x
		HMM_a_ens[HMM_ax][HMM_ax] = 0
		MatrixOP /FREE /O M_Sum = sumRows(HMM_a_ens)
		HMM_a_ens[HMM_ax][HMM_ax] = 1 - M_Sum[HMM_ax][0]
	
		ENS_iterate_MThread(skipBW=0)//ToDo: consItot??? -> ignore since only FB for now
		ENS_opt()		//no parameters anymore, global variable vDbal instead //ENS_opt(0)	//ENS_opt(dbal)
		
		//now the logP_FB of forced values should be in NVAR logP_FB
		NVAR logP_FB
		if ( abs(logP_FB-logP_FB_prev)<2e-3 )		//delta of 2e-3 in logP_FB -> delta of 0.01 in LR
			break
		endif
		
		logP_FB_prev = logP_FB
		i += 1
	while (1)
	
	
	Variable logP_FB_local
	MatrixOP /FREE /O aux = sum(collect_logP_FB)
	logP_FB_local = aux[0]
	
	Print logP_FB, logP_FB_local
	return logP_FB_local
	
End



//*_CIresult folder as curr data folder!
/// CIresult is @ "ENS_path":CI:CIresult
Function reportCI(preStr)
	String preStr


	Wave HMM_a_ens
	String wList = WaveList("wCI_*", ";", "")	
	String strDF
	Variable V_last
	
	
	///make result waves in CI_ENS_*
	Make /O /T /N=0 ::$(preStr + "_cat") /WAVE=cat
	Make /O /D /N=0 ::$(preStr + "_MLE") /WAVE=MLE
	Make /O /D /N=0 ::$(preStr + "_CIm") /WAVE=CIm
	Make /O /D /N=0 ::$(preStr + "_CIp") /WAVE=CIp

	
	Print "from", "to", "MLE", "relCI", "relCI"
	Variable i, j
	for (i=0; i<DimSize(HMM_a_ens,0); i+=1)
		for (j=0; j<DimSize(HMM_a_ens,1); j+=1)
			if (i!=j)
//				if (HMM_a_ens[i][j] == 0)		//special treat rates that are 0
//					Redimension /N=(numpnts(cat)+1) cat, MLE, CIm, CIp
//					V_last = numpnts(cat)-1
//					cat[V_last] = num2str(i) + num2str(j)
//					MLE[V_last] = HMM_a_ens[i][j]
//					CIm[V_last] = NaN
//					CIp[V_last] = NaN
//					Print i, j, HMM_a_ens[i][j], "NaN", "NaN"
//					continue
//				endif
				//get wCI with highest numpnts
				String currWCI = ListMatch(wList, "wCI_" + num2str(i) + "_" + num2str(j) + "*")
				Wave /Z wCI = $StringFromList(ItemsInList(currWCI)-1, currWCI)
				Redimension /N=(numpnts(cat)+1) cat, MLE, CIm, CIp
				V_last = numpnts(cat)-1
				//cat[V_last] = num2str(i) + "->" + num2str(j)
				cat[V_last] = num2str(i) + num2str(j)
				if (WaveExists(wCI))
					MLE[V_last] = HMM_a_ens[i][j]
				else
					MLE[V_last] = NaN
				endif
				if (WaveExists(wCI) && wCI[0] != 0)
					CIm[V_last] = abs(wCI[0] - HMM_a_ens[i][j])
					CIp[V_last] = abs(wCI[1] - HMM_a_ens[i][j])
				else
					CIm[V_last] = NaN
					CIp[V_last] = NaN
				endif
				//Print i, j, HMM_a_ens[i][j], 100*(wCI[0]-HMM_a_ens[i][j])/HMM_a_ens[i][j], "%", 100*(wCI[1]-HMM_a_ens[i][j])/HMM_a_ens[i][j], "%"
				Print i, j, HMM_a_ens[i][j], -1*(CIm[V_last])/HMM_a_ens[i][j], 1*(CIp[V_last])/HMM_a_ens[i][j]
			endif
		endfor
	endfor
End



//plot all rates with CI, expects to be in CI folder
Function CI_plot(strExp)
	String strExp			//string that preceeds *_MLE, *_cat, etc
		
	Wave MLE = $(strExp+"_MLE")
	Wave cat = $(strExp+"_cat")
	Wave CIp = $(strExp+"_CIp")
	Wave CIm = $(strExp+"_CIm")
	
	
	Make /O /N=(DimSize(cat,0)) dummy = p	
	Display /W=(243,46.25,564,239.75) /NCAT $(strExp+"_MLE"),$(strExp+"_MLE") vs $(strExp+"_cat")
	ModifyGraph userticks(bottom)={dummy,cat}
	
	ModifyGraph mode($(strExp+"_MLE"))=1,mode($(strExp+"_MLE#1"))=3
	ModifyGraph fSize=12
	ModifyGraph tkLblRot(bottom)=90
	ModifyGraph lSize=9
	ModifyGraph rgb($(strExp+"_MLE#1"))=(0,0,0)
	ModifyGraph mirror=2
	ModifyGraph axThick=2
	ModifyGraph tick(bottom)=4
	ModifyGraph offset={0.5,0}
	ModifyGraph axOffset(bottom)=0.5
	ModifyGraph axOffset(left)=-0.5
	ModifyGraph lowTrip(left)=0.01
	SetAxis bottom 0.5, DimSize(cat,0)-0.5
//	SetAxis left 0,0.1
	Label left "\\Z14Probability"
	Label bottom "\\Z14Transition"
	ErrorBars $(strExp+"_MLE#1") Y,wave=($(strExp+"_CIp"),$(strExp+"_CIm"))
	ModifyGraph marker($(strExp+"_MLE#1"))=9
	//SetWindow kwTopWin,hook(MyPasteHook)=PasteTraceWindowHook
	
		
	TextBox/C/N=text0/F=0/A=RT strExp+"\r"+IgorInfo(1)
	
	//report values
	Edit/W=(568,45,1014,243) cat,MLE,CIp,CIm
	
//	SetDataFolder saveDFR
End



//get mean and sdev for collection of *_MLE waves copied to current data folder
Function mean_sdev_MLE()
	String listMLE = WaveList("*_MLE*", ";", "")
	Wave anyW = $StringFromList(0, listMLE)
	
	Duplicate/O anyW, $"meanMLE" /WAVE=meanW
	Duplicate/O anyW, $"sdevMLE" /WAVE=sdevW
	Duplicate/O anyW, $"sdevMLE_rel" /WAVE=sdevWrel
	
	meanW = 0
	sdevW = 0
	sdevWrel = 0
	
	Variable i
	for (i=0; i<ItemsInList(listMLE); i+=1)
		Wave currW = $StringFromList(i, listMLE)
		meanW += currW
	endfor
	meanW /= ItemsInList(listMLE)
	
	for (i=0; i<ItemsInList(listMLE); i+=1)
		Wave currW = $StringFromList(i, listMLE)
		sdevW += (currW - meanW)^2
	endfor
	sdevW = sqrt(sdevW[p][q]/(ItemsInList(listMLE)-1))
	
	sdevWrel = sdevW / meanW
	
	edit meanW, sdevW, sdevWrel
End



//plot meanMLE & sdevMLE calculated with mean_sdev_MLE()
Function plot_meanMLE()
	Wave meanMLE// = $(strExp+"_MLE")
	Wave sdevMLE
	Wave /Z cat// = $(strExp+"_cat")
	
	if (!WaveExists(cat))
		Abort "Wave cat is missing."
	endif
	
	
	Make /O /N=(DimSize(cat,0)) dummy = p
	
	//PauseUpdate; Silent 1		// building window...
	Display /NCAT meanMLE,meanMLE vs cat
	
	ModifyGraph userticks(bottom)={dummy,cat}
	
	ModifyGraph mode(''#0)=1,mode(''#1)=3
	ModifyGraph lSize=10
	ModifyGraph rgb(''#1)=(0,0,0)
	ModifyGraph mirror=2
	ModifyGraph axThick=2
	ModifyGraph tick(bottom)=4
	ModifyGraph offset={0.5,0}
	SetAxis bottom 0, DimSize(cat,0)
	Label left "\\Z18Probability"
	Label bottom "\\Z18Transition"
	SetAxis left 0,0.1
	ErrorBars ''#1 Y,wave=(sdevMLE,sdevMLE)
	ModifyGraph marker(''#1)=9
	//SetWindow kwTopWin,hook(MyPasteHook)=PasteTraceWindowHook
	
	TextBox/C/N=text0/F=0/A=RT "mean & sdev from 3 fits"+"\r"+IgorInfo(1)
End
