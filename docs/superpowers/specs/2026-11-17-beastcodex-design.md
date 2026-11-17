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
- Fonte dos dados: Petopia Forever (https://www.wow-petopia.com/forever/)
  para criaturas, e Wowhead Forever para coordenadas (o mapa da página de
  cada NPC, `https://www.wowhead.com/forever/npc=<id>`).
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
- Ordem: dados, depois addon funcionando, depois arte. A versão 1 só é
  publicada com a arte.

### Publicação e créditos

- Repositório GitHub privado até a publicação.
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
