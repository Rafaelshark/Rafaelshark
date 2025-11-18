//+------------------------------------------------------------------+
//|                                      LinhasMoveisIndicador.mq5   |
//|                                  Indicador com Linhas Móveis     |
//+------------------------------------------------------------------+
#property copyright "Indicador Personalizado"
#property link      ""
#property version   "2.02"
#property indicator_chart_window
#property indicator_plots 0

//+------------------------------------------------------------------+
//| Parâmetros de entrada                                            |
//+------------------------------------------------------------------+
input group "=== Posição do Botão Analisar ==="
input int BotaoPosX = 10;  // Posição X do botão (pixels da borda direita)
input int BotaoPosY = 10;   // Posição Y do botão (pixels da borda superior)

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

// Nome do quadrado de análise
string nomeQuadradoAnalise = "Quadrado_Analise";

// Variáveis de controle da análise
bool fiboInvertida = false;  // Controla se a Fibonacci está invertida
bool analiseAtiva = false;   // Controla se a análise está ativa
int barraInicio = -1;        // Índice da barra onde iniciou a análise
double fundoAtual = 0;       // Fundo atual do quadrado
bool rompeuTopo = false;     // Se já rompeu o topo do quadrado

//+------------------------------------------------------------------+
//| Função de inicialização do indicador                             |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("Iniciando indicador LinhasMoveisIndicador v2.02...");

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

   // Inicializa variáveis
   fiboInvertida = false;
   analiseAtiva = false;
   rompeuTopo = false;

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
//| Função para criar ou atualizar o quadrado de análise             |
//+------------------------------------------------------------------+
void CriarQuadradoAnalise(datetime tempoInicio, double precoBase, int larguraVelas)
{
   // Remove quadrado existente
   if(ObjectFind(0, nomeQuadradoAnalise) >= 0)
      ObjectDelete(0, nomeQuadradoAnalise);

   // Calcula o tempo final (larguraVelas para frente)
   int indiceInicio = iBarShift(_Symbol, _Period, tempoInicio);
   int indiceFim = indiceInicio - larguraVelas;
   if(indiceFim < 0) indiceFim = 0;

   datetime tempoFim = iTime(_Symbol, _Period, indiceFim);

   // Altura do quadrado em pontos
   double alturaEmPreco = 400 * _Point;
   double precoTopo = precoBase + alturaEmPreco;

   // Cria o retângulo
   if(!ObjectCreate(0, nomeQuadradoAnalise, OBJ_RECTANGLE, 0, tempoInicio, precoBase, tempoFim, precoTopo))
   {
      Print("ERRO ao criar quadrado de análise. Erro: ", GetLastError());
      return;
   }

   // Define propriedades do quadrado
   ObjectSetInteger(0, nomeQuadradoAnalise, OBJPROP_COLOR, clrGreen);
   ObjectSetInteger(0, nomeQuadradoAnalise, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, nomeQuadradoAnalise, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, nomeQuadradoAnalise, OBJPROP_BACK, false);
   ObjectSetInteger(0, nomeQuadradoAnalise, OBJPROP_FILL, false);
   ObjectSetInteger(0, nomeQuadradoAnalise, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nomeQuadradoAnalise, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, nomeQuadradoAnalise, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, nomeQuadradoAnalise, OBJPROP_ZORDER, 5);

   ObjectSetString(0, nomeQuadradoAnalise, OBJPROP_TEXT, "Quadrado de Análise - 400 pontos");

   Print("Quadrado de análise criado - Base: ", precoBase, " Topo: ", precoTopo);
}

