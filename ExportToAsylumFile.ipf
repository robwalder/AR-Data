#pragma rtGlobals=3		// Use modern global access method and strict wave access.
/// Here are the functions to export force ramps to external files.  

Function SaveFRListToFile(FRListName)
	String FRListName
	Wave/T SavedFRLists=root:MyForceData:SavedFRLists
	
	SaveForceRamps(SavedFRLists[%$FRListName])
End

Function SaveForceRamps(FRList)
	String FRList
	
	String ParmFolder = ARGetForceFolder("Parameters","","")
	String TempFolder = GetDF("TempRoot")

	String FMapList = "", Pname = "ForceSavePath", UserPathStr = "", JHand = "SaveForceJBar", FPName
	String DataFolderList = "", DataFolder, CtrlName, SrcFolder = "", FPList = "",DataFolderMasterList="",FPMasterList=""
	Variable FileRef, FlushIt, Index, FPIndex, IsSaveAs=0, A=0, nop
	
	SVAR/Z LastMod = $ParmFolder+"LastMod"
	Wave/T ForceLoadDirs = InitOrDefaultTextWave(ParmFolder+"ForceLoadDirs",0)
	
	GetForcePlotsList(2,FPMasterList,DataFolderMasterList)
	Variable NumFR = ItemsInList(FRList,";")

	For (A = 0;A < NumFR;A += 1)
		Variable DataFolderListLoc=WhichListItem(StringFromList(A,FRList,";"), FPMasterList,";")
		DataFolderList+=StringFromList(DataFolderListLoc,DataFolderMasterList,";")+";"
	EndFor

	nop=NumFR
	if (Nop > 10)
		InitJbar(JHand,num2str(nop),"Saving Force Data","","")
	endif
	A=0
	
	for (A = 0;A < nop;A += 1)
		Jbar(JHand,A,0,.03)
		FPName = StringFromList(A,FRList,";")
		DataFolder = StringFromList(A,DataFolderList,";")
		SrcFolder = ARGetForceFolder("",DataFolder,FPName)
		Wave/Z Raw = $SrcFolder+FPName+"Raw"
		FlushIt = !WaveExists(Raw)
		Wave/Z Data = $CompressForceData(DataFolder,FPName,TempFolder+FPName,1,0)		//new header, but no slave data types...
		if (!WaveExists(Data))
			Continue
		endif
		FPIndex = FindDimLabel(ForceLoadDirs,0,DataFolder+FPName)
		if (!IsSaveAs)		//staight save
			if (FPIndex >= 0)
				NewPath/C/O/Q/Z $PName ForceLoadDirs[FPIndex]
			elseif (!Strlen(UserPathStr))
				V_Flag = ARNewPath(Pname,CreateFlag=1,TextStr="Path for Force plot not found, please provide path")
				if (V_Flag || !SafePathInfo(PName))
					continue
				endif
				PathInfo $Pname
				UserPathStr = S_Path
			else
				//set the path
				NewPath/C/O/Q/Z $PName UserPathStr
			endif
		else		//SaveAs
			if (StringMatch(DataFolder,"Memory") || StringMatch(DataFolder,ForceSubFolderCleanUp(LastDir(UserPathStr))))
				NewPath/C/O/Q/Z $PName UserPathStr
			else
				NewPath/C/O/Q/Z $PName UserPathStr+DataFolder
			endif
		endif
		if (FPIndex < 0)
			FPIndex = DimSize(ForceLoadDirs,0)
			InsertPoints/M=0 FPIndex,1,ForceLoadDirs
			SetDimLabel 0,FPIndex,$DataFolder+FPName,ForceLoadDirs
		endif
		//this is redundant for Straight save, when the data was there, but who cares...
		PathInfo $Pname
		ForceLoadDirs[FPIndex] = s_path
		
		Save/C/O/P=$Pname Data as FPName+".ibw"

		//File footer hack
		Open/A/P=$Pname FileRef FPname+".ibw"
		TagFPFooter(FileRef,Data)
		Close(FileRef)
		KillWaves Data
		if (FlushIt)
			SafeKillWaveList(ListMultiply(SrcFolder,ARWaveList(SrcFolder,FPName+"*",";",""),";"),";")
			Wave/Z/T LookupTable = $ParmFolder+DataFolder+"LookUpTable"
			if (WaveExists(LookupTable))
				Index = FindDimLabel(LookupTable,0,FPName)
				if (Index >= 0)
					DeletePoints/M=0 Index,1,LookupTable
				endif
			endif
		endif
	endfor
	UpdateForcePlotsNumbers()
	DoWindow/K $Jhand
	GhostForceModifyPanel()
	
End