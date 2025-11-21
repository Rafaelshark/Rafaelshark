//+------------------------------------------------------------------+
//|                                   ZigzagColorProgress_EA.mq5     |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

//--- Enum para tipo de perna
enum ENUM_LEG_TYPE
  {
   LEG_ALTA_ONLY=0,    // Apenas Alta (Bullish)
   LEG_BAIXA_ONLY=1,   // Apenas Baixa (Bearish)
   LEG_AMBAS=2         // Ambas (Both)
  };

//--- Parâmetros de entrada do ZigZag
input int InpDepth     =12;  // Profundidade
input int InpDeviation =5;   // Desvio
input int InpBackstep  =3;   // Passo para Trás

//--- Parâmetros de Trading
input double InpLotSize=0.01; // Tamanho do Lote
input int InpMagicNumber=123456; // Número Mágico
input string InpTradeComment="ZZProgress_EA"; // Comentário das Ordens

//--- Parâmetros visuais
input int InpLineWidth =3;   // Largura da Linha (1-5)
input bool InpShowPanel=true; // Mostrar Painel de Progresso
input int InpPanelX    =20;  // Posição X do Painel
input int InpPanelY    =30;  // Posição Y do Painel
input int InpPanelWidth=500; // Largura do Painel
input int InpPanelHeight=280;// Altura do Painel
input int InpLineSpacing=20; // Espaçamento Vertical entre Linhas
input int InpColumnSpacing=250; // Espaçamento Horizontal (Rótulo para Valor)
input color InpPanelColor=clrBlack; // Cor de Fundo do Painel
input color InpTextColor=16777215; // Cor do Texto
input int InpFontSize  =9;   // Tamanho da Fonte

//--- Parâmetros de Fibonacci
input bool InpShowFibo=true; // Mostrar Retração de Fibonacci
input color InpFiboColor=clrBlack; // Cor das Linhas de Fibonacci
input ENUM_LINE_STYLE InpFiboStyle=STYLE_DOT; // Estilo da Linha de Fibonacci
input int InpFiboWidth=1; // Largura da Linha de Fibonacci
input bool InpShowFiboLabels=true; // Mostrar Rótulos de Fibonacci

//--- Parâmetros do Quadrado
input bool InpShowSquare=true; // Mostrar Quadrado
input ENUM_LEG_TYPE InpLegType=LEG_AMBAS; // Tipo de Perna
input double InpActivationLevel=0.692; // Nível de Ativação (0.0 a 1.10)
input int InpSquareHeight=400; // Altura do Quadrado (pontos)
input int InpSquareWidth=10; // Largura do Quadrado (velas)
input color InpSquareColor=clrBlack; // Cor do Quadrado
input int InpSquareWidth_Line=2; // Largura da Linha do Quadrado
input int InpEntryLimit=250; // Limite de Entrada (pontos do nível de rompimento do quadrado)
input int InpTakeProfit=500; // Take Profit (pontos do fechamento da vela)
input int InpStopLoss=550; // Stop Loss (pontos da entrada)

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
string objPrefix="ZZProgress_EA_";
string fiboPrefix="ZZFibo_EA_";
string squarePrefix="ZZSquare_EA_";
string zigzagPrefix="ZZLine_EA_";

//--- Fibonacci levels
double fiboLevels[];
string fiboLabels[];

//--- Square state variables
enum SquareState
  {
   SQUARE_NONE,
   SQUARE_WAITING,
   SQUARE_ACTIVE,
   SQUARE_BREAKOUT_WAITING_TAKE,
   SQUARE_TAKE_ACTIVE,
   SQUARE_LOCKED
  };

SquareState squareState=SQUARE_NONE;
datetime squareStartTime=0;
int squareStartBar=0;
double squareBasePrice=0;
int squareDirection=0;
double fiboActivationPrice=0;
double fibo110Price=0;
double fibo100Price=0;
double fibo0Price=0;
double entryPrice=0;
double entryLimitPrice=0;
double takeProfitPrice=0;
double stopLossPrice=0;
int currentLegEndPos=0;
bool squareUsedForCurrentLeg=false;
bool squareLockedAt110=false;
int last110CheckBar=-1;
bool takeActivated=false;
double takeActivationClosePrice=0;
bool hitTakeFirst=false;
bool hitStopFirst=false;
int breakoutBar=-1;
bool activationTouched=false;
int breakoutDetectedAtBar=-1;
int activationTouchBar=-1;
int lockedLegStartPos=-1;
int lockedLegEndPos=-1;
double lockedLegStartPrice=0;
double lockedLegEndPrice=0;
int lockedLegColor=0;

//--- Trading variables
CTrade trade;
ulong currentTicket=0;
bool positionOpen=false;
datetime lastTradeTime=0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Setup trade object
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);

//--- Initialize arrays (NOT as series, matching original indicator)
   ArraySetAsSeries(ZigzagPeakBuffer,false);
   ArraySetAsSeries(ZigzagBottomBuffer,false);
   ArraySetAsSeries(HighMapBuffer,false);
   ArraySetAsSeries(LowMapBuffer,false);
   ArraySetAsSeries(ColorBuffer,false);