//+------------------------------------------------------------------+
//| Função principal de análise Fibonacci                            |
//+------------------------------------------------------------------+
void AnalisarFibonacci()
{
   Print("===== INICIANDO ANÁLISE FIBONACCI =====");

   // Remove quadrado anterior se existir
   if(ObjectFind(0, nomeQuadradoAnalise) >= 0)
      ObjectDelete(0, nomeQuadradoAnalise);

   // Obtém os preços das linhas Fibonacci
   double preco618 = ObjectGetDouble(0, nomeLinhaFibo618, OBJPROP_PRICE);
   double preco764 = ObjectGetDouble(0, nomeLinhaFibo764, OBJPROP_PRICE);

   Print("Preços Fibonacci - 61.8%: ", preco618, " | 76.4%: ", preco764);

   // Verifica se 76.4 está abaixo de 61.8
   if(preco764 >= preco618)
   {
      Print("CONDIÇÃO NÃO ATENDIDA: 76.4 não está abaixo de 61.8");
      Alert("Análise não pode ser executada: 76.4 deve estar abaixo de 61.8");
      return;
   }

   Print("CONDIÇÃO OK: 76.4 está abaixo de 61.8");

   // Obtém a posição da linha azul (início da análise)
   datetime tempoLinhaAzul = (datetime)ObjectGetInteger(0, nomeLinhaVerticalAzul, OBJPROP_TIME);
   int indiceLinhaAzul = iBarShift(_Symbol, _Period, tempoLinhaAzul);

   if(indiceLinhaAzul < 0)
   {
      Print("ERRO: Não foi possível encontrar a barra da linha azul");
      return;
   }

   Print("Linha azul - Tempo: ", TimeToString(tempoLinhaAzul), " | Índice: ", indiceLinhaAzul);

   // Variáveis para análise
   bool tocouNa618 = false;
   int indiceToque = -1;
   double precoToque = 0;

   // Percorre as velas a partir da linha azul (da esquerda para direita, índices decrescentes)
   Print("Iniciando varredura das velas...");

   for(int i = indiceLinhaAzul; i >= 0; i--)
   {
      double high = iHigh(_Symbol, _Period, i);
      double low = iLow(_Symbol, _Period, i);
      datetime tempo = iTime(_Symbol, _Period, i);

      // Verifica se tocou na linha 61.8
      if(low <= preco618 && high >= preco618)
      {
         tocouNa618 = true;
         indiceToque = i;
         precoToque = low;
         Print("TOQUE DETECTADO na barra ", i, " | Tempo: ", TimeToString(tempo), " | Low: ", low);
         break;
      }
   }

   if(!tocouNa618)
   {
      Print("Nenhum toque na linha 61.8 detectado após a linha azul");
      Alert("Nenhum toque na linha 61.8 foi detectado");
      return;
   }

   // Agora percorre a partir do ponto de toque para acompanhar o fundo
   datetime tempoQuadrado = iTime(_Symbol, _Period, indiceToque);
   double fundoQuadrado = precoToque;
   double alturaEmPreco = 400 * _Point;
   int barraQuadrado = indiceToque;

   Print("Acompanhando movimento a partir do toque...");

   // Percorre as velas para acompanhar o fundo e verificar rompimento
   for(int i = indiceToque - 1; i >= 0; i--)
   {
      double high = iHigh(_Symbol, _Period, i);
      double low = iLow(_Symbol, _Period, i);
      double close = iClose(_Symbol, _Period, i);
      datetime tempo = iTime(_Symbol, _Period, i);

      // Atualiza o fundo se desceu
      if(low < fundoQuadrado)
      {
         fundoQuadrado = low;
         tempoQuadrado = tempo;
         barraQuadrado = i;
         Print("Fundo atualizado na barra ", i, " | Novo fundo: ", fundoQuadrado);
      }

      // Verifica se rompeu o topo do quadrado
      double topoQuadrado = fundoQuadrado + alturaEmPreco;

      if(close > topoQuadrado)
      {
         Print("ROMPIMENTO DETECTADO na barra ", i, " | Close: ", close, " | Topo: ", topoQuadrado);
         Print("Quadrado final - Tempo: ", TimeToString(tempoQuadrado), " | Base: ", fundoQuadrado);

         // Cria o quadrado na posição final
         CriarQuadradoAnalise(tempoQuadrado, fundoQuadrado, 10);

         analiseAtiva = true;
         barraInicio = barraQuadrado;
         fundoAtual = fundoQuadrado;
         rompeuTopo = true;

         ChartRedraw(0);
         Alert("Análise concluída: Rompimento detectado!");
         return;
      }
   }

   // Se chegou aqui, o preço ainda não rompeu - deixa o quadrado acompanhando
   Print("Preço ainda não rompeu - Quadrado posicionado no último fundo");
   Print("Quadrado - Tempo: ", TimeToString(tempoQuadrado), " | Base: ", fundoQuadrado);

   CriarQuadradoAnalise(tempoQuadrado, fundoQuadrado, 10);

   analiseAtiva = true;
   barraInicio = barraQuadrado;
   fundoAtual = fundoQuadrado;
   rompeuTopo = false;

   ChartRedraw(0);
   Alert("Análise ativa: Acompanhando o movimento");

   Print("===== ANÁLISE CONCLUÍDA =====");
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
   // Se análise está ativa e ainda não rompeu, atualiza o quadrado em tempo real
   if(analiseAtiva && !rompeuTopo && ObjectFind(0, nomeQuadradoAnalise) >= 0)
   {
      // Obtém o fundo atual do quadrado
      double baseAtual = ObjectGetDouble(0, nomeQuadradoAnalise, OBJPROP_PRICE, 0);
      double topoAtual = baseAtual + (400 * _Point);

      // Verifica as últimas barras
      for(int i = 0; i < 10; i++)
      {
         double low = iLow(_Symbol, _Period, i);
         double close = iClose(_Symbol, _Period, i);

         // Se encontrou novo fundo, atualiza o quadrado
         if(low < baseAtual)
         {
            datetime tempo = iTime(_Symbol, _Period, i);
            CriarQuadradoAnalise(tempo, low, 10);
            fundoAtual = low;
            break;
         }

         // Se rompeu o topo, para a análise
         if(close > topoAtual)
         {
            rompeuTopo = true;
            Alert("Rompimento detectado em tempo real!");
            break;
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

   // Remove quadrado de análise
   ObjectDelete(0, nomeQuadradoAnalise);

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

   // Detecta redimensionamento do gráfico
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      ChartRedraw(0);
   }

   // Detecta quando um objeto é arrastado
   if(id == CHARTEVENT_OBJECT_DRAG)
   {
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

      // Atualiza linha azul quando as linhas pretas são movidas
      if(sparam == nomePontoSuperiorEsquerda || sparam == nomePontoCentroEsquerda)
      {
         ReposicionarLinhaAzul();
      }

      // Atualiza as linhas de Fibonacci
      AtualizarLinhasFibonacci();

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

   // Define tamanho do botão
   int larguraBotao = 120;
   int alturaBotao = 35;

   // Cria o botão
   if(!ObjectCreate(0, nomeBotaoAnalisar, OBJ_BUTTON, 0, 0, 0))
   {
      Print("ERRO ao criar botão Analisar. Erro: ", GetLastError());
      return;
   }

   // Define propriedades do botão
   ObjectSetInteger(0, nomeBotaoAnalisar, OBJPROP_XDISTANCE, BotaoPosX);
   ObjectSetInteger(0, nomeBotaoAnalisar, OBJPROP_YDISTANCE, BotaoPosY);
   ObjectSetInteger(0, nomeBotaoAnalisar, OBJPROP_XSIZE, larguraBotao);
   ObjectSetInteger(0, nomeBotaoAnalisar, OBJPROP_YSIZE, alturaBotao);
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

   // Define tamanho do botão
   int larguraBotao = 120;
   int alturaBotao = 35;
   int yPos = BotaoPosY + alturaBotao + 5;

   // Cria o botão
   if(!ObjectCreate(0, nomeBotaoInverterFibo, OBJ_BUTTON, 0, 0, 0))
   {
      Print("ERRO ao criar botão Inverter Fibo. Erro: ", GetLastError());
      return;
   }

   ObjectSetInteger(0, nomeBotaoInverterFibo, OBJPROP_XDISTANCE, BotaoPosX);
   ObjectSetInteger(0, nomeBotaoInverterFibo, OBJPROP_YDISTANCE, yPos);
   ObjectSetInteger(0, nomeBotaoInverterFibo, OBJPROP_XSIZE, larguraBotao);
   ObjectSetInteger(0, nomeBotaoInverterFibo, OBJPROP_YSIZE, alturaBotao);
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

   // Define tamanho do botão
   int larguraBotao = 120;
   int alturaBotao = 35;
   int yPos = BotaoPosY + (alturaBotao + 5) * 2;

   // Cria o botão
   if(!ObjectCreate(0, nomeBotaoReset, OBJ_BUTTON, 0, 0, 0))
   {
      Print("ERRO ao criar botão Reset. Erro: ", GetLastError());
      return;
   }

   ObjectSetInteger(0, nomeBotaoReset, OBJPROP_XDISTANCE, BotaoPosX);
   ObjectSetInteger(0, nomeBotaoReset, OBJPROP_YDISTANCE, yPos);
   ObjectSetInteger(0, nomeBotaoReset, OBJPROP_XSIZE, larguraBotao);
   ObjectSetInteger(0, nomeBotaoReset, OBJPROP_YSIZE, alturaBotao);
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

   // Remove o indicador atual e reinicializa
   OnDeinit(0);
   OnInit();

   Print("Indicador resetado!");
}

//+------------------------------------------------------------------+
