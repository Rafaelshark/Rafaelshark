//+------------------------------------------------------------------+
//|                                                  ZigzagColor.mq5 |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
//--- indicator settings
#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   3
#property indicator_type1   DRAW_COLOR_ZIGZAG
#property indicator_color1  clrDodgerBlue,clrRed
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  3
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrLime
#property indicator_width3  3
//--- input parameters
input int InpDepth     =12;  // Depth
input int InpDeviation =5;   // Deviation
input int InpBackstep  =3;   // Back Step
input int InpLineWidth =2;   // Line Width (1-5)
input int InpSymbolSize=3;   // Symbol Size (1-5)
//--- indicator buffers
double ZigzagPeakBuffer[];
double ZigzagBottomBuffer[];
double ColorBuffer[];
double BreakUpBuffer[];      // Quebra de alta (vermelho)
double BreakDownBuffer[];    // Quebra de baixa (verde)
double HighMapBuffer[];
double LowMapBuffer[];

int ExtRecalc=3; // recounting's depth

// Arrays para rastrear histórico de topos e fundos
double HistoryHighs[];    // Histórico de topos
double HistoryLows[];     // Histórico de fundos
int HistoryHighsPos[];    // Posições dos topos
int HistoryLowsPos[];     // Posições dos fundos
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
   SetIndexBuffer(3,BreakUpBuffer,INDICATOR_DATA);
   SetIndexBuffer(4,BreakDownBuffer,INDICATOR_DATA);
   SetIndexBuffer(5,HighMapBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(6,LowMapBuffer,INDICATOR_CALCULATIONS);
//--- set accuracy
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
//--- set line width
   PlotIndexSetInteger(0,PLOT_LINE_WIDTH,InpLineWidth);
//--- configurar símbolos de quebra
   PlotIndexSetInteger(1,PLOT_ARROW,159); // Círculo grande para quebra de alta
   PlotIndexSetInteger(1,PLOT_LINE_WIDTH,InpSymbolSize);
   PlotIndexSetInteger(2,PLOT_ARROW,159); // Círculo grande para quebra de baixa
   PlotIndexSetInteger(2,PLOT_LINE_WIDTH,InpSymbolSize);
//--- name for DataWindow and indicator subwindow label
   string short_name=StringFormat("ZigZagColor(%d,%d,%d)",InpDepth,InpDeviation,InpBackstep);
   IndicatorSetString(INDICATOR_SHORTNAME,short_name);
   PlotIndexSetString(0,PLOT_LABEL,short_name);
   PlotIndexSetString(1,PLOT_LABEL,"Quebra Alta");
   PlotIndexSetString(2,PLOT_LABEL,"Quebra Baixa");
//--- set an empty value
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetDouble(2,PLOT_EMPTY_VALUE,0.0);
//--- inicializar arrays de histórico
   ArrayResize(HistoryHighs,100);
   ArrayResize(HistoryLows,100);
   ArrayResize(HistoryHighsPos,100);
   ArrayResize(HistoryLowsPos,100);
   ArrayInitialize(HistoryHighs,0.0);
   ArrayInitialize(HistoryLows,0.0);
   ArrayInitialize(HistoryHighsPos,0);
   ArrayInitialize(HistoryLowsPos,0);
  }
//+------------------------------------------------------------------+
//| Adiciona um topo ao histórico                                    |
//+------------------------------------------------------------------+
void AddHighToHistory(double high_value,int pos)
  {
   if(HighCount>=ArraySize(HistoryHighs))
     {
      ArrayResize(HistoryHighs,ArraySize(HistoryHighs)+50);
      ArrayResize(HistoryHighsPos,ArraySize(HistoryHighsPos)+50);
     }
   HistoryHighs[HighCount]=high_value;
   HistoryHighsPos[HighCount]=pos;
   HighCount++;
  }
//+------------------------------------------------------------------+
//| Adiciona um fundo ao histórico                                   |
//+------------------------------------------------------------------+
void AddLowToHistory(double low_value,int pos)
  {
   if(LowCount>=ArraySize(HistoryLows))
     {
      ArrayResize(HistoryLows,ArraySize(HistoryLows)+50);
      ArrayResize(HistoryLowsPos,ArraySize(HistoryLowsPos)+50);
     }
   HistoryLows[LowCount]=low_value;
   HistoryLowsPos[LowCount]=pos;
   LowCount++;
  }
