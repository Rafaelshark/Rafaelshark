//+------------------------------------------------------------------+
//|                                         ZigzagColorProgress.mq5 |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                              https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
//--- indicator settings
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_ZIGZAG
#property indicator_color1  clrDodgerBlue,clrRed,clrYellow
//--- input parameters
input int InpDepth        =12;    // Depth
input int InpDeviation    =5;     // Deviation
input int InpBackstep     =3;     // Back Step
input int InpLineWidth    =3;     // Line Width (1-5)
input bool InpShowPanel   =true;  // Show Progress Panel
input int InpPanelX       =20;    // Panel X Position
input int InpPanelY       =30;    // Panel Y Position
input int InpPanelWidth   =500;   // Panel Width
input int InpPanelHeight  =250;   // Panel Height
input int InpLineSpacing  =20;    // Vertical Line Spacing
input int InpColumnSpacing=250;   // Horizontal Spacing (Label to Value)
input color InpPanelColor =clrBlack; // Panel Background Color
input color InpTextColor  =16777215; // Text Color
input int InpFontSize     =9;     // Font Size

//--- indicator buffers
double ZigzagPeakBuffer[];
double ZigzagBottomBuffer[];
double HighMapBuffer[];
double LowMapBuffer[];
double ColorBuffer[];

int ExtRecalc=3; // recounting's depth

enum EnSearchMode
  {
   Extremum=0,  // searching for the first extremum
   Peak=1,      // searching for the next ZigZag peak
   Bottom=-1    // searching for the next ZigZag bottom
  };

//--- Global variables for panel
string objPrefix="ZZProgress_";

//--- Global variables for trend break detection
struct ZigZagPoint
  {
   double            value;
   int               position;
   int               type; // 1 = Peak (Topo), -1 = Bottom (Fundo)
  };

ZigZagPoint g_points[4]; // Armazena os últimos 4 pontos
int g_pointCount=0;      // Contador de pontos válidos

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

//--- Initialize points array
   for(int i=0; i<4; i++)
     {
      g_points[i].value=0;
      g_points[i].position=0;
      g_points[i].type=0;
     }

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
   ChartRedraw();
  }
//+------------------------------------------------------------------+
//| Add point to tracking array                                      |
//+------------------------------------------------------------------+
void AddPoint(double value, int position, int type)
  {
//--- Shift existing points
   for(int i=3; i>0; i--)
     {
      g_points[i]=g_points[i-1];
     }
//--- Add new point at position 0 (most recent)
   g_points[0].value=value;
   g_points[0].position=position;
   g_points[0].type=type;

//--- Increment counter (max 4)
   if(g_pointCount<4)
      g_pointCount++;
  }
//+------------------------------------------------------------------+
//| Check for uptrend break                                          |
//+------------------------------------------------------------------+
bool CheckUptrendBreak()
  {
   if(g_pointCount<4)
      return false;

//--- Padrão 1: Fundo -> Topo -> Fundo -> Topo
//--- Verifica se temos: Bottom(3) -> Peak(2) -> Bottom(1) -> Peak(0)
   if(g_points[3].type==-1 && g_points[2].type==1 &&
      g_points[1].type==-1 && g_points[0].type==1)
     {
      //--- Verifica se estava em tendência de alta
      //--- Fundo[1] > Fundo[3] E Topo[2] crescente
      if(g_points[1].value>g_points[3].value)
        {
         //--- Quebra: Topo[0] <= Topo[2] (topo atual menor ou igual ao anterior)
         if(g_points[0].value<=g_points[2].value)
           {
            return true;
           }
        }
     }

//--- Padrão 2: Topo -> Fundo -> Topo -> Fundo
//--- Verifica se temos: Peak(3) -> Bottom(2) -> Peak(1) -> Bottom(0)
   if(g_points[3].type==1 && g_points[2].type==-1 &&
      g_points[1].type==1 && g_points[0].type==-1)
     {
      //--- Verifica se estava em tendência de alta
      //--- Topo[1] > Topo[3] E Fundo[2] crescente
      if(g_points[1].value>g_points[3].value)
        {
         //--- Quebra: Fundo[0] <= Fundo[2] (fundo atual menor ou igual ao anterior)
         if(g_points[0].value<=g_points[2].value)
           {
            return true;
           }
        }
     }

   return false;
  }
//+------------------------------------------------------------------+
//| ZigZag calculation                                                |
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
   int i,start=0;
   int extreme_counter=0,extreme_search=Extremum;
   int shift,back=0,last_high_pos=0,last_low_pos=0;
   double val=0,res=0;
   double cur_low=0,cur_high=0,last_high=0,last_low=0;
