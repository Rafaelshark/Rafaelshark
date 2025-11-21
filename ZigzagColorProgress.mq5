//+------------------------------------------------------------------+
//|                                          ZigzagColorProgress.mq5 |
//|                                  Copyright 2000-2025, MetaQuotes Ltd. |
//|                                              https://www.mql5.com |
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
input int InpDepth           =12;       // Depth
input int InpDeviation       =5;        // Deviation
input int InpBackstep        =3;        // Back Step
input int InpLineWidth       =3;        // Line Width (1-5)
input bool InpShowPanel      =true;     // Show Progress Panel
input int InpPanelX          =20;       // Panel X Position
input int InpPanelY          =30;       // Panel Y Position
input int InpPanelWidth      =500;      // Panel Width
input int InpPanelHeight     =250;      // Panel Height
input int InpLineSpacing     =20;       // Vertical Line Spacing
input int InpColumnSpacing   =250;      // Horizontal Spacing (Label to Value)
input color InpPanelColor    =clrBlack; // Panel Background Color
input color InpTextColor     =16777215; // Text Color
input int InpFontSize        =9;        // Font Size

//--- Fibonacci inputs
input bool InpShowFibo           =true;         // Show Fibonacci Retracement
input color InpFiboColor         =clrBlack;     // Fibonacci Lines Color
input ENUM_LINE_STYLE InpFiboStyle=STYLE_DOT;   // Fibonacci Line Style
input int InpFiboWidth           =1;            // Fibonacci Line Width
input bool InpShowFiboLabels     =true;         // Show Fibonacci Labels

//--- Square inputs
input bool InpShowSquare         =true;         // Show Square
input int InpLegsBack            =0;            // Legs Back (0=current, 1=1 leg back, 2=2 legs back)
input int InpLegType             =2;            // Leg Type (0=Bullish Only, 1=Bearish Only, 2=Both - Default)
input double InpActivationLevel  =0.692;        // Activation Level (0.0 to 1.10)
input int InpSquareHeight        =400;          // Square Height (points)
input int InpSquareWidth         =10;           // Square Width (candles)
input color InpSquareColor       =clrBlack;     // Square Color
input int InpSquareWidth_Line    =2;            // Square Line Width
input int InpEntryLimit          =250;          // Entry Limit (points from square breakout level)
input int InpTakeProfit          =500;          // Take Profit (points from candle close)
input int InpStopLoss            =550;          // Stop Loss (points from entry)

//--- indicator buffers
double ZigzagPeakBuffer[];
double ZigzagBottomBuffer[];
double HighMapBuffer[];
double LowMapBuffer[];
double ColorBuffer[];

int ExtRecalc=3;  // recounting's depth

enum EnSearchMode
  {
   Extremum=0,    // searching for the first extremum
   Peak=1,        // searching for the next ZigZag peak
   Bottom=-1      // searching for the next ZigZag bottom
  };

//--- Global variables for panel
string objPrefix="ZZProgress_";
string fiboPrefix="ZZFibo_";
string squarePrefix="ZZSquare_";

//--- Fibonacci levels (will be adjusted based on activation level)
double fiboLevels[];
string fiboLabels[];

//--- Square state variables
enum SquareState
  {
   SQUARE_NONE,                     // No square
   SQUARE_WAITING,                  // Waiting for activation level touch
   SQUARE_ACTIVE,                   // Active after touch, waiting for breakout or 110% breach
   SQUARE_BREAKOUT_WAITING_TAKE,    // Breakout occurred, waiting for take activation
   SQUARE_TAKE_ACTIVE,              // Take activated, monitoring take/stop
   SQUARE_LOCKED                    // Locked due to entry limit violation or 110% breach or take/stop hit
  };

SquareState squareState=SQUARE_NONE;
datetime squareStartTime=0;
int squareStartBar=0;
double squareBasePrice=0;    // For bullish: base, for bearish: top
int squareDirection=0;       // 1=bullish (100% at bottom), -1=bearish (100% at top)
double fiboActivationPrice=0;   // Dynamic activation level price
double fibo110Price=0;
double fibo100Price=0;
double fibo0Price=0;
double entryPrice=0;           // Entry price when breakout occurs
double entryLimitPrice=0;
double takeProfitPrice=0;
double stopLossPrice=0;
int currentLegEndPos=0;        // To track if leg changed
bool squareUsedForCurrentLeg=false; // Track if square was already created for this leg
bool squareLockedAt110=false;  // Track if square is locked at 110% level
int last110CheckBar=-1;        // Track last bar checked for 110% to avoid re-checking

