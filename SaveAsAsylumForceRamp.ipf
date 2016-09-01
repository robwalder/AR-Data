#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma version=1.0

//This is a function that saves data from custom force ramps .  It uses information from the CTFC, so this will only work for waves generated from the CTFC.
// If you do something that doesn't use the CTFC, you'll need to build another function.
// This primarily uses a modifed version of  Devin Edward's function to save force curves (DE_SaveFC).  
// However, this also hacks asylum's code to put in your own name and number for the force ramp.
// It will read the CTFC info by default, unless you supply a separate wave with all the CTFC info.  
// FRname needs to be <=17 characters, or it will be truncated.
// Iteration should be < 10,000, or it will be set to 0.

Function SaveAsAsylumForceRamp(FRName,Iteration,DefVolts,ZSensorVolts,[TriggerInfo,AdditionalNotes])
	String FRName,AdditionalNotes
	Variable Iteration
	Wave DefVolts,ZSensorVolts
	Wave/T TriggerInfo
	
	SVAR gBaseName = root:Packages:MFP3D:Main:Variables:BaseName
	wave MVW = root:Packages:MFP3D:Main:Variables:MasterVariablesWave
	
	If(Iteration>9999)
		Iteration=0
	EndIf
	Variable FRNameLength=strlen(FRName)
	If(FRNameLength>17)
		String NewName=FRName[0,16]
		FRname=NewName
	EndIf
	gBaseName=FRName		//take a local copy, to protect the global

	MVW[%BaseSuffix][0]=Iteration
	
	If(ParamIsDefault(TriggerInfo))
		Make/O/T TriggerInfo
		td_ReadGroup("ARC.CTFC",TriggerInfo)
	EndIf

	If(ParamIsDefault(AdditionalNotes))
		DE_SaveFC(DefVolts,ZSensorVolts,TriggerInfo)
	EndIf
	If(!ParamIsDefault(AdditionalNotes))
		DE_SaveFC(DefVolts,ZSensorVolts,TriggerInfo,AdditionalNote=AdditionalNotes)
	EndIf
	
	
End

//DE_SaveFC() Taskes the DefVolts and ZsensorVolts waves, along with the parameters from TriggerInfo, RampInfo and RepeatInfo.
//This assumes that TriggerInfo already exists (it should), but does doublecheck that it's up-to-date by reloading the
//triggering parameters from the CTFC. this is built to be called when there's data you Have, and wish to save it out. As it is currently
//written it will BOTH generate a series of waves into the saved folder with iterated names, as well as save some of these
//to the Asylum file system. The former can be ignored in general, but were kept from trouble shooting. 

