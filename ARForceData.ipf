#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma version=1.1
#include "::General-Igor-Utilities:ParseDateTime"

// Adapting for FRU version 1.4
// I now remove outputwaves with no data when you use applyfuncstoforcewaves with numoutputs=0
// put default folders at root:FRU

/////////////////////////////////////////////////////////////////////////
// Here's the start of my functions

// This is a super function that will take any function with an arguments list and apply it to the saved force waves
// Here are the main features...
// 1) If you include "ForceWave" or "SepWave", it will automatically put the force or separation wave into the argument of the function
// 2) You can apply your function to a subset of force waves by including a string list of force waves using the optional argument FPList.
// 2 continued... The default is to run the function on all the saved force waves
// 3) You can supply an explicit output wave name using the option arugment OutputWaveName.  The default is OutputWave
// 4) You can also put a specific destination folder for your outputs
// 5) If you have functions that output waves, use NumOutputs to define how many outputs each function should have.  
//     For example, do NumOutputs="3;2;1" for a list of functions with 3, 2 and 1 element outputs
Function ApplyFuncsToForceWaves(FunctionInputList,[FPList,OutputWaveNameList,DestFolder,NumOutputs])
	String FunctionInputList,FPList,OutputWaveNameList,DestFolder,NumOutputs

	// If I don't include a specific directory, then put it in MyForceData
	If(ParamIsDefault(DestFolder))
		DestFolder = BuildDataFolder("root:FRU:")
	EndIf
	
	SetDataFolder DestFolder
	
	String FPName, DataFolder, FPMasterList, DataFolderMasterList,DataFolderList=""
	GetForcePlotsList(2,FPMasterList,DataFolderMasterList)

	// If I don't include a specific list, then just include everything
	If(ParamIsDefault(FPList))
		FPList = FPMasterList
		DataFolderList = DataFolderMasterList
	EndIf
	
	// Figure out how many force pulls we are dealing with
	Variable A, nop = ItemsInList(FPList,";")

	// If we include a list of specific force pulls, then figure out what folders they are located in
	If(!ParamIsDefault(FPList))
		For (A = 0;A < nop;A += 1)
			Variable DataFolderListLoc=WhichListItem(StringFromList(A,FPList,";"), FPMasterList,";")
			DataFolderList+=StringFromList(DataFolderListLoc,DataFolderMasterList,";")+";"
		EndFor
	EndIf
	
	Variable NumFunctions=ItemsInList(FunctionInputList,";")
	
	// If we don't include a names for the output waves, just call them outputwave1,outputwave2,etc.
	If(ParamIsDefault(OutputWaveNameList))
		Variable Counter=0
		OutputWaveNameList=""
		For(Counter=0;Counter<NumFunctions;Counter+=1)
			OutputWaveNameList+= "OutputWave"+Num2Str(Counter)+";"
		EndFor
	EndIf
	
	// If I don't tell you how many outputs the functions have, just assume they all output 0 value
	If(ParamIsDefault(NumOutputs))
		Counter=0
		NumOutputs=""
		For(Counter=0;Counter<NumFunctions;Counter+=1)
			NumOutputs+= "0"+";"
		EndFor
	EndIf

	// Initialize Output Waves
	For(Counter=0;Counter<NumFunctions;Counter+=1)
		Variable NumColumns = str2num(StringFromList(Counter,NumOutputs,";"))
		Make/O/N=(nop,NumColumns) $StringFromList(Counter,OutputWaveNameList,";")
	EndFor

	// This is our master loop.  It will iterate through our list of Force Ramps and apply our functions
	for (A = 0;A < nop;A += 1)
		
		// Get name and location of force ramp
		FPName = StringFromList(A,FPList,";")
		DataFolder = StringFromList(A,DataFolderList,";")
		
		// Next lines deal with putting in the correct wave references
		String FRWaveNameKeys="Force_Ret;Force_Ext;Sep_Ret;Sep_Ext;Defl_Ret;Defl_Ext;DeflV_Ret;DeflV_Ext;ZSnsr_Ret;ZSnsr_Ext;Force_Away;Sep_Away;Defl_Away;DefV_Away;ZSnsr_Away;RawV_Ext;RawV_Ret;RawV_Away"
		Variable NumKeys=ItemsInList(FRWaveNameKeys), KeyCounter=0
		String KeysUsed=""
		String FunctionInputListForLoop=FunctionInputList
		FunctionInputListForLoop=ReplaceString("ForceWave", FunctionInputListForLoop, "Force_Ret")
		FunctionInputListForLoop=ReplaceString("SepWave", FunctionInputListForLoop, "Sep_Ret")
		FunctionInputListForLoop=ReplaceString("FRName", FunctionInputListForLoop, "\""+FPName+"\"")
		
		For(KeyCounter=0;KeyCounter<NumKeys;KeyCounter+=1)
			String FRKey=StringFromList(KeyCounter,FRWaveNameKeys)
			String StringReplacementString=FPName+FRKey
			If(strsearch(FunctionInputListForLoop,FRKey,0,2)!=-1)
				FunctionInputListForLoop=ReplaceString(FRKey, FunctionInputListForLoop, StringReplacementString)
				KeysUsed+=FRKey+";"
			EndIf
		EndFor
		
		Variable NumKeysUsed=ItemsInList(KeysUsed), KeyUsedCounter=0
		Variable NoData=0
		
		For(KeyUsedCounter=0;KeyUsedCounter<NumKeysUsed;KeyUsedCounter+=1)
			String CurrentKey=StringFromList(KeyUsedCounter,KeysUsed)
			String FRWavePath=DestFolder+FPName+CurrentKey		
			Wave DestForceData = InitOrDefaultWave(FRWavePath,0)
			Variable KeyPrefixLength= strlen(CurrentKey)-5
			String KeyPrefix=CurrentKey[0,KeyPrefixLength]
			Wave/Z SrcForceData = $CalcForceDataType(DataFolder,FPName+KeyPrefix)
			if ((!WaveExists(SrcForceData)) || (DimSize(SrcForceData,0) == 0))
				NoData=1
				Continue		//we don't have force for this force plot
			endif
			ExtractForceSection(SrcForceData,DestForceData)
			if ((!WaveExists(DestForceData)) || (DimSize(DestForceData,0) == 0))
				NoData=1
				Continue		//we don't have force for this force plot
			endif

		EndFor
		
		Variable FunctionCounter=0
		
		
		// Now we are going to loop through all those functions and apply them to our force and separation data
		For(FunctionCounter=0;FunctionCounter<NumFunctions;FunctionCounter+=1)
			
			String FunctionInput=StringFromList(FunctionCounter,FunctionInputListForLoop,";")
			Variable NumberOfFunctionOutputs=str2num(StringFromList(FunctionCounter,NumOutputs,";"))
			Variable CorrectEndIndex=NumberOfFunctionOutputs-1
			String CommandString=""
			
			If(NumberOfFunctionOutputs==0)
				// Now we construct the string of the form outputwave[A]=Function(function arguments)
				CommandString = FunctionInput
				If(NoData)
					CommandString=" "
				EndIf
				// Now I use execute to actually run this string as if I typed it into the command line.  I set the dimension label with the name of the force pull
				Execute CommandString
			EndIf
			If(NumberOfFunctionOutputs>=1)
				Wave OutputWave=$StringFromList(FunctionCounter,OutputWaveNameList,";")
			EndIf
			// For a single output from a wave, we can use a single line to set up everything correctly
			If(NumberOfFunctionOutputs==1)
				// Now we construct the string of the form outputwave[A]=Function(function arguments)
				CommandString = NameOfWave(OutputWave)+"["+Num2Str(A)+"]="+FunctionInput
				If(NoData)
					CommandString=NameOfWave(OutputWave)+"["+Num2Str(A)+"]=nan"
				EndIf
				// Now I use execute to actually run this string as if I typed it into the command line.  I set the dimension label with the name of the force pull
				Execute CommandString
			EndIf
			
			// For a function that returns a multiple outputs through a wave reference, we need to use a duplicate to create a local copy of the wave (TempWave)
			// Next we set the columns from TempWave into rows for the output wave.  This will provide a very useful wave to create a multidimensional output wave
			// I also preserve the dimension labels from the rows of temp wave and make them column names for output wave.  
			// This is useful to keep track of all the various outputs and keep code cleaner for functions that depend on these data.  
			If (NumberOfFunctionOutputs>1)
				Variable DimCounter=0
				String MultiOutputCommandString="Duplicate/O "+ FunctionInput+",TempWave"
				If(NoData)
					MultiOutputCommandString="Make/O/N=("+num2str(NumberOfFunctionOutputs)+") TempWave;TempWave=nan"
				EndIf
				Execute MultiOutputCommandString
				Wave TempWave=TempWave

				For (DimCounter=0;DimCounter<NumberOfFunctionOutputs;DimCounter+=1)
					String TheLabel=GetDimLabel(TempWave, 0, DimCounter)
					SetDimLabel 1,DimCounter,$TheLabel,OutputWave
					OutputWave[A][DimCounter]=TempWave[DimCounter]
				EndFor
			EndIf

			If(NumberOfFunctionOutputs>=1)
				// Set the row label as the name of the force pull
				SetDimLabel 0,A,$FPName,OutputWave 
			EndIf
			
				
		EndFor // Function Loop
		
		// Finally, I kill the force and separation waves, to keep things clean in the My Force Folder and prevent the program from crashing when dealing with big 
		// igor experiment files.
		For(KeyUsedCounter=0;KeyUsedCounter<NumKeysUsed;KeyUsedCounter+=1)
			CurrentKey=StringFromList(KeyUsedCounter,KeysUsed)
			FRWavePath=DestFolder+FPName+CurrentKey		

			If(WaveExists($FRWavePath))
				KillWaves $FRWavePath
			EndIf 
		EndFor
			// If I don't tell you how many outputs the functions have, just assume they all output 0 value
	If(ParamIsDefault(NumOutputs))
		Counter=0
		NumOutputs=""
		For(Counter=0;Counter<NumFunctions;Counter+=1)
			NumOutputs+= "0"+";"
		EndFor
	EndIf

	// Kill output waves if there is nothing that is supposed to be written to them.  
	For(Counter=0;Counter<NumFunctions;Counter+=1)
		Variable NumOutputsCheck = str2num(StringFromList(Counter,NumOutputs,";"))
		If(NumOutputsCheck==0)
			If(WaveExists($StringFromList(Counter,OutputWaveNameList,";")))
				KillWaves $StringFromList(Counter,OutputWaveNameList,";")
			EndIf
		EndIF
	EndFor

		
	endfor
	
