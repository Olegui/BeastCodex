# Beast Codex: design

Data: 2026-11-17. Status: aguardando aprovação.

## O que é e por quê

Beast Codex é um addon de World of Warcraft Forever para caçadores. É um
grimório dentro do jogo com todas as feras listadas no Petopia Forever: as
que podem ser domadas e as que não podem (estas só como referência). O
jogador filtra, vê o modelo 3D, e marca no mapa onde a fera aparece para ir
domá-la.

Já existem addons parecidos no Forever (Hunter's Handbook, Hunter's Field
Guide, TameDex - Hunter's Bestiary, Huntmaster). O dono do projeto viu os
prints deles e achou o design vago. **O diferencial do Beast Codex é o
design:** uma janela artística, rústica, com cara de caçador, que não se
pareça com janela de addon comum. Uma versão que funciona mas parece uma
janela padrão não cumpre o objetivo.

## Objetivos

1. Listar todas as criaturas do Petopia Forever, uma linha por criatura
   (NPC), agrupadas por aparência.
2. Filtros: família, zona, faixa de nível (1-10, 11-20, e assim por diante).
3. Criaturas não domáveis aparecem na lista, visualmente apagadas e com o
   motivo quando o Petopia informa. Uma caixa permite escondê-las.
4. Modelo 3D da criatura ao passar o cursor na linha.
5. Botão "Mostrar no mapa": pins no mapa do mundo em todos os pontos de
   aparição da criatura.
6. Janela com arte própria (ver "Arte").
7. Interface traduzida conforme o idioma do cliente do jogador.

## Fora do escopo (versão 1)

- Rastrear quais pets o jogador já domou ou tem no estábulo.
- Guia de ranks de habilidade ou de treino do pet.
- Integração com TomTom ou seta de navegação.
- Janela redimensionável.
- Esconder o addon para outras classes (ele abre para qualquer classe).

## O que faria disso um fracasso

- Parecer uma janela de addon comum.
- Copiar imagens ou texto do Petopia. Só dados factuais (nome, nível, zona,
  habilidades) são usados, com crédito.
- Depender de outro addon instalado para os pins funcionarem.
- Erros de Lua no BugSack em uso normal.

## Decisões do dono do projeto

- Nome: **Beast Codex**. Pasta do addon e repositório: `BeastCodex`.
- Fonte dos dados, nesta ordem:
  1. **Huntmaster** (https://github.com/yurristudio/Huntermaster, licença
     MIT) como base: 334 criaturas domáveis com nome, ID, nível, família,
     dieta, raro/elite, coordenadas e ID do mapa do jogo.
  2. **Petopia Forever** (https://www.wow-petopia.com/forever/) para o que
     falta: aparências, criaturas indomáveis, famílias ausentes (Raptor,
     Core Hound), velocidade de ataque e criaturas que o Huntmaster não tem.
  3. **Wowhead Forever** (`https://www.wowhead.com/forever/npc=<id>`) só
     para coordenadas das criaturas que vierem do Petopia sem elas.
- Dados de addons com "todos os direitos reservados" (TameDex, Hunter's
  Field Guide) não são copiados. O Hunter's Handbook (GPLv3) não é usado.
- Disposição da janela: filtros à esquerda, lista ao centro, painel de
  detalhes com modelo 3D e botão do mapa à direita. Aprovada em esboço.
- Pins: um ou vários, conforme os pontos de aparição.
- Arte da janela gerada por ele no Gemini Nano Banana, a partir de um prompt
  que o construtor fornece.
- Arquivos de tradução por idioma.
- Projeto em `D:\Projetos\Addons\BeastCodex`, com repositório Git e GitHub.

## Restrições do ambiente

- Jogo em `C:\Program Files (x86)\World of Warcraft\_forever_`; addons em
  `Interface\AddOns`.
- O `.toc` declara só `## Interface: 16001`.
- Cliente moderno com conteúdo clássico: usar `C_Spell`, `C_Item`, `C_Map`
  e conferir se cada função existe antes de chamar.
- Dados salvos só vão para o disco no `/reload` ou ao sair.
- Arquivo novo no addon exige fechar e abrir o jogo; mudança em arquivo
  existente basta `/reload`.
- O dono usa FlareUI, BugSack e Auctionator. A bolsa de botões do FlareUI só
  padroniza botões registrados na LibDBIcon.
- Sem emojis de bandeira em README ou descrições.
- Prints do jogo: captura de tela por script PowerShell.
- Publicação: tag no GitHub dispara o empacotador do CurseForge; release do
  GitHub é feito à parte, com zip.

## Escolhas do construtor (não foram decididas pelo dono)

Estas são decisões minhas. O dono pode trocar qualquer uma.

### Dados

- O script lê primeiro o `Data/TameableNPCs.lua` do Huntmaster (cópia local
  em `.cache/`, fora do Git) e junta com o Petopia pelo ID do NPC. Quando
  os dois divergem num campo, vale o Huntmaster para coordenadas e mapa, e
  o Petopia para o resto; as divergências vão para o relatório.
- O README e o arquivo de licença trazem o aviso de direitos do Huntmaster
  (Yurri Studio e Justin Moody), como a licença MIT exige.
- Um script em `tools/` (Python, só biblioteca padrão) percorre o Petopia
  uma vez: famílias, aparências, criaturas. De cada criatura guarda nome,
  ID do NPC (do link do Wowhead), nível mínimo e máximo, raro, elite, zona,
  domável ou não, motivo, velocidade de ataque, habilidades ensinadas.
  Dieta vem da família.
- Para cada ID, o script busca a página do NPC no Wowhead Forever e extrai
  as coordenadas e o ID da zona do mapa embutido.
- O script guarda as páginas baixadas em cache local (fora do Git), espera
  entre requisições, e só roda quando o dono pedir. O addon nunca acessa a
  internet.
- A coleta do Wowhead é o maior risco dos dados (milhares de páginas, e o
  site pode barrar scripts). Por isso ela começa com um teste pequeno, de
  umas dez criaturas, antes de escrever o resto. O addon anterior do dono
  já gerou dados do Wowhead Forever, então há precedente. Se o script
  simples for barrado, a alternativa é coletar por um navegador de verdade.
  Se nem isso funcionar, o botão do mapa passa a abrir só a zona, sem pins,
  e isso volta para o dono decidir.
- Saída: arquivos Lua em `Data/`, gerados, não editados à mão.
- Autoverificação do script: a contagem de criaturas domáveis por aparência
  tem que bater com o "There are N tameable creatures with this look" do
  Petopia; criaturas sem coordenadas são listadas num relatório.
- Aparências "não usadas" que não têm nenhuma criatura ficam fora, porque a
  lista é de criaturas.

### Addon

- Lua puro, sem framework. Bibliotecas embutidas: LibStub,
  CallbackHandler, LibDataBroker e LibDBIcon (só para o botão do minimapa).
- Abre pelo botão do minimapa e por `/beastcodex`.
- Lista com rolagem virtual (reaproveita linhas), porque são centenas de
  criaturas.
- Busca por nome no topo.
- Faixas de nível geradas a partir do nível máximo que existir nos dados.
- Modelo 3D: tentar exibir pelo ID da criatura. Se o cliente Forever não
  permitir, o script passa a coletar também o ID de exibição no Wowhead.
- Pins: desenhados pelo próprio addon no mapa do mundo, sem biblioteca
  externa obrigatória. Ficam até o jogador limpar ou escolher outra fera.
  Criatura sem coordenadas: o botão fica indisponível e o painel diz que a
  localização é desconhecida.
- Zona do Wowhead para mapa do jogo: resolver em tempo de execução, casando
  o nome localizado da área com o nome do mapa. Se não funcionar no cliente
  Forever, o script gera uma tabela de correspondência.
- Dados salvos (`BeastCodexDB`): posição do botão do minimapa e últimos
  filtros. Nada mais.

- Agrupamento por aparência: linhas de cabeçalho fixas (não recolhem) com o
  nome da aparência, e as criaturas embaixo. Filtros e busca contam
  criaturas; cabeçalho sem criatura visível some.
- Passar o cursor numa linha mostra a prévia (modelo e detalhes) no painel
  da direita. Clicar fixa a criatura no painel, e é nela que o botão
  "Mostrar no mapa" age. Ao tirar o cursor, o painel volta para a fixada.

### Testes no jogo

- Só o dono roda o jogo. O construtor não controla o cliente.
- O construtor lê os resultados do disco depois de um `/reload`: os dados
  salvos do addon e os do BugSack em `WTF\Account\<conta>\SavedVariables`,
  e os prints feitos pelo script PowerShell.
- Primeiro passo no jogo: um addon de sondagem descartável que testa de uma
  vez os três pontos incertos (modelo 3D por ID da criatura, casar zona com
  mapa pelo nome, desenhar pins no mapa do mundo) e grava o resultado nos
  dados salvos. O resto do plano depende do que a sondagem mostrar.
- Depois disso, cada etapa termina com um ponto de conferência do dono no
  jogo.

### Idiomas

- `Locales/` com um arquivo por idioma: enUS, deDE, esES, esMX, frFR, itIT,
  koKR, ptBR, ruRU, zhCN, zhTW. Inglês é a reserva.
- Só os textos da interface são traduzidos nesses arquivos. As traduções
  são feitas pelo construtor, sem revisão de falante nativo.
- Nomes de famílias, zonas e criaturas: usar os nomes que o próprio jogo
  fornece quando houver função para isso; senão ficam em inglês.

### Arte

- Janela de tamanho fixo. A arte é uma imagem única da moldura inteira com o
  miolo liso, mais peças pequenas se necessário (botões, marcador de pin).
- O construtor define as medidas e entrega ao dono um prompt para o Nano
  Banana, com as áreas que precisam ficar livres e fundo de cor sólida para
  recorte. O construtor recorta, redimensiona e converte para TGA.
- Tema: rústico e selvagem. Madeira, couro, pergaminho, folhas, arco ou
  espingarda.
- Enquanto a arte não chega, o addon usa uma moldura provisória simples. A
  disposição já respeita as medidas da arte final, para a troca ser só de
  textura.
- Quem julga a arte é o dono. A etapa de arte termina quando ele aprova um
  print da janela dentro do jogo. Não há limite fixo de rodadas de geração.
- Se o gerador não conseguir respeitar as áreas livres numa imagem única, a
  moldura passa a ser montada em peças (cantos, bordas, fundo). A
  disposição do conteúdo não muda.
- Ordem: dados, depois addon funcionando, depois arte. A versão 1 só é
  publicada com a arte.

### Mudança de 2026-11-17: arte primeiro, dois temas

Decisão do dono, depois de ver o addon funcionando: a arte vem antes da
disposição, e não o contrário. Ele gerou dois conceitos no Nano Banana e
quer os dois como temas para testar no jogo.

- **Tomo:** livro de caçador aberto sobre uma mesa, pergaminho, texto escuro.
- **Selva:** interface moderna de painéis verde-escuros com detalhe âmbar e
  folhas tropicais nas bordas, texto claro.

O que isso muda em relação ao que está escrito acima:

- A janela deixa de ter medidas fixas próprias. Cada tema traz a sua
  textura, as posições de cada área (medidas na imagem) e as cores de texto.
  `Skin.lua` guarda os temas; `UI/*.lua` só lê posições e cores de lá.
- Um tema "classic", sem arte, continua existindo como reserva.
- Troca de tema por `/beastcodex theme <nome>`, que recarrega a interface.
- Botões, campos e caixa de marcar são do próprio addon (sem modelos da
  Blizzard), para a arte aparecer e o FlareUI não repintá-los.
- A imagem de cada tema precisa de uma versão limpa (sem texto nem animal,
  fundo magenta), gerada pelo dono a partir do conceito.
- `docs/art-brief.md` (moldura única de 896 x 560) ficou obsoleto.

### Publicação e créditos

- Repositório GitHub privado até a publicação: `Olegui/BeastCodex`, já
  criado. O projeto no CurseForge ainda não existe, e é o dono quem cria.
- README e descrição do CurseForge dão crédito ao Petopia e ao Wowhead.

## Questões em aberto para o dono

1. **Permissão do Petopia.** O site diz "All rights reserved" e não tem
   política de reuso visível. Recomendo pedir permissão antes de publicar
   no CurseForge. Desenvolver e usar localmente não depende disso.
2. **Qualidade dos dados.** O Petopia avisa que os dados do Forever vêm do
   beta e estão incompletos para feras raras e de nível alto. O addon terá
   as mesmas lacunas até o script ser rodado de novo.

## O que fica para o construtor

Estrutura de arquivos, nomes internos, o desenho exato dos pins, as medidas
da janela, e a forma de extrair os dados de cada página.