//--- Initialize Fibonacci levels
   InitializeFibonacciLevels();

//--- Clean all objects from previous instances
   ObjectsDeleteAll(0,objPrefix);
   ObjectsDeleteAll(0,fiboPrefix);
   ObjectsDeleteAll(0,squarePrefix);
   ObjectsDeleteAll(0,zigzagPrefix);

//--- Create panel
   if(InpShowPanel)
      CreatePanel();

   Print("═══ ZigzagColorProgress EA Inicializado ═══");
   Print("Lote: ", InpLotSize);
   Print("Magic Number: ", InpMagicNumber);
   Print("Take Profit: ", InpTakeProfit, " pontos");
   Print("Stop Loss: ", InpStopLoss, " pontos");
   Print("Aguardando dados suficientes do ZigZag...");

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Delete all objects
   ObjectsDeleteAll(0,objPrefix);
   ObjectsDeleteAll(0,fiboPrefix);
   ObjectsDeleteAll(0,squarePrefix);
   ObjectsDeleteAll(0,zigzagPrefix);
   ChartRedraw();
   Print("ZigzagColorProgress EA Desinicializado");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- Get current data
   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   int copied=CopyRates(_Symbol,_Period,0,500,rates);
   if(copied<100)
      return;

//--- Get price arrays (NOT as series, matching original indicator)
   double high[], low[], open[], close[];
   datetime time[];
   ArraySetAsSeries(high,false);
   ArraySetAsSeries(low,false);
   ArraySetAsSeries(open,false);
   ArraySetAsSeries(close,false);
   ArraySetAsSeries(time,false);

   int copiedH=CopyHigh(_Symbol,_Period,0,500,high);
   int copiedL=CopyLow(_Symbol,_Period,0,500,low);
   int copiedO=CopyOpen(_Symbol,_Period,0,500,open);
   int copiedC=CopyClose(_Symbol,_Period,0,500,close);
   int copiedT=CopyTime(_Symbol,_Period,0,500,time);

   if(copiedH<100 || copiedL<100 || copiedO<100 || copiedC<100 || copiedT<100)
      return;

//--- Resize buffers
   ArrayResize(ZigzagPeakBuffer,copied);
   ArrayResize(ZigzagBottomBuffer,copied);
   ArrayResize(HighMapBuffer,copied);
   ArrayResize(LowMapBuffer,copied);
   ArrayResize(ColorBuffer,copied);

//--- Calculate ZigZag
   CalculateZigZag(copied,time,open,high,low,close);

//--- Check if we have an open position
   positionOpen=false;
   currentTicket=0;
   if(PositionSelect(_Symbol))
     {
      if(PositionGetInteger(POSITION_MAGIC)==InpMagicNumber)
        {
         positionOpen=true;
         currentTicket=PositionGetInteger(POSITION_TICKET);
        }
     }

//--- Manage trading signals
   ManageTrading(copied,time,high,low,close);

//--- Update panel
   if(InpShowPanel)
     {
      int last_high_pos=-1, last_low_pos=-1;
      double last_high=0, last_low=0;
      int extreme_search=Extremum;

      //--- Find last extremes
      for(int i=0; i<copied; i++)
        {
         if(ZigzagPeakBuffer[i]!=0)
           {
            last_high_pos=i;
            last_high=ZigzagPeakBuffer[i];
            extreme_search=Bottom;
            break;
           }
         if(ZigzagBottomBuffer[i]!=0)
           {
            last_low_pos=i;
            last_low=ZigzagBottomBuffer[i];
            extreme_search=Peak;
            break;
           }
        }

      UpdatePanel(copied,last_high_pos,last_low_pos,last_high,last_low,
                  high,low,extreme_search);
     }
  }

//+------------------------------------------------------------------+
//| Calculate ZigZag                                                  |
//+------------------------------------------------------------------+
void CalculateZigZag(const int rates_total,
                     const datetime &time[],
                     const double &open[],
                     const double &high[],
                     const double &low[],
                     const double &close[])
  {
   if(rates_total<100)
      return;

//--- Initialize buffers
   ArrayInitialize(ZigzagPeakBuffer,0.0);
   ArrayInitialize(ZigzagBottomBuffer,0.0);
   ArrayInitialize(HighMapBuffer,0.0);
   ArrayInitialize(LowMapBuffer,0.0);
   ArrayInitialize(ColorBuffer,0.0);

   int    i,start=0;
   int    extreme_counter=0,extreme_search=Extremum;
   int    shift,back=0,last_high_pos=0,last_low_pos=0;
   double val=0,res=0;
   double cur_low=0,cur_high=0,last_high=0,last_low=0;

//--- Start from InpDepth
   start=InpDepth-1;

//--- Searching for high and low extremes
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

//--- Set last values
   last_low=0;
   last_high=0;

//--- Final selection of extremes
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
            return;
        }
     }

//--- Draw ZigZag Lines
   DrawZigZagLines(rates_total, time);