End //GetRetraceDataFromForceWaves

// Getting one of the force ramp settings from the wave note.  
// Should have things like pulling velocity, invols, spring constant, etc.
Function/S GetForceRampSetting(ForceWave,ParmString)
	Wave ForceWave
	String ParmString
	
	String NoteStr = Note(ForceWave)
	String Parm = StringByKey(ParmString,NoteStr,":","\r")
	return(Parm)
End //GetForceRampSetting

Function GetDateNum(ForceWave,[DateComponent])
	Wave ForceWave
	String DateComponent
	
	If(ParamIsDefault(DateComponent))
		DateComponent = "Day"
	EndIf
	String DateString=GetForceRampSetting(ForceWave,"Date")
	String DateComponentStr="0"
	
	StrSwitch(DateComponent)
		case "Day":
			DateComponentStr=DateString[8,9]
		break
		case "Month":
			DateComponentStr=DateString[5,6]
		break
		case "Year":
			DateComponentStr=DateString[0,3]
		break
		default:
			Print "Error.  You haven't selected a proper date component"
		break
		
	EndSwitch
	Return str2num(DateComponentStr)
End

Function GetTimeNum(ForceWave,[TimeComponent])
	Wave ForceWave
	String TimeComponent
	
	If(ParamIsDefault(TimeComponent))
		TimeComponent = "Minute"
	EndIf
	String TimeString=GetForceRampSetting(ForceWave,"Time")
	String TimeComponentStr="0"
	
	StrSwitch(TimeComponent)
		case "Hour":
			TimeComponentStr=StringFromList(0, TimeString, ":")
		break
		case "Minute":
			TimeComponentStr=StringFromList(1, TimeString, ":")
		break
		case "Second":
			TimeComponentStr=StringFromList(0,StringFromList(2, TimeString, ":"), " ")
		break
		case "AM/PM":
			String AMPMStr=StringFromList(1,StringFromList(2, TimeString, ":"), " ")
			If(StringMatch(AMPMStr,"AM"))
				TimeComponentStr="0"
			Else
				TimeComponentStr="1"			
			EndIf
		break
		default:
			Print "Error.  You haven't selected a proper time component"
		break
		
	EndSwitch
	Return str2num(TimeComponentStr)
