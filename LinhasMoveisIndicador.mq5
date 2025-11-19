//+------------------------------------------------------------------+
//|                                      LinhasMoveisIndicador.mq5   |
//|                                  Indicador com Linhas Móveis     |
//+------------------------------------------------------------------+
#property copyright "EA Fibonacci - Indicador e Automatizado"
#property link      ""
#property version   "5.10"
#property indicator_chart_window
#property indicator_plots 0

#include <Trade\Trade.mqh>

CTrade trade;

//+------------------------------------------------------------------+
//| Parâmetros de entrada                                            |
//+------------------------------------------------------------------+
input group "=== Configurações dos Botões ==="
input int BotaoPosX = 190;         // Posição X dos botões (pixels da borda direita)
input int BotaoPosY = 30;          // Posição Y dos botões (pixels da borda superior)
input int BotaoLargura = 180;      // Largura dos botões
input int BotaoAltura = 45;        // Altura dos botões

input group "=== Posição das Tabelas de Status ==="
input int TabelaPosX = 500;        // Posição X das tabelas (pixels da borda direita)
input int TabelaPosY = 30;         // Posição Y das tabelas (pixels da borda superior)
input int TabelaLargura = 290;     // Largura das tabelas
input int TabelaAltura = 90;       // Altura das tabelas
input int AlturaCabecalho = 30;    // Altura do cabeçalho das tabelas
input int AjusteVerticalTitulo = 5; // Ajuste vertical do título (+ desce, - sobe)
input int AjusteVerticalTexto = 2;  // Ajuste vertical do texto (+ desce, - sobe)
input int TamanhoFonteTitulo = 11; // Tamanho da fonte do título
input int TamanhoFonteTexto = 10;  // Tamanho da fonte do texto
input string NomeFonte = "Segoe UI"; // Nome da fonte

input group "=== Configurações do Quadrado de Análise ==="
input int AlturaQuadrado = 400;    // Altura do quadrado em pontos

input group "=== Configurações do EA (Expert Advisor) ==="
input bool HabilitarEA = false;    // Habilitar negociação automática
input double Lote = 0.01;          // Volume de lote
input int MagicNumber = 123456;    // Número mágico
input string Comentario = "EA Fibo"; // Comentário da ordem

// Nomes dos objetos
string nomeLinhaHorizontalSuperior = "LinhaH_Superior";
string nomeLinhaHorizontalCentro = "LinhaH_Centro";
string nomeLinhaVerticalEsquerda = "LinhaV_Esquerda";
string nomeLinhaVerticalDireita = "LinhaV_Direita";
string nomeLinhaVerticalAzul = "LinhaV_Azul";
string nomePontoLinhaAzul = "Ponto_LinhaAzul";

// Nomes dos pontos de controle (cruzamentos)
string nomePontoSuperiorEsquerda = "Ponto_SE";
string nomePontoSuperiorDireita = "Ponto_SD";
string nomePontoCentroEsquerda = "Ponto_CE";
string nomePontoCentroDireita = "Ponto_CD";

// Nomes das linhas de Fibonacci
string nomeLinhaFibo618 = "Fibo_618";
string nomeLinhaFibo764 = "Fibo_764";

// Nome dos botões
string nomeBotaoAnalisar = "Botao_Analisar";
string nomeBotaoInverterFibo = "Botao_InverterFibo";
string nomeBotaoReset = "Botao_Reset";
string nomeBotaoTravar = "Botao_Travar";

// Nome do quadrado de análise e linhas de referência
string nomeQuadradoAnalise = "Quadrado_Analise";
string nomeLinhaLimite20 = "Linha_Limite_20";
string nomeLinhaLimiteEntrada = "Linha_Limite_Entrada"; // Linha do limite máximo de entrada (Base + 800)
string nomeLinhaStopLoss = "Linha_StopLoss"; // Linha vermelha do Stop Loss (Base - 125)

// Nomes das tabelas de status
string nomeLabelStatusAnalise = "Label_StatusAnalise";
string nomeLabelStatusTravamento = "Label_StatusTravamento";

// Variáveis de controle da análise
bool fiboInvertida = false;     // Controla se a Fibonacci está invertida
bool analiseAtiva = false;      // Controla se a análise está ativa
bool monitorandoAntesFibo = false; // Monitorando antes de tocar na Fibo 61.8
bool tocouFibo618 = false;      // Se já tocou na linha Fibo 61.8
int barraInicioMonitoramento = -1; // Índice da barra onde iniciou o monitoramento (linha azul)
int barraInicio = -1;           // Índice da barra onde iniciou a análise
datetime tempoInicioQuadrado = 0; // Tempo de início do quadrado (primeira vez que tocou na Fibo)
double fundoAtual = 0;          // Fundo atual do quadrado
bool rompeuTopo = false;        // Se já rompeu o topo do quadrado
bool linhasTravadas = false;    // Controla se as linhas estão travadas

// Variáveis de controle do EA
bool jaOperou = false;          // Controla se já realizou a operação (só opera 1 vez)
ulong ticketOrdem = 0;          // Ticket da ordem aberta

//+------------------------------------------------------------------+
//| Função de inicialização do indicador                             |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("Iniciando indicador LinhasMoveisIndicador v4.10 com parâmetros ajustáveis...");

   // Obtém o preço máximo e mínimo visível no gráfico
   double precoMaximo = ChartGetDouble(0, CHART_PRICE_MAX, 0);
   double precoMinimo = ChartGetDouble(0, CHART_PRICE_MIN, 0);

   if(precoMaximo <= precoMinimo)
   {
      Print("ERRO: Preços inválidos. Max=", precoMaximo, " Min=", precoMinimo);
      return(INIT_FAILED);
   }

   double precoCentro = (precoMaximo + precoMinimo) / 2.0;
   double precoSuperior = precoCentro + (precoMaximo - precoMinimo) * 0.25;

   Print("Preços calculados - Superior: ", precoSuperior, " Centro: ", precoCentro);

   // Obtém informações sobre as barras visíveis
   int primeiraBarraVisivel = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
   int barrasVisiveis = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);

   Print("Barras - Primeira visível: ", primeiraBarraVisivel, " Total visível: ", barrasVisiveis);

   // Calcula posição para linha vertical esquerda (75% das barras visíveis)
   int indiceBarraEsquerda = (int)MathMin(primeiraBarraVisivel - (barrasVisiveis / 4), Bars(_Symbol, _Period) - 1);
   if(indiceBarraEsquerda < 0) indiceBarraEsquerda = 0;

   datetime tempoEsquerda = iTime(_Symbol, _Period, indiceBarraEsquerda);

   Print("Tempo esquerda calculado: ", TimeToString(tempoEsquerda), " índice: ", indiceBarraEsquerda);

   // Cria linha horizontal superior
   CriarLinhaHorizontal(nomeLinhaHorizontalSuperior, precoSuperior);

   // Cria linha horizontal no centro
   CriarLinhaHorizontal(nomeLinhaHorizontalCentro, precoCentro);

   // Cria linha vertical esquerda
   CriarLinhaVertical(nomeLinhaVerticalEsquerda, tempoEsquerda);

   // Cria pontos de controle nos cruzamentos (apenas esquerda)
   CriarPontoControle(nomePontoSuperiorEsquerda, tempoEsquerda, precoSuperior);
   CriarPontoControle(nomePontoCentroEsquerda, tempoEsquerda, precoCentro);

   // Cria linha vertical azul
   CriarLinhaVerticalAzul();

   // Cria as linhas de Fibonacci
   AtualizarLinhasFibonacci();

   // Cria os botões
   CriarBotaoAnalisar();
   CriarBotaoInverterFibo();
   CriarBotaoReset();
   CriarBotaoTravar();

   // Cria as tabelas de status
   CriarTabelaStatus();

   // Inicializa variáveis
   fiboInvertida = false;
   analiseAtiva = false;
   monitorandoAntesFibo = false;
   tocouFibo618 = false;
   barraInicioMonitoramento = -1;
   tempoInicioQuadrado = 0;
   rompeuTopo = false;
   linhasTravadas = false;

   // Inicializa variáveis do EA
   jaOperou = false;
   ticketOrdem = 0;

   // Força atualização do gráfico
   ChartRedraw(0);

   Print("Indicador inicializado com sucesso!");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Função para criar linha horizontal                               |
//+------------------------------------------------------------------+
void CriarLinhaHorizontal(string nome, double preco)
{
   // Remove linha se já existir
   if(ObjectFind(0, nome) >= 0)
   {
      Print("Removendo linha horizontal existente: ", nome);
      ObjectDelete(0, nome);
   }

   // Cria a linha horizontal
   if(!ObjectCreate(0, nome, OBJ_HLINE, 0, 0, preco))
   {
      Print("ERRO ao criar linha horizontal: ", nome, " Erro: ", GetLastError());
      return;
   }

   // Define propriedades da linha
   ObjectSetInteger(0, nome, OBJPROP_COLOR, clrBlack);        // Cor preta
   ObjectSetInteger(0, nome, OBJPROP_STYLE, STYLE_SOLID);     // Linha sólida
   ObjectSetInteger(0, nome, OBJPROP_WIDTH, 4);               // Largura da linha (mais grossa)
   ObjectSetInteger(0, nome, OBJPROP_BACK, false);            // Linha na frente
   ObjectSetInteger(0, nome, OBJPROP_SELECTABLE, false);      // NÃO pode ser selecionada
   ObjectSetInteger(0, nome, OBJPROP_SELECTED, false);        // Não selecionada inicialmente
   ObjectSetInteger(0, nome, OBJPROP_HIDDEN, false);          // Visível
   ObjectSetInteger(0, nome, OBJPROP_ZORDER, 0);              // Ordem Z

   // Descrição da linha
   ObjectSetString(0, nome, OBJPROP_TEXT, "Linha horizontal");

   Print("Linha horizontal criada: ", nome, " no preço: ", preco);
}

