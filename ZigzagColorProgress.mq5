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
input color InpFiboColor=clrBlack; // Fibonacci Lines Color
input ENUM_LINE_STYLE InpFiboStyle=STYLE_DOT; // Fibonacci Line Style
input int InpFiboWidth=1; // Fibonacci Line Width
input bool InpShowFiboLabels=true; // Show Fibonacci Labels

//--- Square inputs
input bool InpShowSquare=true; // Show Square
input int InpLegsBack=0; // Legs Back (0=current, 1=1 leg back, 2=2 legs back)
input int InpLegType=2; // Leg Type (0=Bullish Only, 1=Bearish Only, 2=Both - Default)
input double InpActivationLevel=0.692; // Activation Level (0.0 to 1.10)
input int InpSquareHeight=400; // Square Height (points)
input int InpSquareWidth=10; // Square Width (candles)
input color InpSquareColor=clrBlack; // Square Color
input int InpSquareWidth_Line=2; // Square Line Width
input int InpEntryLimit=250; // Entry Limit (points from square breakout level)
input int InpTakeProfit=500; // Take Profit (points from candle close)
input int InpStopLoss=550; // Stop Loss (points from entry)

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
string squarePrefix="ZZSquare_";

//--- Fibonacci levels (will be adjusted based on activation level)
double fiboLevels[];
string fiboLabels[];

//--- Square state variables
enum SquareState
  {
   SQUARE_NONE,        // No square
   SQUARE_WAITING,     // Waiting for activation level touch
   SQUARE_ACTIVE,      // Active after touch, waiting for breakout or 110% breach
   SQUARE_BREAKOUT_WAITING_TAKE, // Breakout occurred, waiting for take activation
   SQUARE_TAKE_ACTIVE, // Take activated, monitoring take/stop
   SQUARE_LOCKED       // Locked due to entry limit violation or 110% breach or take/stop hit
  };

SquareState squareState=SQUARE_NONE;
datetime squareStartTime=0;
int squareStartBar=0;
double squareBasePrice=0; // For bullish: base, for bearish: top
int squareDirection=0; // 1=bullish (100% at bottom), -1=bearish (100% at top)
double fiboActivationPrice=0; // Dynamic activation level price
double fibo110Price=0;
double fibo100Price=0;
double fibo0Price=0;
double entryPrice=0; // Entry price when breakout occurs
double entryLimitPrice=0;
double takeProfitPrice=0;
double stopLossPrice=0;
int currentLegEndPos=0; // To track if leg changed
bool squareUsedForCurrentLeg=false; // Track if square was already created for this leg
bool squareLockedAt110=false; // Track if square is locked at 110% level
int last110CheckBar=-1; // Track last bar checked for 110% to avoid re-checking

//--- New variables for take activation
bool takeActivated=false; // Indicates if take has been activated (candle closed beyond top)
double takeActivationClosePrice=0; // Close price of the candle that activated the take
bool hitTakeFirst=false; // Indicates if take was hit first (for green color)
bool hitStopFirst=false; // Indicates if stop was hit first (for red color)
int breakoutBar=-1; // Bar where breakout occurred
bool activationTouched=false; // Track if price touched activation level for current leg
int breakoutDetectedAtBar=-1; // Bar where breakout was detected (to prevent retroactive entry checks)
int activationTouchBar=-1; // Bar where price touched the 69.2% activation level

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

//--- Draw Fibonacci Retracement and manage square
   int leg_start_pos, leg_end_pos;
   double leg_start_price, leg_end_price;
   int leg_color;
   bool has_valid_leg=FindLastCompletedLeg(rates_total, leg_start_pos, leg_end_pos,
                                            leg_start_price, leg_end_price, leg_color);

   if(InpShowFibo && has_valid_leg)
      DrawFibonacciRetracement(rates_total, time, leg_start_pos, leg_end_pos,
                               leg_start_price, leg_end_price, leg_color);
   else if(!has_valid_leg)
      ObjectsDeleteAll(0,fiboPrefix);

//--- Manage Square
   if(InpShowSquare && has_valid_leg)
      ManageSquare(rates_total, time, high, low, close,
                   leg_start_pos, leg_end_pos, leg_start_price, leg_end_price, leg_color);
   else if(!has_valid_leg && squareState!=SQUARE_NONE)
     {
      squareState=SQUARE_NONE;
      ObjectsDeleteAll(0,squarePrefix);
     }

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
      //--- Debug: Log quando não tem extremos suficientes
      static int last_warning_extremes=-1;
      if(last_warning_extremes!=extremes_found)
        {
         Print("⚠️ PERNA IGNORADA - Extremos insuficientes: ", extremes_found, "/", required_extremes, " (InpLegsBack=", InpLegsBack, ")");
         last_warning_extremes=extremes_found;
        }
      return false;
     }

//--- CORREÇÃO: Para pegar a última perna completa, usar positions[1]->positions[0]
//--- Para InpLegsBack=0: positions[1] e positions[0] (perna mais recente)
//--- Para InpLegsBack=1: positions[3] e positions[2] (1 perna atrás)
//--- Para InpLegsBack=2: positions[5] e positions[4] (2 pernas atrás)
   int start_idx=1+2*InpLegsBack;
   int end_idx=0+2*InpLegsBack;

   //--- Verificar se os índices são válidos
   if(start_idx>=extremes_found || end_idx>=extremes_found)
     {
      Print("⚠️ PERNA IGNORADA - Índices inválidos: start_idx=", start_idx, " end_idx=", end_idx, " extremes_found=", extremes_found);
      return false;
     }

   leg_start_pos=positions[start_idx];
   leg_end_pos=positions[end_idx];
   leg_start_price=prices[start_idx];
   leg_end_price=prices[end_idx];