End

Function GetMilitaryHour(ForceWave)
	Wave ForceWave
	Variable RawHour=GetTimeNum(ForceWave,TimeComponent="Hour")
	Variable PM=GetTimeNum(ForceWave,TimeComponent="AM/PM")
	
	If(RawHour==12&&!PM)
		Return 0
	EndIf
	If(RawHour==12&&PM)
		Return 12
	EndIf
	If(RawHour!=12&&PM)
		Return RawHour+12
	EndIf
	Return RawHour
	
End

Function GetFractionalTime(ForceWave,[TimeMode,DateMode])
	Wave ForceWave
	String TimeMode,DateMode
	
	If(ParamIsDefault(TimeMode))
		TimeMode = "Hour"
	EndIf
	If(ParamIsDefault(DateMode))
		DateMode = "None"
	EndIf
	Variable OutputTime=0
	
	StrSwitch(TimeMode)
		case "Hour":
			OutputTime=GetMilitaryHour(ForceWave)+GetTimeNum(ForceWave,TimeComponent="Minute")/60+GetTimeNum(ForceWave,TimeComponent="Second")/3600
		break
		case "Minute":
			OutputTime=GetMilitaryHour(ForceWave)*60+GetTimeNum(ForceWave,TimeComponent="Minute")+GetTimeNum(ForceWave,TimeComponent="Second")/60
		break
		case "Second":
			OutputTime=GetMilitaryHour(ForceWave)*3600+GetTimeNum(ForceWave,TimeComponent="Minute")*60+GetTimeNum(ForceWave,TimeComponent="Second")
		break
		default:
			Print "Error.  You haven't selected a proper fractional time mode"
		break

	EndSwitch
	Variable TimeAdditionForDateInHours=0
	
	// I'm doing all of these in hours.  Then I'll convert to minute or seconds, if necessary
	StrSwitch(DateMode)
		case "None":
			TimeAdditionForDateInHours=0
		break
		case "Day":
			// Minus one so that day 1 of each month starts at 0 hours.
			TimeAdditionForDateInHours=24*(GetDateNum(ForceWave,DateComponent="Day")-1)
		break
