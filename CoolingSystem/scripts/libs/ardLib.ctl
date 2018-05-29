global dyn_string channelsToPlot;
global string myModuleNameMain;
global string myPanelNameMain;

const float PREFERRED_PLOT_ASPECT_RATIO = 2.21;
const float SIZE_OF_PLOTTABLE_AREA_X    = 850;
const float SIZE_OF_PLOTTABLE_AREA_Y    = 680;
const int   X_INITIAL_OF_PLOTTABLE_AREA = 370;
const int   Y_INITIAL_OF_PLOTTABLE_AREA = 130;

void disableAllCheckboxes() {
    // logoShape1.visible = TRUE;
     dyn_string allCheckboxes = getShapes(myModuleName(), myPanelName(), "shapeType", "CHECK_BOX");

     for( int i = 1; i <= dynlen(allCheckboxes); i++) {
         setValue(myModuleName() + "." + myPanelName() + ":" + allCheckboxes[i], "enabled", false);        
     }
}

void enableAllCheckboxes() {
  
    dyn_string allCheckboxes = getShapes(myModuleName(),myPanelName(), "shapeType", "CHECK_BOX");
    
    for( int i = 1; i <= dynlen(allCheckboxes); i++) {
        setValue(myModuleName() + "." + myPanelName() + ":" + allCheckboxes[i], "enabled", true);    
    }
    //logoShape1.visible = FALSE;
}

void loadPlots(string dpe) {
  
    if (dpe == "") dpe = $dpe;
    bool isChecked;
    int removeElement;
    getValue("checkBox", "state", 0 ,isChecked);
    if (isChecked == 1)
        dynAppend(channelsToPlot, dpe);
    else {
        dynRemove(channelsToPlot, dynContains(channelsToPlot, dpe));
    }

    int plotsNumber = dynlen(channelsToPlot);
    if ((isChecked == 1) && (plotsNumber > 1)) removePlots(plotsNumber - 1);
    else if ((isChecked == 1) && (plotsNumber = 1)) ;
    else removePlots(plotsNumber + 1);
    
    if (dynlen(channelsToPlot) > 0) {
        dyn_int gridSize = splitScreenGridDimensions(plotsNumber, SIZE_OF_PLOTTABLE_AREA_X, SIZE_OF_PLOTTABLE_AREA_Y);
        dyn_dyn_int initCoo = gridToCoordinates(plotsNumber, gridSize);
        dyn_dyn_float scaling = calculateScales(plotsNumber, gridSize);

        dyn_string exceptionInfo;
        for (int i = 1; i <= plotsNumber; i++) {
            fwTrending_addQuickFaceplate(myModuleName(),myPanelName(), "Plot" + i, 
                                      makeDynString(channelsToPlot[i] + ".vMon"),
                                      initCoo[i][1], initCoo[i][2], exceptionInfo, "_FwTrendingQuickPlotDefaults", scaling[i][1], scaling[i][2]);
        }
    }
}

dyn_int splitScreenGridDimensions(int numberOfPlots, float sizeX, float sizeY) {
    
    dyn_dyn_int arraySizeCandidates = makeDynInt(); 
    float i = 1;
    float rowsPerArrays = numberOfPlots;
    float fac;
    dyn_float factors;
    
    while (i <= rowsPerArrays) {
        dynAppend(arraySizeCandidates, makeDynInt(i, rowsPerArrays));
        if (i != rowsPerArrays) dynAppend(arraySizeCandidates, makeDynInt(rowsPerArrays, i));
        i++;
        rowsPerArrays = ceil(numberOfPlots/i);
    }
    
    for ( int i = 1; i <= dynlen(arraySizeCandidates); i++) {
          fac = (arraySizeCandidates[i][1] * sizeX) / (arraySizeCandidates[i][2] * sizeY);
          dynAppend(factors, fabs(fac - PREFERRED_PLOT_ASPECT_RATIO));
    }
    
    int pos = dynContains(factors, dynMin(factors));
    dyn_int optimalSize = arraySizeCandidates[pos];
    
    return optimalSize;
}





dyn_dyn_float calculateScales(int nPlots, dyn_int grid) {
  
    dyn_dyn_float scales; 
    float scx, scy;
    
    scx = (SIZE_OF_PLOTTABLE_AREA_X / grid[2]) / 517;
    scy = (SIZE_OF_PLOTTABLE_AREA_Y / grid[1]) / 300;//277
    
    for (int i = 1; i <= nPlots; i++) {
        dynAppend(scales, makeDynFloat(scx, scy));
    } 
    return scales;
}

dyn_dyn_int gridToCoordinates(int Nplots, dyn_int grid) {
  
    dyn_dyn_int initialPositions;
    float x, y;

    for (int i = 1; i <= grid[1]; i++) {
        for (int j = 1; j <= grid[2]; j++) {
            x = X_INITIAL_OF_PLOTTABLE_AREA + (j-1) * SIZE_OF_PLOTTABLE_AREA_X / grid[2];
            y = Y_INITIAL_OF_PLOTTABLE_AREA + (i-1) * SIZE_OF_PLOTTABLE_AREA_Y / grid[1];
            
            dynAppend(initialPositions, makeDynInt(floor(x), floor(y)));
        }
    }
    
    return initialPositions;  
}

void removePlots (int Nplots) {
    
    if (Nplots == 0) Nplots = dynlen(channelsToPlot);
    dyn_string exceptionInfo;
    
    for (int i = 1; i <= Nplots; i++) {
        fwTrending_removeFaceplate(myModuleName(), myPanelName(), "Plot" + i, exceptionInfo);
    }
}
