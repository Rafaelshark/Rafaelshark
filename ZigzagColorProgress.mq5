//+------------------------------------------------------------------+
//|                                        ZigzagColorProgress.mq5   |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
//--- indicator settings
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_ZIGZAG
#property indicator_color1  clrDodgerBlue,clrRed
//--- input parameters
input int InpDepth     =12;  // Depth
input int InpDeviation =5;   // Deviation
input int InpBackstep  =3;   // Back Step
input int InpLineWidth =3;   // Line Width (1-5)
input bool InpShowPanel=true; // Show Progress Panel
input int InpPanelX    =20;  // Panel X Position
input int InpPanelY    =30;  // Panel Y Position
input int InpPanelWidth=500; // Panel Width
input int InpPanelHeight=250;// Panel Height
input int InpLineSpacing=20; // Vertical Line Spacing
input int InpColumnSpacing=250; // Horizontal Spacing (Label to Value)
input color InpPanelColor=clrBlack; // Panel Background Color
input color InpTextColor=16777215; // Text Color
input int InpFontSize  =9;   // Font Size

//--- Fibonacci inputs
input bool InpShowFibo=true; // Show Fibonacci Retracement
input color InpFiboColor=clrGold; // Fibonacci Lines Color
input ENUM_LINE_STYLE InpFiboStyle=STYLE_DOT; // Fibonacci Line Style
input int InpFiboWidth=1; // Fibonacci Line Width
input bool InpShowFiboLabels=true; // Show Fibonacci Labels

//--- indicator buffers
double ZigzagPeakBuffer[];
double ZigzagBottomBuffer[];
double HighMapBuffer[];
double LowMapBuffer[];
double ColorBuffer[];

int ExtRecalc=3; // recounting's depth

enum EnSearchMode
  {
   Extremum=0, // searching for the first extremum
   Peak=1,     // searching for the next ZigZag peak
   Bottom=-1   // searching for the next ZigZag bottom
  };

//--- Global variables for panel
string objPrefix="ZZProgress_";
string fiboPrefix="ZZFibo_";

//--- Fibonacci levels
double fiboLevels[]={0.0, 0.236, 0.382, 0.50, 0.618, 0.692, 0.786, 1.0, 1.10};
string fiboLabels[]={"0.0%", "23.6%", "38.2%", "50.0%", "61.8%", "69.2%", "78.6%", "100.0%", "110.0%"};

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,ZigzagPeakBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,ZigzagBottomBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,ColorBuffer,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(3,HighMapBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(4,LowMapBuffer,INDICATOR_CALCULATIONS);
//--- set accuracy
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
//--- set line width
   PlotIndexSetInteger(0,PLOT_LINE_WIDTH,InpLineWidth);
//--- name for DataWindow and indicator subwindow label
   string short_name=StringFormat("ZigZagProgress(%d,%d,%d)",InpDepth,InpDeviation,InpBackstep);
   IndicatorSetString(INDICATOR_SHORTNAME,short_name);
   PlotIndexSetString(0,PLOT_LABEL,short_name);
//--- set an empty value
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0.0);

//--- Create panel
   if(InpShowPanel)
      CreatePanel();

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Delete all panel objects
   ObjectsDeleteAll(0,objPrefix);
//--- Delete all fibonacci objects
   ObjectsDeleteAll(0,fiboPrefix);
   ChartRedraw();
  }
//+------------------------------------------------------------------+
//| ZigZag calculation                                               |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(rates_total<100)
      return(0);
//---
   int    i,start=0;
   int    extreme_counter=0,extreme_search=Extremum;
   int    shift,back=0,last_high_pos=0,last_low_pos=0;
   double val=0,res=0;
   double cur_low=0,cur_high=0,last_high=0,last_low=0;
//--- initializing
   if(prev_calculated==0)
     {
      ArrayInitialize(ZigzagPeakBuffer,0.0);
      ArrayInitialize(ZigzagBottomBuffer,0.0);
      ArrayInitialize(HighMapBuffer,0.0);
      ArrayInitialize(LowMapBuffer,0.0);
      //--- start calculation from bar number InpDepth
      start=InpDepth-1;
     }