//--- Draw Fibonacci and manage square
   int leg_start_pos, leg_end_pos;
   double leg_start_price, leg_end_price;
   int leg_color;
   bool has_valid_leg=FindLastCompletedLeg(rates_total, leg_start_pos, leg_end_pos,
                                            leg_start_price, leg_end_price, leg_color);

//--- Se o quadrado está ativo/travado, usar valores travados da fibo
//--- Isso garante que a fibo não mude enquanto o quadrado está em operação
   bool useLockedFibo=(squareState!=SQUARE_NONE && squareState!=SQUARE_WAITING && lockedLegStartPos>=0);

   if(useLockedFibo)
     {
      //--- Usar valores travados quando o quadrado foi ativado
      leg_start_pos=lockedLegStartPos;
      leg_end_pos=lockedLegEndPos;
      leg_start_price=lockedLegStartPrice;
      leg_end_price=lockedLegEndPrice;
      leg_color=lockedLegColor;
      has_valid_leg=true;

      static datetime lastPrintTime=0;
      if(TimeCurrent()-lastPrintTime>60) // Print a cada 60 segundos
        {
         Print("📌 Usando FIBONACCI TRAVADA | Estado: ", EnumToString(squareState));
         lastPrintTime=TimeCurrent();
        }
     }

   if(InpShowFibo && has_valid_leg)
      DrawFibonacciRetracement(rates_total, time, leg_start_pos, leg_end_pos,
                               leg_start_price, leg_end_price, leg_color);
   else if(!has_valid_leg && !useLockedFibo)
     {
      //--- Limpar todos os objetos de Fibonacci incluindo linha vertical azul
      ObjectsDeleteAll(0,fiboPrefix);
     }

   if(InpShowSquare && has_valid_leg)
      ManageSquare(rates_total, time, high, low, close,
                   leg_start_pos, leg_end_pos, leg_start_price, leg_end_price, leg_color);
   else if(!has_valid_leg && squareState!=SQUARE_NONE)
     {
      squareState=SQUARE_NONE;
      ObjectsDeleteAll(0,squarePrefix);
     }

//--- Se não há perna válida e não está usando fibo travada, resetar estado
   if(!has_valid_leg && !useLockedFibo)
     {
      //--- Limpar todas as variáveis de estado
      currentLegEndPos=0;
      squareState=SQUARE_NONE;
      squareUsedForCurrentLeg=false;
      squareLockedAt110=false;
      last110CheckBar=-1;
      takeActivated=false;
      takeActivationClosePrice=0;
      hitTakeFirst=false;
      hitStopFirst=false;
      breakoutBar=-1;
      activationTouched=false;
      breakoutDetectedAtBar=-1;
      activationTouchBar=-1;
      lockedLegStartPos=-1;
      lockedLegEndPos=-1;
      lockedLegStartPrice=0;
      lockedLegEndPrice=0;
      lockedLegColor=0;
     }
  }

//+------------------------------------------------------------------+
//| Manage Trading                                                    |
//+------------------------------------------------------------------+
void ManageTrading(int rates_total, const datetime &time[],
                   const double &high[], const double &low[],
                   const double &close[])
  {
//--- Only trade when square is in specific states
   if(squareState!=SQUARE_TAKE_ACTIVE && squareState!=SQUARE_LOCKED)
      return;

//--- If position is already open, monitor it
   if(positionOpen)
     {
      //--- Position management is handled by MT5 SL/TP
      //--- Just check if it was closed
      if(!PositionSelect(_Symbol))
        {
         Print("═══ POSIÇÃO FECHADA ═══");
         positionOpen=false;
         currentTicket=0;
        }
      return;
     }

//--- Open position when take is activated and no position is open
   if(squareState==SQUARE_TAKE_ACTIVE && takeActivated && !positionOpen)
     {
      //--- Prevent opening multiple orders on same signal
      if(lastTradeTime==time[0])
         return;

      //--- Determine order type
      ENUM_ORDER_TYPE orderType;
      if(squareDirection==1) // Bullish
         orderType=ORDER_TYPE_BUY;
      else // Bearish
         orderType=ORDER_TYPE_SELL;

      //--- Calculate SL and TP prices
      double sl=0, tp=0;
      if(orderType==ORDER_TYPE_BUY)
        {
         sl=entryPrice-InpStopLoss*_Point;
         tp=takeActivationClosePrice+InpTakeProfit*_Point;
        }
      else
        {
         sl=entryPrice+InpStopLoss*_Point;
         tp=takeActivationClosePrice-InpTakeProfit*_Point;
        }

      //--- Normalize prices
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      sl=NormalizeDouble(sl,_Digits);
      tp=NormalizeDouble(tp,_Digits);

      //--- Open position
      bool result=false;
      if(orderType==ORDER_TYPE_BUY)
         result=trade.Buy(InpLotSize,_Symbol,ask,sl,tp,InpTradeComment);
      else
         result=trade.Sell(InpLotSize,_Symbol,bid,sl,tp,InpTradeComment);

      if(result)
        {
         currentTicket=trade.ResultOrder();
         positionOpen=true;
         lastTradeTime=time[0];

         Print("═══ ORDEM ABERTA ═══");
         Print("Tipo: ", orderType==ORDER_TYPE_BUY ? "BUY" : "SELL");
         Print("Lote: ", InpLotSize);
         Print("Preço Entrada: ", DoubleToString(entryPrice, _Digits));
         Print("Stop Loss: ", DoubleToString(sl, _Digits));
         Print("Take Profit: ", DoubleToString(tp, _Digits));
         Print("Ticket: ", currentTicket);
        }
      else
        {
         Print("ERRO ao abrir ordem: ", trade.ResultRetcode());
         Print("Descrição: ", trade.ResultRetcodeDescription());
        }
     }
  }