//+------------------------------------------------------------------+
//| Função para criar linha vertical                                 |
//+------------------------------------------------------------------+
void CriarLinhaVertical(string nome, datetime tempo)
{
   // Remove linha se já existir
   if(ObjectFind(0, nome) >= 0)
   {
      Print("Removendo linha vertical existente: ", nome);
      ObjectDelete(0, nome);
   }

   // Cria a linha vertical
   if(!ObjectCreate(0, nome, OBJ_VLINE, 0, tempo, 0))
   {
      Print("ERRO ao criar linha vertical: ", nome, " Erro: ", GetLastError());
      return;
   }

   // Define propriedades da linha
   ObjectSetInteger(0, nome, OBJPROP_COLOR, clrBlack);        // Cor preta
   ObjectSetInteger(0, nome, OBJPROP_STYLE, STYLE_SOLID);     // Linha sólida
   ObjectSetInteger(0, nome, OBJPROP_WIDTH, 4);               // Largura da linha (mais grossa)
   ObjectSetInteger(0, nome, OBJPROP_BACK, false);            // Linha na frente
   ObjectSetInteger(0, nome, OBJPROP_SELECTABLE, false);      // NÃO pode ser selecionada
   ObjectSetInteger(0, nome, OBJPROP_SELECTED, false);        // Não selecionada inicialmente
   ObjectSetInteger(0, nome, OBJPROP_HIDDEN, false);          // Visível
   ObjectSetInteger(0, nome, OBJPROP_ZORDER, 0);              // Ordem Z

   // Descrição da linha
   ObjectSetString(0, nome, OBJPROP_TEXT, "Linha vertical");

   Print("Linha vertical criada: ", nome, " no tempo: ", TimeToString(tempo));
}

//+------------------------------------------------------------------+
//| Função para criar linha vertical azul                            |
//+------------------------------------------------------------------+
void CriarLinhaVerticalAzul()
{
   // Obtém posição da linha vertical preta esquerda
   datetime tempoEsquerda = (datetime)ObjectGetInteger(0, nomeLinhaVerticalEsquerda, OBJPROP_TIME);

   if(tempoEsquerda == 0)
   {
      Print("ERRO: Linha vertical esquerda não encontrada");
      return;
   }

   // Encontra o índice da barra da linha esquerda
   int indiceEsquerda = iBarShift(_Symbol, _Period, tempoEsquerda);

   if(indiceEsquerda < 0)
   {
      Print("ERRO: Não foi possível encontrar índice da barra esquerda");
      return;
   }

   // Calcula tempo para a linha azul (algumas barras à direita da linha esquerda)
   int barrasVisiveis = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
   int barrasOffset = (int)MathMax(barrasVisiveis / 8, 5); // Mínimo de 5 barras
   int indiceAzul = indiceEsquerda - barrasOffset;

   if(indiceAzul < 0) indiceAzul = 0;

   datetime tempoAzul = iTime(_Symbol, _Period, indiceAzul);

   Print("Linha azul - Índice esquerda: ", indiceEsquerda, " Offset: ", barrasOffset, " Índice azul: ", indiceAzul);

   // Obtém preço médio (entre superior e centro)
   double precoSuperior = ObjectGetDouble(0, nomeLinhaHorizontalSuperior, OBJPROP_PRICE);
   double precoCentro = ObjectGetDouble(0, nomeLinhaHorizontalCentro, OBJPROP_PRICE);
   double precoMeio = (precoSuperior + precoCentro) / 2.0;

   // Remove linha se já existir
   if(ObjectFind(0, nomeLinhaVerticalAzul) >= 0)
      ObjectDelete(0, nomeLinhaVerticalAzul);

   // Cria a linha vertical azul
   if(!ObjectCreate(0, nomeLinhaVerticalAzul, OBJ_VLINE, 0, tempoAzul, 0))
   {
      Print("ERRO ao criar linha vertical azul. Erro: ", GetLastError());
      return;
   }

   // Define propriedades da linha
   ObjectSetInteger(0, nomeLinhaVerticalAzul, OBJPROP_COLOR, clrBlue);        // Cor azul
   ObjectSetInteger(0, nomeLinhaVerticalAzul, OBJPROP_STYLE, STYLE_SOLID);     // Linha sólida
   ObjectSetInteger(0, nomeLinhaVerticalAzul, OBJPROP_WIDTH, 6);                // Largura grossa
   ObjectSetInteger(0, nomeLinhaVerticalAzul, OBJPROP_BACK, false);            // Linha na frente
   ObjectSetInteger(0, nomeLinhaVerticalAzul, OBJPROP_SELECTABLE, false);      // NÃO pode ser selecionada
   ObjectSetInteger(0, nomeLinhaVerticalAzul, OBJPROP_SELECTED, false);        // Não selecionada
   ObjectSetInteger(0, nomeLinhaVerticalAzul, OBJPROP_HIDDEN, false);          // Visível
   ObjectSetInteger(0, nomeLinhaVerticalAzul, OBJPROP_ZORDER, 2);              // Na frente das pretas

   // Descrição da linha
   ObjectSetString(0, nomeLinhaVerticalAzul, OBJPROP_TEXT, "Linha vertical azul - início da análise");

   Print("Linha vertical azul criada no tempo: ", TimeToString(tempoAzul));

   // Cria o ponto de controle vermelho no meio da linha
   CriarPontoLinhaAzul(tempoAzul, precoMeio);
}

//+------------------------------------------------------------------+
//| Função para criar ponto de controle da linha azul                |
//+------------------------------------------------------------------+
void CriarPontoLinhaAzul(datetime tempo, double preco)
{
   // Remove ponto se já existir
   if(ObjectFind(0, nomePontoLinhaAzul) >= 0)
      ObjectDelete(0, nomePontoLinhaAzul);

   // Cria um objeto Arrow como ponto de controle
   if(!ObjectCreate(0, nomePontoLinhaAzul, OBJ_ARROW, 0, tempo, preco))
   {
      Print("ERRO ao criar ponto da linha azul. Erro: ", GetLastError());
      return;
   }

   // Define propriedades do ponto
   ObjectSetInteger(0, nomePontoLinhaAzul, OBJPROP_COLOR, clrRed);           // Cor vermelha
   ObjectSetInteger(0, nomePontoLinhaAzul, OBJPROP_ARROWCODE, 159);          // Código do símbolo (círculo)
   ObjectSetInteger(0, nomePontoLinhaAzul, OBJPROP_WIDTH, 6);                // Largura/tamanho
   ObjectSetInteger(0, nomePontoLinhaAzul, OBJPROP_BACK, false);             // Na frente
   ObjectSetInteger(0, nomePontoLinhaAzul, OBJPROP_SELECTABLE, true);        // PODE ser selecionado
   ObjectSetInteger(0, nomePontoLinhaAzul, OBJPROP_SELECTED, false);         // Não selecionado inicialmente
   ObjectSetInteger(0, nomePontoLinhaAzul, OBJPROP_HIDDEN, false);           // Visível
   ObjectSetInteger(0, nomePontoLinhaAzul, OBJPROP_ZORDER, 3);               // Na frente de tudo

   // Descrição do ponto
   ObjectSetString(0, nomePontoLinhaAzul, OBJPROP_TEXT, "Arraste horizontalmente para mover a linha azul");

   Print("Ponto da linha azul criado");
}

//+------------------------------------------------------------------+
//| Função para atualizar linha azul quando o ponto é arrastado      |
//+------------------------------------------------------------------+
void AtualizarLinhaAzul()
{
   // Obtém a nova posição do ponto (apenas tempo, mantém preço fixo)
   datetime novoTempo = (datetime)ObjectGetInteger(0, nomePontoLinhaAzul, OBJPROP_TIME);

   // Obtém limite da linha vertical preta esquerda
   datetime tempoEsquerda = (datetime)ObjectGetInteger(0, nomeLinhaVerticalEsquerda, OBJPROP_TIME);

   // Garante que a linha azul fique à direita da linha preta esquerda
   if(novoTempo < tempoEsquerda)
      novoTempo = tempoEsquerda;

   // Obtém preço médio (mantém fixo no meio vertical)
   double precoSuperior = ObjectGetDouble(0, nomeLinhaHorizontalSuperior, OBJPROP_PRICE);
   double precoCentro = ObjectGetDouble(0, nomeLinhaHorizontalCentro, OBJPROP_PRICE);
   double precoMeio = (precoSuperior + precoCentro) / 2.0;

   // Atualiza a linha vertical azul
   ObjectSetInteger(0, nomeLinhaVerticalAzul, OBJPROP_TIME, novoTempo);

   // Atualiza o ponto (mantém preço no meio, só muda o tempo)
   ObjectSetInteger(0, nomePontoLinhaAzul, OBJPROP_TIME, novoTempo);
   ObjectSetDouble(0, nomePontoLinhaAzul, OBJPROP_PRICE, precoMeio);
}

//+------------------------------------------------------------------+
//| Função para reposicionar linha azul                              |
//+------------------------------------------------------------------+
void ReposicionarLinhaAzul()
{
   // Obtém posição da linha vertical preta esquerda
   datetime tempoEsquerda = (datetime)ObjectGetInteger(0, nomeLinhaVerticalEsquerda, OBJPROP_TIME);

   if(tempoEsquerda == 0) return;

   int indiceEsquerda = iBarShift(_Symbol, _Period, tempoEsquerda);
   if(indiceEsquerda < 0) return;

   // Calcula tempo para a linha azul (algumas barras à direita)
   int barrasVisiveis = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
   int barrasOffset = (int)MathMax(barrasVisiveis / 8, 5);
   int indiceAzul = indiceEsquerda - barrasOffset;

   if(indiceAzul < 0) indiceAzul = 0;

   datetime tempoAzul = iTime(_Symbol, _Period, indiceAzul);

   // Obtém preço médio
   double precoSuperior = ObjectGetDouble(0, nomeLinhaHorizontalSuperior, OBJPROP_PRICE);
   double precoCentro = ObjectGetDouble(0, nomeLinhaHorizontalCentro, OBJPROP_PRICE);
   double precoMeio = (precoSuperior + precoCentro) / 2.0;

   // Atualiza a linha azul
   ObjectSetInteger(0, nomeLinhaVerticalAzul, OBJPROP_TIME, tempoAzul);

   // Atualiza o ponto
   ObjectSetInteger(0, nomePontoLinhaAzul, OBJPROP_TIME, tempoAzul);
   ObjectSetDouble(0, nomePontoLinhaAzul, OBJPROP_PRICE, precoMeio);
}

