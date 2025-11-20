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
#property indicator_color1  clrDodgerBlue,clrRed
//--- input parameters
input int InpDepth     =12;  // Depth
input int InpDeviation =5;   // Deviation
input int InpBackstep  =3;   // Back Step
input int InpLineWidth =2;   // Line Width (1-5)
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

//--- Estruturas para rastrear padrões
struct ExtremumPoint
  {
   double price;
   int    shift;
   bool   is_peak; // true = peak, false = bottom
  };

ExtremumPoint extremum_history[5]; // Últimos 5 extremos
int extremum_count = 0;
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
//--- set line width
   PlotIndexSetInteger(0,PLOT_LINE_WIDTH,InpLineWidth);
//--- name for DataWindow and indicator subwindow label
   string short_name=StringFormat("ZigZagColor(%d,%d,%d)",InpDepth,InpDeviation,InpBackstep);
   IndicatorSetString(INDICATOR_SHORTNAME,short_name);
   PlotIndexSetString(0,PLOT_LABEL,short_name);
//--- set an empty value
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0.0);
//--- inicializar histórico de extremos
   ArrayInitialize(extremum_history,0);
   extremum_count = 0;
  }
//+------------------------------------------------------------------+
//| Adiciona um novo extremo ao histórico                            |
//+------------------------------------------------------------------+
void AddExtremum(double price, int shift, bool is_peak)
  {
//--- desloca os elementos existentes
   for(int i=4; i>0; i--)
     {
      extremum_history[i] = extremum_history[i-1];
     }
//--- adiciona o novo extremo na posição 0
   extremum_history[0].price = price;
   extremum_history[0].shift = shift;
   extremum_history[0].is_peak = is_peak;
//--- incrementa contador (máximo 5)
   if(extremum_count < 5)
      extremum_count++;
  }
//+------------------------------------------------------------------+
//| Verifica padrão e cria círculo amarelo se necessário             |
//+------------------------------------------------------------------+
void CheckPatternAndCreateMarker(const datetime &time[])
  {
//--- Precisa de pelo menos 5 extremos para verificar o padrão
   if(extremum_count < 5)
      return;

//--- Padrão esperado (do mais recente para o mais antigo):
//--- [0] = Topo maior que [2] <- MARCADOR AQUI
//--- [1] = Fundo menor que [3]
//--- [2] = Topo menor que [4]
//--- [3] = Fundo
//--- [4] = Topo

//--- Verifica se segue a sequência: peak, bottom, peak, bottom, peak
   if(!extremum_history[0].is_peak)  return; // [0] deve ser peak
   if(extremum_history[1].is_peak)   return; // [1] deve ser bottom
   if(!extremum_history[2].is_peak)  return; // [2] deve ser peak
   if(extremum_history[3].is_peak)   return; // [3] deve ser bottom
   if(!extremum_history[4].is_peak)  return; // [4] deve ser peak

//--- Verifica as condições do padrão:
//--- Peak[2] < Peak[4] (topo menor que o anterior)
//--- Bottom[1] < Bottom[3] (fundo menor que o anterior)
//--- Peak[0] > Peak[2] (topo atual maior que o topo anterior)

   if(extremum_history[2].price < extremum_history[4].price && // topo menor que anterior
      extremum_history[1].price < extremum_history[3].price && // fundo menor que anterior
      extremum_history[0].price > extremum_history[2].price)   // topo atual maior que anterior
     {
      //--- Criar círculo amarelo no topo atual [0]
      CreateYellowCircle(extremum_history[0].shift, extremum_history[0].price, time);
     }
  }
//+------------------------------------------------------------------+
//| Cria um círculo amarelo no gráfico                               |
//+------------------------------------------------------------------+
void CreateYellowCircle(int shift, double price, const datetime &time[])
  {
   string obj_name = "YellowCircle_" + IntegerToString(shift) + "_" + IntegerToString(time[shift]);

//--- Remove objeto se já existir
   if(ObjectFind(0, obj_name) >= 0)
      ObjectDelete(0, obj_name);

//--- Cria objeto do tipo Arrow
   if(ObjectCreate(0, obj_name, OBJ_ARROW, 0, time[shift], price))
     {
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, obj_name, OBJPROP_ARROWCODE, 159); // círculo cheio
      ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 15);
      ObjectSetInteger(0, obj_name, OBJPROP_BACK, false);
      ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, obj_name, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true);
      ObjectSetString(0, obj_name, OBJPROP_TOOLTIP, "Padrão de reversão detectado");
     }
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
      //--- resetar histórico de extremos
      ArrayInitialize(extremum_history,0);
      extremum_count = 0;
     }
//--- ZigZag was already calculated before
   if(prev_calculated>0)
     {
      i=rates_total-1;
      //--- searching for the third extremum from the last uncompleted bar
      while(extreme_counter<ExtRecalc && i>rates_total -100)
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
                  //--- Adicionar ao histórico de extremos
                  AddExtremum(last_high, shift, true);
                  //--- Verificar padrão e criar marcador
                  CheckPatternAndCreateMarker(time);
                 }
               if(LowMapBuffer[shift]!=0)
                 {
                  last_low=low[shift];
                  last_low_pos=shift;
                  extreme_search=1;
                  ZigzagBottomBuffer[shift]=last_low;
                  ColorBuffer[shift]=1;
                  res=1;
                  //--- Adicionar ao histórico de extremos
                  AddExtremum(last_low, shift, false);
                  //--- Verificar padrão e criar marcador
                  CheckPatternAndCreateMarker(time);
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
               //--- Adicionar ao histórico de extremos
               AddExtremum(last_high, shift, true);
               //--- Verificar padrão e criar marcador
               CheckPatternAndCreateMarker(time);
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
               //--- Adicionar ao histórico de extremos
               AddExtremum(last_low, shift, false);
               //--- Verificar padrão e criar marcador
               CheckPatternAndCreateMarker(time);
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
