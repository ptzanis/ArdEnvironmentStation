#uses "fwInstallation.ctl"

/** Initialization script for GUIless setup of InstallationTool
  @param commandLineArg (in) path where components should be installed
*/
main(string commandLineArg)
{
  fwInstallation_init(true, commandLineArg);
  fwInstallationManager_setMode("WCCOActrl", "-f fwInstallationAgent.lst", "manual");
}