//--- Determine leg color (direction)
//--- If going from bottom to peak = Blue (bullish)
//--- If going from peak to bottom = Red (bearish)
   if(colors[start_idx]==1 && colors[end_idx]==0)
     {
      leg_color=0; // Blue - upward leg (from bottom to peak)
      //--- Bullish: 100% no bottom (start), 0% no peak (end)
      //--- Start price (bottom) < End price (peak) → range positivo

      //--- Verificar se a perna bullish é válida (start < end)
      if(leg_start_price>=leg_end_price)
        {
         Print("⚠️ PERNA BULLISH REJEITADA - Preços inválidos:");
         Print("   Start (bottom): ", DoubleToString(leg_start_price, _Digits), " | Bar: ", leg_start_pos);
         Print("   End (peak): ", DoubleToString(leg_end_price, _Digits), " | Bar: ", leg_end_pos);
         Print("   Start deve ser MENOR que End para perna bullish!");
         return false;
        }

      //--- Log de confirmação para pernas bullish válidas
      Print("✓ PERNA BULLISH DETECTADA:");
      Print("   Start (bottom 100%): ", DoubleToString(leg_start_price, _Digits), " | Bar: ", leg_start_pos);
      Print("   End (peak 0%): ", DoubleToString(leg_end_price, _Digits), " | Bar: ", leg_end_pos);
      Print("   Range: ", DoubleToString(leg_end_price-leg_start_price, _Digits));
     }
   else if(colors[start_idx]==0 && colors[end_idx]==1)
     {
      leg_color=1; // Red - downward leg (from peak to bottom)
      //--- Bearish: 100% no peak (start), 0% no bottom (end)
      //--- Start price (peak) > End price (bottom) → range negativo (OK)

      //--- Verificar se a perna bearish é válida (start > end)
      if(leg_start_price<=leg_end_price)
        {
         Print("⚠️ PERNA BEARISH REJEITADA - Preços inválidos:");
         Print("   Start (peak): ", DoubleToString(leg_start_price, _Digits), " | Bar: ", leg_start_pos);
         Print("   End (bottom): ", DoubleToString(leg_end_price, _Digits), " | Bar: ", leg_end_pos);
         Print("   Start deve ser MAIOR que End para perna bearish!");
         return false;
        }

      //--- Log de confirmação para pernas bearish válidas
      Print("✓ PERNA BEARISH DETECTADA:");
      Print("   Start (peak 100%): ", DoubleToString(leg_start_price, _Digits), " | Bar: ", leg_start_pos);
      Print("   End (bottom 0%): ", DoubleToString(leg_end_price, _Digits), " | Bar: ", leg_end_pos);
      Print("   Range: ", DoubleToString(leg_end_price-leg_start_price, _Digits));
     }
   else
     {
      //--- Debug: Log para entender por que pernas estão sendo rejeitadas
      Print("⚠️ PERNA REJEITADA - Padrão inválido:");
      Print("   Extremos encontrados: ", extremes_found);
      Print("   Start idx: ", start_idx, " | Type: ", (colors[start_idx]==0 ? "PEAK" : "BOTTOM"), " | Price: ", DoubleToString(prices[start_idx], _Digits));
      Print("   End idx: ", end_idx, " | Type: ", (colors[end_idx]==0 ? "PEAK" : "BOTTOM"), " | Price: ", DoubleToString(prices[end_idx], _Digits));
      Print("   Esperado: BOTTOM→PEAK (bullish) ou PEAK→BOTTOM (bearish)");
      return false; // Invalid leg
     }

   //--- Filtrar pernas baseado no parâmetro InpLegType
   //--- InpLegType: 0=Bullish Only, 1=Bearish Only, 2=Both (default)
   if(InpLegType==0 && leg_color!=0)
     {
      //--- Apenas pernas bullish são permitidas, mas esta é bearish
      static int last_warning_bull=-1;
      if(last_warning_bull!=leg_end_pos)
        {
         Print("⚠️ PERNA BEARISH IGNORADA - Modo: Apenas Alta (Bullish Only)");
         Print("   Perna detectada: Bearish (de alta para baixa)");
         Print("   Configure InpLegType=2 para aceitar ambas");
         last_warning_bull=leg_end_pos;
        }
      return false;
     }
   else if(InpLegType==1 && leg_color!=1)
     {
      //--- Apenas pernas bearish são permitidas, mas esta é bullish
      static int last_warning_bear=-1;
      if(last_warning_bear!=leg_end_pos)
        {
         Print("⚠️ PERNA BULLISH IGNORADA - Modo: Apenas Baixa (Bearish Only)");
         Print("   Perna detectada: Bullish (de baixa para alta)");
         Print("   Configure InpLegType=2 para aceitar ambas");
         last_warning_bear=leg_end_pos;
        }
      return false;
     }
   //--- Se InpLegType==2 (Both) ou o tipo corresponde, aceita a perna

   return true;
  }
//+------------------------------------------------------------------+
//| Initialize Fibonacci Levels                                       |
//+------------------------------------------------------------------+
void InitializeFibonacciLevels()
  {
//--- Base levels
   double baseLevels[]={0.0, 0.692, 1.0, 1.10};
   string baseLabels[]={"0.0%", "69.2%", "100.0%", "110.0%"};

//--- Check if activation level is 69.2%
   bool is692=(MathAbs(InpActivationLevel-0.692)<0.001);

//--- If activation level is not 69.2%, remove it from arrays
   if(!is692)
     {
      ArrayResize(fiboLevels,3);
      ArrayResize(fiboLabels,3);
      int idx=0;
      for(int i=0; i<ArraySize(baseLevels); i++)
        {
         if(MathAbs(baseLevels[i]-0.692)>=0.001) // Skip 69.2%
           {
            fiboLevels[idx]=baseLevels[i];
            fiboLabels[idx]=baseLabels[i];
            idx++;
           }
        }
     }
   else
     {
      //--- Keep all levels including 69.2%
      ArrayResize(fiboLevels,ArraySize(baseLevels));
      ArrayResize(fiboLabels,ArraySize(baseLabels));
      ArrayCopy(fiboLevels,baseLevels);
      ArrayCopy(fiboLabels,baseLabels);
     }
  }