//--- New variables for take activation
bool takeActivated=false;      // Indicates if take has been activated (candle closed beyond top)
double takeActivationClosePrice=0; // Close price of the candle that activated the take
bool hitTakeFirst=false;       // Indicates if take was hit first (for green color)
bool hitStopFirst=false;       // Indicates if stop was hit first (for red color)
int breakoutBar=-1;            // Bar where breakout occurred
bool activationTouched=false;  // Track if price touched activation level for current leg
int breakoutDetectedAtBar=-1; // Bar where breakout was detected (to prevent retroactive entry checks)
int activationTouchBar=-1;     // Bar where price touched the 69.2% activation level

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

//--- Initialize Fibonacci levels
   InitializeFibonacciLevels();

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
//--- Delete all square objects
   ObjectsDeleteAll(0,squarePrefix);
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
            if(LowMapBuffer[shift]!=0.0 && LowMapBuffer[shift]<last_low && HighMapBuffer[shift]==0.0)
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
            if(HighMapBuffer[shift]!=0.0 && HighMapBuffer[shift]>last_high && LowMapBuffer[shift]==0.0)
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

//--- Draw Fibonacci Retracement and manage square
   int leg_start_pos, leg_end_pos;
   double leg_start_price, leg_end_price;
   int leg_color;
   bool has_valid_leg=FindLastCompletedLeg(rates_total,
                                            leg_start_pos, leg_end_pos,
                                            leg_start_price, leg_end_price,
                                            leg_color);

   if(InpShowFibo && has_valid_leg)
      DrawFibonacciRetracement(rates_total, time,
                               leg_start_pos, leg_end_pos,
                               leg_start_price, leg_end_price,
                               leg_color);
   else if(!has_valid_leg)
      ObjectsDeleteAll(0,fiboPrefix);

//--- Manage Square
   if(InpShowSquare && has_valid_leg)
      ManageSquare(rates_total, time, high, low, close,
                   leg_start_pos, leg_end_pos,
                   leg_start_price, leg_end_price,
                   leg_color);
   else if(!has_valid_leg && squareState!=SQUARE_NONE)
     {
      squareState=SQUARE_NONE;
      ObjectsDeleteAll(0,squarePrefix);
     }

//--- Update progress panel
   if(InpShowPanel)
      UpdatePanel(rates_total,
                  last_high_pos, last_low_pos,
                  last_high, last_low,
                  high, low,
                  extreme_search);

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
//--- Calculate how many extremes we need: 3 + 2*InpLegsBack
//--- For InpLegsBack=0: need 3 extremes (current leg)
//--- For InpLegsBack=1: need 5 extremes (1 leg back)
//--- For InpLegsBack=2: need 7 extremes (2 legs back)
   int required_extremes=3+2*InpLegsBack;
   int extremes_found=0;

//--- Dynamic arrays to store extremes
   int positions[];
   double prices[];
   int colors[];

   ArrayResize(positions,required_extremes);
   ArrayResize(prices,required_extremes);
   ArrayResize(colors,required_extremes);

//--- Search from the most recent bar backwards
   for(int i=rates_total-1; i>=0 && extremes_found<required_extremes; i--)
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

//--- Need at least required_extremes to have the desired leg
   if(extremes_found<required_extremes)
     {
      static int last_warning_extremes=-1;
      if(last_warning_extremes!=extremes_found)
        {
         Print("⚠️ PERNA IGNORADA - Extremos insuficientes: ", extremes_found, "/", required_extremes, " (InpLegsBack=", InpLegsBack, ")");
         last_warning_extremes=extremes_found;
        }
      return false;
     }