//+------------------------------------------------------------------+
//| Função para criar ponto de controle (cruzamento)                 |
//+------------------------------------------------------------------+
void CriarPontoControle(string nome, datetime tempo, double preco)
{
   // Remove ponto se já existir
   if(ObjectFind(0, nome) >= 0)
      ObjectDelete(0, nome);

   // Cria um objeto Arrow como ponto de controle
   if(!ObjectCreate(0, nome, OBJ_ARROW, 0, tempo, preco))
   {
      Print("ERRO ao criar ponto de controle: ", nome, " Erro: ", GetLastError());
      return;
   }

   // Define propriedades do ponto
   ObjectSetInteger(0, nome, OBJPROP_COLOR, clrRed);           // Cor vermelha para destaque
   ObjectSetInteger(0, nome, OBJPROP_ARROWCODE, 159);          // Código do símbolo (círculo)
   ObjectSetInteger(0, nome, OBJPROP_WIDTH, 5);                // Largura/tamanho
   ObjectSetInteger(0, nome, OBJPROP_BACK, false);             // Na frente
   ObjectSetInteger(0, nome, OBJPROP_SELECTABLE, true);        // PODE ser selecionado
   ObjectSetInteger(0, nome, OBJPROP_SELECTED, false);         // Não selecionado inicialmente
   ObjectSetInteger(0, nome, OBJPROP_HIDDEN, false);           // Visível
   ObjectSetInteger(0, nome, OBJPROP_ZORDER, 1);               // Na frente das linhas

   // Descrição do ponto
   ObjectSetString(0, nome, OBJPROP_TEXT, "Arraste para mover as linhas");

   Print("Ponto de controle criado: ", nome);
}

//+------------------------------------------------------------------+
//| Função para atualizar linhas de Fibonacci                        |
//+------------------------------------------------------------------+
void AtualizarLinhasFibonacci()
{
   double preco0, preco100;

   if(fiboInvertida)
   {
      // Fibonacci invertida: 0% = Superior Esquerda, 100% = Centro Esquerda
      preco0 = ObjectGetDouble(0, nomePontoSuperiorEsquerda, OBJPROP_PRICE);
      preco100 = ObjectGetDouble(0, nomePontoCentroEsquerda, OBJPROP_PRICE);
   }
   else
   {
      // Fibonacci normal: 0% = Centro Esquerda, 100% = Superior Esquerda
      preco0 = ObjectGetDouble(0, nomePontoCentroEsquerda, OBJPROP_PRICE);
      preco100 = ObjectGetDouble(0, nomePontoSuperiorEsquerda, OBJPROP_PRICE);
   }

   // Calcula a diferença total
   double diferencaTotal = preco100 - preco0;

   // Calcula os níveis de Fibonacci
   double preco618 = preco0 + (diferencaTotal * 0.618);
   double preco764 = preco0 + (diferencaTotal * 0.764);

   // Cria ou atualiza linha 61.8%
   if(ObjectFind(0, nomeLinhaFibo618) < 0)
   {
      ObjectCreate(0, nomeLinhaFibo618, OBJ_HLINE, 0, 0, preco618);
      ObjectSetInteger(0, nomeLinhaFibo618, OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, nomeLinhaFibo618, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, nomeLinhaFibo618, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, nomeLinhaFibo618, OBJPROP_BACK, false);
      ObjectSetInteger(0, nomeLinhaFibo618, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, nomeLinhaFibo618, OBJPROP_TEXT, "Fibonacci 61.8%");
      Print("Linha Fibonacci 61.8% criada");
   }
   else
   {
      ObjectSetDouble(0, nomeLinhaFibo618, OBJPROP_PRICE, preco618);
      ObjectSetInteger(0, nomeLinhaFibo618, OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, nomeLinhaFibo618, OBJPROP_STYLE, STYLE_DASH);
   }

   // Cria ou atualiza linha 76.4%
   if(ObjectFind(0, nomeLinhaFibo764) < 0)
   {
      ObjectCreate(0, nomeLinhaFibo764, OBJ_HLINE, 0, 0, preco764);
      ObjectSetInteger(0, nomeLinhaFibo764, OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, nomeLinhaFibo764, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, nomeLinhaFibo764, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, nomeLinhaFibo764, OBJPROP_BACK, false);
      ObjectSetInteger(0, nomeLinhaFibo764, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, nomeLinhaFibo764, OBJPROP_TEXT, "Fibonacci 76.4%");
      Print("Linha Fibonacci 76.4% criada");
   }
   else
   {
      ObjectSetDouble(0, nomeLinhaFibo764, OBJPROP_PRICE, preco764);
      ObjectSetInteger(0, nomeLinhaFibo764, OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, nomeLinhaFibo764, OBJPROP_STYLE, STYLE_DASH);
   }
}

//+------------------------------------------------------------------+
//| Função para criar ou atualizar a linha do limite de 20%          |
//+------------------------------------------------------------------+
void CriarLinhaLimite20()
{
   // Calcula o limite de 20%
   double precoLinhaHorizontalSuperior = ObjectGetDouble(0, nomeLinhaHorizontalSuperior, OBJPROP_PRICE);
   double precoLinhaHorizontalCentro = ObjectGetDouble(0, nomeLinhaHorizontalCentro, OBJPROP_PRICE);
   double diferencaLinhas = precoLinhaHorizontalSuperior - precoLinhaHorizontalCentro;
   double tolerancia20Porcento = diferencaLinhas * 0.20;
   double limiteInferior = precoLinhaHorizontalCentro - tolerancia20Porcento;

   // Remove linha se já existir
   if(ObjectFind(0, nomeLinhaLimite20) >= 0)
      ObjectDelete(0, nomeLinhaLimite20);

   // Cria a linha horizontal tracejada
   if(!ObjectCreate(0, nomeLinhaLimite20, OBJ_HLINE, 0, 0, limiteInferior))
   {
      Print("ERRO ao criar linha limite 20%. Erro: ", GetLastError());
      return;
   }

   // Define propriedades da linha
   ObjectSetInteger(0, nomeLinhaLimite20, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, nomeLinhaLimite20, OBJPROP_STYLE, STYLE_DASH);  // Tracejada
   ObjectSetInteger(0, nomeLinhaLimite20, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, nomeLinhaLimite20, OBJPROP_BACK, false);
   ObjectSetInteger(0, nomeLinhaLimite20, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nomeLinhaLimite20, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, nomeLinhaLimite20, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, nomeLinhaLimite20, OBJPROP_ZORDER, 0);

   ObjectSetString(0, nomeLinhaLimite20, OBJPROP_TEXT, "Limite 20% - Fundo");

   Print("Linha limite 20% criada no preço: ", limiteInferior);
}

//+------------------------------------------------------------------+
//| Função para criar linha do limite máximo de entrada (Base + 800) |
//+------------------------------------------------------------------+
void CriarLinhaLimiteEntrada(double precoBase)
{
   // Remove linha se já existir
   if(ObjectFind(0, nomeLinhaLimiteEntrada) >= 0)
      ObjectDelete(0, nomeLinhaLimiteEntrada);

   // Calcula o limite máximo de entrada: Base + 800 pontos
   double limiteMaximoEntrada = precoBase + (800 * _Point);

   // Cria a linha horizontal fina
   if(!ObjectCreate(0, nomeLinhaLimiteEntrada, OBJ_HLINE, 0, 0, limiteMaximoEntrada))
   {
      Print("ERRO ao criar linha limite entrada. Erro: ", GetLastError());
      return;
   }

   // Define propriedades da linha (bem fina e azul claro)
   ObjectSetInteger(0, nomeLinhaLimiteEntrada, OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, nomeLinhaLimiteEntrada, OBJPROP_STYLE, STYLE_DOT);  // Pontilhada
   ObjectSetInteger(0, nomeLinhaLimiteEntrada, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, nomeLinhaLimiteEntrada, OBJPROP_BACK, false);
   ObjectSetInteger(0, nomeLinhaLimiteEntrada, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nomeLinhaLimiteEntrada, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, nomeLinhaLimiteEntrada, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, nomeLinhaLimiteEntrada, OBJPROP_ZORDER, 0);

   ObjectSetString(0, nomeLinhaLimiteEntrada, OBJPROP_TEXT, "Limite Máximo Entrada (Base + 800)");

   Print("Linha limite entrada criada no preço: ", limiteMaximoEntrada);
}

//+------------------------------------------------------------------+
//| Função para criar linha vermelha do Stop Loss (Base - 125)       |
//+------------------------------------------------------------------+
void CriarLinhaStopLoss(double precoBase)
{
   // Remove linha se já existir
   if(ObjectFind(0, nomeLinhaStopLoss) >= 0)
      ObjectDelete(0, nomeLinhaStopLoss);

   // Calcula o nível do Stop Loss: Base - 125 pontos
   double nivelStopLoss = precoBase - (125 * _Point);

   // Cria a linha horizontal
   if(!ObjectCreate(0, nomeLinhaStopLoss, OBJ_HLINE, 0, 0, nivelStopLoss))
   {
      Print("ERRO ao criar linha Stop Loss. Erro: ", GetLastError());
      return;
   }

   // Define propriedades da linha (vermelha, tracejada)
   ObjectSetInteger(0, nomeLinhaStopLoss, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, nomeLinhaStopLoss, OBJPROP_STYLE, STYLE_DASH);  // Tracejada
   ObjectSetInteger(0, nomeLinhaStopLoss, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, nomeLinhaStopLoss, OBJPROP_BACK, false);
   ObjectSetInteger(0, nomeLinhaStopLoss, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nomeLinhaStopLoss, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, nomeLinhaStopLoss, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, nomeLinhaStopLoss, OBJPROP_ZORDER, 0);

   ObjectSetString(0, nomeLinhaStopLoss, OBJPROP_TEXT, "Stop Loss (Base - 125 pontos)");

   Print("Linha Stop Loss criada no preço: ", nivelStopLoss);
}

