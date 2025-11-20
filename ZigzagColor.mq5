//+------------------------------------------------------------------+
//|                                                  ZigzagColor.mq5 |
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
#property indicator_color1  clrLime,clrYellow,clrRed
#property indicator_width1  2
//--- input parameters
input int  InpDepth       =12;    // Depth
input int  InpDeviation   =5;     // Deviation
input int  InpBackstep    =3;     // Back Step
input bool InpShowLine    =true;  // Show ZigZag Line
input int  InpLineWidth   =2;     // Line Width (1-5)
//--- indicator buffers
double ZigzagPeakBuffer[];
double ZigzagBottomBuffer[];
double ColorBuffer[];
double HighMapBuffer[];
double LowMapBuffer[];

int ExtRecalc=3; // recounting's depth

// Arrays para rastrear histórico de topos e fundos
double HistoryHighs[];    // Histórico de topos
double HistoryLows[];     // Histórico de fundos
int HistoryHighsPos[];    // Posições dos topos
int HistoryLowsPos[];     // Posições dos fundos
int HistoryColors[];      // Cores fixas de cada extremo
int HighCount=0;          // Contador de topos
int LowCount=0;           // Contador de fundos

enum EnSearchMode
  {
   Extremum=0, // searching for the first extremum
   Peak=1,     // searching for the next ZigZag peak
   Bottom=-1   // searching for the next ZigZag bottom
  };
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,ZigzagPeakBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,ZigzagBottomBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,ColorBuffer,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(3,HighMapBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(4,LowMapBuffer,INDICATOR_CALCULATIONS);
//--- set accuracy
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);

//--- configurar linha do ZigZag
   if(InpShowLine)
     {
      PlotIndexSetInteger(0,PLOT_DRAW_TYPE,DRAW_COLOR_ZIGZAG);
      PlotIndexSetInteger(0,PLOT_LINE_WIDTH,InpLineWidth);
     }
   else
     {
      PlotIndexSetInteger(0,PLOT_DRAW_TYPE,DRAW_NONE); // Ocultar linha
     }

//--- name for DataWindow and indicator subwindow label
   string short_name=StringFormat("ZigZagColor(%d,%d,%d)",InpDepth,InpDeviation,InpBackstep);
   IndicatorSetString(INDICATOR_SHORTNAME,short_name);
   PlotIndexSetString(0,PLOT_LABEL,short_name);
//--- set an empty value
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0.0);
//--- inicializar arrays de histórico
   ArrayResize(HistoryHighs,100);
   ArrayResize(HistoryLows,100);
   ArrayResize(HistoryHighsPos,100);
   ArrayResize(HistoryLowsPos,100);
   ArrayResize(HistoryColors,100);
   ArrayInitialize(HistoryHighs,0.0);
   ArrayInitialize(HistoryLows,0.0);
   ArrayInitialize(HistoryHighsPos,0);
   ArrayInitialize(HistoryLowsPos,0);
   ArrayInitialize(HistoryColors,1); // Amarelo por padrão
  }
//+------------------------------------------------------------------+
//| Adiciona um topo ao histórico                                    |
//+------------------------------------------------------------------+
void AddHighToHistory(double high_value,int pos,int color)
  {
   if(HighCount>=ArraySize(HistoryHighs))
     {
      ArrayResize(HistoryHighs,ArraySize(HistoryHighs)+50);
      ArrayResize(HistoryHighsPos,ArraySize(HistoryHighsPos)+50);
     }
   HistoryHighs[HighCount]=high_value;
   HistoryHighsPos[HighCount]=pos;
   HighCount++;

   // Salvar cor fixa para este extremo
   int total_idx=HighCount+LowCount-1;
   if(total_idx>=ArraySize(HistoryColors))
      ArrayResize(HistoryColors,ArraySize(HistoryColors)+50);
   HistoryColors[total_idx]=color;
  }
//+------------------------------------------------------------------+
//| Adiciona um fundo ao histórico                                   |
//+------------------------------------------------------------------+
void AddLowToHistory(double low_value,int pos,int color)
  {
   if(LowCount>=ArraySize(HistoryLows))
     {
      ArrayResize(HistoryLows,ArraySize(HistoryLows)+50);
      ArrayResize(HistoryLowsPos,ArraySize(HistoryLowsPos)+50);
     }
   HistoryLows[LowCount]=low_value;
   HistoryLowsPos[LowCount]=pos;
   LowCount++;

   // Salvar cor fixa para este extremo
   int total_idx=HighCount+LowCount-1;
   if(total_idx>=ArraySize(HistoryColors))
      ArrayResize(HistoryColors,ArraySize(HistoryColors)+50);
   HistoryColors[total_idx]=color;
  }