//--- ZigZag was already calculated before
   if(prev_calculated>0)
     {
      i=rates_total-1;
      //--- searching for the third extremum from the last uncompleted bar
      while(extreme_counter<ExtRecalc && i>rates_total-100)
        {
         res=(ZigzagPeakBuffer[i]+ZigzagBottomBuffer[i]);
         //---
         if(res!=0)
            extreme_counter++;
         i--;
        }
      i++;
      start=i;
      //--- what type of exremum we search for
      if(LowMapBuffer[i]!=0)
        {
         cur_low=LowMapBuffer[i];
         extreme_search=Peak;
        }
      else
        {
         cur_high=HighMapBuffer[i];
         extreme_search=Bottom;
        }
      //--- clear indicator values
      for(i=start+1; i<rates_total && !IsStopped(); i++)
        {
         ZigzagPeakBuffer[i]  =0.0;
         ZigzagBottomBuffer[i]=0.0;
         LowMapBuffer[i]      =0.0;
         HighMapBuffer[i]     =0.0;
        }
     }
//--- searching for high and low extremes
   for(shift=start; shift<rates_total && !IsStopped(); shift++)
     {
      //--- low
      val=Lowest(low,InpDepth,shift);
      if(val==last_low)
         val=0.0;
      else
        {
         last_low=val;
         if((low[shift]-val)>(InpDeviation*_Point))
            val=0.0;
         else
           {
            for(back=InpBackstep; back>=1; back--)
              {
               res=LowMapBuffer[shift-back];
               //---
               if((res!=0) && (res>val))
                  LowMapBuffer[shift-back]=0.0;
              }
           }
        }
      if(low[shift]==val)
         LowMapBuffer[shift]=val;
      else
         LowMapBuffer[shift]=0.0;
      //--- high
      val=Highest(high,InpDepth,shift);
      if(val==last_high)
         val=0.0;
      else
        {
         last_high=val;
         if((val-high[shift])>(InpDeviation*_Point))
            val=0.0;
         else
           {
            for(back=InpBackstep; back>=1; back--)
              {
               res=HighMapBuffer[shift-back];
               //---
               if((res!=0) && (res<val))
                  HighMapBuffer[shift-back]=0.0;
              }
           }
        }
      if(high[shift]==val)
         HighMapBuffer[shift]=val;
      else
         HighMapBuffer[shift]=0.0;
     }
//--- set last values
   if(extreme_search==0) // undefined values
     {
      last_low=0;
      last_high=0;
     }
   else
     {
      last_low=cur_low;
      last_high=cur_high;
     }
//--- final selection of extreme points for ZigZag
   for(shift=start; shift<rates_total && !IsStopped(); shift++)
     {
      res=0.0;
      switch(extreme_search)
        {
         case Extremum:
            if(last_low==0 && last_high==0)
              {
               if(HighMapBuffer[shift]!=0)
                 {
                  last_high=high[shift];
                  last_high_pos=shift;
                  extreme_search=-1;
                  ZigzagPeakBuffer[shift]=last_high;
                  ColorBuffer[shift]=0;
                  res=1;
                 }
               if(LowMapBuffer[shift]!=0)
                 {
                  last_low=low[shift];
                  last_low_pos=shift;
                  extreme_search=1;
                  ZigzagBottomBuffer[shift]=last_low;
                  ColorBuffer[shift]=1;
                  res=1;
                 }
              }
            break;
         case Peak:
            if(LowMapBuffer[shift]!=0.0 && LowMapBuffer[shift]<last_low &&
               HighMapBuffer[shift]==0.0)
              {
               ZigzagBottomBuffer[last_low_pos]=0.0;
               last_low_pos=shift;
               last_low=LowMapBuffer[shift];
               ZigzagBottomBuffer[shift]=last_low;
               ColorBuffer[shift]=1;
               res=1;
              }
            if(HighMapBuffer[shift]!=0.0 && LowMapBuffer[shift]==0.0)
              {
               last_high=HighMapBuffer[shift];
               last_high_pos=shift;
               ZigzagPeakBuffer[shift]=last_high;
               ColorBuffer[shift]=0;
               extreme_search=Bottom;
               res=1;
              }
            break;
         case Bottom:
            if(HighMapBuffer[shift]!=0.0 &&
               HighMapBuffer[shift]>last_high &&
               LowMapBuffer[shift]==0.0)
              {
               ZigzagPeakBuffer[last_high_pos]=0.0;
               last_high_pos=shift;
               last_high=HighMapBuffer[shift];
               ZigzagPeakBuffer[shift]=last_high;
               ColorBuffer[shift]=0;
              }
            if(LowMapBuffer[shift]!=0.0 && HighMapBuffer[shift]==0.0)
              {
               last_low=LowMapBuffer[shift];
               last_low_pos=shift;
               ZigzagBottomBuffer[shift]=last_low;
               ColorBuffer[shift]=1;
               extreme_search=Peak;
              }
            break;
         default:
            return(rates_total);
        }
     }