//+------------------------------------------------------------------+
//| Draw ZigZag Lines                                                 |
//+------------------------------------------------------------------+
void DrawZigZagLines(int rates_total, const datetime &time[])
  {
//--- Find all ZigZag extremes and connect them with lines
   int extremes_count=0;
   int positions[100];
   double prices[100];
   int colors[100];

//--- Collect all extremes
   for(int i=0; i<rates_total && extremes_count<100; i++)
     {
      if(ZigzagPeakBuffer[i]!=0.0)
        {
         positions[extremes_count]=i;
         prices[extremes_count]=ZigzagPeakBuffer[i];
         colors[extremes_count]=0; // Blue
         extremes_count++;
        }
      else if(ZigzagBottomBuffer[i]!=0.0)
        {
         positions[extremes_count]=i;
         prices[extremes_count]=ZigzagBottomBuffer[i];
         colors[extremes_count]=1; // Red
         extremes_count++;
        }
     }

//--- Draw lines between consecutive extremes
   for(int i=0; i<extremes_count-1; i++)
     {
      string line_name=zigzagPrefix+IntegerToString(i);

      datetime time1=time[positions[i]];
      double price1=prices[i];
      datetime time2=time[positions[i+1]];
      double price2=prices[i+1];

      //--- Determine line color based on direction
      color line_color=clrDodgerBlue;
      if(colors[i]==1 && colors[i+1]==0)
         line_color=clrDodgerBlue; // Bullish (bottom to peak)
      else if(colors[i]==0 && colors[i+1]==1)
         line_color=clrRed; // Bearish (peak to bottom)

      if(ObjectFind(0,line_name)<0)
        {
         ObjectCreate(0,line_name,OBJ_TREND,0,time1,price1,time2,price2);
         ObjectSetInteger(0,line_name,OBJPROP_COLOR,line_color);
         ObjectSetInteger(0,line_name,OBJPROP_STYLE,STYLE_SOLID);
         ObjectSetInteger(0,line_name,OBJPROP_WIDTH,InpLineWidth);
         ObjectSetInteger(0,line_name,OBJPROP_RAY_RIGHT,false);
         ObjectSetInteger(0,line_name,OBJPROP_RAY_LEFT,false);
         ObjectSetInteger(0,line_name,OBJPROP_BACK,true);
         ObjectSetInteger(0,line_name,OBJPROP_SELECTABLE,false);
        }
      else
        {
         ObjectMove(0,line_name,0,time1,price1);
         ObjectMove(0,line_name,1,time2,price2);
         ObjectSetInteger(0,line_name,OBJPROP_COLOR,line_color);
        }
     }

//--- Delete old lines that are no longer needed
   for(int i=extremes_count; i<100; i++)
     {
      string line_name=zigzagPrefix+IntegerToString(i);
      if(ObjectFind(0,line_name)>=0)
         ObjectDelete(0,line_name);
     }
  }