//+------------------------------------------------------------------+
//| Determina cor do trecho baseado no padrão de topos e fundos      |
//+------------------------------------------------------------------+
int GetTrendColor()
  {
// 0 = Verde (alta)
// 1 = Amarelo (indefinido)
// 2 = Vermelho (baixa)

   if(HighCount<2 || LowCount<2) return 1; // Amarelo se não tem dados suficientes

   double last_high=HistoryHighs[HighCount-1];
   double prev_high=HistoryHighs[HighCount-2];
   double last_low=HistoryLows[LowCount-1];
   double prev_low=HistoryLows[LowCount-2];

   bool highs_rising=(last_high>prev_high);
   bool lows_rising=(last_low>prev_low);
   bool highs_falling=(last_high<prev_high);
   bool lows_falling=(last_low<prev_low);

// VERDE: fundos e topos crescentes = tendência de alta
   if(highs_rising && lows_rising)
      return 0;

// VERMELHO: fundos e topos decrescentes = tendência de baixa
   if(highs_falling && lows_falling)
      return 2;

// AMARELO: padrão indefinido/quebrado
   return 1;
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
      ArrayInitialize(ColorBuffer,1); // Amarelo por padrão
      //--- resetar histórico
      ArrayInitialize(HistoryHighs,0.0);
      ArrayInitialize(HistoryLows,0.0);
      ArrayInitialize(HistoryHighsPos,0);
      ArrayInitialize(HistoryLowsPos,0);
      ArrayInitialize(HistoryColors,1); // Amarelo por padrão
      HighCount=0;
      LowCount=0;
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

      //--- Reconstruir histórico de extremos até o ponto de recálculo
      HighCount=0;
      LowCount=0;
      for(int j=0;j<start;j++)
        {
         if(ZigzagPeakBuffer[j]!=0)
           {
            AddHighToHistory(ZigzagPeakBuffer[j],j,(int)ColorBuffer[j]);
           }
         if(ZigzagBottomBuffer[j]!=0)
           {
            AddLowToHistory(ZigzagBottomBuffer[j],j,(int)ColorBuffer[j]);
           }
        }

      //--- what type of extremum we search for
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
         ColorBuffer[i]       =1; // Amarelo por padrão
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
                  int color=GetTrendColor();
                  ColorBuffer[shift]=color;
                  AddHighToHistory(last_high,shift,color);
                  res=1;
                 }
               if(LowMapBuffer[shift]!=0)
                 {
                  last_low=low[shift];
                  last_low_pos=shift;
                  extreme_search=1;
                  ZigzagBottomBuffer[shift]=last_low;
                  int color=GetTrendColor();
                  ColorBuffer[shift]=color;
                  AddLowToHistory(last_low,shift,color);
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

               // Remover o último fundo do histórico e adicionar o novo
               if(LowCount>0)
                  LowCount--;
               int color=GetTrendColor();
               ColorBuffer[shift]=color;
               AddLowToHistory(last_low,shift,color);

               res=1;
              }
            if(HighMapBuffer[shift]!=0.0 && LowMapBuffer[shift]==0.0)
              {
               last_high=HighMapBuffer[shift];
               last_high_pos=shift;
               ZigzagPeakBuffer[shift]=last_high;

               int color=GetTrendColor();
               ColorBuffer[shift]=color;
               AddHighToHistory(last_high,shift,color);

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

               // Remover o último topo do histórico e adicionar o novo
               if(HighCount>0)
                  HighCount--;
               int color=GetTrendColor();
               ColorBuffer[shift]=color;
               AddHighToHistory(last_high,shift,color);
              }
            if(LowMapBuffer[shift]!=0.0 && HighMapBuffer[shift]==0.0)
              {
               last_low=LowMapBuffer[shift];
               last_low_pos=shift;
               ZigzagBottomBuffer[shift]=last_low;

               int color=GetTrendColor();
               ColorBuffer[shift]=color;
               AddLowToHistory(last_low,shift,color);

               extreme_search=Peak;
              }
            break;
         default:
            return(rates_total);
        }
     }

//--- return value of prev_calculated for next call
   return(rates_total);
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