//--- initializing
   if(prev_calculated==0)
     {
      ArrayInitialize(ZigzagPeakBuffer,0.0);
      ArrayInitialize(ZigzagBottomBuffer,0.0);
      ArrayInitialize(HighMapBuffer,0.0);
      ArrayInitialize(LowMapBuffer,0.0);
      ArrayInitialize(ColorBuffer,0.0);
      //--- Reset point tracking
      g_pointCount=0;
      for(int j=0; j<4; j++)
        {
         g_points[j].value=0;
         g_points[j].position=0;
         g_points[j].type=0;
        }
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
         ZigzagPeakBuffer[i] =0.0;
         ZigzagBottomBuffer[i]=0.0;
         LowMapBuffer[i]     =0.0;
         HighMapBuffer[i]    =0.0;
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
                  AddPoint(last_high,shift,1); // Adiciona ponto Topo
                  res=1;
                 }
               if(LowMapBuffer[shift]!=0)
                 {
                  last_low=low[shift];
                  last_low_pos=shift;
                  extreme_search=1;
                  ZigzagBottomBuffer[shift]=last_low;
                  ColorBuffer[shift]=1;
                  AddPoint(last_low,shift,-1); // Adiciona ponto Fundo
                  res=1;
                 }
              }
            break;
         case Peak:
            if(LowMapBuffer[shift]!=0.0 && LowMapBuffer[shift]<last_low && HighMapBuffer[shift]==0.0)
              {
               ZigzagBottomBuffer[last_low_pos]=0.0;
               last_low_pos=shift;
               last_low=LowMapBuffer[shift];
               ZigzagBottomBuffer[shift]=last_low;
               ColorBuffer[shift]=1;
               AddPoint(last_low,shift,-1); // Adiciona ponto Fundo
               res=1;
              }
            if(HighMapBuffer[shift]!=0.0 && LowMapBuffer[shift]==0.0)
              {
               last_high=HighMapBuffer[shift];
               last_high_pos=shift;
               ZigzagPeakBuffer[shift]=last_high;
               //--- Verifica quebra de tendência
               AddPoint(last_high,shift,1); // Adiciona ponto Topo
               if(CheckUptrendBreak())
                  ColorBuffer[shift]=2; // Amarelo - Quebra de tendência
               else
                  ColorBuffer[shift]=0; // Azul normal
               extreme_search=Bottom;
               res=1;
              }
            break;
         case Bottom:
            if(HighMapBuffer[shift]!=0.0 && HighMapBuffer[shift]>last_high && LowMapBuffer[shift]==0.0)
              {
               ZigzagPeakBuffer[last_high_pos]=0.0;
               last_high_pos=shift;
               last_high=HighMapBuffer[shift];
               ZigzagPeakBuffer[shift]=last_high;
               ColorBuffer[shift]=0;
               AddPoint(last_high,shift,1); // Adiciona ponto Topo
              }
            if(LowMapBuffer[shift]!=0.0 && HighMapBuffer[shift]==0.0)
              {
               last_low=LowMapBuffer[shift];
               last_low_pos=shift;
               ZigzagBottomBuffer[shift]=last_low;
               //--- Verifica quebra de tendência
               AddPoint(last_low,shift,-1); // Adiciona ponto Fundo
               if(CheckUptrendBreak())
                  ColorBuffer[shift]=2; // Amarelo - Quebra de tendência
               else
                  ColorBuffer[shift]=1; // Vermelho normal
               extreme_search=Peak;
              }
            break;
         default:
            return(rates_total);
        }
     }

//--- Update progress panel
   if(InpShowPanel)
      UpdatePanel(rates_total, last_high_pos, last_low_pos, last_high, last_low, high, low, extreme_search);

//--- return value of prev_calculated for next call
   return(rates_total);
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
   ObjectSetInteger(0,objPrefix+"BG",OBJPROP_COLOR,clrGray);
   ObjectSetInteger(0,objPrefix+"BG",OBJPROP_WIDTH,2);
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
   values[2]=(extreme_search==Peak) ? StringFormat("%."+IntegerToString(_Digits)+"f",last_low) : StringFormat("%."+IntegerToString(_Digits)+"f",last_high);
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
   if(progress>=100)
      fill_color=clrLime;
   else if(progress>=75)
      fill_color=clrYellow;
   else if(progress>=50)
      fill_color=clrOrange;

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