//+------------------------------------------------------------------+
//| Função para criar ou atualizar o quadrado de análise             |
//+------------------------------------------------------------------+
void CriarQuadradoAnalise(datetime tempoInicio, double precoBase, int larguraVelas)
{
   // Remove quadrado existente
   if(ObjectFind(0, nomeQuadradoAnalise) >= 0)
      ObjectDelete(0, nomeQuadradoAnalise);

   // Calcula o tempo final - SEMPRE até a barra atual + projeção futura
   int indiceInicio = iBarShift(_Symbol, _Period, tempoInicio);

   // O retângulo vai desde a barra de início até a barra atual (0)
   // Adiciona uma projeção de 20 barras para o futuro para ficar visível
   datetime tempoFim = iTime(_Symbol, _Period, 0) + (PeriodSeconds(_Period) * 20);

   // Altura do quadrado em pontos (usa parâmetro configurável)
   double alturaEmPreco = AlturaQuadrado * _Point;
   double precoTopo = precoBase + alturaEmPreco;

   Print("Criando quadrado - Base: ", precoBase, " Topo: ", precoTopo, " Tempo início: ", TimeToString(tempoInicio), " Tempo fim: ", TimeToString(tempoFim));

   // Cria o retângulo
   if(!ObjectCreate(0, nomeQuadradoAnalise, OBJ_RECTANGLE, 0, tempoInicio, precoBase, tempoFim, precoTopo))
   {
      Print("ERRO ao criar quadrado de análise. Erro: ", GetLastError());
      return;
   }

   // Define propriedades do quadrado
   ObjectSetInteger(0, nomeQuadradoAnalise, OBJPROP_COLOR, clrGreen);
   ObjectSetInteger(0, nomeQuadradoAnalise, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, nomeQuadradoAnalise, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, nomeQuadradoAnalise, OBJPROP_BACK, false);
   ObjectSetInteger(0, nomeQuadradoAnalise, OBJPROP_FILL, false);
   ObjectSetInteger(0, nomeQuadradoAnalise, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nomeQuadradoAnalise, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, nomeQuadradoAnalise, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, nomeQuadradoAnalise, OBJPROP_ZORDER, 5);
   ObjectSetInteger(0, nomeQuadradoAnalise, OBJPROP_RAY_RIGHT, true); // Estende para direita

   ObjectSetString(0, nomeQuadradoAnalise, OBJPROP_TEXT, "Quadrado de Análise - 400 pontos");

   // Cria linhas de referência para o EA
   CriarLinhaLimiteEntrada(precoBase);  // Linha azul: limite máximo de entrada (Base + 800)
   CriarLinhaStopLoss(precoBase);       // Linha vermelha: Stop Loss (Base - 125)

   Print("Quadrado de análise criado - Base: ", precoBase, " Topo: ", precoTopo);
}

//+------------------------------------------------------------------+
//| Função principal de análise Fibonacci                            |
//+------------------------------------------------------------------+
void AnalisarFibonacci()
{
   Print("===== INICIANDO ANÁLISE FIBONACCI =====");

   // Remove quadrado e linha limite anteriores se existirem
   if(ObjectFind(0, nomeQuadradoAnalise) >= 0)
      ObjectDelete(0, nomeQuadradoAnalise);
   if(ObjectFind(0, nomeLinhaLimite20) >= 0)
      ObjectDelete(0, nomeLinhaLimite20);

   // Obtém os preços das linhas Fibonacci e horizontais
   double preco618 = ObjectGetDouble(0, nomeLinhaFibo618, OBJPROP_PRICE);
   double preco764 = ObjectGetDouble(0, nomeLinhaFibo764, OBJPROP_PRICE);
   double precoLinhaHorizontalSuperior = ObjectGetDouble(0, nomeLinhaHorizontalSuperior, OBJPROP_PRICE);
   double precoLinhaHorizontalCentro = ObjectGetDouble(0, nomeLinhaHorizontalCentro, OBJPROP_PRICE);

   Print("Preços Fibonacci - 61.8%: ", preco618, " | 76.4%: ", preco764);
   Print("Linhas Horizontais - Superior: ", precoLinhaHorizontalSuperior, " | Centro: ", precoLinhaHorizontalCentro);

   // Verifica se 76.4 está abaixo de 61.8
   if(preco764 >= preco618)
   {
      Print("CONDIÇÃO NÃO ATENDIDA: 76.4 não está abaixo de 61.8");
      Alert("Análise não pode ser executada: 76.4 deve estar abaixo de 61.8");
      return;
   }

   Print("CONDIÇÃO OK: 76.4 está abaixo de 61.8");

   // Obtém a posição da linha azul (início do monitoramento)
   datetime tempoLinhaAzul = (datetime)ObjectGetInteger(0, nomeLinhaVerticalAzul, OBJPROP_TIME);
   int indiceLinhaAzul = iBarShift(_Symbol, _Period, tempoLinhaAzul);

   if(indiceLinhaAzul < 0)
   {
      Print("ERRO: Não foi possível encontrar a barra da linha azul");
      return;
   }

   Print("Linha azul - Tempo: ", TimeToString(tempoLinhaAzul), " | Índice: ", indiceLinhaAzul);

   // VERIFICA SE O PREÇO JÁ COMEÇOU ABAIXO DA FIBO 61.8
   double closeLinhaAzul = iClose(_Symbol, _Period, indiceLinhaAzul);
   if(closeLinhaAzul < preco618)
   {
      Print("ERRO: O preço na linha azul já está ABAIXO da Fibo 61.8! Close: ", closeLinhaAzul, " | Fibo: ", preco618);
      Alert("REPOSICIONE A FIBO: O preço na linha azul já começou abaixo da Fibonacci 61.8%");
      return;
   }

   // Calcula os limites para verificação de rompimento
   double diferencaLinhas = precoLinhaHorizontalSuperior - precoLinhaHorizontalCentro;
   double tolerancia20Porcento = diferencaLinhas * 0.20;
   double limiteInferior = precoLinhaHorizontalCentro - tolerancia20Porcento;

   // ========== ANÁLISE DO HISTÓRICO DESDE A LINHA AZUL ==========
   Print("Iniciando análise do histórico desde a linha azul...");

   bool jaTocouNaFibo = false;
   int indiceToqueFibo = -1;
   double fundoQuadrado = 0;
   datetime tempoQuadrado;

   // Percorre o histórico desde a linha azul até o presente
   for(int i = indiceLinhaAzul; i >= 0; i--)
   {
      double high_i = iHigh(_Symbol, _Period, i);
      double low_i = iLow(_Symbol, _Period, i);
      double close_i = iClose(_Symbol, _Period, i);
      datetime tempo_i = iTime(_Symbol, _Period, i);

      // ===== FASE 1: ANTES DE TOCAR NA FIBO =====
      if(!jaTocouNaFibo)
      {
         // Verifica se fechou acima da linha superior ANTES de tocar na Fibo
         if(close_i > precoLinhaHorizontalSuperior)
         {
            Print("TOPO SUPERADO antes de tocar na Fibo! Barra: ", i, " Close: ", close_i);
            Alert("TOPO SUPERADO, REAJUSTE A FIBO");
            return; // Encerra a análise
         }

         // Verifica se tocou na Fibo 61.8
         if(low_i <= preco618 && high_i >= preco618)
         {
            Print("TOQUE NA FIBO 61.8 DETECTADO! Barra: ", i);
            jaTocouNaFibo = true;
            indiceToqueFibo = i;
            fundoQuadrado = low_i;
            tempoQuadrado = tempo_i;
         }
      }
      // ===== FASE 2: APÓS TOCAR NA FIBO =====
      else
      {
         // Atualiza o fundo se desceu mais
         if(low_i < fundoQuadrado)
         {
            fundoQuadrado = low_i;
            tempoQuadrado = tempo_i;
            Print("Fundo atualizado na barra ", i, " - Novo fundo: ", fundoQuadrado);
         }

         // Verifica se fechou abaixo do limite inferior (20%)
         if(close_i < limiteInferior)
         {
            Print("FUNDO SUPERADO! Barra: ", i, " Close: ", close_i, " | Limite: ", limiteInferior);
            Alert("SUPEROU O FUNDO, REAJUSTE A FIBO");
            return; // Encerra a análise
         }

         // Verifica se rompeu o topo do quadrado
         double topoQuadrado = fundoQuadrado + (AlturaQuadrado * _Point);
         if(close_i > topoQuadrado)
         {
            Print("QUADRADO TRAVADO no histórico! Barra: ", i, " Close: ", close_i);

            // Cria o quadrado travado
            datetime tempoInicioPrimeiroToque = iTime(_Symbol, _Period, indiceToqueFibo);
            CriarQuadradoAnalise(tempoInicioPrimeiroToque, fundoQuadrado, 10);

            // Ativa flags para manter o quadrado travado
            analiseAtiva = true;
            monitorandoAntesFibo = false;
            tocouFibo618 = true;
            rompeuTopo = true;
            barraInicioMonitoramento = indiceLinhaAzul;
            barraInicio = indiceToqueFibo;
            tempoInicioQuadrado = tempoInicioPrimeiroToque;
            fundoAtual = fundoQuadrado;

            ChartRedraw(0);
            Alert("Análise concluída: Quadrado travado (rompimento detectado no histórico)");
            Print("===== ANÁLISE CONCLUÍDA =====");
            return;
         }
      }
   }

   // ===== RESULTADO DA ANÁLISE =====
   if(!jaTocouNaFibo)
   {
      // Ainda não tocou na Fibo - inicia monitoramento
      Print("Ainda não tocou na Fibo 61.8 - Iniciando monitoramento");
      analiseAtiva = true;
      monitorandoAntesFibo = true;
      tocouFibo618 = false;
      rompeuTopo = false;
      barraInicioMonitoramento = indiceLinhaAzul;

      Alert("Monitoramento ativo: Aguardando toque na Fibonacci 61.8%");
   }
   else
   {
      // Tocou na Fibo mas ainda não rompeu - cria quadrado e continua monitorando
      Print("Tocou na Fibo mas ainda não rompeu - Criando quadrado");
      datetime tempoInicioPrimeiroToque = iTime(_Symbol, _Period, indiceToqueFibo);
      CriarQuadradoAnalise(tempoInicioPrimeiroToque, fundoQuadrado, 10);

      analiseAtiva = true;
      monitorandoAntesFibo = false;
      tocouFibo618 = true;
      rompeuTopo = false;
      barraInicioMonitoramento = indiceLinhaAzul;
      barraInicio = indiceToqueFibo;
      tempoInicioQuadrado = tempoInicioPrimeiroToque;
      fundoAtual = fundoQuadrado;

      Alert("Toque na Fibonacci 61.8% detectado! Quadrado criado e monitoramento ativo.");
   }

   // TRAVA AS LINHAS AUTOMATICAMENTE
   if(!linhasTravadas)
   {
      linhasTravadas = true;
      ObjectSetInteger(0, nomePontoSuperiorEsquerda, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nomePontoCentroEsquerda, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nomePontoLinhaAzul, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, nomeBotaoTravar, OBJPROP_TEXT, "Destravar");
      Print("Linhas TRAVADAS automaticamente");
   }

   // CRIA LINHA DO LIMITE 20%
   CriarLinhaLimite20();

   // ATUALIZA TABELAS DE STATUS
   AtualizarTabelasStatus();

   ChartRedraw(0);
   Print("===== ANÁLISE CONCLUÍDA =====");
}