//--- Calculate indices for the desired leg
//--- For InpLegsBack=0: positions[2] and positions[1]
//--- For InpLegsBack=1: positions[4] and positions[3]
//--- For InpLegsBack=2: positions[6] and positions[5]
   int start_idx=2+2*InpLegsBack;
   int end_idx=1+2*InpLegsBack;

   leg_start_pos=positions[start_idx];
   leg_end_pos=positions[end_idx];
   leg_start_price=prices[start_idx];
   leg_end_price=prices[end_idx];
   int start_color=colors[start_idx];
   int end_color=colors[end_idx];

//--- Determine leg direction
//--- Bullish leg: starts from bottom (1) and ends at peak (0)
//--- Bearish leg: starts from peak (0) and ends at bottom (1)
   bool is_bullish=(start_color==1 && end_color==0); // Bottom to Peak
   bool is_bearish=(start_color==0 && end_color==1); // Peak to Bottom

//--- Apply leg type filter
   if(InpLegType==0) // Bullish Only
     {
      if(!is_bullish)
        {
         static datetime last_warning_time=0;
         datetime current_time=TimeCurrent();
         if(current_time!=last_warning_time)
           {
            Print("🔵 PERNA DE BAIXA IGNORADA - Parâmetro configurado para apenas pernadas de alta (InpLegType=0)");
            last_warning_time=current_time;
           }
         return false;
        }
     }
   else if(InpLegType==1) // Bearish Only
     {
      if(!is_bearish)
        {
         static datetime last_warning_time=0;
         datetime current_time=TimeCurrent();
         if(current_time!=last_warning_time)
           {
            Print("🔴 PERNA DE ALTA IGNORADA - Parâmetro configurado para apenas pernadas de baixa (InpLegType=1)");
            last_warning_time=current_time;
           }
         return false;
        }
     }
   // InpLegType==2: Both - no filter needed

//--- Set leg_color based on end point (for backward compatibility)
   leg_color=end_color;

//--- Validation: ensure we have a valid leg
   if(!is_bullish && !is_bearish)
     {
      Print("⚠️ ERRO - Perna inválida detectada: start_color=", start_color, ", end_color=", end_color);
      return false;
     }