//--- Draw Fibonacci Retracement
   if(InpShowFibo)
      DrawFibonacciRetracement(rates_total, time);

//--- Update progress panel
   if(InpShowPanel)
      UpdatePanel(rates_total, last_high_pos, last_low_pos, last_high, last_low,
                  high, low, extreme_search);

//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| Find last completed leg                                          |
//+------------------------------------------------------------------+
bool FindLastCompletedLeg(int rates_total,
                          int &leg_start_pos, int &leg_end_pos,
                          double &leg_start_price, double &leg_end_price,
                          int &leg_color)
  {
   int extremes_found=0;
   int positions[3];
   double prices[3];
   int colors[3];

//--- Search from the most recent bar backwards
   for(int i=rates_total-1; i>=0 && extremes_found<3; i--)
     {
      double peak_val=ZigzagPeakBuffer[i];
      double bottom_val=ZigzagBottomBuffer[i];

      if(peak_val!=0.0)
        {
         positions[extremes_found]=i;
         prices[extremes_found]=peak_val;
         colors[extremes_found]=0; // Blue (Peak)
         extremes_found++;
        }
      else if(bottom_val!=0.0)
        {
         positions[extremes_found]=i;
         prices[extremes_found]=bottom_val;
         colors[extremes_found]=1; // Red (Bottom)
         extremes_found++;
        }
     }

//--- Need at least 3 extremes to have a completed leg
   if(extremes_found<3)
      return false;

//--- The last completed leg is between positions[1] and positions[2]
//--- (positions[0] is the current incomplete leg endpoint)
   leg_start_pos=positions[2];
   leg_end_pos=positions[1];
   leg_start_price=prices[2];
   leg_end_price=prices[1];

//--- Determine leg color (direction)
//--- If going from bottom to peak = Blue (bullish)
//--- If going from peak to bottom = Red (bearish)
   if(colors[2]==1 && colors[1]==0)
      leg_color=0; // Blue - upward leg (from bottom to peak)
   else if(colors[2]==0 && colors[1]==1)
      leg_color=1; // Red - downward leg (from peak to bottom)
   else
      return false; // Invalid leg

   return true;
  }