//+------------------------------------------------------------------+
//| Função para executar compra (EA)                                 |
//+------------------------------------------------------------------+
void ExecutarCompra(double baseQuadrado)
{
   // Verifica se EA está habilitado
   if(!HabilitarEA)
   {
      Print("EA não habilitado. Ative HabilitarEA = true nos parâmetros.");
      return;
   }

   // Verifica se já operou
   if(jaOperou)
   {
      Print("Já operou nesta análise. Aguardando take ou stop.");
      return;
   }

   // Obtém preço atual
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Calcula os níveis
   double topoQuadrado = baseQuadrado + (AlturaQuadrado * _Point);
   double limiteMaximoEntrada = baseQuadrado + (800 * _Point);

   // Verifica se o preço está na zona de entrada (Topo < Preço < Topo + 400)
   // Considerando o spread
   if(bid <= topoQuadrado || ask > limiteMaximoEntrada)
   {
      Print("Preço fora da zona de entrada. Bid: ", bid, " Topo: ", topoQuadrado, " Limite: ", limiteMaximoEntrada);
      return;
   }

   // Calcula Stop Loss: 125 pontos abaixo da base
   double stopLoss = baseQuadrado - (125 * _Point);

   // Calcula distância entre entrada e stop
   double distancia = ask - stopLoss;

   // Calcula Take Profit: Entrada + distância
   double takeProfit = ask + distancia;

   // Normaliza os valores
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   stopLoss = MathFloor(stopLoss / tickSize) * tickSize;
   takeProfit = MathFloor(takeProfit / tickSize) * tickSize;

   Print("===== EXECUTANDO COMPRA =====");
   Print("Preço Entrada: ", ask);
   Print("Stop Loss: ", stopLoss);
   Print("Take Profit: ", takeProfit);
   Print("Distância SL: ", (ask - stopLoss) / _Point, " pontos");
   Print("Distância TP: ", (takeProfit - ask) / _Point, " pontos");

   // Configura o trade
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);

   // Executa a compra
   if(trade.Buy(Lote, _Symbol, ask, stopLoss, takeProfit, Comentario))
   {
      ticketOrdem = trade.ResultOrder();
      jaOperou = true;
      Print("COMPRA EXECUTADA COM SUCESSO! Ticket: ", ticketOrdem);
      Alert("EA Fibonacci: Compra executada! Ticket: ", ticketOrdem);
   }
   else
   {
      Print("ERRO ao executar compra. Código: ", GetLastError());
      Print("Detalhes: ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Função de cálculo do indicador                                   |
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
   // Monitora posição aberta pelo EA - se fechou (take ou stop), reseta controle
   if(jaOperou && ticketOrdem > 0)
   {
      // Verifica se a posição ainda existe
      if(!PositionSelectByTicket(ticketOrdem))
      {
         Print("===== POSIÇÃO FECHADA - Resetando controle do EA =====");
         Print("Ticket: ", ticketOrdem, " foi encerrado (Take Profit ou Stop Loss)");

         // Reseta flags do EA para permitir nova operação
         jaOperou = false;
         ticketOrdem = 0;

         Alert("EA Fibonacci: Posição encerrada. Sistema pronto para nova análise.");
      }
   }

   // Se análise não está ativa ou quadrado já travado, não faz nada
   if(!analiseAtiva || rompeuTopo) return(rates_total);

   // Obtém os preços das linhas horizontais e Fibonacci
   double precoLinhaHorizontalSuperior = ObjectGetDouble(0, nomeLinhaHorizontalSuperior, OBJPROP_PRICE);
   double precoLinhaHorizontalCentro = ObjectGetDouble(0, nomeLinhaHorizontalCentro, OBJPROP_PRICE);
   double preco618 = ObjectGetDouble(0, nomeLinhaFibo618, OBJPROP_PRICE);

   // Calcula a diferença entre as linhas horizontais
   double diferencaLinhas = precoLinhaHorizontalSuperior - precoLinhaHorizontalCentro;
   double tolerancia20Porcento = diferencaLinhas * 0.20;
   double limiteInferior = precoLinhaHorizontalCentro - tolerancia20Porcento;

   // Verifica as 3 últimas barras para não perder eventos
   for(int idx = 0; idx < 3; idx++)
   {
      double high_i = iHigh(_Symbol, _Period, idx);
      double low_i = iLow(_Symbol, _Period, idx);
      double close_i = iClose(_Symbol, _Period, idx);

      // ========== FASE 1: MONITORANDO ANTES DE TOCAR NA FIBO 61.8 ==========
      if(monitorandoAntesFibo && !tocouFibo618)
      {
         // Verifica se o preço FECHOU (corpo) acima da linha horizontal superior
         // ANTES de tocar na Fibo → encerra e alerta
         if(close_i > precoLinhaHorizontalSuperior)
         {
            Print("TOPO SUPERADO antes de tocar na Fibo! Barra: ", idx, " Close: ", close_i, " | Linha Superior: ", precoLinhaHorizontalSuperior);
            Alert("TOPO SUPERADO, REAJUSTE A FIBO");

            // Encerra o monitoramento
            analiseAtiva = false;
            monitorandoAntesFibo = false;
            AtualizarTabelasStatus();
            return(rates_total);
         }

         // Verifica se tocou na linha 61.8
         if(low_i <= preco618 && high_i >= preco618)
         {
            Print("TOQUE NA FIBO 61.8 DETECTADO em tempo real! Barra: ", idx);

            // Atualiza estado: saiu da fase de monitoramento, entrou na fase pós-toque
            tocouFibo618 = true;
            monitorandoAntesFibo = false;

            // Cria o quadrado inicial na primeira vez que toca
            datetime tempoToque = iTime(_Symbol, _Period, idx);
            tempoInicioQuadrado = tempoToque; // GUARDA O TEMPO DE INÍCIO DO QUADRADO
            CriarQuadradoAnalise(tempoToque, low_i, 10);
            fundoAtual = low_i;
            barraInicio = idx;

            AtualizarTabelasStatus();
            ChartRedraw(0);
            Alert("Toque na Fibonacci 61.8% detectado! Quadrado criado.");

            // NÃO FAZ RETURN - CONTINUA O LOOP PARA JÁ COMEÇAR A MONITORAR
         }
      }
   }

   // ========== FASE 2: APÓS TOCAR NA FIBO 61.8 - MONITORAMENTO CONTÍNUO ==========
   if(tocouFibo618 && !rompeuTopo && ObjectFind(0, nomeQuadradoAnalise) >= 0)
   {
      // Obtém o fundo atual do quadrado
      double baseAtual = ObjectGetDouble(0, nomeQuadradoAnalise, OBJPROP_PRICE, 0);

      // PRIORIDADE: Verifica a barra atual (0) SEMPRE para acompanhar o fundo em tempo real
      double low_atual = iLow(_Symbol, _Period, 0);
      double close_atual = iClose(_Symbol, _Period, 0);

      // Atualiza o fundo do quadrado se a barra atual desceu mais
      if(low_atual < baseAtual)
      {
         CriarQuadradoAnalise(tempoInicioQuadrado, low_atual, 10);
         fundoAtual = low_atual;
         baseAtual = low_atual;
         Print("Fundo do quadrado atualizado em tempo real: ", fundoAtual);
         ChartRedraw(0);
      }

      // Recalcula o topo baseado no fundo atual
      double topoAtual = baseAtual + (AlturaQuadrado * _Point);

      // Verifica as 3 últimas barras para eventos de rompimento
      for(int idx = 0; idx < 3; idx++)
      {
         double close_i = iClose(_Symbol, _Period, idx);
         double low_i = iLow(_Symbol, _Period, idx);

         // Verifica se o CORPO da vela fechou abaixo do limite inferior (20%)
         if(close_i < limiteInferior)
         {
            Print("FUNDO SUPERADO! Barra: ", idx, " Close: ", close_i, " | Limite Inferior (20%): ", limiteInferior);
            Alert("SUPEROU O FUNDO, REAJUSTE A FIBO");

            // Encerra o monitoramento
            analiseAtiva = false;
            tocouFibo618 = false;
            tempoInicioQuadrado = 0;

            // Remove quadrado e linhas de referência
            if(ObjectFind(0, nomeQuadradoAnalise) >= 0)
               ObjectDelete(0, nomeQuadradoAnalise);
            if(ObjectFind(0, nomeLinhaLimite20) >= 0)
               ObjectDelete(0, nomeLinhaLimite20);
            if(ObjectFind(0, nomeLinhaLimiteEntrada) >= 0)
               ObjectDelete(0, nomeLinhaLimiteEntrada);
            if(ObjectFind(0, nomeLinhaStopLoss) >= 0)
               ObjectDelete(0, nomeLinhaStopLoss);

            AtualizarTabelasStatus();
            return(rates_total);
         }

         // Verifica se fechou acima do topo do quadrado
         if(close_i > topoAtual)
         {
            // Calcula os níveis de entrada
            double limiteMaximoEntrada = baseAtual + (800 * _Point);
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

            // Verifica se está na ZONA DE ENTRADA (Topo < Ask <= Limite Máximo)
            // Só trava e executa se estiver DENTRO da zona de entrada
            if(ask > topoAtual && ask <= limiteMaximoEntrada)
            {
               Print("===== ROMPIMENTO VÁLIDO NA ZONA DE ENTRADA =====");
               Print("Close: ", close_i, " | Topo: ", topoAtual, " | Ask: ", ask, " | Limite: ", limiteMaximoEntrada);

               // Tenta executar compra pelo EA
               ExecutarCompra(baseAtual);

               // Trava o quadrado
               rompeuTopo = true;
               AtualizarTabelasStatus();
               ChartRedraw(0);
               Alert("Quadrado travado: Rompimento na zona de entrada!");
               return(rates_total);
            }
            else if(ask > limiteMaximoEntrada)
            {
               // Preço fechou acima do topo mas JÁ ESTÁ FORA da zona de entrada
               Print("AVISO: Preço fechou acima do topo mas FORA da zona de entrada!");
               Print("Close: ", close_i, " | Ask: ", ask, " | Limite Máximo: ", limiteMaximoEntrada);
               Alert("ATENÇÃO: Preço rompeu mas está FORA da zona de entrada (>800 pontos)!");
               // NÃO trava o quadrado, continua monitorando
            }
         }
      }
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Função de desinicialização do indicador                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Removendo indicador. Razão: ", reason);

   // Remove todas as linhas ao remover o indicador
   ObjectDelete(0, nomeLinhaHorizontalSuperior);
   ObjectDelete(0, nomeLinhaHorizontalCentro);
   ObjectDelete(0, nomeLinhaVerticalEsquerda);
   ObjectDelete(0, nomeLinhaVerticalAzul);
   ObjectDelete(0, nomePontoLinhaAzul);

   // Remove todos os pontos de controle
   ObjectDelete(0, nomePontoSuperiorEsquerda);
   ObjectDelete(0, nomePontoCentroEsquerda);

   // Remove linhas de Fibonacci
   ObjectDelete(0, nomeLinhaFibo618);
   ObjectDelete(0, nomeLinhaFibo764);

   // Remove os botões
   ObjectDelete(0, nomeBotaoAnalisar);
   ObjectDelete(0, nomeBotaoInverterFibo);
   ObjectDelete(0, nomeBotaoReset);
   ObjectDelete(0, nomeBotaoTravar);

   // Remove quadrado de análise e linhas de referência
   ObjectDelete(0, nomeQuadradoAnalise);
   ObjectDelete(0, nomeLinhaLimite20);
   ObjectDelete(0, nomeLinhaLimiteEntrada);
   ObjectDelete(0, nomeLinhaStopLoss);

   // Remove tabelas de status profissionais
   RemoverTabelaProfissional("StatusAnalise");
   RemoverTabelaProfissional("StatusTravamento");

   // Atualiza o gráfico
   ChartRedraw(0);

   Print("Indicador removido com sucesso");
}

//+------------------------------------------------------------------+
//| Função ChartEvent - Detecta eventos do gráfico                   |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // Detecta clique no botão Analisar
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == nomeBotaoAnalisar)
   {
      Print("Botão Analisar clicado");
      AnalisarFibonacci();
      ObjectSetInteger(0, nomeBotaoAnalisar, OBJPROP_STATE, false);
   }

   // Detecta clique no botão Inverter Fibo
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == nomeBotaoInverterFibo)
   {
      Print("Botão Inverter Fibo clicado");
      InverterFibonacci();
      ObjectSetInteger(0, nomeBotaoInverterFibo, OBJPROP_STATE, false);
   }

   // Detecta clique no botão Reset
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == nomeBotaoReset)
   {
      Print("Botão Reset clicado");
      ResetarIndicador();
      ObjectSetInteger(0, nomeBotaoReset, OBJPROP_STATE, false);
   }

   // Detecta clique no botão Travar/Destravar
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == nomeBotaoTravar)
   {
      Print("Botão Travar/Destravar clicado");
      TravarDestravarLinhas();
      ObjectSetInteger(0, nomeBotaoTravar, OBJPROP_STATE, false);
   }

   // Detecta redimensionamento do gráfico
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      ChartRedraw(0);
   }

   // Detecta quando um objeto é arrastado
   if(id == CHARTEVENT_OBJECT_DRAG)
   {
      // Se as linhas estiverem travadas, não permite arrastar
      if(linhasTravadas)
      {
         Print("AVISO: Linhas estão travadas! Não é possível arrastar.");
         return;
      }

      Print("Objeto arrastado: ", sparam);

      // Verifica qual ponto foi arrastado
      if(sparam == nomePontoSuperiorEsquerda)
      {
         // Atualiza linha horizontal superior e vertical esquerda
         AtualizarLinhas(sparam, nomeLinhaHorizontalSuperior, nomeLinhaVerticalEsquerda);
      }
      else if(sparam == nomePontoCentroEsquerda)
      {
         // Atualiza linha horizontal centro e vertical esquerda
         AtualizarLinhas(sparam, nomeLinhaHorizontalCentro, nomeLinhaVerticalEsquerda);
      }
      else if(sparam == nomePontoLinhaAzul)
      {
         // Atualiza apenas a linha vertical azul (movimento horizontal)
         AtualizarLinhaAzul();
      }

      // Atualiza posições de todos os pontos para manter sincronização
      SincronizarPontos();

      // Atualiza as linhas de Fibonacci
      AtualizarLinhasFibonacci();

      // Atualiza a linha limite 20% se estiver visível
      if(ObjectFind(0, nomeLinhaLimite20) >= 0)
         CriarLinhaLimite20();

      // Atualiza o gráfico
      ChartRedraw(0);
   }
}

