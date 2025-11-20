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
input int InpPanelHeight=320; // Panel Height (aumentado para novos campos)
input int InpLineSpacing=20; // Vertical Line Spacing
input int InpColumnSpacing=250; // Horizontal Spacing (Label to Value)
input color InpPanelColor=clrBlack; // Panel Background Color
input color InpTextColor=16777215; // Text Color
input int InpFontSize  =9;   // Font Size
input bool InpShowBreaks=true; // Show Trend Breaks on Chart
input int InpArrowSize =2;   // Break Arrow Size (1-5)
input color InpBreakColor=clrRed; // Break Arrow Color

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

//--- Estrutura para armazenar extremos
struct SExtremum
  {
   double price;
   int position;
   bool isPeak; // true = topo, false = fundo
  };

//--- Estrutura para armazenar quebras de tendência
struct STrendBreak
  {
   int position;
   double price;
   datetime time;
   bool isTopBreak; // true = quebra de topo, false = quebra de fundo
  };

//--- Global variables for panel
string objPrefix="ZZProgress_";
string objBreakPrefix="ZZBreak_";

//--- Variáveis globais para detecção de quebra de tendência
SExtremum g_extremes[10]; // Armazena os últimos 10 extremos
int g_extremes_count=0;
bool g_in_uptrend=false;
bool g_trend_break_detected=false;
int g_trend_break_bar=0;
string g_trend_status="Aguardando padrão...";
color g_trend_status_color=clrGray;

//--- Variáveis para armazenar quebras históricas
STrendBreak g_trend_breaks[];
int g_breaks_count=0;

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
//--- Delete all break markers
   ObjectsDeleteAll(0,objBreakPrefix);
   ChartRedraw();
  }
//+------------------------------------------------------------------+
//| Adiciona um novo extremo ao histórico                            |
//+------------------------------------------------------------------+
void AddExtremum(double price, int position, bool isPeak)
  {
//--- Desloca o array para a direita
   for(int i=ArraySize(g_extremes)-1; i>0; i--)
     {
      g_extremes[i]=g_extremes[i-1];
     }

//--- Adiciona o novo extremo na primeira posição
   g_extremes[0].price=price;
   g_extremes[0].position=position;
   g_extremes[0].isPeak=isPeak;

   if(g_extremes_count<ArraySize(g_extremes))
      g_extremes_count++;

//--- Analisa o padrão de tendência
   AnalyzeTrendPattern();
  }
