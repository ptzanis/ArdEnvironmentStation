//#uses "fwAtlasAlarmHandling/fwAtlasAlarmHandlingScreen.ctl"

fwFsmAtlasWidget_initializeWidgetValue(string dpe, string format="[4.1f,,, FALSE,]")
{
   if (!dpExists(dpe)) {
    this.backCol = "_dpdoesnotexist";
    this.toolTipText = "DPE does not exist!";
  }
  else {
      _fwFsmAtlasWidget_initializeWidgetValue(dpe, format);
    }
}

_fwFsmAtlasWidget_initializeWidgetValue(string dpe, string format="[4.1f,,, FALSE,]")
{
  this.format = format;
  dpConnect("_fwFsmAtlasWidget_updateValue", true, dpe);
}
   
fwFsmAtlasWidget_initializeWidgetColor(string dpe, string qualityEl="")
{
  if (!dpExists(dpe)) {
    this.backCol = "_dpdoesnotexist";
   this.toolTipText = "DPE does not exist!";
 }
  else {
    _fwFsmAtlasWidget_initializeWidgetColor(dpe, qualityEl);
 }
}

_fwFsmAtlasWidget_initializeWidgetColor(string dpe, string qualityEl="")
{
    if(qualityEl == "") {
      qualityEl = dpSubStr(dpe, DPSUB_SYS_DP) + ".quality";
    }
    
    bool quality = dpExists(qualityEl);

    int alertType;
    dpGet(dpe + ":_alert_hdl.._type", alertType);
    if (alertType && quality) {
      dpConnect("_fwFsmAtlasWidget_updateAllCallback", true, 
                dpe+":_online.._bad",
                dpe+":_online.._invalid",
                qualityEl+".bad",
                qualityEl+".uncertain",
                dpe+":_alert_hdl.._act_state",
                dpe+":_alert_hdl.._act_text",
                dpe+":_alert_hdl.._active");
    } 
    else if (alertType){
      dpConnect("_fwFsmAtlasWidget_updateDpeAlertCallback", true, 
                dpe+":_online.._bad",
                dpe+":_online.._invalid",
                dpe+":_alert_hdl.._act_state",
                dpe+":_alert_hdl.._act_text",
                dpe+":_alert_hdl.._active");
    }
    else if (quality){
      dpConnect("_fwFsmAtlasWidget_updateDpeQualityCallback", true, 
                dpe+":_online.._bad",
                dpe+":_online.._invalid",
                qualityEl+".bad",
                qualityEl+".uncertain");
    }
    else {
      dpConnect("_fwFsmAtlasWidget_updateDpeCallback", true, 
                dpe+":_online.._bad",
                dpe+":_online.._invalid");
      
    }
}

_fwFsmAtlasWidget_updateAllCallback(string badAttr, bool bad,
            string invalidAttr, bool invalid,
            string qualityBadEl, bool qualityBad,
            string qualityUncertainEl, bool qualityUncertain,
            string alertStateAttr, string alertState,
            string alertTextAttr, string alertText,
            string alertActive, string active)
{
  if (invalid || bad) _fwFsmAtlasWidget_updateDpe(badAttr, bad,
						  invalidAttr, invalid);
  else if (qualityBad || qualityUncertain) _fwFsmAtlasWidget_updateQuality(qualityBadEl, qualityBad,
									   qualityUncertainEl, qualityUncertain);
  else _fwFsmAtlasWidget_updateAlert(alertStateAttr, alertState,
				     alertTextAttr, alertText,
				     alertActive, active);
}

_fwFsmAtlasWidget_updateDpeAlertCallback(string badAttr, bool bad,
            string invalidAttr, bool invalid,
            string alertStateAttr, string alertState,
            string alertTextAttr, string alertText,
            string alertActive, string active)
{
  if (invalid || bad) _fwFsmAtlasWidget_updateDpe(badAttr, bad,
						  invalidAttr, invalid);
  else _fwFsmAtlasWidget_updateAlert(alertStateAttr, alertState,
				     alertTextAttr, alertText,
				     alertActive, active);
}