//+------------------------------------------------------------------+
//| Função para atualizar linhas baseado no ponto movido             |
//+------------------------------------------------------------------+
void AtualizarLinhas(string nomePonto, string nomeLinhaH, string nomeLinhaV)
{
   // Obtém a nova posição do ponto
   datetime novoTempo = (datetime)ObjectGetInteger(0, nomePonto, OBJPROP_TIME);
   double novoPreco = ObjectGetDouble(0, nomePonto, OBJPROP_PRICE);

   // Atualiza a linha horizontal
   ObjectSetDouble(0, nomeLinhaH, OBJPROP_PRICE, novoPreco);

   // Atualiza a linha vertical
   ObjectSetInteger(0, nomeLinhaV, OBJPROP_TIME, novoTempo);
}

//+------------------------------------------------------------------+
//| Função para sincronizar todos os pontos com as linhas            |
//+------------------------------------------------------------------+
void SincronizarPontos()
{
   // Obtém as posições das linhas
   double precoSuperior = ObjectGetDouble(0, nomeLinhaHorizontalSuperior, OBJPROP_PRICE);
   double precoCentro = ObjectGetDouble(0, nomeLinhaHorizontalCentro, OBJPROP_PRICE);
   datetime tempoEsquerda = (datetime)ObjectGetInteger(0, nomeLinhaVerticalEsquerda, OBJPROP_TIME);

   // Atualiza apenas os pontos de controle da esquerda
   ObjectSetInteger(0, nomePontoSuperiorEsquerda, OBJPROP_TIME, tempoEsquerda);
   ObjectSetDouble(0, nomePontoSuperiorEsquerda, OBJPROP_PRICE, precoSuperior);

   ObjectSetInteger(0, nomePontoCentroEsquerda, OBJPROP_TIME, tempoEsquerda);
   ObjectSetDouble(0, nomePontoCentroEsquerda, OBJPROP_PRICE, precoCentro);
}

//+------------------------------------------------------------------+
//| Função para criar botão "Analisar"                               |
//+------------------------------------------------------------------+
void CriarBotaoAnalisar()
{
   // Remove botão se já existir
   if(ObjectFind(0, nomeBotaoAnalisar) >= 0)
      ObjectDelete(0, nomeBotaoAnalisar);

   // Cria o botão
   if(!ObjectCreate(0, nomeBotaoAnalisar, OBJ_BUTTON, 0, 0, 0))
   {
      Print("ERRO ao criar botão Analisar. Erro: ", GetLastError());
      return;
   }

   // Define propriedades do botão
   ObjectSetInteger(0, nomeBotaoAnalisar, OBJPROP_XDISTANCE, BotaoPosX);
   ObjectSetInteger(0, nomeBotaoAnalisar, OBJPROP_YDISTANCE, BotaoPosY);
   ObjectSetInteger(0, nomeBotaoAnalisar, OBJPROP_XSIZE, BotaoLargura);
   ObjectSetInteger(0, nomeBotaoAnalisar, OBJPROP_YSIZE, BotaoAltura);
   ObjectSetInteger(0, nomeBotaoAnalisar, OBJPROP_BGCOLOR, clrDodgerBlue);
   ObjectSetInteger(0, nomeBotaoAnalisar, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, nomeBotaoAnalisar, OBJPROP_BORDER_COLOR, clrNavy);
   ObjectSetInteger(0, nomeBotaoAnalisar, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, nomeBotaoAnalisar, OBJPROP_BACK, false);
   ObjectSetInteger(0, nomeBotaoAnalisar, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nomeBotaoAnalisar, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, nomeBotaoAnalisar, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, nomeBotaoAnalisar, OBJPROP_ZORDER, 10);
   ObjectSetInteger(0, nomeBotaoAnalisar, OBJPROP_STATE, false);

   ObjectSetString(0, nomeBotaoAnalisar, OBJPROP_TEXT, "Analisar");
   ObjectSetString(0, nomeBotaoAnalisar, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, nomeBotaoAnalisar, OBJPROP_FONTSIZE, 11);

   Print("Botão Analisar criado");
}