//+------------------------------------------------------------------+
//| Analisa o padrão de tendência e detecta quebras                  |
//+------------------------------------------------------------------+
void AnalyzeTrendPattern()
  {
   if(g_extremes_count<3)
     {
      g_trend_status="Aguardando padrão... ("+IntegerToString(g_extremes_count)+"/3 extremos)";
      g_trend_status_color=clrGray;
      g_in_uptrend=false;
      return;
     }

//--- Verifica padrão de alta
//--- Padrão 1: Fundo -> Topo -> Fundo (onde Fundo2 > Fundo1)
//--- Padrão 2: Topo -> Fundo -> Topo (onde Topo2 > Topo1)

   bool uptrend_pattern1=false;
   bool uptrend_pattern2=false;

//--- Verifica Padrão 1: Fundo -> Topo -> Fundo maior
   if(g_extremes_count>=3)
     {
      // Extremo[0] = mais recente, Extremo[2] = mais antigo desta análise
      // Ordem cronológica: [2] -> [1] -> [0]

      // Padrão 1: Fundo[2] -> Topo[1] -> Fundo[0] (Fundo[0] > Fundo[2])
      if(!g_extremes[2].isPeak && g_extremes[1].isPeak && !g_extremes[0].isPeak)
        {
         if(g_extremes[0].price>g_extremes[2].price)
           {
            uptrend_pattern1=true;
           }
        }

      // Padrão 2: Topo[2] -> Fundo[1] -> Topo[0] (Topo[0] > Topo[2])
      if(g_extremes[2].isPeak && !g_extremes[1].isPeak && g_extremes[0].isPeak)
        {
         if(g_extremes[0].price>g_extremes[2].price)
           {
            uptrend_pattern2=true;
           }
        }
     }

//--- Se detectou padrão de alta
   if(uptrend_pattern1 || uptrend_pattern2)
     {
      if(!g_in_uptrend)
        {
         g_in_uptrend=true;
         g_trend_break_detected=false;
         g_trend_status="Tendência de ALTA confirmada!";
         g_trend_status_color=clrLime;
        }
     }

//--- Se estamos em tendência de alta, verifica quebra no 4º extremo
   if(g_in_uptrend && g_extremes_count>=4)
     {
      // O 4º extremo é o [0] (mais recente)
      // Precisamos verificar se ele quebrou o padrão

      bool break_detected=false;

      // Se o extremo mais recente é um topo
      if(g_extremes[0].isPeak)
        {
         // Procura o topo anterior
         for(int i=1; i<g_extremes_count; i++)
           {
            if(g_extremes[i].isPeak)
              {
               // Em alta, topos devem ser crescentes
               if(g_extremes[0].price<g_extremes[i].price)
                 {
                  break_detected=true;
                  g_trend_status="QUEBRA DE TENDÊNCIA! Topo menor";
                  g_trend_status_color=clrRed;
                 }
               break;
              }
           }
        }
      // Se o extremo mais recente é um fundo
      else
        {
         // Procura o fundo anterior
         for(int i=1; i<g_extremes_count; i++)
           {
            if(!g_extremes[i].isPeak)
              {
               // Em alta, fundos devem ser crescentes
               if(g_extremes[0].price<g_extremes[i].price)
                 {
                  break_detected=true;
                  g_trend_status="QUEBRA DE TENDÊNCIA! Fundo menor";
                  g_trend_status_color=clrRed;
                 }
               break;
              }
           }
        }

      if(break_detected && !g_trend_break_detected)
        {
         g_trend_break_detected=true;
         g_trend_break_bar=g_extremes[0].position;
         // Registra a quebra no array de quebras históricas
         RegisterTrendBreak(g_extremes[0].position, g_extremes[0].price, g_extremes[0].isPeak);
         // Após detectar quebra, reseta para procurar novo padrão
         // Mas mantém o status por um tempo
        }
      else if(!break_detected && !g_trend_break_detected)
        {
         g_trend_status="Tendência de ALTA ativa";
         g_trend_status_color=clrLime;
        }
     }
  }
//+------------------------------------------------------------------+
//| Registra uma quebra de tendência                                 |
//+------------------------------------------------------------------+
void RegisterTrendBreak(int position, double price, bool isTopBreak)
  {
//--- Verifica se já existe uma quebra nesta posição
   for(int i=0; i<g_breaks_count; i++)
     {
      if(g_trend_breaks[i].position==position)
         return; // Já existe, não adiciona duplicata
     }

//--- Adiciona nova quebra
   ArrayResize(g_trend_breaks, g_breaks_count+1);
   g_trend_breaks[g_breaks_count].position=position;
   g_trend_breaks[g_breaks_count].price=price;
   g_trend_breaks[g_breaks_count].time=iTime(_Symbol, _Period, position);
   g_trend_breaks[g_breaks_count].isTopBreak=isTopBreak;
   g_breaks_count++;
  }