_fwFsmAtlasWidget_updateDpeQualityCallback(string badAttr, bool bad,
            string invalidAttr, bool invalid,
            string qualityBadEl, bool qualityBad,
            string qualityUncertainEl, bool qualityUncertain)
{
  this.backCol = "FwNoAlarmOKPhysics";
  fwFsmAtlasWidget_setDescriptionAsTooltip();

  if (invalid || bad) _fwFsmAtlasWidget_updateDpe(badAttr, bad,
						  invalidAttr, invalid);
  else _fwFsmAtlasWidget_updateQuality(qualityBadEl, qualityBad,
									   qualityUncertainEl, qualityUncertain);
}


_fwFsmAtlasWidget_updateDpeCallback(string badAttr, bool bad,
            string invalidAttr, bool invalid)
{
  this.backCol = "FwNoAlarmOKPhysics";
  fwFsmAtlasWidget_setDescriptionAsTooltip();


  _fwFsmAtlasWidget_updateDpe(badAttr, bad,
						      invalidAttr, invalid);
}

_fwFsmAtlasWidget_updateAlert(string alertStateAttr, string alertState,
            string alertTextAttr, string alertText,
            string alertActive, string active)
{
  string color = alertText;
  string sTemp = dpSubStr(alertStateAttr, DPSUB_SYS_DP_EL);

  int error = dpGet(sTemp + ":_alert_hdl.._act_state_color", color);
  if (active && !error) {
    if (color=="") color = "FwStateOKPhysics";
    this.backCol = color;
    this.toolTipText = alertText;
  }
  else if (!active) {
    this.backCol = "FwAlarmDeactivated";
    this.toolTipText = "Alert deactivated";
  }
  else {
    error("Error in dpGet("+sTemp+":_alert_hdl.._act_state_color)");
  }
}

_fwFsmAtlasWidget_updateQuality(string qualityBadEl, bool qualityBad,
                string qualityUncertainEl, bool qualityUncertain)
{
   if (qualityBad || qualityUncertain) {
    this.backCol = "FwNoAlarmOKPhysics";
    if(qualityBad){ this.toolTipText = "QUALITY BAD"; }
    else if(qualityUncertain){ this.toolTipText = "QUALITY UNCERTAIN"; }
  }
 
}

_fwFsmAtlasWidget_updateDpe(string badAttr, bool bad,
                string invalidAttr, bool invalid)
{ 
  if (invalid || bad) {
    this.backCol = "FwNoAlarmOKPhysics";
    if(bad){ this.toolTipText = "BAD DATA"; }
    else if(invalid){ this.toolTipText = "INVALID DATA"; }
  }
}

_fwFsmAtlasWidget_updateValue(string dpeName, string value)
{
  this.text = value;
}

fwFsmAtlasWidget_setDescriptionAsTooltip()
{
  string tooltip = dpGetComment($dpe);
  if (tooltip=="") tooltip = $dpe;
  this.toolTipText = tooltip;
}

fwFsmAtlasWidget_scaleWidth(float originalX)
{
  int width = $width;
  float scale = width/originalX;
  this.scale(scale, 1);
  int xV, yV, xU, yU;
  getValue("","position",xV,yV);
  if (shapeExists("Unit")) {
    getValue("Unit","position",xU,yU);
    int newStart = xV+width + 2; // adjust to your taste
    Unit.position(newStart, yU);
  }
}

fwFsmAtlasWidget_rightMousePressed(string dpe, int width=60)
{
  
  string plotName = dpGetComment(dpe);
  if (plotName=="") plotName = dpe;
  strreplace(plotName, "/", "_");
  strreplace(plotName, ".", "_");
  dyn_string ex;
  //	fwTrending_createPlot(plotName, ex);
  if (dynlen(ex)) DebugTN(ex);

  int x, y;
  int width;
  getValue("", "position", x, y);
  x += width+40;
  //ChildPanelOn("objects/fsmAtlas/quick_trend.pnl", plotName, makeDynString("$plotName:"+plotName, "$dpe:"+$dpe), x, y);
  ModuleOnWithPanel(plotName+"Module", x, y, 0, 0, 1, 1, "",
                  "objects/fsmAtlas/quick_trend.pnl", plotName, makeDynString("$plotName:"+plotName, "$dpe:"+dpe));
  //	fwTrending_openPlotDisplay(plotName, fwTrending_PANEL_PLOT_FACEPLATE, false, true, "", plotName, x, y);
}