//+------------------------------------------------------------------+
//| Função para criar botão "Inverter Fibo"                          |
//+------------------------------------------------------------------+
void CriarBotaoInverterFibo()
{
   // Remove botão se já existir
   if(ObjectFind(0, nomeBotaoInverterFibo) >= 0)
      ObjectDelete(0, nomeBotaoInverterFibo);

   // Calcula posição Y baseado no botão anterior
   int yPos = BotaoPosY + BotaoAltura + 5;

   // Cria o botão
   if(!ObjectCreate(0, nomeBotaoInverterFibo, OBJ_BUTTON, 0, 0, 0))
   {
      Print("ERRO ao criar botão Inverter Fibo. Erro: ", GetLastError());
      return;
   }

   ObjectSetInteger(0, nomeBotaoInverterFibo, OBJPROP_XDISTANCE, BotaoPosX);
   ObjectSetInteger(0, nomeBotaoInverterFibo, OBJPROP_YDISTANCE, yPos);
   ObjectSetInteger(0, nomeBotaoInverterFibo, OBJPROP_XSIZE, BotaoLargura);
   ObjectSetInteger(0, nomeBotaoInverterFibo, OBJPROP_YSIZE, BotaoAltura);
   ObjectSetInteger(0, nomeBotaoInverterFibo, OBJPROP_BGCOLOR, clrOrange);
   ObjectSetInteger(0, nomeBotaoInverterFibo, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, nomeBotaoInverterFibo, OBJPROP_BORDER_COLOR, clrDarkOrange);
   ObjectSetInteger(0, nomeBotaoInverterFibo, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, nomeBotaoInverterFibo, OBJPROP_BACK, false);
   ObjectSetInteger(0, nomeBotaoInverterFibo, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nomeBotaoInverterFibo, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, nomeBotaoInverterFibo, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, nomeBotaoInverterFibo, OBJPROP_ZORDER, 10);
   ObjectSetInteger(0, nomeBotaoInverterFibo, OBJPROP_STATE, false);

   ObjectSetString(0, nomeBotaoInverterFibo, OBJPROP_TEXT, "Inverter Fibo");
   ObjectSetString(0, nomeBotaoInverterFibo, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, nomeBotaoInverterFibo, OBJPROP_FONTSIZE, 10);

   Print("Botão Inverter Fibo criado");
}

//+------------------------------------------------------------------+
//| Função para criar botão "Reset"                                  |
//+------------------------------------------------------------------+
void CriarBotaoReset()
{
   // Remove botão se já existir
   if(ObjectFind(0, nomeBotaoReset) >= 0)
      ObjectDelete(0, nomeBotaoReset);

   // Calcula posição Y (terceiro botão)
   int yPos = BotaoPosY + (BotaoAltura + 5) * 2;

   // Cria o botão
   if(!ObjectCreate(0, nomeBotaoReset, OBJ_BUTTON, 0, 0, 0))
   {
      Print("ERRO ao criar botão Reset. Erro: ", GetLastError());
      return;
   }

   ObjectSetInteger(0, nomeBotaoReset, OBJPROP_XDISTANCE, BotaoPosX);
   ObjectSetInteger(0, nomeBotaoReset, OBJPROP_YDISTANCE, yPos);
   ObjectSetInteger(0, nomeBotaoReset, OBJPROP_XSIZE, BotaoLargura);
   ObjectSetInteger(0, nomeBotaoReset, OBJPROP_YSIZE, BotaoAltura);
   ObjectSetInteger(0, nomeBotaoReset, OBJPROP_BGCOLOR, clrCrimson);
   ObjectSetInteger(0, nomeBotaoReset, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, nomeBotaoReset, OBJPROP_BORDER_COLOR, clrDarkRed);
   ObjectSetInteger(0, nomeBotaoReset, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, nomeBotaoReset, OBJPROP_BACK, false);
   ObjectSetInteger(0, nomeBotaoReset, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nomeBotaoReset, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, nomeBotaoReset, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, nomeBotaoReset, OBJPROP_ZORDER, 10);
   ObjectSetInteger(0, nomeBotaoReset, OBJPROP_STATE, false);

   ObjectSetString(0, nomeBotaoReset, OBJPROP_TEXT, "Reset");
   ObjectSetString(0, nomeBotaoReset, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, nomeBotaoReset, OBJPROP_FONTSIZE, 11);

   Print("Botão Reset criado");
}

//+------------------------------------------------------------------+
//| Função para criar botão "Travar/Destravar"                       |
//+------------------------------------------------------------------+
void CriarBotaoTravar()
{
   // Remove botão se já existir
   if(ObjectFind(0, nomeBotaoTravar) >= 0)
      ObjectDelete(0, nomeBotaoTravar);

   // Calcula posição Y (quarto botão)
   int yPos = BotaoPosY + (BotaoAltura + 5) * 3;

   // Cria o botão
   if(!ObjectCreate(0, nomeBotaoTravar, OBJ_BUTTON, 0, 0, 0))
   {
      Print("ERRO ao criar botão Travar. Erro: ", GetLastError());
      return;
   }

   ObjectSetInteger(0, nomeBotaoTravar, OBJPROP_XDISTANCE, BotaoPosX);
   ObjectSetInteger(0, nomeBotaoTravar, OBJPROP_YDISTANCE, yPos);
   ObjectSetInteger(0, nomeBotaoTravar, OBJPROP_XSIZE, BotaoLargura);
   ObjectSetInteger(0, nomeBotaoTravar, OBJPROP_YSIZE, BotaoAltura);
   ObjectSetInteger(0, nomeBotaoTravar, OBJPROP_BGCOLOR, clrGold);
   ObjectSetInteger(0, nomeBotaoTravar, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, nomeBotaoTravar, OBJPROP_BORDER_COLOR, clrDarkGoldenrod);
   ObjectSetInteger(0, nomeBotaoTravar, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, nomeBotaoTravar, OBJPROP_BACK, false);
   ObjectSetInteger(0, nomeBotaoTravar, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nomeBotaoTravar, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, nomeBotaoTravar, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, nomeBotaoTravar, OBJPROP_ZORDER, 10);
   ObjectSetInteger(0, nomeBotaoTravar, OBJPROP_STATE, false);

   ObjectSetString(0, nomeBotaoTravar, OBJPROP_TEXT, "Destravar");
   ObjectSetString(0, nomeBotaoTravar, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, nomeBotaoTravar, OBJPROP_FONTSIZE, 11);

   Print("Botão Travar/Destravar criado");
}

//+------------------------------------------------------------------+
//| Função para criar tabelas de status                              |
//+------------------------------------------------------------------+
void CriarTabelaStatus()
{
   // === TABELA 1: STATUS ANÁLISE ===
   int posY1 = TabelaPosY;
   CriarTabelaProfissional("StatusAnalise", TabelaPosX, posY1,
                           "STATUS ANÁLISE", "INATIVA",
                           C'25,35,45', C'35,45,55', C'70,130,180',
                           clrWhite, clrYellow);

   // === TABELA 2: STATUS TRAVAMENTO ===
   int posY2 = TabelaPosY + TabelaAltura + 10;
   CriarTabelaProfissional("StatusTravamento", TabelaPosX, posY2,
                           "STATUS LINHAS", "DESTRAVADAS",
                           C'20,40,30', C'30,50,40', C'50,205,50',
                           clrWhite, clrLime);

   Print("Tabelas de status criadas com design profissional");
}

//+------------------------------------------------------------------+
//| Função para criar tabela profissional                            |
//+------------------------------------------------------------------+
void CriarTabelaProfissional(string nome, int posX, int posY,
                             string titulo, string texto,
                             color corHeader, color corFundo, color corBorda,
                             color corTitulo, color corTexto)
{
   string prefixo = "Tabela_" + nome + "_";

   // Remove objetos anteriores se existirem
   ObjectDelete(0, prefixo + "Sombra");
   ObjectDelete(0, prefixo + "Header");
   ObjectDelete(0, prefixo + "Corpo");
   ObjectDelete(0, prefixo + "Separador");
   ObjectDelete(0, prefixo + "Titulo");
   ObjectDelete(0, prefixo + "Texto");

   //--- Criar sombra (destaque 3D)
   ObjectCreate(0, prefixo + "Sombra", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, prefixo + "Sombra", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, prefixo + "Sombra", OBJPROP_XDISTANCE, posX + 3);
   ObjectSetInteger(0, prefixo + "Sombra", OBJPROP_YDISTANCE, posY + 3);
   ObjectSetInteger(0, prefixo + "Sombra", OBJPROP_XSIZE, TabelaLargura);
   ObjectSetInteger(0, prefixo + "Sombra", OBJPROP_YSIZE, TabelaAltura);
   ObjectSetInteger(0, prefixo + "Sombra", OBJPROP_BGCOLOR, C'20,20,20');
   ObjectSetInteger(0, prefixo + "Sombra", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, prefixo + "Sombra", OBJPROP_BACK, false);
   ObjectSetInteger(0, prefixo + "Sombra", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, prefixo + "Sombra", OBJPROP_SELECTED, false);
   ObjectSetInteger(0, prefixo + "Sombra", OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, prefixo + "Sombra", OBJPROP_ZORDER, 0);

   //--- Criar cabeçalho
   ObjectCreate(0, prefixo + "Header", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, prefixo + "Header", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, prefixo + "Header", OBJPROP_XDISTANCE, posX);
   ObjectSetInteger(0, prefixo + "Header", OBJPROP_YDISTANCE, posY);
   ObjectSetInteger(0, prefixo + "Header", OBJPROP_XSIZE, TabelaLargura);
   ObjectSetInteger(0, prefixo + "Header", OBJPROP_YSIZE, AlturaCabecalho);
   ObjectSetInteger(0, prefixo + "Header", OBJPROP_BGCOLOR, corHeader);
   ObjectSetInteger(0, prefixo + "Header", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, prefixo + "Header", OBJPROP_COLOR, corBorda);
   ObjectSetInteger(0, prefixo + "Header", OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, prefixo + "Header", OBJPROP_BACK, false);
   ObjectSetInteger(0, prefixo + "Header", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, prefixo + "Header", OBJPROP_SELECTED, false);
   ObjectSetInteger(0, prefixo + "Header", OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, prefixo + "Header", OBJPROP_ZORDER, 1);

   //--- Criar corpo
   ObjectCreate(0, prefixo + "Corpo", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, prefixo + "Corpo", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, prefixo + "Corpo", OBJPROP_XDISTANCE, posX);
   ObjectSetInteger(0, prefixo + "Corpo", OBJPROP_YDISTANCE, posY + AlturaCabecalho);
   ObjectSetInteger(0, prefixo + "Corpo", OBJPROP_XSIZE, TabelaLargura);
   ObjectSetInteger(0, prefixo + "Corpo", OBJPROP_YSIZE, TabelaAltura - AlturaCabecalho);
   ObjectSetInteger(0, prefixo + "Corpo", OBJPROP_BGCOLOR, corFundo);
   ObjectSetInteger(0, prefixo + "Corpo", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, prefixo + "Corpo", OBJPROP_COLOR, corBorda);
   ObjectSetInteger(0, prefixo + "Corpo", OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, prefixo + "Corpo", OBJPROP_BACK, false);
   ObjectSetInteger(0, prefixo + "Corpo", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, prefixo + "Corpo", OBJPROP_SELECTED, false);
   ObjectSetInteger(0, prefixo + "Corpo", OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, prefixo + "Corpo", OBJPROP_ZORDER, 1);

   //--- Criar linha separadora
   ObjectCreate(0, prefixo + "Separador", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, prefixo + "Separador", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, prefixo + "Separador", OBJPROP_XDISTANCE, posX);
   ObjectSetInteger(0, prefixo + "Separador", OBJPROP_YDISTANCE, posY + AlturaCabecalho - 1);
   ObjectSetInteger(0, prefixo + "Separador", OBJPROP_XSIZE, TabelaLargura);
   ObjectSetInteger(0, prefixo + "Separador", OBJPROP_YSIZE, 2);
   ObjectSetInteger(0, prefixo + "Separador", OBJPROP_BGCOLOR, corBorda);
   ObjectSetInteger(0, prefixo + "Separador", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, prefixo + "Separador", OBJPROP_BACK, false);
   ObjectSetInteger(0, prefixo + "Separador", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, prefixo + "Separador", OBJPROP_SELECTED, false);
   ObjectSetInteger(0, prefixo + "Separador", OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, prefixo + "Separador", OBJPROP_ZORDER, 2);

   //--- Criar título centralizado no header
   int tituloX = posX - (TabelaLargura / 2);
   int tituloY = posY + (AlturaCabecalho / 2) - (TamanhoFonteTitulo / 2) + AjusteVerticalTitulo;
   CriarTextoTabela(prefixo + "Titulo", titulo, tituloX, tituloY,
                    corTitulo, TamanhoFonteTitulo, NomeFonte + " Semibold");

   //--- Criar texto centralizado no corpo
   int textoX = posX - (TabelaLargura / 2);
   int textoY = posY + AlturaCabecalho + ((TabelaAltura - AlturaCabecalho) / 2) - (TamanhoFonteTexto / 2) + AjusteVerticalTexto;
   CriarTextoTabela(prefixo + "Texto", texto, textoX, textoY,
                    corTexto, TamanhoFonteTexto, NomeFonte + " Bold");
}