//+------------------------------------------------------------------+
//| Desenha marcadores de quebra de tendência no gráfico             |
//+------------------------------------------------------------------+
void DrawTrendBreakMarkers()
  {
   if(!InpShowBreaks)
      return;

//--- Limpa marcadores antigos
   ObjectsDeleteAll(0,objBreakPrefix);

//--- Desenha cada quebra detectada
   for(int i=0; i<g_breaks_count; i++)
     {
      string objName=objBreakPrefix+IntegerToString(g_trend_breaks[i].position);

      datetime time=g_trend_breaks[i].time;
      double price=g_trend_breaks[i].price;

      // Cria seta para baixo indicando quebra
      ObjectCreate(0, objName, OBJ_ARROW_DOWN, 0, time, price);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, InpBreakColor);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, InpArrowSize);
      ObjectSetInteger(0, objName, OBJPROP_BACK, false);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);

      // Adiciona tooltip
      string tooltip="Quebra de Tendência\n";
      tooltip+=g_trend_breaks[i].isTopBreak ? "Topo menor que anterior" : "Fundo menor que anterior";
      tooltip+="\nPreço: "+DoubleToString(price, _Digits);
      ObjectSetString(0, objName, OBJPROP_TOOLTIP, tooltip);
     }

   ChartRedraw();
  }
//+------------------------------------------------------------------+
//| Varre histórico completo para detectar quebras passadas          |
//+------------------------------------------------------------------+
void ScanHistoricalBreaks(int rates_total)
  {
//--- Limpa quebras anteriores
   ArrayResize(g_trend_breaks, 0);
   g_breaks_count=0;

//--- Array temporário para armazenar extremos do histórico
   SExtremum temp_extremes[];
   int temp_count=0;

//--- Coleta todos os extremos do ZigZag do mais antigo ao mais recente
   for(int i=0; i<rates_total; i++)
     {
      if(ZigzagPeakBuffer[i]!=0 || ZigzagBottomBuffer[i]!=0)
        {
         ArrayResize(temp_extremes, temp_count+1);

         if(ZigzagPeakBuffer[i]!=0)
           {
            temp_extremes[temp_count].price=ZigzagPeakBuffer[i];
            temp_extremes[temp_count].position=i;
            temp_extremes[temp_count].isPeak=true;
           }
         else
           {
            temp_extremes[temp_count].price=ZigzagBottomBuffer[i];
            temp_extremes[temp_count].position=i;
            temp_extremes[temp_count].isPeak=false;
           }

         temp_count++;
        }
     }

//--- Analisa o padrão para cada conjunto de extremos
   if(temp_count<4)
      return; // Precisa de pelo menos 4 extremos

   bool in_uptrend=false;

   for(int i=0; i<temp_count-3; i++)
     {
      // Verifica padrão de alta nos 3 primeiros extremos
      bool uptrend_pattern=false;

      // Padrão 1: Fundo -> Topo -> Fundo (Fundo2 > Fundo1)
      if(!temp_extremes[i].isPeak && temp_extremes[i+1].isPeak && !temp_extremes[i+2].isPeak)
        {
         if(temp_extremes[i+2].price>temp_extremes[i].price)
            uptrend_pattern=true;
        }

      // Padrão 2: Topo -> Fundo -> Topo (Topo2 > Topo1)
      if(temp_extremes[i].isPeak && !temp_extremes[i+1].isPeak && temp_extremes[i+2].isPeak)
        {
         if(temp_extremes[i+2].price>temp_extremes[i].price)
            uptrend_pattern=true;
        }

      if(uptrend_pattern)
        {
         in_uptrend=true;

         // Verifica se o 4º extremo quebra a tendência
         if(i+3<temp_count)
           {
            bool break_detected=false;

            // Se o 4º extremo é um topo
            if(temp_extremes[i+3].isPeak)
              {
               // Procura o topo anterior
               for(int j=i+2; j>=i; j--)
                 {
                  if(temp_extremes[j].isPeak)
                    {
                     if(temp_extremes[i+3].price<temp_extremes[j].price)
                       {
                        break_detected=true;
                        RegisterTrendBreak(temp_extremes[i+3].position, temp_extremes[i+3].price, true);
                       }
                     break;
                    }
                 }
              }
            // Se o 4º extremo é um fundo
            else
              {
               // Procura o fundo anterior
               for(int j=i+2; j>=i; j--)
                 {
                  if(!temp_extremes[j].isPeak)
                    {
                     if(temp_extremes[i+3].price<temp_extremes[j].price)
                       {
                        break_detected=true;
                        RegisterTrendBreak(temp_extremes[i+3].position, temp_extremes[i+3].price, false);
                       }
                     break;
                    }
                 }
              }

            if(break_detected)
              {
               in_uptrend=false; // Reseta tendência após quebra
              }
           }
        }
     }

//--- Desenha os marcadores
   DrawTrendBreakMarkers();
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
      //--- Reset trend detection
      g_extremes_count=0;
      g_in_uptrend=false;
      g_trend_break_detected=false;
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
                  //--- Adiciona extremo ao histórico
                  AddExtremum(last_high,shift,true);
                 }
               if(LowMapBuffer[shift]!=0)
                 {
                  last_low=low[shift];
                  last_low_pos=shift;
                  extreme_search=1;
                  ZigzagBottomBuffer[shift]=last_low;
                  ColorBuffer[shift]=1;
                  res=1;
                  //--- Adiciona extremo ao histórico
                  AddExtremum(last_low,shift,false);
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
               //--- Adiciona extremo ao histórico
               AddExtremum(last_low,shift,false);
              }
            if(HighMapBuffer[shift]!=0.0 && LowMapBuffer[shift]==0.0)
              {
               last_high=HighMapBuffer[shift];
               last_high_pos=shift;
               ZigzagPeakBuffer[shift]=last_high;
               ColorBuffer[shift]=0;
               extreme_search=Bottom;
               res=1;
               //--- Adiciona extremo ao histórico
               AddExtremum(last_high,shift,true);
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
               //--- Adiciona extremo ao histórico
               AddExtremum(last_high,shift,true);
              }
            if(LowMapBuffer[shift]!=0.0 && HighMapBuffer[shift]==0.0)
              {
               last_low=LowMapBuffer[shift];
               last_low_pos=shift;
               ZigzagBottomBuffer[shift]=last_low;
               ColorBuffer[shift]=1;
               extreme_search=Peak;
               //--- Adiciona extremo ao histórico
               AddExtremum(last_low,shift,false);
              }
            break;
         default:
            return(rates_total);
        }
     }

