//FVR
// $License: NOLICENSE
/**@file
 *
 * This package contains general functions of the FW Component Installation tool
 *
 * @author Fernando Varela (EN-ICE)
 * @date   August 2010
 */

#uses "CtrlPv2Admin"
#uses "pmon.ctl"
#uses "dist.ctl"    //Not loaded by default by control managers

#uses "fwInstallationDB.ctl"
#uses "fwInstallationDBAgent.ctl"
#uses "fwInstallationRedu.ctl"
#uses "fwInstallationManager.ctl"
#uses "fwInstallationXml.ctl"
#uses "fwInstallationPackager.ctl"
#uses "fwInstallationDeprecated.ctl"
///////////////////////////////////////////////////
/** Version of this tool.
 * Used to determine the coherency of all libraries of the installation tool
 * @ingroup Constants
*/
const string csFwInstallationToolVersion = "8.1.1";
/** Version of this library.
 * Used to determine the coherency of all libraries of the installtion tool
 * @ingroup Constants
*/
const string csFwInstallationLibVersion = "8.1.1";

///EN-ICE support line:
const string FW_INSTALLATION_SUPPORT_ADDRESS = "icecontrols.support@cern.ch";

///////////////////////////////////////////////////
/**
 * @name fwInstallation.ctl: Definition of variables

   The following variables are used by the fwInstallationManager.ctl library

 * @{
 */

dyn_bool    gButtonsEnabled;
string      gUserName;
string      gPassword;
string      gDebugFlag;
int         gSelectedMan;
int         gManShifted;
bool        gRefreshManagerList;
int         gRefreshSec;
int         gRefreshMilli;
int         gRefreshTime;

string      gTcpHostName;
int         gTcpPortNumber;
int         gTcpFileDescriptor;
int         gTcpFileDescriptor2;
string      gTcpFifo;

string      gTestVariable;
bool        gShowLicenseWarning;
int         gErrorCounter;
bool        gCloseEnabled;
dyn_string  gParams;

global string      gFwInstallationPmonUser = "N/A";
global string      gFwInstallationPmonPwd = "N/A";
global dyn_dyn_string      gFwInstallationLog;
global string      gFwInstallationLogPost;

global string      gFwInstallationCurrentComponent;
global int         gInstallationAgentUiNum;

//@} // end of constants

/** Error codes that can be ignored while doing ASCII import  
 * @ingroup Constants
 */
//const dyn_int gASCIIImportErrorsToIgnore = makeDynInt(0, 55, 56, 58, 69, 76);

/** Name of this component.
 * @ingroup Constants
*/
const string gFwInstallationComponentName = "fwInstallation";
/** Name of the config file of the tool.
 * @ingroup Constants
*/
const string gFwInstallationConfigFile = "fwInstallation.config";
/** Name of the init file loaded at start up of the tool.
 * @ingroup Constants
*/
const string gFwInstallationInitFile = "fwInstallationInit.config";

/** Name of the init file loaded at start up of the tool.
 * @ingroup Constants
*/
const string gFwInstallationInitScript = "fwInstallationInitScript.ctl";

/** Returned error code in case of problems
 * @ingroup Constants
*/
const int gFwInstallationError = -1;
/** Returned error code in case everything is OK
 * @ingroup Constants
*/
const int gFwInstallationOK = 0;
/** Constant that stores a particular error has already been shown
 * @ingroup Constants
*/
bool gFwInstallationErrorShown = FALSE;

/** Constant that stores if the user has clicked in the Yes to All button during installations
 * @ingroup Constants
*/
bool gFwYesToAll = FALSE;

//const int EXPIRED_REQUEST_ACTION = 1;
//const int EXPIRED_REQUEST_NAME = 2;
//const int EXPIRED_REQUEST_VERSION = 3;
//const int EXPIRED_REQUEST_EXECUTION_DATE = 4;

/** keyword used to replace by the current version name
 * @ingroup Constants
*/
string fwInstallation_VERSION_KEYWORD = "%VERSION%";
/** Path to the trash folder
 * @ingroup Constants
*/
const string gFwTrashPath = PROJ_PATH + "/fwTrash/";

const string gFwInstallationOverparametrizedFileIssue = "OVERPARAMETERIZED"; // multiple instances
const string gFwInstallationHashFileIssue             = "HASH"; // hash error
const string gFwInstallationCompNotPossibleFileIssue  = "HASH_COMPARASION_NOT_POSSIBLE"; // no hash comparison possible

//Beginning executable code:

//======== Source file hashes =========

const dyn_string FW_INSTALLATION_HASH_FOLDERS = makeDynString("scripts/", "panels/"); //calculate hash only for files from these folders
const dyn_string FW_INSTALLATION_HASH_FILES_EXCEPTIONS = makeDynString("panels/fwFSMuser/fwUi.pnl",
                                                                       "panels/fwFSMuser/logo.pnl",
                                                                       "scripts/libs/fwFsmUser.ctl"); //don't calculate hash for files from this list

/** Gets the list of component files for which hash calclulation should be done.
  * It retreives list of all component files from internal component dp and filters out files for which hash calculation should not be performed.
  * @param component (in)  Component name, when subcomponent then must be provided without leading underscore
  * @param componentFiles (out)  List of component files for which hash calculation should be done
  * @return 0 in case when list was retreived successfully, -1 in case of error (component doesn't have any files)
  */
int fwInstallation_getComponentFilesForHashCalculation(string component, dyn_string &componentFiles)
{
  //get list of all component files
  dyn_string allComponentFiles;
  fwInstallation_getComponentInfo(component, "componentfiles", allComponentFiles); 
  if(dynlen(allComponentFiles) <= 0)
  {
    fwInstallation_throw("Component: " + component + " does not have any files", "INFO", 17);
    return -1;
  }
  const int allComponentFilesLen = dynlen(allComponentFiles);
  const int hashFoldersLen = dynlen(FW_INSTALLATION_HASH_FOLDERS);
  const int hashFilesExceptionLen = dynlen(FW_INSTALLATION_HASH_FILES_EXCEPTIONS);
  dynClear(componentFiles);
  for(int i=1;i<=allComponentFilesLen;i++)
  {
    string componentFile = allComponentFiles[i];
    strreplace(componentFile, "./", "");
    for(int j=1;j<=hashFoldersLen;j++)
      if(patternMatch(FW_INSTALLATION_HASH_FOLDERS[j] + "*", componentFile))
      {//check if file should be included by checking its folder
        if(fwInstallation_normalizePath(componentFile) != 0)
        {
          fwInstallation_throw("Failed to normalize path of file: " + componentFile + ". File is not added to the list of files for hash calculation", "WARNING", 17);
          continue;
        }
        bool addComponentFile = true;
        for(int k=1;k<=hashFilesExceptionLen;k++)
          if(patternMatch(FW_INSTALLATION_HASH_FILES_EXCEPTIONS[k], componentFile))
          {//file should be excluded from hash calculation and comparison
            addComponentFile = false;
            break;
          }
        
        if(addComponentFile)
        {//add component file to the list of files for which hash is calculated
          dynAppend(componentFiles, componentFile);
          break;
        }
      }
  }
  dynUnique(componentFiles);
  return 0;
}

const string FW_INSTALLATION_HASH_FILENAME_SEPARATOR = "|"; //this serves as separator between hash value and file name when they are stored together.

/** This function calculates and stores sources files hashes.
  * It gets list of component files, calculates their hashes and write them to a component installation dp: _fwInstallation_[componentName].sourceFilesHashes
  * Data is stored as a list of formatted strings. Single string contains information about particular file, it has the following pattern:
  * [baseHashValue]|[alternativeHashValue]|[relativePathToComponentFile].
  * - baseHashValue is a hash of a file in component source directory
  * - alternativeHashValue by default is the same as base hash value, however user can store there hash value of component file in different directory - it can be used to mask 'hash mismatch' file issue
  * If source file is not accessible or it is not possible to calculate hash for the file then it is added to the list with empty hash.
  * File issue 'Hash comparison not possible' will be detected in such case, user later can mask this error by setting an alternativeHashValue for file (as for 'hash mismatch' file issue)
  * @param component (in)  Component name, when subcomponent then must be provided without leading underscore
  * @return 0 whem hashes were successfully calculated and stored, -1 in case of error (failed to retreive source directory or list of component files, failed to store hashes in a file)
  */
int fwInstallation_calculateComponentSourceFilesHashes(string component)
{
  //get component source directory
  dyn_anytype at;
  fwInstallation_getComponentInfo(component, "sourcedir", at); 
  if(dynlen(at) <= 0 || at[1] == "")
  {
    fwInstallation_throw("Could not retrieve the source directory date for component: " + component + ". Hash calculation not possible", "WARNING", 18);
    return -1;
  } 
  string sourceDir = at[1];
  //get component source files
  dyn_string componentFiles;
  if(fwInstallation_getComponentFilesForHashCalculation(component, componentFiles))
  {
    fwInstallation_throw("Could not get list of source files of component: " + component + ". Hash calculation not possible", "WARNING", 18);
    return -1;
  }
  dyn_string fileNames, baseFileHashes, alternativeFileHashes;
  int componentFilesLen = dynlen(componentFiles);
  for(int i=1;i<=componentFilesLen;i++)//calculate hash of each source file
  {
    string fileHash = "";
    if(!access(sourceDir + componentFiles[i], F_OK))
    {
      fileHash = getFileCryptoHash(sourceDir + componentFiles[i]);
      if(fileHash == "")
        fwInstallation_throw("Failed to calculate hash for source file: " + sourceDir + componentFiles[i] + ". Saving file without hash in the list", "WARNING");  
    }
    else
      fwInstallation_throw("Failed to access file: " + (string)(sourceDir + componentFiles[i]) + ". Hash calculation not possible, saving file without hash in the list.", "WARNING");
    
    dynAppend(fileNames, componentFiles[i]);
    dynAppend(baseFileHashes, fileHash);
    dynAppend(alternativeFileHashes, fileHash);
  }
  return fwInstallation_storeComponentSourceFilesHashes(component, fileNames, baseFileHashes, alternativeFileHashes);//save hashes in component installation dp
}

/** Store list of component files and list of corresponding hash values for given component in the component dp.
  * @param component (in)  Component name, when subcomponent then must be provided without leading underscore
  * @param fileNames (in)  List of relative paths of component files for which the hash was calculated
  * @param baseFileHashes (in)  List of base hash values of component files
  * @param alternativeFileHashes (in)  List of alternative hash values of component files
  * @return 0 if lists of files and hashes were saved successfully in dp, -1 in case of errors (provided lists are of different size, failed to set value of dp)
  */
int fwInstallation_storeComponentSourceFilesHashes(string component, dyn_string fileNames, dyn_string baseFileHashes, dyn_string alternativeFileHashes)
{
  int componentFilesLen = dynlen(fileNames);
  if(dynlen(baseFileHashes) != componentFilesLen || dynlen(alternativeFileHashes) != componentFilesLen)
  {
    fwInstallation_throw("List of files and list of hashes are of different size. Failed to store list of file hashes for component: " + component);
    return -1;
  }
  
  dyn_string componentFilesHashes;
  for(int i=1;i<=componentFilesLen;i++)
    dynAppend(componentFilesHashes, fwInstallation_formatComponentSourceFileHashString(fileNames[i], baseFileHashes[i], alternativeFileHashes[i]));
  
  return dpSet(fwInstallation_getComponentDp(component) + ".sourceFilesHashes", componentFilesHashes);
}

/** This function formats string that contains information about particular component file, its hash value and hash comparison status
  * @param fileName (in)  Relative path to a component file
  * @param baseFileHash (in)  Base hash value for component file (should be the one calculated for file in component source directory)
  * @param alternativeFileHash (in)  Alternative hash value for component file, when empty (default) then baseFileHash is used here
  * @return Formatted string with component source file hash info
  */
string fwInstallation_formatComponentSourceFileHashString(string fileName, string baseFileHash, string alternativeFileHash = "")
{
  if(alternativeFileHash == "")
    alternativeFileHash = baseFileHash;
  return baseFileHash + FW_INSTALLATION_HASH_FILENAME_SEPARATOR + alternativeFileHash + FW_INSTALLATION_HASH_FILENAME_SEPARATOR + fileName;
}

/** Retrieves list of component files and list of corresponding hash values for given component.
  * @param component (in)  Component name, when subcomponent then must be provided without leading underscore
  * @param fileNames (out)  List of relative paths of component files for which the hash was calculated
  * @param baseFileHashes (out)  List of base hash values of component files
  * @param alternativeFileHashes (out)  List of alternative hash values of component files
  * @return 0 if lists of files and hashes were retreived successfully, -1 in case of errors (failed to get list of files and hashes from dp)
  */
int fwInstallation_getComponentSourceFilesHashes(string component, dyn_string &fileNames, dyn_string &baseFileHashes, dyn_string &alternativeFileHashes)
{
  dyn_string componentFilesHashes;
  if(dpGet(fwInstallation_getComponentDp(component) + ".sourceFilesHashes", componentFilesHashes) != 0)
  {
    fwInstallation_throw("Failed to get list of component source files hashes for component: " + component);
    return -1;
  }
  dynClear(fileNames);
  dynClear(baseFileHashes);
  dynClear(alternativeFileHashes);
  int componentFilesHashesLen = dynlen(componentFilesHashes);
  for(int i=1;i<=componentFilesHashesLen;i++)
  {
    string componentFileHash = componentFilesHashes[i];
    //get position of first separator
    int separator1Pos = strpos(componentFileHash, FW_INSTALLATION_HASH_FILENAME_SEPARATOR);
    if(separator1Pos < 0)
    {
      fwInstallation_throw("Failed to get base and alternative hash and filename from line: " + componentFileHash + " - incorrect line format. Skipping this line.", "WARNING");
      continue;
    }
    if(separator1Pos != 32 && separator1Pos != 0)//second condition to avoid log littering when there is no hash value for file - this will appear on file issue list as 'hash comparison not possible'
      fwInstallation_throw("Base hash in line: " + componentFileHash + " has unexpected length of " + (string)separator1Pos + " bits. The expected length is 32 bits", "WARNING");
    //get base file hash value (part of componentFileHash string before first separator)
    string baseFileHash = substr(componentFileHash, 0, separator1Pos);
    
    //get position of second separator
    int separator2Pos = strpos(componentFileHash, FW_INSTALLATION_HASH_FILENAME_SEPARATOR, separator1Pos + 1);
    if(separator2Pos < 0)
    {
      fwInstallation_throw("Failed to get alternative hash and filename from line: " + componentFileHash + " - incorrect line format. Skipping this line.", "WARNING");
      continue;
    }
    int separator2PosRelative = separator2Pos - separator1Pos - 1;
    if(separator2PosRelative != 32 && separator2PosRelative != 0)//second condition to avoid log littering when there is no hash value for file - this will appear on file issue list as 'hash comparison not possible'
      fwInstallation_throw("Alternative hash in line: " + componentFileHash + " has unexpected length of " + (string)separator2PosRelative + " bits. The expected length is 32 bits", "WARNING");
    //get alternative file hash value (part of componentFileHash string between first and second separator)
    string alternativeFileHash = substr(componentFileHash, separator1Pos + 1, separator2PosRelative);
    
    //get file name from the rest of the componentFileHash string
    string fileName = substr(componentFileHash, separator2Pos + 1);
    
    dynAppend(fileNames, fileName);
    dynAppend(baseFileHashes, baseFileHash);
    dynAppend(alternativeFileHashes, alternativeFileHash);
  }
  return 0;
}

/** This function allows to set alternative hash value for file.
  * It can be used to hide 'hash mismatch' file issues for given file.
  * @param component (in)  Component name, when subcomponent then must be provided without leading underscore
  * @param fileName (in)  Relative path to a component file
  * @param directory (in)  Flag that indicates if hash comparison should be enabled (true - default) or disabled
  * @return 0 when file hash value was updated successfully, -1 in case of an error (error reading dp that contains component file hashes, given file is not a component file or failed to update dp with hashes)
  */
int fwInstallation_setAlternativeComponentFileHash(string component, string fileName, string directory = "")
{
  dyn_string fileNames, baseFileHashes, alternativeFileHashes;
  if(fwInstallation_getComponentSourceFilesHashes(component, fileNames, baseFileHashes, alternativeFileHashes) != 0)
  {
    fwInstallation_throw("Failed to get base and alternative file hashes for component: " + component + ". Failed to set alternative hash value for file: " + fileName);
    return -1;
  }
  int componentFilesLen = dynlen(fileNames);
  if(dynlen(baseFileHashes) != componentFilesLen || dynlen(alternativeFileHashes) != componentFilesLen)
  {
    fwInstallation_throw("List of files and list of hashes are of different size. Failed to set alternative hash value for file: " + fileName);
    return -1;
  }
  fwInstallation_normalizePath(fileName);
  int filePosition = dynContains(fileNames, fileName);//get index of fileName in an array of component files
  if(filePosition < 1)
  {
    fwInstallation_throw("Provided file name " + fileName + " is not a part of " + component + " component. Cannot to set alternative hash value for this file");
    return -1;
  }
  
  if(directory == "")//resolve default installation directory when it is not provided
  {
    dyn_string at;
    fwInstallation_getComponentInfo(component, "installationdirectory", at); 
    if(dynlen(at) <= 0 || at[1] == "")
    {
      fwInstallation_throw("Could not retrieve the installation directory for component: " + component + ". Failed to to set alternative hash value for file: " + fileName);
      return -1;
    }
    directory = at[1];
  }
  fwInstallation_normalizePath(directory, true);
  string filePath = directory + fileName;
  if(access(directory + fileName, F_OK) != 0)
  {
    fwInstallation_throw("Cannot access file " + filePath + ". Failed to set alternative hash value for this file");
    return -1;
  }
  string fileHash = getFileCryptoHash(filePath);
  if(fileHash == "")
  {
    fwInstallation_throw("Error while calculating hash for file: " + filePath + ". Failed to set alternative hash value for this file");
    return -1;
  }
  
  alternativeFileHashes[filePosition] = fileHash;
  
  return fwInstallation_storeComponentSourceFilesHashes(component, fileNames, baseFileHashes, alternativeFileHashes);
}

/** This function resets alternative hash value for given file (set alternative hash same as base hash)
  * @param component (in)  Component name, when subcomponent then must be provided without leading underscore
  * @param fileName (in)  Relative path to a component file
  * @return 0 when file hash value was reset successfully, -1 in case of an error (error reading dp that contains component file hashes, given file is not a component file or failed to update dp with hashes)
  */
int fwInstallation_resetAlternativeComponentFileHash(string component, string fileName)
{
  dyn_string fileNames, baseFileHashes, alternativeFileHashes;
  if(fwInstallation_getComponentSourceFilesHashes(component, fileNames, baseFileHashes, alternativeFileHashes) != 0)
  {
    fwInstallation_throw("Failed to get base and alternative file hashes for component: " + component + ". Failed to reset alternative hash value for file: " + fileName);
    return -1;
  }
  int componentFilesLen = dynlen(fileNames);
  if(dynlen(baseFileHashes) != componentFilesLen || dynlen(alternativeFileHashes) != componentFilesLen)
  {
    fwInstallation_throw("List of files and list of hashes are of different size. Failed to reset alternative hash value for file: " + fileName);
    return -1;
  }
  int filePosition = dynContains(fileNames, fileName);//get index of fileName in an array of component files
  if(filePosition < 1)
  {
    fwInstallation_throw("Provided file name " + fileName + " is not a part of " + component + " component. Cannot to reset alternative hash value for this file");
    return -1;
  }
  
  alternativeFileHashes[filePosition] =  baseFileHashes[filePosition];
  
  return fwInstallation_storeComponentSourceFilesHashes(component, fileNames, baseFileHashes, alternativeFileHashes);
}

/** This function retrieves list of files that have set alternative hash value different than base hash value
  * @param component (in)  Component name, when subcomponent then must be provided without leading underscore
  * @param filesWithAlternativeHash (out)  List of files that have set alternative hash value different than base hash value
  * @return 0 when list was retrieved successfully, -1 in case of an error when reading dp that contains component file hashes
  */
int fwInstallation_getComponentFilesWithAlternativeHash(string component, dyn_string &filesWithAlternativeHash)
{
  dyn_string fileNames, baseFileHashes, alternativeFileHashes;
  if(fwInstallation_getComponentSourceFilesHashes(component, fileNames, baseFileHashes, alternativeFileHashes) != 0)
  {
    fwInstallation_throw("Failed to get base and alternative file hashes for component: " + component + ". Cannot retrieve list of files with alternative hashes for this component");
    return -1;
  }
  int componentFilesLen = dynlen(fileNames);
  if(dynlen(baseFileHashes) != componentFilesLen || dynlen(alternativeFileHashes) != componentFilesLen)
  {
    fwInstallation_throw("List of files and list of hashes are of different size. Failed to retrieve list of files with alternative hashes for component: " + component);
    return -1;
  }
  
  dynClear(filesWithAlternativeHash);
  for(int i=1;i<=componentFilesLen;i++)
    if(baseFileHashes[i] != alternativeFileHashes[i])
      dynAppend(filesWithAlternativeHash, fileNames[i]);
  return 0;
}

//========== File issues for project and particular component ===========
/**
Gets all the file issues for the project
@param fileIssues (out) array of all file issues
*/
int fwInstallation_getProjectFileIssues(dyn_dyn_mixed &fileIssues)
{
  dyn_mapping projectFileIssues;
  dyn_dyn_string componentsInfo;
  fwInstallation_getInstalledComponents(componentsInfo);
  
  int n = 1;
  for(int i = 1; i <= dynlen(componentsInfo); i++)  
  {
    dynClear(projectFileIssues);
    fwInstallation_getComponentFilesIssues(componentsInfo[i][1], projectFileIssues);
    //append file issues to array:
    for(int j = 1; j <= dynlen(projectFileIssues); j++)
    {
      
      fileIssues[n][FW_INSTALLATION_DB_FILE_ISSUE_COMPONENT] = componentsInfo[i][1];
      fileIssues[n][FW_INSTALLATION_DB_FILE_ISSUE_VERSION] = componentsInfo[i][2];
      fileIssues[n][FW_INSTALLATION_DB_FILE_ISSUE_FILENAME] = projectFileIssues[j]["name"];
      fileIssues[n][FW_INSTALLATION_DB_FILE_ISSUE_TYPE] = projectFileIssues[j]["error"];
      fileIssues[n][FW_INSTALLATION_DB_FILE_ISSUE_MODIFICATION_DATE] = projectFileIssues[j]["time"];
      ++n;
    }
  }
  
  return 0;
}

/** Gets all the file issues for a particular component in the project
  * @param component (in)  Name of the component, when subcomponent then must be provided without leading underscore
  * @param errorFiles (out)  Array of all file issues. Each file issue is represented by a mapping with following fields: 'name' (absolute path to a file), 'error' (file issue type), 'size' (file size), 'time' (file modification time)
  * @param getOverparameterized (in)  Indicates whether the method should include the overparameterized files in the result, default value is true
  * @param getHash (in)  Indicates whether the method should include the files with hash issue in the result, default value is true
  * @param getHashCompNotPossible (in)  Indicates whether the method should include the files for which hash comparasion is not possible in the result, default value is true
  * @param useAlternativeHash (in)  Indicates whether file hash should be compared to the alternative hash value (true - default) or base hash value (false)
  * @return 0 if OK, -1 if error (component is not installed, failed to get installation directory, failed to read file with source files hashes values, failed to calculate hash for component's file)
  */
int fwInstallation_getComponentFilesIssues(string component, dyn_mapping &errorFiles, bool getOverparameterized = true, bool getHash = true,
                                           bool getHashCompNotPossible = true, bool useAlternativeHash = true)
{
  string version = "";
  if(!fwInstallation_isComponentInstalled(component, version))
  {
    fwInstallation_throw("Component: " + component + " not installed in the local project. Not possible to find out error files", "WARNING", 16);
    return -1;
  }
  
  //get list of files that should be checked in project directories
  dyn_string componentFiles;
  if(fwInstallation_getComponentFilesForHashCalculation(component, componentFiles))
  {
    fwInstallation_throw("Could not get list of source files of component: " + component + ". Failed to get component file issues", "WARNING", 18);
    return -1;
  }
  //get reference hash values for component files
  dyn_string sourceFileNames, sourceFileHashes, alternativeFileHashes;
  if(fwInstallation_getComponentSourceFilesHashes(component, sourceFileNames, sourceFileHashes, alternativeFileHashes) != 0)
  {
    fwInstallation_throw("Failed to get " + component + " component source files hashes. Failed to get component file issues");
    return -1;
  }
  int sourceFileNamesLen = dynlen(sourceFileNames);

  //get installation directory
  dyn_anytype at;
  fwInstallation_getComponentInfo(component, "installationdirectory", at); 
  if(dynlen(at) <= 0 || at[1] == "")
  {
    fwInstallation_throw("Could not retrieve the installation directory for component: " + component + ". Failed to get component file issues", "WARNING", 18);
    return -1;
  }
  string installationDir = at[1];
  if(fwInstallation_normalizePath(installationDir, true) != 0)
  {
    fwInstallation_throw("Could not normalize installation directory path of component: " + component + ". Failed to get component file issues");
    return -1;
  }
  //get all project paths:
  dyn_string projPaths;
  fwInstallation_getProjPaths(projPaths);
  int installationDirPosition = dynContains(projPaths, strrtrim(installationDir, "/"));//find where is installation directory
  if(installationDirPosition < 1)
  {
    fwInstallation_throw("Could not get find installation directory of component: " + component + " in the list of project paths. Failed to get component file issues");
    return -1;
  }
  int componentFilesLen = dynlen(componentFiles);
  int projPathsLen = dynlen(projPaths);
  for(int i=installationDirPosition;i<=projPathsLen;i++)//search for file issues in installation directory and in all directories that are below it in the hierarchy
  {
    string projPath = projPaths[i] + "/";//add trailing slash for directory path
    if(getOverparameterized && i > installationDirPosition)
    {//look for overparametrized files only when they are in paths that are below the installation directory in config file, in other cases there is no overparametrization - a file from installation directory is loaded by WinCC OA
      for(int j=1;j<=componentFilesLen;j++)
      {
        string overparametrizedFile = projPath + componentFiles[j];
        if(isfile(overparametrizedFile))
          dynAppend(errorFiles, makeMapping("name", overparametrizedFile, 
                                            "error", gFwInstallationOverparametrizedFileIssue,
                                            "size", getFileSize(overparametrizedFile),
                                            "time", getFileModificationTime(overparametrizedFile)));
      }
    }
    else if(getHash || getHashCompNotPossible)
    {//compare file hashes, if getOverparameterized is false then compare hashes of files in all project directories starts from installation directory
      for(int j=1;j<=componentFilesLen;j++) 
      {
        string componentFileName = projPath + componentFiles[j];
        bool fileHashFound = false;
        for(int k=j;k<=sourceFileNamesLen;k++)
        {//file should be at the same index in both arrays so start searching from this point (j=k)
          if(componentFiles[j] == sourceFileNames[k])
          {
            fileHashFound = true;
            if(access(componentFileName, R_OK) != 0)
            {
              if(i == installationDirPosition)//file should be in installation directory, if not then throw an error/(or report as file issue - 'missing file' - TODO)
              {
                fwInstallation_throw("File " + componentFileName + " of " + component + " component not found in installation directory. Cannot calculate hash for this file");
              }
              break;
            }
            
            string componentFileHash = getFileCryptoHash(componentFileName);
            if(componentFileHash == "")
            {
              fwInstallation_throw("Failed to calculate file hash for file " + componentFileName + " of " + component + " component. Failed to get component file issues");
              break;
            }
          
            int hashMismatch = -1;
            if(useAlternativeHash && alternativeFileHashes[k] != "")
              hashMismatch = (int)(componentFileHash != alternativeFileHashes[k]);
            if(!useAlternativeHash && sourceFileHashes[k] != "")
              hashMismatch = (int)(componentFileHash != sourceFileHashes[k]);
          
            if(hashMismatch == 1)
              dynAppend(errorFiles, makeMapping("name", componentFileName, 
                                                "error", gFwInstallationHashFileIssue,
                                                "size", getFileSize(componentFileName),
                                                "time", getFileModificationTime(componentFileName)));
            else if(hashMismatch < 0)
              dynAppend(errorFiles, makeMapping("name", componentFileName, 
                                            "error", gFwInstallationCompNotPossibleFileIssue,
                                            "size", getFileSize(componentFileName),
                                            "time", getFileModificationTime(componentFileName)));
            break;
          }
          if(k == sourceFileNamesLen)
            k = 0;//this allows to search sourceFileNames on indexes k<j
        
          if(k == j - 1)//whole sourceFileNames list was checked at this point so exit loop now
            break;
        }
        if(!fileHashFound)//file was not found in .sourceFilesHashes dp
          fwInstallation_throw("File " + componentFiles[j] + " was not found in list of component source files hashes for " + component + " component. Cannot perform hash comparison", "WARNING");
      }
    }
  }
  return 0;
}

/**
fwInstallation_installComponentSet installs a set of components in the local project.
@param componentNames (in) array of string containing the names of the components to be installed.
@param dontRestartProject (out) overall flag that specifies if project restart can be skipped at the end of the installation, 
       "yes" means the project restart can be skipped and the post-installation scripts are launched.
@return 0 if all components were installed succesfully, -1 if error occured
*/
int fwInstallation_installComponentSet(dyn_string componentFiles,
                                       string &dontRestartProject)
{
  int err = 0;
  dyn_string componentFilesInOrder;
  dontRestartProject = "yes"; //assume that the project does not have to be restarted.
  string localDontRestartProject = "yes";
  dyn_string componentNames, componentVersions;
  for(int i = dynlen(componentFiles); i >= 1; i--)
  {
    dyn_dyn_mixed componentInfo;
    dynClear(componentInfo);
    if(fwInstallationXml_load(componentFiles[i], componentInfo))
    {
      fwInstallation_throw("Could not load XML file: " + componentFiles[i] + ". Component skipped from installation.");
      dynRemove(componentFiles, i);
      continue;
      
    }
    dynInsertAt(componentNames, componentInfo[FW_INSTALLATION_XML_COMPONENT_NAME][1], 1);
    dynInsertAt(componentVersions, componentInfo[FW_INSTALLATION_XML_COMPONENT_VERSION][1], 1);
  }//end of loop over components.

  // put the components in order for installing
  int retVal;
  retVal = fwInstallation_putComponentsInOrder_Install(componentNames, componentVersions,
                                                       componentFiles, componentFilesInOrder);
  if(retVal == -1)
  {
    return -1;
  }
  dyn_string componentNamesInOrder;
  for (int i=1;i<=dynlen(componentFilesInOrder);i++)
  {
    dyn_dyn_mixed componentInfo;
    if(fwInstallationXml_load(componentFilesInOrder[i], componentInfo))
      continue;
    componentNamesInOrder[i] = componentInfo[FW_INSTALLATION_XML_COMPONENT_NAME][1];
  }
  fwInstallation_reportSetTotalComponentsNumber(dynlen(componentFilesInOrder));
  fwInstallation_reportInstallationStartTime();
  
  fwInstallation_throw("Backing up project config file", "INFO", 10);

  //backup project config file before starting the installation:
  if(fwInstallation_backupProjectConfigFile())
  {
    fwInstallation_throw("Project config file could not be backed up. Component installation aborted.");
    return -1;
  }

  // install every component
  fwInstallation_throw("Project config file successfully backed up. Proceding now with installation of components", "INFO", 10);

  for (int i =1; i <= dynlen(componentFilesInOrder); i++)
  {
    string componentName = componentNamesInOrder[i];
    fwInstallation_reportComponentInstallationProgress(componentName, FW_INSTALLATION_REPORT_STEP_STARTING_INSTALLATION);
    
    fwInstallation_throw("Installing component from XML file: " + componentFilesInOrder[i], "INFO", 10);
    bool isSubcomponent = false;
    fwInstallation_isSubComponent(componentFilesInOrder[i], isSubcomponent);

    string sourceDir = _fwInstallation_baseDir(componentFilesInOrder[i]);
    int componentInstalled = 0;
    int retVal = fwInstallation_installComponent(componentFilesInOrder[i],
                                           sourceDir,
                                           isSubcomponent,
                                           componentName,
                                           componentInstalled,
                                           localDontRestartProject);
    err += retVal;
    if(retVal != 0){}//report installation status (success/error)
    if(componentName != "")
      fwInstallation_reportComponentInstallationFinished(componentName);

    if(localDontRestartProject == "no")
    {
      dontRestartProject = "no";
    }
  }

  if(err)
    return -1;

  return 0;
///end of components intallation
}

/** fwInstallation_deleteComponentSet removes a set of components in the local project.
 * @param dynComponentsNames (in) Array of string containing the names of the components to be removed.
 * @param deleteFiles (in) Indicates whether component files should be removed from the installation directory.
 * @return 0 if OK, -1 if error
*/
int fwInstallation_deleteComponentSet(dyn_string dynComponentsNames, bool deleteFiles)
{
  dyn_string componentsNamesInOrder;
  bool componentDeleted = false;
  dyn_int status;
  string sMessage;
  
  // put the components in order depending on dependencies between the components
  fwInstallation_putComponentsInOrder_Delete(dynComponentsNames,  componentsNamesInOrder);
                        
  //backup project config file before starting the installation:
  //backup project config file before starting the installation:
  if(fwInstallation_backupProjectConfigFile())
  {
    fwInstallation_throw("Project config file could not be backed up. Component deinstallation aborted.");
    return -1;
  }
  // delete the components - one by one
  for (int i =1; i <= dynlen(componentsNamesInOrder); i++)
  {	
    bool deletionAborted = false;
    fwInstallation_deleteComponent(componentsNamesInOrder[i], componentDeleted, deleteFiles, true, deletionAborted);
    if(!componentDeleted && !deletionAborted)
    {
      sMessage = formatTime("[%Y-%m-%d_%H:%M:%S] ",getCurrentTime()) + componentsNamesInOrder[i] + " not deleted.";
      if(myManType() == UI_MAN) fwInstallation_writeToMainLog(sMessage);
      
      fwInstallation_throw(sMessage);
    }
  }	
  return 0;
}

void deleteComponents(dyn_string dynComponentsNames, bool deleteFiles)
{
  fwInstallation_resetLog();
  fwInstallation_deleteComponentSet(dynComponentsNames, deleteFiles);
	
  // refresh the main panel
  fwInstallation_getInstalledComponentsUI();
  fwInstallation_getComponentsInfo("tblAvailableComponents", "txtSourceDir");
  
  //update system information db if instructed to do so
  fwInstallationDB_update();
  
  btnDBDetails.enabled = true;
  btnCheck.enabled = true;
}

/** This function stops managers for the period of installation of components.
 * @return 0 if OK, -1 if error
*/
int fwInstallation_stopManagersForInstallation()
{
  //Check if there are managers to be stopped:
  if(fwInstallationManager_shallStopManagersOfType(fwInstallation_getWCCOAExecutable("dist")))
  {
    if(fwInstallation_stopManagers(makeDynString(fwInstallation_getWCCOAExecutable("dist"))) != 0)
    {
      ChildPanelOnCentral("vision/MessageInfo1", "ERROR Stopping dist manager", makeDynString("Could not stop dist manager.\nPlease do it manually and then click OK\nto continue."));
      return -1;
    }
  }
      
  if(fwInstallationManager_shallStopManagersOfType(fwInstallation_getWCCOAExecutable("ui")))
  {
    if(fwInstallation_stopManagers(makeDynString(fwInstallation_getWCCOAExecutable("ui"), fwInstallation_getWCCOAExecutable("NV"))) != 0)
    {
      ChildPanelOnCentral("vision/MessageInfo1", "ERROR Stopping UI managers", makeDynString("Could not stop UI and NV managers.\nPlease do it manually and then click OK\nto continue."));
      return -1;
    }
  }
        
  if(fwInstallationManager_shallStopManagersOfType(fwInstallation_getWCCOAExecutable("ctrl")))
  {
    if(fwInstallation_stopManagers(makeDynString(fwInstallation_getWCCOAExecutable("ctrl"))) != 0)
    {
      ChildPanelOnCentral("vision/MessageInfo1", "ERROR Stopping control managers", makeDynString("Could not stop control managers.\nPlease do it manually and then click OK\nto continue."));
      return -1;
    }
  }
      
  return 0;
}
    


/** This function parses the distPeer entry in order to retrieve the host and the distPort. 
  
@note So far this function does not consider redundancy

@param distPeer (in) distPeer entry, as found in the config file
@param host (out)
@param reduHost (out)
@param distPort (out)
*/
void _fwInstallation_parseDistPeer(string distPeer, 
                                   string &host, 
                                   string &reduHost, 
                                   string &port)
{
  string hostString;
  string reduHostString;
  
  dyn_string tmpArr = strsplit(distPeer, ":"); //tmpArr[1] = host1.cern.ch$host2.cern.ch, tmpArr[2] = 4777
  if (dynlen(tmpArr) > 1)
  {
    port = tmpArr[2];
      
    dyn_string ds = strsplit(tmpArr[1], "$");
    hostString = ds[1];
    
    if(dynlen(ds) > 1)
      reduHostString = ds[2];
    else
      reduHostString = "";

    dyn_string dss = strsplit(hostString, ".");
    host = dss[1];
    
    if(reduHostString != "")
    {
      dss = strsplit(reduHostString, ".");
      reduHost = dss[1];    
    }
    else
    {
      reduHost = "";
    }
  }
  else
  {  
    dyn_string ds = strsplit(distPeer, "$");
    hostString = ds[1];
    
    if(dynlen(ds) > 1)
      reduHostString = ds[2];
    else
      reduHostString = "";
    
    dyn_string dss = strsplit(hostString, ".");
    host = dss[1];
    
    if(reduHostString != "")
    {
      dss = strsplit(reduHostString, ".");
      reduHost = dss[1];    
    }
    else
    {
      reduHost = "";
    }
  }
  host = strtoupper(host);
  reduHost = strtoupper(reduHost);
  
  return;
}

/** This function removes the given project paths from the config file.
 * @param (in) paths array of strings that contains the project paths to be removed from the config file.
 * @return 0
*/
int fwInstallation_deleteProjectPaths(dyn_string paths)
{
  for(int i = 1; i <= dynlen(paths); i++)
  { 
    fwInstallation_throw("fwInstallationDBAgent_synchronizeProjectPaths() -> Deleting project path from config file: " + paths[i], "info", 10);
    fwInstallation_removeProjPath(paths[i]);
  }
  
  return 0;
}

/** This function adds the given project paths to the config file.
 * @param (in) dbPaths array of strings that contains the project paths to be added to the config file.
 * @return 0
*/
int fwInstallation_addProjectPaths(dyn_string dbPaths)
{ 
  for(int i = 1; i <= dynlen(dbPaths); i++)
  { 
    fwInstallation_throw("fwInstallationDBAgent_synchronizeProjectPaths() -> Adding new project path to config file: " + dbPaths[i], "info", 10);
    fwInstallation_addProjPath(dbPaths[i], 999);
  }
  return 0;
}

/** This function returns the list of all installed WinCC OA versions on current machine.
 * @return list of all installed WinCC OA versions in a dyn_string
*/
dyn_string fwInstallation_getHostPvssVersions()
{
  dyn_string pvssVersions;
  
  if(_WIN32)
  {
    //Get the installed WinCC OA versions up to 3.13//Get the installed WinCC OA versions up to 3.13
    //32-bit hosts first:
    string key = "HKEY_LOCAL_MACHINE\\SOFTWARE\\ETM\\PVSS II";
    string res = fwInstallation_getWinRegKey(key);
    dyn_string values = strsplit(res, "\n");
    for(int i = 1; i <= dynlen(values); i++)
    {
      if(patternMatch(key + "\\*", values[i]))
      {
        strreplace(values[i], key + "\\", "");
        if(values[i] != "" && values[i] != "AutoStart" && values[i] != "Configs" && strtoupper(values[i]) != "CMF")
        {
          if(values[i] == VERSION)
            values[i] = VERSION_DISP;
          
          if (!dynContains(pvssVersions,values[i]))
            dynAppend(pvssVersions, values[i]);
        }
      }
    }
    

    //and now 64-bit hosts:
    key = "HKEY_LOCAL_MACHINE\\SOFTWARE\\Wow6432Node\\ETM\\PVSS II";
    res = fwInstallation_getWinRegKey(key);
    values = strsplit(res, "\n"); 
    for(int i = 1; i <= dynlen(values); i++)
    {
      if(patternMatch(key + "\\*", values[i]))
      {
        strreplace(values[i], key + "\\", "");
        if(values[i] != "" && values[i] != "AutoStart" && values[i] != "Configs" && strtoupper(values[i]) != "CMF")
        {
          if(values[i] == VERSION)
            values[i] = VERSION_DISP;
          if (!dynContains(pvssVersions,values[i]))
            dynAppend(pvssVersions, values[i]);
        }
      }
    }

    //Get the installed WinCC OA versions from 3.14 (FWINS-2050)
    key = "HKEY_LOCAL_MACHINE\\SOFTWARE\\ETM\\WinCC_OA";
    res = fwInstallation_getWinRegKey(key);
    values = strsplit(res, "\n"); 
    for(int i = 1; i <= dynlen(values); i++)
    {
      if(patternMatch(key + "\\*", values[i]))
      {
        strreplace(values[i], key + "\\", "");
        if(values[i] != "" && values[i] != "AutoStart" && values[i] != "Configs" && strtoupper(values[i]) != "CMF")
        {
          if(values[i] == VERSION)
            values[i] = VERSION_DISP;
          if (!dynContains(pvssVersions,values[i]))
            dynAppend(pvssVersions, values[i]);
        }
      }
    }
  }
  else
  {
    string tempFile = PROJ_PATH + "/rpmQuery.txt";
    system("rpm -qa | grep -i -e pvss -e wincc_oa > " + tempFile);
    
    string res = "";
    fileToString(tempFile, res);
    dyn_string values = strsplit(res, "\n");
    for(int i = 1; i <= dynlen(values); i++)
    {
      dyn_string ds = strsplit(values[i], "-");
      //version
      dyn_string ds2 = strsplit(ds[1], "_");
      string version = ds2[dynlen(ds2)];
      dyn_string ds3 = strsplit(ds[2], ".");
      
      //append the service pack if necessary:
      if(ds3[1] != "0") version = version + "-SP" + ds3[1];
      
      if(values[i] == VERSION)
         values[i] = VERSION_DISP;
      if (!dynContains(pvssVersions,values[i]))
        dynAppend(pvssVersions, version);
    }
  }
  return pvssVersions;

}

/** This function returns the next tier of subkeys of the specified key in the Windows registry.
 * @note It returns a single string that contains subkeys separated with newline character ("\n").
 * @param key (in) registry key that will be queried
 * @return string contains all subkeys of specified key
*/
string fwInstallation_getWinRegKey(string key)
{
  string res;  
  string tempFile = PROJ_PATH + "\\regquery.txt";
  
  system("cmd /c reg query \"" + key +"\" > " + tempFile);
  fileToString(tempFile, res);
  
  return res;
}

/** This function returns the list of pending postInstall scripts of the given component.
 * @param component (in) Name of the component.
 * @param reduHostNum (in) Local host redu number, default value (0) indicates that the number will be obtained automatically.
 * @return Array of strings that contains the names of pending postInstall scripts for the given component.
*/
dyn_string fwInstallation_getComponentPendingPostInstalls(string component, int reduHostNum = 0)
{
  dyn_string componentScripts;
  if(reduHostNum == 0) reduHostNum = fwInstallationRedu_myReduHostNum();
  
  dyn_string projectScripts = fwInstallation_getProjectPendingPostInstalls(reduHostNum);
  
  dpGet(fwInstallation_getComponentDp(component, reduHostNum) + ".postInstallFiles", componentScripts);
  dyn_string pendingPostInstalls =  dynIntersect(componentScripts, projectScripts);
  return pendingPostInstalls;
}

/** This function returns the list of pending postInstall scripts in the project.
 * @param reduHostNum (in) Local host redu number, default value (0) indicates that the number will be obtained automatically.
 * @return Array of strings that contains the names of pending postInstall scripts.
*/
dyn_string fwInstallation_getProjectPendingPostInstalls(int reduHostNum = 0)
{
  dyn_string scripts;
  
  if(reduHostNum == 0) reduHostNum = fwInstallationRedu_myReduHostNum();
  
  dpGet(fwInstallation_getInstallationPendingActionsDp(reduHostNum) + ".postInstallFiles", scripts);
  return scripts;
}

/** This function clears the global array of stings that contains fwInstallation log messages.
*/
void fwInstallation_resetLog()
{
  gFwInstallationLog = makeDynString();
}

/** This function returns the name of WinCC OA manager executable file.
 * @TODO Consider removing support for PVSS version older than 3.11 (PVSS00)
 * @param type (in) Type of manager (UI, CTRL, dist, etc., case insensitive)
 * @return Name of WinCC OA executable file (PVSS00 - obsolete, WCCOA or WCCIL + type) 
*/
string fwInstallation_getWCCOAExecutable(string type)
{
  string prefix = "PVSS00";

  if(VERSION_DISP != "3.6" &&
     VERSION_DISP != "3.6-SP2" &&
     VERSION_DISP != "3.8-SP2" &&
     VERSION_DISP != "3.8")  
  {
    if(strtolower(type) == "data" ||
       strtolower(type) == "event" ||
       strtolower(type) == "dist" ||
       strtolower(type) == "sim" ||
       strtolower(type) == "redu" ||
       strtolower(type) == "split" ||
       strtolower(type) == "proxy" ||
       strtolower(type) == "databg" ||
       strtolower(type) == "pmon" 
       )
    {
      prefix = "WCCIL";    
    }
    else
    {
      prefix = "WCCOA";
    }
  }
  
  return prefix + strtolower(type);
}

/** This function append a new log message to the fwInstallation log.
 * Logs are appended to the global array of logs and, if there is a connection, stored in the DB
 * @param msg (in) Log message
 * @param severity (in) Severity of the message
*/
void fwInstallation_appendLog(string msg, string severity)
{  
  if(myManType() == CTRL_MAN)
    msg = fwInstallation_getWCCOAExecutable("ctrl") + "(" + myManNum() + "): " + msg;
  else
    msg = fwInstallation_getWCCOAExecutable("ui") + "(" + myManNum() + "): " + msg;
    
  dyn_string log_line = makeDynString((string) getCurrentTime(), severity, msg);
  dynAppend(gFwInstallationLog, log_line);
  
  if(fwInstallationDB_isConnected())
    fwInstallationDB_storeInstallationLog();
}

/** This function deploys the crashAction script for the restart of the DB-Agent 
 *  of the Installation Tool when it gets blocked
 *
 * @return  0 if OK, -1 if error
*/
/*
int fwInstallation_deployCrashActionScript()
{
  string fw_installation_filename = PROJ_PATH +  BIN_REL_PATH;
  string filename = PROJ_PATH +  BIN_REL_PATH;
  
  //initialize   
  if(_WIN32)
  {
    filename += "crashAction.cmd";
    fw_installation_filename += "fwInstallation_crashAction.cmd";
  }
  else
  {
    filename += "crashAction.sh";
    fw_installation_filename += "fwInstallation_crashAction.sh";
  }
  
  if(access(filename, R_OK)) //the file does not exist or it is not readable. Just copy the new one
  {
    fwInstallation_throw("Copying the Crash Action Script for the DB-agent of the Component Installation Tool", "INFO", 10);
    if(fwInstallation_copyFile(fw_installation_filename, filename))
    {
      fwInstallation_throw("Failed to copy the Crash Action Script for the DB-agent of the Component Installation Tool");
      return -1;
    }
    system("chmod +x " + filename);    
    system("dos2unix " + filename);    
    system("dos2unix " + fw_installation_filename);    
  }  
  //if the file already exists, check if the necessary info for the installation tool is up-to-date  
  return fwInstallation_updateCrashActionScript(filename, fw_installation_filename);  
}
*/

/** This function checks and, if necessary, updates the crash action script of the Installation Tool
 *
 * @param filename name of the crash action script as expected by PMON, including the full path
 * @param fw_installation_filename name of the crash action script delievered with this version of the Installation Tool, including the full name
 * @return  0 if OK, -1 if error
*/

/*
int fwInstallation_updateCrashActionScript(string filename, string fw_installation_filename)
{
  string scriptContents;
  string fwInstallationScriptContents;
  dyn_string ds, dsInstallation;
  string beginTag = "::#Beginning FW_INSTALLATION#";
  string endTag = "::#End FW_INSTALLATION#";
  string versionTag = "::# Version:";
  string version = "";
  string versionInstallation = "";
  bool write = false;
  
  if(!_WIN32)
  {
    beginTag = substr(beginTag, 2, strlen(beginTag));
    endTag = substr(endTag, 2, strlen(endTag));
    versionTag = substr(versionTag, 2, strlen(versionTag));
  }
  
  fileToString(filename, scriptContents);
  fileToString(fw_installation_filename, fwInstallationScriptContents);
  
  ds = strsplit(scriptContents, "\n");
  dsInstallation = strsplit(fwInstallationScriptContents, "\n");

  int beginPos = dynContains(ds, beginTag); 
  int endPos = -1;
  if(beginPos > 0)
  {
    version = fwInstallation_getCrashActionScriptVersion(filename);
    versionInstallation = fwInstallation_getCrashActionScriptVersion(fw_installation_filename);
    if(version != versionInstallation)
    {
      fwInstallation_throw("Crash Action script for the Installation Tool needs to be udpate from version " 
                           + version + " to version " + versionInstallation, "INFO", 10);
      //find end tag:
      endPos = dynContains(ds, endTag);
      if(endPos > beginPos)
      {
        write = true;
        for(int z = endPos; z >= beginPos; z--)
        {
          dynRemove(ds, z);
        }
        dynAppend(ds, dsInstallation); 
      }
    }
  }

  if(write)
    if(fwInstallation_saveFile(ds, filename))
    {
      fwInstallation_throw("Failed to save the crashAction script");
      return -1;
    }
  
  if(!_WIN32)
  {
    system("chmod +x " + filename);    //make sure the file is executable
    system("dos2unix " + filename);    
    system("dos2unix " + fw_installation_filename);    
  }
 
  return 0;
}
*/

/** This function returns the version of a crash action script
 *
 * @param filename name of the file containing the crash action script
 * @return  version of the script as a string
*/
/*
string fwInstallation_getCrashActionScriptVersion(string filename)
{
  string scriptContents;
  dyn_string ds;
  string beginTag = "::#Beginning FW_INSTALLATION#";
  string versionTag = "::# Version:";
  
  if(!_WIN32)
  {    
    beginTag = substr(beginTag, 2, strlen(beginTag));
//    endTag = substr(endTag, 2, strlen(endTag));
    versionTag = substr(versionTag, 2, strlen(versionTag));
  }
  
  fileToString(filename, scriptContents);
  
  ds = strsplit(scriptContents, "\n");
  int beginPos = dynContains(ds, beginTag); 
  if(beginPos > 0)
  {
    for(int i = beginPos; i <= dynlen(ds); i++)
    {
      if(patternMatch(versionTag + "*", ds[i]))
      {
        //Check the version
        string version = ds[i];
        strreplace(version, versionTag, "");
        strreplace(version, " ", "");
        strreplace(version, "\n", "");
        return version;
      }
    }//end of loop
  }  
  
  return "";
}
*/

/** Checks if a particular patch has been applied to the current installation
 *
 * @param patch patch name
 * @return  0 if the patch is not present
            1 if the patch has been applied
*/
bool fwInstallation_isPatchInstalled(string patch)
{
  dyn_string patches;
  fwInstallation_getPvssVersion(patches);
  
  return dynContains(patches, patch);
}

/** Check if the PVSS version is equal or newer than the required PVSS version passed as argument
 *
 * @param reqVersion required PVSS version
 * @return  2 if current PVSS version is greater than the required one.
            1 if current and required PVSS versions are equal.
            0 if the required version is greater than the current one.

*/
int fwInstallation_checkPvssVersion(string reqVersion)
{
  int reqMajor, reqMinor, reqSP;
  int currMajor, currMinor, currSP;
  
  float fReqVersion = fwInstallation_pvssVersionAsFloat(reqVersion, reqMajor, reqMinor, reqSP);
  float fCurrVersion = fwInstallation_pvssVersionAsFloat(VERSION_DISP, currMajor, currMinor, currSP);

  if(fReqVersion > fCurrVersion)
    return 0;
  else if(fReqVersion == fCurrVersion) 
    return 1;
  
  return 2;
}
/** Checks if the version of the FW Component Installation Tool is equal or newer than the required PVSS version passed as argument
 *
 * @param reqVersion required version of the FW Component Installation Tool
 * @return  2 if current Tool version is greater than the required one.
            1 if current and required Tool versions are equal.
            0 if the required version is greater than the current one.

*/
int fwInstallation_checkToolVersion(string reqVersion)
{
  int reqMajor, reqMinor, reqSP;
  int currMajor, currMinor, currSP;
  
  float fReqVersion = fwInstallation_stringVersionAsFloat(reqVersion, reqMajor, reqMinor, reqSP);
  float fCurrVersion = fwInstallation_stringVersionAsFloat(csFwInstallationToolVersion, currMajor, currMinor, currSP);

  if(fReqVersion > fCurrVersion)
    return 0;
  else if(fReqVersion == fCurrVersion) 
    return 1;
  
  return 2;
}

/** Converts a Component or Tool version from string to float for easy comparison
 *
 * @param  reqVersion - (in) name of the pvss version
 * @param  version - (out) number corresponding to the version of the release
 * @param  major - (out) number corresponding to the major version of the release
 * @param  minor - (out) number corresponding to the minor version of the release
 * @return  pvss version as a float
*/
float fwInstallation_stringVersionAsFloat(string reqVersion, int &version, int &major, int &minor)
{
  dyn_string ds2 = strsplit(reqVersion, ".");

  version = 0;
  major = 0;
  minor = 0;
  
  version = (int)ds2[1];
  if(dynlen(ds2) >= 2)
    major = (int)ds2[2];
  if(dynlen(ds2) >= 3)
    minor = (int)ds2[3];
  
  return version* 1000000. + major * 1000. + minor;
}
/** Converts a PVSS version from string to float for easy comparison
 *
 * @param  reqVersion - (in) name of the pvss version
 * @param  major - (out) number corresponding to the major version of the release
 * @param  minor - (out) number corresponding to the minor version of the release
 * @param  sp - (out) number corresponding to the Service Pack of the release
 * @return  pvss version as a float
*/
float fwInstallation_pvssVersionAsFloat(string reqVersion, int &major, int &minor, int &sp)
{
  dyn_string ds = strsplit(reqVersion, "-");
  dyn_string ds2 = strsplit(ds[1], ".");

  major = 0;
  minor = 0;
  sp = 0;
  
  major = (int)ds2[1];
  if(dynlen(ds2) >= 2)
    minor = (int)ds2[2];
  
  if(dynlen(ds) >= 2)
  {
    string str = substr(ds[2], 2, (strlen(ds[2])-2));
    sp = (int)str;
  }
  
  return major * 1000. + minor + sp/100.;
}

/** Gets the properties of a particular PVSS system as a dyn_mixed
 *
 * @param  systemName - (in) name of the pvss system
 * @param  pvssSystem - (out) properties of the system
 * @return  0 if everything OK, -1 if errors
*/
int fwInstallation_getPvssSystemProperties(string systemName, dyn_mixed &pvssSystem)
{
  
  pvssSystem[FW_INSTALLATION_DB_SYSTEM_NAME] = systemName;
  pvssSystem[FW_INSTALLATION_DB_SYSTEM_NUMBER] = getSystemId();
  pvssSystem[FW_INSTALLATION_DB_SYSTEM_DATA_PORT] = dataPort();
  pvssSystem[FW_INSTALLATION_DB_SYSTEM_EVENT_PORT] = eventPort();
  pvssSystem[FW_INSTALLATION_DB_SYSTEM_PARENT_SYS_ID] = -1; 
  dyn_string evHosts = eventHost();
  
  pvssSystem[FW_INSTALLATION_DB_SYSTEM_COMPUTER] = strtoupper(evHosts[1]);

  int distPort = fwInstallation_getDistPort();
  int reduPort = fwInstallation_getReduPort();
  int splitPort = fwInstallation_getSplitPort();  
  pvssSystem[FW_INSTALLATION_DB_SYSTEM_DIST_PORT] = distPort;
  pvssSystem[FW_INSTALLATION_DB_SYSTEM_REDU_PORT] = reduPort;
  pvssSystem[FW_INSTALLATION_DB_SYSTEM_SPLIT_PORT] = splitPort;  
  
  return 0;
}

/** Throws a PVSS error in the log 
 * @param  msg - (in) error message
 * @param  severity - (int) severity of the message: ERROR, WARNING, INFO
 * @param  code - (int) code of the error message in the fwInstallation catalog
*/
void fwInstallation_throw(string msg, string severity = "ERROR", int code = 1)
{
  int prio = PRIO_WARNING; 
  int type = ERR_CONTROL;
  
  switch(strtoupper(severity))
  {
    case "INFO": prio = PRIO_INFO; 
      if(code ==1) 
        code =10; 
      
      break;
    case "WARNING": prio = PRIO_WARNING; break;
    case "ERROR": prio = PRIO_SEVERE; break;
  }
  
  errClass err = makeError("fwInstallation", prio, type, code, msg);
  throwError(err);

  if(dynlen(dynPatternMatch("fwInstallation_throw(*", getStackTrace())) > 1)
  {//detect recursive call of fwInstallation_throw() (FWINS-1888)
    throwError(makeError("fwInstallation", PRIO_WARNING, ERR_CONTROL, 1, "Detected recursive call " +
                         "of fwInstallation_throw() function. There is a problem with DB connection. " +
                         "Cannot write log message: " + msg + " to the DB"));
    return;
  }

  fwInstallation_reportInstallationMessage(err);
  if(fwInstallationDB_getUseDB() && fwInstallationDB_isConnected())
  {
    fwInstallation_appendLog(msg, strtoupper(severity));
  }
  
  return;
}

/** Return data point for value indicating
 * if restart is needed before running
 * post install scripts. 
 *  
 * @return value of type 'string' data point (element) if
 * restart is needed.
 */
string fwInstallation_getAfterInitRestartNeededDpElem()
{
  return "postInitRestartNeeded";
}

/** Return data point for value containing
 * component that requested project restart.
 * Data point contains only the last component
 * requesting the restart. 
 *  
 * @return value of type 'string' Data point pointing to
 * project restart requester (component name).
 */
string fwInstallation_getAfterInitRestartRequesterDpElem()
{
  return "postInitRestartRequester";
}

/** Request project restart after component installation, but
 * before running postInstall scripts.
 * 
 * This function will set requester to a datapoint which later
 * be used to issue a project request.
 *  
 * @param requester	(string)	IN 	component requesting project restart.
 * @return value of type 'int' 0 if request is successful, otherwise -1.
 */
int fwInstallation_requestProjectRestartAfterInit(string requester)
{
  int retVal = -1;

  // TODO: get real datapoints here
  string requesterDp = fwInstallation_getAgentDp() + "." + fwInstallation_getAfterInitRestartRequesterDpElem();
  string restartDp = fwInstallation_getAgentDp() + "." + fwInstallation_getAfterInitRestartNeededDpElem();
  
   // Remember requester
  if(dpSetWait(requesterDp, requester) == 0)
  {
    // Issue an restart after init scripts
    if(dpSetWait(restartDp, 1) == 0)
    {
      retVal = 0;
    }
  }

  return retVal;
}

/** Clear data point that will cause project restart
 * after init scripts (before post install scripts). 
 *  
 * @return value of type 'int' 0 - success clearing project
 * restart request, -1 - failure to clear restart request.
 */
int fwInstallation_clearProjectRestartAfterInit()
{
  int retVal = -1;
  
  string restartDp = fwInstallation_getAgentDp() + "." + fwInstallation_getAfterInitRestartNeededDpElem();
  
  if(dpSetWait(restartDp, 0) == 0)
  {
    retVal = 0;
  }
  
  return retVal;
}

/** Return if project should be restarted after init
 * scripts were executed. 
 *  
 * @return value of type 'int' 1 - project should be
 * restarted after init scripts, 0 - project should NOT
 * be restarted after init scripts.
 */
int fwInstallation_isProjectRestartAfterInitPending()
{
  string restartDp = fwInstallation_getAgentDp() + "." + fwInstallation_getAfterInitRestartNeededDpElem();
  
  int restartPending;
  dpGet(restartDp, restartPending);
  
  return restartPending;
}

/** Order the dpl files of a component according to the attributes defined in the XML file
 * @param  files - (in) files to the ordered as a dyn_string
 * @param  attribs - (int) XML attributes for the files ordered as the 'files' argument
 * @return  ordered list of the files according to the attribs values
*/
dyn_string fwInstallation_orderDplFiles(dyn_string files, dyn_int attribs)
{
  dyn_string orderedFiles;
  dyn_string ds;

  //find those files having an attributed specified and build ds array with only them:
  for(int i = 1; i <= dynlen(files); i++)
    if(attribs[i] > 0)
      ds[attribs[i]] = files[i]; 
  
  //now append files with no attribute defined:
  for(int i = 1; i <= dynlen(files); i++)
    if(dynContains(ds, files[i]) <= 0)
      dynAppend(ds, files[i]); 
  
  //Now remove empty/non-initialized elements that there could be in ds array
  for(int i = 1; i <= dynlen(ds); i++)
    if(ds[i] != "")
      dynAppend(orderedFiles, ds[i]); 

  return orderedFiles;
}

/** This functions is to be called from the close event of a panel. 
    It checks whether the connection with the event manager is established or not. 
    If the connection is down, the function will call exit() to close the actual panel.
    If the connection is to the event manager is still up, the calling code can decide
    whether the panel must closed or not. This is done through the argument closeIfConnected.
    Typically the argument will be set to false in the cases where the developer wants to prevent
    that the user closes the panel by clicking on the top-right 'x' of the window.

  @param closeIfConnected: (boolean) Defines whether the current panel has to be close if the 
                         connection to the event manager is still up. The default value is false
                         (i.e. the function will not close the panel) 
  @return 0 - success,  -1 - error 
  @author F. Varela 
*/
int fwInstallation_closePanel(bool closeIfConnected = false) 
{
  dyn_anytype da, daa;
  da[1]  = myModuleName();     
  da[2]  = myPanelName();
  daa[1] = 0.0; daa[2] = "FALSE"; // Return value optional  
  da[3] = daa;                    // dyn_anytype binding

  if(!isEvConnOpen()) 
    return panelOff(da);
  else if(closeIfConnected)
    PanelOff();

  return 0;
}


/** Retrieves the name of a host without network domain
   @param hostName name of the host to parse; when empty - the local host
 * @return  name of the  host as string
*/
string fwInstallation_getHostname(string hostName = "")
{
  string host = hostName == "" ? getHostname() : hostName ;
  dyn_string ds = strsplit(host, ".");
  
  return ds[1];
}

/** Gets the name of the internal datapoint of the Installation Tool
 * @return  dp name as string
*/
string fwInstallation_getInstallationDp()
{
  string dp;
  
//  if(fwInstallationRedu_myReduHostNum() > 1)
//    dp = "fwInstallationInfo_" + fwInstallationRedu_myReduHostNum();
//  else
    dp = "fwInstallationInfo";

  return dp;
}

/** Get file issues sychronization enable/disable data point element.
  @return name of data point element for file issues synchronization enabled/disabled.
*/
string fwInstallation_getFileIssuesSyncDpElem()
{
  string dp;
  
  dp = "fileIssuesSyncDisabled";
  
  return dp;
}

/** Returns wether the DB-agent must delete or not from the project config file during synchronization with the System Configuration DB
 * @return  True is deletions must be carried out, FALSE if deletion is inhibited.
*/
bool fwInstallation_deleteFromConfigFile()
{
  bool edit = false;
  string dp = fwInstallation_getInstallationDp();
  
  dpGet(dp + ".deleteFromConfigFile", edit);
  
  return edit; 
}

/** Function used to flag deprecated functions in the library
 * @param deprecated name of the deprecated function
 * @param toBeUsed name of the function to be used instaed. If an empty argument is passed, a 
 *                 different message will be shown, telling that the user must report its usage.
*/
void fwInstallation_flagDeprecated(string deprecated, string toBeUsed = "")
{
  string str = gFwInstallationCurrentComponent + " Function :" + deprecated +" is deprecated and may eventually disappear.";
  
  if(toBeUsed != "")
    str += " Please use " + toBeUsed + " instead.";
  else
    str += " Should you be using it, please, reported to IceControls.Support@cern.ch";
  
  fwInstallation_throw(str, "WARNING", 11);
  
  return;
    
}

/** Function during the installation of the components to resolve the right name for a file depending on the current PVSS version
 * @param baseFileName (in) base name of the file
 * @param targetVersions (in) name of the target PVSS version
 * @param considerSpLevel (in) argument that defines whether the Service Pack level has to be also taken into account
 * @return final name of the file matching the target pvss version
*/
string fwInstallation_findFileForPvssVersion(string baseFileName, dyn_string targetVersions = makeDynString(), bool considerSpLevel = FALSE)
{
  bool matchingVersion = FALSE;
  string localFileName = "", currentVersion;
    
  //get current VERSION of VERSION_DISP (DISP includes Service Pack level)
  currentVersion = considerSpLevel?VERSION_DISP:VERSION;
  
  //if target versions specified, check if current version matches the pattern of any target version
  //if not, then assume that current version is a valid target version
  if(dynlen(targetVersions) == 0)
    matchingVersion = TRUE;
  else
  {      
    //search for pattern in target versions that matches current PVSS version
    for(int i=1; i<=dynlen(targetVersions) && !matchingVersion; i++)
      matchingVersion = patternMatch(targetVersions[i], currentVersion);
  }
    
  //if current PVSS version is a valid target version then try to search for the specified file
  if(matchingVersion)
  {
    //substitute the keyword with the current PVSS version, if no keyword, simply append version to file name
    if(strpos(baseFileName, fwInstallation_VERSION_KEYWORD) >= 0)
      strreplace(baseFileName, fwInstallation_VERSION_KEYWORD, currentVersion);
    else
      baseFileName += currentVersion;

    //search for file in all PVSS paths, return highest level file found
    localFileName = getPath("", baseFileName);
  }
  
  return localFileName;
}

/** Execute command and read the output. Note that a command should be prepared in
  such way that it is possible to redirect its output to a file. Redirection is
  automatically added by this function. Output is redirected to a temporary file
  which is later removed.
  @param command - command to execute, note that redirection is automatically added ("> tempfile").
  @param systemExecResult - where to store output from command execution.
  @param trim - should the result be trimmed (left/right).
  @return Returns 0 on success, -1 on error.
*/
int _fwInstallation_getStringFromSystemCommand(string command, string &systemExecResult, bool trim=false)
{
  bool error = true;

  string tempFile = tmpnam();
  // On occassion tmpnam() returns empty string? A bug? In such casee create our own temporary name 
  if(tempFile == "")
  {
    tempFile = getPath(DATA_REL_PATH) + "/tmpfwInstallation" + period(getCurrentTime()) + "_" + milliSecond(getCurrentTime()) + "_" + getThreadId() + "_" + rand() + ".txt";
  }

  string fullCommand = command + " > " + tempFile;
  int retCode = system(fullCommand);

  if(retCode != -1)
  {
    if(fileToString(tempFile, systemExecResult))
    {
      if(trim)
      {
        systemExecResult = strltrim(strrtrim(systemExecResult));
      }
      error = false;
    }
  }

  if(isfile(tempFile))
  {
    remove(tempFile);
  }

  if(error)
  {
    return -1;
  }

  return 0;
}

/** Return memory size in bytes.
  @param memSizeInBytes - return value, memory size in bytes.
  @return 0 on success, -1 on failure.
*/
int fwInstallation_getHostMemorySize(string &memSizeInBytes)
{
  string command;

  if(_WIN32)
  {
    // A bit hacky but should work for Windows Vista and up
    command = "cmd.exe /c @for /f \"skip=2 tokens=2 delims==\" %p in ('wmic os get TotalVisibleMemorySize /format:list') do @echo %p";
  }
  else // Not Windows = Linux
  {
    command = "free -b | grep Mem: | cut -f5 -d' '";
  }

  if(_fwInstallation_getStringFromSystemCommand(command, memSizeInBytes, true) != 0)
  {
    fwInstallation_throw("Couldn't get host memory information", "ERROR", 10);
    return -1;
  }

  return 0;
}

/** Return CPU information.
  @param cpuInfo - return CPU information, ex. "".
  @return 0 on success, -1 on failure.
*/
int fwInstallation_getHostCpuInfo(string &cpuInfo)
{
  string command = "";

  if(_WIN32)
  {
    // A bit hacky but should work for Windows Vista and up
    command = "cmd.exe /c @for /f \"skip=2 tokens=2 delims==\" %p in ('wmic cpu get name /format:list') do @echo %p";
  }
  else
  {
    command = "grep -m 1 \"model name\" /proc/cpuinfo | cut -f2 -d\":\"";
  }

  if(_fwInstallation_getStringFromSystemCommand(command, cpuInfo, true) != 0)
  {
    fwInstallation_throw("Couldn't get CPU information", "ERROR", 10);
    return -1;
  }

  return 0;
}

/** Returns packages installed on an RPM based Linux system.
  Note that an argument (grepExpression) is passed to filter out
  interesting packages out of all installed packages, filter is
  case insensitive.
  @param grepExpression grep expression to filter out packages.
  @param packages output string receiving comma separated list of packages.
  @return 0 on success, -1 on error.
*/
int fwInstallation_getLinuxInstalledPackages(string grepExpression, string &packages)
{
  string command = "rpm -qa | grep -i " + grepExpression + " | sort -r";
  if(_fwInstallation_getStringFromSystemCommand(command, packages) == 0)
  {
    if(packages == "")
    {
      // TODO: remove in future
      //fwInstallation_throw("There seem not to be any requested packages installed (" + grepExpression +
      //                     ", is this Linux distribution supported /not rpm based?/)?", "WARNING", 10);
      packages = "(none)";
    }
    else
    {
      packages = strltrim(strrtrim(packages, "\n"), "\n");
      strreplace(packages, "\n", ",");
    }
  }
  else
  {
    fwInstallation_throw("Couldn't get packages list (command: " + command + ").");
    return -1;
  }
  
  return 0;
}

/** Get list of installed FMC.
  @param packages variable to receive comma separated list of FMC packages.
  @return 0 on success, -1 on error.
*/
int fwInstallation_getFMCInstalledPackages(string &packages)
{
  bool error = true;
  
  if(_WIN32)
  {
    packages = "?"; // Windows not yet supported
    error = false; // Do not report problems if not supported (creates spam in log)
  }
  else if(fwInstallation_getLinuxInstalledPackages("fmc", packages) == 0)
  {
    error = false;
  }
  
  if(error)
  {
    fwInstallation_throw("Couldn't get installed FMC packages", "ERROR", 10);
    return -1;
  }

  return 0;
}

/** Get list of installed WinCC OA packages (also inclused PVSS packages).
  @param packages variable to recieve comma separated list of WinCC OA/PVSS packages.
  @return 0 on success, -1 on error.
*/
int fwInstallation_getWCCOAInstalledPackages(string &packages)
{
  bool error = true;
  
  if(_WIN32)
  {
    packages = "?"; // Windows not yet supported
    error = false; // Do not report problems if not supported (creates spam in log)
  }
  else if(fwInstallation_getLinuxInstalledPackages("-e pvss -e wincc_oa", packages) == 0)
  {
    error = false;
  }
  
  if(error)
  {
    fwInstallation_throw("Couldn't get installed WinCCOA packages", "ERROR", 10);
    return -1;
  }

  return 0;
}


/** Function to retrieve host properties as a dyn_mixed array
 * @param hostname (int) name of the host
 * @param pvssHostInfo (out) host properties
 * @return 0 if OK, -1 if errors
*/
int fwInstallation_getHostProperties(string hostname, dyn_mixed &pvssHostInfo)
{
  dyn_string pvssIps;
  
  hostname = strtoupper(hostname);
  pvssHostInfo[FW_INSTALLATION_DB_HOST_NAME_IDX] = hostname;  
  pvssHostInfo[FW_INSTALLATION_DB_HOST_IP_1_IDX] = getHostByName(hostname, pvssIps); 
  
  //assign pvssIps to ... 
  if(dynlen(pvssIps) && pvssHostInfo[FW_INSTALLATION_DB_HOST_IP_1_IDX] == "")
    pvssHostInfo[FW_INSTALLATION_DB_HOST_IP_1_IDX] = pvssIps[1];
       
  if(dynlen(pvssIps) > 1)
    pvssHostInfo[FW_INSTALLATION_DB_HOST_IP_2_IDX] = pvssIps[2];
  
  // WinCC OA/PVSS packages
  string packages = "?";
  fwInstallation_getWCCOAInstalledPackages(packages);
  pvssHostInfo[FW_INSTALLATION_DB_HOST_WCCOA_INSTALL_PKG_IDX] = packages;
  packages = "?";
  fwInstallation_getFMCInstalledPackages(packages);
  pvssHostInfo[FW_INSTALLATION_DB_HOST_FMC_INSTALL_PKG_IDX] = packages;
  
  // CPU & memory information
  string hwInfo = "?";
  fwInstallation_getHostCpuInfo(hwInfo);
  pvssHostInfo[FW_INSTALLATION_DB_HOST_CPU_INFO_IDX] = hwInfo;
  hwInfo = "0";
  fwInstallation_getHostMemorySize(hwInfo);
  pvssHostInfo[FW_INSTALLATION_DB_HOST_MEM_SIZE_IDX] = hwInfo;

  return 0;
}  

/** Function to move files into the trash
 * @param filename (in) name of the file to be moved
 * @param trashPath (in) path to the trash. Empty path means use the default path
 * @return 0 if OK, -1 if errors
*/
int fwInstallation_sendToTrash(string filename, string trashPath = "")
{
  if(filename == "")
  {
    fwInstallation_throw("fwInstallation_sendToTrash()-> Empty file name, cannot send file to trash.", "ERROR", 1);
    return -1;
  }
  string trashedName = _fwInstallation_fileName(filename) + formatTime(".%Y_%m_%d_%H_%M", getCurrentTime());

  if(trashPath == "")
    trashPath = gFwTrashPath;
  else
    trashPath += "/fwTrash/";

  if(access(trashPath, W_OK) && !mkdir(trashPath))
  {
    fwInstallation_throw("fwInstallation_sendToTrash()-> Could not create trash folder. File cannot be sent to trash.", "ERROR", 1);
    return -1;
  }

  return !moveFile(filename, trashPath + trashedName);
}

/** Empty the trash of the FW Component Installation Tool
 * @param path (in) path to the trash. Empty path means use the default path
 * @return 0 if OK, -1 if errors
*/
int fwInstallation_emptyTrash(string path = "")
{
  int err = 0;
  if(path == "")
    path = gFwTrashPath;
  else
    path += "/fwTrash/";
  
  dyn_string files = getFileNames(path);

  for(int i = 1; i <= dynlen(files); i++)
  {
    if(remove(path + files[i]))
      ++err;
  }
  if(err)
    return -1;
    
  return 0;  
}


////
/** Function to make a binary comparison of two files. Contribution from TOTEM.
 * @param filename1 (in) name of the first file for comparison
 * @param filename2 (in) name of the second file for comparison
 * @return true if the two files are identical, false if the files are different
 * 
*/
bool fwInstallation_fileCompareBinary(string filename1, string filename2)
{
   if (!isfile(filename1)||!isfile(filename2))
   {
       return false;
   }

   if (getFileSize(filename1)!=getFileSize(filename2))
   {
     return false;
   }

   file f1, f2;
   int size=1024;
   int c1, c2;
   blob b1, b2;

   //opens a file for reading in the binary mode rb
   f1 = fopen(filename1, "rb");
   f2 = fopen(filename2, "rb");

     bool result = true;
   while (true)
   {
     if (feof(f1)!=0) {break;}
     if (feof(f2)!=0) {break;}

     c1 = blobRead(b1, size, f1);
     c2 = blobRead(b2, size, f2);

     if (c1!=c2) {result=false;}
     if (b1!=b2) {result=false;}
   }

   fclose(f1);
   fclose(f2);

   return result;
}

/** This function unlinks a file under Linux and then overwrites it.
 * @param source (in) name of the file to be copied
 * @param destination (in) target file name including full path
 * @param trashPath (in) path to trash
 * @param compare (in) argument used to compare files before copying. If files are identical the file is not re-copied.
 * @return 0 if OK, -1 if errors
 * 
*/
int fwInstallation_safeFileOverwrite(string source, string destination, string trashPath = "", bool compare = true)
{
  if(!_WIN32)
  {
    system("/bin/unlink " + destination);
  }
  
  return fwInstallation_copyFile(source, destination, trashPath, compare);
}

/** Function to copy files. If blind copy fails (e.g. an executable is in used), the 
 *  function will try to rename the existing file and only then copy the file once again.
 * @param source (in) name of the file to be copied
 * @param destination (in) target file name including full path
 * @param trashPath (in) path to trash
 * @param compare (in) argument used to compare files before copying. If files are identical the file is not re-copied.
 * @return 0 if OK, -1 if errors
 * 
*/
int fwInstallation_copyFile(string source, string destination, string trashPath = "", bool compare = true)
{
  time t = getCurrentTime();
  
  if(compare)
  {
    if(fwInstallation_fileCompareBinary(source, destination)) //if files are binary identical, do not copy them
      return 0;
  }

  //if linux and trying to copy an .so, unlink the file prior to the copy so that all running processes are happy.
  if(!_WIN32 && patternMatch("*.so", source))
  {
    if(access(destination, F_OK) == 0) system("/bin/unlink " + destination);
  }
  
  if(!copyFile(source, destination))
  {    
    if(access(destination, F_OK) == 0)
    {
      fwInstallation_throw("INFO: fwInstallation_copyFile() -> Renaming old file before trying to copy new one....", "INFO", 10);
      //File already exists, move it to trash first and then try to copy the new file:
      if(fwInstallation_sendToTrash(destination, trashPath))
      {
        fwInstallation_throw("fwInstallation_copyFile() -> Could not move previous version of the file in target directory: " + destination, "error", 4);
        return -1; 
      }
  
      if(!copyFile(source, destination))
      {
        fwInstallation_throw("fwInstallation_copyFile() -> Could not copy file from: " + source + " to: " + destination, "error", 5);
        //put old file back:
        //moveFile(destination + "." + str, destination);    
        return -1;
      }      
      else
        fwInstallation_throw("INFO: fwInstallation_copyFile() -> File successfully copied: " + destination, "info", 10);
    }
    else
    {
        fwInstallation_throw("fwInstallation_copyFile() -> Could not copy file from: " + source + " to: " + destination, "error", 5);
        return -1;
    }
  }
  
  return 0;
}
        
/** This function registers a PVSS project path
  @note Registered project paths can be found in pvssInst.conf file (usually C:\ProgramData\Siemens\WinCC_OA\pvssInst.conf or /etc/opt/pvss/pvssInst.conf)
  @param sPath: (in) path to be registered as string
  @return 0 if success,  -1 if error 
  @author F. Varela 
*/
int fwInstallation_registerProjectPath(string sPath)
{
  fwInstallation_normalizePath(sPath);
  string projName = _fwInstallation_fileName(sPath);
  if(strrtrim(sPath, " /.") == "" || projName == "")
  {
    if(myManType() == UI_MAN )
      ChildPanelOnCentralModal("vision/MessageInfo1", "ERROR", "$1:Project registration error.\nEmpty path or project name");
    else
      fwInstallation_throw("Project registration error.\nEmpty path or project name");
    return -1;
  }
  //Check if path exists:
  if(!isdir(sPath) && !mkdir(sPath)) //if directory does not exist, create it now
  {
    fwInstallation_throw("Path registration failed. Given path does not exists and creation of directory failed.");
    return -1;
  }
  int iPmonPort;
  string remoteHost;
  int iErr = paRegProj(projName, _fwInstallation_baseDir(sPath), remoteHost, iPmonPort, true, false);
/*
  if ( iErr )
  {
    if(myManType() == UI_MAN)
      ChildPanelOnCentralModal("vision/MessageInfo1", "ERROR", "$1:Path registration failed.");
    else
      fwInstallation_throw("Path registration failed.");

    return -1;
  }
*/
  return 0;
}

/** This function retrieves the version of an installed component
  @param component (in) name of the component
  @return component version as string
*/
string fwInstallation_getComponentVersion(string component, int reduHostNum = 0)
{
  string version;
  if(reduHostNum == 0) reduHostNum = fwInstallationRedu_myReduHostNum();  
  fwInstallation_isComponentInstalled(component, version, reduHostNum);
    
  return version;
}

/** This function checks if a component is installed in the current project.
	Returns true if component is installed and its version is succesfully retrieved.
	If component is not installed or retrieving component version failed, "version" is set to empty.
  @param component (in) name of the component
  @param version (out) current version of the installed component
  @return true if the component is installed, false otherwise
*/
bool fwInstallation_isComponentInstalled(string component, string &version, int reduHostNum = 0)
{
  dyn_anytype componentInfo;
  
  if(reduHostNum == 0)
  {
    reduHostNum = fwInstallationRedu_myReduHostNum();
  }
  
  if(!dpExists(fwInstallation_getComponentDp(component, reduHostNum)))
  {
    version = "";  
    return false;  
  }
  else 
  {
    if(fwInstallation_getComponentInfo(component, "componentversionstring", componentInfo, reduHostNum) != 0)
    {
      fwInstallation_throw("fwInstallation_isComponentInstalled() -> Could not retrieve the version of component: " + component); 
      version = "";
      return false;
    }
    
    if(dynlen(componentInfo))
    {
      version = componentInfo[1];
    }
    else
    {
      version = "";
    }
  }
    
  return true;
}

/** This function retrieves the source directory from which a component was installed
  @param component (in) name of the component
  @param sourceDir (out) source directory
  @return 0 if everything OK, -1 if errors.
*/
int fwInstallation_getComponentSourceDir(string component, string &sourceDir)
{
  dyn_anytype componentInfo;
  
  if(fwInstallation_getComponentInfo(component, "sourceDir", componentInfo ) != 0)
  {
    fwInstallation_throw("fwInstallation_getComponentSourceDir() -> Could not retrieve the source directory of component: " + component); 
    return -1;
  }
  
  if(dynlen(componentInfo))
    sourceDir = componentInfo[1];
  else
    sourceDir = "";
  
  return 0;
}

/** This function returns the name of a component correspoding to an internal dp of the installation tool
  @param dp (in) name of the dp of the installation tool
  @return name of the component
*/
string fwInstallation_dp2name(string dp)
{
  
  //remove system name
  if(strpos(dp, ":") > 0)
    strreplace(dp, getSystemName(), "");

  //remove fwInstallation prefix  
  strreplace(dp, "fwInstallation_", "");

  //remove _2 if it exists  
  if(strpos(dp, "_1") > 0){
    dp = substr(dp, 0, strpos(dp, "_1"));
  }
  if(strpos(dp, "_2") > 0){
    dp = substr(dp, 0, strpos(dp, "_2"));
  }
  return dp;
}

/** This function updates the internal dp-type used by the installation tool for the components
*/
fwInstallation_updateComponentDps()
{
  string name;
  dyn_string compDps = fwInstallation_getInstalledComponentDps();
  
  for(int z = 1; z <= dynlen(compDps); z++)
  {
    dpGet(compDps[z] + ".name", name);
                  
    if(name != fwInstallation_dp2name(compDps[z]))
      dpSet(compDps[z] + ".name", fwInstallation_dp2name(compDps[z]));
  }
}


/** This function adds the main libraries of the installation tool to the config file of the project
*/
void fwInstallation_addLibToConfig()
{
  dyn_string libs;
  
	paCfgReadValueList(PROJ_PATH + CONFIG_REL_PATH + "config", "ui", "LoadCtrlLibs", libs);
	if(dynContains(libs, "fwInstallation.ctl") == 0)
		paCfgInsertValue(PROJ_PATH + CONFIG_REL_PATH + "config", "ui", "LoadCtrlLibs", "fwInstallation.ctl");		

	paCfgReadValueList(PROJ_PATH + CONFIG_REL_PATH + "config", "ctrl", "LoadCtrlLibs", libs);
	if(dynContains(libs, "fwInstallation.ctl") == 0)
		paCfgInsertValue(PROJ_PATH + CONFIG_REL_PATH + "config", "ctrl", "LoadCtrlLibs", "fwInstallation.ctl");		
}

/** This function updates the main dp-type (FwInstallationInformation) of the installation tool from previous versions
  @return 0 if OK, -1 if errors
*/
int fwInstallation_updateDPT()
{
  string dp = fwInstallation_getInstallationDp();

  //check pending post-installs and post-delete scripts from old dptype:
  fwInstallation_updatePendingInstallationActions();
  
  string probeDp = "fw_InstallationProbing";
  probeDp = fwInstallationRedu_getLocalDp(probeDp);
  dpCreate(probeDp,"_FwInstallationComponents");	
  
  int count = 0;
  while(!dpExists(probeDp))
  {
    delay(0, 100);
    count++;
    if(count == 300)
      fwInstallation_throw("Failed to create internal fwInstallation probe component dp: " + dp + " for 30 seconds. Cannot continue. Please kill the UI and check para privledges or contact support" , "ERROR");
  }
  
  // If there was a change in data point structure, update it here
  string newDp = fwInstallation_getAgentDp() + "." + fwInstallation_getAfterInitRestartNeededDpElem();
  if(!dpExists(newDp))
  {
    int dpCreateResult = 0;
    _fwInstallation_createDataPointTypes(FALSE, dpCreateResult); //Not up-to-date: Update dpts now
    _fwInstallation_createAgentDataPointType("_FwInstallation_agentParametrization", true);
    if(dpCreateResult)
      return -1;

    // Set initial value to new data point (restart after init scripts).
    fwInstallation_clearProjectRestartAfterInit();

    dyn_string protectedManagers;
    _fwInstallationManager_getManagersProtectedFromStopping(protectedManagers);
    if (dynlen(protectedManagers) == 0)
    {
      //initialize the protected managers
      protectedManagers = makeDynString("-m gedi", "-f pvss_scripts.lst", "-f fwInstallationAgent.lst", "-p fwInstallation/fwInstallation.pnl",
                                                 "fwInstallationFakeScript.ctl", "fwInstallationAgentDBConsistencyChecker.ctl", "archiv_client.ctl", "calculateState.ctl", 
                                                 "libs/PVSSBootstrapper/PVSSBootstrapper_insider.ctl");
      _fwInstallationManager_setManagersProtectedFromStopping(protectedManagers);
    }
  }
  // Check if _FwInstallationComponents dpt contains element "sourceFilesHashes", if not, then update dpt
  string newComponentsDpe = probeDp + ".sourceFilesHashes";
  if(!dpExists(newComponentsDpe))
  {
    int dpCreateResult = 0;
    _fwInstallation_createDataPointTypes(FALSE, dpCreateResult); //Not up-to-date: Update dpts now
    if(dpCreateResult)
      return -1;
    //calculate hashes for currently installed components
    dyn_dyn_string installedComponents;
    if(fwInstallation_getInstalledComponents(installedComponents) != 0)
      fwInstallation_throw("Failed to get installed components properties. Cannot calculate hashes of source files. This needs to be done manually later", "ERROR");
                           
    int installedComponentsCount = dynlen(installedComponents);
    for(int i=1;i<=installedComponentsCount;i++)
      if(fwInstallation_calculateComponentSourceFilesHashes(installedComponents[i][1]) != 0)
        fwInstallation_throw("Error when calculating source files hashes for component: " + installedComponents[i][1] +
                             ". Hash calculation needs for this component to be done manually later", "ERROR");
  }
                	
  if(dpExists(probeDp))
    dpDelete(probeDp);

  return 0;
}

int fwInstallation_updatePendingInstallationActions()
{
  string dp = fwInstallation_getInstallationDp();
  if(dpExists(dp + ".postInstallFiles") ||
     dpExists(dp + ".postDeleteFiles"))
  {
    dyn_string pendingPostInstalls, pendingPostDeletes;
    
    dpExists(dp + ".postInstallFiles", pendingPostInstalls,
             dp + ".postDeleteFiles", pendingPostDeletes);
    
    int result = -1;
    _fwInstallation_createDataPointTypes(true, result);
    _fwInstallation_createPendingActionsDataPointType();
    fwInstallation_createPendingActionsDp();
    string pendingActionsDp = fwInstallation_getInstallationPendingActionsDp();
    dpSet(pendingActionsDp + ".postInstallFiles", pendingPostInstalls,
          pendingActionsDp + ".postDeleteFiles", pendingPostDeletes);
  }
  else 
  {
     string pendingActionsDp = fwInstallation_getInstallationPendingActionsDp();
     if (!dpExists(pendingActionsDp))
       fwInstallation_createPendingActionsDp();
  }
  return 0;
}

void fwInstallation_setCurrentComponent(string component, string version = "")
{
  gFwInstallationCurrentComponent = component;
  if(version != "")
    gFwInstallationCurrentComponent = gFwInstallationCurrentComponent + " v." + version;
                                      
  return;
}

void fwInstallation_unsetCurrentComponent()
{
  gFwInstallationCurrentComponent = "";
  return;
}


/** Sets the status of the installation tool
  @param status true if OK, false if error
*/
void fwInstallation_setToolStatus(bool status)
{
  string dp = fwInstallation_getInstallationDp();
  dpSet(dp + ".status", status);
  
  return;
}

bool fwInstallation_getToolStatus()
{
  bool status = false;
  string dp = fwInstallation_getInstallationDp();
  dpGet(dp + ".status", status);
  
  return status;
}

int fwInstallation_updateWCCOAInfo()
{
  dyn_string patches;
  string version = fwInstallation_getPvssVersion(patches);
  string dp = fwInstallation_getInstallationDp();
  
  return dpSet(dp + ".projectInfo.wccoaVersion", version,
               dp + ".projectInfo.wccoaPatchList", patches);
  
}

int fwInstallation_getProjectWCCOAInfo(string &version, 
                                      dyn_string &patchList, 
                                      time &lastUpdate,
                                      dyn_string &exception, 
                                      string sys = "")
{
  if(sys == "")
    sys = getSystemName();
  
  string dp = sys + fwInstallation_getInstallationDp();
  
  if(!dpExists(dp + ".projectInfo.wccoaVersion"))
  {
    version = "";
    patchList = makeDynString();
    
    dynAppend(exception, "ERROR: fwInstallation_getProjectPvssInfo() -> Could not retrieve PVSS info from system: " + sys + ".Please, upgrade the installation tool in the remote system to enable this functionality");
    return -1;  
  }  
  
  dpGet(dp + ".projectInfo.wccoaVersion", version,
        dp + ".projectInfo.wccoaPatchList", patchList,
        dp + ".projectInfo.wccoaVersion:_online.._stime", lastUpdate);
  
  return 0;  
}



/** This function needs to be called before the first use of the installation library and after each installation.
  @param runPostInstall (in) this variable specifies whether pending post-install scripts, if any, must be run during initialization
  @return 0 if OK, -1 if errors 
*/
int fwInstallation_init(bool runPostInstall = true, string installationPath = "")
{
  dyn_string dataPointTypes;
  int dpCreateResult;
  dyn_string dynPostInstallFiles_all; // all the postInstall init files to be executed
  dyn_string dynScripts;
  int i;
  int iReturn;
  dyn_float dreturnf;
  dyn_string dreturns;
  string testString, startMode;
  string dp = fwInstallation_getInstallationDp();
  string dpa = fwInstallation_getAgentDp();
        	
	//Add libs to config file if they do not exist yet
  fwInstallation_addLibToConfig();

  if ( !globalExists("gInstallationAgentUiNum") )
    addGlobal("gInstallationAgentUiNum", INT_VAR);

  if ( !globalExists("gFwInstallationLog") )
    addGlobal("gFwInstallationLog", DYN_DYN_STRING_VAR);
  
  //Initialize the PMON variables:
  if ( !globalExists("gFwInstallationPmonUser") )
    addGlobal("gFwInstallationPmonUser", STRING_VAR);
  
  if ( !globalExists("gFwInstallationPmonPwd") )
    addGlobal("gFwInstallationPmonPwd", STRING_VAR);
  
  if ( !globalExists("gFwInstallationCurrentComponent") )
    addGlobal("gFwInstallationCurrentComponent", STRING_VAR);

  gFwInstallationPmonUser = "N/A";
  gFwInstallationPmonPwd = "N/A";
 
  // check whether the _FwInstallationComponents dpt exists
  dataPointTypes = dpTypes();
  if (dynContains(dataPointTypes, "_FwInstallationComponents") <= 0)
  {
    fwInstallation_throw("Starting the Installation Tool for the first time", "INFO", 10);
		  // create the installation tool internal data points	
		  _fwInstallation_createDataPointTypes(TRUE, dpCreateResult);
		  // check the result
		  if (dpCreateResult)
  		  fwInstallation_throw("Failed to create the internal data points. Please re-install the FW Component Installation Tool");
    
    if(_fwInstallation_createPendingActionsDataPointType())
    {
  		  fwInstallation_throw("Failed to create the internal data point type for pending actions. Please re-install the FW Component Installation Tool");
    }
    
    if(fwInstallation_createPendingActionsDp())
    {
  		  fwInstallation_throw("Failed to create the internal data point for pending actions. Please re-install the FW Component Installation Tool");
    }
    
   fwInstallation_throw("Internal data points for the installation tool created", "INFO", 10);
  }
  else if((fwInstallationRedu_isSplitMode() || !fwInstallationRedu_isPassive()) && fwInstallation_updateDPT())//Check that the DPTs are up-to-date:
  {
    fwInstallation_throw("Could not update internal DPTs of the installation tool");
    return -1;
  }
  else if(fwInstallationRedu_isRedundant())
  {//When redundant system is migrated from version < 8.1.0 ensure that new _FwInstallationComponents dpe .sourceFilesHases contains files hashes
    int emptyFilesHashes = 0;
    dyn_string installedComponentDps = fwInstallation_getInstalledComponentDps();
    int installedComponentDpsLen = dynlen(installedComponentDps);
    for(int i=1;i<=installedComponentDpsLen;i++)
    {
      string dpe = installedComponentDps[i] + ".sourceFilesHashes";
      if(!dpExists(dpe))
      {
        fwInstallation_throw("Internal DPTs of the installation tool are not up-to-date. Need to run on active peer first", "WARNING", 10);
        break;
      }
      dyn_string sourceFilesHashes;
      dpGet(dpe, sourceFilesHashes);
      if(dynlen(sourceFilesHashes) == 0)
      {
        emptyFilesHashes++;
      }
    }
    if(installedComponentDpsLen > 0 && emptyFilesHashes == installedComponentDpsLen)
    {//calculate hashes for currently installed components
      dyn_dyn_string installedComponents;
      if(fwInstallation_getInstalledComponents(installedComponents) != 0)
        fwInstallation_throw("Failed to get installed components properties. Cannot calculate hashes of source files. This needs to be done manually later", "ERROR");
                           
      int installedComponentsCount = dynlen(installedComponents);
      for(int i=1;i<=installedComponentsCount;i++)
        if(fwInstallation_calculateComponentSourceFilesHashes(installedComponents[i][1]) != 0)
          fwInstallation_throw("Error when calculating source files hashes for component: " + installedComponents[i][1] +
                               ". Hash calculation needs for this component to be done manually later", "ERROR");
    }
  }
  
  if(!dpExists(dp))
  {
    dpCreate(dp, "_FwInstallationInformation");
    int count = 0;
    while(!dpExists(dp))
    {
      delay(0, 100);
      count++;
      if(count == 300)
        fwInstallation_throw("Failed to create internal fwInstallation dp: " + dp + " for 30 seconds. Cannot continue. Please kill the UI and check para privledges or contact support directly" , "ERROR");
    }
  }
  
  //make default option not to add managers on redu system:
  fwInstallation_setAddManagersOnReduPartner(false);
  
  //if there are components installed, make sure that the dp-element 'name' is properly filled:
  fwInstallation_updateComponentDps();
    
  // Installation path was given as an argument - set a DP, it will be later checked
  if(installationPath != "")
  {
    dpSet(dp + ".installationDirectoryPath", installationPath);
  }
  
  //Create trash if it does not exist:
  string sourceDir;
  dpGet(dp + ".installationDirectoryPath", sourceDir);
  
  if(sourceDir != "" && access(sourceDir, F_OK) >= 0)
  {
    fwInstallation_addProjPath(sourceDir, 999);
  } 
  

  //Install installation agent:
  if(!fwInstallation_isAgentInstalled())      
  {
    fwInstallation_throw("Installation Tool DB-agent not up-to-date. Forcing update now...", "INFO", 10);
    if(fwInstallation_installAgent())
    {
      fwInstallation_throw("fwInstallation_init() -> Could not install FW installation Agent");
      return -1;
    }
    fwInstallation_throw("FW Component Installation DB-agent successfully installed", "INFO", 10);
  }
  
  fwInstallation_updateVersion();
  
  //Load init file as the user may have defined the schema owner there
  fwInstallation_loadInitFile();
  //Load init scripts
  if(fwInstallation_runInitScript())
  {
    fwInstallation_setToolStatus(false);
    fwInstallation_throw("There were errors executing the init script FW Component Installation Tool");
    return -1;
  }
  //Check if the DB is to be used and if so, upgrade system table to populate the event computer id column if required:
  int projectId = -1;
  if(fwInstallationDB_getUseDB() && fwInstallationDB_connect() == 0)
  {
    //check version of the schema
    string version = "";
    int getSchemaRetVal = fwInstallationDB_getSchemaVersion(version);
    bool compareSchemaRetVal = (getSchemaRetVal == 0)?fwInstallationDB_compareSchemaVersion():false;
    if(!compareSchemaRetVal)//disconnect DB as DB schema is wrong or has wrong version
    {
      fwInstallationDB_closeDBConnection();
      fwInstallationDB_setUseDB(false);
      
      if(getSchemaRetVal != 0)//schema not found
        fwInstallation_throw("fwInstallation_init(): Failed to retrieve version of the DB schema. Please check if Configuration DB System Information schema is present in the DB");
      else//wrong schema version
        fwInstallation_throw("fwInstallation_init(): Current DB schema version: " + version + " is lower than required: " + FW_INSTALLATION_DB_REQUIRED_SCHEMA_VERSION + ". Please upgrade the DB schema");
    }
    else
      fwInstallationDB_isProjectRegistered(projectId);
  }
  
  //add control manager for post installation scripts:
  string user, pwd, host = fwInstallation_getPmonHostname();
  int port = pmonPort();

  fwInstallation_getPmonInfo(user, pwd);
  
  //Add Agent to the PVSS console:
  fwInstallationManager_add(fwInstallation_getWCCOAExecutable("ctrl"), "always", 30, 3, 3, "-f fwInstallationAgent.lst", host, port, user, pwd);
 
  fwInstallationManager_add(fwInstallation_getWCCOAExecutable("ctrl"), "once", 30, 1, 1, "-f fwScripts.lst", host, port, user, pwd);
  //fwInstallation_throw("Ctrl Manager to project console for component post-install scripts added", "INFO", 10);
 
  if(runPostInstall)
  {
    fwInstallation_executePostInstallScripts();
  }
  
// add control manager for redundant systems:
//   if(fwInstallationRedu_isRedundant())
//   {
//     fwInstallationManager_add(fwInstallation_getWCCOAExecutable("ctrl"), "always", 30, 1, 1, "-f fwInstallationRedu.lst", host, port, user, pwd);
//   } 
     

/*  
  //Deploy the crash action script for the installation tool:
  if(VERSION != "3.6")
  {
    if(fwInstallation_deployCrashActionScript())
    {
      fwInstallation_setToolStatus(false);
      fwInstallation_throw("fwInstallation_init() -> Failed to deploy the crash action script of the FW Component Installation Tool");
      return -1;
    }
  }
*/ 
 
//  fwInstallation_throw("*** FW Component Installation Tool v." + csFwInstallationToolVersion+ " ready ***", "INFO", 10);
  
  //Fill pvss version and patch list here:
  fwInstallation_updateWCCOAInfo();
  fwInstallation_setToolStatus(true);
  return 0;
}


/** This function lauches the pending post-installation of scripts of installed components (if any)
  @return 0 if OK, -1 if errors 
*/
int fwInstallation_executePostInstallScripts()
{
  dyn_string dynPostInstallFiles_all;
  string dp = fwInstallation_getInstallationPendingActionsDp();
        
  dpGet(dp + ".postInstallFiles:_original.._value", dynPostInstallFiles_all);
  
  if(dynlen(dynPostInstallFiles_all))
  {
    string user, pwd, host = fwInstallation_getPmonHostname();
    int port = pmonPort();
    fwInstallation_getPmonInfo(user, pwd);

    return fwInstallationManager_command("START", fwInstallation_getWCCOAExecutable("ctrl"), "-f fwScripts.lst", host, port, user, pwd);
  }
  return 0;
}

/** This function creates the trash for the installation tool
  @param sourceDir (in) path where to create the trash as string
  @return 0 if OK, -1 if errors 
*/
int fwInstallation_createTrash(string sourceDir)
{
  if(sourceDir != "" && access(sourceDir, W_OK))
  if(!mkdir(sourceDir))
    return -1;
  
  return 0;
}

/** This function updates the version number of the installation tool from previous versions
  @return 0 if OK, -1 if errors 
*/
int fwInstallation_updateVersion()
{
  string version;
  string dp = fwInstallation_getInstallationDp();
  
  int error = fwInstallation_getToolVersion(version);
  
  if(error != 0){
    fwInstallation_throw("fwInstallation_getToolVersion() -> Could not update the installation tool version");
    return -1;
  }
    
  if(version != csFwInstallationToolVersion)
    dpSet(dp + ".version", csFwInstallationToolVersion);

  return 0;
}

/** This function retrieves the current version of the installation tool used in a particular PVSS system.
  @param version (out) version of the tool
  @param systemName (int) name the pvss system where to read the installation tool version from
  @return 0 if OK, -1 if errors 
*/
int fwInstallation_getToolVersion(string &version, string systemName = "")
{  
  string dp = fwInstallation_getInstallationDp();
  
  if(systemName == "")
    systemName = getSystemName();

  if(systemName == getSystemName())
  {
    version = csFwInstallationToolVersion;
    return 0;  //If local system we are done
  }
      
  //In case we want to read tool version in a different version
  if(!patternMatch("*:", systemName))
    systemName += ":";
  
  if(!dpExists(dp + ".version")){
    version = "";
    return -1;
  }
  else {
    dpGet(systemName + dp + ".version", version);    
  }
  return 0;
}

/** This function retrieves name of the internal dp holding the parameterization of the DB-agent
  @return name of the internal dp as string 
*/
string fwInstallation_getAgentDp()
{
//  string dp;
  
//  if(fwInstallationRedu_myReduHostNum() > 1)
//    dp = "fwInstallation_agentParametrization_" + fwInstallationRedu_myReduHostNum();
//  else
    return "fwInstallation_agentParametrization";
}

/** This function retrieves name of the internal dp holding the pending installation requests to be executed by the DB-Agent
  @return name of the dp as string  
*/
string fwInstallation_getAgentRequestsDp(int localReduHostNum = 0)
{
  if (localReduHostNum == 0)
    localReduHostNum = fwInstallationRedu_myReduHostNum();
  
  string dp;
  
  if(localReduHostNum > 1)
    dp = "fwInstallation_agentPendingRequests_" + localReduHostNum;
  else
    dp = "fwInstallation_agentPendingRequests";
  
  return dp;
}


/** This function checks if the DB-agent of the installation tool is installed in the current project
  @return true if the agent is installed, false otherwise
*/
bool fwInstallation_isAgentInstalled()
{
  string dp = fwInstallation_getAgentDp();
  string dpAgent = fwInstallation_getAgentRequestsDp();

  if(dpExists(dp + ".managers.stopDistAfterSync") &&
  	 dpExists(dp + ".db.connection.schemaOwner") &&
  	 dpExists(dp + ".db.connection.driver") &&
  	 dpExists(dpAgent + ".managerReconfiguration.manager"))
  {
  	// If this is a redundand system, check if fwInstallation is present there
  	if(fwInstallationRedu_isRedundant() &&
       (!dpExists(fwInstallation_getAgentRequestsDp(2))))
  	{
	  	return false;
	}

    return true;
  }  
  
  return false;  
}

/** This function installs the DB-Agent of the FW Component Installation Tool
  @return 0 if OK, -1 if errors 
*/
int  fwInstallation_installAgent()
{
  int error = 0;
  dyn_string dataPointTypes = dpTypes();
  string oldVersion;
  string newVersion;
  string dp = fwInstallation_getInstallationDp();
  string dpa = fwInstallation_getAgentDp();
        
  error = _fwInstallation_createAgentDataPointType("_FwInstallation_agentParametrization", true);

  if(error){
    fwInstallation_throw("fwInstallation_installAgent() -> Could not create DPT for FW installation agent");
    return -1;
  }
  if(_fwInstallation_createAgentDataPointType("_FwInstallation_agentPendingRequests", true))
  {
    fwInstallation_throw("fwInstallation_installAgent() -> Could not create DPT for FW installation agent");
    return -1;
  }
  
  // check whether the fwInstallation_agentParametrization dp exists
  dpa = fwInstallation_getAgentDp();
  if(!dpExists(dpa))
  {
    error = dpCreate(dpa, "_FwInstallation_agentParametrization");
    if(error){
      fwInstallation_throw("fwInstallation_installAgent() -> Could not create DP for FW installation agent: Agent parametrization");
      return -1;
    }
    else
    {
      //initialize the protected managers
      dyn_string protectedManagers = makeDynString("-m gedi", "-f pvss_scripts.lst", "-f fwInstallationAgent.lst", "-p fwInstallation/fwInstallation.pnl",
                                                 "fwInstallationFakeScript.ctl", "fwInstallationAgentDBConsistencyChecker.ctl", "archiv_client.ctl", "calculateState.ctl", 
                                                 "libs/PVSSBootstrapper/PVSSBootstrapper_insider.ctl");
      _fwInstallationManager_setManagersProtectedFromStopping(protectedManagers);
    }
    fwInstallationDBAgent_setSyncInterval(300);
  }
  else
  {
    //this piece of code is necessary to upgrade from versions previous to 4.0.0
    //as the owner was introduced only in this version of the tool.
    string owner, writer;
    dpGet(dpa + ".db.connection.schemaOwner", owner,
          dpa + ".db.connection.username", writer);
    
    if(owner == "" || writer == owner)
    {
      //Load init file as schema owner may have been defined there:
      fwInstallation_loadInitFile();
    }
  }
  
  if (fwInstallationRedu_isRedundant())
  {
    string dpr = fwInstallation_getAgentRequestsDp(1);
    if(!dpExists(dpr))
    {
      error = dpCreate(dpr, "_FwInstallation_agentPendingRequests");
      if(error){
        fwInstallation_throw("fwInstallation_installAgent() -> Could not create DP for FW installation agent: Agent installation requests pair 1");
        return -1;
      }
    }
    dpr = fwInstallation_getAgentRequestsDp(2);
    if(!dpExists(dpr))
    {
      error = dpCreate(dpr, "_FwInstallation_agentPendingRequests");
      if(error){
        fwInstallation_throw("fwInstallation_installAgent() -> Could not create DP for FW installation agent: Agent installation requests pair 2");
        return -1;
      }
    }
  }
  else
  {
    string dpr = fwInstallation_getAgentRequestsDp();
    if(!dpExists(dpr))
    {
      error = dpCreate(dpr, "_FwInstallation_agentPendingRequests");
      if(error){
        fwInstallation_throw("fwInstallation_installAgent() -> Could not create DP for FW installation agent: Agent installation requests");
        return -1;
      }
    }
  }

  time tSync;
    
  dpGet(dpa + ".syncInterval:_online.._stime", tSync);
    
  if(tSync <= makeTime(2000, 1, 1, 1)){
    fwInstallationDBAgent_setSyncInterval(300);
  }
 
  dpSet(dpa + ".db.projectStatus", makeDynInt(0, 0, 0, 0, 0, 0, 0, 0, 0));
  
  return error;
}




/** This function creates the internal dp-types of the installtation tool
@param type name of the dp-type to be created
@param create flag to indicated if the dp-type has to be overwritten (obsolete, legacy)
@return result 0 if OK, -1 otherwise 
*/

int _fwInstallation_createAgentDataPointType(string type, bool create)
{
	 dyn_dyn_string dynDynElements;
	 dyn_dyn_int dynDynTypes;
	
	 int result = 0;

  dynDynElements[1] = makeDynString (type , "");
  dynDynTypes[1] = makeDynInt (DPEL_STRUCT);

  if(type == "_FwInstallation_agentParametrization")
  {	
    // Names
	   dynDynElements[2] = makeDynString ("","db");
	     dynDynElements[3] = makeDynString ("","", "connection");
	       dynDynElements[4] = makeDynString ("", "", "", "driver");
        dynDynElements[5] = makeDynString ("", "", "", "server");
        dynDynElements[6] = makeDynString ("", "", "", "username");
        dynDynElements[7] = makeDynString ("" , "", "", "password");
        dynDynElements[8] = makeDynString ("" , "", "", "initialized");
        dynDynElements[9] = makeDynString ("" , "", "", "schemaOwner");
	     dynDynElements[10] = makeDynString ("", "", "useDB");
	     dynDynElements[11] = makeDynString ("", "", "projectStatus");
//	   dynDynElements[12] = makeDynString ("", "", "synchronization");
	   dynDynElements[12] = makeDynString ("", "lock");
	   dynDynElements[13] = makeDynString ("", "restart");
	   dynDynElements[14] = makeDynString ("", "syncInterval");
    dynDynElements[15] = makeDynString ("", "managers");
      dynDynElements[16] = makeDynString ("", "", "stopDist");
      dynDynElements[17] = makeDynString ("", "", "stopUIs");
      dynDynElements[18] = makeDynString ("", "", "stopCtrl");
      dynDynElements[19] = makeDynString ("", "", "stopDistAfterSync");
      dynDynElements[20] = makeDynString ("", "", "protected");
    dynDynElements[21] = makeDynString ("", "redundancy");
      dynDynElements[22] = makeDynString ("", "", "installOnlyInSplit");
      dynDynElements[23] = makeDynString ("", "", "restoreRedundancyAfterInstallation");
      dynDynElements[24] = makeDynString ("", "", "splitModeForced");
      dynDynElements[25] = makeDynString ("", "", "pairToKeepAfterSplit");
    dynDynElements[26] = makeDynString ("", fwInstallation_getFileIssuesSyncDpElem());
    dynDynElements[27] = makeDynString ("", fwInstallation_getAfterInitRestartNeededDpElem());
    dynDynElements[28] = makeDynString ("", fwInstallation_getAfterInitRestartRequesterDpElem());

    // Types      
    dynDynTypes[2] = makeDynInt (0, DPEL_STRUCT);
	     dynDynTypes[3] = makeDynInt (0, 0, DPEL_STRUCT);
	       dynDynTypes[4] = makeDynInt (0, 0, 0, DPEL_STRING);
	       dynDynTypes[5] = makeDynInt (0, 0, 0, DPEL_STRING);
 	      dynDynTypes[6] = makeDynInt (0, 0, 0, DPEL_STRING);
 	      dynDynTypes[7] = makeDynInt (0, 0, 0, DPEL_STRING);
 	      dynDynTypes[8] = makeDynInt (0, 0, 0, DPEL_INT);
 	      dynDynTypes[9] = makeDynInt (0, 0, 0, DPEL_STRING);
 	    dynDynTypes[10] = makeDynInt (0, 0, DPEL_INT);
 	    dynDynTypes[11] = makeDynInt (0, 0, DPEL_DYN_INT);
//    dynDynTypes[12] = makeDynInt (0, 0, DPEL_DYN_INT);
	   dynDynTypes[12] = makeDynInt (0, DPEL_INT);
	   dynDynTypes[13] = makeDynInt (0, DPEL_INT);
	   dynDynTypes[14] = makeDynInt (0, DPEL_INT);
	   dynDynTypes[15] = makeDynInt (0, DPEL_STRUCT);
	     dynDynTypes[16] = makeDynInt (0, 0, DPEL_INT);
	     dynDynTypes[17] = makeDynInt (0, 0, DPEL_INT);
	     dynDynTypes[18] = makeDynInt (0, 0, DPEL_INT);
      dynDynTypes[19] = makeDynInt (0, 0, DPEL_INT);
      dynDynTypes[20] = makeDynInt (0, 0, DPEL_DYN_STRING);    
    dynDynTypes[21] = makeDynInt (0, DPEL_STRUCT);
      dynDynTypes[22] = makeDynInt (0, 0, DPEL_INT);
      dynDynTypes[23] = makeDynInt (0, 0, DPEL_INT);      
      dynDynTypes[24] = makeDynInt (0, 0, DPEL_BOOL);
      dynDynTypes[25] = makeDynInt (0, 0, DPEL_INT);      
    dynDynTypes[26] = makeDynInt (0, DPEL_BOOL);
    dynDynTypes[27] = makeDynInt(0, DPEL_INT);
    dynDynTypes[28] = makeDynInt(0, DPEL_STRING);
  }
  else if(type == "_FwInstallation_agentPendingRequests")
  {
    // Names
	   dynDynElements[2] = makeDynString ("", "restart");
	   dynDynElements[3] = makeDynString ("", "pvssInstallRequests");
	   dynDynElements[4] = makeDynString ("", "pvssDeleteRequests");
    dynDynElements[5] = makeDynString ("", "dbInstallRequests");
    dynDynElements[6] = makeDynString ("", "dbDeleteRequests");
    dynDynElements[7] = makeDynString ("", "trigger");
    dynDynElements[8] = makeDynString ("", "execute");
    dynDynElements[9] = makeDynString ("", "msg");
    dynDynElements[10] = makeDynString ("", "managerReconfiguration");
      dynDynElements[11] = makeDynString ("", "", "manager");
      dynDynElements[12] = makeDynString ("", "", "startMode");
      dynDynElements[13] = makeDynString ("", "", "secKill");
      dynDynElements[14] = makeDynString ("", "", "restartCount");
      dynDynElements[15] = makeDynString ("", "", "resetMin");
      dynDynElements[16] = makeDynString ("", "", "commandLine");

    // Types
    dynDynTypes[2] = makeDynInt (0, DPEL_INT);
	   dynDynTypes[3] = makeDynInt (0, DPEL_DYN_STRING);
	   dynDynTypes[4] = makeDynInt (0, DPEL_DYN_STRING);
	   dynDynTypes[5] = makeDynInt (0, DPEL_DYN_STRING);
	   dynDynTypes[6] = makeDynInt (0, DPEL_DYN_STRING);
    dynDynTypes[7] = makeDynInt (0, DPEL_INT);
    dynDynTypes[8] = makeDynInt (0, DPEL_INT);
    dynDynTypes[9] = makeDynInt (0, DPEL_STRING);
    dynDynTypes[10] = makeDynInt (0, DPEL_STRUCT);
	     dynDynTypes[11] = makeDynInt (0, 0, DPEL_DYN_STRING);
	     dynDynTypes[12] = makeDynInt (0, 0, DPEL_DYN_STRING);
	     dynDynTypes[13] = makeDynInt (0, 0, DPEL_DYN_INT);
	     dynDynTypes[14] = makeDynInt (0, 0, DPEL_DYN_INT);
	     dynDynTypes[15] = makeDynInt (0, 0, DPEL_DYN_INT);
	     dynDynTypes[16] = makeDynInt (0, 0, DPEL_DYN_STRING);
  }
    
 	result = dpTypeChange(dynDynElements, dynDynTypes);
	
  dynClear(dynDynElements);
  dynClear(dynDynTypes);
   
  return result;
}

/** This function creates the internal dp-types of the installtation tool pending actions
@return result 0 if OK, -1 otherwise 
*/
int _fwInstallation_createPendingActionsDataPointType()
{
  dyn_dyn_string dynDynElements;
  dyn_dyn_int dynDynTypes;
	
  int result = 0;

  dynDynElements[1] = makeDynString ("_FwInstallationPendingActions");
  dynDynElements[2] = makeDynString ("","postInstallFiles");
  dynDynElements[3] = makeDynString ("","postDeleteFiles"); 
  
  dynDynTypes[1] = makeDynInt (DPEL_STRUCT);
  dynDynTypes[2] = makeDynInt (0, DPEL_DYN_STRING);
  dynDynTypes[3] = makeDynInt (0, DPEL_DYN_STRING);
  
  return dpTypeChange(dynDynElements, dynDynTypes );
}

int fwInstallation_createPendingActionsDp()
{
  if (fwInstallationRedu_isRedundant())
  {
    string dpPair1 = fwInstallation_getInstallationPendingActionsDp(1);  
    if(!dpExists(dpPair1)) 
      dpCreate(dpPair1, "_FwInstallationPendingActions");
    
    string dpPair2 = fwInstallation_getInstallationPendingActionsDp(2);  
    if(!dpExists(dpPair2)) 
      dpCreate(dpPair2, "_FwInstallationPendingActions");
  }
  else
  {
    string dp = fwInstallation_getInstallationPendingActionsDp();  
    if(!dpExists(dp)) 
      return dpCreate(dp, "_FwInstallationPendingActions");
  }
  return 0;
    
}

string fwInstallation_getInstallationPendingActionsDp(int localReduHostNum = 0)
{
  if (localReduHostNum == 0)
    localReduHostNum = fwInstallationRedu_myReduHostNum();
  
  string dp = "fwInstallation_pendingActions";
  
  if(localReduHostNum > 1) dp += "_" + localReduHostNum;

  return dp;  
}

/** The function reads all project paths from the config file into a dyn_string list. Project paths have the same order as in the config file.
@param proj_paths: dyn_string which will be filled with the project paths from the config file
@return 0 if success,  -1 if error, -2 if no project paths in the config file (this should not happen)
*/
int fwInstallation_getProjPaths(dyn_string& proj_paths, bool adjustScattered = false)
{
  string configPath = getPath(CONFIG_REL_PATH);
  string configFile = configPath + "config";

  // Get paths from config file and normalize them	
  int err = paCfgReadValueList(configFile, "general", "proj_path", proj_paths);

  if(fwInstallation_normalizePathList(proj_paths) == -1)
    return -1;
  
  string projPathConst = PROJ_PATH;
  if(fwInstallation_normalizePath(projPathConst) == -1)
  {
    return -1;
  }

  if (adjustScattered && !dynContains(proj_paths, projPathConst))
  {
    string projPath = proj_paths[dynlen(proj_paths)];
    int iteratorPathInConfig = strlen(projPath);
    int iteratorSymProjPathConst = strlen(projPathConst);
    int diffPositionProjPathConst =  iteratorSymProjPathConst; 
    int diffPositionPathInConfig = iteratorPathInConfig;
    while (projPath[iteratorPathInConfig--] == projPathConst[iteratorSymProjPathConst--])
    {
      diffPositionProjPathConst--;
      diffPositionPathInConfig--;
    }
    string searchStr = substr(projPath, 0, diffPositionPathInConfig + 1);
    string replaceStr = substr(projPathConst, 0, diffPositionProjPathConst + 1);
    for(int i = 1; i<= dynlen(proj_paths); i++)
    {
      strreplace(proj_paths[i], searchStr, replaceStr);
    }
  }

  return err;				
}

/** Helper function to convert data point name (remove blank spaces, etc.). 
 * @param app (string) IN WCCOA application name to convert (may contain blanks, etc.)	
 * @return converted data point type
 */
string _fwInstallation_getWCCOAApplicationDpName(string app)
{
  string dp = strtoupper(app);

  strreplace(dp, ".", "_dot_");
  strreplace(dp, " ", "_");
 
  return dp;
}

/** Retrieve existing WinCC OA (UNICOS) applications on this system
  @param wccoaApplications variable to receive info about currently installed WinCC OA applications.
  @return 0 on success, -1 on error.
  
  @Note: Currently only 'Default_Panel' field is filled. 'Info_URL', 'Comment_text', 'Status', 'Responsible' and 'Alarm_Overview_Panel' are missed.
*/
int fwInstallation_getWCCOAApplications(dyn_dyn_mixed &wccoaApplications)
{
  dyn_string feDps = dpNames(getSystemName() + "*.configuration.subApplications");
  dyn_string apps;
 
  int n = dynlen(feDps);
  for(int i = 1; i <= n; i++)
  {
    dyn_string temp;
    dpGet(feDps[i], temp);
    dynAppend(apps, temp);
  }
  dynUnique(apps);
  
  n = dynlen(apps);
  for(int i = 1; i <= n; i++)
  {
  	string appName = apps[i];
    string appNameDp = "_unApplication_" + _fwInstallation_getWCCOAApplicationDpName(appName);
    string defaultPanelDpElem = appNameDp + ".defaultPanel";
    string defaultPanelName; 
    
    wccoaApplications[i][FW_INSTALLATION_DB_WCCOA_APP_NAME] = appName;

    if(dpExists(defaultPanelDpElem) && dpGet(defaultPanelDpElem, defaultPanelName) == 0)
    {
      wccoaApplications[i][FW_INSTALLATION_DB_WCCOA_APP_DEFAULT_PANEL] = defaultPanelName;
    }
    else
    {
      fwInstallation_throw("Unable to retrieve WinCC OA default panel name, dp: " + appNameDp, "WARNING", 10);
      wccoaApplications[i][FW_INSTALLATION_DB_WCCOA_APP_DEFAULT_PANEL] = "?";
    }

    // Commented out intentionally, we don't have this information
    //wccoaApplications[i][FW_INSTALLATION_DB_WCCOA_APP_INFO_URL] = "";
    //wccoaApplications[i][FW_INSTALLATION_DB_WCCOA_APP_COMMENT_TEXT] = "";
    //wccoaApplications[i][FW_INSTALLATION_DB_WCCOA_APP_STATUS] = "";
    //wccoaApplications[i][FW_INSTALLATION_DB_WCCOA_APP_RESPONSIBLE] = "";
    //wccoaApplications[i][FW_INSTALLATION_DB_WCCOA_APP_ALARM_OVERVIEW_PANEL] = "";
  }
 
  return 0;
}


/** This function backs up the project config file. 
*   It is intendended to be called before component installation/uninstallation
  @return 0 if OK, -1 otherwise 
*/
int fwInstallation_backupProjectConfigFile()
{
  string configPath = getPath(CONFIG_REL_PATH);
  string configFile = configPath + "config";
  time t = getCurrentTime();
  //Get string with following format YYYY_MM_DD_HH_mm_ss_nnn (n stands for a ms)
  string str = formatTime("%Y_%m_%d_%H_%M_%S",t,"_%03d");
        
  string bkConfigFile = configPath + "config_" + str;
            
  return fwInstallation_copyFile(configFile, bkConfigFile);
}

/** This functions writes all project paths given in a dyn_string to the config file 
*   and overwrites existing paths exept the main project path.
  @param projPaths: dyn_string with the project paths for the config file
  @return 0 if OK, -1 if error 
*/
int fwInstallation_setProjPaths( dyn_string projPaths )
{
	dyn_string configLines;
	
	dyn_int tempPositions;
	dyn_string tempLines;
	string tempLine;
	int i,j;
	bool sectionFound = FALSE;
	
	string configPath = getPath(CONFIG_REL_PATH);
	string configFile = configPath + "config";

	if(_fwInstallation_getConfigFile(configLines) == 0)
	{
		for (i=1; i<=dynlen(configLines); i++)
		{
			tempLine = configLines[i];
			if(strpos(tempLine, "proj_path") >= 0)
			{
				dynAppend(tempPositions,i);
			}
		}
		if(dynlen(tempPositions)>0)
		{
			sectionFound = TRUE;
			dynClear(tempLines);
			for (j=1; j<=dynlen(projPaths); j++)
			{
				tempLine = "proj_path = \"" + projPaths[j] + "\"";
				dynAppend(tempLines,tempLine);
			}
			for (j=dynlen(tempPositions); j>=1; j--)	
			{
				dynRemove(configLines,tempPositions[j]);
			}
			dynInsertAt(configLines,tempLines,tempPositions[1]);
		}
		if(sectionFound)
		{
			fwInstallation_saveFile(configLines, configFile);
		} else {
			return -2;
		}
	} else {
		return -1;
	}
 return 0;       
}

/** This function checks if given path exists in config file
* @param projPath: Project path (in)
* @param isPathInConfig: 
@return 0 if path was successfully normalised, -1 in case of error
*/

int fwInstallation_isPathInConfigFile(string projPath, bool &isPathInConfig)
{
	dyn_string projPathsFromConfig;
  // Sequence of operations to compact the code
	if((fwInstallation_normalizePath(projPath) == -1) || 
		 (fwInstallation_getProjPaths(projPathsFromConfig) == -1))
	{
		return -1;
	}
  
  int retVal = dynContains(projPathsFromConfig, projPath);
  if(retVal == -1)
  {
    return -1;
  }
  
  isPathInConfig = (retVal > 0);

	return 0;
}

/** This function add a project path to the config file.
@param projPath: string that contains the project path to be added to the config file
@param position: position of the added path in the list (n = specified position, try 999 for last before main project path)
@return 0 if success,  -1 if error,  -2 if position out of range
@author S. Schmeling
*/
synchronized int fwInstallation_addProjPath(string projPath, int position)
{
	dyn_string configLines;
	
	dyn_int tempPositions;
	string tempLine;
	int i,j;
	bool sectionFound = FALSE;
	
	bool isPathInConfigFile = false;
	if(fwInstallation_normalizePath(projPath) == -1 ||
		fwInstallation_isPathInConfigFile(projPath,isPathInConfigFile) == -1)
	{
		return -1;
	}
	if(isPathInConfigFile)
	{
		return 0;
	}
	
	string configPath = getPath(CONFIG_REL_PATH);
	string configFile = configPath + "config";

	if(_fwInstallation_getConfigFile(configLines) == 0)
	{
		for (i=1; i<dynlen(configLines); i++)
		{
			tempLine = configLines[i];
			if(strpos(tempLine, "proj_path") >= 0)
			{
				dynAppend(tempPositions,i);
			}
		}
		
		if(dynlen(tempPositions)>0)
		{
			sectionFound = TRUE;
			tempLine = "proj_path = \"" + projPath + "\"";
			if(position > 0) 
			{
				if(position < dynlen(tempPositions))
				{
					dynInsertAt(configLines,tempLine,tempPositions[position]);
				} else {
					dynInsertAt(configLines,tempLine,tempPositions[dynlen(tempPositions)]);
				}
			}			
		}
		if(sectionFound == TRUE)
		{
    fwInstallation_registerProjectPath(projPath);
			return fwInstallation_saveFile(configLines, configFile);
		} else {
			return -2;
		}
	} else {
		return -1;
	}
        return 0;
}


/** This function removes the given project path from the config file.
@param projPath: string that contains the project path to be removed from the config file
@return 0 if success, -1 if general error, -2 if project path does not exist
@author S. Schmeling
*/
synchronized int fwInstallation_removeProjPath( string projPath )
{
/*  
	dyn_string configLines;
	
	dyn_int tempPositions;
	dyn_string tempLines;
	string tempLine;
	int i,j;
	bool sectionFound = FALSE;
*/	
  string configPath = getPath(CONFIG_REL_PATH);
  string configFile = configPath + "config";
  
  if(fwInstallation_normalizePath(projPath) == -1)
  {
    return -1;
  }

  paCfgDeleteValue(configFile, "general", "proj_path", projPath);
  //remove potential duplicated entries (with "/" at the end)
  paCfgDeleteValue(configFile, "general", "proj_path", projPath + FW_INSTALLATION_PATH_SEPARATOR);

/*  
	if(_fwInstallation_getConfigFile(configLines) == 0)
	{
		for (i=1; i<=dynlen(configLines); i++)
		{
			tempLine = configLines[i];
			if(strpos(tempLine, "proj_path") >= 0)
			{
				if(strpos(tempLine, projPath) >= 0)
				{
					dynAppend(tempPositions,i);
				}
			}
		}
		if(dynlen(tempPositions)>0)
		{
			sectionFound = TRUE;
			for (j=dynlen(tempPositions); j>=1; j--)	
			{
				dynRemove(configLines,tempPositions[j]);
			}
		}
		if(sectionFound == TRUE)
		{
			return fwInstallation_saveFile(configLines, configFile);
		} else {
			return -2;
		}
	} else {
		return -1;
	}
*/  
}

/** This function retrieves name of the internal dp associated
 * with an installed component.
 *
 * @param componentName name of the component
 * @param reduHostNum number of redundant host
 * @return datapoint name for a given component, or empty it doesn't exist
 */
string fwInstallation_getComponentDp(string componentName, int reduHostNum = 0)
{
  string dp;

  if(reduHostNum == 0) reduHostNum = fwInstallationRedu_myReduHostNum();
  
  if(reduHostNum > 1 && !patternMatch("*_"+ reduHostNum, componentName))
    dp = "fwInstallation_"+strltrim(strrtrim(componentName)) + "_" + reduHostNum;
  else
    dp = "fwInstallation_"+strltrim(strrtrim(componentName));
  
  return dp;
}


/** This function returns the following property of the installed component: list of files for this component

@param componentName: string with the name of the component 
@param componentProperty: name of the requested property
@param componentInfo: variable that contains the property of the component
@return 0 - "success"  -1 - error 
@author S. Schmeling and F. Varela
*/
int fwInstallation_getComponentInfo(string componentName, string componentProperty, dyn_anytype & componentInfo, int reduHostNum = 0)
{
  string temp_componentProperty, temp_string;
  float temp_float;
  dyn_anytype temp_dyn_string;
  bool temp_bool;
  int i;

  if(reduHostNum == 0) reduHostNum = fwInstallationRedu_myReduHostNum();

  temp_componentProperty = strtolower(componentProperty);

  string dp = fwInstallation_getComponentDp(componentName, reduHostNum);
  if(!dpExists(dp)) // Check if component data exists
    return -1;

	switch(temp_componentProperty)
	{
		case "componentfiles": 
			i = dpGet(dp +".componentFiles", temp_dyn_string);
			dynAppend(componentInfo, temp_dyn_string);
			return i;
			break;
		case "configgeneral": 
			i = dpGet(dp+".configFiles.configGeneral", temp_dyn_string);
			dynAppend(componentInfo, temp_dyn_string);
			return i;
			break;
		case "configlinux": 
			i = dpGet(dp+".configFiles.configLinux", temp_dyn_string);
			dynAppend(componentInfo, temp_dyn_string);
			return i;
			break;
		case "configwindows": 
			i = dpGet(dp+".configFiles.configWindows", temp_dyn_string);
			dynAppend(componentInfo, temp_dyn_string);
			return i;
			break;
		case "initfiles": 
			i = dpGet(dp+".initFiles", temp_dyn_string);
			dynAppend(componentInfo, temp_dyn_string);
			return i;
			break;
		case "postinstallfiles": 
			i = dpGet(dp+".postInstallFiles", temp_dyn_string);
			dynAppend(componentInfo, temp_dyn_string);
			return i;
			break;
		case "dplistfiles": 
			i = dpGet(dp+".dplistFiles", temp_dyn_string);
			dynAppend(componentInfo, temp_dyn_string);
			return i;
			break;
		case "requiredcomponents": 
			i = dpGet(dp+".requiredComponents", temp_dyn_string);
			dynAppend(componentInfo, temp_dyn_string);
			return i;
			break;
		case "subcomponents": 
			i = dpGet(dp+".subComponents", temp_dyn_string);
			dynAppend(componentInfo, temp_dyn_string);
			return i;
			break;
		case "scriptfiles": 
			i = dpGet(dp+".scriptFiles", temp_dyn_string);
			dynAppend(componentInfo, temp_dyn_string);
			return i;
			break;
		case "date": 
			i = dpGet(dp+".date:_original.._value", temp_string);
			dynAppend(componentInfo, temp_string);
			return i;
			break;
		case "descfile": 
			i = dpGet(dp+".descFile", temp_string);
			dynAppend(componentInfo, temp_string);
			return i;
			break;
		case "sourcedir": 
			i = dpGet(dp+".sourceDir", temp_string);
			dynAppend(componentInfo, temp_string);
			return i;
			break;
		case "installationdirectory": 
			i = dpGet(dp+".installationDirectory", temp_string);
			dynAppend(componentInfo, temp_string);
			return i;
			break;
		case "componentversion": 
		case "componentversionstring": 
			i = dpGet(dp+".componentVersionString", temp_string);
			// Backwards compatibility (version stored as float)
			if(temp_string == "")
			{
				i += dpGet(dp+".componentVersion", temp_float);
				if(temp_float == floor(temp_float))
				{
					sprintf(temp_string,"%2.1f",temp_float);
				} else {
					temp_string = (string) temp_float;
				}
				dpSet(dp + ".componentVersionString", temp_string);
			}
			dynAppend(componentInfo, temp_string);
			return i;
			break;
		case "requiredinstalled": 
			i = dpGet(dp+".requiredInstalled", temp_bool);
			dynAppend(componentInfo, temp_bool);
			return i;
			break;
		case "isitsubcomponent": 
			i = dpGet(dp+".isItSubComponent", temp_bool);
			dynAppend(componentInfo, temp_bool);
			return i;
			break;
		default:
			dynAppend(componentInfo, "Property not known");
			return -1;
	}
	return -1; // Default to fail
}

/** This function returns the name of the internal dps correspoding to all components installed in the project
@return names of the internal dps as a dyn_string 
*/
dyn_string fwInstallation_getInstalledComponentDps(int reduHostNum = 0)
{
  dyn_string componentDPs;
  
  if(reduHostNum == 0) reduHostNum = fwInstallationRedu_myReduHostNum();
  
  if(reduHostNum > 1)
    componentDPs = dpNames("fwInstallation_*_" + reduHostNum, "_FwInstallationComponents");
  else
  {
    componentDPs = dpNames("fwInstallation_*", "_FwInstallationComponents");
    for(int i = dynlen(componentDPs); i >= 1; i--)
    {
      if(strpos(componentDPs[i], ":") > 0)
        strreplace(componentDPs[i], getSystemName(), "");
      
      //Savannah #54773 
      if(patternMatch("*_2", componentDPs[i])|| patternMatch("*_3", componentDPs[i]) || patternMatch("*_4", componentDPs[i]))
        dynRemove(componentDPs, i);
    }
    
  }
  return componentDPs;
}

/** This function gets the information about all installed components into a dyn_dyn_string structure:
	[n][1] component name
	[n][2] component version
	[n][3] path to the installation
  [n][4] description file
@param componentsInfo: dyn_dyn_string that will contain all installed components and their respective version numbers
@return 0 if success,  -1 if error, -999999 if no components installed
@author S. Schmeling and F. Varela
*/
int fwInstallation_getInstalledComponents(dyn_dyn_string & componentsInfo, int reduHostNum = 0)
{
  dyn_dyn_string tempAllInfo;	
  dyn_string componentDPs;
  string componentVersionString, installationDirectory, descFile;
  float componentVersion;
  string sourcePath;
  int installationNotOK;
  int dependenciesOK;
  string name;
  bool isSubcomponent = false;
        
  if(reduHostNum == 0) reduHostNum = fwInstallationRedu_myReduHostNum();
  
  componentDPs = fwInstallation_getInstalledComponentDps(reduHostNum);
  dynClear(tempAllInfo);

	if(dynlen(componentDPs) == 0)
	{
		return -999999;
	} 
  else 
  {
		for (int i=1; i<=dynlen(componentDPs); i++)
		{  
      dpGet(componentDPs[i]+".name", name,
            componentDPs[i]+".componentVersionString",componentVersionString,
            componentDPs[i]+".installationDirectory",installationDirectory,
            componentDPs[i]+".descFile", descFile,
            componentDPs[i]+".sourceDir", sourcePath,
            componentDPs[i]+".installationNotOK", installationNotOK,
            componentDPs[i]+".requiredInstalled", dependenciesOK,
            componentDPs[i]+".isItSubComponent", isSubcomponent);
      
      fwInstallation_updateComponentVersionFormat(name, reduHostNum);
      dpGet(componentDPs[i]+".componentVersionString", componentVersionString);
                        
      if(patternMatch("*/", sourcePath))
        descFile = sourcePath + descFile;
      else
        descFile = sourcePath + "/" + descFile;
    
      dynAppend(tempAllInfo[i], name);
      dynAppend(tempAllInfo[i], componentVersionString);
      dynAppend(tempAllInfo[i], installationDirectory);
      dynAppend(tempAllInfo[i], descFile);
      dynAppend(tempAllInfo[i], installationNotOK);
      dynAppend(tempAllInfo[i], dependenciesOK);
      dynAppend(tempAllInfo[i], (string)fwInstallation_getComponentPendingPostInstalls(name, reduHostNum));
      dynAppend(tempAllInfo[i], isSubcomponent);
    }
		componentsInfo = tempAllInfo;
		return 0;
	}
}

/** This function gets the information about all available components in the specified paths into a dyn_dyn_string structure:
	- component name
	- component version
	- subcomponent [yes/no]
	- path to the description file

@param componentPaths (in) dyn_string with the paths to description files
@param componentsInfo (out) dyn_dyn_string that will contain all installed components and their respective version numbers and their paths
@param component (in) component pattern
@param scanRecursively (in) flag indicating if the search must recurse over subdirectories
@return 0 if success, -1 if error 
@author S. Schmeling and F. Varela
*/
int fwInstallation_getAvailableComponents(dyn_string componentPaths, 
                                          dyn_dyn_string & componentsInfo, 
                                          string component = "*", 
                                          bool scanRecursively = false)
{
 	string dirCurrentValue;
	dyn_string dynAvailableDescriptionFiles;
	string componentFileName;
	string strComponentFile;
	string tagName;
	string tagValue;

	string componentName;
	string componentVersionString;
	
	int result;
	
	bool	fileLoaded;
	bool isItSubComponent = false;
	
	int i, j, ii, iii;

	dyn_dyn_string tempAllInfo;
	dynClear(tempAllInfo);
	iii = 0;
        
        string dontRestartProject = "no";

	if(dynlen(componentPaths) == 0)
	{
		return -1;
	}

	for(ii=1; ii<=dynlen(componentPaths); ii++)
	{
		dirCurrentValue = componentPaths[ii];
		// it the directory name is empty
		if (dirCurrentValue != "")
		{
			// read the names of files that have the .xml extension in a directory specified by dirCurrentValue
			//FVR: Do it recursively
			if(scanRecursively)
  	          dynAvailableDescriptionFiles =  fwInstallation_getFileNamesRec(dirCurrentValue, component + ".xml");
 	        else
	          dynAvailableDescriptionFiles =  getFileNames(dirCurrentValue, component + ".xml");			

			// for each component description file, read the component name, version and display it in the graphic table
			
			for( i = 1; i <= dynlen(dynAvailableDescriptionFiles); i++)
			{
				// get the file name of an .xml description file
				componentFileName = dynAvailableDescriptionFiles[i];                                
                                dyn_string tags, values;
                                dyn_anytype attribs;
                                int err = 0;
                                
                                if(fwInstallationXml_getTag(dirCurrentValue + "/" + componentFileName, "name", values, attribs) != 0 ||
                                   dynlen(values) <= 0)
                                {
                                  //non-component file
                                  continue;
                                }
                                
                                componentName = values[1];
                                dynClear(values);
                                fwInstallationXml_getTag(dirCurrentValue + "/" + componentFileName, "version", values, attribs);
                                componentVersionString = values[1];
                                
                                dynClear(values);
                                fwInstallationXml_getTag(dirCurrentValue + "/" + componentFileName, "subComponent", values, attribs);
                                if(dynlen(values) > 0 )
                                  if((strtolower(values[1]) == "yes"))
                                    isItSubComponent = true;
                                  else
                                    isItSubComponent = false;
                                                                  
                                dynClear(values);
                                fwInstallationXml_getTag(dirCurrentValue + "/" + componentFileName, "dontRestartProject", values, attribs);
                                if(dynlen(values) > 0 )
                                  dontRestartProject = values[1];

					// check whether the description file contains the component name
					if(componentName != "") 
					{
						iii++;
						dynAppend(tempAllInfo[iii], componentName);
						dynAppend(tempAllInfo[iii], componentVersionString);
						dynAppend(tempAllInfo[iii], dontRestartProject);
						if(isItSubComponent)
						{
							dynAppend(tempAllInfo[iii], "yes");
						} else {
							dynAppend(tempAllInfo[iii], "no");
						}
						dynAppend(tempAllInfo[iii], dirCurrentValue + "/" + componentFileName);
					 	componentName = "";
						isItSubComponent = false;
					}
			}
		}
	}
	componentsInfo = tempAllInfo;
	return 0;
}

//Predefined window titles for fwInstallation_popup() function
const string FW_INSTALLATION_POPUP_TITLE_ERROR = "Installation Error";
const string FW_INSTALLATION_POPUP_TITLE_INFORMATION = "Information";
const string FW_INSTALLATION_POPUP_TITLE_WARNING = "Warning";

/**
 * This function opens a timed out popup with title and test provided as parameter.
 * @param popupText   text to be shown in popup window
 * @param popupTitle  title of the popup window, the default one is "Installation Error". 
 * It is possible to use predefined titles:
 * FW_INSTALLATION_POPUP_TITLE_ERROR - "Installation Error"
 * FW_INSTALLATION_POPUP_TITLE_INFORMATION - "Information"
 * FW_INSTALLATION_POPUP_TITLE_WARNING - "Warning"
 * @author Sascha Schmeling
 */
int fwInstallation_popup(string popupText, string popupTitle = FW_INSTALLATION_POPUP_TITLE_ERROR)
{
  if(myManType() == UI_MAN)
  {
    ChildPanelOnCentralModal("fwInstallation/fwInstallation_popup.pnl", popupTitle, makeDynString("$text:"+popupText));
  }
    
  fwInstallation_throw(popupText, "INFO", 10);

  return 0;
}

/** This function returns the project name
@return project name as string
*/
string paGetProjName()
{
	return PROJ;
}

/** This function retrieves the system name(s) on which a certain 
"application" = component is installed.

@param applicationName	name of the application/component to be found
@param systemNames			name(s) of the system(s) with the application/component installed
@author Sascha Schmeling
*/

void fwInstallation_getApplicationSystem(string applicationName, dyn_string &systemNames)
{
  string tempString;
  dyn_string reduSystems;
  
  systemNames = dpNames("*:fwInstallation_" + applicationName, "_FwInstallationComponents");
  reduSystems = dpNames("*:fwInstallation_" + applicationName + "_2", "_FwInstallationComponents");
  
  for (int i=1; i<=dynlen(reduSystems); i++) 
  {
    tempString = substr(reduSystems[i], 0, strlen(reduSystems[i])-2);
    if (!dynContains(systemNames, tempString))
    {
      dynAppend(systemNames, reduSystems[i]);
    }
  }

  if(dynlen(systemNames) > 0)
  {
    for(int i=1; i<=dynlen(systemNames); i++)
    {
      dpGet(systemNames[i] + ".componentVersionString", tempString);
      if(tempString != "")
        systemNames[i] = dpSubStr(systemNames[i], DPSUB_SYS);
      else
        systemNames[i] = "*" + dpSubStr(systemNames[i], DPSUB_SYS) + "*";
    }
  }

  dynSortAsc(systemNames);
}


/** This function retrieves the PVSS version number as well as the installed patches

@param patches (out) dyn_string array with all installed patches
@return pvss version as a string
*/
string fwInstallation_getPvssVersion(dyn_string & patches)
{
  string pvssVersion = VERSION_DISP;
  dynClear(patches);

  patches = getFileNames(PVSS_PATH, "Readme*.txt");
  for(int i = dynlen(patches); i >= 1; i--) {
    strreplace(patches[i], "Readme", "");
    strreplace(patches[i], ".txt", "");
  }

	return pvssVersion;
}

/** This function shows the help file associated to a component

@param componentName	(in) name of the component in the database
@param systemName (in) name of the system where to look for the component
@author Sascha Schmeling
*/
fwInstallation_showHelpFile(string componentName, string systemName = "")
{
  int replaced;
  string 	path, tempHelpFile, helpFile, browserCommand;
  string dp = fwInstallation_getComponentDp(componentName);
  
  if(!dpExists("fwGeneral.help.helpBrowserCommandWindows"))
  {
    if(myManType() == UI_MAN )
      ChildPanelOnCentral("vision/MessageInfo1", "ERROR", "Sorry you need to install the fwCore\nin order to enable this functionality.");
    else
      fwInstallation_throw("Sorry you need to install the fwCore\nin order to enable this functionality.");
    
    return;
  }
  	
    if(systemName == "")
      systemName = getSystemName();
    
    if(!patternMatch("*:", systemName))
      systemName += ":";

	componentName = strltrim(componentName, "_");
            
	dpGet(dp + ".installationDirectory", path,
              dp + ".helpFile", tempHelpFile);
  
  if(!patternMatch("*/", path))
    path += "/";

	helpFile = path + "help/en_US.iso88591/"+ tempHelpFile;
	
  fwInstallation_normalizePath(helpFile);

	if(_WIN32)
	{
		dpGet(systemName + "fwGeneral.help.helpBrowserCommandWindows", browserCommand);
		if(browserCommand =="")
			browserCommand = "cmd /c start iexplore $1";
		replaced = strreplace(browserCommand, "$1", helpFile);
		if(replaced == 0)
			browserCommand = browserCommand + " " + helpFile;
		system(browserCommand);
	}
	else
	{
		dpGet(systemName + "fwGeneral.help.helpBrowserCommandLinux", browserCommand);
		if(browserCommand =="")
			browserCommand = "mozilla $1";
		replaced = strreplace(browserCommand, "$1", helpFile);
		if(replaced == 0)
			browserCommand = browserCommand + " " + helpFile;
		system(browserCommand);
	}
}	

/** This function gets all entries from the config file into string structures
@param configLines: dyn_string containing the lines from the config file 
@return 0 if OK, -1 if error
@author M. Sliwinski, adapted for library by S. Schmeling and F. Varela
*/
int _fwInstallation_getConfigFile(dyn_string & configLines)
{
	bool fileLoaded = false;
	string fileInString;
	string configPath = getPath(CONFIG_REL_PATH);
	string configFile = configPath + "config";
	
// load config file into dyn_string
	fileLoaded = fileToString(configFile, fileInString);
	if (! fileLoaded )
	{
		fwInstallation_throw("fwInstallationLib: Cannot load config file");
		return -1;
	} else {
		configLines = fwInstallation_splitLines(fileInString);
		return 0;
	}
}

/** this function saves the dyn_string  into PVSS project confg file

@param configLines: the dyn_string containing the lines from the  file
@param filename: the name of a file
@author M.Sliwinski. Modified by F. Varela (with a lot of pain...)
*/
int fwInstallation_saveFile( dyn_string & configLines, string filename)
{
	int i;
	string strLinesToSave;
	

	file fileHdlConfig;
	
	int writeResult;

	// open the file for writing
	fileHdlConfig = fopen(filename, "w");
	// if the file is not opened
	if(fileHdlConfig == 0)
	{
		fwInstallation_throw("fwInstallation: File " + filename + " could not be opened", "error", 4);
		return -1;
	}
	else
	{
		// copy each line from a dyn_string into string and separate the lines with newline character
		for(i = 1; i <= dynlen(configLines); i++)
		{
                  if(configLines[i] !=  "")
                  {
                    if(configLines[i] != "\n")
                    {
                      if(patternMatch("[*", configLines[i]))
                        strLinesToSave += "\n" + configLines[i]; //If a new section, add also a blank line just before
                      
		      strLinesToSave += configLines[i] + "\n";
                    }
                      else
                      strLinesToSave += configLines[i];
                  }     
		}
		// save the string into the file
		writeResult = fputs(strLinesToSave , fileHdlConfig);
		fclose(fileHdlConfig);
		return 0;
	}
}

/** This function returns the list of pending pending post-install scripts and their components
@param components (out) list of components corresponding to the scripts
@param scripts (out) list of pending post-install scripts
*/
void _fwInstallation_GetComponentsWithPendingPostInstall(dyn_string &components, dyn_string &scripts)
{
  dynClear(components);
  dynClear(scripts);
  
  dyn_string compDelimScript;
  dpGet(fwInstallation_getInstallationPendingActionsDp() + ".postInstallFiles", compDelimScript);
  for(int i = 1; i <= dynlen(compDelimScript); i++) {
    int delimPos = strtok(compDelimScript[i], "|");
    if(delimPos < 0) {
      fwInstallation_throw("fwInstallation: Wrong entry " + compDelimScript[i] + " in pending postInstall actions");
      continue;
    }    
 
    string component = substr(compDelimScript[i], 0, delimPos);  
    string script = substr(compDelimScript[i], delimPos + 1);
    dynAppend(components, component);
    dynAppend(scripts, script);
  }
}

/** This function deletes the information for the component from the project config file.

@param componentName: the name of a component
@author S.Schmeling and patched by F. Varela.
*/
void _fwInstallation_DeleteComponentFromConfig(string componentName)
{
	dyn_string configLines; // this table contains the config file - each row contains one line from config file
	string configPath = getPath(CONFIG_REL_PATH);
	string configFile = configPath + "config";
	int i;
	bool insideComponentConfiguration = FALSE;

	if(_fwInstallation_getConfigFile(configLines) == 0)
	{
		for(i=1; i<=dynlen(configLines); i++)
		{		
			if(strltrim(strrtrim(configLines[i])) == "#begin " + componentName)
			{
				insideComponentConfiguration = TRUE;
			}
			else if(strltrim(strrtrim(configLines[i])) == "#end " + componentName)
			{
				insideComponentConfiguration = FALSE;
				dynRemove(configLines, i);
				i--;
			}
                        
			if(insideComponentConfiguration)
			{
				dynRemove(configLines, i);
				i--;
			}
		}
    // save the config file
		fwInstallation_saveFile(configLines, configFile);
	}
	else
	{
		fwInstallation_throw("Failed to get config file content", "ERROR", 10);
	}
}


/** This function creates the Installation Component DPT and DP
@param create (in) flag to indicate if an existing dp-type has to be overwritten (obsolete, legacy)
@param result (out) result of the operation, 0 if OK, -1 if error
@author M.Sliwinski, adapted by S. Schmeling and F. Varela.
*/
_fwInstallation_createDataPointTypes(bool create, int & result)
{
  int n;
  dyn_dyn_string dynDynElements;
  dyn_dyn_int dynDynTypes;
  
  result = 0;
  
  int pos = 1; //Note: [pos++] - first returns pos value, then increments it. 
  dynDynElements[pos] = makeDynString ("_FwInstallationComponents", "", "");
  dynDynTypes[pos++] =  makeDynInt (DPEL_STRUCT);
  
  dynDynElements[pos] = makeDynString ("", "componentFiles", "");
  dynDynTypes[pos++]  = makeDynInt    (0, DPEL_DYN_STRING);
  dynDynElements[pos] = makeDynString ("", "configFiles", "");
  dynDynTypes[pos++]  = makeDynInt    (0, DPEL_STRUCT);

  dynDynElements[pos] = makeDynString ("", "", "configWindows");
  dynDynTypes[pos++]  = makeDynInt    (0, 0, DPEL_DYN_STRING);
  dynDynElements[pos] = makeDynString ("", "", "configLinux");
  dynDynTypes[pos++]  = makeDynInt    (0, 0, DPEL_DYN_STRING);
  dynDynElements[pos] = makeDynString ("", "", "configGeneral");
  dynDynTypes[pos++]  = makeDynInt    (0, 0, DPEL_DYN_STRING);
  

  dynDynElements[pos] = makeDynString ("", "initFiles", "");
  dynDynTypes[pos++]  = makeDynInt    (0, DPEL_DYN_STRING);
  dynDynElements[pos] = makeDynString ("", "postInstallFiles", "");
  dynDynTypes[pos++]  = makeDynInt    (0, DPEL_DYN_STRING);
  
  dynDynElements[pos] = makeDynString ("", "dplistFiles", "");
  dynDynTypes[pos++]  = makeDynInt    (0, DPEL_DYN_STRING);
  dynDynElements[pos] = makeDynString ("", "sourceFilesHashes", "");
  dynDynTypes[pos++]  = makeDynInt    (0, DPEL_DYN_STRING);
  
  dynDynElements[pos] = makeDynString ("", "componentVersion", "");
  dynDynTypes[pos++]  = makeDynInt    (0, DPEL_FLOAT);
  dynDynElements[pos] = makeDynString ("", "date", "");
  dynDynTypes[pos++]  = makeDynInt    (0, DPEL_STRING);
  dynDynElements[pos] = makeDynString ("", "descFile", "");
  dynDynTypes[pos++]  = makeDynInt    (0, DPEL_STRING);
  dynDynElements[pos] = makeDynString ("", "installationDirectory", "");
  dynDynTypes[pos++]  = makeDynInt    (0, DPEL_STRING);
  dynDynElements[pos] = makeDynString ("", "requiredComponents", "");
  dynDynTypes[pos++]  = makeDynInt    (0, DPEL_DYN_STRING);
  dynDynElements[pos] = makeDynString ("", "requiredInstalled", "");
  dynDynTypes[pos++]  = makeDynInt    (0, DPEL_BOOL);
  dynDynElements[pos] = makeDynString ("", "subComponents", "");
  dynDynTypes[pos++]  = makeDynInt    (0, DPEL_DYN_STRING);
  dynDynElements[pos] = makeDynString ("", "isItSubComponent", "");
  dynDynTypes[pos++]  = makeDynInt    (0, DPEL_BOOL);
  dynDynElements[pos] = makeDynString ("", "scriptFiles", "");
  dynDynTypes[pos++]  = makeDynInt    (0, DPEL_DYN_STRING);
  dynDynElements[pos] = makeDynString ("", "componentVersionString", "");
  dynDynTypes[pos++]  = makeDynInt    (0, DPEL_STRING);

  dynDynElements[pos] = makeDynString ("", "deleteFiles", "");
  dynDynTypes[pos++]  = makeDynInt    (0, DPEL_DYN_STRING);
  dynDynElements[pos] = makeDynString ("", "postDeleteFiles", "");
  dynDynTypes[pos++]  = makeDynInt    (0, DPEL_DYN_STRING);

  dynDynElements[pos] = makeDynString ("", "helpFile", "");
  dynDynTypes[pos++]  = makeDynInt    (0, DPEL_STRING);

  dynDynElements[pos] = makeDynString ("", "sourceDir", "");
  dynDynTypes[pos++]  = makeDynInt    (0, DPEL_STRING);
  dynDynElements[pos] = makeDynString ("", "installationNotOK", "");
  dynDynTypes[pos++]  = makeDynInt    (0, DPEL_BOOL);
  dynDynElements[pos] = makeDynString ("", "comments", "");
  dynDynTypes[pos++]  = makeDynInt    (0, DPEL_DYN_STRING);
  dynDynElements[pos] = makeDynString ("", "name", "");
  dynDynTypes[pos++]  = makeDynInt    (0, DPEL_STRING);
  dynDynElements[pos] = makeDynString ("", "description", "");
  dynDynTypes[pos++]  = makeDynInt    (0, DPEL_STRING);
 
  n = dpTypeChange(dynDynElements, dynDynTypes );
        
	// check the result of creating dpts
	if(n == -1)
	  result = -1;
	
	dynClear(dynDynElements);
	dynClear(dynDynTypes);
	
	dynDynElements[1] = makeDynString ("_FwInstallationInformation" , "");
	dynDynElements[2] = makeDynString ("","installationDirectoryPath");
//	dynDynElements[3] = makeDynString ("","postInstallFiles");
//	dynDynElements[4] = makeDynString ("","postDeleteFiles", "");
	dynDynElements[3] = makeDynString ("","lastSourcePath");
	dynDynElements[4] = makeDynString ("","lastInstToolSourcePath");  
	dynDynElements[5] = makeDynString ("","addManagersDisabled");
	dynDynElements[6] = makeDynString ("","activateManagersDisabled");
	dynDynElements[7] = makeDynString ("","version");
	dynDynElements[8] = makeDynString ("", "blockUis");
	dynDynElements[9] = makeDynString ("", "deleteFromConfigFile");
	dynDynElements[10] = makeDynString ("", "status");
	dynDynElements[11] = makeDynString ("", "addManagersOnReduPartner");
	dynDynElements[12] = makeDynString ("", "projectInfo");
	dynDynElements[13] = makeDynString ("", "", "wccoaVersion");
	dynDynElements[14] = makeDynString ("", "", "wccoaPatchList");

	dynDynTypes[1] = makeDynInt (DPEL_STRUCT);
	dynDynTypes[2] = makeDynInt (0, DPEL_STRING);
//	dynDynTypes[3] = makeDynInt (0, DPEL_DYN_STRING);
//	dynDynTypes[4] = makeDynInt (0, DPEL_DYN_STRING);
	dynDynTypes[3] = makeDynInt (0, DPEL_STRING);
	dynDynTypes[4] = makeDynInt (0, DPEL_STRING);  
	dynDynTypes[5] = makeDynInt (0, DPEL_BOOL);
	dynDynTypes[6] = makeDynInt (0, DPEL_BOOL);
	dynDynTypes[7] = makeDynInt (0, DPEL_STRING);
	dynDynTypes[8] = makeDynInt (0, DPEL_BOOL);
	dynDynTypes[9] = makeDynInt (0, DPEL_BOOL);
	dynDynTypes[10] = makeDynInt (0, DPEL_BOOL);
	dynDynTypes[11] = makeDynInt (0, DPEL_BOOL);
	dynDynTypes[12] = makeDynInt (0, DPEL_STRUCT);
	dynDynTypes[13] = makeDynInt (0, 0, DPEL_STRING);
	dynDynTypes[14] = makeDynInt (0, 0, DPEL_DYN_STRING);
		
  n = dpTypeChange(dynDynElements, dynDynTypes );
	
	// check the result of creating dpts
	if(n == -1)
		result = -1;
  
}


bool fwInstallation_getAddManagersOnReduPartner()
{
  bool addManagersOnReduPartner = false;
  dpGet(fwInstallation_getInstallationDp() + ".addManagersOnReduPartner", addManagersOnReduPartner);
  return addManagersOnReduPartner;
}

int fwInstallation_setAddManagersOnReduPartner(bool addManagersOnReduPartner)
{
  return dpSetWait(fwInstallation_getInstallationDp() + ".addManagersOnReduPartner", addManagersOnReduPartner);
}

/** This function proposes an installation directory
  @return path to the installation directory defined by the user as a string
*/
string _fwInstallation_proposeInstallationDir()
{
	string path;
	dyn_string steps;
	steps = strsplit(getPath(LOG_REL_PATH), "/");
	if(dynlen(steps)>2)
		for(int i=1; i<dynlen(steps)-1; i++)
			path += steps[i] +"/";
	else
		path = steps[1] +"/";
	return path + "fwComponents_"+formatTime("%Y%m%d", getCurrentTime())+"/";
}

/** This function returns proposals of the component installation directory.
  * List contains paths from config file appearing in reverse order excluding main project path or if there are no such paths in config file then a set of default locations.
  * @return list of proposed paths for installation directory
  */
dyn_string _fwInstallation_proposeInstallationDirs()
{
  dyn_string installationDirProposals;
  
  // get paths from config file
  dyn_string projPathsInConfig;
  fwInstallation_getProjPaths(projPathsInConfig);
  int projPathsInConfigLen = dynlen(projPathsInConfig) - 1; // exclude main project path (PROJ_PATH)
  for(int i=projPathsInConfigLen;i>0;i--)
    dynAppend(installationDirProposals, projPathsInConfig[i]);
  
  if(dynlen(installationDirProposals) > 0)
    return installationDirProposals;
  
  // if there is no directories other than PROJ_PATH in config file then propose a list of default installation paths
  installationDirProposals = makeDynString(
      _fwInstallation_baseDir(PROJ_PATH) + "fwComponents_" + formatTime("%Y%m%d", getCurrentTime()), // default option
      _fwInstallation_baseDir(PROJ_PATH) + "installed_components", // UNICOS style
      PROJ_PATH + "/fwComponents"); // fwComponents subfolder of the project folder
  fwInstallation_normalizePathList(installationDirProposals);
  return installationDirProposals;
}

/** This function gets the components data from the directory specified in the textBox and fills the graphic table with it.

@param tableName (in) the name of a graphic table to be filled with data 
@param sourceWidget (in) the name of a widget containing the directory from which the data about the components is taken
@param systemName (in) name of the pvss system where to look for components
@param scanRecursively (in) flag indicating if the search must recurse over subdirectories
@return 0 - "success"  -1 - error 
@author M.Sliwinski. Modified by F. Varela.
*/
int fwInstallation_getComponentsInfo(string tableName , 
                                     string sourceWidget, 
                                     string systemName = "", 
                                     bool scanRecursively = false)
{
  string dirCurrentValue;
  dyn_string dynAvailableDescriptionFiles;
  string componentFileName;
  string strComponentFile;
  string tagName;
  string tagValue;

  string componentName;
  string componentVersionString;

  shape shape_dirFromSourceWidget = getShape(sourceWidget);
  shape shape_destinationTable = getShape(tableName);
  int result;

  bool	fileLoaded;
  bool isItSubComponent = false;
  bool isItHiddenComponent = false;

  int i, j;
  bool showSubComponents;
  bool showHiddenComponents;
  string dontRestartProject = "no";
  dyn_anytype attribs;


  if(systemName == "")
    systemName = getSystemName();

  if(!patternMatch("*:", systemName))
    systemName += ":";

  shape_destinationTable.deleteAllLines();

  dirCurrentValue = shape_dirFromSourceWidget.text;
  if (dirCurrentValue == "")
  {
    //fwInstallation_throw("You must define the source directory", "WARNING", 10);
    return 0;
  }

  if(fwInstallation_normalizePath(dirCurrentValue, true) != 0)
    fwInstallation_throw("Failed to normalize directory path: " + dirCurrentValue);

  openProgressBar("FW Component Installation Tool", "copy.gif", "Looking for components in: " + dirCurrentValue, "This make take a while", "Please wait...", 1);

  // read the names of files that have the .xml extension in a directory specified by dirCurrentValue
  //FVR: Do it recursively
  if(scanRecursively)
    dynAvailableDescriptionFiles =  fwInstallation_getFileNamesRec( dirCurrentValue, "*.xml");
  else
    dynAvailableDescriptionFiles = getFileNames(dirCurrentValue, "*.xml");


  if(dynlen(dynAvailableDescriptionFiles) <= 0)
  {
    if(myManType() == UI_MAN)
    {
      ChildPanelOnCentral("vision/MessageInfo1", "Not files found", makeDynString("$1:No component files found.\nAre you sure the directory is readable?"));
    }
    else
    {
      fwInstallation_throw("No component files found.\nAre you sure the directory is readable?");
    }
    closeProgressBar();
    return 0;
  }
  showProgressBar("Found : " + dynlen(dynAvailableDescriptionFiles) + " XML files", "Verifying that they are component files", "Please wait...", 75);

  // for each component description file, read the component name, version and display it in the graphic table
  for( i = 1; i <= dynlen(dynAvailableDescriptionFiles); i++)
  {
    isItSubComponent = false;
    isItHiddenComponent = false;
    // get the file name of an .xml description file
    componentFileName = dynAvailableDescriptionFiles[i];

    // load the description file
    //fileLoaded = fileToString(dirCurrentValue + "/" + componentFileName, strComponentFile);
    dyn_string ds;
    if(fwInstallationXml_getTag(dirCurrentValue + "/" + componentFileName, "name", ds, attribs))
    {
      //fwInstallation_throw("Cannot load " + componentFileName + " file ", "error", 4);
      continue;
    }
    else if(dynlen(ds) < 1)//bug #38484: Check that it is a component file:
      continue;

    componentName = ds[1];

    dynClear(ds);
    fwInstallationXml_getTag(dirCurrentValue + "/" + componentFileName, "version", ds, attribs);
    if(dynlen(ds) < 1)//bug #38484: Check that it is a component file:
    {
      continue; //not a component file
    }
    componentVersionString = ds[1];

    dynClear(ds);
    fwInstallationXml_getTag(dirCurrentValue + "/" + componentFileName, "hiddenComponent", ds, attribs);
    if(dynlen(ds) > 0 && strtolower(ds[1]) == "yes")
      isItHiddenComponent = true;

    dynClear(ds);
    fwInstallationXml_getTag(dirCurrentValue + "/" + componentFileName, "subComponent", ds, attribs);
    if(dynlen(ds) > 0 && strtolower(ds[1]) == "yes")
      isItSubComponent = true;

    ///TODO: check if it is always the same as subcomponent as ds array is not cleared
    fwInstallationXml_getTag(dirCurrentValue + "/" + componentFileName, "dontRestartProject", ds, attribs);
    if((dynlen(ds) > 0 && strtolower(ds[1]) == "yes"))
      dontRestartProject = "yes";

    // check whether the description file contains the component name
    // and whether it is a subcomponent - if it is a subcomponent - do not display it in a table with available components
    getValue("ShowSubComponents","state", 0, showSubComponents);
    // if there is a ShowHiddenComponents button on a panel then get its state, otherwise always show hidden components (checking if shape exists is needed as this function is used also in fwConfigurationDBSystemInformation that doesn't have this checkbox in older versions)
    showHiddenComponents = true;
    if(shapeExists("ShowHiddenComponents"))
    {
      getValue("ShowHiddenComponents","state", 0, showHiddenComponents);
    }

    if((componentName != "") && ((!isItSubComponent) || (isItSubComponent && showSubComponents)) && ((!isItHiddenComponent) || (isItHiddenComponent && showHiddenComponents)))
    {
      // this component can be installed - put it in the table with available components.
      //if (componentName == "") - it means that the xml file does not contain the component name
      //                           or the component file does not describe a component
      // Check if the component is already installed
      if(systemName != "*" || systemName != "*:")  //If we are not dealing with more than one system, look if component is installed
        fwInstallation_componentInstalled(componentName, componentVersionString, result, systemName, true);

      if (result == 1) // component is installed
      {
        if(isItSubComponent)
          shape_destinationTable.appendLine("componentName", "_"+componentName, "componentVersion", componentVersionString, "colStatus" , "Installed" , "descFile", dirCurrentValue + "/" + componentFileName);
        else
          shape_destinationTable.appendLine("componentName", componentName, "componentVersion", componentVersionString, "colStatus" , "Installed" , "descFile", dirCurrentValue + "/" + componentFileName);
      }
      else // component is not installed
      {
        // display the information about the component
        if(isItSubComponent)
          shape_destinationTable.appendLine("componentName", "_"+componentName, "componentVersion", componentVersionString, "descFile", dirCurrentValue + "/" + componentFileName);
        else
          shape_destinationTable.appendLine("componentName", componentName, "componentVersion", componentVersionString, "descFile", dirCurrentValue + "/" + componentFileName);
      }
      componentName = "";
    }
  }

  closeProgressBar();
  return 0;
}



/** This function checks if the component is already installed. It checks the PVSSDB.

@param componentName (in) the name of a component to be checked
@param requestedComponentVersion (in) requested version of the component
@param result (out) result of the operation (obsolete, legacy)
@param systemName (in) system where to check if the component is installed
@param beStrict (in) flag to indicate an exact match of the versions installed and required
@return 1 - "component installed"  0 - "component not installed"
*/
fwInstallation_componentInstalled(string componentName, 
                                  string requestedComponentVersion, 
                                  int &result, 
                                  string systemName = "", 
                                  bool beStrict = false)
{
    string installedComponentVersion,dummy;
    float installedComponentVersionOld;
    string dp = fwInstallation_getComponentDp(componentName);

    if(systemName == "")
      systemName = getSystemName();
    
    if(!patternMatch("*:", systemName))
      systemName += ":";
  	
	// check whether the component data point exists - if it exists it is installed
	if(dpExists(dp))
	{
		// retrieve the version of installed component
		dpGet(dp + ".componentVersionString:_original.._value", installedComponentVersion);

		// Legacy
		if(installedComponentVersion == "")
		{
			fwInstallation_throw("Updating information for component: " + componentName, "INFO", 10);
			dpGet(dp + ".componentVersion:_original.._value", installedComponentVersionOld);
			sprintf(dummy,"%5.5f",installedComponentVersionOld);
			installedComponentVersion = strltrim(strrtrim(dummy,"0"));
			if(strpos(installedComponentVersion,".") == strlen(installedComponentVersion)-1)
			{
				installedComponentVersion += "0";
			}
			dpSet(dp + ".componentVersionString", installedComponentVersion);
		}
		result = (_fwInstallation_CompareVersions(installedComponentVersion,requestedComponentVersion, beStrict));
	}
	else
	{
		// return the component is not installed
		result = 0;
	}	
}

void fwInstallation_updateComponentVersionFormat(string componentName, int reduHostNum = 0)
{
  string componentVersionString, componentVersion;
  if(reduHostNum == 0) reduHostNum = fwInstallationRedu_myReduHostNum();
  
  string dp = fwInstallation_getComponentDp(componentName, reduHostNum);
  dpGet(dp + ".componentVersionString", componentVersionString);
  if(componentVersionString == "")
  {
    dpGet(dp + ".componentVersion", componentVersion);
    if(componentVersion == floor(componentVersion)) sprintf(componentVersionString,"%2.1f",componentVersion);
    else componentVersionString = componentVersion;

    dpSetWait(dp + ".componentVersionString", componentVersionString);
  }
  return;
}

void fwInstallation_showFileIssues(string componentName, bool isSubComponent)
{
   dyn_mapping filesIssues;
   bool showSubComponent = ShowInstalledSubComponents.state(0);
   
   if(isSubComponent && !showSubComponent) //subcomponent but these are not to be shown. do nothing!
     return;
   
   fwInstallation_getComponentFilesIssues(componentName, filesIssues, true, true, false);
   
   if (isSubComponent)
     componentName = "_" + componentName;
   
   string filesIssuesStr = filesIssues;
   if(!isSubComponent)
     tblInstalledComponents.updateLine(1, "componentName", componentName, 
                                        "filesIssuesCount", dynlen(filesIssues),
                                        "filesIssues", filesIssuesStr);
   else
     tblInstalledComponents.updateLine(1, "componentName", componentName, 
                                        "filesIssuesCount", dynlen(filesIssues),
                                        "filesIssues", filesIssuesStr);

   dyn_string componentNameColumn = tblInstalledComponents.getColumnN(tblInstalledComponents.nameToColumn("componentName"));
   int row = dynContains(componentNameColumn, componentName);
   if(row > 0 && dynlen(filesIssues) > 0)
   {
     setValue("tblInstalledComponents", "cellBackColRC", row - 1, "filesIssuesCount", "yellow"); 
   }
   else if(row > 0)
   {
     setValue("tblInstalledComponents", "cellBackColRC", row - 1, "filesIssuesCount", "green"); 
   }
   
  if (shapeExists("fileIssueFeedbackText") && shapeExists("fileIssueFeedbackArrow"))
  {
    fileIssueFeedbackArrow.visible = dynlen(filesIssues);
    fileIssueFeedbackText.visible = dynlen(filesIssues);
    
    fileIssueFeedbackText.text = "Component(s) have file issues.";
  }
}

/** This function retrieves the installed components from the PVSS database and 
fills the graphic table - "tblInstalledComponents"

@author M.Sliwinski and F. Varela
*/

synchronized fwInstallation_getInstalledComponentsUI(int reduHostNum = 0)
{
  dyn_string dynComponentNames, dynComponentNameDps;
  dyn_string systemName_Component;
  dyn_string dataPointTypes;
  dyn_string componentsTempList;
    
  string componentName;
  string componentVersionString;
  float componentVersion;
  bool installationNotOK; 
  string descFile, helpFile;
  string installationDirectory;
  shape shape_destinationTable;
  bool isItSubComponent;	
  int row = 0, column;
  int i;	
  dyn_string ds;
  unsigned systemId;
  bool showSubComponents = false;
  bool requiredInstalled = true;

  string tempFileIssuesStr = "Not checked";
  // get shape of the graphic table	
  tblInstalledComponents.deleteAllLines();

  if(reduHostNum == 0)
  {
    reduHostNum = fwInstallationRedu_myReduHostNum();
  }  
  
  fwInstallation_checkComponentBrokenDependencies(reduHostNum);  
  bool errorCompNotPropInstalled, errorCompBrokenDepend;
  
  // get existing data point types
  showSubComponents = ShowInstalledSubComponents.state(0);
	
  // get the names of all installed components
  dynComponentNameDps = fwInstallation_getInstalledComponentDps(reduHostNum);
  dynComponentNames = dynComponentNameDps;
  dyn_dyn_string componentsInfo;
  fwInstallation_getInstalledComponents(componentsInfo, reduHostNum);
  for (i= 1; i<= dynlen(componentsInfo); i++)
  {
    dynAppend(componentsTempList, componentsInfo[i][1]);
  }
  bool showingLocalPear =  reduHostNum == 0 || reduHostNum == fwInstallationRedu_myReduHostNum();
   
  for (i = 1; i <= dynlen(dynComponentNames); i++)
  {
    requiredInstalled = true;
    installationNotOK = false;
    dynComponentNames[i] = dpSubStr( dynComponentNames[i], DPSUB_DP );
    strreplace(dynComponentNames[i], "fwInstallation_" , "");
    componentName = dynComponentNames[i];
      
    fwInstallation_updateComponentVersionFormat(componentName, reduHostNum);
    dyn_string subcomponents;
    dynClear(subcomponents);
    dpGet(dynComponentNameDps[i] + ".installationNotOK", installationNotOK,
          dynComponentNameDps[i] + ".isItSubComponent", isItSubComponent,
          dynComponentNameDps[i] + ".helpFile", helpFile,
          dynComponentNameDps[i] + ".name", componentName,
          dynComponentNameDps[i] + ".subComponents", subcomponents,
          dynComponentNameDps[i] + ".requiredInstalled", requiredInstalled,
          dynComponentNameDps[i] + ".componentVersionString", componentVersionString);
    
    //check that the sub-components are actually installed. If not, remove them from the list:      
    for(int z = dynlen(subcomponents); z >= 1; z--)
    {
      string ver = "";
      if(!fwInstallation_isComponentInstalled(subcomponents[z], ver, reduHostNum)) dynRemove(subcomponents, z);
    }
			
    // if it is the subcomponent
    if(isItSubComponent)
      continue;
    
    if(showingLocalPear)
    {
      // this is not the sub-component - display it in a graphic table
      if(helpFile != "")
        tblInstalledComponents.appendLine("componentName", componentName, 
                                          "componentVersion", componentVersionString,
                                          "helpFile", "HELP", 
                                          "filesIssuesCount", tempFileIssuesStr);
      else
        tblInstalledComponents.appendLine("componentName", componentName, 
                                          "componentVersion", componentVersionString,
                                          "filesIssuesCount", tempFileIssuesStr);
      //startThread("fwInstallation_showFileIssues", componentName);
      int pos = dynContains(componentsTempList, componentName);
      if (pos > 0)
        dynRemove(componentsTempList, pos);
     
    }
    else
    {
      // this is not the sub-component - display it in a graphic table
      if(helpFile != "")
        tblInstalledComponents.appendLine("componentName", componentName, 
                                          "componentVersion", componentVersionString,
                                          "helpFile", "HELP");
      else
        tblInstalledComponents.appendLine("componentName", componentName, 
                                          "componentVersion", componentVersionString);
    }
    
    // check if the components required by this component are installed
    if(!requiredInstalled)
    {
      setValue("tblInstalledComponents", "cellBackColRC", row, "componentName", "STD_trend_pen6");
      errorCompBrokenDepend = true;
    }
    
    if(installationNotOK)
    {
      setValue("tblInstalledComponents", "cellBackColRC", row, "componentName", "red"); 
      errorCompNotPropInstalled = true;
    }
    ++row;
    

    //are there subcomponent and do they have to be shown?   
    if(dynlen(subcomponents))
    {
      dynSortAsc(subcomponents);
      //Check which version of the subcomponent is installed
      for(int k = 1; k <= dynlen(subcomponents); k++)
      {
        int pos = dynContains(componentsTempList, subcomponents[k]);
        if (pos > 0)
          dynRemove(componentsTempList, pos);

        requiredInstalled = true;
        installationNotOK = false;
        fwInstallation_updateComponentVersionFormat(subcomponents[k], reduHostNum);
        dpGet(fwInstallation_getComponentDp(subcomponents[k], reduHostNum) + ".installationNotOK", installationNotOK,
              fwInstallation_getComponentDp(subcomponents[k], reduHostNum) + ".helpFile", helpFile,
              fwInstallation_getComponentDp(subcomponents[k], reduHostNum) + ".componentVersionString", componentVersionString);
        
        errorCompBrokenDepend = errorCompBrokenDepend || !requiredInstalled;
        errorCompNotPropInstalled = errorCompNotPropInstalled || installationNotOK;

        // show subComponents:
        if (showSubComponents)
        {
          if (showingLocalPear)
          {
            if(helpFile != "")
              tblInstalledComponents.appendLine("componentName", "_"+subcomponents[k], 
                                                "componentVersion", componentVersionString,
                                                "helpFile", "HELP",
                                                "filesIssuesCount", tempFileIssuesStr);
            else
              tblInstalledComponents.appendLine("componentName", "_"+subcomponents[k], 
                                                "componentVersion", componentVersionString, 
                                                "filesIssuesCount", tempFileIssuesStr);
            //startThread("fwInstallation_showFileIssues", subcomponents[k], true);

          }
          else
          {
            if(helpFile != "")
              tblInstalledComponents.appendLine("componentName", "_"+subcomponents[k], 
                                                "componentVersion", componentVersionString,
                                                "helpFile", "HELP");
            else
              tblInstalledComponents.appendLine("componentName", "_"+subcomponents[k], 
                                                "componentVersion", componentVersionString);
          }
        
          // check if the components required by this component are installed
          if(!requiredInstalled)
          {
            setValue("tblInstalledComponents", "cellBackColRC", row, "componentName", "STD_trend_pen6");
          }   
 
          if(installationNotOK)
          {
            setValue("tblInstalledComponents", "cellBackColRC", row, "componentName", "red"); 
          }       
          ++row;
        }
      }
    }
  }
  
  //adding subcomponents without components
  if (showSubComponents)
  {
    for(int k = 1; k <= dynlen(componentsTempList); k++) // the only things left in the list are subcomponents for which the component is not installed
    {
      requiredInstalled = true;
      installationNotOK = false;
      fwInstallation_updateComponentVersionFormat(componentsTempList[k], reduHostNum);
      dpGet(fwInstallation_getComponentDp(componentsTempList[k], reduHostNum) + ".installationNotOK", installationNotOK,
            fwInstallation_getComponentDp(componentsTempList[k], reduHostNum) + ".helpFile", helpFile,
            fwInstallation_getComponentDp(componentsTempList[k], reduHostNum) + ".componentVersionString", componentVersionString);
        
      errorCompBrokenDepend = errorCompBrokenDepend || !requiredInstalled;
      errorCompNotPropInstalled = errorCompNotPropInstalled || installationNotOK;

      if (showingLocalPear)
      {
        if(helpFile != "")
          tblInstalledComponents.appendLine("componentName", "_"+componentsTempList[k], 
                                            "componentVersion", componentVersionString,
                                            "helpFile", "HELP",
                                            "filesIssuesCount", tempFileIssuesStr);
        else
          tblInstalledComponents.appendLine("componentName", "_"+componentsTempList[k], 
                                            "componentVersion", componentVersionString, 
                                            "filesIssuesCount", tempFileIssuesStr);
//        startThread("fwInstallation_showFileIssues", componentsTempList[k], true);

      }
      else
      {
        if(helpFile != "")
          tblInstalledComponents.appendLine("componentName", "_"+componentsTempList[k], 
                                            "componentVersion", componentVersionString,
                                            "helpFile", "HELP");
        else
          tblInstalledComponents.appendLine("componentName", "_"+componentsTempList[k], 
                                            "componentVersion", componentVersionString);
      }
        
      // check if the components required by this component are installed
      if(!requiredInstalled)
      {
        setValue("tblInstalledComponents", "cellBackColRC", row, "componentName", "STD_trend_pen6");
      }   
 
      if(installationNotOK)
      {
        setValue("tblInstalledComponents", "cellBackColRC", row, "componentName", "red"); 
      }       
      ++row;
    }
  }
  
  fileIssueFeedbackArrow.visible = errorCompNotPropInstalled || errorCompBrokenDepend;
  fileIssueFeedbackText.visible = errorCompNotPropInstalled || errorCompBrokenDepend;

  if(errorCompNotPropInstalled && errorCompBrokenDepend)
  {
    fileIssueFeedbackText.text = "Component(s) not correctly installed, broken dependencies and file issues.";
  }
  else if(errorCompNotPropInstalled)
  {    
    fileIssueFeedbackText.text = "Component(s) not correctly installed and file issues.";
  }  
  else if(errorCompBrokenDepend)
  {
    fileIssueFeedbackText.text = "Component(s) have broken dependencies and file issues.";
  }
  return;
}

/** this functions outputs the message into the log textarea of a panel
@param message: the message to be displayed
*/
fwInstallation_showMessage(dyn_string message)
{
  int i, length = dynlen(message);
  string isUI = false;
  if(myManType() == UI_MAN && shapeExists("list")) isUI = true;
 
  for (i = 1; i <= length; i++)
  {
    fwInstallation_writeToMainLog(message[i] + "\n");
    if(isUI){
      list.appendItem(message[i]);	
    }
  }
  
  if(isUI){
    length = list.itemCount();
    list.bottomPos(length);
    list.selectedPos(length);
  }
}

/** This function executes a script from the component .init file

@param componentInitFile: the .init file with the functions to be executed
@param iReturn: -1 if error calling the script, otherwise, it returns the error code of the user script
@author F. Varela
*/
fwInstallation_evalScriptFile(string componentInitFile , int &iReturn)
{
	string fileInString;
	anytype retVal;
	int result;

  if(access(componentInitFile, R_OK) != 0)	
  {
    fwInstallation_throw("Execution of script: " + componentInitFile + " aborted as the file is not readable");
    iReturn = -1;
    return;
  }
 
	if (!fileToString(componentInitFile, fileInString))
	{
		fwInstallation_throw("fwInstallation: Cannot load " + componentInitFile);
		iReturn =  -1;
   return;
	}
  
  iReturn = evalScript(retVal, fileInString, makeDynString("$value:12345"));
  if(iReturn)
    return;
  
  iReturn = retVal; //Make iReturn equal to the error code returned by the user script
  
  return;  
}

// Delimiter of main parts of component version sequence [versionNumber]-[preReleaseTag]-[preReleaseNumber] (e.g. 1.2.3-beta-4)
const string FW_INSTALLATION_COMPONENT_VERSION_PARTS_DELIMITER = "-"; 

/** Parse parts of componet version sequence ([versionNumber]-[preReleaseTag]-[preReleaseNumber]).
  * All parts are optional, however, if present, they must appear in the presented order. Any characters after third '-' delimiter are discarded.
  * @private Used in version comparison (_fwInstallation_CompareVersions())
  * @param versionString (in)  String containing component version sequence.
  * @param versionNumber (out)  Main version number (first part of component version sequence)
  * @param preReleaseTag (out)  Pre-release tag (second part of component version sequence)
  * @param preReleaseNumber (out)  Pre-release number (third part of component version sequence)
  */
private _fwInstallation_CompareVersions_parseVersionParts(string versionString, string &versionNumber, string &preReleaseTag, string &preReleaseNumber)
{
  versionNumber = "";
  preReleaseTag = "";
  preReleaseNumber = "";

  dyn_string versionParts = strsplit(versionString, FW_INSTALLATION_COMPONENT_VERSION_PARTS_DELIMITER);
  int versionPartsLen = dynlen(versionParts);
  if(versionPartsLen >= 1){ versionNumber = versionParts[1];
    if(versionPartsLen >= 2){ preReleaseTag = versionParts[2];
      if(versionPartsLen >= 3){ preReleaseNumber = versionParts[3];}
    }
  }
}

const string FW_INSTALLATION_COMPONENT_VERSION_NUMBERS_SEQUENCE_DELIMITER = "."; // Delimiter of version numbers sequence [major].[minor].[...]...
// Constants below are used in internal version comparison functions, they are not intended to use for comparison with returned values of _fwInstallation_CompareVersions() function.
const int FW_INSTALLATION_INSTALLED_COMPONENT_VERSION_IS_HIGHER = 1; // Indicates that installed component version (first argument of interal version comparison functions) is higher than requested component version
const int FW_INSTALLATION_REQUESTED_COMPONENT_VERSION_IS_HIGHER = 2; // Indicates that requested component version (second argument of interal version comparison functions) is higher than installed component version
const int FW_INSTALLATION_BOTH_VERSIONS_ARE_EQUAL = 0;               // Indicates that both provided component versions are equal, must be lower than previus ones

/** Compares given parts of version strings as sequence of version number strings ([major].[minor].[...]...). Version number strings can contain non-numerical character.
  * @private Used in version comparison (_fwInstallation_CompareVersions())
  * @param instCompVersionNumber (in)  Part of version string of installed component
  * @param reqCompVersionNumber (in)  Part of version string of requested component
  * @return Integer value that indicates whether first or second argument contains higher version string.
  *         Following codes are possible: FW_INSTALLATION_INSTALLED_COMPONENT_VERSION_IS_HIGHER, FW_INSTALLATION_REQUESTED_COMPONENT_VERSION_IS_HIGHER, FW_INSTALLATION_BOTH_VERSIONS_ARE_EQUAL
  */
private int _fwInstallation_CompareVersions_compareVersionNumbers(string instCompVersionNumber, string reqCompVersionNumber)
{
  // Split version number string into parts
  dyn_string instCompVersionNumberParts = strsplit(instCompVersionNumber, FW_INSTALLATION_COMPONENT_VERSION_NUMBERS_SEQUENCE_DELIMITER);
  dyn_string reqCompVersionNumberParts = strsplit(reqCompVersionNumber, FW_INSTALLATION_COMPONENT_VERSION_NUMBERS_SEQUENCE_DELIMITER);
  int instCompVersionNumberPartsLen = dynlen(instCompVersionNumberParts);
  int reqCompVersionNumberPartsLen = dynlen(reqCompVersionNumberParts);

  int commonPartsLen = (instCompVersionNumberPartsLen < reqCompVersionNumberPartsLen)?
                       instCompVersionNumberPartsLen:reqCompVersionNumberPartsLen;
  // Compare each part of the version number until difference is found or all parts of shorter list are checked
  for(int i=1;i<=commonPartsLen;i++)
  {
    int comparisonResult = _fwInstallation_CompareVersions_compareVersionNumberPart(instCompVersionNumberParts[i],
                                                                                    reqCompVersionNumberParts[i]);
    if(comparisonResult > FW_INSTALLATION_BOTH_VERSIONS_ARE_EQUAL) return comparisonResult;
  }
  // If all common parts are equal, the one with more parts of version number is higher. If number of parts is equal then version numbers are equal.
  if(instCompVersionNumberPartsLen > commonPartsLen) return FW_INSTALLATION_INSTALLED_COMPONENT_VERSION_IS_HIGHER;
  if(reqCompVersionNumberPartsLen > commonPartsLen) return FW_INSTALLATION_REQUESTED_COMPONENT_VERSION_IS_HIGHER;
  return FW_INSTALLATION_BOTH_VERSIONS_ARE_EQUAL;
}

/** Compares given strings containing particular number (string) eg. [major] from the sequence of version numbers strings ([major].[minor].[...]...)
  * @private Used in version comparison (_fwInstallation_CompareVersions_compareVersionNumbers())
  * @param instCompVersionNumberPart (in)  Single number from the sequence of version numbers of installed component version
  * @param reqCompVersionNumberPart (in)  Single number from the sequence of version numbers of required component version,
  *                                       must be on the same position in the sequence of version numbers as instCompVersionNumberPart
  * @return Integer value that indicates whether first or second argument contains higher number.
  *         Following codes are possible: FW_INSTALLATION_INSTALLED_COMPONENT_VERSION_IS_HIGHER, FW_INSTALLATION_REQUESTED_COMPONENT_VERSION_IS_HIGHER, FW_INSTALLATION_BOTH_VERSIONS_ARE_EQUAL
  */
private int _fwInstallation_CompareVersions_compareVersionNumberPart(string instCompVersionNumberPart, string reqCompVersionNumberPart)
{
  // Parse number and modifier (if present) from the single "number" string of version numbers strings sequence,
  // eg. "1a" results in number=1 and modifier="a", "a" -> number=0 and modifier="a" (this way also alphabetic characters are handled in the version number)
  string installVerModifier, requestVerModifier;
  int installVerNumber = _fwInstallation_CompareVersions_parseNumberAndModifierString(instCompVersionNumberPart, installVerModifier);
  int requestVerNumber = _fwInstallation_CompareVersions_parseNumberAndModifierString(reqCompVersionNumberPart, requestVerModifier);
  // Compare numbers
  if(installVerNumber > requestVerNumber) return FW_INSTALLATION_INSTALLED_COMPONENT_VERSION_IS_HIGHER;
  if(installVerNumber < requestVerNumber) return FW_INSTALLATION_REQUESTED_COMPONENT_VERSION_IS_HIGHER;

  return _fwInstallation_CompareVersions_compareVersionStrings(installVerModifier, requestVerModifier);
}

/** Parses number (integer value) and modifier string (string of alphanumeric characters that appears after the integer value)
  * from given part of version numbers string sequence.
  * @private Used in version comparison (_fwInstallation_CompareVersions_compareVersionNumberPart())
  * @param versionNumberPart (in)  Part of the sequence of version numbers strings ([major].[minor].[...]...)
  * @param modifierString (out)  Modifier string for the retrieved numeric value.
  * @return Integer value retrieved from the first numeric characters of versionNumberPart.
  */
private int _fwInstallation_CompareVersions_parseNumberAndModifierString(string versionNumberPart, string &modifierString)
{
  int number;
  if(sscanf(versionNumberPart, "%d", number) > 0){
    string numberAsString;
    sprintf(numberAsString, "%d", number); // Format number back to string to get its position in versionNumberPart string
    int modifierStringPos = strpos(versionNumberPart, numberAsString) + strlen(numberAsString); // Find position of first character of modifier string
    modifierString = substr(versionNumberPart, modifierStringPos);
  }else{ // If versionNumberPart string does not begin with numeric character - asssuming that whole versionNumberPart string is modifier and integer number is 0.
    modifierString = versionNumberPart;
  }
  return number;
}

/** This function compares two version strings as a string of characters. Higher string is the one with character with higher ASCII code
  * on the first position that differs in both string. If one string is longer than the other and the common parts are equal then the longer string is higher.
  * An exception is a situation when one string is empty - then it is considered to be higher as string version should be used to indicate pre-release versions.
  * @private Used in version comparison (_fwInstallation_CompareVersions_compareVersionNumberPart(), _fwInstallation_CompareVersions())
  * @param instCompVersionString (in)  Part of installed component version identifier that should be compared as a string
  * @param reqCompVersionString (in)  Part of requested component version identifier corresponding to the same part of instCompVersionString
  * @return Integer value that indicates whether first or second argument contains higher string version.
  *         Following codes are possible: FW_INSTALLATION_INSTALLED_COMPONENT_VERSION_IS_HIGHER, FW_INSTALLATION_REQUESTED_COMPONENT_VERSION_IS_HIGHER, FW_INSTALLATION_BOTH_VERSIONS_ARE_EQUAL
  */
private int _fwInstallation_CompareVersions_compareVersionStrings(string instCompVersionString, string reqCompVersionString)
{
  if(instCompVersionString == "" && reqCompVersionString == "") return FW_INSTALLATION_BOTH_VERSIONS_ARE_EQUAL;
  if(instCompVersionString == "" && reqCompVersionString != "") return FW_INSTALLATION_INSTALLED_COMPONENT_VERSION_IS_HIGHER;
  if(reqCompVersionString == "") return FW_INSTALLATION_REQUESTED_COMPONENT_VERSION_IS_HIGHER;
  if(instCompVersionString > reqCompVersionString) return FW_INSTALLATION_INSTALLED_COMPONENT_VERSION_IS_HIGHER;
  if(instCompVersionString < reqCompVersionString) return FW_INSTALLATION_REQUESTED_COMPONENT_VERSION_IS_HIGHER;
  return FW_INSTALLATION_BOTH_VERSIONS_ARE_EQUAL;
}

/** This function compares two component versions.
  The following version format is supported: [versionNumber]-[preReleaseTag]-[preReleaseNumber] (e.g. 1.2.3-beta-4). 
  preReleaseTag and preReleaseNumber are not mandatory and they are used for indicating the pre-release version of component (eg. beta).
  - preReleaseTags (second part of version format) are compared as a strings (string is higher when it has a character with higher ASCII code on the first position that differs in both strings).
  - versionNumbers and preReleaseNumbers are compared as a sequence of version numbers ([major].[minor].[...]...).
    Single part of the sequence (element) can contain number and a string modifier (eg. 10a -> number=10, modifier="a"). Numer contains all numerical chracter starting from the first position in element of a sequence.
    If at the first position is non-numerical character it is assumed that number has value of 0. Any characters that appears after the first non-numerical character are treated as a string modifier and they are compared as a string (so 1a10 < 1a9)
    hence next versions should not be indicated this way (for this pupose 'number' part should be used).
    If element contains modifier it is considered to be lower than the element that contains only the number (10a < 10) - it gives possibility to indicate pre-release version by the modifier (eg. 1.1beta)
  If version contain pre-release tags then it is lower than the version with the same versionNumber that does not have any pre-release tags (1.0.0-beta-1 < 1.0.0).
  @param installedComponentVersion (in) Version name as string of the installed component
  @param requestedComponentVersion (in) Required component version
  @param beStrict (in) If set to true, the comparison will required that both component versions as identical
  @param caseSensitive (in) Indicates if comparison of alphabetical characters should be case-sensitive (by default false)
  @return 1 if the required component is equal or older than the version installed (if beStrict=false), 0 otherwise
*/
int _fwInstallation_CompareVersions(string installedComponentVersion, string requestedComponentVersion, bool beStrict = false, bool caseSensitive = false)
{
  if(!caseSensitive){ // Prepare for case-insensitive comparison
    installedComponentVersion = strtolower(installedComponentVersion);
    requestedComponentVersion = strtolower(requestedComponentVersion);
  }
  
  if(installedComponentVersion == requestedComponentVersion) // Skip detailed comparison if version strings are equal
    return 1;
  
  // Extract main parts of version string
  string instCompVersionNumber, instCompPreReleaseTag, instCompPreReleaseNumber;
  _fwInstallation_CompareVersions_parseVersionParts(installedComponentVersion, instCompVersionNumber,
                                                    instCompPreReleaseTag, instCompPreReleaseNumber);
  string reqCompVersionNumber, reqCompPreReleaseTag, reqCompPreReleaseNumber;
  _fwInstallation_CompareVersions_parseVersionParts(requestedComponentVersion, reqCompVersionNumber,
                                                    reqCompPreReleaseTag, reqCompPreReleaseNumber);
  // Compare version numbers
  int versionNumbersComparisonResult = _fwInstallation_CompareVersions_compareVersionNumbers(instCompVersionNumber, reqCompVersionNumber);
  if(versionNumbersComparisonResult == FW_INSTALLATION_INSTALLED_COMPONENT_VERSION_IS_HIGHER) return beStrict?0:1;
  if(versionNumbersComparisonResult == FW_INSTALLATION_REQUESTED_COMPONENT_VERSION_IS_HIGHER) return 0;
  
  // Compare pre-release tags as a strings
  int preReleaseTagComparisonResult = _fwInstallation_CompareVersions_compareVersionStrings(instCompPreReleaseTag, reqCompPreReleaseTag);
  if(preReleaseTagComparisonResult == FW_INSTALLATION_INSTALLED_COMPONENT_VERSION_IS_HIGHER) return beStrict?0:1;
  if(preReleaseTagComparisonResult == FW_INSTALLATION_REQUESTED_COMPONENT_VERSION_IS_HIGHER) return 0;
  
  // Check if both version strings contains pre-release number
  if(instCompPreReleaseNumber == "" && reqCompPreReleaseNumber != "") return beStrict?0:1;
  if(instCompPreReleaseNumber != "" && reqCompPreReleaseNumber == "") return 0;
  // Compare pre-release numbers
  int preReleaseNumbersComparisonResult = _fwInstallation_CompareVersions_compareVersionNumbers(instCompPreReleaseNumber, reqCompPreReleaseNumber);
  if(preReleaseNumbersComparisonResult == FW_INSTALLATION_INSTALLED_COMPONENT_VERSION_IS_HIGHER) return beStrict?0:1;
  if(preReleaseNumbersComparisonResult == FW_INSTALLATION_REQUESTED_COMPONENT_VERSION_IS_HIGHER) return 0;
  //else - installed component version and requested component version are equal
  return 1;
}

/** this function deletes the component  files
@param componentFiles: the dyn_string with the names of the files to be deleted
@param installationDirectory: the name of the installation directory
@return 0 if OK, -1 if errors
@author M.Sliwinski and modified by F. Varela
*/

int fwInstallation_deleteFiles(dyn_string componentFiles, string installationDirectory)
{
  fwInstallation_normalizePath(installationDirectory, true);
  
  string fileToDelete;
  // Deleting the files
  for(int i=1;i<=dynlen(componentFiles);i++)
  {
    // remove the first dot in file name
    fileToDelete = installationDirectory + strltrim(componentFiles[i], ".");
    
    if(isfile(fileToDelete) && remove(fileToDelete) != 0)
    {
      fwInstallation_showMessage(makeDynString("Could not delete file " + installationDirectory + fileToDelete));
      return -1;
    }	
  }
  return 0;
}

/** This function writes to the main log
@author M.Sliwinski
*/
fwInstallation_writeToMainLog(string message)
{
  file logFile;
  int i;
	
  string fileName = getPath(LOG_REL_PATH) + "/fwInstallation.log";
	
  fwInstallation_normalizePath(fileName);

  logFile = fopen(fileName,"a");
  if(ferror(logFile) != 0)
  {
    fwInstallation_throw("fwInstallation: Cannot write to LogFile "+fileName, "error", 4);
  } 
  else 
  {
    fprintf(logFile,"%s\n",message);
  }
  fclose(logFile);
  
}
/** This function retrieves the path from a full filename
@param filePath (in) full file name (basedir + filename)
@return path to the file
*/
string _fwInstallation_baseDir(string filePath)
{
  if(filePath == "")
    return "";
  
  string baseDir = dirName(filePath);
  if(baseDir == "//")
    return "/";
  
  return baseDir;
}

/** This function retrieves the name of a file from the full path to the file
@param filePath (in) full file name (basedir + filename)
@return filename as string
*/
string _fwInstallation_fileName(string filePath)
{
  return baseName(filePath);
}


/** This function puts the components to be installed in order in which they should be installed 
The algorithm is similar to that used during deleting the components (see fwInstallation_putComponentsInOrder_Delete() function btn_ApplyDelete()) 
 
@param componentsNames: the names of the components to be installed 
@param componentsVersions: the versions of components to be installed 
@param componentFiles: the file names with the description of the components 
@param componentFilesInOrder: the  file names with the description of the components

@author F. Varela and R. Gomez-Reino
*/
int fwInstallation_putComponentsInOrder_Install(dyn_string & componentsNames, 
                                                dyn_string & componentsVersions, 
                                                dyn_string & componentFiles, 
                                                dyn_string & componentFilesInOrder)  
{
  dyn_dyn_string dependecyMatrix;
  dyn_string componentsInOrder;
  dyn_string tempDynRequired;
  dyn_string componentSubComps;
  mapping componentToDependencies;

  for(int i = 1; i <= dynlen(componentFiles); i++)	
  {
     componentFiles[i] = fwInstallationDBAgent_getComponentFile(componentFiles[i]);
     
     fwInstallation_readComponentRequirements(componentFiles[i], tempDynRequired);  
     fwInstallation_readSubcomponents(componentFiles[i], componentSubComps);
       
     //put that each of the subcomponents has the same dependencies like its component
     //and in addition add that each component dependns on the subcomponents before it in the list
     dyn_string tempComponentSubComps = componentSubComps;
     for (int j=dynlen(componentSubComps); j >= 1; j--)
     {
       dynRemove(tempComponentSubComps, j);
       //if the subcomponent should be installed
       if (dynContains(componentsNames, componentSubComps[j]))
       {
         dyn_string currentDependencies;
         if (mappingHasKey(componentToDependencies, componentSubComps[j]))
         {
           currentDependencies = componentToDependencies[componentSubComps[j]];
         }
         dyn_string tmp = tempComponentSubComps;
         dynAppend(currentDependencies, tmp);
         tmp = tempDynRequired;
         dynAppend(currentDependencies, tmp);           
         dynUnique(currentDependencies);
         componentToDependencies[componentSubComps[j]] = currentDependencies;
       }
     }
     
     // put implicit dependency of the component on the subcomponent
     for (int j=1; j <= dynlen(componentSubComps); j++)
     {
       //only if the subcomponents is going to be installed
       if (dynContains(componentsNames, componentSubComps[j]))
       {
         dynAppend(tempDynRequired, componentSubComps[j]);
       }
     }
    
     //add the dependencies to the mapping that will be used for building the dependency matrix
     if (mappingHasKey(componentToDependencies, componentsNames[i]))
     {
       dyn_string currentDependencies = componentToDependencies[componentsNames[i]];
       dynAppend(currentDependencies, tempDynRequired);
       dynUnique(currentDependencies);
       componentToDependencies[componentsNames[i]] = currentDependencies;
     }
     else
     {
       componentToDependencies[componentsNames[i]] = tempDynRequired;
     }

  } 

  //build the dependency matrix
  dyn_string componentWithDependencies = mappingKeys(componentToDependencies);
  int k =1;
  for (int i=1; i<=dynlen(componentWithDependencies); i++)
  {
    int originalIndex = dynContains(componentsNames, componentWithDependencies[i]);
    if (originalIndex >= 0)
    {
      //if the component has dependencies
      if (dynlen(componentToDependencies[componentWithDependencies[i]]) > 0)
      {
        dependecyMatrix[k] = makeDynString(componentWithDependencies[i], componentFiles[originalIndex]);
        dynAppend(dependecyMatrix[k], componentToDependencies[componentWithDependencies[i]]);
        k++;
      }
      else
      {
        dynAppend(componentFilesInOrder,componentFiles[originalIndex]);
        dynAppend(componentsInOrder, componentWithDependencies[i]);
      }
    }
  }

  // +1 just make it different to fail first cyclic dependency test
  int lastDepMatrixSize = dynlen(dependecyMatrix) + 1;
  while (dynlen(dependecyMatrix)>0)
  {
    dyn_dyn_string remaningMatrix ; 
    remaningMatrix = dependecyMatrix; 
    for (int i=1;i<=dynlen(dependecyMatrix);i++)
    {
      bool skip = false;
      for (int j=3;j<=dynlen(dependecyMatrix[i]);j++)
      {        
        string componentName = dependecyMatrix[i][j];
        int pos = strpos(dependecyMatrix[i][j],"=");
        if (pos > 0)
          componentName =  substr(componentName, 0, pos);
        if (!dynContains(componentsInOrder, componentName) && 
             dynContains(componentsNames, componentName))
        {
          skip = true;
        }
      }    

      if(lastDepMatrixSize == dynlen(dependecyMatrix))
      {
        fwInstallation_throw("fwInstallation: cyclic dependency in components detected, aborting installation", "error", 10);
        return -1;
      }

      if(skip == false)
      {
          dynAppend(componentFilesInOrder,dependecyMatrix[i][2]); 
          dynAppend(componentsInOrder,dependecyMatrix[i][1]);
          for(int g=dynlen(remaningMatrix);g>=1;g--)
          {
            if(remaningMatrix[g][1] == dependecyMatrix[i][1])
            {
              dynRemove(remaningMatrix,g);
            }
          }          
      }
    }
    
    lastDepMatrixSize = dynlen(dependecyMatrix);
    dependecyMatrix = remaningMatrix;
  }
  
  fwInstallation_throw("Resulting list of components sorted for installation according to their dependencies: " +  componentsInOrder + ". Please wait...", "INFO");
  if(fwInstallationDB_getUseDB() && fwInstallationDB_connect() == 0)
  {
    fwInstallationDB_storeInstallationLog();
  }
  
  return 0;
}

/** This function reads the requirements from the component description file

@param descFile (in) the file with the description of a component 
@param dynRequiredComponents (out) the dyn_string of requiredComponents
@author M.Sliwinski
*/
fwInstallation_readComponentRequirements(string descFile, dyn_string & dynRequiredComponents)
{
	bool	fileLoaded;
	string strComponentFile;
	string tagName;
	string tagValue;
	int i;
        dyn_anytype attribs;
        dyn_string values;

	// clear the required components table
	dynClear(dynRequiredComponents);
	
	if(_WIN32)
	{
		strreplace(descFile, "/", "\\");
	}	
	// load the description file into strComponentFile string
        if(fwInstallationXml_getTag(descFile, "required", dynRequiredComponents, attribs))
        {
          fwInstallation_throw("fwInstallation_readComponentRequirements() -> Cannot load " + descFile + " file ", "error", 4);
          return;
        }
		
}

/** This function reads the sub components from the component description file
@param descFile (in) the file with the description of a component 
@param dynSubcomponents (out) the dyn_string of the subcomponents
*/
fwInstallation_readSubcomponents(string descFile, dyn_string & dynSubcomponents)
{
  dynClear(dynSubcomponents);
  fwInstallation_normalizePath(descFile);
  // load the description file into strComponentFile string
  dyn_string subcompFiles;
  dyn_anytype attribs;
  if(fwInstallationXml_getTag(descFile, "includeComponent", subcompFiles, attribs))
  {
    fwInstallation_throw("fwInstallation_readSubcomponents() -> Cannot load " + descFile + " file ", "error", 4);
    return;
  }

  string componentDirectory = fwInstallation_getComponentPath(descFile);
  dyn_string values;
  //read the names of the components
  for(int i=1;i<=dynlen(subcompFiles);i++)
  {
    strreplace(subcompFiles[i], "./", "/");
    dynClear(values);
    fwInstallationXml_getTag(componentDirectory + subcompFiles[i], "name", values, attribs);
    if(dynlen(values) > 0)
      dynAppend(dynSubcomponents, values[1]);
  }
}

/** This function resolves the Pmon Information (i.e. user name and password)
  @param user (out) user 
  @param pwd (out) password
  @return 0 if OK, -1 if errors.
*/
int fwInstallation_getPmonInfo(string &user, string &pwd)
{
  dyn_float df;
  dyn_string ds;
  dyn_mixed projectProperties;
  int projectId;
  
  //Cache Segment
    bool isProjectRegisteredCache = false;
    string dbCacheProjectUser = "";         
    string dbCacheProjectPassword = "";     
    dyn_mixed dbProjectInfo;                
    if( globalExists("gDbCache") && mappingHasKey(gDbCache, "dbProjectInfo") ) { 
       dbProjectInfo = gDbCache["dbProjectInfo"];                               
       if( dynlen(dbProjectInfo) > 1 ) {                                       
         isProjectRegisteredCache = true;                                      
         dbCacheProjectUser = dbProjectInfo[FW_INSTALLATION_DB_PROJECT_PMON_USER];
         dbCacheProjectPassword = dbProjectInfo[FW_INSTALLATION_DB_PROJECT_PMON_PWD];
       }                                                                       
     }                                                                         
  //End Cache segment                                                       
                                                                               
  
  //Check if password can be read from the DB
  if(gFwInstallationPmonUser != "N/A" && gFwInstallationPmonPwd != "N/A")   //nothing to be done. Globals have already been initialized
  {
    user = gFwInstallationPmonUser;
    pwd = gFwInstallationPmonPwd;    
    return 0;
  }
  
  if(!fwInstallation_isPmonProtected())
  {
    //Nothing to be done; Return empty strings
    user = "";
    pwd = "";
  }
  else if(fwInstallationDB_getUseDB() && fwInstallationDB_connect() == 0)
  {
    if( isProjectRegisteredCache ) {
      user = dbCacheProjectUser;
      pwd = dbCacheProjectPassword;
    } else {
      if(fwInstallationDB_isProjectRegistered(projectId, PROJ, strtoupper(fwInstallation_getHostname())))
      {
        fwInstallation_throw("fwInstallation_getPmonInfo() -> Could not access the DB to read the PMON info. Failed to check if the project is registered in the System Configuration DB", "error", 7);
        gFwInstallationPmonUser = "N/A";
        gFwInstallationPmonPwd = "N/A";
        return -1;
      }
      else if(projectId == -1)
      {
        if(myManType() != UI_MAN)
        {
          fwInstallation_throw("fwInstallation_getPmonInfo() -> Project not yet registered in the DB. Cannot resolve the pmon parameters from the System Configuration DB", "warning", 10);
          gFwInstallationPmonUser = "N/A";
          gFwInstallationPmonPwd = "N/A";
          return -1;
        }
        else
        {
          fwInstallation_throw("Prompting user to enter PMON info", "INFO", 10);
          int err = fwInstallation_askForPmonInfo(user, pwd);
          gFwInstallationPmonUser = user;
          gFwInstallationPmonPwd = pwd;
          return err;
        }
      }
      else if(fwInstallationDB_getProjectProperties(PROJ, strtoupper(fwInstallation_getHostname()), projectProperties, projectId))
      {
        fwInstallation_throw("fwInstallation_getPmonInfo() -> Could not access the DB to read the PMON info", "error", 7);
        gFwInstallationPmonUser = "N/A";
        gFwInstallationPmonPwd = "N/A";
        return -1;
      }
    
      user = projectProperties[FW_INSTALLATION_DB_PROJECT_PMON_USER];
      pwd = projectProperties[FW_INSTALLATION_DB_PROJECT_PMON_PWD];    
     }
  } 
  else if(myManType() == UI_MAN)
  {
    fwInstallation_askForPmonInfo(user, pwd);
  }
  else
  {
    fwInstallation_throw("Could not resolve pmon username/password");
    user = "N/A";
    pwd = "N/A";
    gFwInstallationPmonUser = "N/A";
    gFwInstallationPmonPwd = "N/A";
    return -1;
  }
  
  gFwInstallationPmonUser = user;
  gFwInstallationPmonPwd = pwd;

  return 0; 
}      

int fwInstallation_askForPmonInfo(string &user, string &pwd)
{
  dyn_string ds;
  dyn_float df;
  ChildPanelOnCentralReturn("fwInstallation/fwInstallation_pmon.pnl", "Username/Password required", makeDynString(""), df, ds);
  if(!dynlen(df) || df[1] != 1.)
  {
    user = "N/A";
    pwd = "N/A";
//    gFwInstallationPmonUser = "N/A";
//    gFwInstallationPmonPwd = "N/A";
    return -1;
  }
  else
  {
    user = ds[1];
    pwd = ds[2];
  }
  
  return 0;
}

/** This function forces the restart of the whole project
@author F. Varela
*/
int fwInstallation_forceProjectRestart()
{
  string host;
  int port;
  int iErr = paGetProjHostPort(paGetProjName(), host, port);
  string cmd;              
  string user, pwd;
  string dpr = fwInstallation_getAgentRequestsDp();

  
  //Try to use first pmon without user and password and see if it fails:
  if(!fwInstallation_isPmonProtected())
  {
    cmd = "##RESTART_ALL:";
    if(!pmon_command(cmd, host, port, FALSE, TRUE))
    {
      fwInstallation_throw("FW Installation Tool forcing project restart now. Please, wait...", "INFO", 10);
      //Project successfully restarted. We are done
      return 0;
    }
  }
  
  //Pmon does have a username and password. Try to resolve them on the fly.
  fwInstallation_getPmonInfo(user, pwd);       
  cmd = user + "#" + pwd + "#" + "RESTART_ALL:";    
  
  paVerifyPassword(PROJ, user, pwd, iErr);
  if(iErr)
  {
    fwInstallation_throw("Invalid Pmon Username/Password. Cannot restart the project", "WARNING", 6);
    return -1;
  }
  if(pmon_command(cmd, host, port, FALSE, TRUE))
  {
    fwInstallation_throw("Cannot restart the project", "WARNING");
    return -1;
  }

  fwInstallation_throw("FW Installation Tool forcing project restart", "INFO", 10);
  return 0;          
}


/** This function resolves the source path from the component description file
  @param componentFile (out) full path to the XML file of the component 
  @return source directory
*/
string fwInstallation_getComponentPath(string componentFile)
{
  return _fwInstallation_baseDir(componentFile);
}

/** This function retrieves whether the component can be registered only 
    or if all component files have to be copied during installation
  @param destinationDir (in) target directory for installation. 
                         Note that a previous installtion of the component may exist in there.
  @param componentName (in) name of the component being installed
  @param forceOverwriteFiles (in) flag to force overwriting of existing files
  @param isSilent (in) flag to specify if the installation is silent (no windows will be pop up even during interactive installation)
  @return 0 if OK, -1 if error.
*/
int fwInstallation_getRegisterOnly(string destinationDir, 
                                   string componentName, 
                                   bool forceOverwriteFiles, 
                                   bool isSilent)
{
  int registerOnly = 0;
  string installedVersion;
  dyn_string ds;
  dyn_float df;
  
  if(fwInstallationDB_getUseDB() && fwInstallationDB_getCentrallyManaged() && !forceOverwriteFiles && fwInstallation_checkTargetDirectory(destinationDir, componentName, installedVersion))
  {
    registerOnly = 1; 
  }                            
  else if(!gFwYesToAll && fwInstallation_checkTargetDirectory(destinationDir, componentName, installedVersion) && !forceOverwriteFiles)
  {
   if(!isSilent && myManType() == UI_MAN){
      ChildPanelOnCentralReturn("fwInstallation/fwInstallation_messageInfo3", "Warning", makeDynString("$1:Version " + installedVersion + " of \"" + componentName + "\" \nalready exists in the destination directory.\n\nDo you want to overwrite the files?"), df, ds); 
     
      if(df[1] < 0.){
         fwInstallation_throw("fwInstallation_getRegisterOnly() -> Installation of " + componentName + " aborted by the user.", "INFO");
         return -1;
      }else if(df[1] == 1.){
                        fwInstallation_throw("fwInstallation_getRegisterOnly() -> Overwriting files of component" + componentName + " in directory " + destinationDir, "INFO");
         registerOnly = 0;
      }else if(df[1] == 0.){
         fwInstallation_throw("INFO: fwInstallation_getRegisterOnly() -> Registering component " + componentName + " only. Not copying files...", "INFO");
         registerOnly = 1;
         }else{
           gFwYesToAll = true;
         }
     
      } else{
          fwInstallation_throw("fwInstallation_getRegisterOnly() -> Registering component " + componentName + " only. Not copying files...", "INFO");
          registerOnly = 1;
      }
  }
  else if(fwInstallation_isComponentInstalled(componentName, installedVersion))
  {
    string previousDir = "";
    dyn_anytype componentProperties;
    fwInstallation_getComponentInfo(componentName, "installationdirectory", componentProperties);
    
    if(dynlen(componentProperties))
      previousDir = componentProperties[1];
    
    if(destinationDir != previousDir)
     {
       if(!isSilent)
       {
         if(myManType() == UI_MAN )
        {
                ChildPanelOnCentralReturn("fwInstallation/fwInstallation_messageInfo3", "Warning", makeDynString("$1:Version " + installedVersion + " of the component \"" + componentName + "\" \nwas previously installed in a different path.\n\nDo you want to proceed?"), df, ds); 
           if(df[1] <= 0.)
           {
             fwInstallation_throw("fwInstallation_getRegisterOnly() -> Installation of " + componentName + " aborted by the user.", "INFO");
             return -1;
           }
           else if(df[1] > 0)
           {
                          fwInstallation_throw("fwInstallation_getRegisterOnly() -> Installing component " + componentName + " in a new directory: " + destinationDir, "INFO");
             registerOnly = 0;
           }
           else
           {
             gFwYesToAll = true;
           }
        }
      }
    }
  }
  else
    registerOnly = 0;

  return registerOnly;
}


/** This function forces all required components to be installed prior to the installation of a given component if available in the distribution
 @param componentName (in) name of the component being installed
 @param dynRequiredComponents (in) array of required components
 @param sourceDir (in) source directory for installation
 @param forceInstallRequired (in) flag to force installation of required components
 @param forceOverwriteFiles (in) flag to force all existing files to be overwritten
 @param isSilent (in) flag to define if the installation is silent, i.e. no pop-ups
 @param requiredInstalled (out) returned argument indicating if the required components have been successfully installed or not
 @param actionAborted (out) flag that indicates if the action was aborted by the user
 @return 0 if OK, -1 if errors
*/
int fwInstallation_installRequiredComponents(string componentName, 
                                             dyn_string dynRequiredComponents, 
                                             string sourceDir, 
                                             bool forceInstallRequired, 
                                             bool forceOverwriteFiles, 
                                             bool isSilent, 
                                             int & requiredInstalled, 
                                             bool &actionAborted)
{
  string strNotInstalledNames = "";
  dyn_string dsNotInstalledComponents, dsFileComponentName, dsFileComponentVersion, dsFileComponent;
  dyn_string dreturns;
  dyn_string dreturnf;
  string componentPath;
  
  actionAborted = false;
  
  fwInstallation_getNotInstalledComponentsFromRequiredComponents(dynRequiredComponents, strNotInstalledNames);
	
  // show the panel that asks if it should be installed
  if( strNotInstalledNames != "")
  {
    fwInstallation_throw("Missing at installation of "+componentName+ ": " + strNotInstalledNames, "info", 10);
      
    //If all components are available proceed with the installation otherwise cancel installation of dependent components by claering the arrays
    dsNotInstalledComponents = strsplit(strNotInstalledNames, "|");
    
    fwInstallation_checkDistribution(sourceDir, dsNotInstalledComponents, dsFileComponentName, dsFileComponentVersion, dsFileComponent);
		
    //FVR: Check the forceInstallRequired flag is not set:
    if(!forceInstallRequired)
    {
      // show the panel informing the user about broken dependencies
      if(myManType() == UI_MAN )
        ChildPanelOnCentralReturn("fwInstallation/fwInstallationDependency.pnl", "Dependencies of " + componentName,
	                          makeDynString("$strDependentNames:" + strNotInstalledNames , "$componentName:" + componentName, "$fileComponentName:" + dsFileComponentName, "$fileComponentVersion:" + dsFileComponentVersion), dreturnf, dreturns);
      else
        dreturns[1] = "Install_Delete"; //Force installation of this component

      // check the return value
      if(dreturns[1] == "Install_Delete")
      {
	      requiredInstalled = false;
	      fwInstallation_showMessage(makeDynString("User choice at installation of "+componentName+": INSTALL"));
      }
      else if(dreturns[1] == "DoNotInstall_DoNotDelete")
      {
	      fwInstallation_showMessage(makeDynString("User choice at installation of "+componentName+": ABORT"));
        actionAborted = true;
	      return gFwInstallationOK;
      }
      else if(dreturns[1] == "InstallAll_DeleteAll"){  
        forceInstallRequired = true;     //FVR: 30/03/2006: Install all required components
      }
    }

   //Check if flag is now true -> Need of another if since the value of the flag could have changed in the previous loop
   if(forceInstallRequired){
     //update number of components with added required components
     fwInstallation_reportUpdateTotalComponentsNumber(dynlen(dsFileComponentName));
     
     for(int kk = 1; kk <= dynlen(dsFileComponentName); kk++)
     {
       fwInstallation_reportComponentInstallationProgress(dsFileComponentName[kk], FW_INSTALLATION_REPORT_STEP_STARTING_INSTALLATION);
       componentPath = fwInstallation_getComponentPath(dsFileComponent[kk]);
       string componentSubPath = substr(componentPath, strlen(sourceDir));
       bool componentInstalled = false;
       string dontRestartProject = "no";
       fwInstallation_throw("Forcing installation of the required component: " + dsFileComponentName[kk] + " v." + dsFileComponentVersion[kk], "INFO");
       if(fwInstallation_installComponent(dsFileComponent[kk], 
                                          sourceDir, 
                                          false, 
                                          dsFileComponentName[kk], 
                                          componentInstalled, 
                                          dontRestartProject,
                                          componentSubPath, 
                                          forceInstallRequired, 
                                          forceOverwriteFiles, 
                                          isSilent) == gFwInstallationError && isSilent)
       {
         // + report installation status (success/error)
         if(dsFileComponentName[kk] != "")
           fwInstallation_reportComponentInstallationFinished(dsFileComponentName[kk]);
         
         fwInstallation_showMessage(makeDynString("ERROR: Silent installation failed installing dependent component: " + componentName)); 
         fwInstallation_throw("Silent installation failed installing dependent component: " + componentName); 
         string dp = fwInstallation_getComponentDp(dsFileComponentName[kk]);
         
         dpSet(dp + ".installationNotOK", false);
	       return gFwInstallationError;
       }
       if(dsFileComponentName[kk] != "")
           fwInstallation_reportComponentInstallationFinished(dsFileComponentName[kk]);
      }
     }
   }  // end check the component dependencies

  return 0; 
}

/** This function checks the syntax of a component script
 @note Obsolete: From version 8.1.1 script checking is no longer performed (FWINS-2105)
 @param sourceDir (in) source directory for installation
 @param subPath (in) path to the appended to the source directory
 @param script name of the script to be tested
 @return 0 if OK, -1 if errors
*/
int fwInstallation_checkScript(string sourceDir, string subPath, string script)
{
  string strTestFile;
  if (!fileToString(sourceDir + subPath + script, strTestFile))
  {
    fwInstallation_throw("fwInstallation: init script "+ sourceDir + subPath + script + " cannot be loaded", "WARNING", 10);
    return -1;
  } 
  else 
  {  
    if(!checkScript(strTestFile))
    {
      fwInstallation_throw("fwInstallation: init script "+ sourceDir + subPath + script + " is not valid", "WARNING", 10);
      return -1;
    }
  }
  
  return 0;
}


/** This function verifies the integrity of a package
 @note Signature of this function may changed in the future due to obsolence of several arguments.
 @param sourceDir (in) source directory for installation
 @param subPath (in) path to be appended to the sourceDir
 @param componentName (in) name of the component being installed
 @param destinationDir (in) target directory for installation
 @param registerOnly (in) flag indicating whether file copying can be avoided or not if the files already exist
 @param dynInitFiles (in) component init scripts - obsolete - no longer used
 @param dynPostInstallFiles (in) component post-install scripts - obsolete - no longer used
 @param dynDeleteFiles (in) component delete scripts - obsolete - no longer used
 @param dynPostDeleteFiles (in) component post-delete scripts
 @param dynFileNames (in) component files
 @param isSilent (in) flag to define if the installation is silent, i.e. no pop-ups
 @param actionAborted (out) flag that indicates if the action was aborted by the user
 @return 0 if OK, -1 if error
*/
int fwInstallation_verifyPackage(string sourceDir, 
                                 string subPath,
                                 string componentName,
                                 string destinationDir,
                                 bool registerOnly, 
                                 dyn_string dynInitFiles, 
                                 dyn_string dynPostInstallFiles, 
                                 dyn_string dynDeleteFiles,
                                 dyn_string dynPostDeleteFiles,
                                 const dyn_string &dynFileNames,
                                 int isSilent,
                                 bool &actionAborted)
{
  actionAborted = false;
  dyn_string strErrors;

  if(access(destinationDir, W_OK) != 0 && !registerOnly)
  {
    string strError = "The folder " + destinationDir + " is not write enabled";
    dynAppend(strErrors, strError);
    fwInstallation_throw("fwInstallation: " + strError);
  }

  int dynFileNamesLen = dynlen(dynFileNames);
  for(int i=1;i<=dynFileNamesLen;i++)
  {
    if(access(sourceDir + subPath + "/" + dynFileNames[i], R_OK) != 0)
    {
      string strError = "The file " + sourceDir + subPath + "/" + dynFileNames[i] + " does not exist";
      dynAppend(strErrors, strError);
      fwInstallation_throw(strError, "WARNING", 3);
    }
  }

  int errorCounter = dynlen(strErrors);
  if(errorCounter!=0)
  {
    if(!isSilent)
    {
      dyn_string dreturns;
      dyn_float dreturnf;
      
      if(myManType() == UI_MAN )
      {
        ChildPanelOnCentralReturn("fwInstallation/fwInstallationShowErrors.pnl", "Installation Errors",
                                  makeDynString("$strErrors:" + strErrors , "$componentName:" + componentName), dreturnf, dreturns);
      }
      else
        dreturns[1] = "Install_Delete";
      
      // check the return value
      if(dreturns[1] == "Install_Delete")
      {
        fwInstallation_throw("fwInstallation: "+errorCounter+" error(s) found. Installation of "+componentName+" will continue on user request", "WARNING", 10);
        return gFwInstallationError;
      }
      else if(dreturns[1] == "DoNotInstall_DoNotDelete")
      {
        fwInstallation_throw("fwInstallation: "+errorCounter+" error(s) found. Installation of "+componentName+" is aborted", "INFO");
        actionAborted = true;
        return gFwInstallationOK;
      }
    }
    else
    {
      fwInstallation_throw("fwInstallation: "+errorCounter+" error(s) found. Silent installation of "+componentName+" is aborted");
      actionAborted = true;
      return gFwInstallationError;
    }
  }
  return 0;
}

/** This function copies all component files
 @param componentName (in) name of the component being installed
 @param sourceDir (in) source directory for installation
 @param subPath (in) path to be appended to the sourceDir
 @param destinationDir (in) target directory for installation
 @param dynFileNames (in) component files
 @param registerOnly (in) flag indicating whether file copying can be avoided or not if the files already exist
 @param isSilent (in) flag to define if the installation is silent, i.e. no pop-ups
 @return 0 if OK, -1 if error
*/
int fwInstallation_copyComponentFiles(string componentName, 
                                      string sourceDir, 
                                      string subPath, 
                                      string destinationDir, 
                                      dyn_string dynFileNames, 
                                      bool registerOnly, 
                                      bool isSilent)
{
  string fileToCopy;
  int i;
  int errorCounter;
  string errorString;
  int fileCopied;
  int errorInstallingComponent = 1; // has value -1 if there were any errors during the component installation, 1 if everything is OK

  string dp = fwInstallation_getComponentDp(componentName);
  
  if(sourceDir != destinationDir)
  {
    if(dynlen(dynFileNames) > 0)
      fwInstallation_showMessage(makeDynString("    Copying files ...."));
    
    for (i =1; i <= dynlen(dynFileNames); i++)
    {
      //strreplace( destinationDir, "//", "/" );
      //strreplace( sourceDir, "//", "/" );
      
      fileToCopy = strltrim(dynFileNames[i], ".");
      
      if(!registerOnly){
        fileCopied =  fwInstallation_copyFile(sourceDir+ subPath + fileToCopy, destinationDir + fileToCopy);
      }
      
      if(fileCopied != 0 && !registerOnly) 
      {
        fwInstallation_throw("Error copying file - source: " + sourceDir+ subPath + fileToCopy + " destination: " + destinationDir + fileToCopy, "error", 4);
        fwInstallation_showMessage(makeDynString("      Error copying file: " + fileToCopy));
        if(dpExists(dp + ".installationNotOK")) dpSet(dp + ".installationNotOK", true);
        return -1;
      }
    }
  }
  return 0;
}

/** This function imports the dpl files of a component
 @param componentName (in) name of the component being installed
 @param sourceDir (in) source directory for installation
 @param subPath (in) path to be appended to the sourceDir
 @param dynDplistFiles (in) list of dpl files to be imported
 @param updateTypes (in) flag to indicate if existing types have to be updated or not
 @return 0 if OK, -1 if error
*/
int fwInstallation_importComponentAsciiFiles(string componentName, 
                                             string sourceDir, 
                                             string subPath, 
                                             dyn_string dynDplistFiles, 
                                             bool updateTypes = true)
{
  string fileToCopy;
  string asciiFile;
  string cmd;
  string infoFile = getPath(LOG_REL_PATH) + fwInstallation_getWCCOAExecutable("ascii") + "_info.log";
  string logFile =  getPath(LOG_REL_PATH) + fwInstallation_getWCCOAExecutable("ascii") + "_log.log";
  int err;
  int errorInstallingComponent = 0;
  string result;
  dyn_string resultInLines;  
  int i = 1;
  string dplistFile;
  string asciiManager = PVSS_BIN_PATH + fwInstallation_getWCCOAExecutable("ascii");
  
  string commitCnt = "";//command line option that indicates how many messages the ASCII Man waits for a reply from the Event Man
  if(_WIN32)
  {
    commitCnt = "-commit 10";//set this option to 10 messages on Windows (on Linux this is 10 by default)
  }
  
  string dp = fwInstallation_getComponentDp(componentName);
  string host = fwInstallation_getHostname();
  for( i = 1; i <= dynlen(dynDplistFiles); i++)
  {	
    dplistFile = dynDplistFiles[i];
    fwInstallation_throw("Importing dplist file: " + dplistFile, "INFO");
    fileToCopy = strltrim(dplistFile, ".");
    asciiFile = sourceDir+ subPath + fileToCopy;
    
    if(asciiFile == "")
    {
      fwInstallation_throw("fwInstallation_importComponentAsciiFiles() -> Empty ASCII file name passed for component: " + componentName);
								 
      dpSet(dp + ".installationNotOK", true);
      return gFwInstallationError;
    }
    else
    {
      if(updateTypes)
      {
        fwInstallation_throw("Calling ASCII manager with DP-Type update option", "INFO", 10);
        cmd = asciiManager + " -event " + host + ":" + eventPort() + " -data " + host + ":" + dataPort() + " -in " + commitCnt + " \"" + asciiFile + "\" -yes -log +stderr -log -file > " + infoFile + " 2> " + logFile;
      }
      else
      {
        fwInstallation_throw("Calling ASCII manager with NO DP-Type update option", "INFO", 10);
        cmd = asciiManager + " -event " + host + ":" + eventPort() + " -data " + host + ":" + dataPort() + "  -in " + commitCnt + " \"" + asciiFile + "\" -log +stderr -log -file > " + infoFile + " 2> " + logFile;
      }

      if (_WIN32) 
      {
        err = system("cmd /c " + cmd);
      }
      else  //LIN
      {
        err = system(cmd);
      }

      if (err < 0)
      {
        fwInstallation_throw("Could not import properly the file " + asciiFile + " (Error number = " + err +")");
        errorInstallingComponent = -1;
      }
      else if(err > 0)
      {
        fwInstallation_throw("Warnings while importing the dpl file " + asciiFile + " (Error number = " + err +"). Find details in PROJ_PATH/log/" + fwInstallation_getWCCOAExecutable("ascii") + ".log. The installation will proceed anyway...", "WARNING", 10);
      }
      
      // Show result of the import of the current file in the log text field
      fileToString (logFile, result);
      resultInLines = fwInstallation_splitLines(result);
      fwInstallation_showMessage(resultInLines);
    }
    fwInstallation_showMessage(makeDynString(""));
  }
  
  if(errorInstallingComponent == -1)
    return -1;
  
  return 0;
}

/** This function imports the dpl files of a component
 @param componentName (in) name of the component being installed
 @param sourceDir (in) source directory for installation
 @param subPath (in) path to be appended to the sourceDir
 @param dynConfigFiles_general (in) list of dpl files to be imported
 @param dynConfigFiles_linux (in) list of dpl files to be imported (linux only)
 @param dynConfigFiles_windows (in) list of dpl files to be imported (windows only)
 @return 0 if OK, -1 if error
*/
int fwInstallation_importConfigFiles(string componentName, 
                                     string sourceDir, 
                                     string subPath,
                                     dyn_string dynConfigFiles_general, 
                                     dyn_string dynConfigFiles_linux, 
                                     dyn_string dynConfigFiles_windows)
{
  int i = 1;
  string componentConfigFile;
  
  for(i = 1; i <= dynlen(dynConfigFiles_linux); i++)
  {
    if(! _WIN32)
    {
      fwInstallation_showMessage(makeDynString("    Importing linux config file ... "));
      componentConfigFile = sourceDir+ subPath + strltrim(dynConfigFiles_linux[i], ".");
      if (strtolower(substr(componentConfigFile, strlen(componentConfigFile) - 5)) == ".redu" &&
          fwInstallationRedu_isRedundant())
      {
        fwInstallation_addComponentIntoConfigRedu( componentConfigFile,  componentName);
      }
      else
        fwInstallation_AddComponentIntoConfig( componentConfigFile,  componentName);
    }
  }
// end import config files for linux

// import config files for windows

  for(i = 1; i <= dynlen(dynConfigFiles_windows); i++)
  {
    if(_WIN32)
    {
      fwInstallation_showMessage(makeDynString("    Importing windows config file ... "));
      componentConfigFile = sourceDir+ subPath + strltrim(dynConfigFiles_windows[i], ".");
      
      if (strtolower(substr(componentConfigFile, strlen(componentConfigFile) - 5)) == ".redu" &&
          fwInstallationRedu_isRedundant())
      {
        fwInstallation_addComponentIntoConfigRedu( componentConfigFile,  componentName);
      }
      else
        fwInstallation_AddComponentIntoConfig( componentConfigFile,  componentName);
    }
  }
// end import config files for windows
		
// import config files
  if(dynlen(dynConfigFiles_general) > 0)
    fwInstallation_throw("Importing general config file ... ", "INFO");
  
  for(i = 1; i <= dynlen(dynConfigFiles_general); i++)
  {
    componentConfigFile = sourceDir+ subPath + strltrim(dynConfigFiles_general[i], ".");
    if (strtolower(substr(componentConfigFile, strlen(componentConfigFile) - 5)) == ".redu" &&
          fwInstallationRedu_isRedundant())
    {
      fwInstallation_addComponentIntoConfigRedu( componentConfigFile,  componentName);
    }
    else
      fwInstallation_AddComponentIntoConfig( componentConfigFile,  componentName);
  }
  
  return 0;
}


/** This function executes the component init scripts
 @param componentName (in) name of the component being installed
 @param sourceDir (in) source directory for installation
 @param subPath (in) path to be appended to the sourceDir
 @param dynInitFiles (in) list of init files to be executed
 @param isSilent (in) flag to define if the installation is silent, i.e. no pop-ups
 @return 0 if OK, -1 if error
*/
int fwInstallation_executeComponentInitScripts(string componentName, 
                                               string sourceDir, 
                                               string subPath, 
                                               dyn_string dynInitFiles, 
                                               int isSilent)
{
  int i;
  string componentInitFile;
  int iReturn;
  
  for(i =1; i <= dynlen(dynInitFiles); i++)
  {
    componentInitFile = sourceDir + subPath+ strltrim(dynInitFiles[i], ".");
    fwInstallation_throw("Executing the init file : " + componentInitFile, "INFO");
	
    // read the file and execute it
    fwInstallation_evalScriptFile(componentInitFile , iReturn);
    if(iReturn == -1)
    {
      fwInstallation_throw("Error executing script: " + componentInitFile);
      return -1;
    }
  }
  return 0; 
}

/** This function stores in the component internal dp of the installation tool the list of post install scripts to be run with names
  of the components from which they came in following format "<component>|<postInstallScript>"
 @param component (in) components corresponding to post-install scripts
 @param dynPostInstallFiles_current (in) list of post-install files to be stored
 @return 0 if OK, -1 if error
*/
int fwInstallation_storeComponentPostInstallScripts(const string &component, const dyn_string &dynPostInstallFiles_current)
{
  dyn_string dynPostInstallFiles_all;
  string dp = fwInstallation_getInstallationPendingActionsDp();

  dpGet(dp + ".postInstallFiles", dynPostInstallFiles_all);
  for(int i = 1; i <= dynlen(dynPostInstallFiles_current); i++) {
    dynAppend(dynPostInstallFiles_all, component + "|" + dynPostInstallFiles_current[i]); 
  }
  dpSet(dp + ".postInstallFiles", dynPostInstallFiles_all);			
  
  return 0;
}

/** This function creates the internal dp for the installed component
 @param componentName (in) name of the component being installed
 @param componentVersion (in) component version
 @param descFile (in) component description file
 @param isItSubComponent (in) component description file
 @param sourceDir (in) source directory for installation
 @param date (in) source directory for installation
 @param helpFile (in) source directory for installation
 @param destinationDir (in) source directory for installation
 @param dynComponentFiles (in) source directory for installation
 @param dynConfigFiles_general (in) list of dpl files to be imported
 @param dynConfigFiles_linux (in) list of dpl files to be imported (linux only)
 @param dynConfigFiles_windows (in) list of dpl files to be imported (windows only)
 @param dynInitFiles (in) list of init scripts
 @param dynPostInstallFiles (in) list of post install scritps
 @param dynDeleteFiles (in) list of delete scripts
 @param dynPostDeleteFiles (in) list of post-delete scripts
 @param dynDplistFiles (in) list of dpl files
 @param dynRequiredComponents (in) list of required components
 @param dynSubComponents (in) list of subcomponents
 @param dynScriptsToBeAdded (in) list of scritps
 @param requiredInstalled (in) flag to indicated if the required component were installed
 @param comments (in) component comments
 @param description (in) component description
 @return 0 if OK, -1 if error
*/
int fwInstallation_createComponentInternalDp(string componentName, string componentVersion, 
                                             string descFile, int isItSubComponent, 
                                             string sourceDir, string date, 
                                             string helpFile, string destinationDir,
                                             dyn_string dynComponentFiles, dyn_string dynConfigFiles_general, 
                                             dyn_string dynConfigFiles_linux, dyn_string dynConfigFiles_windows,
                                             dyn_string dynInitFiles, dyn_string dynPostInstallFiles, 
                                             dyn_string dynDeleteFiles, dyn_string dynPostDeleteFiles,
                                             dyn_string dynDplistFiles,
                                             dyn_string dynRequiredComponents, dyn_string dynSubComponents, 
                                             dyn_string dynScriptsToBeAdded, int requiredInstalled, 
                                             dyn_string comments,
                                             string description)
{
  // save the component info into the PVSS database
  fwInstallation_throw("Saving the component info into the database: " + componentName + " v." + componentVersion, "INFO");
  string dp = fwInstallation_getComponentDp(componentName);
  
  if (dpCreate(dp, "_FwInstallationComponents") == 0 )
  {
    dpSet(dp + ".componentVersion", componentVersion,
          dp + ".componentVersionString", componentVersion,
          dp + ".descFile", descFile,
          dp + ".sourceDir", sourceDir,
          dp + ".installationDirectory", destinationDir,
          dp + ".date", date,
          dp + ".helpFile", helpFile,
          dp + ".componentFiles", dynComponentFiles,
          dp + ".configFiles.configGeneral", dynConfigFiles_general,
          dp + ".configFiles.configLinux", dynConfigFiles_linux,
          dp + ".configFiles.configWindows", dynConfigFiles_windows,
          dp + ".initFiles", dynInitFiles,
          dp + ".postInstallFiles", dynPostInstallFiles,
          dp + ".deleteFiles", dynDeleteFiles,
          dp + ".postDeleteFiles", dynPostDeleteFiles,
          dp + ".dplistFiles", dynDplistFiles,
          dp + ".requiredComponents", dynRequiredComponents,
          dp + ".requiredInstalled", requiredInstalled,
          dp + ".subComponents", dynSubComponents,
          dp + ".isItSubComponent", isItSubComponent,
          dp + ".scriptFiles", dynScriptsToBeAdded,
          dp + ".comments", comments,
          dp + ".description", description,
          dp + ".name", componentName);
  }
  else
  {
    fwInstallation_showMessage(makeDynString("    ERROR: The information cannot be saved into the database "));
    fwInstallation_writeToMainLog(formatTime("[%Y-%m-%d_%H:%M:%S] ",getCurrentTime()) + componentName + " " + componentVersion + " installed with errors");
    fwInstallation_showMessage(makeDynString("    Component installed with errors - check the log."));
    dpSet(dp + ".requiredInstalled:_original.._value", false);
    dpSet(dp + ".installationNotOK", true);
    return -1;
  }
  
  return 0;
}

/** This function checks if there is any dependency broken among the installed components 
 *  and sets the values of the internal dps accordingly
 @return 0 (error code not yet implemented)
*/
int fwInstallation_checkComponentBrokenDependencies()
{
  dyn_string dynNotProperlyInstalled;
  dyn_string dynRequiredComponents;
  dyn_string dynSubComponents;
  string strNotInstalledNames;
  int i = 1;
  string str = "";
  
//  if(fwInstallationRedu_myReduHostNum() > 1)
//    str = "_" + fwInstallationRedu_myReduHostNum();
  
  //fwInstallation_getListOfNotProperlyInstalledComponents(dynNotProperlyInstalled);
  dyn_string dps = fwInstallation_getInstalledComponentDps();
  
  for(i = 1; i <= dynlen(dps); i++)
  {
    strNotInstalledNames = "";
    dynClear(dynRequiredComponents);
    dynClear(dynSubComponents);
    dpGet(dps[i] + ".requiredComponents", dynRequiredComponents,
          dps[i] + ".subComponents", dynSubComponents);    
    fwInstallation_getNotInstalledComponentsFromRequiredComponents(dynRequiredComponents, strNotInstalledNames);

    if(strNotInstalledNames == "")
    {
      dpSet(dps[i] + ".requiredInstalled", true);
    }
    else
    {
      dpSet(dps[i] + ".requiredInstalled", false);
      continue;
    }
    
    strNotInstalledNames = "";
    fwInstallation_getNotInstalledComponentsFromRequiredComponents(dynSubComponents, strNotInstalledNames);
    
    if(strNotInstalledNames == "")
    {
      dpSet(dps[i] + ".requiredInstalled", true);
    }
    else
    {
      dpSet(dps[i] + ".requiredInstalled", false);
      continue;
    }
  }
  
  return 0;
}


/*
int fwInstallation_checkComponentBrokenDependencies()
{
  dyn_string dynNotProperlyInstalled;
  dyn_string dynRequiredComponents;
  string strNotInstalledNames;
  int i = 1;
  string str = "";
  
  if(fwInstallationRedu_myReduHostNum() > 1)
    str = "_" + fwInstallationRedu_myReduHostNum();
  
  fwInstallation_getListOfNotProperlyInstalledComponents(dynNotProperlyInstalled);
  
  for(i = 1; i <= dynlen(dynNotProperlyInstalled); i++)
  {
    dynClear(dynRequiredComponents);
    string dp = fwInstallation_getComponentDp(dynNotProperlyInstalled[i]);
    //dpGet(dp + ".requiredComponents", dynRequiredComponents);
    
    dpGet(dynNotProperlyInstalled[i] + ".requiredComponents", dynRequiredComponents);    
    
    fwInstallation_getNotInstalledComponentsFromRequiredComponents(dynRequiredComponents, strNotInstalledNames);
    
    if(strNotInstalledNames == "")
      dpSet(dynNotProperlyInstalled[i] + ".requiredInstalled", true);
//      dpSet(dp + ".requiredInstalled", true);
  }
  
  return 0;
}
*/
string fwInstallation_getComponentName(string filename)
{//Note: check if code below should be changed, component name should be retrieved from tag name in component description file, see: FWINS-1956
  string component = _fwInstallation_fileName(filename);
  strreplace(component, ".xml", "");
  return component;
}
/** This function installs the component. It copies the files, imports the component DPs, DPTs, updates the project config file

@param descFile: the file with the description of a component 
@param sourceDir: the root directory with the component files
@param isItSubComponent: it is false - if it is the master component; it is true if it is the sub component
@param componentName: it is the return value - the name of the installed component
@param componentInstalled: set to 1 if the component is properly installed
@param dontRestartProject: indicates whether the project has to be restarted after installations or not
@param subPath: path to be appended to the source directory
@param forceInstallRequired this flag indicates whether all required components must be installed provided that 
       they correct versions are found in the distribution. This is a optional parameter. The default value is false to keep the tool backwards compatible.
	   Note that the value of this parameter is set to the default value (TRUE) when a silent installation is chosen.
@param forceOverwriteFiles this flag indicates whether the files of the component must be overwritten if a previous installation of the component is detected in the target directory
       This is a optional parameter. The default value is false to keep the tool backwards compatible.
	   Note that the value of this parameter is set to the default value (FALSE) when a silent installation is chosen.
@param isSilent flag indicating whether we are dealing with a silent installation of the packages or not. The default value is false.
@param installSubComponents flag indicating whether subcomponents have to also be installed
@return Error code: -1 if ERROR, 0 if all OK.
@author  F. Varela.
*/
int fwInstallation_installComponent(string descFile, 
                                    string sourceDir, 
                                    bool isItSubComponent,  
                                    string & componentName, 
                                    bool & componentInstalled, 
                                    string &dontRestartProject, 
                                    string subPath = "", 
                                    bool forceInstallRequired = false, 
                                    bool forceOverwriteFiles = false, 
                                    bool isSilent = false, 
                                    bool installSubComponents = true)
{

  string destinationDir;  // the name of a directory where the component will be installed
  string popupText;
  dyn_float df;
  dyn_string ds;
  	
  dyn_float dreturnf; // return value of a panel
  dyn_string dreturns; // return value of a panel
	
  string componentFileName; 
  string fileToCopy;
  string asciiManager;
  string infoFile;
  string logFile;
  string cmd;
  string strComponentFile; 
  string asciiFile;
  string result;
  string tmpResult;
  int dpCreated;
  int iReturn; // the return value of function fwInstallation_evalScriptFile;
//  dyn_string dynComponentFileLines;
  dyn_string dynFileNames;
  dyn_string dynComponentFiles;
//  dyn_string dynPostDeleteFiles_current;
  dyn_string dynPostDeleteFiles_all;
//  dyn_string dynPostInstallFiles_current;
  dyn_string dynPostInstallFiles_all;
  dyn_string dynPostDeleteFiles;
  dyn_string dynPostInstallFiles;
  dyn_string dynConfigFiles_general;
  dyn_string dynConfigFiles_linux;
  dyn_string dynConfigFiles_windows;
  dyn_string dynInitFiles;
  dyn_string dynDeleteFiles;
  dyn_string dynDplistFiles;
  dyn_string resultInLines;
  dyn_string dynScriptsToBeAdded; 
  string helpFile;

  // sub Components handling
  dyn_string dynSubComponents;
	
  // end sub Components handling

  string componentVersion;
  string date;
  string componentConfigFile = "";
  string dplistFile;
  bool requiredInstalled = true;
	
  // component dependencies
	
  dyn_string dynRequiredComponents;
	
  string strNotInstalledNames = "";
	

  float floatInstalledVersion;
  string strInstalledName; 
  dyn_string  dynNotProperlyInstalled;
	
  // end component dependencies
	
  string tagName;
  string tagValue;
  string filePath, filePattern, fileNameToAdd;
  dyn_string fileNames;
	
  bool	fileLoaded;
  bool x;
  string err;
  string componentInitFile;
	
  int i, j, k;
  int pos1, pos2, pos3, pos4;
  int dpGetResult;
  int fileCopied;

  int error = 0;
	
  int registerOnly = 0;
  dyn_string proj_paths;

  dyn_string dsNotInstalledComponents;
  dyn_string dsGoodComponents;
  
  dyn_dyn_string componentsInfo;
  dyn_string currentComponentInfo;
  dyn_string dsTmp;
  string notInstalledComponentName;
  string notInstalledComponentVersion;
  string fileComponentName;
  string fileComponentVersion;
  string fileComponent;

  string componentPath; 
  dyn_string comments;
  string description;
  
  dyn_string dsFileComponentName;
  dyn_string dsFileComponentVersion;
  dyn_string dsFileComponent;  
  
  dynClear(dsFileComponentName);
  dynClear(dsFileComponentVersion);
  dynClear(dsFileComponent);

  string installedVersion;
  string dp = fwInstallation_getInstallationDp();
  
  dontRestartProject = "no";

  // add a control manager for the fwScripts.lst
  string user, pwd, host = fwInstallation_getPmonHostname();
  int port = pmonPort();
  fwInstallation_getPmonInfo(user, pwd);
  fwInstallationManager_add(fwInstallation_getWCCOAExecutable("ctrl"), "once", 30, 1, 1, "-f fwScripts.lst", host, port, user, pwd);
  
  if(componentName != "")//theoretically it might be the case that component name is empty - don't report the first step then as it will create wrong entry in report list
    fwInstallation_reportComponentInstallationProgress(componentName, FW_INSTALLATION_REPORT_STEP_PARSING_XML);

  if(descFile == "")
  {
    popupText = "Installation of \"" + componentName + "\" failed. \nNo XML file defined.";
    fwInstallation_popup(popupText);

    return -1;
  }
  
  // get the destination dir
  dpGet(dp + ".installationDirectoryPath", destinationDir);
  
  //step 1
  dyn_dyn_mixed parsedComponentInfo;
  if(fwInstallationXml_parseFile(sourceDir, descFile, subPath, destinationDir, parsedComponentInfo))
  {
    popupText = "Installation of \"" + componentName + "\" failed. \nXML file not properly parsed.";
    fwInstallation_popup(popupText);

    return -1;
  }  
  
  componentName = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_NAME];
  componentVersion = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_VERSION];
  dynSubComponents = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_SUBCOMPONENTS];
  dynFileNames = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_FILES];
  dynPostDeleteFiles = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_POST_DELETE_SCRIPTS];
  dynPostInstallFiles = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_POST_INSTALL_SCRIPTS];
  dyn_string dynPostDeleteFilesCurrent = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_POST_DELETE_SCRIPTS_CURRENT];
  dyn_string dynPostInstallFilesCurrent = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_POST_INSTALL_SCRIPTS_CURRENT];
  dynConfigFiles_general = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_CONFIG_FILES];
  dynConfigFiles_linux = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_CONFIG_FILES_LINUX];
  dynConfigFiles_windows = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_CONFIG_FILES_WINDOWS];
  dynInitFiles = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_INIT_SCRIPTS];
  dynDeleteFiles = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_DELETE_SCRIPTS];
  dynDplistFiles = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_DPLIST_FILES];
  dynScriptsToBeAdded = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_SCRIPT_FILES];
  helpFile = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_HELP_FILE];
  date = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_DATE];
  comments = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_COMMENTS];
  description = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_DESCRIPTION];
  dynRequiredComponents = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_REQUIRED_COMPONENTS];
  string requiredPvssVersion = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_REQUIRED_PVSS_VERSION];
  bool strictPvssVersion = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_STRICT_PVSS_VERSION][1];
  string requiredPvssPatch = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_REQUIRED_PVSS_PATCH];
  dyn_string dynPreinit = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_PREINIT_SCRIPTS];
  bool updateTypes = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_UPDATE_TYPES][1];
  string requiredInstallerVersion = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_REQUIRED_INSTALLER_VERSION];
  bool strictInstallerVersion = parsedComponentInfo[FW_INSTALLATION_XML_COMPONENT_STRICT_INSTALLER_VERSION][1];
  
  fwInstallation_setCurrentComponent(componentName, componentVersion);
  
  fwInstallation_reportComponentInstallationProgress(componentName, FW_INSTALLATION_REPORT_STEP_CHECKING_REQUIREMENTS);

  string msg;
  int ret = -1;
  if(requiredPvssVersion != "") //Check PVSS version
  {
    fwInstallation_throw("Component: "+componentName + "v." + componentVersion + " requires PVSS version: " + requiredPvssVersion + ". Checking condition now...", "INFO", 10);
    ret = fwInstallation_checkPvssVersion(requiredPvssVersion);
    
    if(ret <= 0)
    {
      popupText = "Installation of \""+componentName + "\" (" + componentVersion + ") aborted. Requires WinCC version " + requiredPvssVersion + " or later.";
      fwInstallation_popup(popupText);
      fwInstallation_unsetCurrentComponent();
      return -1;
    }
    else if(strictPvssVersion && ret!= 1)
    {
      popupText = "Installation aborted. Requires WinCC version " + requiredPvssVersion + " or later.";
      fwInstallation_popup(popupText);
      fwInstallation_unsetCurrentComponent();
      return -1;
    }
    else
    {
      fwInstallation_throw("OK: Current PVSS version: " + VERSION_DISP + " equal or newer than required version " 
                           + requiredPvssVersion, "INFO", 10);
    }
  }
  
  if(requiredPvssPatch != "") //Check patching
  {
    fwInstallation_throw("Component: "+componentName + "v." + componentVersion + " requires PVSS patch: " + requiredPvssPatch + ". Checking condition now...", "INFO", 10);

    if(fwInstallation_isPatchInstalled(requiredPvssPatch) <= 0 && ret == 1) //Check the patch level only if we are talking about the exact PVSS version.
    {
      popupText = "Installation aborted. Current WinCC version " + VERSION_DISP + " does not contain patch " + requiredPvssPatch + ".";
      fwInstallation_popup(popupText);
      fwInstallation_unsetCurrentComponent();
      return -1;
    }
    else
    {
      fwInstallation_throw("OK: Patch: " + requiredPvssPatch + " applied to current PVSS version: " + VERSION_DISP, "INFO", 10);
    }
  }
  
  if(requiredInstallerVersion != "") //Check PVSS version
  {
    fwInstallation_throw("Component: "+componentName + "v." + componentVersion + " requires a version: " + requiredInstallerVersion + " of the FW Component Installation Tool. Checking condition now...", "INFO", 10);
    ret = fwInstallation_checkToolVersion(requiredInstallerVersion);
    if(ret <= 0)
    {
      popupText = "Installation aborted.\nRequires Installation Tool version " + requiredInstallerVersion + " or later.";
      fwInstallation_popup(popupText);
      fwInstallation_unsetCurrentComponent();
      return -1;
    }
    else if(strictInstallerVersion && ret!= 1)
    {
      popupText = "Installation aborted. \""+componentName + "\" \nneeds Installation Tool version " + requiredInstallerVersion + ".";
      fwInstallation_popup(popupText);
      fwInstallation_unsetCurrentComponent();
      return -1;
    }
    else
    {
      fwInstallation_throw("OK: Current version of the FW Component Installation Tool: " + csFwInstallationToolVersion + " equal or newer than required version " 
                           + requiredInstallerVersion, "INFO", 10);
    }
  }
  
////////////////////////////////////////////////
  fwInstallation_throw("Now installing " + componentName  + " v." + componentVersion + " from " + sourceDir + ". XML File: " + descFile, "INFO");
  //step 2
  fwInstallation_reportComponentInstallationProgress(componentName, FW_INSTALLATION_REPORT_STEP_VERIFYING_COMPONENT_PACKAGE);
  
  //FVR: 31/03/2006: Check if the component already exists in the destination directory:
  //Check that the forceOverwriteFiles is not true in addition
  registerOnly = fwInstallation_getRegisterOnly(destinationDir, componentName,  forceOverwriteFiles, isSilent);
  if(registerOnly < 0.) //Installation aborted by the user.
    return 0;

  //// check if all scripts all valid, and all directories are writeable and if all source files exist
  bool actionAborted = false;
  bool componentIntegrityWrong = false;
  if(fwInstallation_verifyPackage(sourceDir,
                                  subPath,
                                  componentName,
                                  destinationDir,
                                  registerOnly,
                                  makeDynString(), // FWINS-2105 - don't verify component's scripts,
                                  makeDynString(), //              note that dynFileNames also contains
                                  makeDynString(), //              paths to script files so they are still
                                  makeDynString(), //              checked for existence and readability
                                  dynFileNames,
                                  isSilent,
                                  actionAborted))
  {
    fwInstallation_throw("fwInstallation_installComponent() -> Failed to verify component package: " + componentName);
    componentIntegrityWrong = true; //signal that we know that there was a problem with the component but the user has decided to go ahead.
    ++error;
  }

  if(actionAborted) //user has decided to cancel the installation or we are running from a ctrl manager
  {
    fwInstallation_unsetCurrentComponent();
    return 0;
  }
  
  //step 2.5, :-)
  fwInstallation_reportComponentInstallationProgress(componentName, FW_INSTALLATION_REPORT_STEP_EXECUTING_PREINIT_SCRIPTS);
  //Run Pre-init scripts
  if(fwInstallation_executeComponentInitScripts(componentName, sourceDir, subPath, dynPreinit, isSilent))
  {
    fwInstallation_setComponentInstallationStatus(componentName, false);
    popupText = "Installation of \"" + componentName + "\" (" + componentVersion + ") aborted. Execution of component pre-init script(s) failed.";
    fwInstallation_popup(popupText);
    fwInstallation_unsetCurrentComponent();
    return -1;
  }
  //step 3
  fwInstallation_reportComponentInstallationProgress(componentName, FW_INSTALLATION_REPORT_STEP_INSTALLING_REQUIRED_COMPONENTS);
  //install required component if necessary:
  if(fwInstallation_installRequiredComponents(componentName, dynRequiredComponents, sourceDir, forceInstallRequired, forceOverwriteFiles, isSilent, requiredInstalled, actionAborted))
  {
    popupText = "Forced installation of required components \nfor \"" + componentName + "\" failed.";
    fwInstallation_popup(popupText);
    ++error;
  }
  
  if(actionAborted) //user has decided to cancel the installation or running from ctrl script
  {
    fwInstallation_unsetCurrentComponent();
    return 0;
  }
  
  fwInstallation_reportComponentInstallationProgress(componentName, FW_INSTALLATION_REPORT_STEP_INSTALLING_SUBCOMPONENTS);
  fwInstallation_reportUpdateTotalComponentsNumber(dynlen(dynSubComponents));
  dyn_string subComponentNames;
  for(int i=1;i<=dynlen(dynSubComponents);i++)
  {
    dyn_dyn_mixed componentInfo;
    if(fwInstallationXml_load(dynSubComponents[i], componentInfo))
      continue;
    subComponentNames[i] = componentInfo[FW_INSTALLATION_XML_COMPONENT_NAME][1];
  }
// install the subcomponents if they exist
  if(installSubComponents && dynlen(dynSubComponents))
  {
    fwInstallation_showMessage(makeDynString("     Installing sub Components ... "));
    for(i = 1; i <= dynlen(dynSubComponents); i++)
    {
      string subComponentName = subComponentNames[i];
      fwInstallation_reportComponentInstallationProgress(subComponentName, FW_INSTALLATION_REPORT_STEP_STARTING_INSTALLATION);
      
      if(fwInstallation_installComponent(dynSubComponents[i], sourceDir, true, subComponentName, componentInstalled, dontRestartProject))
      {
        // + report installation status (success/error)
        if(subComponentName != "")
          fwInstallation_reportComponentInstallationFinished(subComponentName);
        
        fwInstallation_setComponentInstallationStatus(componentName, false);

        popupText = "Installation of sub-component \n\"" + dynSubComponents[i] + "\" failed.";
        fwInstallation_popup(popupText);
        
        fwInstallation_unsetCurrentComponent();
        return -1;
      }
      if(subComponentName != "")
        fwInstallation_reportComponentInstallationFinished(subComponentName);
    }
  }

  fwInstallation_reportComponentInstallationProgress(componentName, FW_INSTALLATION_REPORT_STEP_COPYING_FILES);
  // copy all the files
  if(fwInstallation_copyComponentFiles(componentName, sourceDir, subPath, destinationDir, dynFileNames, registerOnly, isSilent))
  {
    popupText = "Copying files of \"" + componentName + "\" failed.";
    fwInstallation_popup(popupText);
    
    if(!componentIntegrityWrong) //The component integrity is OK but there were problems copying the file.
    {
      fwInstallation_setComponentInstallationStatus(componentName, false);
      fwInstallation_unsetCurrentComponent();
      return -1;
    }
  }		

  fwInstallation_reportComponentInstallationProgress(componentName, FW_INSTALLATION_REPORT_STEP_IMPORTING_DPS);
// import the dplist files with the ASCII manager
  
  if(fwInstallationRedu_isComponentInstalledInPair(componentName, componentVersion))
  {
    fwInstallation_throw("Redundant system. Component already installed in pair. ASCII import will be skipped for component: " + componentName, "INFO");
  }
  else
  {
    if(fwInstallation_importComponentAsciiFiles(componentName, sourceDir, subPath, dynDplistFiles, updateTypes))
    {
      fwInstallation_setComponentInstallationStatus(componentName, false);
      popupText = "Import of .dpl files for \"" + componentName + "\" failed.";
      fwInstallation_popup(popupText);
      fwInstallation_unsetCurrentComponent();
      return -1;
    }
  }

  fwInstallation_reportComponentInstallationProgress(componentName, FW_INSTALLATION_REPORT_STEP_CONFIGURING_PROJECT);
  if(fwInstallation_importConfigFiles(componentName, sourceDir, subPath, dynConfigFiles_general, dynConfigFiles_linux, dynConfigFiles_windows))
  {
    fwInstallation_setComponentInstallationStatus(componentName, false);
    popupText = "Import of config files for \"" + componentName + "\" failed.";
    fwInstallation_popup(popupText);
    fwInstallation_unsetCurrentComponent();
    return -1;
  }

  fwInstallation_reportComponentInstallationProgress(componentName, FW_INSTALLATION_REPORT_STEP_EXECUTING_INIT_SCRIPTS);
// add scripts to the fwScripts.lst file
  if(fwInstallation_executeComponentInitScripts(componentName, sourceDir, subPath, dynInitFiles, isSilent))
  {
    fwInstallation_setComponentInstallationStatus(componentName, false);
    popupText = "Execution of init script(s) for \"" + componentName + "\" failed.";
    fwInstallation_popup(popupText);
    fwInstallation_unsetCurrentComponent();
    return -1;
  }

  fwInstallation_reportComponentInstallationProgress(componentName, FW_INSTALLATION_REPORT_STEP_REGISTERING_INSTALLATION);
  string xml = "./" + _fwInstallation_fileName(descFile);
  //dynSubComponents is the list of XML files of the subcomponents. We need to extract only the names to set the internal dp
  dyn_string subcomponents;
  for(i = 1; i <= dynlen(dynSubComponents); i++)
    subcomponents[i] = fwInstallation_getComponentName(dynSubComponents[i]);

  if(fwInstallation_createComponentInternalDp(componentName, componentVersion, xml, isItSubComponent, sourceDir, date, helpFile, destinationDir,
                                              dynFileNames, dynConfigFiles_general, dynConfigFiles_linux, dynConfigFiles_windows,
                                              dynInitFiles, dynPostInstallFiles, dynDeleteFiles, dynPostDeleteFiles, dynDplistFiles,
                                              dynRequiredComponents, subcomponents, dynScriptsToBeAdded, requiredInstalled, comments, description))
                                              
  {
    fwInstallation_setComponentInstallationStatus(componentName, false);
    popupText = "Creating internal Installation Tool datapoint \nfor \"" + componentName + "\" failed.";
    fwInstallation_popup(popupText);
    fwInstallation_unsetCurrentComponent();
    return -1;
  }
  
  fwInstallation_reportComponentInstallationProgress(componentName, FW_INSTALLATION_REPORT_STEP_CALCULATING_SOURCE_FILES_HASHES);
  // calculate hashes of component source files
  if(fwInstallation_calculateComponentSourceFilesHashes(componentName))
  {
    fwInstallation_throw("fwInstallation_installComponent() -> Failed to calculate source files' hashes for component: " + componentName);
    ++error;
  }
  fwInstallation_reportComponentInstallationProgress(componentName, FW_INSTALLATION_REPORT_STEP_VERIFYING_DEPENDENCIES);
  // the component has been installed - check whether it has corrected the broken dependencies
  if(fwInstallation_checkComponentBrokenDependencies())
  {
    fwInstallation_throw("fwInstallation_installComponent() -> Failed to check broken dependencies for component: " + componentName);
    ++error;
  }

  fwInstallation_reportComponentInstallationProgress(componentName, FW_INSTALLATION_REPORT_STEP_REQUESTING_POSTINSTALLS);
  //Store post-installation scripts for execution:
  if(fwInstallation_storeComponentPostInstallScripts(componentName, dynPostInstallFiles))
  {
    popupText = "Storing post-install scripts for \"" + componentName + "\" failed.";
    fwInstallation_popup(popupText);
    ++error;
  }
  
  //Legacy		
  componentInstalled = true;

  if(error)
  {
    fwInstallation_setComponentInstallationStatus(componentName, false);
    popupText = "Installation of \"" + componentName + "\" failed.";
    fwInstallation_popup(popupText);
  }
  else
  {
    msg = "The installation of component " + componentName + " v." + componentVersion + " completed OK";
    if(dynlen(dynPostInstallFiles)) {
      msg += " - Note that there are still post-installation scripts pending execution";
      fwInstallation_setComponentInstallationStatus(componentName, false);
    } else {
      fwInstallation_setComponentInstallationStatus(componentName, true);
    }
    
    fwInstallation_throw(msg, "INFO", 10);
  }
  
  dyn_int projectStatus;
  if(fwInstallationDB_getUseDB() && fwInstallationDB_connect() == 0)
  {
    fwInstallation_reportComponentInstallationProgress(componentName, FW_INSTALLATION_REPORT_STEP_REGISTERING_INSTALLATION_IN_DB);
    
    fwInstallation_throw("Updating FW System Configuration DB after installation of " + componentName + " v"+ componentVersion, "INFO", 10);
    fwInstallationDB_storeInstallationLog();
    fwInstallationDB_registerProjectFwComponents();
    fwInstallationDBAgent_checkIntegrity(projectStatus);
  }
//  if(fwInstallationDB_getUseDB() && fwInstallationDBAgent_checkIntegrity(projectStatus) != 0)
//    fwInstallation_throw("Could not check PVSS-DB contents integrity", "error", 7);
                	
  fwInstallation_unsetCurrentComponent();
  return gFwInstallationOK;	
}


/** This function sets the internal dpes of the component dp according to the status of the installation

@param componentName component name
@param ok status of installation
@return Error code: -1 if ERROR, 0 if all OK.
@author  F. Varela.
*/

int fwInstallation_setComponentInstallationStatus(string componentName, bool ok)
{
  string dp;
  
  if(fwInstallationRedu_myReduHostNum() > 1)
    dp = "fwInstallation_" + componentName + "_" + fwInstallationRedu_myReduHostNum();
  else
    dp = "fwInstallation_" + componentName;

  if(!dpExists(dp))
    return 0;
  
  return dpSet(dp + ".installationNotOK", !ok);
}


/** This function retrieves the list of components which were not properly installed - there was error in dependencies
and the user still wanted to install the component.

@param dynNotProperlyInstalled: the list of components which were installed with broken dependencies - .requiredInstalled:_original.._value is false
@author M.Sliwinski
*/
fwInstallation_getListOfNotProperlyInstalledComponents(dyn_string & dynNotProperlyInstalled)
{
		dyn_string dynInstalledComponents;
		int i;
		bool requiredInstalled;
		
		// retrieve all installed components
	        dynInstalledComponents =  fwInstallation_getInstalledComponentDps();
		
		for(i = 1; i <= dynlen(dynInstalledComponents); i++)
		{	
  			dpGet(dynInstalledComponents[i] + ".requiredInstalled:_original.._value", requiredInstalled);
                        
			if(!requiredInstalled)
			  dynAppend(dynNotProperlyInstalled, dynInstalledComponents[i]);
		}		
}

/** This function checks if all the required components are installed. It returns a string of components that are not
installed and required.

@param dynRequiredComponents: the name of a componentConfigFile
@param strNotInstalledNames: the name of a component
@author M.Sliwinski
*/
fwInstallation_getNotInstalledComponentsFromRequiredComponents(dyn_string & dynRequiredComponents, string & strNotInstalledNames)
{
	int i;
	dyn_string dynInstalledComponents, dynInstalledComponentDps;
	dyn_string dynTmpNameVersion;
	string strRequiredName;
	string stringInstalledVersion;
	string stringRequiredVersion;
 
	if (dynlen(dynRequiredComponents) > 0)
	{
		// retrieve all installed components
		dynInstalledComponentDps =  fwInstallation_getInstalledComponentDps();
  dynInstalledComponents = dynInstalledComponentDps;
                
		for(i = 1; i <= dynlen(dynInstalledComponents); i++)
		{	
//			// cut the system name from the installed components
//			dynInstalledComponents[i] = dpSubStr( dynInstalledComponents[i], DPSUB_DP );
//			// cut the fwInstallation_ prefix 
//			strreplace(dynInstalledComponents[i], "fwInstallation_" , "");	
    string name = "";	
    dpGet(dynInstalledComponents[i] + ".name", name);
    dynInstalledComponents[i] = name;
		}

		for( i = 1; i <= dynlen(dynRequiredComponents); i++)
		{
			// retrieve the name and version of the component
			dynTmpNameVersion = strsplit(dynRequiredComponents[i] , "=");
   
			strRequiredName = strltrim(strrtrim(dynTmpNameVersion[1]));
			if(dynlen(dynTmpNameVersion) > 1)
				stringRequiredVersion = strltrim(strrtrim(dynTmpNameVersion[2]));
			else
				stringRequiredVersion = "";
   			
			// check whether the required component is installed
			if(dynContains(dynInstalledComponents, strRequiredName))
			{
				// the required component is installed
				// checking the version of the installed component
     string reqDp = fwInstallation_getComponentDp(strRequiredName);
				 dpGet(reqDp + ".componentVersionString", stringInstalledVersion);
				 if(_fwInstallation_CompareVersions(stringInstalledVersion, stringRequiredVersion))
				 {
				 
				 	// the installed version of the component is greater than the required version - OK
				 }
				 else
				 {
				 	// the installed version is older than the required version
					strNotInstalledNames += strRequiredName + "=" + stringRequiredVersion + "|";
                                 }
			}
			else
			{
				// the required component is not installed
				strNotInstalledNames += strRequiredName + "=" + stringRequiredVersion + "|";
			}
		}
	}
}

/** This function reads the information from the componentConfigFile and copies it into the project config file.
Function uses the following functions: fwInstallation_loadConfigIntoTables, fwInstallation_AddComponentIntoConfigIntoMemory
fwInstallation_saveFile

@param componentConfigFile: the name of a componentConfigFile
@param componentName: the name of a component
@author M.Sliwinski and F. Varela
*/

fwInstallation_AddComponentIntoConfig(string componentConfigFile, string componentName)
{
	
	string configPath = getPath(CONFIG_REL_PATH);
	string configFile = configPath + "config";
	
	dyn_string loadedSections;  // this table contains the sections loaded from the config file
	dyn_dyn_string configSectionTable; // the memory representation of a config file     [1][i] - [section:parameter] , [i+1][j] - [value]
	dyn_string configLines; // this table contains the config file - each row contains one line from config file
	dynClear(loadedSections);
	configSectionTable [1] = "";
	configSectionTable [2] = "";
	configSectionTable [3] = "";

	// load the config file into its memory representation			
	fwInstallation_loadConfigIntoTables(loadedSections, configSectionTable, configLines, configFile);

	// add component into memory if not fwInstallation
	if(componentName != gFwInstallationComponentName)
        {
  	  fwInstallation_AddComponentIntoConfigIntoMemory(loadedSections, configSectionTable, configLines, componentConfigFile , componentName);
        }
        
	fwInstallation_saveFile(configLines, configPath + "config");

}


/** This function reads the information from the componentConfigReduFile and copies it into the project config.redu file.
@param componentConfigReduFile: the name of a componentConfigFile
@param componentName: the name of a component
*/

fwInstallation_addComponentIntoConfigRedu(string componentConfigReduFile, string componentName)
{
	
	string configPath = getPath(CONFIG_REL_PATH);
	string configFile = configPath + "config.redu";
	
	dyn_string loadedSections;  // this table contains the sections loaded from the config file
	dyn_dyn_string configSectionTable; // the memory representation of a config file     [1][i] - [section:parameter] , [i+1][j] - [value]
	dyn_string configLines; // this table contains the config file - each row contains one line from config file
	dynClear(loadedSections);
	configSectionTable [1] = "";
	configSectionTable [2] = "";
	configSectionTable [3] = "";

  if (!isfile(configFile))
  {
    file f = fopen(configFile, "w");
    fclose(f);
  
  } 
  else
  {  
  	// load the config file into its memory representation			
  	fwInstallation_loadConfigIntoTables(loadedSections, configSectionTable, configLines, configFile);
  }
  
  // add component into memory if not fwInstallation
  if(componentName != gFwInstallationComponentName)
  {
    fwInstallation_AddComponentIntoConfigIntoMemory(loadedSections, configSectionTable, configLines, componentConfigReduFile , componentName);
  }
        
	fwInstallation_saveFile(configLines, configFile);

}

/** This function reads the information from the component config file and saves the information into memory:
loadedSections and configSectionTable - the tables containing the information about the sections:parameters:values
configLines: the table containing the lines of a config file

@param loadedSections: the list of loaded sections
@param configSectionTable: the memory representation of a config file     [1][i] - [section:parameter] , [i+1][j] - [value]
@param configLines: the dyn_string containing the lines of a config file
@param fileName: the name of a config file of a component
@param componentName: the name of a component
@author M.Sliwinski
*/

int fwInstallation_AddComponentIntoConfigIntoMemory(dyn_string & loadedSections, dyn_dyn_string & configSectionTable, dyn_string & configLines, string fileName, string componentName)
{
	string fileInString;
	string tempLine;
	string currentSection = "NOT_YET_DEFINED";
	dyn_string componentLines; // contains the lines from the component config file
	dyn_dyn_string componentParameters; // [1][i] - section name; [i + 1][j] - section parameters ( lines )
	bool fileLoaded = false;
	dyn_string linesToAdd;
	string tempParameter;
	string tempValue;
	string tempString,tempStringQuotes;
	
	dyn_string strValues;
	dyn_string parameterValue;
	
	int idxOfSection;
	int sectionExistsInConfig;
	int valueExistsInConfig;
	int i, j , k;
	int returnValue;
	
	
//	componentParameters[1] = "";
//	componentParameters[2] = "";
	dynClear(componentParameters[1]);
	dynClear(componentParameters[2]);
	
	// first delete the old information about the component from the config file
	fwInstallation_deleteComponentFromConfigInMemory(loadedSections, configSectionTable, configLines, componentName);
		
	
	// load the component config file
	fileLoaded = fileToString(fileName, fileInString);
	
	if (! fileLoaded )
	{
	
		fwInstallation_throw("Cannot load " + fileName + " file", "error", 4);
	}
	else 
	{
			componentLines = fwInstallation_splitLines(fileInString);
			
			for(i = 1; i <= dynlen(componentLines); i++)
			{
				tempLine = strltrim(strrtrim(componentLines[i]));
		
		
				if (tempLine == "" )
				{
		//			Debug("\n The line is blank |"  + tempLine + "|");
				}
				else if ( strtok(tempLine, "#") == 0)
				{
					if( currentSection == "NOT_YET_DEFINED")
					{
						// we do not know in which section to add the comment
					}
					else  // add the comment into the table
					{
						idxOfSection = dynContains(componentParameters[1], currentSection);
						
						dynAppend(componentParameters[idxOfSection + 1], tempLine);
					}
				}
				else if ( strtok(tempLine, "[") == 0)  // this is a section
				{
					if(dynContains(componentParameters[1], tempLine) == 0)
					{ // add section only if it was not there
					  dynAppend(componentParameters[1] ,tempLine);
					}
					//else -> this section is already on the list, don't append it once again, entries will be merged with previous ones from same section

					currentSection = tempLine;
				}
				else // this is parametrization
				{
					 if(currentSection == "NOT_YET_DEFINED")
					 {
					 	fwInstallation_throw("the component file has errors  section is not defined. line: " + i);
					 }
					 else
					 {
					 	idxOfSection = dynContains(componentParameters[1], currentSection);
					 	//Debug("&&&&Parametrization: ", tempLine);
					 	dynAppend(componentParameters[idxOfSection + 1], tempLine);
					 }
				}
			} //end  for ( i = 1; i <= dynlen(componentLines)
			
			// the component information is now in the componentParameters table
      
			
		// adding the component into the config file
		
			for(i = 1; i <= dynlen(componentParameters[1]); i++)
			{
				currentSection = componentParameters[1][i];
				
		//		Debug("\n adding the lines in section: " + currentSection);
				
				sectionExistsInConfig = dynContains(loadedSections, currentSection);
				
				if(sectionExistsInConfig == 0) // the section does not exist - add the lines into the config table and into the memory
				{
					dynClear(linesToAdd);
							
					dynAppend(loadedSections, currentSection);
					dynAppend(configLines, currentSection);
					
					dynAppend(configLines, "#begin " + componentName);
					dynAppend(configLines, "#This should not be edited manually");
					dynAppend(configLines, "#if the component is empty it means that the parametrization is already done in the section");

					for(j =1; j <= dynlen(componentParameters[i + 1]); j++)
					{
						tempLine = strltrim(strrtrim(componentParameters[i + 1][j]));
						
						if (tempLine == "")
						{
		//					 Debug("\n The line is blank: |" + tempLine + "|");
						}
						else if( strtok(tempLine, "#") == 0)
						{
		//					Debug("\n The line is a comment: |" + tempLine + "|");
							dynAppend(linesToAdd, tempLine);
		//
						}
						else  // this line is a parametrization - check if the value already exist, if not add it
						{
								parameterValue = strsplit(tempLine, "=");
								tempParameter = strltrim(strrtrim(parameterValue[1]));
								tempValue = strltrim(strrtrim(parameterValue[2]));
								tempStringQuotes = tempValue; //SMS
								tempString = strltrim(strrtrim(tempValue, "\""), "\"");
								tempValue = tempString;
								strValues = strsplit(tempValue, ",");
                
								if(dynlen(strValues) == 0)//To handle config entry with the empty string value (e.g. exampleParam = "")
								{
									strValues = makeDynString("");
								}
								
								for(k = 1; k <= dynlen(strValues); k++)
								{
									tempValue = strltrim(strrtrim(strValues[k]));
									
									returnValue = fwInstallation_configContainsValue(configSectionTable, currentSection, tempParameter, tempValue);
									if( returnValue == 1)
									{
										// the value is already defined for this section and parameter
									}
									else
									{
										if(tempString == tempStringQuotes)	//SMS only if quotes where there before, put them again
										{
											dynAppend(linesToAdd, tempParameter + " = " + tempValue );	//SMS
										} else {
											dynAppend(linesToAdd, tempParameter + " = \"" + tempValue + "\"");	//SMS the original line
										}
		
										fwInstallation_addValueIntoMemory(configSectionTable, currentSection, tempParameter, tempValue); 
									}
								}	
						}

					}
					dynAppend(configLines, linesToAdd);
					dynAppend(configLines, "#end " + componentName + "\n");
					
					// we have added the whole information into the section			
				}
				else if(sectionExistsInConfig == -1)
				{
					Debug("\n ERROR: Cannot check if section exists in loadedSections table");
				}
				else // add the lines into the config table and into the memory
				{
					//Debug("&&&& 5 section exists in the config");
					if(dynlen(componentParameters) >= i+1)
					{
						dynClear(linesToAdd);
					 	dynAppend(linesToAdd, "#begin " + componentName);
						dynAppend(linesToAdd, "#This should not be edited manually");
						dynAppend(linesToAdd, "#if the component is empty it means that the parametrization is already done in the section");
						
						for(j = 1; j <= dynlen(componentParameters[i + 1]); j++)
						{
							tempLine = strltrim(strrtrim(componentParameters[i + 1][j]));
							
							if (tempLine == "")
							{
			//					 Debug("\n The line is blank: |" + tempLine + "|");
							}
							else if( strtok(tempLine, "#") == 0)
							{
			//					Debug("\n The line is a comment: |" + tempLine + "|");
								dynAppend(linesToAdd, tempLine);
			//
							}
							else  // this line is a parametrization - check if the value already exist, if not add it
							{
									parameterValue = strsplit(tempLine, "=");
									tempParameter = strltrim(strrtrim(parameterValue[1]));
									tempValue = strltrim(strrtrim(parameterValue[2]));
									
									tempStringQuotes = tempValue; //SMS
									tempString = strltrim(strrtrim(tempValue, "\""), "\"");
									tempValue = tempString;
									strValues = strsplit(tempValue, ",");
									
									for(k = 1; k <= dynlen(strValues); k++)
									{
										tempValue = strltrim(strrtrim(strValues[k]));
										
										returnValue = fwInstallation_configContainsValue(configSectionTable, currentSection, tempParameter, tempValue);
										if( returnValue == 1)
										{
											// the value is already defined for this section and parameter
										}
										else
										{
                                                                                        if(tempParameter == "distPeer")
                                                                                        {  
												dynAppend(linesToAdd, tempParameter + " = " + tempStringQuotes);	//SMS
                                                                                        }
											else if(tempString == tempStringQuotes)	//SMS only if quotes where there before, put them again
											{
												dynAppend(linesToAdd, tempParameter + " = " + tempValue );	//SMS
											} else {
												dynAppend(linesToAdd, tempParameter + " = \"" + tempValue + "\"");	//SMS the original line
											}
			
											fwInstallation_addValueIntoMemory(configSectionTable, currentSection, tempParameter, tempValue); 
										}
									}	
							}
						}
						
						dynAppend(linesToAdd, "#end " + componentName + "\n");
					}
		
		
		    // we are adding the lines - linesToAdd   into the configLines table under  - currentSection
					fwInstallation_addLinesIntoSection(configLines, currentSection, linesToAdd);
				}
			}

	}
}


/** This function adds the lines from linesToAdd into the configLines under the section specified by currentSection

@param configLines: the dyn_string with file lines
@param currentSection: the name of a currentSection
@param linesToAdd: the lines to be added

@author M.Sliwinski
*/

int fwInstallation_addLinesIntoSection(dyn_string & configLines, string currentSection, dyn_string  linesToAdd)
{
	int idxOfLine;
	int i;
	int returnValue;
	
	string tempLine;
	
	for( i = 1; i <= dynlen(configLines); i++)
	{
		tempLine = strltrim(strrtrim(configLines[i]));
		
		// find the section where it should be inserted	
		if(tempLine == currentSection)
		{
			// insert the lines into the configLines
			returnValue = dynInsertAt(configLines, linesToAdd, ++i);
			
			if(returnValue == -1)
			{
				return -1;
			}
			else
			{
				return 1;
			}
		}	
	}
	
	
}

/** This function adds [section:parameter] , [value] data into the memory representation of a config file

@param configSectionTable: the memory representation of a config file     [1][i] - [section:parameter] , [i+1][j] - [value]
@param section: the value of a section
@param parameter: the value of a parameter
@param value: the value of a "value"

@author M.Sliwinski
*/

int fwInstallation_addValueIntoMemory(dyn_dyn_string & configSectionTable, string section, string parameter, string value)
{
	int	idxSectionParam;
	int idxValue;
	int idxTemp;
	
	// get the index of section:parameter
	idxSectionParam = dynContains(configSectionTable[1], section + ":" + parameter);
	
	if (idxSectionParam == 0)
	{
		// add the section:parameter to the configSectionTable
		
		dynAppend(configSectionTable[1], section + ":" + parameter);
		
		// find the index of section:parameter
		idxTemp	= dynContains(configSectionTable[1], section + ":" + parameter);
		
		// add the value into memory
		dynAppend(configSectionTable[idxTemp + 1], value);	
	}
	else if(idxSectionParam == -1)
	{
		Debug("Error: fwInstallation_addValueIntoMemory");
		return -1;
	}
	else
	{
		idxValue = dynContains(configSectionTable[idxSectionParam + 1], value);
		
		if (idxValue == 0)
		{
			dynAppend(configSectionTable[idxSectionParam + 1], value);	
		}
		else if(idxValue == -1)
		{
			Debug("Error: fwInstallation_addValueIntoMemory");
		}
		else
		{	
			// This value already exists - do nothing
		}
	}
	return 1;

}

/** This function deletes the config info about a component from the memory representation of a config file - [section:parameter] , [value]
and from the configLines dyn_string

@param loadedSections: the list of sections loaded from the config file
@param configSectionTable: the memory representation of a config file     [1][i] - [section:parameter] , [i+1][j] - [value]
@param configLines: the dyn_string containing the lines from the config file
@param componentName: the name of a component to be deleted

@author M.Sliwinski
*/

int fwInstallation_deleteComponentFromConfigInMemory(dyn_string & loadedSections, dyn_dyn_string & configSectionTable, dyn_string & configLines, string componentName)
{
	int i, j;
	
	int configLength;
	int idxSectionParam;
	int idxSection;
	int idxValue;
	int idxCurrent;
	int removeResult;
	
	string currentSection;
	dyn_string sections;
	dyn_string configSectionRow;
	
	string tempLine;
	string tempParameter;
	string tempValue;
	string tempString;
	string tempSection;
	dyn_string parameter_Value;
	
	dyn_dyn_int components; // [1][i] index of beginning of a component definition;  [2][i] index of ending of a component definition
	dyn_string strValues;
	
	int idxBegin = 0;
	int idxEnd = 0;
	
	dynClear(sections);
	dynClear(components[1]);
	dynClear(components[2]);
	


// find out where are the components situated and in which sections
// we are interested in the indexes of #begin and #end lines
	for(i = 1; i <= dynlen(configLines); i++)
	{
	
		if ( strtok(configLines[i], "[") == 0)
		{
						currentSection = configLines[i];
		}
		
			if(configLines[i] == "#begin " + componentName)
			{
				idxBegin = i;
			}
			
			if(configLines[i] == "#end " + componentName)
			{
				idxEnd = i;
			}
			
			if(idxBegin < idxEnd)
			{
				dynAppend(components[1], idxBegin); 
				dynAppend(components[2], idxEnd);
				dynAppend(sections, currentSection);

				idxBegin = 0;
				idxEnd = 0;
			}
	}


// delete the component from the file ( the configLines table ) and from configSectionTable

	for(i = dynlen(components[1]); i >=1; i--)
	{
		idxBegin = components[1][i];
		idxEnd = components[2][i];
	
		idxCurrent = idxEnd;

		currentSection = sections[i];

		for(idxCurrent = idxEnd; idxCurrent >= idxBegin; idxCurrent--)
		{
			// delete it from the configSectionTable
			tempLine = strltrim(strrtrim(configLines[idxCurrent]));
			removeResult = dynRemove(configLines, idxCurrent);
			if (removeResult == -1)
			{
				Debug("\n ERROR: fwInstallation_deleteComponentFromConfigInMemory(): could not remove the line from table");
			}
			
			if (tempLine == "" )
			{
			}
			else if ( strtok(tempLine, "#") == 0)
			{
			}
			else // the templine contains parameters
			{
				parameter_Value = strsplit(tempLine, "=");
				tempParameter = strltrim(strrtrim(parameter_Value[1]));
				tempValue = strltrim(strrtrim(parameter_Value[2]));
				tempString = strltrim(strrtrim(tempValue, "\""));
				tempValue = tempString;  // now value is without quotation marks
				strValues = strsplit(tempValue, ",");
				
				for(j = 1 ; j <= dynlen(strValues); j++)
				{
					tempValue = strValues[j];
					strValues[j] = strrtrim(strltrim(tempValue , "\" ") , "\" ");
				}
				
				tempString = currentSection + ":" + tempParameter;
				
				// Deleting the values from memory
				idxSectionParam = dynContains(configSectionTable[1], tempString);
					
				if(idxSectionParam == 0)
				{
				}
				else if (idxSectionParam == -1)
				{
					fwInstallation_throw("Cannot read value from configSectionTable: ");
				}
				else{
				
					for(j = 1; j <= dynlen(strValues); j++)
					{
						idxValue = dynContains(configSectionTable[idxSectionParam + 1], strValues[j]);
						
						if(idxValue > 0)
						{
							removeResult = dynRemove(configSectionTable[idxSectionParam + 1], idxValue);
						}					
					}

				} // else
			}
				
		}
		
	}
	
}


/** This function checks whether the section-parameter-value is defined in the memory


@param configSectionTable: the memory representation of a config file     [1][i] - [section:parameter] , [i+1][j] - [value]
@param section: the value of a section
@param parameter: the value of a parameter
@param value: the value of a "value"

@author M.Sliwinski
*/

int fwInstallation_configContainsValue(dyn_dyn_string & configSectionTable, string section , string parameter, string value)
{
	int idxOfParameter;
	int idxOfValue;
	
	idxOfParameter = dynContains(configSectionTable[1] , section + ":" + parameter);
	
	if(idxOfParameter == 0)
	{
//		Debug("\n fwInstallation_configContainsValue: There is no section_parameter:" + section + ":" + parameter);
		return 0;
	}
	else if (idxOfParameter == -1)
	{
		Debug("\n ERROR: fwInstallation_configContainsValue: error in checking section_parameter" );
		return 0;
	}
	else
	{	
		idxOfValue = dynContains(configSectionTable[idxOfParameter + 1], value);
		if(idxOfValue ==  0)
		{
			return 0;
		}
		else if (idxOfValue == -1)
		{
//			Debug("\n fwInstallation_configContainsValue: error in checking value" );
			return 0;
		}
		else
		{
//			Debug("\n fwInstallation_configContainsValue: value exists: returning 1");
			return 1;
		}
		
	}
}

						
/** This function builds the memory representation of a config file

@param loadedSections: the list of sections loaded from the config file
@param configSectionTable: the memory representation of a config file     [1][i] - [section:parameter] , [i+1][j] - [value]
@param configLines: dyn_string containing the lines from the config file 
@param fileName: the name of a config file

@author M.Sliwinski
*/
	
int fwInstallation_loadConfigIntoTables(dyn_string & loadedSections, dyn_dyn_string & configSectionTable, dyn_string & configLines, string fileName)
{
//	dyn_string knownSections = makeDynString("[ui]" , "[ctrl]");
	
	dyn_string parameter_Value;

	int idxSectionParam;
	int idxSection;
	int idxValue;
	int sectionLength;

	bool fileLoaded = false;

	string fileInString;

	string tempLine;
	string tempParameter;
	string tempValue;
	string tempString; 

	dyn_string strValues;
	
	string currentSection = "NOT_KNOWN";
	string lineTrimmed;
	
	int i, j ;
	
	fileLoaded = fileToString(fileName, fileInString);
	
	if (! fileLoaded )
	{
	
		fwInstallation_throw("Cannot load " + fileName + " file");
	}
	else 
	{
//		Debug("\n" + fileName + " - file loaded");
	}

	configLines = fwInstallation_splitLines(fileInString);
	
// each line is loaded in a row of dyn_string configLines
	
	for(i = 1; i <= dynlen(configLines); i++)
	{
		tempLine = strltrim(strrtrim(configLines[i]));

					
		if (tempLine == "" )
		{
//			Debug("\n The line is blank |"  + tempLine + "|");
		}
		else if ( strtok(tempLine, "#") == 0)
		{
//			Debug("\n This line is a comment |"  + tempLine + "|");
		}
		else if ( strtok(tempLine, "[") == 0)
		{
//			Debug("\n This line is a section |"  + tempLine + "|");
		//	if(dynContains(knownSections, tempLine))
		//	{
//						Debug("\n Adding new section into memory: " + tempLine);
			
					dynAppend(loadedSections ,tempLine);
					currentSection = tempLine;
					
		//	}
		//	else
		//	{
			//	Debug("\n This section is not known");
		//				currentSection = "NOT_KNOWN";
		//	}
		}
		else // this is parametrization
		{ 
			if (currentSection == "NOT_KNOWN")
			{
				// Debug("\n This section is not known: don't add parameter to memory");
			}
			else // This section is already in memory
			{
//				Debug("\n Adding the parameter into memory" + tempLine + "|");
				
				parameter_Value = strsplit(tempLine, "=");
				
				tempParameter = strltrim(strrtrim(parameter_Value[1]));
				
				tempValue = strltrim(strrtrim(parameter_Value[2]));
				
				tempString = strltrim(strrtrim(tempValue, "\""));
				
				tempValue = tempString;  // now value is without quotation marks
				
				strValues = strsplit(tempValue, ",");
				
				for(j = 1 ; j <= dynlen(strValues); j++)
				{
					tempValue = strValues[j];
					strValues[j] = strrtrim(strltrim(tempValue , "\" ") , "\" ");
				}
				
				// we hava all the values in a dyn_string - strValues
								
				idxSection = dynContains(loadedSections, currentSection);
				
				if (idxSection > 0)  // this section is in loaded sections
				{
				
					tempString = currentSection + ":" + tempParameter;
												
					idxSectionParam = dynContains(configSectionTable[1], tempString);
					
	//				Debug("\n idxSection : " + idxSection );
				
					if(idxSectionParam == 0)  // the parameter tempParameter is not defined
					{
						
						dynAppend(configSectionTable[1], tempString);
						
//						Debug("\n Adding parameter: " + tempString + " and values: " + strValues + "for the first time");
						
						idxSectionParam = dynContains(configSectionTable[1], tempString);
						
						for( j = 1; j<= dynlen(strValues); j++)
						{
							
							dynAppend(configSectionTable[idxSectionParam + 1], strValues[j]);
							
						}
							
	//					Debug("\n adding the parameter: " + tempParameter );			
					}
					else if( idxSectionParam == -1)
					{

					}
					else // the parameter is defined for the section add the value
					{
		
			
						for( j = 1; j<= dynlen(strValues); j++)
						{
									
							idxValue = dynContains(configSectionTable[idxSectionParam + 1], strValues[j]);
							
							if(idxValue == 0)
							{
								dynAppend(configSectionTable[idxSectionParam + 1], strValues[j]);
//								Debug("\n Adding parameter: " + tempString + " and values: " + strValues);
								
							}
							else if (idxValue == -1)
							{
								Debug("\n ERROR: fwInstallation_loadConfigIntoTables():  Error in adding Value into memory");
							}
							else
							{
//								Debug("\n This value already exists: " + tempValue);
							}
						}
					}
				} // if (dynContains(loadedSections, currentSection))
				else
				{	
					// This parameter is in a "not known section"
				}
				
			}
		
		} // else		
	} // end for	
        
        

}

/** This function saves the new order of project paths into the config file.
Provided list of paths must contain all paths that were previously in config file. 
If PROJ_PATH is not at the last position in the list (or is missing) it will be automatically moved/added at the end of the provided list.

@param projPaths (in)  List of project paths in choosen order
@return 0 if OK, -1 if error
@author Sascha Schmeling
*/

int fwInstallation_changeProjPaths(dyn_string projPaths)
{  
  string proj_path = PROJ_PATH;
  fwInstallation_normalizePath(proj_path);
  fwInstallation_normalizePathList(projPaths);

  //FVR reshuffle project paths to make sure that the last one corresponds to the project path
  dynRemove(projPaths, dynContains(projPaths, proj_path));
  dynAppend(projPaths, proj_path);

  string configPath = getPath(CONFIG_REL_PATH);
  string configFile = configPath + "config";
  string fileInString;
  if(!fileToString(configFile, fileInString))//load config file into string
  {
    fwInstallation_throw("Failed to load config file: " + configFile + ". Cannot change order of project paths");
    return -1;
  }
  dyn_string configLines = fwInstallation_splitLines(fileInString);
  int configLinesLen = dynlen(configLines);

  int projPathsToChange = dynlen(projPaths);//get length of provided list of project paths
  int changedProjPath = 0;
  for(int i=1;i<=configLinesLen;i++)
  {
    string currentLine = strltrim(strrtrim(configLines[i]));
    if(currentLine == "")//empty config line - skipping
      continue;

    dyn_string paramNameValue = strsplit(currentLine, "=");
    string paramName = strltrim(strrtrim(paramNameValue[1]));

    if(paramName != "proj_path" || dynlen(paramNameValue) != 2)//skip lines that don't contain project paths, second condition to avoid exception in exotic cases
      continue;

    string paramValue = strltrim(strrtrim(paramNameValue[2]));
    paramValue = strltrim(strrtrim(paramValue, "\""), "\"");
    fwInstallation_normalizePath(paramValue);//prepare path from config for comparison
    if(dynContains(projPaths, paramValue) <= 0)//if path which is currently in config is missing in the provided list of ordered paths then abort changes
    {
      fwInstallation_throw("Missing path: " + paramValue + " in the list of provided path. Cannot change order of project paths");
      return -1;
    }

    changedProjPath++;
    if(changedProjPath > projPathsToChange)//make sure that list of ordered paths does not contain less paths than config file - to avoid 'index out of range' exception
    {
      fwInstallation_throw("List of provided project paths does not contain all paths from config file. Cannot change order of project paths");
      return -1;
    }
    //now config entry can be updated safely
    configLines[i] = "proj_path = \"" + projPaths[changedProjPath] + "\"";
  }

  if(changedProjPath != projPathsToChange)//ensure that all paths from provided list were written to configLines
  {
    fwInstallation_throw("List of provided project paths contains more paths (" + (string)projPathsToChange +
                         ") than config file (" + (string)changedProjPath + "). Cannot change order of project paths");
    return -1;
  }
  if(fwInstallation_saveFile(configLines, configFile) != 0)
  {
    fwInstallation_throw("Failed to save config file with reordered project paths. Project paths order remains unchanged");
    return -1;
  }
  return 0;
}

/** This function creates a project path, either creates the directory or just adds the path

@param sPath:	project path to be created
@param createDirectory flag to indicate if the directory has to be created if it does not exist (default value is true)
@return 0 if OK, -1 if error
*/

int fwInstallation_createPath(string sPath, bool createDirectory = true)
{
  dyn_string projPaths;
  int i, x;
  string result;
	
  int directoryExists;
  bool state;
  string cmd, err = 0;
  string dp = fwInstallation_getInstallationDp();
	
	if(fwInstallation_normalizePath(sPath) == -1)
	{
	  return -1;
	}
  if (access(sPath, F_OK) == -1 && createDirectory)
  {
    mkdir(sPath, "755");
		if(access(sPath, F_OK) != -1)
      fwInstallation_throw("New directory successfully created: " + sPath, "INFO", 10);
		else
		{
         fwInstallation_throw("You must define the full path. Project path will not be added");
         return -1;
     }
  }
	//the directory has been created - add it into the config file
	if(fwInstallation_addProjPath(sPath, 999))
  {
    fwInstallation_throw("File to add project path to config file: " + sPath);    
    return -1;
  }
        
  dpSet(dp + ".installationDirectoryPath", sPath);
  
  return 0;
}

///FVR: 29/03/2006

/** This function retrieves the component information from the PVSS DB and
	displays it in the panel

@param componentName the name of a file with component description
@author M.Sliwinski
*/

fwInstallation_getComponentDescriptionPVSSDB(string componentName, int reduHostNum = 0)
{
	float componentVersion;
	string descFile;
	string date;
	dyn_string componentFiles;
	dyn_string configFiles_linux;
	dyn_string configFiles_windows;
	dyn_string configFiles_general;
	dyn_string initFiles;
	dyn_string dplistFiles;
	dyn_string scriptFiles;
	dyn_string requiredComponents;
	dyn_string requiredNameVersion;
	dyn_string dynSubComponents;
	dyn_string postInstallFiles;
	string componentVersionString;
  string sourceDirectory;
	
	string requiredName;
	string requiredVersion;
	//shape shape_destinationTable = getShape("tblSubComponents");
 string dp = fwInstallation_getComponentDp(componentName, reduHostNum);

	int i;

		dpGet(dp + ".componentVersionString:_original.._value", componentVersionString);
		dpGet(dp + ".descFile:_original.._value", descFile);
		dpGet(dp + ".componentFiles:_original.._value", componentFiles);
		dpGet(dp + ".configFiles.configLinux:_original.._value", configFiles_linux);
		dpGet(dp + ".configFiles.configWindows:_original.._value", configFiles_windows);
		dpGet(dp + ".configFiles.configGeneral:_original.._value", configFiles_general);

		dpGet(dp + ".initFiles:_original.._value", initFiles);
		dpGet(dp + ".scriptFiles:_original.._value", scriptFiles);
		dpGet(dp + ".dplistFiles:_original.._value", dplistFiles);
		dpGet(dp + ".requiredComponents:_original.._value", requiredComponents);
		dpGet(dp + ".date:_original.._value", date);
		dpGet(dp + ".subComponents:_original.._value", dynSubComponents);
		dpGet(dp + ".postInstallFiles:_original.._value", postInstallFiles);
    
    dpGet(dp + ".sourceDir:_original.._value", sourceDirectory);

		TextName.text = componentName;
		TextVersion.text = componentVersionString;
		TextDate.text = date;
		
		for(i = 1; i<= dynlen(componentFiles); i++)
			selectionOtherFiles.appendItem(componentFiles[i]);
		
		for(i = 1; i<= dynlen(configFiles_windows); i++)
			selectionConfigFiles_windows.appendItem(configFiles_windows[i]);
		
		for(i = 1; i<= dynlen(configFiles_linux); i++)
			selectionConfigFiles_linux.appendItem(configFiles_linux[i]);
		
		for(i = 1; i<= dynlen(configFiles_general); i++)
			selectionConfigFiles_general.appendItem(configFiles_general[i]); 
		
		for(i = 1; i<= dynlen(initFiles); i++)
			selectionInitFiles.appendItem(initFiles[i]);
		
		for(i = 1; i<= dynlen(dplistFiles); i++)
			selectionDplistFiles.appendItem(dplistFiles[i]);
		
		for(i = 1; i<= dynlen(scriptFiles); i++)
			selectionScripts.appendItem(scriptFiles[i]);
		
		for(i = 1; i<= dynlen(requiredComponents); i++)
		{	
			requiredNameVersion = strsplit(requiredComponents[i], "=");
			requiredName = requiredNameVersion[1];
			
			if(dynlen(requiredNameVersion) > 1)
			{
				requiredVersion = requiredNameVersion[2];
			}
			else
			{
				requiredVersion = " ";
			}
			
			selectionRequiredComponents.appendItem(requiredName + " ver.: " + requiredVersion);
			
		}
		
		for(i = 1; i <= dynlen(postInstallFiles); i++)
			selectionPostInstallFiles.appendItem(postInstallFiles[i]);
		
		for(i = 1; i <= dynlen(dynSubComponents); i++)
			selectionSubComponents.appendItem( dynSubComponents[i]);
    
    TextSourceDirectory.text = sourceDirectory;
    string descFilePath = sourceDirectory + descFile;
    fwInstallation_normalizePath(descFilePath);
    bool isSourceDirReadable = isfile(descFilePath);
    btnCalculateHash.enabled = isSourceDirReadable;
    TextIsAccessible.text = isSourceDirReadable?"Yes":"No";
}

/** This function puts the components to be deleted in order in which they should be deleted
The function only checks if the component chosen for deleting depend on each other.
The function operates on the component information contained in the PVSS DB

algorithm: suppose we have the following components to delete:  com1, com2, com3
the dependencies are following:
	com1: is required by com2
	com2: is required by com3
	com3: is nor required by them
We can first delete the com3 because it is not required by com1 i com3
	the dependencies are following:
	com1: is required by com2
	com2: is not required by any component
If there is a loop: com1 is required by com2 and com2 is required by com1 the components can not be ordered

@param componentsNames: the dyn_string of the components to be put in order before deleting 
@param componentsNamesInOrder: the dyn_string of the ordered components to be deleted

@author M.Sliwinski
*/

fwInstallation_putComponentsInOrder_Delete(dyn_string componentsNames, dyn_string & componentsNamesInOrder)
{
	dyn_dyn_string dependencies; //  first column - component name, next columns - components that require this component
	dyn_string dynDependentComponents;
	string tempComponentName;
	bool emptyListExists = true;
	int i, j, k;
	
	// build the dependencies table
	// for each compomponent
	for(i = 1; i <= dynlen(componentsNames); i++)
	{
		// build the dependencies table
		dynAppend(dependencies[i] , componentsNames[i]);
		
		// get the list of dependent components
		fwInstallation_getListOfDependentComponents(componentsNames[i], dynDependentComponents);
		// append the dependent components
		dynAppend(dependencies[i], dynDependentComponents);
	}
	 

	// put the components in order - algorithm is described in the comment before the function
	while(emptyListExists)
	{
		emptyListExists = false;
			
			// for each component	
			for(i = 1; i <= dynlen(componentsNames); i++)
			{
				// if it is not required by other components
				if((dynlen(dependencies[i]) == 1) && (dependencies[i][1] != "EMPTY"))
				{
					emptyListExists = true;

					tempComponentName = dependencies[i][1];
					
					// remove the component name from the dependencies table ( set it to EMPTY value )
					dependencies[i][1] = "EMPTY"; 
					
					// put it at the end of the  components in order
					dynAppend(componentsNamesInOrder, tempComponentName);
					
					// remove the component from the list
					for(j = 1; j <= dynlen(componentsNames); j++)
					{
						
						k = dynContains(dependencies[j], tempComponentName);
						
						if(k > 0)
						{
							// this component no longer requires other components
							dynRemove(dependencies[j], k);	
						}	
					}
				}
			}
	}
	
	// if there were unsolved dependencies copy the components to the end of the list
	
	for(i = 1; i <= dynlen(componentsNames); i++)
	{
		if(dependencies[i][1] != "EMPTY")
		{
			dynAppend(componentsNamesInOrder, dependencies[i][1]);
		}	
	}
		
}


/** This function gets the list of dependent components. This functions from the list of  all  installed components
 retrieves the list of components that require strComponentName

@param strComponentName: the name of the component for which we would like to find dependent components
@param dynDependentComponents: the dyn_string of components that require the strComponentName component
@author M.Sliwinski
*/

fwInstallation_getListOfDependentComponents(string strComponentName, dyn_string & dynDependentComponents)
{

	dyn_string dynInstalledComponents, dynInstalledComponentDps;
	dyn_string dynRequiredComponents;
	dyn_string dynTmpNameVersion;
	string strTmpName;
	int i, j, k;
	
	dynClear(dynDependentComponents);
	
	// get all the components installed in the system
  dynInstalledComponentDps =  fwInstallation_getInstalledComponentDps();
	// check all the components whether they require the strComponentName
	for(i = 1; i <= dynlen(dynInstalledComponentDps); i++) 
	{
    dynInstalledComponents[i] = dpSubStr( dynInstalledComponentDps[i], DPSUB_DP ); 
    strreplace(dynInstalledComponents[i], "fwInstallation_", "");

    if( dynInstalledComponents[i] != strComponentName)
    {
      // retrieve the required components
      dpGet(dynInstalledComponentDps[i] + ".requiredComponents", dynRequiredComponents);
      // check whether the strComponentName is required by this component
      for(j = 1; j <= dynlen(dynRequiredComponents); j++)
      {
        dynClear(dynTmpNameVersion);
        dynTmpNameVersion = strsplit(dynRequiredComponents[j], "=");
        strTmpName = strltrim(strrtrim(dynTmpNameVersion[1]));
        if(strTmpName == strComponentName)
        {
          string name = "";
          dpGet("fwInstallation_" + dynInstalledComponents[i] + ".name", name);
//				      dynAppend(dynDependentComponents, dynInstalledComponents[i]);	
				      dynAppend(dynDependentComponents, name);	
				    }
      }
    }
  }
}

/** this function deletes the component files, the component information from the config file
	and the internal DP created by the installation tool with the description of a component. 
	This function does not delete the component data point types ( ETM is planning to 
	add the functionality of deleting the DPT, DP from the ASCII Manager ).

@param componentName (in) the name of a component to be deleted
@param componentDeleted (out) result of the operation
@param deleteAllFiles (in) flag indicating if the components files must also be deleted. Default value is true.
@param deleteSubComponents flag indicating if the subcomponent must also be deleted. Default value is true.
@author F. Varela
*/
int fwInstallation_deleteComponent(string componentName, 
                                   bool & componentDeleted, 
                                   bool deleteAllFiles = TRUE, 
                                   bool deleteSubComponents = true,
                                   bool &deletionAborted)
{

	dyn_string componentFiles, componentFilesDelete;
	dyn_string deleteFiles;
	dyn_string postDeleteFiles;
	dyn_string dynDependentComponents;
	dyn_string dynSubComponents;
	string strDependentComponentsNames;
	dyn_string dreturns;
	dyn_float dreturnf;
	int iReturn;
	int	errorDeletingComponent, error;
	int i,k;
	string installationDirectory, tempString;
	int errorCounter = 0;
	string errorString,descFileName;
	dyn_string strErrors = "";
	dyn_string dynPostDeleteFiles_all;
  string componentVersion;
  string msg;
  
  string dp = fwInstallation_getComponentDp(componentName);
  if(!dpExists(dp))
  {
    componentDeleted = true;
    return 0;
  }
	  
  dpGet(dp + ".componentVersionString", componentVersion,
        dp + ".installationDirectory", installationDirectory,
        dp + ".subComponents", dynSubComponents,
        dp + ".componentFiles", componentFiles,
        dp + ".deleteFiles", deleteFiles,
        dp + ".postDeleteFiles", postDeleteFiles);
  dynUnique(componentFiles);
  
  if(installationDirectory == "") {fwInstallation_throw("The installation directory for the " + componentName + " does not exist or is not specified!", "error", 4);return -1;}

  fwInstallation_throw("Deleting component: " + componentName + " v." + componentVersion + " from project " + PROJ + " in host " + fwInstallation_getHostname(), "info", 10);
  //begin check the component dependencies - if it is required by other components 
  fwInstallation_getListOfDependentComponents(componentName, dynDependentComponents);

  if(dynlen(dynDependentComponents) > 0)
  {
    for(i = 1; i <= dynlen(dynDependentComponents); i++) strDependentComponentsNames += dynDependentComponents[i] + "|";
    fwInstallation_showMessage(makeDynString("Dependent components at deletion of "+componentName+":",strDependentComponentsNames));
    // ask the user if he wants to delete this component - other components are using it
    if(myManType() == UI_MAN )
      ChildPanelOnCentralReturn("fwInstallation/fwInstallationDependencyDelete.pnl", "Dependencies of " + componentName,
                                makeDynString("$strDependentNames:" + strDependentComponentsNames , "$componentName:" + componentName), dreturnf, dreturns);
    else
    {
//      fwInstallation_throw("Deleting component: " + componentName + ", which is required by " + strDependentComponentsNames, "warning", 10);
      dreturns[1] = "Install_Delete";
    }
			
    // check the return value of fwInstallationDependency .pnl
    if(dreturns[1] == "Install_Delete")
    {
      fwInstallation_showMessage(makeDynString("User choice at deletion of "+componentName+": DELETE"));
    }
    else if(dreturns[1] == "DoNotInstall_DoNotDelete")
    {
      fwInstallation_showMessage(formatTime("[%Y-%m-%d_%H:%M:%S] ", getCurrentTime())+": Component deletion aborted by the user.");
      deletionAborted = true;
      return 0;
    }
  }

	if(!deletionAborted)
	{
    // check if all files are deletable
    // FVR: Do this check only if the deleteAllFiles flag is set to true
    if(deleteAllFiles)
    {	
      for (k=1; k<=dynlen(componentFiles); k++)
      {
        if(access(installationDirectory + "/" + componentFiles[k], F_OK) == 0)
          dynAppend(componentFilesDelete, componentFiles[k]);
        else
          fwInstallation_throw("Component " + componentName + " points to a non existing file: " + installationDirectory + "/" + componentFiles[k], "WARNING", 3);
      }
    }

    if(myManType() == UI_MAN && shapeExists("logFileName")) 
    {
      logFileName.text = PROJ_PATH + "/log/fwInstallation.log\"";
    }
          
		fwInstallation_writeToMainLog(formatTime("[%Y-%m-%d_%H:%M:%S] ",getCurrentTime()) + "Starting to delete " + componentName);
		fwInstallation_showMessage(makeDynString("Deleting " + componentName + " ... ")); 
		
		// delete all subcomponents
		for(i = 1; i <= dynlen(dynSubComponents); i++)
		{
      if(deleteSubComponents)
      {
        fwInstallation_showMessage(makeDynString("   Deleting sub components: " + dynSubComponents[i]));
        fwInstallation_deleteComponent(dynSubComponents[i], componentDeleted, deleteAllFiles, deleteSubComponents, deletionAborted);
      }
   }	

		
   // begin store the postDelete files in a datapoint
		if(dynlen(postDeleteFiles)>0)
   {
     for(i=1; i<=dynlen(postDeleteFiles); i++)
			  dynAppend(dynPostDeleteFiles_all, installationDirectory +"/"+ postDeleteFiles[i]);
    
		  dpSet(fwInstallation_getInstallationPendingActionsDp() + ".postDeleteFiles", dynPostDeleteFiles_all);			
   }
    
   // delete the DP
   dpDelete(dp);
   delay(1);             
   
   // execute delete scripts
   for(i =1; i <= dynlen(deleteFiles); i++)
   {
     msg = "Executing the delete file ... ";
     fwInstallation_throw(msg, "INFO", 10);
     fwInstallation_showMessage(makeDynString(msg));
     string componentDeleteFile = deleteFiles[i];
     // read the file and execute it		
     fwInstallation_evalScriptFile( installationDirectory +"/"+ componentDeleteFile , iReturn);
     if(iReturn == -1)
     {
       msg = "Executing the delete file: " + componentDeleteFile + " - Component: " + componentName;
       fwInstallation_throw(msg, "WARNING", 10);
//       fwInstallation_showMessage(makeDynString(msg));
       errorDeletingComponent = -1;
     }
   }
   
   if(deleteAllFiles)
   {
     msg = "Deleting files for component: " + componentName;
     fwInstallation_throw(msg, "INFO", 10);
     fwInstallation_showMessage(makeDynString(msg));
     if(fwInstallation_deleteFiles(componentFilesDelete, installationDirectory)) 
       errorDeletingComponent = -1;
		}
		
		// now delete the component info from the config file
   msg = "Updating the project config file after component deletion: " + componentName;
   fwInstallation_throw(msg, "INFO", 10);
//		fwInstallation_showMessage(makeDynString(msg));
		_fwInstallation_DeleteComponentFromConfig(componentName);
	}

	if(myManType() == UI_MAN && shapeExists("logFileName"))	
	  logFileName.text = "";

	if((errorDeletingComponent == -1))
	{
    msg = "There were errors while deleting the components - see the log for details - Component: " + componentName;
//    fwInstallation_showMessage(makeDynString(msg));		
    fwInstallation_throw(msg);		
    if(deletionAborted)
    {
      fwInstallation_writeToMainLog(formatTime("[%Y-%m-%d_%H:%M:%S] ",getCurrentTime()) + componentName + " de-installation aborted");
    } else 
    {
      fwInstallation_writeToMainLog(formatTime("[%Y-%m-%d_%H:%M:%S] ",getCurrentTime()) + componentName + " deleted with errors");
    }
    componentDeleted = FALSE;
	}
	else
	{
    msg = "Component deleted: " + componentName;
    fwInstallation_throw(msg, "INFO", 10);
//    fwInstallation_showMessage(makeDynString(msg));
    fwInstallation_writeToMainLog(formatTime("[%Y-%m-%d_%H:%M:%S] ",getCurrentTime()) + componentName + " deleted");
    componentDeleted = true;
	}

  if(myManType() == UI_MAN && shapeExists("logFileName"))
    tempString = logFileName.text;
  
  if(tempString != "")
  {
//    fwInstallation_showMessage(makeDynString("Please find the log file for this deinstallation operation in:",tempString));
    fwInstallation_writeToMainLog(formatTime("[%Y-%m-%d_%H:%M:%S] ",getCurrentTime()) + "Please find the log file for this de-installation operation in: "+tempString);
  }
  
  if(fwInstallation_checkComponentBrokenDependencies()) fwInstallation_throw("fwInstallation_deleteComponent() -> Failed to check broken dependencies");
  
  dyn_int projectStatus;
  if(fwInstallationDB_getUseDB() && fwInstallationDB_connect() == 0)
  {
    fwInstallation_throw("Updating FW System Configuration DB after deletion of " + componentName + " v"+ componentVersion, "INFO", 10);
    fwInstallationDB_storeInstallationLog();
    fwInstallationDB_registerProjectFwComponents();
    fwInstallationDBAgent_checkIntegrity(projectStatus);
  }

  return 0;
}


/** This function resolves the XML files and versions of the compoents required 
*   for installation during the installation of a particular component

@param sourceDir (in) source directory
@param requiredComponents (in) list of required components
@param dsFileComponentName (out) list of names corresponding to the required components (obsolete, legacy)
@param dsFileVersions (out) list versions corresponding to the required components
@param dsFileComponent (out) list of XML files corresponding to the required components
@return 0 if success, -1 if error 
*/
int fwInstallation_checkDistribution(string sourceDir, 
                                     dyn_string requiredComponents, 
                                     dyn_string &dsFileComponentName, 
                                     dyn_string &dsFileVersions, 
                                     dyn_string &dsFileComponent)
{
  dyn_dyn_string componentsInfo;
  dyn_string dsTmp;
  string requiredComponentName;
  string requiredComponentVersion;
  string fileComponentName;
  string fileComponentVersion;
  string fileComponent;
   
  fwInstallation_getAvailableComponents(sourceDir, componentsInfo);
  for(int jj = 1; jj <= dynlen(requiredComponents); jj++){
    dsTmp = strsplit(requiredComponents[jj], "=");
    requiredComponentName = dsTmp[1];
    requiredComponentVersion = dsTmp[2];
                
    for(int ii = 1; ii <= dynlen(componentsInfo);ii++){
      fileComponentName = componentsInfo[ii][1];
      fileComponentVersion = componentsInfo[ii][2];
      fileComponent = componentsInfo[ii][5];
      if(patternMatch(requiredComponentName, fileComponentName)){
        fwInstallation_throw("Required component found in distribution:" + requiredComponentName + ". Comparing versions", "info", 10);
        if(_fwInstallation_CompareVersions(fileComponentVersion, requiredComponentVersion)){
          fwInstallation_throw("Distribution version OK. Proceeding with the installation: " + fileComponentVersion + " required: " +  requiredComponentVersion, "info", 10);
          fwInstallation_throw("Component description file: " + fileComponent, "info", 10);
          dynAppend(dsFileComponentName, fileComponentName);
          dynAppend(dsFileComponent, fileComponent);
          dynAppend(dsFileVersions, fileComponentVersion);
        }else{
          fwInstallation_throw("Distribution version NOT OK. Aborting installation: " + fileComponentVersion + " required: " +  requiredComponentVersion);
          return -1;
        }
      }
    }
  }
  //If all components are available it all right otherwise error
  if(dynlen(dsFileComponentName) == dynlen(requiredComponents))
    return 0;
  else
	  return -1;
  
}


/** This function checks if a given component is correctly installed

@param componentName: Name of the component to be checked
@param version: Version of the component to be checked. Optional parameter: if emtpy it checks for any version.
@return 0 if the component version or newer correctly installed,  -1 if the component installed correctly or just not installed
@author F. Varela
*/
int fwInstallation_checkInstalledComponent(string componentName, string version = "")
{
  dyn_string componentDPs;
  string componentDP;
  bool requiredComponents;
  
  string componentVersionString, installationDirectory;
  float componentVersion;

  componentDP = fwInstallation_getComponentDp(componentName);
        
  if(!dpExists(componentDP))
  {
    return -1;
  }
  dpGet(componentDP+".componentVersionString:_online.._value",componentVersionString,
        componentDP+".installationDirectory:_online.._value",installationDirectory,
        componentDP+".requiredInstalled:_online.._value", requiredComponents);


	if(componentVersionString == "")
	{
		dpGet(componentDP + ".componentVersion:_original.._value", componentVersion);
		if(componentVersion == floor(componentVersion))
		{
			sprintf(componentVersionString,"%2.1f",componentVersion);
		} else {
			componentVersionString = componentVersion;
		}
		dpSet(componentDP + ".componentVersionString:_original.._value", componentVersionString);
	}

  if(version != "" && !_fwInstallation_CompareVersions(componentVersionString, version)){
    fwInstallation_throw("fwInstallation_checkInstalledComponent()-> An old version:"+ componentVersionString +" of the component: " + componentName + " is installed in this system. Requested version: " + version, "INFO", 10);
    return -1;	  
	}
	
	if(!requiredComponents){
    fwInstallation_throw("fwInstallation_checkInstalledComponent()-> Version:"+ componentVersionString +" of the component: " + componentName + " is installed but not all required components", "INFO", 10);
    return -1;	  	
	}
  //fwInstallation_throw("fwInstallation_checkInstalledComponent()-> Version:"+ componentVersionString +" of the component: " + componentName + " installed in this system", "INFO", 10);
  return 0;
}

/** This function checks if a previous installation of a particular directory exists in the target directiory
@param destinationDir (in) target directory
@param componentName (in) name of the component to be checked
@param versionInstalled (in) version of the component installed, if any
@return 0 if OK, -1 if error
*/
int fwInstallation_checkTargetDirectory(string destinationDir, string componentName, string &versionInstalled)
{
  dyn_string componentFiles = getFileNames(destinationDir, componentName + ".xml");
  
  if(dynlen(componentFiles) >0)
  {
    dyn_dyn_mixed componentInfo;  
    fwInstallationXml_load(destinationDir + "/" + componentFiles[1], componentInfo);
    versionInstalled = componentInfo[FW_INSTALLATION_XML_COMPONENT_VERSION];
    return 1;
  }
  
  versionInstalled = "";
  return 0;
}


/** This function retrieves the files in a directory recursing over sub-directories
@param dir (in) directory where to look for files
@param pattern (in) search pattern
@return list of file found as a dyn_string 
*/
dyn_string fwInstallation_getFileNamesRec(string dir = ".", string pattern = "*")
{
	dyn_string tempDynString;
	dyn_string allFileNames;
	string newDir = "/*";
	dynClear(allFileNames);
	fwInstallation_recurserFileNames(dir, "*", allFileNames);

	if(dynlen(allFileNames) > 0)
		for(int i=1; i<=dynlen(allFileNames); i++)
		{
			strreplace(allFileNames[i], dir + "/", "");
			strreplace(allFileNames[i], "//", "/");
		}

    if(pattern != "*")
      pattern = "*" + pattern;

	for(int i=1; i<=dynlen(allFileNames); i++){
		if(patternMatch(pattern, allFileNames[i]))
			dynAppend(tempDynString, allFileNames[i]);
	}
	return tempDynString;
}

/** Helper function used by fwInstallation_getFileNamesRec
@param dir (in) directory where to look for files
@param pattern (in) search pattern
@param fileNames (out) names of the files found
*/
fwInstallation_recurserFileNames(string dir, string pattern, dyn_string & fileNames)
{
  dyn_string tempDynString = getFileNames(dir + "/", pattern, FILTER_DIRS);
	dyn_string tempDynString2 = getFileNames(dir, pattern, FILTER_FILES);

  for(int i=1; i<=dynlen(tempDynString2); i++)
    tempDynString2[i] = dir +"/"+ tempDynString2[i];
	
	dynAppend(fileNames, tempDynString2);
  dynRemove(tempDynString, dynContains(tempDynString,".."));
  dynRemove(tempDynString, dynContains(tempDynString,"."));

 	for(int i=1; i<=dynlen(tempDynString); i++)
  {
    fwInstallation_recurserFileNames(dir + "/" + tempDynString[i] + "/", pattern, fileNames);
  }
}

/** This function retrieves the full path to the XML description file of a component
@param componentName (in) name of the component
@param componentVersion (in) version of the component (legacy, not used)
@param sourceDir (in) source directory
@param descriptionFile (out) XML description file
@param isItSubComponent (out) indicates if it is a subcomponent or not
@return 0 if OK, -1 if error
*/
int fwInstallation_getDescriptionFile(string componentName,
                                      string componentVersion, 
                                      string sourceDir, 
                                      string &descriptionFile, 
                                      bool &isItSubComponent)
{
  string fileName = componentName + ".xml";
  dyn_dyn_string componentsInfo;

  fwInstallation_getAvailableComponents(makeDynString(sourceDir), componentsInfo, componentName);
  for(int i =1; i <= dynlen(componentsInfo); i++){
    
	  if(componentsInfo[i][1] == componentName && componentsInfo[i][2] == componentVersion)
    {
	    descriptionFile = componentsInfo[i][4];

	    if(componentsInfo[i][3] == "no")
	      isItSubComponent = false;
	    else
	      isItSubComponent = true;

        return 0;
    }
  }
  return -1;
}

/** This function parses the xml file of a coponent to find out if it is a sub-component
@param xmlFile (in) XML file name
@param isSubComponent (out) indicates if it is a subcomponent or not
@return 0 if OK, -1 if error
*/
int fwInstallation_isSubComponent(string xmlFile, bool &isSubComponent)
{
  dyn_dyn_mixed componentInfo;  
  isSubComponent = false;
  if(fwInstallationXml_load(xmlFile, componentInfo))
  {	
     fwInstallation_throw("fwInstallation_isSubComponent() -> Could not load XML file " + xmlFile + ". Aborted.", "error", 4);
     return -1;
  }
  isSubComponent = componentInfo[FW_INSTALLATION_XML_COMPONENT_IS_SUBCOMPONENT][1];
  
  return 0;

}
/** This function returns the port used by the distribution manager of the local project
@return port number
*/
int fwInstallation_getDistPort()
{
  int port;
  string filename = PROJ_PATH + "/config/config";
  string section = "dist";

  paCfgReadValue(filename,section, "distPort", port);
 
  if(port == 0)
    port = 4777;

  return port; 
}

/** This function returns the redundancy port of the local project
@return port number
*/
int fwInstallation_getReduPort()
{
  int port;
  const string filename = PROJ_PATH + "/config/config";
  const string section = "redu";

  // reduPort is the new configuration entry. portNr is deprecated
  paCfgReadValue(filename, section, "reduPort", port);

  // FIXME: backward compatibility, to be removed in future
  if(port == 0)
    paCfgReadValue(filename, section, "portNr", port);
 
  if(port == 0)
    port = 4899;

  return port; 
}

/** This function returns the split port of the local project
@return port number
*/
int fwInstallation_getSplitPort()
{
  int port;
  string filename = PROJ_PATH + "/config/config";
  string section = "split";

  paCfgReadValue(filename,section, "splitPort", port);
 
  if(port == 0)
    port = 4778;

  return port; 
}

/** This function returns the pmon user (not yet implemented)
@return pmon user 
*/
string fwInstallation_getPmonUser()
{
   return "N/A";   
}

/** This function returns the pmon pwd (not yet implemented)
@return pmon user 
*/
string fwInstallation_getPmonPwd()
{
   return "N/A";   
}

/** This function returns hostname 'localhost'
  */
string fwInstallation_getPmonHostname()
{
  string pmonHost = "localhost";
  if(VERSION_DISP == "3.11-SP1") // Emulate 3.11 behaviour
    pmonHost = fwInstallation_getHostname();
  return pmonHost;
}

/** This function returns the properties of the local project as a dyn_mixed array
@param projectInfo (in) Project properties
@return 0 if OK, -1 if error
*/
int fwInstallation_getProjectProperties(dyn_mixed &projectInfo)
{
  string fwInstToolVer;
  string pvssOs;
  dyn_string ds = eventHost();
  string hostname = strtoupper(ds[1]);  
  if(_WIN32)
    pvssOs = "WINDOWS";
  else
    pvssOs = "LINUX";
  
  fwInstallation_getToolVersion(fwInstToolVer);

  projectInfo[FW_INSTALLATION_DB_PROJECT_NAME] = PROJ;
  projectInfo[FW_INSTALLATION_DB_PROJECT_HOST] = hostname;
  projectInfo[FW_INSTALLATION_DB_PROJECT_DIR] = PROJ_PATH;
  projectInfo[FW_INSTALLATION_DB_PROJECT_SYSTEM_NAME] = getSystemName();
  projectInfo[FW_INSTALLATION_DB_PROJECT_SYSTEM_NUMBER] = getSystemId();
  projectInfo[FW_INSTALLATION_DB_PROJECT_PMON_PORT] = pmonPort();
  projectInfo[FW_INSTALLATION_DB_PROJECT_PMON_USER] = fwInstallation_getPmonUser();
  projectInfo[FW_INSTALLATION_DB_PROJECT_PMON_PWD] = fwInstallation_getPmonPwd();
  projectInfo[FW_INSTALLATION_DB_PROJECT_TOOL_VER] = fwInstToolVer;
  
  if(fwInstallationDB_getUseDB())
    projectInfo[FW_INSTALLATION_DB_PROJECT_CENTRALLY_MANAGED] = fwInstallationDB_getCentrallyManaged();
  else
    projectInfo[FW_INSTALLATION_DB_PROJECT_CENTRALLY_MANAGED] = 0;
    
  projectInfo[FW_INSTALLATION_DB_PROJECT_PVSS_VER] = VERSION_DISP;
  projectInfo[FW_INSTALLATION_DB_PROJECT_DATA] = dataPort();
  projectInfo[FW_INSTALLATION_DB_PROJECT_EVENT] = eventPort();
  projectInfo[FW_INSTALLATION_DB_PROJECT_DIST] = fwInstallation_getDistPort();
  projectInfo[FW_INSTALLATION_DB_PROJECT_REDU_PORT] = fwInstallation_getReduPort();
  projectInfo[FW_INSTALLATION_DB_PROJECT_SPLIT_PORT] = fwInstallation_getSplitPort();  
  projectInfo[FW_INSTALLATION_DB_PROJECT_SYSTEM_OVERVIEW] = 1;  
  projectInfo[FW_INSTALLATION_DB_PROJECT_UPGRADE] = "";
  projectInfo[FW_INSTALLATION_DB_PROJECT_TOOL_STATUS]= fwInstallation_getToolStatus();
//  projectInfo[FW_INSTALLATION_DB_PROJECT_REDU_NR] = fwInstallation_getRedundancyNumber();
  ds = eventHost();
  projectInfo[FW_INSTALLATION_DB_PROJECT_SYSTEM_COMPUTER] = strtoupper(ds[1]);
   
  
  if(_WIN32)
    projectInfo[FW_INSTALLATION_DB_PROJECT_OS] = "WINDOWS";  
  else
    projectInfo[FW_INSTALLATION_DB_PROJECT_OS] = "LINUX";  

  projectInfo[FW_INSTALLATION_DB_PROJECT_REDU_HOST] = dynlen(ds) > 1 && ds[2] != ""?strtoupper(ds[2]):hostname;
  projectInfo[FW_INSTALLATION_DB_PROJECT_INSTALL_ONLY_IN_SPLIT] = fwInstallation_getInstallOnlyInSplit(); 
  projectInfo[FW_INSTALLATION_DB_PROJECT_RESTORE_REDUNDANCY_AFTER_INST] = fwInstallation_getRestoreRedundancyAfterInstallation(); 

  return 0;  
}


/** This function loads the init file for the installation tool
@return 0 if OK, -1 if error
*/
int fwInstallation_loadInitFile()
{
  string cmd;
  string asciiManager = PVSS_BIN_PATH + fwInstallation_getWCCOAExecutable("ascii");
  string infoFile = getPath(LOG_REL_PATH) + fwInstallation_getWCCOAExecutable("ascii") + "_info.log";
  string logFile =  getPath(LOG_REL_PATH) + fwInstallation_getWCCOAExecutable("ascii") + "_log.log";
  string asciiFile = "";
  string instDir;
  dyn_string paths;
  string dp = fwInstallation_getInstallationDp();
  
  // Find ascii file
  fwInstallation_getProjPaths(paths);
  for(int i = dynlen(paths); i >= 1; i--)
  {
    paths[i] +="/config/"; 
    if(access(paths[i] + gFwInstallationInitFile, R_OK) == 0)
    {
	  asciiFile = paths[i] + gFwInstallationInitFile;
      break;
    }
  }

  if(asciiFile == "")
  {
//    fwInstallation_throw("FW Installation Tool init file cannot be found.", "INFO", 10);
	  return 0;
  }
  
  fwInstallation_throw("FW Installation Tool Init file found. Loading now: " + asciiFile, "INFO", 10);
  
  // Can we write to the log directory? Adjust command line accordingly
  string extraArgs = ""; // Put any extra arguments here
  string logPostfix = ""; // Logging postfix, put at the end of command string
  if(access(PROJ_PATH + LOG_REL_PATH, W_OK) != 0)
  {
    fwInstallation_throw("fwInstallation_loadInitFile() -> Project log directory not writeable. Omitting stderr output.", "warning");
    logPostfix = "-noVerbose";								
  }
  else
  {
	sprintf(logPostfix, "-log +stderr -log -file > %s 2> %s", infoFile, logFile);
  }
  
  // In split mode we need to explicitly connect to only one host,
  // the one that we are currently being executed on
  if(fwInstallationRedu_isRedundant() && fwInstallationRedu_isSplitMode())
  {
    // Note: we assume that event and data hosts are the same, this
    // will not support some exotic configurations where active data & even
    // are on separate hosts
    string hostname = myReduHost();
    
    // If this is a remote UI - we don't support such option (init file would
    // be loaded using local file, while we are connected to a remote system)
    if(strtoupper(hostname) != strtoupper(fwInstallation_getHostname()))
    {
      fwInstallation_throw("fwInstallation_loadInitFile(): skipping loading of init file (redundand system in split mode, remote UI).", "WARNING", 10);
      return 0;
    }

  	sprintf(extraArgs, "-data %s:%d -event %s:%d",
  		hostname, dataPort(),
  		hostname, eventPort()
  	);
  }
  
  sprintf(cmd, "%s -in \"%s\" -yes %s %s",
  	asciiManager,
  	asciiFile,
  	extraArgs,
  	logPostfix // This has to be as last one (output redirection on Linux)
  	);

  if(_WIN32)
  {
    system("cmd /c " + cmd);  
  }
  else
  {
    system(cmd);
  }
  
  dpGet(dp + ".installationDirectoryPath", instDir);
  if(access(instDir, F_OK) != 0)
    mkdir(instDir, 777);
  
  if(access(instDir, W_OK) != 0)
  {
    fwInstallation_throw("fwInstallation_loadInitFile() -> Could not create installation directory", "error", 4);
    return -1;
  }

  fwInstallation_addProjPath(instDir, 999); 
  
  return 0;
   
}

/** This function loads the init file for the installation tool
@return 0 if OK, -1 if error
*/
int fwInstallation_runInitScript()
{
  int iReturn = 0;
  string script = "";
  dyn_string paths;
  
  //find asccii file:
  fwInstallation_getProjPaths(paths);
  for(int i = dynlen(paths); i >= 1; i--)
  {
    paths[i] +="/scripts/"; 
    if(access(paths[i] + gFwInstallationInitScript, R_OK) == 0)
    {
	    script = paths[i] + gFwInstallationInitScript;
      break;
    }
  }

  if(script == "")
  {
//    fwInstallation_throw("FW Installation Tool init script cannot be found.", "INFO", 10);
    return 0;
  }
  
  fwInstallation_throw("FW Installation Tool Init script found. Executing now: " + script, "INFO", 10);
  fwInstallation_evalScriptFile(script, iReturn);
  
  return iReturn;   
}


/** This function checks if pmon is protected with a username and a pwd
@return 0 if PMON is NOT protected, 1 otherwise
*/
int fwInstallation_isPmonProtected()
{
  bool err;
  string str, host;  
  int port, iErr = paGetProjHostPort(PROJ, host, port);
  dyn_dyn_string dsResult;
  
  paVerifyPassword(PROJ, "", "", iErr);
  if(iErr > 0)
    return 1;
  
  return 0; 
}
/** This function returns post install files that are scheduled to run

@param allPostInstallFiles:	dyn_string to contain the list of post install files
@return 0 - "success"  -1 - error 
@author S. Schmeling
*/
int fwInstallation_postInstallToRun(dyn_string & allPostInstallFiles)
{
  dyn_string dynPostInstallFiles_all;
  string dp = fwInstallation_getInstallationPendingActionsDp();
        
  if(dpExists(dp))
  {
    // get all the post install init files
    dpGet(dp + ".postInstallFiles", dynPostInstallFiles_all);
    allPostInstallFiles = dynPostInstallFiles_all;
    return 0;
  } 
  else 
  {
		  dynClear(allPostInstallFiles);
		  return -1;
  }
}
/** This function gets list of sections in config file into a dyn_string
@param dsSectionList (out)  dyn_string that will contain names of the all configs' sections
@param sPattern (in)  string to define the pattern 
@return 0 - sections with specified pattern were forund in config file,
        -1 - error (config file cannot be loaded),  -2 - no sections with given pattern were found in config file (dsSectionList is empty)
@author D. Dyngosz
*/
int fwInstallation_getSections(dyn_string &dsSectionList, string sPattern = "")
{ 
  dynClear(dsSectionList);

  string configPath = getPath(CONFIG_REL_PATH);
  string configFile = configPath + "config";

  dyn_string configLines;
  if(_fwInstallation_getConfigFile(configLines) != 0)
    return -1;

  int configLinesLen = dynlen(configLines);
  for (int i=1;i<=configLinesLen;i++)
  {
    string configLine = strltrim(strrtrim(configLines[i]));
    if(strpos(configLine, "[") == 0) {
      int iEndPos = strpos(configLine, "]");
      if(iEndPos > 1) { //section exist
        dynAppend(dsSectionList, substr(configLine, 1, iEndPos-1));
      }
    }
  }
  if(sPattern != ""){
    dsSectionList = dynPatternMatch(sPattern, dsSectionList);
  }
  if(dynlen(dsSectionList)<1)
    return -2;

  return 0;
}
/** This function gets a specified section into a dyn_string

@param section: string to define the section 
@param configEntry: dyn_string that will contain the lines for the section
@return 0 - "success"  -1 - error  -2 - section does not exist
@author S. Schmeling
*/

int fwInstallation_getSection( string section, dyn_string & configEntry )
{ 
	dyn_string configLines;
	
	dyn_string tempLines;
	string tempLine;
	int i,j;
	bool sectionFound = FALSE;
	
	string configPath = getPath(CONFIG_REL_PATH);
	string configFile = configPath + "config";

	if(_fwInstallation_getConfigFile(configLines) == 0)
	{
		for (i=1; i<=dynlen(configLines); i++)
		{
			tempLine = configLines[i];
			if(strpos(strltrim(strrtrim(tempLine)), "["+section+"]") == 0)
			{
				if(sectionFound == FALSE)
				{
					sectionFound = TRUE;
				}
				j = 1;
				do
				{
					if(i+j <= dynlen(configLines))
					{
						tempLine = configLines[i+j];
						if(strpos(strltrim(strrtrim(tempLine)),"[") != 0)
						{
//							if(tempLine != "")
//							{
							dynAppend(tempLines,tempLine);
//							}
							j++;
						}
					}
				}
				while ((strpos(strltrim(strrtrim(tempLine)),"[") != 0) && (i+j <=dynlen(configLines)));
				i += j-1;
			}
		}
		if(sectionFound == TRUE)
		{
			configEntry = tempLines;
			return 0;
		} else {
			return -2;
		}
	} else {
		return -1;
	}
}


/** This function sets a specified section from a dyn_string

@param section: string to define the section to where the data has to written
@param configEntry: dyn_string that contains the lines for the section
@return 0 - "success"  -1 - error
@author S. Schmeling
*/

int fwInstallation_setSection( string section, dyn_string configEntry )
{
	if(fwInstallation_clearSection( section ) != -1)
	{
		return fwInstallation_addToSection( section, configEntry );	
	} else {
		return -1;
	}
}


/** This function will delete all entries of the specified section as well as all but the first header.

@param section: string to define the section which will be cleared (first header will stay)
@return 0 - "success"  -1 - error  -2 - section does not exist
@author S. Schmeling
*/

int fwInstallation_clearSection( string section )
{
	dyn_string configLines;
	dyn_int tempPositions;
	dyn_string tempLines;
	string tempLine;
	int i,j;
	bool sectionFound = FALSE;
	
	string configPath = getPath(CONFIG_REL_PATH);
	string configFile = configPath + "config";

	if(_fwInstallation_getConfigFile(configLines) == 0)
	{
		for (i=1; i<=dynlen(configLines); i++)
		{
			tempLine = configLines[i];
			if(strpos(strltrim(strrtrim(tempLine)), "["+section+"]") == 0)
			{
				if(sectionFound == FALSE)
				{
					sectionFound = TRUE;
				} else {
					dynAppend(tempPositions,i);
				}
				if(i < dynlen(configLines))
				{
					j = 1;
					do
					{
						tempLine = configLines[i+j];
						if(strpos(strltrim(strrtrim(tempLine)),"[") != 0)
						{
							dynAppend(tempPositions,i+j);
							if(tempLine != "")
							{
								dynAppend(tempLines,tempLine);
							}
							j++;
						}
					}
					while ((strpos(strltrim(strrtrim(tempLine)),"[") != 0) && (i+j <=dynlen(configLines)));
					i += j-1;
				}
			}
		}
		if(dynlen(tempPositions)>0)
		{
			for (i=dynlen(tempPositions); i>0; i--)
			{
				dynRemove(configLines, tempPositions[i]);
			}
		}			
		if(sectionFound == TRUE)
		{
			return fwInstallation_saveFile(configLines, configFile);
		} else {
			return -2;
		}
	} else {
		return -1;
	}
}

/** This function adds the given lines to a section in the config file.

@param section: string to define the section where the data has to be added (will be created if not existing)
@param configEntry: dyn_string containing the lines to be added
@return 0 - "success"  -1 - error 
@author S. Schmeling
*/
int fwInstallation_addToSection( string section, dyn_string configEntry )
{
	dyn_string configLines;
	
	dyn_int tempPositions;
	dyn_string tempLines;
	string tempLine;
	int i,j;
	bool sectionFound = FALSE;
	
	string configPath = getPath(CONFIG_REL_PATH);
	string configFile = configPath + "config";

	j = -1;

	if(_fwInstallation_getConfigFile(configLines) == 0)
	{
		for (i=1; i<=dynlen(configLines); i++)
		{
			tempLine = configLines[i];
			if(strpos(strltrim(strrtrim(tempLine)), "["+section+"]") == 0)
			{
				j = i;
				break;
			}
		}
		tempLines = configEntry;
		if(j > 0)
		{
			if(j+1 <= dynlen(configLines))
				dynInsertAt(configLines,tempLines,j+1);
			else
				dynAppend(configLines,tempLines);			
		} else {
			tempLine = "[" + section + "]";
			dynInsertAt(tempLines,tempLine,1);
			dynAppend(configLines,tempLines);
		}
		return fwInstallation_saveFile(configLines, configFile);
	} else {
		return -1;
	}
}

int fwInstallation_getInstallOnlyInSplit()
{
  int installInSplit = 0;
  string dp = fwInstallation_getAgentDp() + ".redundancy.installOnlyInSplit";
  if (dpExists(dp))
  {
    dpGet(dp, installInSplit);
  }
  return installInSplit;
}

void fwInstallation_setInstallOnlyInSplit(int installOnlyInSplit)
{
  int currentInstallInSplit = 0;
  string dp = fwInstallation_getAgentDp() + ".redundancy.installOnlyInSplit";
  if (dpExists(dp))
  {
    dpGet(dp, currentInstallInSplit);
    if (currentInstallInSplit != installOnlyInSplit)
      dpSet(dp, installOnlyInSplit);
  }
}
int fwInstallation_getRestoreRedundancyAfterInstallation()
{
  int restore = 0;
  string dp = fwInstallation_getAgentDp() + ".redundancy.restoreRedundancyAfterInstallation";
  if (dpExists(dp))
  {
    dpGet(dp, restore);
  }
  return restore;
}

void fwInstallation_setRestoreRedundancyAfterInstallation(int restore)
{
  int currentRestore = 0;
  string dp = fwInstallation_getAgentDp() + ".redundancy.restoreRedundancyAfterInstallation";
  if (dpExists(dp))
  {
    dpGet(dp, currentRestore);
    if (currentRestore != restore)
      dpSet(dp, restore);
  }
}

string fwInstallation_getLastInstToolSourcePath()
{
  string lastPath;
  string dp = fwInstallation_getInstallationDp() + ".lastInstToolSourcePath";
  if (dpExists(dp))
  {
    dpGet(dp, lastPath);
  }
  return lastPath;
}

void fwInstallation_setLastInstToolSourcePath(string lastPath)
{
  string dp = fwInstallation_getInstallationDp() + ".lastInstToolSourcePath";
  if (dpExists(dp))
  {
    dpSet(dp, lastPath);
  }
}

/** This function retrieves the component information from the xml file and
	displays it in the panel
@param descFile: the name of a file with component description
@author M.Sliwinski
*/
void fwInstallationXml_getComponentDescription(string descFile)
{

	string strComponentFile;

	bool fileLoaded;
//	dyn_string dynComponentFileLines;
	dyn_string dynRequiredComponents;
	
	dyn_string requiredNameVersion;
	string requiredName;
	string requiredVersion;
	
	string fileName;
	int i;
	

  dyn_string tags, values;
  dyn_anytype attribs;	
	int j;
        
  if(fwInstallationXml_get(descFile, tags, values, attribs))
  {
    fwInstallation_throw("fwInstallationXml_getComponentDescription() -> Cannot load " + descFile + " file ");
    return;
  }
  
  for(i = 1; i <= dynlen(tags); i++)
  {
  	switch(tags[i])
				{
					case "file" : 		selectionOtherFiles.appendItem(values[i]);
										break;
	
					case "name":  		TextName.text = values[i];
										break;
										
					case "desc":		selectionDescription.appendItem(values[i]);
										break;
					
					case "version": 	TextVersion.text = values[i];
										break;
										
					case "date": 		TextDate.text = values[i];
										break;
										
					case "required":	if(values[i] != "")
										{
											requiredNameVersion = strsplit(values[i], "=");
											requiredName = requiredNameVersion[1];
				
											if(dynlen(requiredNameVersion) > 1)
											{
												requiredVersion = requiredNameVersion[2];
											}
											else
											{
												requiredVersion = " ";
											}			
											selectionRequiredComponents.appendItem(requiredName + " ver.: " + requiredVersion);
										}
										break;
										
					case "config":		selectionConfigFiles_general.appendItem(values[i]);
										break;
					
					case "script": 		selectionScripts.appendItem(values[i]);
										break;
					
					case "postInstall": selectionPostInstallFiles.appendItem(values[i]);
										break;
															
					case "init": 		selectionInitFiles.appendItem(values[i]);
										break;
										
					case "config_windows": 	selectionConfigFiles_windows.appendItem(values[i]);
											break;
											
					case "config_linux" : 	selectionConfigFiles_linux.appendItem(values[i]);
											break;
											
					case "dplist":		selectionDplistFiles.appendItem(values[i]);
										break;
										
					case "includeComponent": strreplace(values[i], "./", "");
											 selectionSubComponents.appendItem(values[i]);
											 break;										
												
				} // end switch
				
			} // end while	
					
//		}	
}

const string FW_INSTALLATION_PATH_SEPARATOR = "/";


/** This function normalises the path. After execution of the function the given argument is normalised - all backslashes in path are replaced with slashes.
@param projPath: Project path (in/out)
@return 0 if path was successfully normalised, -1 in case of error
*/
int fwInstallation_normalizePath(string &projPath, bool addTrailingSlash = false)
{
  string tempPath = projPath;
  
  //handle UNC paths, it is enough to replace double backslashes with double slashes (although path in that form is not handled by windows file explorer)
  bool isUnc = false;
  if(patternMatch("\\\\*", projPath) || patternMatch("//*", projPath))//double backslashes for original paths, double slashes for paths that were normalized previously
  {
    isUnc = true;
    tempPath = substr(projPath, 2);
  }
  
  if(strreplace(tempPath, "\\", FW_INSTALLATION_PATH_SEPARATOR) == -1)
  {
    fwInstallation_throw("fwInstallation_normalizePath() -> failed to convert \"\\\"");
    return -1;
  }
  dyn_string pathElem = strsplit(tempPath, FW_INSTALLATION_PATH_SEPARATOR);
  if(dynlen(pathElem) == 0)
  {
    fwInstallation_throw("fwInstallation_normalizePath() -> empty path");
    return -1;
  }

  if(tempPath[0] == FW_INSTALLATION_PATH_SEPARATOR)//linux absolute path
    tempPath = FW_INSTALLATION_PATH_SEPARATOR;
  else
    tempPath = "";

  int pathElemLen = dynlen(pathElem);
  for(int i=1;i<=pathElemLen;i++)
  {
    if(pathElem[i] != "" && pathElem[i] != ".")
      tempPath += pathElem[i] + FW_INSTALLATION_PATH_SEPARATOR;
  }
  if(!addTrailingSlash)
    tempPath = strrtrim(tempPath,"/");
  
  if(isUnc)
    tempPath = "//" + tempPath;
  
  projPath = tempPath;
  return 0;
}

/** Normalize list of paths. Replaces all backslashes with slashes.
  * @param projPaths - list of project paths
  * @return In case of error returns -1 (no changes are made to input variable),
  *         normally (OK) returns 0
 */
int fwInstallation_normalizePathList(dyn_string &projPaths, bool addTrailingSlash = false)
{
  // Get a copy to prevent changes in case of error
  dyn_string tmpPaths = projPaths;
  
  int pathCount = dynlen(projPaths);
  for(int i=1; i<=pathCount; i++)
  {
    if(fwInstallation_normalizePath(tmpPaths[i], addTrailingSlash) == -1)
    {
      return -1; // In case of error, exit (no changes made to projPaths)
    }
  }
  
  projPaths = tmpPaths;
  return 0;
}

/** Returns a list of lines in given string, breaking at line boundaries.
  * New line characters (LF or CR+LF) are removed and don't occur in the returned list.
  * If string contains n new line characters then the returned list has size n+1. However if
  * the last new line character is also the last character of the string then last empty substring
  * is ignored and returned list has size n.
  * @note This function is recommended to use instead of strsplit(string, "\n") as it provides
  *       the correct handling of carriage return (CR) character in UNIX systems.
  * @param s (in)  String to be splitted.
  * @return List of lines in given string. 
  */
dyn_string fwInstallation_splitLines(string s)
{
  if(!_WIN32) strreplace(s, "\r\n", "\n");
  return strsplit(s, "\n");
}

const int FW_INSTALLATION_DEV_TYPE_DP_PATTERN = 1;
const int FW_INSTALLATION_DEV_TYPE_DP_TYPE = 2;

//Device Types mapping - key: device type, value: {device type dp pattern, device type dp type}
mapping deviceTypesInfo = makeMapping(
    "SCHNEIDER_PLC", makeDynString("_unPlc_", "_UnPlc"),
    "SIEMENS_PLC", makeDynString("S7_PLC_", "S7_PLC"),
    "FEC", makeDynString("CRYOGTW_", "CRYOGTW")
    );

void fwInstallation_getDeviceTypes(dyn_string &devTypes)
{
  devTypes = mappingKeys(deviceTypesInfo);
}

const string FW_INSTALLATION_DEV_DP_PATTERN_WILDCARD = "*";
const string FW_INSTALLATION_DEV_DPE = ".configuration.subApplications";

/** This functions returns the dp pattern and dp type for given device type.
 * @param deviceType Device type name.
 * @param devicesDpt (out) Datapoint type of given device type name.
 * @return Datapoint pattern for given device type name or empty string when unknown device type.
*/
string _fwInstallation_getDevicesDpPattern(string deviceType, string &devicesDpt)
{
  if(!mappingHasKey(deviceTypesInfo, deviceType))
  {
    DebugTN("Unknown Device type: " + deviceType);
    return "";
  }
  
  string devicesDpPattern;
  if(dynlen(deviceTypesInfo[deviceType]) > 1)
  {
    devicesDpPattern = deviceTypesInfo[deviceType][FW_INSTALLATION_DEV_TYPE_DP_PATTERN] +
                       FW_INSTALLATION_DEV_DP_PATTERN_WILDCARD + FW_INSTALLATION_DEV_DPE;
    devicesDpt = deviceTypesInfo[deviceType][FW_INSTALLATION_DEV_TYPE_DP_TYPE];
  }
  else
  {
    DebugTN("Invalid device type dp info for: " + deviceType);
  }
  
  return devicesDpPattern;
}

const string FW_INSTALLATION_DEV_TYPE_GET_NAME_FUNCTION = "_fwInstallation_getDeviceName_";
    
string _fwInstallation_getDeviceName_FEC(string deviceDp)
{
  if(patternMatch("*__*", deviceDp))
    return substr(deviceDp, 0, (strlen(deviceDp) - 3));
  return deviceDp;
}

/** This functions gets the device name from device datapoint.
 * @param deviceDp Device datapoint.
 * @param deviceType Device type name.
 * @return Device name or empty string when unknown device type.
*/
string fwInstallation_getDeviceNameFromDp(string deviceDp, string deviceType)
{
  if(!mappingHasKey(deviceTypesInfo, deviceType))
  {
    DebugTN("Cannot get the device name. Unknown Device type: " + deviceType);
    return "";
  }
  
  deviceDp = dpSubStr(deviceDp, DPSUB_DP);
  strreplace(deviceDp, deviceTypesInfo[deviceType][FW_INSTALLATION_DEV_TYPE_DP_PATTERN], "");
  
  // execute additional name formatting function if there is any
  string formatNameFunction = FW_INSTALLATION_DEV_TYPE_GET_NAME_FUNCTION + deviceType;
  if(isFunctionDefined(formatNameFunction))
    deviceDp = callFunction(formatNameFunction, deviceDp);
  
  strreplace(deviceDp, "_", "-");
  return deviceDp;
}

const string FW_INSTALLATION_DEV_TYPE_GET_ADDITONAL_INFO_FUNCTION = "_fwInstallation_getDeviceAdditionalInfo_";

string _fwInstallation_getDeviceAdditionalInfo_SCHNEIDER_PLC(string deviceDp)
{
  return fwInstallation_getAdditionalPlcInfo(deviceDp);
}

string _fwInstallation_getDeviceAdditionalInfo_SIEMENS_PLC(string deviceDp)
{
  return fwInstallation_getAdditionalPlcInfo(deviceDp);
}

/** This function gets additional PLC info for the Schneider and Siemens PLCs.
 * @param plcDp (in) PLC datapoint
 * @return JSON formatted string with additional PLC info
*/
string fwInstallation_getAdditionalPlcInfo(string plcDp)
{
  string info = "{\"Application\":[\"Type\":\"<type>\",\"Framework\":\"<framework>\"," +
                "\"Import Date\":\"<importDate>\", \"PLC Application Version\":\"<plcApplicationVersion>\"]," +
                "\"Resources\":[\"PLC Baseline\":\"<baseline>\",\"PLC Resource Package\":\"<plcResourcePackage>\"," + 
                "\"SCADA Resource Package\":\"<scadaResourcePackage>\"]}";
  string type;
  string framework;
  string importDate;
  string plcApplicationVersion;
  string baseline;
  string a;
  string b;
  string c;
  string plcResourcePackage;
  string scadaResourcePackage;
  
  dpGet(plcDp + ".version.import", framework,
        plcDp + ".configuration.importTime", importDate,
        plcDp + ".configuration.type", type,
        plcDp + ".version.PLCApplication", plcApplicationVersion,
        plcDp + ".version.PLCBaseline", baseline,
        plcDp + ".version.PLCresourcePackageMajor", a,
        plcDp + ".version.PLCresourcePackageMinor", b,
        plcDp + ".version.PLCresourcePackageSmall", c,
        plcDp + ".version.resourcePackage", scadaResourcePackage);
  
  plcResourcePackage = a + "." + b + "." + c;

  strreplace(info, "<type>", type);  
  strreplace(info, "<framework>", framework);  
  strreplace(info, "<importDate>", importDate);  
  strreplace(info, "<plcApplicationVersion>", plcApplicationVersion);  
  strreplace(info, "<baseline>", baseline);  
  strreplace(info, "<plcResourcePackage>", plcResourcePackage);  
  strreplace(info, "<scadaResourcePackage>", scadaResourcePackage);  

  return info;
}

/** Retrieve existing devices of given type in given application on this system.
  @param deviceType Device type name.
  @param application Application name, when it is empty string then all devices will of given type will be retrieved.
  @param devices Variable to receive info about devices.
  @return 0 on success, -1 on error.
  
  @Note: Currently only information from 'Comment' field are filled, 'Info_URL' and 'Status' are missed.
         The 'Moon_Info' will be updated from MOON project.
*/
int fwInstallation_getDevices(string deviceType, string application, dyn_dyn_mixed &devices)
{
  string devicesDpt;
  string devicesDpPattern = _fwInstallation_getDevicesDpPattern(deviceType, devicesDpt);
  if(devicesDpPattern == "")
  {
    DebugTN("fwInstallation_getDevices(): Couldn't find dp pattern for given device type: " + deviceType);
    return -1;
  }
  
  dynClear(devices);
  
  //Check if device dpt exists in current system
  if(dynlen(dpTypes(devicesDpt)) < 1)
    return 0;
  
  dyn_string devDps = dpNames(getSystemName() + devicesDpPattern, devicesDpt);
 
  int n = dynlen(devDps);
  int k = 0;
  for(int i = 1; i <= n; i++)
  {
    dyn_string devApplications;
    dpGet(devDps[i], devApplications);
    if(dynContains(devApplications, application) == 0)
      continue;
    k++;
    
    string device = fwInstallation_getDeviceNameFromDp(devDps[i], deviceType);
    devices[k][FW_INSTALLATION_DB_WCCOA_DEV_NAME] = device;

    //get additional info if available
    string getAdditionalInfoFunction = FW_INSTALLATION_DEV_TYPE_GET_ADDITONAL_INFO_FUNCTION + deviceType;
    if(isFunctionDefined(getAdditionalInfoFunction))
      devices[k][FW_INSTALLATION_DB_WCCOA_DEV_COMMENT] = callFunction(getAdditionalInfoFunction,
                                                                      dpSubStr(devDps[i], DPSUB_SYS_DP));
    // Commented out intentionally, we don't have this information
    //devices[i][FW_INSTALLATION_DB_WCCOA_DEV_INFO_URL] = "";
    //devices[i][FW_INSTALLATION_DB_WCCOA_DEV_STATUS] = "";
  }
 
  return 0;
}

/** Shows and handles the right click pop-up menu in components table.
  * @param tableShape (in)  Components' table shape
  */
fwInstallation_ui_componentsTableRightClickPopupMenu(shape tableShape, int row, string column)
{
  if(row < 0) return;

  const int menuIdCopyComponents = 1;
  dyn_string menu = makeDynString("PUSH_BUTTON, Copy component list to clipboard, " + menuIdCopyComponents + ", 1");

  int selectedItemId;
  popupMenu(menu, selectedItemId);

  switch(selectedItemId)
  {
    case menuIdCopyComponents: fwInstallation_ui_copyComponentsListToClipboard(tableShape); break;
  }
}

/** Copies to clipboard a list of components and their versions as a string.
  * @param tableShape (in)  Components' table shape
  */
private void fwInstallation_ui_copyComponentsListToClipboard(shape tableShape)
{
  const dyn_string columns = makeDynString("componentName", "componentVersion");
  string componentListAsString = fwInstallation_ui_getTableColumnsAsString(tableShape, columns);
  if(setClipboardText(componentListAsString) != 0)
    fwInstallation_throw("Failed to copy components' list to clipboard", "WARNING");
}

/** Reads all rows of the given table's columns as a string.
  * @param tableShape (in)  Shape of a table
  * @param columns (in)  List of table columns
  * @param addHeader (in)  Flag that indicates if columns headers should be added at the beginning (true - default)
  * @param colSeparator (in)  String that separates fields of different columns (default is TAB character)
  * @return Content of table's columns as string. When shape is not ot type 'TABLE' or table don't have a specified column then empty string is returned.
  */
string fwInstallation_ui_getTableColumnsAsString(shape tableShape, dyn_string columns, bool addHeader = true, string colSeparator = "\t")
{
  if(fwInstallation_ui_areTableColumnsValid(tableShape, columns) != 0) return "";

  const string newLineChar = "\n";
  string tableText;

  int columnsToGet = dynlen(columns);
  if(addHeader)
  {
    for(int j=1;j<=columnsToGet;j++)
    {
      tableText += tableShape.columnHeader(
          tableShape.nameToColumn(columns[j]));
      if(j<columnsToGet) tableText += colSeparator;
    }
    tableText += newLineChar;
  }

  int tableRows = tableShape.lineCount();
  for(int i=0;i<tableRows;i++) {
    for(int j=1;j<=columnsToGet;j++)
    {
      tableText += tableShape.cellValueRC(i, columns[j]);
      if(j<columnsToGet) tableText += colSeparator;
    }
    if(i<tableRows-1) tableText += newLineChar;
  }
  return tableText;
}

private int fwInstallation_ui_areTableColumnsValid(shape tableShape, dyn_string columns)
{
  if(tableShape.shapeType() != "TABLE")
  {
    fwInstallation_throw("fwInstallation_ui_areTableColumnsValid() -> Given shape is not of type 'TABLE'");
    return -1;
  }
  int columnsLen = dynlen(columns);
  for(int i=1;i<=columnsLen;i++)
  {
    if(tableShape.nameToColumn(columns[i]) < 0)
    {
      fwInstallation_throw("fwInstallation_ui_areTableColumnsValid() -> Given table does not have a column named: '" + columns[i] + "'");
      return -2;
    }
  }
  return 0;
}

/******************************************
 *      Report installation progress      */

//Name of global variable that stores shape of 'Installation Info' panel
const string FW_INSTALLATION_REPORT_GLOBAL_SHAPE = "reportShape";

/** Creates/updates global variable that stores provided shape of a 'Installation Info' reference panel and therefore enables reporting of component installation process.
  * This function is called in fwInstallation_installationInfo.pnl panel with its own shape as an argument when user-defined event eventStartReporting() occurs. 
  * @param sh (in)  Shape of 'Installation Info' reference panel on main installation panel.
  */
void fwInstallation_reportInit(shape sh)
{
  if(!fwInstallation_reportReportShapeExists())
    addGlobal(FW_INSTALLATION_REPORT_GLOBAL_SHAPE, SHAPE_VAR);
  fwInstallation_reportSetReportShape(sh);
}

/** Removes global variable with shape of a 'Installation Info' reference panel. This disables reporting of reporting of component installation process.
  * This function is called in fwInstallation_installationInfo.pnl panel when user-defined event eventStopReporting() occurs. 
  */
void fwInstallation_reportTeardown()
{
  removeGlobal(FW_INSTALLATION_REPORT_GLOBAL_SHAPE);
}

/** Sets the shape stored by 'reportShape' global variable.
  * @param sh (in)  Shape that is assigned to 'reportShape' global variable
  */
private fwInstallation_reportSetReportShape(shape sh){
  execScript("int main(shape sh){" + FW_INSTALLATION_REPORT_GLOBAL_SHAPE + " = sh;}", makeDynString(), sh);
}

/** Returns the shape stored in 'reportShape' global variable.
  * @note fwInstallation_reportReportShapeExists() function should be called before to check if global variable exists. 
  * @return Shape stored in 'reportShape'
  */
shape fwInstallation_reportGetReportShape()
{
  shape sh;
  evalScript(sh, "int main(){return " + FW_INSTALLATION_REPORT_GLOBAL_SHAPE + ";}", makeDynString());
  return sh;
}

/** Checks if global variable 'reportShape' exists.
  * @return TRUE when 'reportShape' exists or else, FALSE
  */
bool fwInstallation_reportReportShapeExists(){
  return globalExists(FW_INSTALLATION_REPORT_GLOBAL_SHAPE);
}

//Name of the public function in fwInstallation_installationInfo.pnl panel ScopeLib, that processes parameter sent by fwInstallation_updateReport() according to the given message type
const string FW_INSTALLATION_REPORT_MESSAGE_HANDLING_FUNCTION = "updateReport";

/** Sends installation report messages to the 'Installation Info' panel.
  * This function invokes 'updateReport' public function in fwInstallation_installationInfo.pnl, with message type and parameter value provided as an arguments.
  * @note Handling of provided message type should be implemented in 'updateReport' public function in fwInstallation_installationInfo.pnl
  * @param messageType (in)  Type of the message
  * @param value (in)  Parameter value for given message type
  */
private void fwInstallation_updateReport(string messageType, anytype value)
{
  shape sh;
  if(fwInstallation_reportReportShapeExists())
    sh = fwInstallation_reportGetReportShape();
  if(!sh)//don't send messages when report panel shape does not exists or it is empty
    return;
  
  invokeMethod(fwInstallation_reportGetReportShape(), FW_INSTALLATION_REPORT_MESSAGE_HANDLING_FUNCTION, messageType, value);  
}

/** Elements of mapping, that stores information about installation of particular component **/
const string FW_INSTALLATION_REPORT_VARIABLE_INSTALATION_INFO_COMPONENT = "componentName";
const string FW_INSTALLATION_REPORT_VARIABLE_INSTALATION_INFO_PARENT = "parentComponentId";
const string FW_INSTALLATION_REPORT_VARIABLE_INSTALATION_INFO_REASON = "installationReason";
const string FW_INSTALLATION_REPORT_VARIABLE_INSTALATION_INFO_STAGE = "installationStage";
const string FW_INSTALLATION_REPORT_VARIABLE_INSTALATION_INFO_FINISHED = "isFinished";

/** Definition of report message types and functions that sends them **/

 const string FW_INSTALLATION_REPORT_MESSAGE_INSTALLATION_STARTED = "installationStarted";
/** This function sends installation start time. Start time is the current time.
  * @note This function must be called after the number of components to be installed is set.
  */
fwInstallation_reportInstallationStartTime()
{
  fwInstallation_updateReport(FW_INSTALLATION_REPORT_MESSAGE_INSTALLATION_STARTED, getCurrentTime());
}

const string FW_INSTALLATION_REPORT_MESSAGE_COMPONENTS_NUMBER = "componentsNumber";
/** This function sends number of components to be installed.
  * @param componentsNumber (in)  Number of components to be installed
  */
fwInstallation_reportSetTotalComponentsNumber(int componentsNumber)
{
  fwInstallation_updateReport(FW_INSTALLATION_REPORT_MESSAGE_COMPONENTS_NUMBER, componentsNumber);
}

const string FW_INSTALLATION_REPORT_MESSAGE_ADDITIONAL_COMPONENTS_NUMBER = "additionalComponentsNumber";
/** This function sends number of additional components to be installed (this number is added to the current number of components to be installed).
  * @param additionalComponentsNumber (in)  Number of additional components to be installed
  */
fwInstallation_reportUpdateTotalComponentsNumber(int additionalComponentsNumber)
{
  fwInstallation_updateReport(FW_INSTALLATION_REPORT_MESSAGE_ADDITIONAL_COMPONENTS_NUMBER, additionalComponentsNumber);
}

/** Definition of component installation steps **/
const int FW_INSTALLATION_REPORT_STEP_STARTING_INSTALLATION = 1;
const int FW_INSTALLATION_REPORT_STEP_PARSING_XML = 2;
const int FW_INSTALLATION_REPORT_STEP_CHECKING_REQUIREMENTS = 3;
const int FW_INSTALLATION_REPORT_STEP_VERIFYING_COMPONENT_PACKAGE = 4;
const int FW_INSTALLATION_REPORT_STEP_EXECUTING_PREINIT_SCRIPTS = 5;
const int FW_INSTALLATION_REPORT_STEP_INSTALLING_REQUIRED_COMPONENTS = 6;
const int FW_INSTALLATION_REPORT_STEP_INSTALLING_SUBCOMPONENTS = 7;
const int FW_INSTALLATION_REPORT_STEP_COPYING_FILES = 8;
const int FW_INSTALLATION_REPORT_STEP_IMPORTING_DPS = 9;
const int FW_INSTALLATION_REPORT_STEP_CONFIGURING_PROJECT = 10;
const int FW_INSTALLATION_REPORT_STEP_EXECUTING_INIT_SCRIPTS = 11;
const int FW_INSTALLATION_REPORT_STEP_REGISTERING_INSTALLATION = 12;
const int FW_INSTALLATION_REPORT_STEP_CALCULATING_SOURCE_FILES_HASHES = 13;
const int FW_INSTALLATION_REPORT_STEP_VERIFYING_DEPENDENCIES = 14;
const int FW_INSTALLATION_REPORT_STEP_REQUESTING_POSTINSTALLS = 15;
const int FW_INSTALLATION_REPORT_STEP_REGISTERING_INSTALLATION_IN_DB = 16;//optional step, only when DB is used
    
const string FW_INSTALLATION_REPORT_MESSAGE_INSTALLING_COMPONENT = "installingComponent";
/** This function sends installation progress of given component 
  * @param componentName (in)  Name of the component being installed
  * @param stage (in)  Current component installation step number
  */
fwInstallation_reportComponentInstallationProgress(string componentName, int stage)
{
  fwInstallation_updateReport(FW_INSTALLATION_REPORT_MESSAGE_INSTALLING_COMPONENT,
                              makeMapping(FW_INSTALLATION_REPORT_VARIABLE_INSTALATION_INFO_COMPONENT, componentName,
                                          FW_INSTALLATION_REPORT_VARIABLE_INSTALATION_INFO_STAGE, stage));
}

const string FW_INSTALLATION_REPORT_MESSAGE_COMPONENT_INSTALLATION_FINISHED = "componentInstallationFinished";
/** This function sends information that installation of given component is finished
  * @param componentName (in)  Name of the component which installation is finished
  */
fwInstallation_reportComponentInstallationFinished(string componentName)
{  
  fwInstallation_updateReport(FW_INSTALLATION_REPORT_MESSAGE_COMPONENT_INSTALLATION_FINISHED, componentName);
}

const string FW_INSTALLATION_REPORT_MESSAGE_INSTALLATION_LOG_MESSAGE = "installationLogMessage";
/** This function sends installation log messages ()
  * @note During processing of log messages in 'Installation Info' panel it is assumed that fwInstallation_throw() is called only by functions that run installation process
  * (this might not always be true - DB agent? - but this can be detected by checking if error comes from UI manager that runs fwInstallation main panel, but what about executing init scripts in dedicated control manager [future solution?]?)
  * + that component installation is not run in parallel (only one component is being installed at the moment - this should be always true)
  * @param message (in) Log message of errClass type
  */  
fwInstallation_reportInstallationMessage(errClass message)
{
  fwInstallation_updateReport(FW_INSTALLATION_REPORT_MESSAGE_INSTALLATION_LOG_MESSAGE, message);
}