//		Because of the different days in months, this will take a lot more work.  Not neccessary for now, but maybe fix in the future.		
//		case "Month":
//			TimeAdditionForDateInHours=0
//		break
//		case "Year":
//			TimeAdditionForDateInHours=0
//		break
		default:
			Print "Error.  You haven't selected a proper fractional time component"
		break

	EndSwitch
	If(!StringMatch(DateMode,"None"))
		StrSwitch(TimeMode)
			case "Hour":
				OutputTime+=TimeAdditionForDateInHours
			break
			case "Minute":
				OutputTime+=(TimeAdditionForDateInHours*60)
			break
			case "Second":
				OutputTime+=(TimeAdditionForDateInHours*3600)
			break
			default:
				Print "Error.  You haven't selected a proper fractional time mode"
			break
		EndSwitch
	EndIf

	
	Return OutputTime
End

Function GetAbsoluteTimeAR(ForceWave)
	Wave ForceWave
	String DateString=GetForceRampSetting(ForceWave,"Date")
	String TimeString=GetForceRampSetting(ForceWave,"Time")
	Return ParseDateTime(DateString,TimeString,DateFormat="yyyy-mm-dd")
	
End

Function GetPullingVelocity(ForceWave)
	Wave ForceWave
	Variable Velocity = str2num(GetForceRampSetting(ForceWave,"Velocity"))
	Variable Velocity2 = str2num(GetForceRampSetting(ForceWave,"RetractVelocity"))
	If(Velocity > Velocity2)
		Velocity=Velocity2
	EndIf
	
	Return Velocity