//+------------------------------------------------------------------+
//| Draw Fibonacci Retracement                                       |
//+------------------------------------------------------------------+
void DrawFibonacciRetracement(int rates_total, const datetime &time[])
  {
   int leg_start_pos, leg_end_pos;
   double leg_start_price, leg_end_price;
   int leg_color;

//--- Find the last completed leg
   if(!FindLastCompletedLeg(rates_total, leg_start_pos, leg_end_pos,
                            leg_start_price, leg_end_price, leg_color))
     {
      //--- No completed leg found, delete all fibonacci objects
      ObjectsDeleteAll(0,fiboPrefix);
      return;
     }

//--- Calculate Fibonacci levels
   double range=leg_end_price-leg_start_price;
   datetime start_time=time[leg_start_pos];
   datetime end_time=time[leg_end_pos];

//--- Draw each Fibonacci level
   for(int i=0; i<ArraySize(fiboLevels); i++)
     {
      double level_price;

      //--- Blue leg (upward): 100% at bottom, 0% at top
      if(leg_color==0)
        {
         level_price=leg_start_price+range*(1.0-fiboLevels[i]);
        }
      //--- Red leg (downward): 100% at top, 0% at bottom
      else
        {
         level_price=leg_start_price+range*fiboLevels[i];
        }

      //--- Create or update trend line
      string line_name=fiboPrefix+"Line_"+IntegerToString(i);

      if(ObjectFind(0,line_name)<0)
        {
         ObjectCreate(0,line_name,OBJ_TREND,0,start_time,level_price,end_time,level_price);
         ObjectSetInteger(0,line_name,OBJPROP_COLOR,InpFiboColor);
         ObjectSetInteger(0,line_name,OBJPROP_STYLE,InpFiboStyle);
         ObjectSetInteger(0,line_name,OBJPROP_WIDTH,InpFiboWidth);
         ObjectSetInteger(0,line_name,OBJPROP_RAY_RIGHT,true);
         ObjectSetInteger(0,line_name,OBJPROP_RAY_LEFT,false);
         ObjectSetInteger(0,line_name,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,line_name,OBJPROP_BACK,true);
        }
      else
        {
         ObjectMove(0,line_name,0,start_time,level_price);
         ObjectMove(0,line_name,1,end_time,level_price);
        }

      //--- Create or update label
      if(InpShowFiboLabels)
        {
         string label_name=fiboPrefix+"Label_"+IntegerToString(i);

         if(ObjectFind(0,label_name)<0)
           {
            ObjectCreate(0,label_name,OBJ_TEXT,0,end_time,level_price);
            ObjectSetString(0,label_name,OBJPROP_FONT,"Arial");
            ObjectSetInteger(0,label_name,OBJPROP_FONTSIZE,8);
            ObjectSetInteger(0,label_name,OBJPROP_COLOR,InpFiboColor);
            ObjectSetInteger(0,label_name,OBJPROP_ANCHOR,ANCHOR_LEFT);
            ObjectSetInteger(0,label_name,OBJPROP_SELECTABLE,false);
            ObjectSetInteger(0,label_name,OBJPROP_BACK,true);
           }

         string label_text=fiboLabels[i]+" ("+DoubleToString(level_price,_Digits)+")";
         ObjectSetString(0,label_name,OBJPROP_TEXT,label_text);
         ObjectMove(0,label_name,0,end_time,level_price);
        }
     }
  }
//+------------------------------------------------------------------+
//| Create progress panel                                            |
//+------------------------------------------------------------------+
void CreatePanel()
  {
   int x=InpPanelX;
   int y=InpPanelY;
   int width=InpPanelWidth;
   int height=InpPanelHeight;

//--- Background
   ObjectCreate(0,objPrefix+"BG",OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,objPrefix+"BG",OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,objPrefix+"BG",OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,objPrefix+"BG",OBJPROP_XSIZE,width);
   ObjectSetInteger(0,objPrefix+"BG",OBJPROP_YSIZE,height);
   ObjectSetInteger(0,objPrefix+"BG",OBJPROP_BGCOLOR,InpPanelColor);
   ObjectSetInteger(0,objPrefix+"BG",OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,objPrefix+"BG",OBJPROP_COLOR,clrGray); // Cor da borda
   ObjectSetInteger(0,objPrefix+"BG",OBJPROP_WIDTH,2); // Espessura da borda
   ObjectSetInteger(0,objPrefix+"BG",OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,objPrefix+"BG",OBJPROP_BACK,true);

//--- Title
   ObjectCreate(0,objPrefix+"Title",OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,objPrefix+"Title",OBJPROP_XDISTANCE,x+10);
   ObjectSetInteger(0,objPrefix+"Title",OBJPROP_YDISTANCE,y+5);
   ObjectSetInteger(0,objPrefix+"Title",OBJPROP_COLOR,clrYellow);
   ObjectSetInteger(0,objPrefix+"Title",OBJPROP_FONTSIZE,InpFontSize+1);
   ObjectSetString(0,objPrefix+"Title",OBJPROP_TEXT,"═══ PROGRESSO ZIGZAG ═══");
   ObjectSetString(0,objPrefix+"Title",OBJPROP_FONT,"Arial Bold");

//--- Labels
   string labels[]={"Status:","Procurando:","Último Extremo:","Barras Desde:","Progresso Tempo:","Movimento Preço:","Progresso Movimento:","Geral:"};

   for(int i=0; i<ArraySize(labels); i++)
     {
      ObjectCreate(0,objPrefix+"Label"+IntegerToString(i),OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,objPrefix+"Label"+IntegerToString(i),OBJPROP_XDISTANCE,x+10);
      ObjectSetInteger(0,objPrefix+"Label"+IntegerToString(i),OBJPROP_YDISTANCE,y+30+i*InpLineSpacing);
      ObjectSetInteger(0,objPrefix+"Label"+IntegerToString(i),OBJPROP_COLOR,InpTextColor);
      ObjectSetInteger(0,objPrefix+"Label"+IntegerToString(i),OBJPROP_FONTSIZE,InpFontSize);
      ObjectSetString(0,objPrefix+"Label"+IntegerToString(i),OBJPROP_TEXT,labels[i]);
      ObjectSetString(0,objPrefix+"Label"+IntegerToString(i),OBJPROP_FONT,"Courier New");
     }

   ChartRedraw();
  }
