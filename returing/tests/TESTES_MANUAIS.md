# Testes manuais das habilidades novas

O que dá para checar sozinho está em `tests/habilidades_test.tscn` (`godot --headless --path . res://tests/habilidades_test.tscn`).
Esta lista cobre o que só os olhos e os ouvidos conferem. Para abrir uma fase já com as habilidades, dê as habilidades
pelo Inspector (`AbilityComponent > Abilities` no `Turing.tscn` da fase) ou suba de nível. Ativar: **Ctrl**, setas, **Enter**.

## Habilidades (ativar, ver o efeito, ver o fim, reativar)
| Habilidade | Sequência | Conferir |
|---|---|---|
| Reflexos | ↑ ← ↑ | O dash recarrega bem mais rápido por 10 s; o anel dourado do slot encolhe e some. Reativar só depois da recarga (14 s). |
| Carga Rápida | ↓ ↑ ↓ | A barra de carga do tiro enche em ~0,84 s (normal 1,2 s) por 10 s. |
| Pele de Ferro | → ↓ → | Os golpes dos inimigos tiram ~20% menos de vida por 10 s. |
| Pulso Gélido | ← ← ↑ → | Anel azul; inimigos no raio ficam azulados e lentos por 4 s; o chefe (Guide) não é afetado; ao fim a cor e a velocidade voltam. |
| Mina Binária | → ↓ ↓ ← | Mina "01" nos pés; ela pisca ao armar; explode quando um inimigo chega perto; some sozinha em 20 s. |
| Drone Aliado | ↑ ↑ → ← | Drone orbita e atira no inimigo mais próximo por 12 s; some no fim. |
| Tiro em Leque | → → ↓ ← | 5 tiros verdes em arco de 40° centrados no cursor. |
| Máquina Enigma | ← ↑ ← ↑ ↓ ↓ | Anel tracejado girando no jogador; todos os inimigos lentos por 8 s (chefe menos); apaga as outras habilidades (o menu avisa). |
| Overclock | ↑ → ↑ → ↓ ← | 10 s com anel dourado (+dano, +velocidade), depois 5 s com anel laranja/vermelho (penalidade); o anel do slot muda de cor. |

## HUD
- Ícones das 9 nítidos e distinguíveis a 1280x720 e 1024x768 (`godot --path . res://tests/hud_habilidades_novas.tscn`).
- Cartas do menu de escolha: nome e descrição sem corte; lendárias com o aviso de perda.
- Slot: varredura radial e tempo; anel de duração enquanto o efeito dura; HUD parada com o jogo pausado.
- Três habilidades ao mesmo tempo (máximo): nenhum slot sobreposto em 16:9 e 4:3.

## Ajustes
- **Escudo:** ao acabar os 3 s toca um "bip" curto descendente e o círculo abre um anel; morrer com o escudo ativo não toca.
- **Pulso EMP:** com Ctrl aberto e o EMP pronto, digitar ↓ mostra um círculo azul fraco com o alcance; errar, fechar o modo, ativar ou estar em recarga esconde.
- **Rastro de Fogo:** halo de fogo na frente da espada enquanto armado; some ao golpear, ao passar 8 s, ao morrer.
- **Tiro Perfurante (celular, `-- --mobile`):** com a mira assistida ligada o tiro sai reto na linha do toque.
- **Reroll:** botão "Rerrolar (1 por run)" no menu de escolha (mouse, teclado, controle e toque); depois de usado fica desabilitado; cancelar a confirmação de uma lendária não gasta; run nova libera de novo.
- **Cura:** recupera 4 unidades da barra (33 HP) a cada 36 s.
- Morrer com buffs ativos e conferir que velocidade, dash, carga e dano voltam ao normal na fase seguinte.