fwFsmAtlasWidget_rightMousePressedOnParameter(string dpe)
{
//  DebugTN("fwFsmAtlasWidget_rightMousePressedOnParameter "+dpe);
  string subdet = fwAtlas_getSubdetectorId(dpSubStr(dpe, DPSUB_SYS));
  if (subdet=="EXT" || subdet=="SAF") subdet = "GCS";
  
  dyn_string ex;
  int granted;
  fwAccessControl_isGranted(subdet+":Expert", granted, ex);
  if (dynlen(ex)) fwAccessControl_displayException(ex);
  if (!granted) {
    return;
  }
  
  dynClear(ex);
  int admin;
  fwAccessControl_isGranted(subdet+":Administration", admin, ex);
  if (dynlen(ex)) fwAccessControl_displayException(ex);
//  DebugTN("fwFsmAtlasWidget_rightMousePressedOnParameter admin "+admin);
  
  // fill menu
  //
  dyn_string menu = makeDynString(
      "PUSH_BUTTON, Expert Options, 1, 0", // title
      "SEPARATOR",
      "PUSH_BUTTON, Description, 2, 1"
  );
  int alertType, archiveType;
  dpGet(dpe+":_alert_hdl.._type", alertType, dpe+":_archive.._type", archiveType);
  if (alertType>0 || admin==1) dynAppend(menu, "PUSH_BUTTON, Alert Settings, 3, 1");
  else dynAppend(menu, "PUSH_BUTTON, Alert Settings, 3, 0");
  if ( (archiveType>0 || admin==1 ) && dpExists(dpSubStr(dpe, DPSUB_DP)) ) dynAppend(menu, "PUSH_BUTTON, Archive Settings, 4, 1"); // must be local DP
  else dynAppend(menu, "PUSH_BUTTON, Archive Settings, 4, 0");

  if (alertType>0) {
    dynAppend(menu, "SEPARATOR");
    if (fwInstallation_checkInstalledComponent("fwAlarmAtlas")==-1) dynAppend(menu, "PUSH_BUTTON, Alarm Help, 5, 0");
    else dynAppend(menu, "PUSH_BUTTON, Alarm Help, 5, 1");
  }

  DebugTN("Menu: ", menu);

  int answer = 0;
  popupMenu(menu, answer);
  //  DebugTN("Menu answer = "+answer);

  if (answer == 0) {
    DebugTN("No answer selected, abort");
    return;
  }

  string description = dpGetComment(dpe);

  switch (answer) {
    case 2:
      DebugTN("Description");
      ChildPanelOnCentralModal("objects/fwAtlas/fwAtlas_setDescription.pnl", "Set New Description for "+dpe, makeDynString("$dpid:"+dpe));
      break;
    case 3:
      DebugTN("Alert");
      ChildPanelOnCentralModal("objects/fwAtlas/fwAtlas_alertSettings.pnl", "Alert Settings for "+description,
                               makeDynString("$sDpe:"+dpe, "$fromFsm:1", "$alertExists:"+alertType, "$admin:"+admin));
      break;
    case 4:
      DebugTN("Archive");
      ChildPanelOnCentralModal("objects/fwAtlas/fwAtlas_archiveSettings.pnl", "Archive Settings for "+description, makeDynString("$sDpe:"+dpe,"$fromFsm:1"));
      break;
    case 5:
      DebugTN("Alarm help");
      fwAlarmScreenUser_showHelp(dpe, "", 0, ex);
      break;
    default:
      DebugTN("No answer selected, abort");
      break;
  }
}