End



Function GetLVDTPosition(ForceWave,XorY)
	Wave ForceWave
	String XorY
	String LVDTString=XorY+"LVDT"
	String PositionString=GetForceRampSetting(ForceWave,LVDTString)
	Variable OutputPosition
	sscanf PositionString, "%f", OutputPosition

	Return OutputPosition
End

Function GetLVDTV(ForceWave,XorY)
	Wave ForceWave
	String XorY
	String LVDTString=XorY+"LVDT"
	String LVDTSensString=XorY+"LVDTSens"
	String LVDTOffsetString=XorY+"LVDTOffset"
	
	String PositionString=GetForceRampSetting(ForceWave,LVDTString)
	Variable OutputPosition
	sscanf PositionString, "%f", OutputPosition
	String SensString=GetForceRampSetting(ForceWave,LVDTSensString)
	Variable OutputSens
	sscanf SensString, "%f", OutputSens
	String OffsetString=GetForceRampSetting(ForceWave,LVDTOffsetString)
	Variable OutputOffset
	sscanf OffsetString, "%f", OutputOffset
	Variable OutputV = OutputPosition/OutputSens
			
	Return OutputV
End

Function GetLVDTSens(ForceWave,XorY)
	Wave ForceWave
	String XorY
	String LVDTSensString=XorY+"LVDTSens"

	String SensString=GetForceRampSetting(ForceWave,LVDTSensString)
	Variable OutputSens
	sscanf SensString, "%f", OutputSens
			
	Return OutputSens
End

Function GetSpotPosition(ForceWave)
	Wave ForceWave
	String ParmString="ForceSpotNumber"
	String SpotPositionString=GetForceRampSetting(ForceWave,ParmString)
	Return str2num(SpotPositionString)
End




// SaveForceAndSep
// This function takes a force and separation wave and creates copies in the SavedFRData folder
// Using the optional parameters, you can specify a different folder and different base name.
// This should be useful for creating copies of force and separation waves when needed.
Function SaveForceAndSep(Force_Ret,Sep_Ret,[TargetFolder,NewName,Suffix])
	Wave Force_Ret,Sep_Ret
	String TargetFolder,NewName,Suffix

	If(ParamIsDefault(TargetFolder))
		TargetFolder = "root:FRU:SavedFR:"
	EndIf
	
	If(ParamIsDefault(NewName))
		String FullWaveName=NameOfWave(Force_Ret)
		Variable SizeOfName = strlen(FullWaveName)-10
		NewName = FullWaveName[0,SizeOfName]
	EndIf	
	If(ParamIsDefault(Suffix))
		Suffix = "_Ret"
	EndIf

	String ForceWaveName=TargetFolder+NewName+"Force"+ Suffix
	String SepWaveName=TargetFolder+NewName+"Sep"+ Suffix

	Duplicate/O Force_Ret, $ForceWaveName
	Duplicate/O Sep_Ret, $SepWaveName
	
	Return 0

End  // SaveForceAndSep

// Moves the index for the Master Force Panel by inputing the names of the target force ramp
Function GoToForceReviewWave(TargetForceWaveName)
	String TargetForceWaveName

	String FPMasterList, DataFolderMasterList
	GetForcePlotsList(2,FPMasterList,DataFolderMasterList)

	Variable TargetIndex = WhichListItem(TargetForceWaveName, FPMasterList, ";")
	Variable IndexJump = TargetIndex - GV("ForceDisplayIndex") 
	ShiftForceList(IndexJump)
End


