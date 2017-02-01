#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include "::AR-Data:ARForceData" version>=1.1
#include "::General-Igor-Utilities:WaveDimNote" version>=1.1


Function InitTimeLine()
	NewDataFolder/O/S root:Timeline
	GetForceRampTimeline()
	GetUserMeasurementTimeLine("root:RNAPulling:SavedData:","DefV","RNAPulling")
	SetDataFolder root:Timeline
	Wave RNAPullingTime
	Wave/T RNAPullingName
	Wave ARTime
	Wave/T ARName
	
	Concatenate/DL/O/NP {RNAPullingTime,ARTime}, MasterTime
	Concatenate/DL/O/NP {RNAPullingName,ARName}, MasterNames
	Duplicate/O RNAPullingTime, RNAPullingState
	Duplicate/O ARTime, ARState
	ARState=0
	RNAPullingState=0
	Concatenate/DL/O/NP {RNAPullingState,ARState}, MasterState
	Sort/DIML MasterTime,MasterTime,MasterNames,MasterState
	GetCenteredFRTimeline()
End

Function DisplayTimeline()
	SetDataFolder root:Timeline
	Wave ARTime, ARState,ARStartTime,AREndTime,ARErrorBar
	Wave RNAPullingTime, RNAPullingState,RNAPullingStartTime,RNAPullingEndTime,RNAPullingErrorBar,MasterTime
	Wave/T ARName,RNAPullingName
	Display RNAPullingState vs RNAPullingTime
	ModifyGraph rgb(RNAPullingState)=(0,65000,0 )
	AppendToGraph ARState vs ARTime
	ModifyGraph rgb(ARState)=(65000,0,0)
	ErrorBars RNAPullingState X,wave=(RNAPullingErrorBar,RNAPullingErrorBar)	
	ErrorBars ARState X,wave=(ARErrorBar,ARErrorBar)	
	ModifyGraph mode=3
	ModifyGraph textMarker(RNAPullingState)={RNAPullingName,"Arial",0,90,3,0,2}
	ModifyGraph textMarker(ARState)={ARName,"Arial",0,90,3,0,2}
	ModifyGraph muloffset={0.0166667,0}
	ModifyGraph offset={-MasterTime[0]/60,0}
End

Function GetForceRampTimeline()
	ApplyFuncsToForceWaves("ARStartRampTime(Force_Ret);AREndRampTime(Force_Ret);",OutputWaveNameList="ARStartTime;AREndTime",DestFolder="root:Timeline:",NumOutputs="1;1")
	Wave ARStartTime=root:Timeline:ARStartTime
	Wave AREndTime=root:Timeline:AREndTime
	Variable NumRamps=DimSize(ARStartTime,0)
	Make/O/T/N=(NumRamps) ARName
	Make/D/O/N=(NumRamps) ARTime,ARErrorBar
	Variable RampCounter=0
	For(RampCounter=0;RampCounter<NumRamps;RampCounter+=1)
		ARName[RampCounter]=GetDimLabel(ARStartTime, 0, RampCounter )
		ARTime[RampCounter]=(ARStartTime[RampCounter]+AREndTime[RampCounter])/2
		ARErrorBar[RampCounter]=(AREndTime[RampCounter]-ARStartTime[RampCounter])/2
		SetDimLabel 0,RampCounter,$ARName[RampCounter],ARName,ARTime,ARErrorBar
		
	EndFor
	Sort/DIML AREndTime,AREndTime,ARTime,ARStartTime,ARName,ARErrorBar
End

Function GetCenteredFRTimeline()
	
	SetDataFolder root:Timeline
	Wave/T ARName
	Wave ARTime, ARState,ARStartTime,AREndTime,ARErrorBar
	Make/D/O/N=1 CenteredRampTime, CenteredRampState,CenteredRampStartTime,CenteredRampEndTime,CenteredRampErrorBar
	Make/O/T/N=1 CenteredRampName
	Variable NumRamps=DimSize(ARStartTime,0)
	Variable RampCounter=0
	For(RampCounter=0;RampCounter<NumRamps;RampCounter+=1)
		If(StringMatch(ARName[RampCounter],"*CFR*"))
			Variable NumCenteredRamps=DimSize(CenteredRampTime,0)
			InsertPoints NumCenteredRamps, 1, CenteredRampTime, CenteredRampState,CenteredRampStartTime,CenteredRampEndTime,CenteredRampErrorBar,CenteredRampName
			CenteredRampName[NumCenteredRamps]=ARName[RampCounter]
			CenteredRampTime[NumCenteredRamps]=ARTime[RampCounter]
			CenteredRampState[NumCenteredRamps]=ARState[RampCounter]
			CenteredRampStartTime[NumCenteredRamps]=ARStartTime[RampCounter]
			CenteredRampEndTime[NumCenteredRamps]=AREndTime[RampCounter]
			CenteredRampErrorBar[NumCenteredRamps]=ARErrorBar[RampCounter]
			SetDimLabel 0,NumCenteredRamps,$CenteredRampName[NumCenteredRamps],CenteredRampName,CenteredRampTime,CenteredRampState,CenteredRampStartTime,CenteredRampEndTime,CenteredRampErrorBar

		EndIf
	EndFor
	DeletePoints 0, 1, CenteredRampTime, CenteredRampState,CenteredRampStartTime,CenteredRampEndTime,CenteredRampErrorBar,CenteredRampName
