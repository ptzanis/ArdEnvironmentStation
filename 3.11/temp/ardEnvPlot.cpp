{
    
    int number_of_lines=0;
    int events;
    string line;
    ifstream file_Ard("temp.dat");

    gROOT->SetBatch(kTRUE);
    
    vector<string> ar_dataArd;
    
    
    while (getline(file_Ard, line))
    {
        ++number_of_lines;
        ar_dataArd.push_back(line);
    }
    
    int entries_file= number_of_lines-1;

    
    double pressure[entries_file],temperature[entries_file],humidity[entries_file],x[entries_file];
    
    
    for(int i=1;i<number_of_lines;i++)
    {
        std::string pressureString = ar_dataArd[i].substr(22,6);
        pressure[i-1]= atof(pressureString.c_str());
        std::string temperatureString = ar_dataArd[i].substr(31,5);
        temperature[i-1]= atof(temperatureString.c_str());
        std::string humidityString = ar_dataArd[i].substr(41,5);
        humidity[i-1]= atof(humidityString.c_str());
        x[i-1]=i;
        
    }
    
        string startTime=ar_dataArd[1].substr(0,19);
        string endTime=ar_dataArd[number_of_lines-1].substr(0,19);

        TCanvas *canvas_arduino=new TCanvas("canvas_arduino","canvas_arduino",1300,900);
        canvas_arduino.Divide(1,3);
        
        canvas_arduino.cd(1);
        gPad->SetGrid();
        gPad->SetTickx();
        gPad->SetTicky();

        TGraph *gr = new TGraph(number_of_lines-1,x,pressure);
        gr->SetMarkerColor(kBlue);
        gr->SetMarkerStyle(2);
        gr->SetTitle("#scale[1.6]{#font[62]{Pressure}}");
        gr->GetXaxis()->SetLabelSize(0.05);
        gr->GetXaxis()->SetTitleOffset(1.4);
        gr->GetYaxis()->SetLabelSize(0.05);
        gr->GetXaxis()->SetTitle("#scale[1.8]{#font[62]{Time (xSampling Time)}}");
        gr->GetYaxis()->SetTitle("#scale[1.8]{#font[62]{P (hPa)}}");
        gr->Draw("AP");
        
        char startTimeChar[19],endTimeChar[19];
        sprintf(startTimeChar,"%s",startTime.c_str());
        sprintf(endTimeChar,"%s",endTime.c_str());

        
         TPaveText *pt2 = new TPaveText(.75,.80,1,1,"bNDC");
         pt2->AddText(Form("#scale[1.]{Start : %s}",startTimeChar));
         pt2->AddText(Form("#scale[1.]{End  : %s}",endTimeChar));
         pt2.SetTextAlign(12);
         pt2->SetFillColor(0);
         pt2->SetBorderSize(1);
         
         
         pt2.Draw();
        
        
        canvas_arduino.cd(2);
        gPad->SetGrid();
        gPad->SetTickx();
        gPad->SetTicky();

        TGraph *gr = new TGraph(number_of_lines-1,x,temperature);
        gr->SetMarkerColor(kGreen);
        gr->SetMarkerStyle(2);
        gr->SetTitle("#scale[1.6]{#font[62]{Temperature}}");
        gr->GetXaxis()->SetLabelSize(0.05);
        gr->GetXaxis()->SetTitleOffset(1.4);
        gr->GetYaxis()->SetLabelSize(0.05);
        gr->GetXaxis()->SetTitle("#scale[1.8]{#font[62]{Time (xSampling Time)}}");
        gr->GetYaxis()->SetTitle("#scale[1.8]{#font[62]{T (C)}}");
        gr->Draw("AP");
        
        canvas_arduino.cd(3);
        gPad->SetGrid();
        gPad->SetTickx();
        gPad->SetTicky();

        TGraph *gr = new TGraph(number_of_lines-1,x,humidity);
        gr->SetMarkerColor(kRed);
        gr->SetMarkerStyle(2);
        gr->SetTitle("#scale[1.6]{#font[62]{Humidity}}");
        gr->GetXaxis()->SetLabelSize(0.05);
        gr->GetXaxis()->SetTitleOffset(1.4);
        gr->GetYaxis()->SetLabelSize(0.05);
        gr->GetXaxis()->SetTitle("#scale[1.8]{#font[62]{Time (xSampling Time)}}");
        gr->GetYaxis()->SetTitle("#scale[1.8]{#font[62]{H (%)}}");
        gr->Draw("AP");

        
        canvas_arduino.SaveAs("arduino.png");
    

        
    
    
    
}