//+------------------------------------------------------------------+
//| Update progress panel                                            |
//+------------------------------------------------------------------+
void UpdatePanel(int rates_total, int last_high_pos, int last_low_pos,
                 double last_high, double last_low,
                 const double &high[], const double &low[],
                 int extreme_search)
  {
   if(!InpShowPanel)
      return;

   int x=InpPanelX+InpColumnSpacing;
   int y=InpPanelY+30;

//--- Calculate progress
   int bars_since=0;
   double time_progress=0;
   double price_move=0;
   double move_progress=0;
   double overall_progress=0;
   string searching="";
   string status="Procurando...";
   color status_color=clrYellow;

   int current_bar=rates_total-1;

   if(extreme_search==Peak) // Searching for Peak (Topo)
     {
      searching="TOPO ▲";
      bars_since=current_bar-last_low_pos;

      // Time progress based on Depth
      time_progress=MathMin(100.0, (bars_since*100.0)/InpDepth);

      // Price movement from last bottom
      price_move=(high[current_bar]-last_low)/_Point;
      double required_move=InpDeviation;
      move_progress=MathMin(100.0, (price_move/required_move)*100.0);

      // Overall progress (average of time and price)
      overall_progress=(time_progress+move_progress)/2.0;

      // Status
      if(overall_progress>=100.0)
        {
         status="Pronto para Confirmar!";
         status_color=clrLime;
        }
      else if(overall_progress>=75.0)
        {
         status="Quase lá...";
         status_color=clrOrange;
        }
     }
   else if(extreme_search==Bottom) // Searching for Bottom (Fundo)
     {
      searching="FUNDO ▼";
      bars_since=current_bar-last_high_pos;

      // Time progress based on Depth
      time_progress=MathMin(100.0, (bars_since*100.0)/InpDepth);

      // Price movement from last peak
      price_move=(last_high-low[current_bar])/_Point;
      double required_move=InpDeviation;
      move_progress=MathMin(100.0, (price_move/required_move)*100.0);

      // Overall progress
      overall_progress=(time_progress+move_progress)/2.0;

      // Status
      if(overall_progress>=100.0)
        {
         status="Pronto para Confirmar!";
         status_color=clrLime;
        }
      else if(overall_progress>=75.0)
        {
         status="Quase lá...";
         status_color=clrOrange;
        }
     }
   else // Extremum - first search
     {
      searching="Primeiro Extremo";
      status="Inicializando...";
      status_color=clrGray;
     }

//--- Update values
   string values[8];
   values[0]=status;
   values[1]=searching;
   values[2]=(extreme_search==Peak) ? StringFormat("%."+IntegerToString(_Digits)+"f",last_low) :
                                       StringFormat("%."+IntegerToString(_Digits)+"f",last_high);
   values[3]=IntegerToString(bars_since)+" barras";
   values[4]=StringFormat("%.1f%%",time_progress);
   values[5]=StringFormat("%.1f pontos",price_move);
   values[6]=StringFormat("%.1f%%",move_progress);
   values[7]=StringFormat("%.1f%%",overall_progress);

   color colors[]={status_color,clrWhite,clrCyan,clrWhite,clrAqua,clrWhite,clrAqua,clrYellow};

   for(int i=0; i<8; i++)
     {
      string objName=objPrefix+"Value"+IntegerToString(i);

      if(ObjectFind(0,objName)<0)
        {
         ObjectCreate(0,objName,OBJ_LABEL,0,0,0);
         ObjectSetInteger(0,objName,OBJPROP_XDISTANCE,x);
         ObjectSetInteger(0,objName,OBJPROP_YDISTANCE,y+i*InpLineSpacing);
         ObjectSetInteger(0,objName,OBJPROP_FONTSIZE,InpFontSize);
         ObjectSetString(0,objName,OBJPROP_FONT,"Courier New");
        }

      ObjectSetString(0,objName,OBJPROP_TEXT,values[i]);
      ObjectSetInteger(0,objName,OBJPROP_COLOR,colors[i]);
     }

//--- Progress bars
   DrawProgressBar(InpPanelX+10, InpPanelY+InpPanelHeight-20, InpPanelWidth-20, 10, time_progress, "Time");

   ChartRedraw();
  }