End

Function GetUserMeasurementTimeLine(TargetDataFolder,WavePrefix,TimelineName)
	String TargetDataFolder,WavePrefix,TimelineName
	String WaveSearchString=WavePrefix+"*"
	SetDataFolder $TargetDataFolder
	String TargetWaveNames=	WaveList(WaveSearchString,";","")
	Variable NumWaves=ItemsInList(TargetWaveNames,";")
	Variable WaveCounter=0
	String FullTimelineName="root:Timeline:"+TimeLineName
	Make/D/O/N=(NumWaves) $FullTimelineName+"StartTime",$FullTimelineName+"EndTime",$FullTimelineName+"Time",$FullTimelineName+"ErrorBar"
	Make/O/T/N=(NumWaves) $FullTimelineName+"Name"
	Wave StartTime=$FullTimelineName+"StartTime"
	Wave EndTime=$FullTimelineName+"EndTime"
	Wave MiddleTime=$FullTimelineName+"Time"
	Wave ErrorBar=$FullTimelineName+"ErrorBar"
	Wave/T Name=$FullTimelineName+"Name"
	
	For(WaveCounter=0;WaveCounter<NumWaves;WaveCounter+=1)
		Wave TargetWave=$StringFromList(WaveCounter,TargetWaveNames,";")
		Variable MeasurementIndex=WaveCounter
		sscanf StringFromList(WaveCounter,TargetWaveNames,";"), WavePrefix+"%f", MeasurementIndex
		EndTime[WaveCounter]=GetAbsoluteTimeWN(TargetWave)
		Variable NumPts=DimSize(TargetWave,0)
		Variable TimeForMeasurement=pnt2x(TargetWave, NumPts-1 )
		
		StartTime[WaveCounter]=EndTime[WaveCounter]-TimeForMeasurement
		MiddleTime[WaveCounter]=(EndTime[WaveCounter]+StartTime[WaveCounter])/2
		ErrorBar[WaveCounter]=(EndTime[WaveCounter]-StartTime[WaveCounter])/2
		Name[WaveCounter]=TimelineName+num2str(MeasurementIndex)
		SetDimLabel 0,WaveCounter,$Name[WaveCounter],StartTime,MiddleTime,ErrorBar,Name,EndTime
		
	EndFor
	Sort/DIML EndTime,EndTime,MiddleTime,StartTime,Name,ErrorBar
End

Function/S NearestARForceRamp(Name)
	String Name
	SetDataFolder root:Timeline	
	Wave ARTime, ARState,ARStartTime,AREndTime,ARErrorBar,MasterTime
	Wave/T MasterNames,ARName

	Variable MasterIndex=FindDimLabel(MasterNames, 0, Name )
	Variable TargetTime=MasterTime[MasterIndex]
	
	FindLevel/P/Q ARTime, TargetTime
	Variable RampEndBeforeIndex=Floor(V_LevelX)
	Variable RampStartAfterIndex=Ceil(V_LevelX)
	Variable RampEndBefore=AREndTime[RampEndBeforeIndex]
 	Variable RampStartAfter=ARStartTime[RampStartAfterIndex]
 	
 	Variable TimeToRampBefore=(TargetTime-RampEndBefore)
 	Variable TimeToRampAfter=(RampStartAfter-TargetTime)
 	If(TimeToRampBefore<TimeToRampAfter)
 		Return ARName[RampEndBeforeIndex]
 	Else
 		Return ARName[RampStartAfterIndex]
 	EndIf
	
End

// Just doing this for RNA right now.
Function/S PreviousCenteredForceRamp(Name)
	String Name
	SetDataFolder root:Timeline	
	Wave MasterTime,CenteredRampTime
	Wave/T MasterNames,CenteredRampName

	Variable MasterIndex=FindDimLabel(MasterNames, 0, Name )
	Variable TargetTime=MasterTime[MasterIndex]
	Variable NumCFR=DimSize(CenteredRampTime,0)
	
	
	FindLevel/T=0.01/EDGE=1/P/Q CenteredRampTime, TargetTime
	
	Variable CFRTime=V_LevelX
	Variable CFRIndex=Floor(V_LevelX)

 	If(!V_flag)
 		Return CenteredRampName[CFRIndex]
 	Else
 		If(TargetTime>CenteredRampTime[NumCFR-1])
 			Return CenteredRampName[NumCFR-1]
 		Else
 			Return "No Centered Ramp Before This"
 		EndIf
 	EndIf
End

Function TimeSincePreviousCFR(Name)
	String Name
	SetDataFolder root:Timeline	
	Wave CenteredRampEndTime,MasterTime
	Return MasterTime[%$Name]-CenteredRampEndTime[%$PreviousCenteredForceRamp(Name)]

End