//+------------------------------------------------------------------+
//| Find last completed leg                                          |
//+------------------------------------------------------------------+
bool FindLastCompletedLeg(int rates_total,
                          int &leg_start_pos, int &leg_end_pos,
                          double &leg_start_price, double &leg_end_price,
                          int &leg_color)
  {
//--- Para EA: usar perna CONFIRMADA (sem repintagem)
//--- Precisamos de 4 extremos para garantir que a perna está confirmada:
//--- positions[0]=mais recente (não confirmado)
//--- positions[1]=anterior (confirmado por positions[0])
//--- positions[2]=início da perna confirmada
//--- positions[3]=fim da perna confirmada (totalmente estável)
   int required_extremes=4;
   int extremes_found=0;

   int positions[];
   double prices[];
   int colors[];

   ArrayResize(positions,required_extremes);
   ArrayResize(prices,required_extremes);
   ArrayResize(colors,required_extremes);

   for(int i=0; i<rates_total && extremes_found<required_extremes; i++)
     {
      double peak_val=ZigzagPeakBuffer[i];
      double bottom_val=ZigzagBottomBuffer[i];

      if(peak_val!=0.0)
        {
         positions[extremes_found]=i;
         prices[extremes_found]=peak_val;
         colors[extremes_found]=0;
         extremes_found++;
        }
      else if(bottom_val!=0.0)
        {
         positions[extremes_found]=i;
         prices[extremes_found]=bottom_val;
         colors[extremes_found]=1;
         extremes_found++;
        }
     }

   if(extremes_found<required_extremes)
     {
      //--- Debug apenas na primeira vez
      static bool first_warning=true;
      if(first_warning)
        {
         Print("⚠️ Aguardando extremos suficientes do ZigZag...");
         Print("   Encontrados: ", extremes_found, " / Necessários: ", required_extremes);
         Print("   O EA iniciará quando houver dados suficientes.");
         first_warning=false;
        }
      return false;
     }

//--- Perna confirmada: usar extremos estáveis que não vão repintar
   int start_idx=3; // Início da perna confirmada (extremo totalmente estável)
   int end_idx=2;   // Fim da perna confirmada (extremo estável)

   if(start_idx>=extremes_found || end_idx>=extremes_found)
      return false;

   leg_start_pos=positions[start_idx];
   leg_end_pos=positions[end_idx];
   leg_start_price=prices[start_idx];
   leg_end_price=prices[end_idx];

   if(colors[start_idx]==1 && colors[end_idx]==0)
     {
      leg_color=0; // Bullish
     }
   else if(colors[start_idx]==0 && colors[end_idx]==1)
     {
      leg_color=1; // Bearish
      if(leg_start_price<=leg_end_price)
         return false;
     }
   else
     {
      return false;
     }

   if((int)InpLegType==(int)LEG_ALTA_ONLY && leg_color!=0)
      return false;
   else if((int)InpLegType==(int)LEG_BAIXA_ONLY && leg_color!=1)
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Initialize Fibonacci Levels                                       |
//+------------------------------------------------------------------+
void InitializeFibonacciLevels()
  {
   double baseLevels[]={0.0, 0.692, 1.0, 1.10};
   string baseLabels[]={"0.0%", "69.2%", "100.0%", "110.0%"};

   bool is692=(MathAbs(InpActivationLevel-0.692)<0.001);

   if(!is692)
     {
      ArrayResize(fiboLevels,3);
      ArrayResize(fiboLabels,3);
      int idx=0;
      for(int i=0; i<ArraySize(baseLevels); i++)
        {
         if(MathAbs(baseLevels[i]-0.692)>=0.001)
           {
            fiboLevels[idx]=baseLevels[i];
            fiboLabels[idx]=baseLabels[i];
            idx++;
           }
        }
     }
   else
     {
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
   double range=leg_end_price-leg_start_price;
   datetime start_time=time[leg_start_pos];
   datetime end_time=time[leg_end_pos];

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

   for(int i=0; i<ArraySize(fiboLevels); i++)
     {
      double level_price=leg_start_price+range*(1.0-fiboLevels[i]);
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
//| Manage Square                                                     |
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

   if(legChanged)
     {
      SquareState previousState=squareState;
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
      activationTouched=false;
      breakoutDetectedAtBar=-1;
      activationTouchBar=-1;
      lockedLegStartPos=-1;
      lockedLegEndPos=-1;
      lockedLegStartPrice=0;
      lockedLegEndPrice=0;
      lockedLegColor=0;

      if(previousState!=SQUARE_NONE)
        {
         Print("═══ FIBONACCI DESTRAVADA ═══");
         Print("Motivo: Nova perna detectada - Reset completo");
         Print("Perna anterior end pos: ", currentLegEndPos);
         Print("Nova perna end pos: ", leg_end_pos);
        }
     }

   currentLegEndPos=leg_end_pos;

   double range=leg_end_price-leg_start_price;
   bool is_bullish=(ZigzagPeakBuffer[leg_start_pos]!=0.0) ? false : true;

   if(is_bullish)
     {
      fibo100Price=leg_start_price;
      fibo0Price=leg_end_price;
      fiboActivationPrice=leg_start_price+range*(1.0-InpActivationLevel);
      fibo110Price=leg_start_price+range*(1.0-1.10);
      squareDirection=1;
     }
   else
     {
      fibo100Price=leg_start_price;
      fibo0Price=leg_end_price;
      fiboActivationPrice=leg_start_price+range*(1.0-InpActivationLevel);
      fibo110Price=leg_start_price+range*(1.0-1.10);
      squareDirection=-1;
     }

   int current_bar=rates_total-1; // Última barra (arrays não são as_series)

//--- Detect activation touch
   if(!activationTouched)
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
            activationTouched=true;
            activationTouchBar=i;
            break;
           }
        }
     }
   else
     {
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

//--- STATE: NONE - Activate square after touch
   if(squareState==SQUARE_NONE && activationTouched && !squareUsedForCurrentLeg && activationTouchBar>=0)
     {
      squareState=SQUARE_ACTIVE;
      squareStartTime=time[activationTouchBar];
      squareStartBar=activationTouchBar;
      squareUsedForCurrentLeg=true;
      squareLockedAt110=false;
      last110CheckBar=activationTouchBar;

      if(is_bullish)
         squareBasePrice=low[activationTouchBar];
      else
         squareBasePrice=high[activationTouchBar];

      lockedLegStartPos=leg_start_pos;
      lockedLegEndPos=leg_end_pos;
      lockedLegStartPrice=leg_start_price;
      lockedLegEndPrice=leg_end_price;
      lockedLegColor=leg_color;

      Print("═══ FIBONACCI TRAVADA ═══");
      Print("Quadrado ativado - Fibo travada nos valores atuais da perna");
      Print("Leg start: ", leg_start_pos, " | Leg end: ", leg_end_pos);
      Print("Start price: ", DoubleToString(leg_start_price, _Digits));
      Print("End price: ", DoubleToString(leg_end_price, _Digits));
     }

//--- STATE: ACTIVE - Monitor for breakout or 110% breach
   if(squareState==SQUARE_ACTIVE)
     {
      int minStartBar=activationTouchBar>=0 ? activationTouchBar+1 : squareStartBar+1;
      int startCheckBar=(last110CheckBar>=minStartBar) ? last110CheckBar+1 : minStartBar;
      bool broke110=false;
      bool brokeSquare=false;
      int breakBar=-1;
      int endCheckBar=current_bar-1;
      if(rates_total>current_bar+1)
         endCheckBar=current_bar;

      //--- Debug: Log apenas na primeira execução
      static bool first_active_log=true;
      if(first_active_log)
        {
         Print("🔍 DEBUG ACTIVE STATE:");
         Print("   current_bar: ", current_bar);
         Print("   rates_total: ", rates_total);
         Print("   startCheckBar: ", startCheckBar);
         Print("   endCheckBar: ", endCheckBar);
         Print("   Loop irá executar: ", startCheckBar<=endCheckBar ? "SIM" : "NÃO");
         first_active_log=false;
        }

      for(int i=startCheckBar; i<=endCheckBar; i++)
        {
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
            break;
           }

         bool brokeSquareThisBar=false;
         if(is_bullish)
           {
            if(close[i]>squareTop)
               brokeSquareThisBar=true;
           }
         else
           {
            if(close[i]<squareBottom)
               brokeSquareThisBar=true;
           }

         if(brokeSquareThisBar)
           {
            brokeSquare=true;
            breakBar=i;
            breakoutBar=i;
            last110CheckBar=i;
            break;
           }

         last110CheckBar=i;
        }

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

      if(broke110)
        {
         squareLockedAt110=true;
         squareState=SQUARE_LOCKED;
         lockedLegStartPos=-1;
         lockedLegEndPos=-1;
         lockedLegStartPrice=0;
         lockedLegEndPrice=0;
         lockedLegColor=0;

         Print("═══ FIBONACCI DESTRAVADA ═══");
         Print("Motivo: 110% atingido - Quadrado travado");
        }
      else if(brokeSquare)
        {
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

         breakoutDetectedAtBar=current_bar;
         squareState=SQUARE_BREAKOUT_WAITING_TAKE;

         if(is_bullish)
            entryPrice=squareTop;
         else
            entryPrice=squareBottom;

         if(is_bullish)
            stopLossPrice=entryPrice-InpStopLoss*_Point;
         else
            stopLossPrice=entryPrice+InpStopLoss*_Point;

         if(is_bullish)
            entryLimitPrice=squareTop+InpEntryLimit*_Point;
         else
            entryLimitPrice=squareBottom-InpEntryLimit*_Point;
        }

      if(squareState==SQUARE_ACTIVE)
        {
         DrawSquare(time, current_bar, is_bullish);
        }
     }

//--- STATE: BREAKOUT_WAITING_TAKE
   if(squareState==SQUARE_BREAKOUT_WAITING_TAKE)
     {
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

      if(breakoutBar>=0 && breakoutBar<rates_total)
        {
         if(current_bar>breakoutBar)
           {
            bool realBreakout=false;
            if(is_bullish)
              {
               if(close[breakoutBar]>squareTop)
                  realBreakout=true;
              }
            else
              {
               if(close[breakoutBar]<squareBottom)
                  realBreakout=true;
              }

            if(realBreakout)
              {
               bool withinLimit=false;
               double maxEntryPrice=0.0, minEntryPrice=0.0;

               if(is_bullish)
                 {
                  maxEntryPrice=squareTop+InpEntryLimit*_Point;
                  if(close[breakoutBar]<=maxEntryPrice)
                    {
                     withinLimit=true;
                     takeActivationClosePrice=close[breakoutBar];
                     takeProfitPrice=takeActivationClosePrice+InpTakeProfit*_Point;
                    }
                 }
               else
                 {
                  minEntryPrice=squareBottom-InpEntryLimit*_Point;
                  if(close[breakoutBar]>=minEntryPrice)
                    {
                     withinLimit=true;
                     takeActivationClosePrice=close[breakoutBar];
                     takeProfitPrice=takeActivationClosePrice-InpTakeProfit*_Point;
                    }
                 }

               if(withinLimit)
                 {
                  takeActivated=true;
                  squareState=SQUARE_TAKE_ACTIVE;
                  Print("═══ TAKE ACTIVATED (EA) ═══");
                 }
               else
                 {
                  squareState=SQUARE_LOCKED;
                  lockedLegStartPos=-1;
                  lockedLegEndPos=-1;
                  lockedLegStartPrice=0;
                  lockedLegEndPrice=0;
                  lockedLegColor=0;

                  Print("═══ FIBONACCI DESTRAVADA ═══");
                  Print("Motivo: Limite de entrada violado - Quadrado travado");
                 }
              }
            else
              {
               squareState=SQUARE_ACTIVE;
              }
           }
        }

      DrawSquare(time, current_bar, is_bullish);
      DrawStopLoss(time, current_bar, is_bullish);

      if(takeActivated && squareState==SQUARE_TAKE_ACTIVE)
        {
         DrawTakeProfit(time, current_bar, is_bullish);
        }
     }

//--- STATE: TAKE_ACTIVE
   if(squareState==SQUARE_TAKE_ACTIVE)
     {
      bool hitTake=false;
      bool hitStop=false;
      int hitTakeBar=-1;
      int hitStopBar=-1;

      int startCheckBar=breakoutBar>=0 ? breakoutBar : squareStartBar;

      for(int i=startCheckBar; i<=current_bar; i++)
        {
         if(is_bullish)
           {
            if(!hitTake && high[i]>=takeProfitPrice)
              {
               hitTake=true;
               hitTakeBar=i;
              }
            if(!hitStop && low[i]<=stopLossPrice)
              {
               hitStop=true;
               hitStopBar=i;
              }
           }
         else
           {
            if(!hitTake && low[i]<=takeProfitPrice)
              {
               hitTake=true;
               hitTakeBar=i;
              }
            if(!hitStop && high[i]>=stopLossPrice)
              {
               hitStop=true;
               hitStopBar=i;
              }
           }

         if(hitTake && hitStop)
           {
            if(hitTakeBar<=hitStopBar)
              {
               hitStop=false;
              }
            else
              {
               hitTake=false;
              }
            break;
           }
        }

      if(hitTake && !hitStop)
        {
         hitTakeFirst=true;
         hitStopFirst=false;
         squareState=SQUARE_LOCKED;
         lockedLegStartPos=-1;
         lockedLegEndPos=-1;
         lockedLegStartPrice=0;
         lockedLegEndPrice=0;
         lockedLegColor=0;

         Print("═══ FIBONACCI DESTRAVADA ═══");
         Print("Motivo: Take Profit atingido ✓");
        }
      else if(hitStop && !hitTake)
        {
         hitStopFirst=true;
         hitTakeFirst=false;
         squareState=SQUARE_LOCKED;
         lockedLegStartPos=-1;
         lockedLegEndPos=-1;
         lockedLegStartPrice=0;
         lockedLegEndPrice=0;
         lockedLegColor=0;

         Print("═══ FIBONACCI DESTRAVADA ═══");
         Print("Motivo: Stop Loss atingido ✗");
        }

      DrawSquare(time, current_bar, is_bullish);
      DrawStopLoss(time, current_bar, is_bullish);
      DrawTakeProfit(time, current_bar, is_bullish);
     }

//--- STATE: LOCKED
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
   color squareColor=InpSquareColor;
   if(hitTakeFirst)
      squareColor=clrGreen;
   else if(hitStopFirst)
      squareColor=clrRed;

   datetime start_time=squareStartTime;
   int end_bar=squareStartBar+InpSquareWidth;
   if(end_bar>=ArraySize(time)) end_bar=ArraySize(time)-1;
   datetime end_time=time[end_bar];

   double price1, price2;
   if(is_bullish)
     {
      price1=squareBasePrice;
      price2=squareBasePrice+(InpSquareHeight*_Point);
     }
   else
     {
      price1=squareBasePrice-(InpSquareHeight*_Point);
      price2=squareBasePrice;
     }

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

   string entry_line_name=squarePrefix+"EntryLimit";
   if(squareState==SQUARE_ACTIVE || squareState==SQUARE_BREAKOUT_WAITING_TAKE || squareState==SQUARE_TAKE_ACTIVE)
     {
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
   color lineColor=InpSquareColor;
   if(hitTakeFirst)
      lineColor=clrGreen;
   else if(hitStopFirst)
      lineColor=clrRed;

   datetime start_time=squareStartTime;
   int end_bar=squareStartBar+InpSquareWidth;
   if(end_bar>=ArraySize(time)) end_bar=ArraySize(time)-1;
   datetime end_time=time[end_bar];

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
//| Draw Take Profit                                                  |
//+------------------------------------------------------------------+
void DrawTakeProfit(const datetime &time[], int current_bar, bool is_bullish)
  {
   if(!takeActivated)
      return;

   color lineColor=InpSquareColor;
   if(hitTakeFirst)
      lineColor=clrGreen;
   else if(hitStopFirst)
      lineColor=clrRed;

   datetime start_time=squareStartTime;
   int end_bar=squareStartBar+InpSquareWidth;
   if(end_bar>=ArraySize(time)) end_bar=ArraySize(time)-1;
   datetime end_time=time[end_bar];

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

   ObjectCreate(0,objPrefix+"Title",OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,objPrefix+"Title",OBJPROP_XDISTANCE,x+10);
   ObjectSetInteger(0,objPrefix+"Title",OBJPROP_YDISTANCE,y+5);
   ObjectSetInteger(0,objPrefix+"Title",OBJPROP_COLOR,clrYellow);
   ObjectSetInteger(0,objPrefix+"Title",OBJPROP_FONTSIZE,InpFontSize+1);
   ObjectSetString(0,objPrefix+"Title",OBJPROP_TEXT,"═══ ZIGZAG EA ═══");
   ObjectSetString(0,objPrefix+"Title",OBJPROP_FONT,"Arial Bold");

   string labels[]={"Status:","Procurando:","Último Extremo:","Barras Desde:","Progresso Tempo:","Movimento Preço:","Progresso Movimento:","Geral:","Status Quadrado:","Posição Aberta:"};

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
//| Get Square Status Text                                           |
//+------------------------------------------------------------------+
string GetSquareStatusText()
  {
   string status_text="";

   switch(squareState)
     {
      case SQUARE_NONE:
         if(!activationTouched)
           {
            double activationPercent=InpActivationLevel*100.0;
            status_text="Aguardando "+DoubleToString(activationPercent,1)+"%";
           }
         else
           {
            status_text="Sem quadrado";
           }
         break;

      case SQUARE_WAITING:
         status_text="Aguardando ativação";
         break;

      case SQUARE_ACTIVE:
         status_text="Aguardando entrada";
         break;

      case SQUARE_BREAKOUT_WAITING_TAKE:
         status_text="Aguardando take";
         break;

      case SQUARE_TAKE_ACTIVE:
         status_text="Aguardando take/stop";
         break;

      case SQUARE_LOCKED:
         if(squareLockedAt110)
           {
            status_text="Travado - 110%";
           }
         else if(hitTakeFirst)
           {
            status_text="Take ✓";
           }
         else if(hitStopFirst)
           {
            status_text="Stop ✗";
           }
         else
           {
            status_text="Travado - Limite";
           }
         break;
     }

   return status_text;
  }

//+------------------------------------------------------------------+
//| Get Square Status Color                                          |
//+------------------------------------------------------------------+
color GetSquareStatusColor()
  {
   color status_color=clrGray;

   switch(squareState)
     {
      case SQUARE_NONE:
         if(!activationTouched)
            status_color=clrYellow;
         else
            status_color=clrGray;
         break;

      case SQUARE_WAITING:
         status_color=clrYellow;
         break;

      case SQUARE_ACTIVE:
         status_color=clrOrange;
         break;

      case SQUARE_BREAKOUT_WAITING_TAKE:
         status_color=clrAqua;
         break;

      case SQUARE_TAKE_ACTIVE:
         status_color=clrCyan;
         break;

      case SQUARE_LOCKED:
         if(hitTakeFirst)
            status_color=clrLime;
         else if(hitStopFirst)
            status_color=clrRed;
         else
            status_color=clrOrange;
         break;
     }

   return status_color;
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

   int bars_since=0;
   double time_progress=0;
   double price_move=0;
   double move_progress=0;
   double overall_progress=0;
   string searching="";
   string status="Procurando...";
   color status_color=clrYellow;

   int current_bar=rates_total-1; // Última barra (arrays não são as_series)

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

   string square_status=GetSquareStatusText();
   color square_status_color=GetSquareStatusColor();

   string position_status=positionOpen ? "SIM (#"+IntegerToString(currentTicket)+")" : "NÃO";
   color position_color=positionOpen ? clrLime : clrGray;

   string values[10];
   values[0]=status;
   values[1]=searching;
   values[2]=(extreme_search==Peak) ? StringFormat("%."+IntegerToString(_Digits)+"f",last_low) :
                                       StringFormat("%."+IntegerToString(_Digits)+"f",last_high);
   values[3]=IntegerToString(bars_since)+" barras";
   values[4]=StringFormat("%.1f%%",time_progress);
   values[5]=StringFormat("%.1f pontos",price_move);
   values[6]=StringFormat("%.1f%%",move_progress);
   values[7]=StringFormat("%.1f%%",overall_progress);
   values[8]=square_status;
   values[9]=position_status;

   color colors[]={status_color,clrWhite,clrCyan,clrWhite,clrAqua,clrWhite,clrAqua,clrYellow,square_status_color,position_color};

   for(int i=0; i<10; i++)
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
   for(int i=start-1; i>start-count && i>=0; i--)
      if(res<array[i])
         res=array[i];
   return(res);
  }

//+------------------------------------------------------------------+
//| Get lowest value for range                                       |
//+------------------------------------------------------------------+
double Lowest(const double&array[],int count,int start)
  {
   double res=array[start];
   for(int i=start-1; i>start-count && i>=0; i--)
      if(res>array[i])
         res=array[i];
   return(res);
  }
//+------------------------------------------------------------------+
