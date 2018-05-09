#uses "fwInstallation.ctl"
main()
{
	
//  if ( !globalExists("gFwInstallationLog") )
//    addGlobal("gFwInstallationLog", STRING_VAR);
//    
//  gFwInstallationLog = "";
	
  // if there are any postInstallation files execute them

  int iReturn;
  int i;
  bool postInstallsRun = false;

  dyn_string dynPostInstallFiles_all;

  if(fwInstallationRedu_isRedundant())
  {
    if (fwInstallation_getInstallOnlyInSplit())
    {
      bool isSplitMode = fwInstallationRedu_isSplitMode();
      if (!isSplitMode || (isSplitMode && fwInstallationRedu_isSplitActive()))
      {
        fwInstallation_throw("Post installation scripts could run only in the split passive peer!", "INFO", 26);
        dpSet("_Managers.Exit", 1280 + myManNum());
        return;
      }
	  
  	  if (isSplitMode && ! fwInstallationRedu_isSplitActive()) {
        while (fwInstallationRedu_isRecovering()) {
            delay(30);            
        }
          
      }
    }
    else if (fwInstallationRedu_isPassive())
    {
      fwInstallation_throw("Post installation scripts could run only in the active peer!", "INFO", 26);
      dpSet("_Managers.Exit", 1280 + myManNum());
      return;
    }
  }
  
  
  string dp = fwInstallation_getInstallationPendingActionsDp();
  setUserId(getUserId("para"));
  
  if(dpExists(dp))
  {
    dyn_string components, scriptFiles;
    _fwInstallation_GetComponentsWithPendingPostInstall(components, scriptFiles);
    bool dbConnectionInitialized = false;
    mapping component2PostInstallStatus;
    for(i = 1; i <= dynlen(scriptFiles); i++)	
    {
      postInstallsRun = true;
      if(!dbConnectionInitialized && fwInstallationDB_getUseDB())
      {    
        dbConnectionInitialized  = true;
        if(fwInstallationDB_connect()){fwInstallation_throw("Failed to connect to the System Configuration DB before executing post-install and/or post-delete scripts", "WARNING", 10); return;}
        fwInstallation_throw("Starting execution of Components' Post-Installation Scripts", "INFO", 26);
      }

      // execute the file	and check returned code
      fwInstallation_setCurrentComponent(components[i]);
      fwInstallation_throw("Running post-installation script: " + scriptFiles[i] + " for component: " + components[i], "INFO", 26);  
      fwInstallation_evalScriptFile(scriptFiles[i] , iReturn);
      
      if(mappingHasKey(component2PostInstallStatus, components[i])) {
        component2PostInstallStatus[components[i]] &= (iReturn == 0); 
      } else {
        component2PostInstallStatus[components[i]] = (iReturn == 0);
      }
      
      if(iReturn != 0)
      {
        fwInstallation_throw("Error executing : " + scriptFiles[i] + " file.", "ERROR", 26);
      }
      else
      {
        fwInstallation_throw("  " + scriptFiles[i] + " - OK ", "INFO", 26);
      }
      
      fwInstallation_unsetCurrentComponent();
    }	
    
    // set component statuses based on combined result of their postInstall scripts
    dyn_string componentKeys = mappingKeys(component2PostInstallStatus);
    for(int i = 1; i <= dynlen(componentKeys); i++) {
      fwInstallation_setComponentInstallationStatus(componentKeys[i], component2PostInstallStatus[componentKeys[i]]);
    }
			
    // all the files were executed - if there were any errors the user has been informed
    // clearing the fwInstallationInfo.postInstallFiles:_original.._value
				
    dynClear(dynPostInstallFiles_all);

    dpSet(dp + ".postInstallFiles", makeDynString());
    

    // get all the post delete files
    dpGet(dp + ".postDeleteFiles", dynPostInstallFiles_all);
			
    // for each post delete file
    for(i = 1; i <= dynlen(dynPostInstallFiles_all); i++)
    {
      fwInstallation_showMessage(makeDynString("Executing post delete  files ..."));
				
      // execute the file	
      fwInstallation_setCurrentComponent(dynPostInstallFiles_all[i]);
      fwInstallation_evalScriptFile(dynPostInstallFiles_all[i] , iReturn);
				
      // check the return value
      if(iReturn == -1)
      {
        fwInstallation_throw("Error executing : " + dynPostInstallFiles_all[i] + " file.", "ERROR", 26);
      }
      else
      {
        fwInstallation_throw(dynPostInstallFiles_all[i] + " - OK ", "INFO", 26);
        fwInstallation_deleteFiles(dynPostInstallFiles_all[i], "");
      }
      fwInstallation_unsetCurrentComponent();
    }
			
    // all the files were executed - if there were any errors the user has been informed
    // clearing the fwInstallationInfo.postDeleteFiles:_original.._value
    dpSet(dp + ".postDeleteFiles", makeDynString());
  }
  else
    fwInstallation_throw("Dp does not exist: " + dp, "ERROR", 26);   
        
  //Re-sync unicos ows files if needed:
  if(isFunctionDefined("unConfigGenericFunctions_Create_Config_ows"))
  {
    unConfigGenericFunctions_Create_Config_ows("config_ows");
  }
    
  if(fwInstallationManager_executeAllReconfigurationActions(true))
  {
    fwInstallation_throw("There were errors executing the managers' reconfiguration actions", "WARNING", 26);
    delay(1); //Make sure that our message gets print out.
  }

  postInstallsRun = true;
  //Update System Configuration DB if required:
  if(postInstallsRun && fwInstallationDB_getUseDB())
  {
    if(fwInstallationDB_connect()){fwInstallation_throw("Failed to connect to the System Configuration DB after executing post-install and/or post-delete scripts", "WARNING", 26); return;}
    if(fwInstallationDB_registerProjectFwComponents()) {fwInstallation_throw("Failed to upate the System Configuration DB after execution of the component post-installation scripts", "WARNING", 26); return;}
//    DebugN("Wrinting log with", gFwInstallationLog);
//    fwInstallationDB_storeInstallationLog();
  }	
 
  bool splitForced;
  string pairToLive;
  _fwInstallationRedu_getSplitInfo(splitForced, pairToLive);
  if(fwInstallationRedu_isSplitMode() && splitForced && pairToLive == fwInstallationRedu_myReduHostNum() && fwInstallation_getRestoreRedundancyAfterInstallation() == 1)
  {
    DebugN("Re-enabling redundancy", pairToLive);
    _fwInstallationRedu_setSplitInfo(0, "");
    fwInstallationRedu_setReduSplitOff(pairToLive);
    delay(30);
  }
  dpSet("_Managers.Exit", 1280 + myManNum());
  
}