//+------------------------------------------------------------------+
//| Detecta quebra de tendência                                      |
//+------------------------------------------------------------------+
int DetectTrendBreak(double new_value,bool is_high,int shift)
  {
// 0 = sem quebra
// 1 = quebra de tendência de alta (símbolo vermelho)
// 2 = quebra de tendência de baixa (símbolo verde)

   if(is_high)
     {
      // Novo topo sendo adicionado
      if(HighCount>=2 && LowCount>=1)
        {
         double prev_high=HistoryHighs[HighCount-1];
         double prev_prev_high=HistoryHighs[HighCount-2];

         // Verifica se estávamos em tendência de alta (topos crescentes)
         if(prev_high>prev_prev_high)
           {
            // Se o novo topo é menor que o anterior = quebra de tendência de alta
            if(new_value<prev_high)
              {
               BreakUpBuffer[shift]=new_value;
               return 1; // Quebra de alta
              }
           }
         // Verifica se estávamos em tendência de baixa (topos decrescentes)
         else if(prev_high<prev_prev_high)
           {
            // Se o novo topo é maior que o anterior = quebra de tendência de baixa
            if(new_value>prev_high)
              {
               BreakDownBuffer[shift]=new_value;
               return 2; // Quebra de baixa
              }
           }
        }
     }
   else
     {
      // Novo fundo sendo adicionado
      if(LowCount>=2 && HighCount>=1)
        {
         double prev_low=HistoryLows[LowCount-1];
         double prev_prev_low=HistoryLows[LowCount-2];

         // Verifica se estávamos em tendência de alta (fundos crescentes)
         if(prev_low>prev_prev_low)
           {
            // Se o novo fundo é menor que o anterior = quebra de tendência de alta
            if(new_value<prev_low)
              {
               BreakUpBuffer[shift]=new_value;
               return 1; // Quebra de alta
              }
           }
         // Verifica se estávamos em tendência de baixa (fundos decrescentes)
         else if(prev_low<prev_prev_low)
           {
            // Se o novo fundo é maior que o anterior = quebra de tendência de baixa
            if(new_value>prev_low)
              {
               BreakDownBuffer[shift]=new_value;
               return 2; // Quebra de baixa
              }
           }
        }
     }

   return 0; // Sem quebra
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
      ArrayInitialize(ColorBuffer,0);
      ArrayInitialize(BreakUpBuffer,0.0);
      ArrayInitialize(BreakDownBuffer,0.0);
      //--- resetar histórico
      ArrayInitialize(HistoryHighs,0.0);
      ArrayInitialize(HistoryLows,0.0);
      ArrayInitialize(HistoryHighsPos,0);
      ArrayInitialize(HistoryLowsPos,0);
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
            AddHighToHistory(ZigzagPeakBuffer[j],j);
           }
         if(ZigzagBottomBuffer[j]!=0)
           {
            AddLowToHistory(ZigzagBottomBuffer[j],j);
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
         BreakUpBuffer[i]     =0.0;
         BreakDownBuffer[i]   =0.0;
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

                  DetectTrendBreak(last_high,true,shift);
                  ColorBuffer[shift]=0;
                  AddHighToHistory(last_high,shift);

                  res=1;
                 }
               if(LowMapBuffer[shift]!=0)
                 {
                  last_low=low[shift];
                  last_low_pos=shift;
                  extreme_search=1;
                  ZigzagBottomBuffer[shift]=last_low;

                  DetectTrendBreak(last_low,false,shift);
                  ColorBuffer[shift]=1;
                  AddLowToHistory(last_low,shift);

                  res=1;
                 }
              }
            break;
         case Peak:
            if(LowMapBuffer[shift]!=0.0 && LowMapBuffer[shift]<last_low &&
               HighMapBuffer[shift]==0.0)
              {
               ZigzagBottomBuffer[last_low_pos]=0.0;
               BreakUpBuffer[last_low_pos]=0.0;
               BreakDownBuffer[last_low_pos]=0.0;
               last_low_pos=shift;
               last_low=LowMapBuffer[shift];
               ZigzagBottomBuffer[shift]=last_low;

               // Remover o último fundo do histórico e adicionar o novo
               if(LowCount>0)
                  LowCount--;
               DetectTrendBreak(last_low,false,shift);
               ColorBuffer[shift]=1;
               AddLowToHistory(last_low,shift);

               res=1;
              }
            if(HighMapBuffer[shift]!=0.0 && LowMapBuffer[shift]==0.0)
              {
               last_high=HighMapBuffer[shift];
               last_high_pos=shift;
               ZigzagPeakBuffer[shift]=last_high;

               DetectTrendBreak(last_high,true,shift);
               ColorBuffer[shift]=0;
               AddHighToHistory(last_high,shift);

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
               BreakUpBuffer[last_high_pos]=0.0;
               BreakDownBuffer[last_high_pos]=0.0;
               last_high_pos=shift;
               last_high=HighMapBuffer[shift];
               ZigzagPeakBuffer[shift]=last_high;

               // Remover o último topo do histórico e adicionar o novo
               if(HighCount>0)
                  HighCount--;
               DetectTrendBreak(last_high,true,shift);
               ColorBuffer[shift]=0;
               AddHighToHistory(last_high,shift);
              }
            if(LowMapBuffer[shift]!=0.0 && HighMapBuffer[shift]==0.0)
              {
               last_low=LowMapBuffer[shift];
               last_low_pos=shift;
               ZigzagBottomBuffer[shift]=last_low;

               DetectTrendBreak(last_low,false,shift);
               ColorBuffer[shift]=1;
               AddLowToHistory(last_low,shift);

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