// This function figures out all the different prefixes from the master force list.  Might upgrade this to handle a force sublist, if necessary
Function/S UniqueForceLists()
	
	String FPMasterList, DataFolderMasterList
	GetForcePlotsList(2,FPMasterList,DataFolderMasterList)

	Variable NumberOfForceRamps = ItemsInList(FPMasterList)
	Variable Counter=0
	String UniqueNamesList=""
	
	For(Counter=0;Counter<NumberOfForceRamps;Counter+=1)
		String RawName = StringFromList(Counter,FPMasterList)
		Variable SizeOfName = strlen(RawName)-5
		
		String FormattedName = RawName[0,SizeOfName]
		Variable ItemLocation=WhichListItem(FormattedName, UniqueNamesList)
		If(ItemLocation<0)
			UniqueNamesList+=FormattedName+";"
		EndIf
	EndFor
	
	Return UniqueNamesList
	
End // UniqueForceLists

//
//Window ApplyFuncToFRPanel() : Panel
//	PauseUpdate; Silent 1		// building window...
//	NewPanel /W=(1290,183,1636,685) as "Apply Functions to Force Ramps"
//	ListBox FunctionsList_ListBox,pos={8,6},size={332,284},proc=FRUListBoxProc
//	ListBox FunctionsList_ListBox,listWave=root:MyForceData:CurrentFunctionsList
//	ListBox FunctionsList_ListBox,selWave=root:MyForceData:CurrentFunctionsListSel
//	ListBox FunctionsList_ListBox,mode= 2,selRow= 4
//	SetVariable NameOfFunction_SV,pos={8,330},size={322,16},proc=FRUSetVarProc,title="Function Name"
//	SetVariable NameOfFunction_SV,limits={-inf,inf,0},value= root:MyForceData:CurrentFunctions[0][%FunctionName]
//	SetVariable FunctionToApply_SV,pos={8,352},size={320,16},proc=FRUSetVarProc,title="Function"
//	SetVariable FunctionToApply_SV,limits={-inf,inf,0},value= root:MyForceData:CurrentFunctions[0][%FunctionString]
//	SetVariable OutputWaveName_SV,pos={8,375},size={320,16},proc=FRUSetVarProc,title="Output Wave Name"
//	SetVariable OutputWaveName_SV,limits={-inf,inf,0},value= root:MyForceData:CurrentFunctions[0][%OutputWaveName]
//	Button AddToFunctionsList_Button,pos={8,299},size={87,27},proc=FRUButtonProc,title="Add Function"
//	Button AddToFunctionsList_Button,fColor=(61440,61440,61440)
//	Button RemoveFromFunctionsList_Button,pos={105,299},size={95,27},proc=FRUButtonProc,title="Remove Function"
//	Button RemoveFromFunctionsList_Button,fColor=(61440,61440,61440)
//	SetVariable NumOutputs_SV,pos={8,397},size={320,16},proc=FRUSetVarProc,title="Number Of Outputs"
//	SetVariable NumOutputs_SV,limits={-inf,inf,0},value= root:MyForceData:CurrentFunctions[0][%NumberOfOutputs]
//	Button ApplyAllFuncsToFRList_Button,pos={137,462},size={122,30},proc=FRUButtonProc,title="Apply All Functions"
//	Button ApplyAllFuncsToFRList_Button,fColor=(61440,61440,61440)
//	Button ApplyOneFuncToFRList_Button,pos={8,463},size={122,30},proc=FRUButtonProc,title="Apply This Function"
//	Button ApplyOneFuncToFRList_Button,fColor=(61440,61440,61440)
//	PopupMenu FunctionPresets_Popup,pos={8,424},size={154,22},proc=FRUPopMenuProc,title="Function Presets"
//	PopupMenu FunctionPresets_Popup,mode=1,popvalue="WLC Fit",value= #"\"WLC Fit;Load Corrected FR;CL Analysis;Find And Save Detrend;Apply Detrend Function;Update Offset Stats;Update Rupture Stats;Box Car Filter;Rupture Force Stats;Offset Stats;Custom\""
//EndMacro