//+------------------------------------------------------------------+
//| Draw progress bar                                                |
//+------------------------------------------------------------------+
void DrawProgressBar(int x, int y, int width, int height, double progress, string label)
  {
   string objBG=objPrefix+"ProgBG_"+label;
   string objFill=objPrefix+"ProgFill_"+label;

//--- Background
   if(ObjectFind(0,objBG)<0)
     {
      ObjectCreate(0,objBG,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,objBG,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,objBG,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,objBG,OBJPROP_XSIZE,width);
      ObjectSetInteger(0,objBG,OBJPROP_YSIZE,height);
      ObjectSetInteger(0,objBG,OBJPROP_BGCOLOR,clrBlack);
      ObjectSetInteger(0,objBG,OBJPROP_BORDER_TYPE,BORDER_FLAT);
     }

//--- Fill
   int fill_width=(int)((width-4)*progress/100.0);
   color fill_color=clrGreen;
   if(progress>=100) fill_color=clrLime;
   else if(progress>=75) fill_color=clrYellow;
   else if(progress>=50) fill_color=clrOrange;

   if(ObjectFind(0,objFill)<0)
     {
      ObjectCreate(0,objFill,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,objFill,OBJPROP_XDISTANCE,x+2);
      ObjectSetInteger(0,objFill,OBJPROP_YDISTANCE,y+2);
      ObjectSetInteger(0,objFill,OBJPROP_BGCOLOR,fill_color);
      ObjectSetInteger(0,objFill,OBJPROP_BORDER_TYPE,BORDER_FLAT);
     }

   ObjectSetInteger(0,objFill,OBJPROP_XSIZE,fill_width);
   ObjectSetInteger(0,objFill,OBJPROP_YSIZE,height-4);
   ObjectSetInteger(0,objFill,OBJPROP_BGCOLOR,fill_color);
  }
//+------------------------------------------------------------------+
//| Get highest value for range                                      |
//+------------------------------------------------------------------+
double Highest(const double&array[],int count,int start)
  {
   double res=array[start];
//---
   for(int i=start-1; i>start-count && i>=0; i--)
      if(res<array[i])
         res=array[i];
//---
   return(res);
  }
//+------------------------------------------------------------------+
//| Get lowest value for range                                       |
//+------------------------------------------------------------------+
double Lowest(const double&array[],int count,int start)
  {
   double res=array[start];
//---
   for(int i=start-1; i>start-count && i>=0; i--)
      if(res>array[i])
         res=array[i];
//---
   return(res);
  }
//+------------------------------------------------------------------+