//--- Debug info
   static int last_logged_end_pos=-1;
   if(last_logged_end_pos!=leg_end_pos)
     {
      string leg_type_str=is_bullish?"🔵 ALTA (Bullish)":"🔴 BAIXA (Bearish)";
      Print("✅ PERNA VÁLIDA ENCONTRADA - Tipo: ", leg_type_str,
            " | Início: ", leg_start_price, " | Fim: ", leg_end_price,
            " | InpLegType=", InpLegType);
      last_logged_end_pos=leg_end_pos;
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Lowest value over a depth starting from start_pos               |
//+------------------------------------------------------------------+
double Lowest(const double& array[], int depth, int start_pos)
  {
   if(start_pos-depth<0)
      depth=start_pos;
   double min=array[start_pos];
   for(int i=start_pos; i>start_pos-depth && i>=0; i--)
     {
      if(array[i]<min)
         min=array[i];
     }
   return(min);
  }
//+------------------------------------------------------------------+
//| Highest value over a depth starting from start_pos              |
//+------------------------------------------------------------------+
double Highest(const double& array[], int depth, int start_pos)
  {
   if(start_pos-depth<0)
      depth=start_pos;
   double max=array[start_pos];
   for(int i=start_pos; i>start_pos-depth && i>=0; i--)
     {
      if(array[i]>max)
         max=array[i];
     }
   return(max);
  }

//+------------------------------------------------------------------+
//| Initialize Fibonacci levels                                      |
//+------------------------------------------------------------------+
void InitializeFibonacciLevels()
  {
// Standard Fibonacci retracement levels (will be adjusted dynamically)
   ArrayResize(fiboLevels,8);
   ArrayResize(fiboLabels,8);

   fiboLevels[0]=0.0;
   fiboLabels[0]="0%";

   fiboLevels[1]=0.236;
   fiboLabels[1]="23.6%";

   fiboLevels[2]=0.382;
   fiboLabels[2]="38.2%";

   fiboLevels[3]=0.5;
   fiboLabels[3]="50%";

   fiboLevels[4]=0.618;
   fiboLabels[4]="61.8%";

   fiboLevels[5]=0.786;
   fiboLabels[5]="78.6%";

   fiboLevels[6]=1.0;
   fiboLabels[6]="100%";

   fiboLevels[7]=1.10;
   fiboLabels[7]="110%";
  }

//+------------------------------------------------------------------+
//| Draw Fibonacci Retracement                                       |
//+------------------------------------------------------------------+
void DrawFibonacciRetracement(int rates_total,
                              const datetime &time[],
                              int leg_start_pos, int leg_end_pos,
                              double leg_start_price, double leg_end_price,
                              int leg_color)
  {
   double range=MathAbs(leg_end_price-leg_start_price);
   bool is_uptrend=(leg_end_price>leg_start_price);

// Determine activation level index
   int activation_level_idx=-1;
   for(int i=0; i<ArraySize(fiboLevels); i++)
     {
      if(MathAbs(fiboLevels[i]-InpActivationLevel)<0.001)
        {
         activation_level_idx=i;
         break;
        }
     }

// Draw each Fibonacci level
   for(int i=0; i<ArraySize(fiboLevels); i++)
     {
      double level_price;
      if(is_uptrend)
         level_price=leg_end_price-range*fiboLevels[i];
      else
         level_price=leg_end_price+range*fiboLevels[i];

      string line_name=fiboPrefix+"Line_"+IntegerToString(i);
      string label_name=fiboPrefix+"Label_"+IntegerToString(i);

      // Create or update horizontal line
      if(ObjectFind(0,line_name)<0)
        {
         ObjectCreate(0,line_name,OBJ_TREND,0,time[leg_end_pos],level_price,time[rates_total-1],level_price);
         ObjectSetInteger(0,line_name,OBJPROP_COLOR,InpFiboColor);
         ObjectSetInteger(0,line_name,OBJPROP_STYLE,InpFiboStyle);
         ObjectSetInteger(0,line_name,OBJPROP_WIDTH,InpFiboWidth);
         ObjectSetInteger(0,line_name,OBJPROP_RAY_RIGHT,true);
         ObjectSetInteger(0,line_name,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,line_name,OBJPROP_BACK,true);
        }
      else
        {
         ObjectSetDouble(0,line_name,OBJPROP_PRICE1,level_price);
         ObjectSetDouble(0,line_name,OBJPROP_PRICE2,level_price);
         ObjectSetInteger(0,line_name,OBJPROP_TIME1,time[leg_end_pos]);
         ObjectSetInteger(0,line_name,OBJPROP_TIME2,time[rates_total-1]);
        }

      // Highlight activation level with thicker line
      if(i==activation_level_idx)
        {
         ObjectSetInteger(0,line_name,OBJPROP_WIDTH,InpFiboWidth+1);
         ObjectSetInteger(0,line_name,OBJPROP_STYLE,STYLE_SOLID);
        }

      // Create or update label
      if(InpShowFiboLabels)
        {
         if(ObjectFind(0,label_name)<0)
           {
            ObjectCreate(0,label_name,OBJ_TEXT,0,time[rates_total-1],level_price);
            ObjectSetString(0,label_name,OBJPROP_TEXT," "+fiboLabels[i]);
            ObjectSetInteger(0,label_name,OBJPROP_COLOR,InpFiboColor);
            ObjectSetInteger(0,label_name,OBJPROP_FONTSIZE,InpFontSize);
            ObjectSetInteger(0,label_name,OBJPROP_SELECTABLE,false);
            ObjectSetInteger(0,label_name,OBJPROP_BACK,true);
           }
         else
           {
            ObjectSetDouble(0,label_name,OBJPROP_PRICE,level_price);
            ObjectSetInteger(0,label_name,OBJPROP_TIME,time[rates_total-1]);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Manage Square                                                     |
//+------------------------------------------------------------------+
void ManageSquare(int rates_total,
                  const datetime &time[],
                  const double &high[],
                  const double &low[],
                  const double &close[],
                  int leg_start_pos, int leg_end_pos,
                  double leg_start_price, double leg_end_price,
                  int leg_color)
  {
// Determine leg direction
   bool is_bullish=(leg_start_price<leg_end_price); // Bottom to Peak
   int direction=is_bullish?1:-1;

// Check if leg changed
   if(leg_end_pos!=currentLegEndPos)
     {
      // New leg detected - reset square
      squareState=SQUARE_WAITING;
      squareUsedForCurrentLeg=false;
      currentLegEndPos=leg_end_pos;
      squareLockedAt110=false;
      last110CheckBar=-1;
      takeActivated=false;
      hitTakeFirst=false;
      hitStopFirst=false;
      breakoutBar=-1;
      activationTouched=false;
      breakoutDetectedAtBar=-1;
      activationTouchBar=-1;

      // Calculate prices
      double range=MathAbs(leg_end_price-leg_start_price);
      if(is_bullish)
        {
         fibo100Price=leg_start_price;
         fibo0Price=leg_end_price;
         fiboActivationPrice=fibo100Price+range*(1.0-InpActivationLevel);
         fibo110Price=fibo100Price-range*0.10;
        }
      else
        {
         fibo100Price=leg_end_price;
         fibo0Price=leg_start_price;
         fiboActivationPrice=fibo100Price-range*(1.0-InpActivationLevel);
         fibo110Price=fibo100Price+range*0.10;
        }

      squareDirection=direction;
      squareStartBar=leg_end_pos;
      squareStartTime=time[leg_end_pos];

      Print("🔄 NOVA PERNA - Direção: ", is_bullish?"ALTA":"BAIXA",
            " | 100%: ", fibo100Price, " | 0%: ", fibo0Price,
            " | Ativação ", DoubleToString(InpActivationLevel*100,1), "%: ", fiboActivationPrice);
     }

// State machine
   if(squareState==SQUARE_WAITING)
     {
      // Check if price touched activation level
      for(int i=leg_end_pos; i<rates_total; i++)
        {
         bool touched=false;
         if(is_bullish)
            touched=(low[i]<=fiboActivationPrice);
         else
            touched=(high[i]>=fiboActivationPrice);

         if(touched && !activationTouched)
           {
            activationTouched=true;
            activationTouchBar=i;
            squareState=SQUARE_ACTIVE;
            squareBasePrice=(is_bullish?fiboActivationPrice:fiboActivationPrice-InpSquareHeight*_Point);
            CreateSquare(time, rates_total, i);
            Print("✅ ATIVAÇÃO - Preço tocou nível ", DoubleToString(InpActivationLevel*100,1), "% na barra ", i);
            break;
           }
        }
     }

   if(squareState==SQUARE_ACTIVE)
     {
      // Check for 110% breach
      for(int i=MathMax(leg_end_pos,last110CheckBar+1); i<rates_total; i++)
        {
         bool breach110=false;
         if(is_bullish)
            breach110=(low[i]<fibo110Price);
         else
            breach110=(high[i]>fibo110Price);

         if(breach110)
           {
            squareState=SQUARE_LOCKED;
            squareLockedAt110=true;
            last110CheckBar=i;
            DeleteSquare();
            Print("🔒 BLOQUEIO 110% - Preço violou 110% na barra ", i);
            return;
           }
        }

      // Update square and check for breakout
      UpdateSquare(time, high, low, close, rates_total);
     }

   if(squareState==SQUARE_BREAKOUT_WAITING_TAKE)
     {
      // Check if candle closed beyond 0% level
      for(int i=breakoutBar; i<rates_total; i++)
        {
         bool closed_beyond=false;
         if(is_bullish)
            closed_beyond=(close[i]>fibo0Price);
         else
            closed_beyond=(close[i]<fibo0Price);

         if(closed_beyond && !takeActivated)
           {
            takeActivated=true;
            takeActivationClosePrice=close[i];
            squareState=SQUARE_TAKE_ACTIVE;
            takeProfitPrice=(is_bullish?takeActivationClosePrice+InpTakeProfit*_Point:takeActivationClosePrice-InpTakeProfit*_Point);
            DrawTakeAndStop();
            Print("🎯 TAKE ATIVADO - Vela fechou além de 0% na barra ", i, " | Close: ", close[i]);
            break;
           }
        }
     }

   if(squareState==SQUARE_TAKE_ACTIVE)
     {
      // Monitor if take or stop is hit
      for(int i=breakoutBar; i<rates_total; i++)
        {
         bool hit_take=false;
         bool hit_stop=false;

         if(is_bullish)
           {
            hit_take=(high[i]>=takeProfitPrice);
            hit_stop=(low[i]<=stopLossPrice);
           }
         else
           {
            hit_take=(low[i]<=takeProfitPrice);
            hit_stop=(high[i]>=stopLossPrice);
           }

         if(hit_take && !hitTakeFirst && !hitStopFirst)
           {
            hitTakeFirst=true;
            squareState=SQUARE_LOCKED;
            UpdateSquareColor(clrGreen);
            Print("💚 TAKE ATINGIDO - Gain na barra ", i);
            return;
           }

         if(hit_stop && !hitTakeFirst && !hitStopFirst)
           {
            hitStopFirst=true;
            squareState=SQUARE_LOCKED;
            UpdateSquareColor(clrRed);
            Print("❤️ STOP ATINGIDO - Loss na barra ", i);
            return;
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Create Square                                                     |
//+------------------------------------------------------------------+
void CreateSquare(const datetime &time[], int rates_total, int start_bar)
  {
   int end_bar=start_bar+InpSquareWidth;
   if(end_bar>=rates_total) end_bar=rates_total-1;

   double top_price=squareBasePrice+InpSquareHeight*_Point;
   double bottom_price=squareBasePrice;

   string rect_name=squarePrefix+"Rectangle";
   if(ObjectFind(0,rect_name)<0)
      ObjectCreate(0,rect_name,OBJ_RECTANGLE,0,time[start_bar],top_price,time[end_bar],bottom_price);
   else
     {
      ObjectSetInteger(0,rect_name,OBJPROP_TIME,0,time[start_bar]);
      ObjectSetInteger(0,rect_name,OBJPROP_TIME,1,time[end_bar]);
      ObjectSetDouble(0,rect_name,OBJPROP_PRICE,0,top_price);
      ObjectSetDouble(0,rect_name,OBJPROP_PRICE,1,bottom_price);
     }

   ObjectSetInteger(0,rect_name,OBJPROP_COLOR,InpSquareColor);
   ObjectSetInteger(0,rect_name,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,rect_name,OBJPROP_WIDTH,InpSquareWidth_Line);
   ObjectSetInteger(0,rect_name,OBJPROP_FILL,false);
   ObjectSetInteger(0,rect_name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,rect_name,OBJPROP_BACK,false);
  }

//+------------------------------------------------------------------+
//| Update Square                                                     |
//+------------------------------------------------------------------+
void UpdateSquare(const datetime &time[],
                  const double &high[],
                  const double &low[],
                  const double &close[],
                  int rates_total)
  {
   string rect_name=squarePrefix+"Rectangle";
   if(ObjectFind(0,rect_name)<0) return;

// Update right edge
   int start_bar=0;
   for(int i=rates_total-1; i>=0; i--)
     {
      if(time[i]==(datetime)ObjectGetInteger(0,rect_name,OBJPROP_TIME,0))
        {
         start_bar=i;
         break;
        }
     }

   int end_bar=start_bar+InpSquareWidth;
   if(end_bar>=rates_total) end_bar=rates_total-1;

   ObjectSetInteger(0,rect_name,OBJPROP_TIME,1,time[end_bar]);

// Check for breakout
   double top_price=squareBasePrice+InpSquareHeight*_Point;
   for(int i=start_bar; i<=end_bar && i<rates_total; i++)
     {
      bool breakout=false;
      if(squareDirection==1) // bullish
         breakout=(close[i]>top_price);
      else // bearish
         breakout=(close[i]<squareBasePrice);

      if(breakout && breakoutBar==-1)
        {
         breakoutBar=i;
         breakoutDetectedAtBar=i;
         entryPrice=(squareDirection==1?top_price:squareBasePrice);
         entryLimitPrice=(squareDirection==1?entryPrice+InpEntryLimit*_Point:entryPrice-InpEntryLimit*_Point);

         // Check entry limit
         bool entry_violated=false;
         if(squareDirection==1)
            entry_violated=(close[i]>entryLimitPrice);
         else
            entry_violated=(close[i]<entryLimitPrice);

         if(entry_violated)
           {
            squareState=SQUARE_LOCKED;
            DeleteSquare();
            Print("🔒 BLOQUEIO ENTRY - Vela fechou além do entry limit na barra ", i);
            return;
           }

         stopLossPrice=(squareDirection==1?entryPrice-InpStopLoss*_Point:entryPrice+InpStopLoss*_Point);
         squareState=SQUARE_BREAKOUT_WAITING_TAKE;
         DrawEntryAndLimit();
         Print("🚀 BREAKOUT - Rompimento na barra ", i, " | Entry: ", entryPrice);
         break;
        }
     }
  }

//+------------------------------------------------------------------+
//| Draw Entry and Limit Lines                                       |
//+------------------------------------------------------------------+
void DrawEntryAndLimit()
  {
   string entry_line=squarePrefix+"Entry";
   string limit_line=squarePrefix+"Limit";

   if(ObjectFind(0,entry_line)<0)
     {
      ObjectCreate(0,entry_line,OBJ_HLINE,0,0,entryPrice);
      ObjectSetInteger(0,entry_line,OBJPROP_COLOR,clrBlue);
      ObjectSetInteger(0,entry_line,OBJPROP_STYLE,STYLE_DASH);
      ObjectSetInteger(0,entry_line,OBJPROP_WIDTH,1);
      ObjectSetString(0,entry_line,OBJPROP_TEXT,"Entry");
     }
   else
      ObjectSetDouble(0,entry_line,OBJPROP_PRICE,entryPrice);

   if(ObjectFind(0,limit_line)<0)
     {
      ObjectCreate(0,limit_line,OBJ_HLINE,0,0,entryLimitPrice);
      ObjectSetInteger(0,limit_line,OBJPROP_COLOR,clrOrange);
      ObjectSetInteger(0,limit_line,OBJPROP_STYLE,STYLE_DOT);
      ObjectSetInteger(0,limit_line,OBJPROP_WIDTH,1);
      ObjectSetString(0,limit_line,OBJPROP_TEXT,"Entry Limit");
     }
   else
      ObjectSetDouble(0,limit_line,OBJPROP_PRICE,entryLimitPrice);
  }

//+------------------------------------------------------------------+
//| Draw Take and Stop Lines                                         |
//+------------------------------------------------------------------+
void DrawTakeAndStop()
  {
   string take_line=squarePrefix+"Take";
   string stop_line=squarePrefix+"Stop";

   if(ObjectFind(0,take_line)<0)
     {
      ObjectCreate(0,take_line,OBJ_HLINE,0,0,takeProfitPrice);
      ObjectSetInteger(0,take_line,OBJPROP_COLOR,clrGreen);
      ObjectSetInteger(0,take_line,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,take_line,OBJPROP_WIDTH,2);
      ObjectSetString(0,take_line,OBJPROP_TEXT,"Take Profit");
     }
   else
      ObjectSetDouble(0,take_line,OBJPROP_PRICE,takeProfitPrice);

   if(ObjectFind(0,stop_line)<0)
     {
      ObjectCreate(0,stop_line,OBJ_HLINE,0,0,stopLossPrice);
      ObjectSetInteger(0,stop_line,OBJPROP_COLOR,clrRed);
      ObjectSetInteger(0,stop_line,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,stop_line,OBJPROP_WIDTH,2);
      ObjectSetString(0,stop_line,OBJPROP_TEXT,"Stop Loss");
     }
   else
      ObjectSetDouble(0,stop_line,OBJPROP_PRICE,stopLossPrice);
  }

//+------------------------------------------------------------------+
//| Update Square Color                                               |
//+------------------------------------------------------------------+
void UpdateSquareColor(color new_color)
  {
   string rect_name=squarePrefix+"Rectangle";
   if(ObjectFind(0,rect_name)>=0)
      ObjectSetInteger(0,rect_name,OBJPROP_COLOR,new_color);
  }

//+------------------------------------------------------------------+
//| Delete Square                                                     |
//+------------------------------------------------------------------+
void DeleteSquare()
  {
   ObjectDelete(0,squarePrefix+"Rectangle");
  }

//+------------------------------------------------------------------+
//| Create Progress Panel                                            |
//+------------------------------------------------------------------+
void CreatePanel()
  {
   string panel_name=objPrefix+"Panel";
   if(ObjectFind(0,panel_name)<0)
     {
      ObjectCreate(0,panel_name,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,panel_name,OBJPROP_XDISTANCE,InpPanelX);
      ObjectSetInteger(0,panel_name,OBJPROP_YDISTANCE,InpPanelY);
      ObjectSetInteger(0,panel_name,OBJPROP_XSIZE,InpPanelWidth);
      ObjectSetInteger(0,panel_name,OBJPROP_YSIZE,InpPanelHeight);
      ObjectSetInteger(0,panel_name,OBJPROP_BGCOLOR,InpPanelColor);
      ObjectSetInteger(0,panel_name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,panel_name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,panel_name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,panel_name,OBJPROP_HIDDEN,true);
     }
  }

//+------------------------------------------------------------------+
//| Update Progress Panel                                            |
//+------------------------------------------------------------------+
void UpdatePanel(int rates_total,
                 int last_high_pos, int last_low_pos,
                 double last_high, double last_low,
                 const double &high[], const double &low[],
                 int extreme_search)
  {
   int current_bar=rates_total-1;
   double current_high=high[current_bar];
   double current_low=low[current_bar];

// Determine current progress based on extreme_search
   double progress_pct=0.0;
   string progress_direction="N/A";

   if(extreme_search==Peak) // Looking for Peak (moving up from Bottom)
     {
      progress_direction="Up (Bottom → Peak)";
      double range=last_high-last_low;
      if(range>0)
         progress_pct=((current_high-last_low)/range)*100.0;
     }
   else if(extreme_search==Bottom) // Looking for Bottom (moving down from Peak)
     {
      progress_direction="Down (Peak → Bottom)";
      double range=last_high-last_low;
      if(range>0)
         progress_pct=((last_high-current_low)/range)*100.0;
     }

   if(progress_pct<0) progress_pct=0;
   if(progress_pct>100) progress_pct=100;

// Create/Update Labels
   CreateOrUpdateLabel(objPrefix+"Label_Direction","Direction:",0);
   CreateOrUpdateLabel(objPrefix+"Value_Direction",progress_direction,1);

   CreateOrUpdateLabel(objPrefix+"Label_Progress","Progress:",2);
   CreateOrUpdateLabel(objPrefix+"Value_Progress",DoubleToString(progress_pct,2)+"%",3);

   CreateOrUpdateLabel(objPrefix+"Label_LastHigh","Last High:",4);
   CreateOrUpdateLabel(objPrefix+"Value_LastHigh",DoubleToString(last_high,_Digits),5);

   CreateOrUpdateLabel(objPrefix+"Label_LastLow","Last Low:",6);
   CreateOrUpdateLabel(objPrefix+"Value_LastLow",DoubleToString(last_low,_Digits),7);

   CreateOrUpdateLabel(objPrefix+"Label_CurrentHigh","Current High:",8);
   CreateOrUpdateLabel(objPrefix+"Value_CurrentHigh",DoubleToString(current_high,_Digits),9);

   CreateOrUpdateLabel(objPrefix+"Label_CurrentLow","Current Low:",10);
   CreateOrUpdateLabel(objPrefix+"Value_CurrentLow",DoubleToString(current_low,_Digits),11);
  }

//+------------------------------------------------------------------+
//| Create or Update Label                                           |
//+------------------------------------------------------------------+
void CreateOrUpdateLabel(string name, string text, int line)
  {
   int x_pos=InpPanelX+10;
   int y_pos=InpPanelY+10+line*InpLineSpacing;

   bool is_value=(StringFind(name,"Value_")>=0);
   if(is_value)
      x_pos+=InpColumnSpacing;

   if(ObjectFind(0,name)<0)
     {
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x_pos);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y_pos);
      ObjectSetInteger(0,name,OBJPROP_COLOR,InpTextColor);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,InpFontSize);
      ObjectSetString(0,name,OBJPROP_FONT,"Arial");
      ObjectSetString(0,name,OBJPROP_TEXT,text);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
     }
   else
     {
      ObjectSetString(0,name,OBJPROP_TEXT,text);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x_pos);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y_pos);
     }
  }
//+------------------------------------------------------------------+