//+------------------------------------------------------------------+
//| Função auxiliar para criar texto nas tabelas                     |
//+------------------------------------------------------------------+
void CriarTextoTabela(string nome, string texto, int x, int y, color cor, int tamanho, string fonte)
{
   ObjectCreate(0, nome, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, nome, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, nome, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, nome, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, nome, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, nome, OBJPROP_COLOR, cor);
   ObjectSetInteger(0, nome, OBJPROP_FONTSIZE, tamanho);
   ObjectSetString(0, nome, OBJPROP_FONT, fonte);
   ObjectSetString(0, nome, OBJPROP_TEXT, texto);
   ObjectSetInteger(0, nome, OBJPROP_BACK, false);
   ObjectSetInteger(0, nome, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nome, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, nome, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, nome, OBJPROP_ZORDER, 100);
}

//+------------------------------------------------------------------+
//| Função para remover tabela profissional                          |
//+------------------------------------------------------------------+
void RemoverTabelaProfissional(string nome)
{
   string prefixo = "Tabela_" + nome + "_";
   ObjectDelete(0, prefixo + "Sombra");
   ObjectDelete(0, prefixo + "Header");
   ObjectDelete(0, prefixo + "Corpo");
   ObjectDelete(0, prefixo + "Separador");
   ObjectDelete(0, prefixo + "Titulo");
   ObjectDelete(0, prefixo + "Texto");
}

//+------------------------------------------------------------------+
//| Função para atualizar tabelas de status                          |
//+------------------------------------------------------------------+
void AtualizarTabelasStatus()
{
   // Atualiza status da análise
   if(analiseAtiva)
   {
      ObjectSetString(0, "Tabela_StatusAnalise_Texto", OBJPROP_TEXT, "ATIVA");
      ObjectSetInteger(0, "Tabela_StatusAnalise_Header", OBJPROP_BGCOLOR, C'15,50,25');
      ObjectSetInteger(0, "Tabela_StatusAnalise_Corpo", OBJPROP_BGCOLOR, C'25,60,35');
      ObjectSetInteger(0, "Tabela_StatusAnalise_Separador", OBJPROP_BGCOLOR, C'50,205,50');
      ObjectSetInteger(0, "Tabela_StatusAnalise_Texto", OBJPROP_COLOR, clrLime);
   }
   else
   {
      ObjectSetString(0, "Tabela_StatusAnalise_Texto", OBJPROP_TEXT, "INATIVA");
      ObjectSetInteger(0, "Tabela_StatusAnalise_Header", OBJPROP_BGCOLOR, C'25,35,45');
      ObjectSetInteger(0, "Tabela_StatusAnalise_Corpo", OBJPROP_BGCOLOR, C'35,45,55');
      ObjectSetInteger(0, "Tabela_StatusAnalise_Separador", OBJPROP_BGCOLOR, C'70,130,180');
      ObjectSetInteger(0, "Tabela_StatusAnalise_Texto", OBJPROP_COLOR, clrYellow);
   }

   // Atualiza status do travamento
   if(linhasTravadas)
   {
      ObjectSetString(0, "Tabela_StatusTravamento_Texto", OBJPROP_TEXT, "TRAVADAS");
      ObjectSetInteger(0, "Tabela_StatusTravamento_Header", OBJPROP_BGCOLOR, C'50,20,20');
      ObjectSetInteger(0, "Tabela_StatusTravamento_Corpo", OBJPROP_BGCOLOR, C'60,30,30');
      ObjectSetInteger(0, "Tabela_StatusTravamento_Separador", OBJPROP_BGCOLOR, C'255,100,100');
      ObjectSetInteger(0, "Tabela_StatusTravamento_Texto", OBJPROP_COLOR, clrRed);
   }
   else
   {
      ObjectSetString(0, "Tabela_StatusTravamento_Texto", OBJPROP_TEXT, "DESTRAVADAS");
      ObjectSetInteger(0, "Tabela_StatusTravamento_Header", OBJPROP_BGCOLOR, C'20,40,30');
      ObjectSetInteger(0, "Tabela_StatusTravamento_Corpo", OBJPROP_BGCOLOR, C'30,50,40');
      ObjectSetInteger(0, "Tabela_StatusTravamento_Separador", OBJPROP_BGCOLOR, C'50,205,50');
      ObjectSetInteger(0, "Tabela_StatusTravamento_Texto", OBJPROP_COLOR, clrLime);
   }

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Função para travar/destravar linhas                              |
//+------------------------------------------------------------------+
void TravarDestravarLinhas()
{
   linhasTravadas = !linhasTravadas;

   // Define se os pontos podem ser selecionados
   bool podeSelecionar = !linhasTravadas;

   // Atualiza pontos de controle
   ObjectSetInteger(0, nomePontoSuperiorEsquerda, OBJPROP_SELECTABLE, podeSelecionar);
   ObjectSetInteger(0, nomePontoCentroEsquerda, OBJPROP_SELECTABLE, podeSelecionar);
   ObjectSetInteger(0, nomePontoLinhaAzul, OBJPROP_SELECTABLE, podeSelecionar);

   // Atualiza texto do botão
   if(linhasTravadas)
   {
      ObjectSetString(0, nomeBotaoTravar, OBJPROP_TEXT, "Destravar");
      Print("Linhas TRAVADAS");
   }
   else
   {
      ObjectSetString(0, nomeBotaoTravar, OBJPROP_TEXT, "Travar");
      Print("Linhas DESTRAVADAS");

      // Ao destravar, encerra a análise
      if(analiseAtiva)
      {
         analiseAtiva = false;
         monitorandoAntesFibo = false;
         tocouFibo618 = false;
         rompeuTopo = false;
         tempoInicioQuadrado = 0;

         // Remove quadrado e linhas de referência
         if(ObjectFind(0, nomeQuadradoAnalise) >= 0)
            ObjectDelete(0, nomeQuadradoAnalise);
         if(ObjectFind(0, nomeLinhaLimite20) >= 0)
            ObjectDelete(0, nomeLinhaLimite20);
         if(ObjectFind(0, nomeLinhaLimiteEntrada) >= 0)
            ObjectDelete(0, nomeLinhaLimiteEntrada);
         if(ObjectFind(0, nomeLinhaStopLoss) >= 0)
            ObjectDelete(0, nomeLinhaStopLoss);

         Print("Análise ENCERRADA ao destravar");
      }
   }

   // Atualiza tabelas
   AtualizarTabelasStatus();

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Função para inverter Fibonacci                                   |
//+------------------------------------------------------------------+
void InverterFibonacci()
{
   // Inverte o estado da Fibonacci
   fiboInvertida = !fiboInvertida;

   Print("Fibonacci invertida: ", fiboInvertida ? "SIM" : "NÃO");

   // Atualiza as linhas de Fibonacci com a nova configuração
   AtualizarLinhasFibonacci();

   // Atualiza o gráfico
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Função para resetar o indicador                                  |
//+------------------------------------------------------------------+
void ResetarIndicador()
{
   Print("Resetando indicador...");

   // Reseta todas as variáveis de controle
   analiseAtiva = false;
   monitorandoAntesFibo = false;
   tocouFibo618 = false;
   barraInicioMonitoramento = -1;
   barraInicio = -1;
   tempoInicioQuadrado = 0;
   fundoAtual = 0;
   rompeuTopo = false;
   linhasTravadas = false;

   // Reseta variáveis do EA
   jaOperou = false;
   ticketOrdem = 0;

   // Remove o quadrado de análise e linhas de referência
   if(ObjectFind(0, nomeQuadradoAnalise) >= 0)
      ObjectDelete(0, nomeQuadradoAnalise);
   if(ObjectFind(0, nomeLinhaLimite20) >= 0)
      ObjectDelete(0, nomeLinhaLimite20);
   if(ObjectFind(0, nomeLinhaLimiteEntrada) >= 0)
      ObjectDelete(0, nomeLinhaLimiteEntrada);
   if(ObjectFind(0, nomeLinhaStopLoss) >= 0)
      ObjectDelete(0, nomeLinhaStopLoss);

   // Remove o indicador atual e reinicializa
   OnDeinit(0);
   OnInit();

   Print("Indicador resetado!");
}

//+------------------------------------------------------------------+