//+------------------------------------------------------------------+
//| Draw Fibonacci Retracement                                       |
//+------------------------------------------------------------------+
void DrawFibonacciRetracement(int rates_total, const datetime &time[],
                              int leg_start_pos, int leg_end_pos,
                              double leg_start_price, double leg_end_price,
                              int leg_color)
  {
//--- Calculate Fibonacci levels
   double range=leg_end_price-leg_start_price;
   datetime start_time=time[leg_start_pos];
   datetime end_time=time[leg_end_pos];

//--- Draw vertical line at leg_end_pos (when Fibonacci was plotted)
   string vline_name=fiboPrefix+"VLine";
   if(ObjectFind(0,vline_name)<0)
     {
      ObjectCreate(0,vline_name,OBJ_VLINE,0,end_time,0);
      ObjectSetInteger(0,vline_name,OBJPROP_COLOR,clrBlue);
      ObjectSetInteger(0,vline_name,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,vline_name,OBJPROP_WIDTH,2);
      ObjectSetInteger(0,vline_name,OBJPROP_BACK,true);
      ObjectSetInteger(0,vline_name,OBJPROP_SELECTABLE,false);
     }
   else
     {
      ObjectMove(0,vline_name,0,end_time,0);
     }

//--- Check if leg_start is a peak (topo) or bottom (fundo)
   bool leg_start_is_peak=(ZigzagPeakBuffer[leg_start_pos]!=0.0);

//--- Draw activation level if not in default levels
   bool activationLevelExists=false;
   for(int j=0; j<ArraySize(fiboLevels); j++)
     {
      if(MathAbs(fiboLevels[j]-InpActivationLevel)<0.001)
        {
         activationLevelExists=true;
         break;
        }
     }

   if(!activationLevelExists)
     {
      double activation_price=leg_start_price+range*(1.0-InpActivationLevel);
      string activation_line_name=fiboPrefix+"Line_Activation";

      if(ObjectFind(0,activation_line_name)<0)
        {
         ObjectCreate(0,activation_line_name,OBJ_TREND,0,start_time,activation_price,end_time,activation_price);
         ObjectSetInteger(0,activation_line_name,OBJPROP_COLOR,InpFiboColor);
         ObjectSetInteger(0,activation_line_name,OBJPROP_STYLE,InpFiboStyle);
         ObjectSetInteger(0,activation_line_name,OBJPROP_WIDTH,InpFiboWidth);
         ObjectSetInteger(0,activation_line_name,OBJPROP_RAY_RIGHT,true);
         ObjectSetInteger(0,activation_line_name,OBJPROP_RAY_LEFT,false);
         ObjectSetInteger(0,activation_line_name,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,activation_line_name,OBJPROP_BACK,true);
        }
      else
        {
         ObjectMove(0,activation_line_name,0,start_time,activation_price);
         ObjectMove(0,activation_line_name,1,end_time,activation_price);
        }

      if(InpShowFiboLabels)
        {
         string activation_label_name=fiboPrefix+"Label_Activation";
         if(ObjectFind(0,activation_label_name)<0)
           {
            ObjectCreate(0,activation_label_name,OBJ_TEXT,0,end_time,activation_price);
            ObjectSetString(0,activation_label_name,OBJPROP_FONT,"Arial");
            ObjectSetInteger(0,activation_label_name,OBJPROP_FONTSIZE,8);
            ObjectSetInteger(0,activation_label_name,OBJPROP_COLOR,InpFiboColor);
            ObjectSetInteger(0,activation_label_name,OBJPROP_ANCHOR,ANCHOR_LEFT);
            ObjectSetInteger(0,activation_label_name,OBJPROP_SELECTABLE,false);
            ObjectSetInteger(0,activation_label_name,OBJPROP_BACK,true);
           }

         string activation_label_text=DoubleToString(InpActivationLevel*100,1)+"% ("+DoubleToString(activation_price,_Digits)+")";
         ObjectSetString(0,activation_label_name,OBJPROP_TEXT,activation_label_text);
         ObjectMove(0,activation_label_name,0,end_time,activation_price);
        }
     }

//--- Draw each Fibonacci level
   for(int i=0; i<ArraySize(fiboLevels); i++)
     {
      double level_price;

      //--- 100% always at leg_start_price (whether it's topo or fundo)
      //--- Use (1.0-fiboLevels[i]) so that 100% maps to leg_start_price
      level_price=leg_start_price+range*(1.0-fiboLevels[i]);

      //--- Check if this is the activation level
      bool isActivationLevel=(MathAbs(fiboLevels[i]-InpActivationLevel)<0.001);

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
         ObjectSetInteger(0,line_name,OBJPROP_COLOR,InpFiboColor);
         ObjectSetInteger(0,line_name,OBJPROP_STYLE,InpFiboStyle);
         ObjectSetInteger(0,line_name,OBJPROP_WIDTH,InpFiboWidth);
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
//| Manage Square (activation level trigger)                         |
//+------------------------------------------------------------------+
void ManageSquare(int rates_total, const datetime &time[],
                  const double &high[], const double &low[],
                  const double &close[],
                  int leg_start_pos, int leg_end_pos,
                  double leg_start_price, double leg_end_price,
                  int leg_color)
  {
//--- Check if leg changed
   bool legChanged=(currentLegEndPos!=0 && currentLegEndPos!=leg_end_pos);

   //--- MODIFICAÇÃO: Se a perna mudou, trocar imediatamente para a nova perna
   //--- Especialmente importante se ainda não tocou na 69.2% da perna anterior
   //--- Isso garante que, se a fibo anterior está traçada mas ainda não tocou na 69.2%,
   //--- ao surgir uma nova perna (nova fibo), troca imediatamente para ela
   if(legChanged)
     {
      //--- Reset for new leg - trocar imediatamente para nova perna
      squareState=SQUARE_NONE;
      ObjectsDeleteAll(0,squarePrefix);
      squareUsedForCurrentLeg=false;
      squareLockedAt110=false;
      last110CheckBar=-1;
      takeActivated=false;
      takeActivationClosePrice=0;
      hitTakeFirst=false;
      hitStopFirst=false;
      breakoutBar=-1;
      activationTouched=false; // Reset para começar a detectar toque na nova perna
      breakoutDetectedAtBar=-1;
      activationTouchBar=-1; // Reset activation touch bar when leg changes

      Print("═══ NOVA PERNA DETECTADA - TROCANDO IMEDIATAMENTE ═══");
      Print("Perna anterior end pos: ", currentLegEndPos);
      Print("Nova perna end pos: ", leg_end_pos);
      Print("Status anterior - Tocado na 69.2%: ", activationTouched ? "SIM" : "NÃO");
      Print("Agora monitorando nova perna e aguardando toque na 69.2%");
     }

   currentLegEndPos=leg_end_pos;

//--- Calculate Fibonacci levels
   double range=leg_end_price-leg_start_price;

//--- Determine direction based on leg_start (100% position)
   bool is_bullish=(ZigzagPeakBuffer[leg_start_pos]!=0.0) ? false : true;

//--- Calculate key Fibonacci prices
   if(is_bullish) // 100% at bottom, 0% at top
     {
      fibo100Price=leg_start_price;
      fibo0Price=leg_end_price;
      fiboActivationPrice=leg_start_price+range*(1.0-InpActivationLevel);
      fibo110Price=leg_start_price+range*(1.0-1.10);
      squareDirection=1;
     }
   else // 100% at top, 0% at bottom
     {
      fibo100Price=leg_start_price;
      fibo0Price=leg_end_price;
      fiboActivationPrice=leg_start_price+range*(1.0-InpActivationLevel);
      fibo110Price=leg_start_price+range*(1.0-1.10);
      squareDirection=-1;
     }

   int current_bar=rates_total-1;

//--- Entre a linha azul (leg_end_pos) e o toque na 69.2%:
//--- Apenas detectar onde vai ser o toque, SEM verificar condições para plotar o quadrado
   if(!activationTouched)
     {
      //--- Apenas detectar onde será o toque na 69.2%, sem ativar nada ainda
      for(int i=leg_end_pos+1; i<rates_total; i++)
        {
         bool touched=false;

         if(is_bullish)
           {
            if(low[i]<=fiboActivationPrice)
               touched=true;
           }
         else
           {
            if(high[i]>=fiboActivationPrice)
               touched=true;
           }

         if(touched)
           {
            activationTouched=true;
            activationTouchBar=i; // Guarda a barra onde tocou (variável global)
            Print("═══ ACTIVATION LEVEL TOUCHED ═══");
            Print("Leg end pos: ", leg_end_pos);
            Print("Activation price: ", DoubleToString(fiboActivationPrice, _Digits));
            Print("Touch bar: ", i);
            break;
           }
        }
     }
   else
     {
      //--- Se já detectou o toque antes mas não guardou a barra, encontrar novamente
      if(activationTouchBar==-1)
        {
         for(int i=leg_end_pos+1; i<rates_total; i++)
           {
            bool touched=false;

            if(is_bullish)
              {
               if(low[i]<=fiboActivationPrice)
                  touched=true;
              }
            else
              {
               if(high[i]>=fiboActivationPrice)
                  touched=true;
              }

            if(touched)
              {
               activationTouchBar=i;
               break;
              }
           }
        }
     }

//--- STATE: NONE - Ativar o quadrado APENAS DEPOIS de tocar na 69.2%
//--- A verificação de condições só começa DEPOIS do toque, na barra seguinte
   if(squareState==SQUARE_NONE && activationTouched && !squareUsedForCurrentLeg && activationTouchBar>=0)
     {
      //--- Ativar o quadrado na barra onde tocou, mas verificar condições só a partir da próxima barra
      squareState=SQUARE_ACTIVE;
      squareStartTime=time[activationTouchBar];
      squareStartBar=activationTouchBar;
      squareUsedForCurrentLeg=true;
      squareLockedAt110=false;
      //--- IMPORTANTE: As verificações de condições só começam DEPOIS do toque
      //--- Começar verificações da próxima barra após o toque (activationTouchBar+1)
      last110CheckBar=activationTouchBar; // Será ajustado para activationTouchBar+1 no estado ACTIVE

      //--- Definir o preço base no momento do toque
      if(is_bullish)
         squareBasePrice=low[activationTouchBar];
      else
         squareBasePrice=high[activationTouchBar];

      Print("═══ SQUARE ACTIVATED ═══");
      Print("Direction: ", is_bullish ? "BULLISH" : "BEARISH");
      Print("Activation touch bar: ", activationTouchBar);
      Print("Conditions checking starts from bar: ", activationTouchBar+1);
      Print("Fibo 100%: ", DoubleToString(fibo100Price, _Digits));
      Print("Fibo 110%: ", DoubleToString(fibo110Price, _Digits));
      Print("110% is ", (fibo110Price < fibo100Price ? "BELOW" : "ABOVE"), " 100%");
     }

//--- STATE: ACTIVE - Monitor for breakout, 110% breach, or entry limit violation
//--- IMPORTANTE: As condições só começam a ser verificadas DEPOIS do toque na 69.2%
   if(squareState==SQUARE_ACTIVE)
     {
      //--- Process bar by bar from last check
      //--- Garantir que começa a verificar condições apenas DEPOIS do toque na 69.2%
      int minStartBar=activationTouchBar>=0 ? activationTouchBar+1 : squareStartBar+1;
      int startCheckBar=(last110CheckBar>=minStartBar) ? last110CheckBar+1 : minStartBar;
      bool broke110=false;
      bool brokeSquare=false;
      int breakBar=-1;

      int endCheckBar=current_bar-1;
      if(rates_total>current_bar+1)
         endCheckBar=current_bar;

      //--- Update square base price up to the last verified bar
      for(int i=startCheckBar; i<=endCheckBar; i++)
        {
         //--- Update square base/top
         if(is_bullish)
           {
            if(low[i]<squareBasePrice)
               squareBasePrice=low[i];
           }
         else
           {
            if(high[i]>squareBasePrice)
               squareBasePrice=high[i];
           }

         //--- Recalculate square boundaries
         double squareTop, squareBottom;
         if(is_bullish)
           {
            squareBottom=squareBasePrice;
            squareTop=squareBasePrice+(InpSquareHeight*_Point);
           }
         else
           {
            squareTop=squareBasePrice;
            squareBottom=squareBasePrice-(InpSquareHeight*_Point);
           }

         //--- Check 110% breach (candle must CLOSE beyond 110%)
         bool closedBeyond110=false;

         if(is_bullish)
           {
            if(close[i]<fibo110Price)
               closedBeyond110=true;
           }
         else
           {
            if(close[i]>fibo110Price)
               closedBeyond110=true;
           }

         if(closedBeyond110)
           {
            broke110=true;
            breakBar=i;
            last110CheckBar=i;
            Print("═══ 110% BREACHED ═══");
            Print("Bar: ", i);
            Print("Close price: ", DoubleToString(close[i], _Digits));
            Print("Fibo 110%: ", DoubleToString(fibo110Price, _Digits));
            break;
           }

         //--- Check square breakout (using HIGH/LOW for touch)
         bool brokeSquareThisBar=false;
         if(is_bullish)
           {
            if(high[i]>squareTop)
               brokeSquareThisBar=true;
           }
         else
           {
            if(low[i]<squareBottom)
               brokeSquareThisBar=true;
           }

         if(brokeSquareThisBar)
           {
            brokeSquare=true;
            breakBar=i;
            breakoutBar=i;
            last110CheckBar=i;
            Print("═══ SQUARE BREACHED ═══");
            Print("Bar: ", i);
            break;
           }

         last110CheckBar=i;
        }

      //--- If no breach, continue updating to current bar
      if(!broke110 && !brokeSquare)
        {
         if(is_bullish)
           {
            if(low[current_bar]<squareBasePrice)
               squareBasePrice=low[current_bar];
           }
         else
           {
            if(high[current_bar]>squareBasePrice)
               squareBasePrice=high[current_bar];
           }
        }

      //--- Decision: which event occurred?
      if(broke110)
        {
         squareLockedAt110=true;
         squareState=SQUARE_LOCKED;
        }
      else if(brokeSquare)
        {
         //--- Calculate final boundaries
         double squareTop, squareBottom;
         if(is_bullish)
           {
            squareBottom=squareBasePrice;
            squareTop=squareBasePrice+(InpSquareHeight*_Point);
           }
         else
           {
            squareTop=squareBasePrice;
            squareBottom=squareBasePrice-(InpSquareHeight*_Point);
           }

         //--- When square is broken, we enter BREAKOUT_WAITING_TAKE state
         //--- Store the current bar to prevent retroactive entry detection
         breakoutDetectedAtBar=current_bar;
         squareState=SQUARE_BREAKOUT_WAITING_TAKE;

         //--- Save entry price (breakout level)
         if(is_bullish)
            entryPrice=squareTop;
         else
            entryPrice=squareBottom;

         //--- Calculate stop loss from entry
         if(is_bullish)
            stopLossPrice=entryPrice-InpStopLoss*_Point;
         else
            stopLossPrice=entryPrice+InpStopLoss*_Point;

         //--- Calculate entry limit price for display
         if(is_bullish)
            entryLimitPrice=squareTop+InpEntryLimit*_Point;
         else
            entryLimitPrice=squareBottom-InpEntryLimit*_Point;

         Print("═══ BREAKOUT_WAITING_TAKE ACTIVATED ═══");
         Print("Direction: ", is_bullish ? "BULLISH" : "BEARISH");
         Print("Square Top: ", DoubleToString(squareTop, _Digits));
         Print("Square Bottom: ", DoubleToString(squareBottom, _Digits));
         Print("Entry Price: ", DoubleToString(entryPrice, _Digits));
         Print("Stop Loss: ", DoubleToString(stopLossPrice, _Digits));
         Print("Entry Limit: ", DoubleToString(entryLimitPrice, _Digits));
         Print("Breakout detected at bar: ", breakoutDetectedAtBar);
        }

      //--- If still ACTIVE, draw the square
      if(squareState==SQUARE_ACTIVE)
        {
         DrawSquare(time, current_bar, is_bullish);
        }
     }

//--- STATE: BREAKOUT_WAITING_TAKE - Monitor for candle closing beyond square top
   if(squareState==SQUARE_BREAKOUT_WAITING_TAKE)
     {
      //--- Calculate square boundaries
      double squareTop, squareBottom;
      if(is_bullish)
        {
         squareBottom=squareBasePrice;
         squareTop=squareBasePrice+(InpSquareHeight*_Point);
        }
      else
        {
         squareTop=squareBasePrice;
         squareBottom=squareBasePrice-(InpSquareHeight*_Point);
        }

      //--- Verificar a vela que fez o breakout (breakoutBar)
      //--- Essa vela deve fechar dentro do limite de 250 pontos para ativar o take
      if(breakoutBar>=0 && breakoutBar<rates_total)
        {
         //--- Verificar se a vela do breakout já fechou (barra completa)
         //--- A barra do breakout só está completa se já passamos dela (current_bar > breakoutBar)
         if(current_bar>breakoutBar)
          {
           //--- Verificar se o fechamento da vela do breakout está dentro do limite de 250 pontos
           bool withinLimit=false;
           double maxEntryPrice, minEntryPrice;

           if(is_bullish)
             {
              maxEntryPrice=squareTop+InpEntryLimit*_Point;
              //--- Verificar se o fechamento está abaixo do limite de entrada (dentro dos 250 pontos)
              if(close[breakoutBar]<=maxEntryPrice)
                {
                 withinLimit=true;
                 takeActivationClosePrice=close[breakoutBar];
                 //--- Take profit = fechamento da vela + 500 pontos
                 takeProfitPrice=takeActivationClosePrice+InpTakeProfit*_Point;
                }
             }
           else
             {
              minEntryPrice=squareBottom-InpEntryLimit*_Point;
              //--- Verificar se o fechamento está acima do limite de entrada (dentro dos 250 pontos)
              if(close[breakoutBar]>=minEntryPrice)
                {
                 withinLimit=true;
                 takeActivationClosePrice=close[breakoutBar];
                 //--- Take profit = fechamento da vela - 500 pontos
                 takeProfitPrice=takeActivationClosePrice-InpTakeProfit*_Point;
                }
             }

           if(withinLimit)
             {
              //--- Ativar take profit quando a vela do breakout fechar dentro do limite
              takeActivated=true;
              squareState=SQUARE_TAKE_ACTIVE;
              Print("═══ TAKE ACTIVATED ═══");
              Print("Direction: ", is_bullish ? "BULLISH" : "BEARISH");
              Print("Breakout bar: ", breakoutBar);
              Print("Close price (breakout candle): ", DoubleToString(takeActivationClosePrice, _Digits));
              if(is_bullish)
                {
                 Print("Square Top: ", DoubleToString(squareTop, _Digits));
                 Print("Max Entry Price (limit 250 points): ", DoubleToString(maxEntryPrice, _Digits));
                }
              else
                {
                 Print("Square Bottom: ", DoubleToString(squareBottom, _Digits));
                 Print("Min Entry Price (limit 250 points): ", DoubleToString(minEntryPrice, _Digits));
                }
              Print("Take profit price (close + 500 points): ", DoubleToString(takeProfitPrice, _Digits));
             }
           else
             {
              //--- Fechou fora do limite de 250 pontos, travar o quadrado
              squareState=SQUARE_LOCKED;
              Print("═══ LOCKED - Outside entry limit ═══");
              Print("Direction: ", is_bullish ? "BULLISH" : "BEARISH");
              Print("Breakout bar: ", breakoutBar);
              Print("Close price: ", DoubleToString(close[breakoutBar], _Digits));
              if(is_bullish)
                {
                 Print("Max Entry Price (limit 250 points): ", DoubleToString(maxEntryPrice, _Digits));
                }
              else
                {
                 Print("Min Entry Price (limit 250 points): ", DoubleToString(minEntryPrice, _Digits));
                }
             }
          }
        }

      //--- Draw square, entry limit, and stop loss
      //--- Always draw stop loss when in BREAKOUT_WAITING_TAKE state
      DrawSquare(time, current_bar, is_bullish);
      DrawStopLoss(time, current_bar, is_bullish);

      //--- If take is activated, also draw take profit
      if(takeActivated && squareState==SQUARE_TAKE_ACTIVE)
        {
         DrawTakeProfit(time, current_bar, is_bullish);
        }
     }

//--- STATE: TAKE_ACTIVE - Monitor take/stop
   if(squareState==SQUARE_TAKE_ACTIVE)
     {
      bool hitTake=false;
      bool hitStop=false;

      if(is_bullish)
        {
         if(high[current_bar]>=takeProfitPrice)
            hitTake=true;
         if(low[current_bar]<=stopLossPrice)
            hitStop=true;
        }
      else
        {
         if(low[current_bar]<=takeProfitPrice)
            hitTake=true;
         if(high[current_bar]>=stopLossPrice)
            hitStop=true;
        }

      if(hitTake)
        {
         hitTakeFirst=true;
         hitStopFirst=false;
         squareState=SQUARE_LOCKED;
         Print("═══ TAKE PROFIT HIT ═══");
        }
      else if(hitStop)
        {
         hitStopFirst=true;
         hitTakeFirst=false;
         squareState=SQUARE_LOCKED;
         Print("═══ STOP LOSS HIT ═══");
        }

      //--- Draw square, stop loss, and take profit
      Print("═══ DRAWING in TAKE_ACTIVE ═══");
      Print("Calling DrawSquare, DrawStopLoss, and DrawTakeProfit");
      DrawSquare(time, current_bar, is_bullish);
      DrawStopLoss(time, current_bar, is_bullish);
      DrawTakeProfit(time, current_bar, is_bullish);
     }

//--- STATE: LOCKED - Keep displaying
   if(squareState==SQUARE_LOCKED)
     {
      DrawSquare(time, current_bar, is_bullish);
      DrawStopLoss(time, current_bar, is_bullish);
      if(takeActivated)
         DrawTakeProfit(time, current_bar, is_bullish);
     }
  }
//+------------------------------------------------------------------+
//| Draw Square                                                       |
//+------------------------------------------------------------------+
void DrawSquare(const datetime &time[], int current_bar, bool is_bullish)
  {
//--- Determine color based on take/stop hit
   color squareColor=InpSquareColor;
   if(hitTakeFirst)
      squareColor=clrGreen;
   else if(hitStopFirst)
      squareColor=clrRed;

//--- Square starts at activation time
   datetime start_time=squareStartTime;

//--- Calculate square end time (activation + width candles)
   int end_bar=squareStartBar+InpSquareWidth;
   if(end_bar>=ArraySize(time)) end_bar=ArraySize(time)-1;
   datetime end_time=time[end_bar];

//--- Calculate square prices
   double price1, price2;

   if(is_bullish)
     {
      price1=squareBasePrice; // Bottom (dynamic)
      price2=squareBasePrice+(InpSquareHeight*_Point); // Top (fixed relative to base)
     }
   else
     {
      price1=squareBasePrice-(InpSquareHeight*_Point); // Bottom (fixed relative to top)
      price2=squareBasePrice; // Top (dynamic)
     }

//--- Draw rectangle
   string rect_name=squarePrefix+"Rectangle";

   if(ObjectFind(0,rect_name)<0)
     {
      ObjectCreate(0,rect_name,OBJ_RECTANGLE,0,start_time,price1,end_time,price2);
      ObjectSetInteger(0,rect_name,OBJPROP_COLOR,squareColor);
      ObjectSetInteger(0,rect_name,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,rect_name,OBJPROP_WIDTH,InpSquareWidth_Line);
      ObjectSetInteger(0,rect_name,OBJPROP_FILL,false);
      ObjectSetInteger(0,rect_name,OBJPROP_BACK,false);
      ObjectSetInteger(0,rect_name,OBJPROP_SELECTABLE,false);
     }
   else
     {
      ObjectMove(0,rect_name,0,start_time,price1);
      ObjectMove(0,rect_name,1,end_time,price2);
      ObjectSetInteger(0,rect_name,OBJPROP_COLOR,squareColor);
     }

//--- Draw entry limit line (always visible when square is active)
   string entry_line_name=squarePrefix+"EntryLimit";
   if(squareState==SQUARE_ACTIVE || squareState==SQUARE_BREAKOUT_WAITING_TAKE || squareState==SQUARE_TAKE_ACTIVE)
     {
      //--- Calculate entry limit price
      double entryLimitDisplay;
      if(is_bullish)
         entryLimitDisplay=price2+InpEntryLimit*_Point;
      else
         entryLimitDisplay=price1-InpEntryLimit*_Point;

      if(ObjectFind(0,entry_line_name)<0)
        {
         ObjectCreate(0,entry_line_name,OBJ_TREND,0,start_time,entryLimitDisplay,end_time,entryLimitDisplay);
         ObjectSetInteger(0,entry_line_name,OBJPROP_COLOR,squareColor);
         ObjectSetInteger(0,entry_line_name,OBJPROP_STYLE,STYLE_SOLID);
         ObjectSetInteger(0,entry_line_name,OBJPROP_WIDTH,2);
         ObjectSetInteger(0,entry_line_name,OBJPROP_RAY_RIGHT,false);
         ObjectSetInteger(0,entry_line_name,OBJPROP_RAY_LEFT,false);
         ObjectSetInteger(0,entry_line_name,OBJPROP_BACK,true);
         ObjectSetInteger(0,entry_line_name,OBJPROP_SELECTABLE,false);
        }
      else
        {
         ObjectMove(0,entry_line_name,0,start_time,entryLimitDisplay);
         ObjectMove(0,entry_line_name,1,end_time,entryLimitDisplay);
         ObjectSetInteger(0,entry_line_name,OBJPROP_COLOR,squareColor);
        }

      //--- Draw entry limit label
      string entry_label_name=squarePrefix+"EntryLabel";
      if(ObjectFind(0,entry_label_name)<0)
        {
         ObjectCreate(0,entry_label_name,OBJ_TEXT,0,end_time,entryLimitDisplay);
         ObjectSetString(0,entry_label_name,OBJPROP_FONT,"Arial Bold");
         ObjectSetInteger(0,entry_label_name,OBJPROP_FONTSIZE,10);
         ObjectSetInteger(0,entry_label_name,OBJPROP_COLOR,squareColor);
         ObjectSetString(0,entry_label_name,OBJPROP_TEXT,"  LIMITE");
         ObjectSetInteger(0,entry_label_name,OBJPROP_ANCHOR,ANCHOR_LEFT);
         ObjectSetInteger(0,entry_label_name,OBJPROP_SELECTABLE,false);
        }
      else
        {
         ObjectMove(0,entry_label_name,0,end_time,entryLimitDisplay);
         ObjectSetInteger(0,entry_label_name,OBJPROP_COLOR,squareColor);
        }
     }
   else
     {
      if(ObjectFind(0,entry_line_name)>=0)
         ObjectDelete(0,entry_line_name);
      string entry_label_name=squarePrefix+"EntryLabel";
      if(ObjectFind(0,entry_label_name)>=0)
         ObjectDelete(0,entry_label_name);
     }
  }
//+------------------------------------------------------------------+
//| Draw Stop Loss                                                    |
//+------------------------------------------------------------------+
void DrawStopLoss(const datetime &time[], int current_bar, bool is_bullish)
  {
   Print("DrawStopLoss called - stopLossPrice: ", DoubleToString(stopLossPrice, _Digits));
   Print("squareStartTime: ", TimeToString(squareStartTime));
   Print("squareStartBar: ", squareStartBar);

//--- Determine color
   color lineColor=InpSquareColor;
   if(hitTakeFirst)
      lineColor=clrGreen;
   else if(hitStopFirst)
      lineColor=clrRed;

//--- Calculate same start/end time as square
   datetime start_time=squareStartTime;
   int end_bar=squareStartBar+InpSquareWidth;
   if(end_bar>=ArraySize(time)) end_bar=ArraySize(time)-1;
   datetime end_time=time[end_bar];

//--- Draw Stop Loss line
   string sl_line_name=squarePrefix+"StopLoss";
   if(ObjectFind(0,sl_line_name)<0)
     {
      ObjectCreate(0,sl_line_name,OBJ_TREND,0,start_time,stopLossPrice,end_time,stopLossPrice);
      ObjectSetInteger(0,sl_line_name,OBJPROP_COLOR,lineColor);
      ObjectSetInteger(0,sl_line_name,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,sl_line_name,OBJPROP_WIDTH,2);
      ObjectSetInteger(0,sl_line_name,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,sl_line_name,OBJPROP_RAY_LEFT,false);
      ObjectSetInteger(0,sl_line_name,OBJPROP_BACK,true);
      ObjectSetInteger(0,sl_line_name,OBJPROP_SELECTABLE,false);
     }
   else
     {
      ObjectMove(0,sl_line_name,0,start_time,stopLossPrice);
      ObjectMove(0,sl_line_name,1,end_time,stopLossPrice);
      ObjectSetInteger(0,sl_line_name,OBJPROP_COLOR,lineColor);
     }

//--- Draw label
   datetime label_time=end_time;
   string sl_label_name=squarePrefix+"SLLabel";
   if(ObjectFind(0,sl_label_name)<0)
     {
      ObjectCreate(0,sl_label_name,OBJ_TEXT,0,label_time,stopLossPrice);
      ObjectSetString(0,sl_label_name,OBJPROP_FONT,"Arial Bold");
      ObjectSetInteger(0,sl_label_name,OBJPROP_FONTSIZE,10);
      ObjectSetInteger(0,sl_label_name,OBJPROP_COLOR,lineColor);
      ObjectSetString(0,sl_label_name,OBJPROP_TEXT,"  STOP");
      ObjectSetInteger(0,sl_label_name,OBJPROP_ANCHOR,ANCHOR_LEFT);
      ObjectSetInteger(0,sl_label_name,OBJPROP_SELECTABLE,false);
     }
   else
     {
      ObjectMove(0,sl_label_name,0,label_time,stopLossPrice);
      ObjectSetInteger(0,sl_label_name,OBJPROP_COLOR,lineColor);
     }
  }
//+------------------------------------------------------------------+
//| Draw Take Profit (only when activated)                           |
//+------------------------------------------------------------------+
void DrawTakeProfit(const datetime &time[], int current_bar, bool is_bullish)
  {
//--- Only draw if take is activated
   if(!takeActivated)
      return;

//--- Determine color
   color lineColor=InpSquareColor;
   if(hitTakeFirst)
      lineColor=clrGreen;
   else if(hitStopFirst)
      lineColor=clrRed;

//--- Calculate same start/end time as square
   datetime start_time=squareStartTime;
   int end_bar=squareStartBar+InpSquareWidth;
   if(end_bar>=ArraySize(time)) end_bar=ArraySize(time)-1;
   datetime end_time=time[end_bar];

//--- Draw Take Profit line
   string tp_line_name=squarePrefix+"TakeProfit";
   if(ObjectFind(0,tp_line_name)<0)
     {
      ObjectCreate(0,tp_line_name,OBJ_TREND,0,start_time,takeProfitPrice,end_time,takeProfitPrice);
      ObjectSetInteger(0,tp_line_name,OBJPROP_COLOR,lineColor);
      ObjectSetInteger(0,tp_line_name,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,tp_line_name,OBJPROP_WIDTH,2);
      ObjectSetInteger(0,tp_line_name,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,tp_line_name,OBJPROP_RAY_LEFT,false);
      ObjectSetInteger(0,tp_line_name,OBJPROP_BACK,true);
      ObjectSetInteger(0,tp_line_name,OBJPROP_SELECTABLE,false);
     }
   else
     {
      ObjectMove(0,tp_line_name,0,start_time,takeProfitPrice);
      ObjectMove(0,tp_line_name,1,end_time,takeProfitPrice);
      ObjectSetInteger(0,tp_line_name,OBJPROP_COLOR,lineColor);
     }

//--- Draw label
   datetime label_time=end_time;
   string tp_label_name=squarePrefix+"TPLabel";
   if(ObjectFind(0,tp_label_name)<0)
     {
      ObjectCreate(0,tp_label_name,OBJ_TEXT,0,label_time,takeProfitPrice);
      ObjectSetString(0,tp_label_name,OBJPROP_FONT,"Arial Bold");
      ObjectSetInteger(0,tp_label_name,OBJPROP_FONTSIZE,10);
      ObjectSetInteger(0,tp_label_name,OBJPROP_COLOR,lineColor);
      ObjectSetString(0,tp_label_name,OBJPROP_TEXT,"  TAKE");
      ObjectSetInteger(0,tp_label_name,OBJPROP_ANCHOR,ANCHOR_LEFT);
      ObjectSetInteger(0,tp_label_name,OBJPROP_SELECTABLE,false);
     }
   else
     {
      ObjectMove(0,tp_label_name,0,label_time,takeProfitPrice);
      ObjectSetInteger(0,tp_label_name,OBJPROP_COLOR,lineColor);
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

   if(extreme_search==Peak)
     {
      searching="TOPO ▲";
      bars_since=current_bar-last_low_pos;
      time_progress=MathMin(100.0, (bars_since*100.0)/InpDepth);
      price_move=(high[current_bar]-last_low)/_Point;
      double required_move=InpDeviation;
      move_progress=MathMin(100.0, (price_move/required_move)*100.0);
      overall_progress=(time_progress+move_progress)/2.0;

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
   else if(extreme_search==Bottom)
     {
      searching="FUNDO ▼";
      bars_since=current_bar-last_high_pos;
      time_progress=MathMin(100.0, (bars_since*100.0)/InpDepth);
      price_move=(last_high-low[current_bar])/_Point;
      double required_move=InpDeviation;
      move_progress=MathMin(100.0, (price_move/required_move)*100.0);
      overall_progress=(time_progress+move_progress)/2.0;

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
   else
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