// I updated this to just read the sampling rate from the wave itself.  This was causing errors from having an incorrect sampling rate hard coded into the function.
// also fixed it so the correct approach and retract velocity gets put into the wave note
function DE_SaveFC(DefVolts,ZSensorVolts,TriggerInfo,[AdditionalNote])
	wave DefVolts
	Wave ZSensorVolts
	Wave/T TriggerInfo
	//Wave/t RampInfo
	string AdditionalNote
	
	wavetransform/o zapNaNs DefVolts
	wavetransform/o zapNaNs ZSensorVolts
	
	duplicate/o ZSensorVolts Z_raw_save
	Fastop Z_raw_save=(GV("ZLVDTSens"))*ZSensorVolts
	SetScale d -10, 10, "m", Z_raw_save
	duplicate/o Z_raw_save Z_snsr_save
	duplicate/o DefVolts Def_save
	fastop Def_save=(GV("Invols"))*DefVolts
	SetScale d -10, 10, "m", Def_save
	
	
	
	variable ApproachVelocity=str2num(TriggerInfo[%RampSlope1])*GV("ZPiezoSens")
	string TriggerChannel=TriggerInfo[%TriggerChannel1]
	variable TriggerSet1=str2num(TriggerInfo[%TriggerValue1])  
	variable RetractVelocity=str2num(TriggerInfo[%RampSlope2])*GV("ZPiezoSens")*-1
	string TriggerChannel2=TriggerInfo[%TriggerChannel2]
	variable TriggerSet2=str2num(TriggerInfo[%TriggerValue2])
	variable NoTrigSet=str2num(TriggerInfo[%TriggerHoldoff2])         //Fix
	string Callback=TriggerInfo[%CallBack]
	variable TriggerSetVolt1=str2num(TriggerInfo[%TriggerValue1])	 //Fix
	variable TriggerSetVolt2=str2num(TriggerInfo[%TriggerValue2])	  //Fix
	variable TriggerValue1=str2num(TriggerInfo[%TriggerPoint1])
	variable TriggerValue2=str2num(TriggerInfo[%TriggerPoint2])
	variable TriggerTime1=str2num(TriggerInfo[%TriggerTime1])
	variable TriggerTime2=str2num(TriggerInfo[%TriggerTime2])
	variable DwellTime1=str2num(TriggerInfo[%DwellTime1])
	variable DwellTime2=str2num(TriggerInfo[%DwellTime2])
	variable NoTrigTime=str2num(TriggerInfo[%TriggerHoldoff2 ])      //Fix
	variable sampleRate=1/DimDelta(DefVolts, 0 )   //This has to be updated to adapt to inputs.
	
	variable TriggerDeflection=0
		
	strswitch(TriggerChannel)  //A switch to properly define the trigger levels (in voltage) based on the channel used for the second trigger.
			
		case "Deflection":

			TriggerDeflection=TriggerValue1/1e-12*GV("InvOLS")*GV("SpringConstant") //Deflection to reach
			break
		
		default:
		
	endswitch
	
	
	
	variable dwellPoints0 = round(DwellTime1*sampleRate)   
	variable dwellpoints1=round(DwellTime2*sampleRate) 
	variable ramp2pts= round((TriggerTime2)*sampleRate)-1
	
	String Indexes = "0," //Start the index and directions 
	String Directions = "Inf,"
	variable Index = round(TriggerTime1*sampleRate)-1      //Counts out to one point less than where it triggered
	Indexes += num2istr(Index)+","
	Directions += num2str(1)+","
	
	if (DwellPoints0)

		Index += DwellPoints0
		Indexes += num2istr(Index)+","
		Directions += "0,"
	
	endif
	
	// Note from Rob on 06/16/2015
	// I tracked down the issues with a back "X" index in saving in the asylum format to this section of code
	// basically, if you use the molecule trigger, it will return a value of over 400000 if you didn't get a molecule
	// this then gets put in this giant number over 400,000 as a index for splitting the wave up.  This just prevents that from happening

	If (ramp2pts<400000)
		Index += ramp2pts
		Indexes += num2istr(Index)+","
		Directions += num2str(-1)+","
	EndIf
	
	//This just lists the rest of the wave (from where the trigger fired through to the end of the wave) as a dwell. In general, this isn't a true dwell, but
	//rather the time it takes to interact with Igor, decide whether we found a molecule, and then do whatever else it is we want to do (for instance,
	//ramp toward the surface etc.
	
	Index=dimsize(Def_save,0)-1
	Indexes += num2istr(Index)
	// Another addition related to my correction above on 06.16.2015.  The direction is important to get right.  You have to set it for 0 in most circumstances, but -1 for the molecule trigger not engaging.
	If (ramp2pts<400000)
		Directions += "0"
	Else
		Directions += "-1"
	EndIf
	
	
	string CNote="" //This is a correction note for the string that the ARSaveAsForce() function is going to write when we save this as a force.
	CNote = ReplaceStringbyKey("Indexes",CNote,Indexes,":","\r")
	CNote = ReplaceStringbyKey("Direction",CNote,Directions,":","\r")
	CNote = ReplaceStringbyKey("ApproachVelocity",CNote,num2str(ApproachVelocity),":","\r")
	CNote = ReplaceStringbyKey("RetractVelocity",CNote,num2str(RetractVelocity),":","\r")
	CNote = ReplaceStringbyKey("DwellTime",CNote,num2str(DwellTime1),":","\r")
	CNote = ReplaceStringbyKey("DwellTime2",CNote,num2str(DwellTime2),":","\r")
	CNote = ReplaceStringbyKey("NumPtsPerSec",CNote,num2str(sampleRate),":","\r")
	CNote = ReplaceStringbyKey("TriggerDeflection",CNote,num2str(TriggerDeflection),":","\r")
	CNote = ReplaceStringbyKey("TriggerChannel",CNote,TriggerChannel,":","\r")
	CNote = ReplaceStringbyKey("TriggerChannel2",CNote,TriggerChannel2,":","\r")
	CNote = ReplaceStringbyKey("TriggerTime1",CNote,num2str(TriggerTime1),":","\r")
	CNote = ReplaceStringbyKey("TriggerTime2",CNote,num2str(TriggerTime2),":","\r")
	CNote = ReplaceStringbyKey("TriggerSet1",CNote,num2str(TriggerSet1),":","\r")
	CNote = ReplaceStringbyKey("TriggerSet2",CNote,num2str(TriggerSet2),":","\r")
	CNote = ReplaceStringbyKey("TriggerValue1",CNote,num2str(TriggerValue1),":","\r")
	CNote = ReplaceStringbyKey("TriggerValue2",CNote,num2str(TriggerValue2),":","\r")

	if (!ParamIsDefault(AdditionalNote) && Strlen(AdditionalNote))

		variable nop
		nop = ItemsInList(AdditionalNote,"\r")
		String CustomItem
		Variable n,A

		for (A = 0;A < nop;A += 1)

			CustomItem = StringFromList(A,AdditionalNote,"\r")
			//print customitem
			n = strsearch(CustomItem,":",0,2)
	
			if (n < 0)
	
				Continue
	
			endif
	
			CNote = ReplaceStringByKey(CustomItem[0,n-1],CNote,Customitem[n+1,Strlen(CustomItem)-1],":","\r",0)
		
		endfor
	
	endif
		
	MakeZPositionFinal(Z_Snsr_save,ForceDist=TriggerSet2,indexes=indexes,DirInfo=Directions)	
	ARSaveAsForce(3,"SaveForce","Defl;ZSnsr",Z_raw_save,Def_save,Z_snsr_save,$"",$"",$"",$"",CustomNote=CNote)
	
	killwaves Z_raw_save, Z_snsr_save,Def_save
			
end // TestingSaving()