//--- Update progress panel
   if(InpShowPanel)
      UpdatePanel(rates_total, last_high_pos, last_low_pos, last_high, last_low,
                  high, low, extreme_search);

//--- Scan and mark historical trend breaks
   if(InpShowBreaks)
      ScanHistoricalBreaks(rates_total);

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
   string labels[]={"Status:","Procurando:","Último Extremo:","Barras Desde:","Progresso Tempo:","Movimento Preço:","Progresso Movimento:","Geral:","","Tendência:","Extremos:"};

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

//--- Monta string com histórico de extremos
   string extremes_history="";
   for(int i=MathMin(4,g_extremes_count)-1; i>=0; i--)
     {
      if(i<g_extremes_count)
        {
         string type_str=g_extremes[i].isPeak ? "T:" : "F:";
         extremes_history+=type_str+DoubleToString(g_extremes[i].price,_Digits);
         if(i>0)
            extremes_history+=" → ";
        }
     }
   if(extremes_history=="")
      extremes_history="Aguardando...";

//--- Update values
   string values[11];
   values[0]=status;
   values[1]=searching;
   values[2]=(extreme_search==Peak) ? StringFormat("%."+IntegerToString(_Digits)+"f",last_low) :
                                       StringFormat("%."+IntegerToString(_Digits)+"f",last_high);
   values[3]=IntegerToString(bars_since)+" barras";
   values[4]=StringFormat("%.1f%%",time_progress);
   values[5]=StringFormat("%.1f pontos",price_move);
   values[6]=StringFormat("%.1f%%",move_progress);
   values[7]=StringFormat("%.1f%%",overall_progress);
   values[8]=""; // Linha vazia
   values[9]=g_trend_status;
   values[10]=extremes_history;

   color colors[]={status_color,clrWhite,clrCyan,clrWhite,clrAqua,clrWhite,clrAqua,clrYellow,clrWhite,g_trend_status_color,clrAqua};

   for(int i=0; i<11; i++)
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
