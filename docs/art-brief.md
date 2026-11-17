# Arte da janela: medidas e prompt

A janela tem tamanho fixo de **896 x 560** (proporção 16:10). A arte é uma
imagem única com a moldura inteira. O conteúdo do addon é desenhado por cima
do miolo, então o miolo precisa ser liso.

## Medidas

```
 0                                                              896
 +----------------------------------------------------------------+ 0
 |  faixa do título (72 px de altura)                             |
 |  título à esquerda .............. busca e botão de fechar      |
 +--+---------+----------------------------+---------------+------+ 72
 |  | filtros |  lista de feras            | modelo 3D     |      |
 |48|  160 px |  cerca de 386 px           | e detalhes    |  48  |
 |px|         |                            |  230 px       |  px  |
 |  |         |                            |               |      |
 +--+---------+----------------------------+---------------+------+ 512
 |  borda inferior (48 px)                                        |
 +----------------------------------------------------------------+ 560
```

- **Miolo livre:** de x=48 a x=848 e de y=72 a y=512 (800 x 440). Nada de
  enfeite, mancha ou desenho aí dentro.
- **Faixa do título:** os 72 px do topo. O título fica à esquerda e a busca
  à direita, por volta de y=28 a y=50, então a parte central dessa faixa
  também precisa ser lisa. Enfeites cabem nos cantos e na beirada de cima.
- **Bordas laterais e inferior:** 48 px. É onde a decoração pode aparecer
  à vontade.

## Escolha de cor do miolo

O texto do addon é claro (branco e dourado), e o modelo 3D aparece melhor
sobre fundo escuro. Por isso o prompt pede miolo de **couro escuro**. Se a
preferência for pergaminho claro, dá para fazer, mas aí as cores do texto
mudam para tons escuros. É uma decisão do dono.

## Prompt para o Nano Banana

Gerar em 16:10, na maior resolução disponível.

```
A user interface window frame for a fantasy RPG game, seen perfectly flat
from the front (orthographic, no perspective, no tilt), aspect ratio 16:10.

Theme: a rustic hunter's lodge. The frame is made of thick weathered dark
wood planks, lashed with leather straps and rope at the corners, with small
iron rivets. Decorations sit only on the border: a hunting longbow resting
along the very top edge, a quiver of arrows at the top right corner, oak
leaves and ivy creeping over the top left and bottom right corners, a few
feathers, a wolf paw print carved into the wood, and animal fang charms
hanging from one corner.

Border thickness: about 5% of the image width on the left and right sides,
about 8% of the image height at the bottom, and about 12% of the image
height at the top. The top border is a wide plain wooden plank whose middle
section is left clear and undecorated, to hold a title later.

The whole interior of the window, a large centered rectangle covering about
85% of the image, is one flat panel of dark brown tanned leather with a very
subtle grain, evenly lit and completely empty: no text, no letters, no
runes, no icons, no drawings, no stains, no objects, no vignette. Nothing
from the border may overlap or cast a shadow onto the interior panel.

Style: hand-painted stylized game interface texture, like classic fantasy
MMO interface art. Warm muted colors, soft even lighting.

Background outside the frame: solid pure magenta (#FF00FF), perfectly flat,
no gradient, no shadow. The frame fills the image, leaving only a thin
magenta margin around it. No drop shadow around the frame.
```

## O que conferir na imagem gerada

1. Vista frontal, sem perspectiva. Se sair inclinada, não serve.
2. Miolo liso e uniforme, sem nada invadindo.
3. Fundo magenta chapado, sem sombra da moldura sobre ele.
4. Sem letras ou símbolos que pareçam texto.

Salvar a imagem escolhida em `.cache/art/` (qualquer nome, PNG de
preferência).
