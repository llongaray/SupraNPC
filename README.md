# SupraNPC

Mod open source de companheiros humanos para **Project Zomboid Build 42.13.1** (Lua/Kahlua 5.1), em desenvolvimento.

**Versão atual: 0.1.20-dev — posturas funcionais PASSIVE (foge sem combater), DEFENSIVE (combate primeiro e recua em desvantagem) e AGGRESSIVE (caça zumbis e não foge automaticamente).** O spawn e a renderização dos dois NPCs `IsoPlayer` foram **observados em jogo** nas capturas de 31/10/2026, mas navegação, HUD, save/load, IA e roupas novas ainda precisam de validação. O editor sequencial de jogador e NPCs já foi validado em jogo. O código de spawn foi integrado a partir do protótipo [ArayHumanNPCTest](https://github.com/llongaray/ArayHumanNPCTest), mas **a integração nova ainda não foi validada in-game**. Use um **save novo e descartável**.

## Instalação direta via Git

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\Zomboid\mods" | Out-Null
Set-Location "$env:USERPROFILE\Zomboid\mods"
git clone https://github.com/llongaray/SupraNPC.git SupraNPC
```

Se já estiver instalado, feche o jogo e atualize com:

```powershell
git -C "$env:USERPROFILE\Zomboid\mods\SupraNPC" pull origin main
```

O diretório `SupraNPC/42/mod.info` fica dentro da raiz clonada. Ative o mod no menu Mods do jogo.

## Posturas reais de combate — 0.1.20-dev

As posturas deixam de ser apenas um alcance de percepção. O módulo `StancePolicy.lua` governa **interrupções, retirada e combate**:

| Postura | Prioridade | Detecção | Fuga |
| --- | --- | --- | --- |
| **PASSIVE** | Não lutar, evitar inimigos, fugir | Até 9 tiles | Qualquer ameaça visível no alcance; nunca SHOVE/SWING/STOMP |
| **DEFENSIVE** | Combater; recuar em desvantagem relevante | ~5,5 tiles para interceptação | Três ou mais inimigos sem apoio corpo a corpo, desvantagem importante em hordas, ou ferimento crítico |
| **AGGRESSIVE** | Perseguir e eliminar zumbis acima de FOLLOW/GUARD | Até 12 tiles | Sem fuga automática por desvantagem; pode morrer tentando lutar |

A troca de postura cancela a tática antiga (inclusive RETREAT) e recalcula o combate preservando a ordem original. Um NPC passivo pode retornar para a base em fuga. Zumbis caídos distantes também são considerados na perseguição agressiva.

**Importante:** AGGRESSIVE não habilita inteligência para armas de fogo nem garante ataques bem-sucedidos no IsoPlayer não controlado; a integração do combate nativo B42 continua experimental. Obstruções e verificação de aliados permanecem.

[Teste de campo e checklist 0.1.20](docs/TEST_CHECKLIST_0.1.20.md).

## Correção 0.1.19-dev — diagnóstico de console.txt real

O teste com Project Zomboid B42.13.1 revelou **352 exceções repetidas** por tentar consultar `getSymbolCount` sobre o objeto Java não exposto de `MapItem:getSymbols()`. O código agora usa somente a API UIWorldMap de símbolos acessível pelo Lua e **nunca indexa métodos diretamente no objeto bruto WorldMapSymbols**. Se essa API não estiver disponível, mantém os dados de território do save sem gerar erro.

A autodefesa também liberará o estado `FLEE` após **4,5 segundos sem novo avistamento** de ameaça; a memória visual continua válida durante esse intervalo e não é renovada só pela presença do objeto zombie na memória.

**Importante:** isso corrige o flood de exceções e a memória de fuga. Não significa que a leitura dos dois marcadores BASE já esteja validada em todas as interfaces de mapa B42.13.1. [Checklist de teste 0.1.19](docs/TEST_CHECKLIST_0.1.19.md).

## Novidades 0.1.18-dev — furtividade, movimento e base no mapa

- **Movimento automático:** WALK, SNEAK e RUN por API nativa IsoPlayer. Agacha quando o jogador agacha ou há inimigos distantes, tenta correr durante fuga e quando fica mais de 5,5 tiles para trás. O roteador evita tiles próximos de zumbis e permite afastar-se quando cercado.
- **Portas e janelas:** continua tentando abrir portas e janelas destrancadas; janela só é escalada se aberta, não barricada, sem vidro quebrado perigoso, destino livre, sem zumbis próximos e canClimbThrough retorna verdadeiro. Usa climbThroughWindow nativo (não teleporta). Suspende novas ordens enquanto a animação de escalada prossegue.
- **BASE de NPCs:** usando lápis/caneta e a ferramenta de anotações de TEXTO do mapa original, escreva **NPC:BASE:A** e **NPC:BASE:B** em cantos opostos da casa. O retângulo entre os pontos vira a base da equipe, persistida no ModData do jogador. Uma anotação **NPC:BASE** sozinha define uma área 7x7 inicial.
- **Retirada:** em situação de perigo, tenta fugir na direção da base usando rota transitável e evitando zumbis; se não houver acesso seguro, recua localmente. Há a ordem de menu **Retornar para base** e comando por ditado **"Yong, volta para base"**.
- **Conhecimento do mapa:** notas NPC:LOOT, NPC:CLEAR, NPC:DANGER, NPC:RALLY, NPC:SUPPLY e NPC:HOSPITAL são classificadas e ficam disponíveis à equipe para futuros sistemas de missão. Notas comuns e ícones também são preservados como pontos de interesse.
- **Limitações:** a base é designada pelo jogador, sem validação física de cercamento/segurança. A delimitação ainda não tem overlay gráfico. Saque e limpeza de áreas marcadas NÃO são executados nesta versão. Dependendo da API B42, a leitura das coordenadas poderá exigir abrir o mapa; o conhecimento previamente salvo é preservado.

**Interações experimentais na Build 42.13.1:** confirmar animações de corrida, agachamento, escalada e leitura do mapa no jogo real. Testes Lua passam, mas não reproduzem a engine.

[Checklist e instruções da v0.1.18](docs/TEST_CHECKLIST_0.1.18.md).

## Ajustes após o teste de 31/10/2026 (v0.1.12-dev)

O teste in-game da 0.1.11 confirmou **roupas completas e retratos 3D**, mas os NPCs não caminharam; "Aguardar aqui" também não interrompia fisicamente o personagem e fome/sede/dor/energia apareciam como N/D.

**Causa técnica / alteração:**
- O protótipo próprio [ArayHumanNPCTest](https://github.com/llongaray/ArayHumanNPCTest) controla a locomoção com `ISWalkToTimedAction:new(npc,square)` e `ISTimedActionQueue.add(action)`, validando a fila por entidade. O `SupraNPC` agora utiliza um adaptador `NPCWalking.lua` baseado nesse código. Isso substitui o loop anterior de `PathFindBehavior2:update()`, que não produziu movimento no teste.
- Seguir: seleciona tile livre próximo ao jogador e mantém uma caminhada de cada vez; um deslocamento significativo do alvo replaneja a rota.
- Aguardar: invalida a ação em andamento, força seu encerramento, retira **somente** o TimedAction desse NPC e cancela o caminho nativo; não usa a fila do jogador.
- Guardar: fica parado se já estiver na posição, ou caminha para o ponto gravado. Se o tile estiver ocupado, procura um adjacente livre.
- `Health.lua`: para B42 lê `Stats:get(CharacterStat.HUNGER/THIRST/PAIN/ENDURANCE)`; getters antigos como fallback. Não inventa valores.
- `NPCSpeech.lua`: o jogador tem falas visíveis em comandos de seguir, aguardar, guardar e alterar postura. Baseado no desenho de bolhas do protótipo.
- O painel da equipe diferencia a **ordem solicitada** do **estado de execução** `MOVING`, `WAITING`, `NEAR`, `HOLD`, `FAILED` e `BLOCKED`.

**ATENÇÃO:** testes de Lua 5.1 e mocks não simulam a engine. Movimentação e áudio/texto em jogo continuam pendentes de validação na B42.13.1; não é uma correção confirmada até o próximo teste real. A ordem "postura agressiva" ainda não implementa combate.

Checklist: [TEST_CHECKLIST_0.1.12.md](docs/TEST_CHECKLIST_0.1.12.md). Use apenas save descartável.

## Autodefesa prioritária — 0.1.13-dev

**Novo:** módulo `NPCDefense.lua`, comportamento Lua determinístico de sobrevivência sem IA externa. Ele procura zumbis `IsoZombie` vivos e visíveis em raio curto, nunca jogadores ou outros NPCs, e interrompe qualquer tarefa para enfrentar o perigo.

**Fluxo:** `FOLLOW` → `SELF_DEFEND` (temporário) → `FOLLOW` após desaparecer a ameaça. Também funciona com `IDLE` e `GUARD`, e preserva ordens novas dadas durante o combate. Interrupções de combate têm precedência sobre o submenu de posturas (Passiva, Defensiva e Agressiva ainda não mudam o estilo de luta).

Ataque **corpo a corpo**, com arma equipada ou `Base.BareHands` nativa se disponível, usando `IsoZombie:Hit` e limites de alcance, visibilidade e cooldown. Aproximação limitada por `NPCWalking`, sem perseguição por todo o mapa. O ataque é alvo-específico, evitando acertar o jogador ou outros NPCs por uma seleção automática de alvo.

**Limitações:** a aplicação de dano real, animação e retomada de locomoção na engine 42.13.1 **não foram validadas in-game**. Testes de unidade do motor determinístico passam, mas não atestam dano efetivo no jogo. Nenhuma arma ou entidade de zumbi é criada pelo mod. Não há combate com armas de fogo, esquiva ou estratégia de múltiplos inimigos nesta versão.

[Checklist de combate](docs/TEST_CHECKLIST_0.1.13.md) e referências ao código de Super Survivors, PZNS e KnoxSurvivors.

## Combate tático de sobrevivência — 0.1.14-dev

A nova máquina determinística `CombatTactics.lua` substitui a política anterior de atacar todo zumbi assim que estivesse próximo.

- **1 ou 2 zumbis de pé:** empurrar e reavaliar. Se o inimigo não cair, recuar, esperar e tentar novamente.
- **Zumbi caído:** aproximar até alcance de finalização; somente golpear se não houver zumbis em pé próximos. Se ele começar a levantar, suspender a finalização.
- **3 ou mais zumbis sem ajuda:** empurrar para abrir espaço, depois fugir para um tile carregado seguro, inclusive quando algum cair.
- **3 ou mais zumbis com jogador ou outro NPC vivo perto:** alternar empurrão/recuo/espera até deixar de haver zumbis em pé, depois finalizar os caídos.
- **Retorno à tarefa:** FOLLOW, GUARD ou IDLE continuam salvos durante a emergência e são retomados assim que não houver ameaças visíveis no raio.

O módulo só conta zumbis reais `IsoZombie` vivos e visíveis. O jogador e outros NPCs nunca são alvos selecionados. Não usa IA neural ou modelos externos.

**Limitações a validar na B42.13.1:** o empurrão usa a API de queda `knockDown` com chance e só aceita o estado de queda ao observá-lo; a animação original de shove não está comprovada. `PIN` aproxima o NPC do corpo, mas ainda não garante impedir que o zumbi levante por colisão. `STOMP` usa dano direcionado ao zumbi, mas a animação de pisoteio também precisa de validação. A movimentação física e a estratégia com vários NPCs continuam experimentais.

[Checklist específico da 0.1.14-dev](docs/TEST_CHECKLIST_0.1.14.md).

## Navegação consciente de obstáculos — 0.1.17-dev

Depois do teste real da 0.1.16, o NPC ficava afastado do jogador e tentava perseguir inimigos atrás de portas/janelas fechadas. As alterações desta versão tratam **seguir, replanejar e reconhecer acessibilidade**:

- **FOLLOW 1,3 tile:** reduzido de 2,5. Rotas locais por `NPCNavigation.next` e replanejamento quando o jogador muda de posição. Sem teleportes.
- **Portas:** verifica travas e barricadas, aproxima-se e tenta `ToggleDoor(npc)` **uma vez**. Se não abrir, evita a passagem por 14 segundos e tenta encontrar outra rota. Não força destravamento.
- **Janelas:** tenta `ToggleWindow(npc)` uma vez quando bloqueiam rota, mas não assume que janela aberta é atravessável. Escalar janelas ainda precisa ser implementado com estado nativo específico.
- **Roteamento:** busca limitada a 16 tiles/640 nós em caminhos livres, excluindo paredes, janelas e portas trancadas. A defesa passa a abordar zumbis por rotas acessíveis.
- **Zumbis inacessíveis:** deixam de ser atacados através de obstáculos. Quando não existe rota, são ignorados por 14 segundos e o NPC retoma a ordem sem insistir no mesmo bloqueio.
- **Segurança:** nenhuma modificação de travas, barricadas ou saúde do obstáculo. Não mexe na fila do jogador.

**Ainda experimental na B42.13.1:** `ToggleDoor`, `ToggleWindow`, passagem real, rotas entre edifícios e movimento fluido requerem teste no jogo. [Checklist 0.1.17](docs/TEST_CHECKLIST_0.1.17.md).

## Atualizações 0.1.16-dev — ataque nativo e comandos ditados

**Correção após teste real da 0.1.15:** o zumbi caía, mas NPC não o finalizava, e a postura AGGRESSIVE não influenciava a estratégia. Agora `NPCNativeAttack.lua` tenta usar **`IsoPlayer:DoAttack(1.0)`** em lugar da alteração manual de vida de `IsoZombie`: próximo em pé = empurrar; com arma melee a uma distância segura = golpear; no chão = selecionar ataque descendente pelo motor. A implementação respeita animação em andamento, oclusão, alcance, aliados no arco de ataque e somente NPCs do mod. **A B42.13.1 ainda precisa comprovar se esse `DoAttack` é funcional para NPC IsoPlayer não controlado.** O fallback de testes não substitui a animação da engine.

- Postura PASSIVE só intercepta a curta distância (~2.2 tiles); DEFENSIVE a ~5; AGGRESSIVE até ~9, interrompendo FOLLOW para tentar aproximar e atacar. Risco de horda mantém prioridade sobre perseguir.
- Reconhecimento de zumbis a curta distância considera tiles adjacentes não bloqueados mesmo se o NPC estiver de costas, sem detecção atravessando paredes.
- `VoiceCommands.lua` interpreta frases PT-BR como **"Yong, me segue"**, **"Todos, me sigam"**, **"Yong, aguarde aqui"**, **"Yong, guarda aqui"** e **"Alex, postura agressiva"**. O HUD tem campo **COMANDO DE VOZ (WIN+H)** com envio por Enter: no Windows 11, o jogador pode usar o ditado do sistema (Win+H), exigindo Internet e microfone. O NPC responde em texto. **Não é um microfone em escuta contínua dentro do jogo.**
- A inspiração de diálogos contextuais vem de [Conditional Speech](https://github.com/Chuckleberry-Finn/zomboid-cnd-speech), que **gera frases textuais condicionais**; ele não faz reconhecimento de fala. Implementação própria, sem copiar seus arquivos.
- Testes adicionais `native_attack_spec.lua` e `voice_commands_spec.lua` na CI.

[Checklist e instruções de teste B42.13.1](docs/TEST_CHECKLIST_0.1.16.md).

## Correções após o teste real da 0.1.14 (v0.1.15-dev)

O teste confirmou **Seguir**, balões do jogador, empurrão e saúde do NPC. Identificou visão de curta distância, empurrão interrompido por fuga, demora em fugir diante de horda e ausência de respostas dos NPCs.

- **Percepção:** novo `NPCPerception.lua` usa cone de 130° até 12 tiles, detecção próxima 360°, oclusão por `CanSee()`, contagem de zumbis na área e antecipação de hordas. Dentro de ~8 tiles de um zumbi visto o NPC pode interceptar antes de ser atacado.
- **Equipamento e risco:** avalia arma melee, desarmado e arma de fogo do próprio NPC, jogador e companheiros próximos. Usa escore determinístico para decidir lutar/recuar/fugir; **não inventa porcentagem de morte**. Armas de fogo ainda não disparam autonomamente.
- **Combate:** 1–2 zumbis = empurrões sucessivos até queda real ou necessidade de recuar; grupos grandes e apoio insuficiente = fugir imediatamente. 3+ com membros melee preparados = continuar controlar via empurrão/recuo.
- **Bug do FLEE:** a `ISWalkToTimedAction` de fuga permanece enfileirada até concluir/falhar; não é cancelada e recriada em cada ciclo. Assim o NPC pode começar a correr antes de ficar cercado.
- **Voz textual:** `NPCSpeech.lua` agora desenha respostas dos NPCs e avisos como "Tem muitos! Foge!", "Estamos sem armas!" e "Socorro! Preciso de ajuda!", com cooldown.

A experiência em jogo **ainda não foi validada nesta versão**, embora o GitHub Actions execute os testes de lógica. O controle da caminhada em interiores, o alcance efetivo da visão e a animação/dano dos golpes continuam dependentes da engine B42.13.1.

[Checklist de teste 0.1.15-dev](docs/TEST_CHECKLIST_0.1.15.md).

## Estado das funcionalidades

| Recurso | Situação |
|---|---|
| Selecionar de 0 a 5 NPCs na criação de nova partida | Implementado |
| Editor de profissão/traços/aparência por NPC, sequencial | Validado pelo usuário em B42.13.1 |
| Fichas individuais, IDs e armazenamento no save | Implementado; persistência do elenco validada no teste anterior |
| Instanciação de corpo humano com `IsoPlayer.new` e `setNPC(true)` | **Dois NPCs visíveis no teste da B42.13.1; controle e persistência ainda não validados** |
| Spawn próximo do jogador em tile livre | **Visualmente confirmado com 2 NPCs** |
| Render extra via `RenderOpaqueObjectsInWorld` (FBO) | **Dois NPCs visíveis; estabilidade e oclusão ainda em testes** |
| Restaurar jogador/câmera após criar um IsoPlayer | Implementado, **em teste** |
| Recuperação do NPC após carregar save | Parcial; sem duplicação automática |
| Nome/aparência/roupas do editor | Captura roupas e propriedades visuais (cor, hue, textura), aplica no spawn; teste in-game pendente |
| Controlador de ordens FOLLOW/GUARD/PROTECT/SELF_DEFEND/RETREAT | **Motor determinístico puro implementado, ainda não conectado ao NPC** |
| Detecção anti-stuck | **Núcleo com retries limitados e testes, ainda não integrado à navegação** |
| Configurações limitadas de comportamento | **Validação disponível, integração ao jogo pendente** |
| Seguir jogador, guarda, defesa, looting, crafting, comida, cura, Base Zone e missões | **Ações no mundo não funcionais nesta versão** |

### Por que mudamos o spawn?

A versão 0.1.3 tentou `addZombiesInOutfit` e realmente gerou **zumbis**, não NPCs. Essa API foi eliminada do adaptador ativo.

Em nosso projeto anterior, [`ArayHumanTest.lua`](https://github.com/llongaray/ArayHumanNPCTest/blob/main/42/media/lua/client/ArayHumanTest.lua) já criava `IsoPlayer` nativo, marcava `setNPC(true)`, registrava a entidade no square, restaurava o jogador e fazia render manual para a B42. A versão 0.1.7 integra esses mecanismos ao fluxo de fichas do SupraNPC.

**Nota:** não instale simultaneamente o ArayHumanNPCTest, NPC Helper Mod ou outros mods de NPC durante os testes. Não use em saves importantes. O retorno do jogo ao mundo na 0.1.6 foi observado; as novas entidades da 0.1.7 ainda não foram verificadas.

## Arquitetura

- `42/media/lua/client/SupraNPC/TeamSetup.lua`: seletor do tamanho da equipe;
- `TeamFlow.lua`: telas sequenciais e captura de fichas;
- `Boot.lua`: persistência das fichas e ciclo seguro de spawn;
- `SpawnAdapter.lua`: criação de `IsoPlayer`, `ModData` e posicionamento;
- `Renderer.lua`: renderização do `IsoPlayer` extra e manutenção da visibilidade;
- `Follow.lua`: rascunho, ainda não ativado nesta etapa;
- `42/media/lua/shared/SupraNPC/Roster.lua`: validação e cópia das fichas.

Não são exigidos Python, Ollama, drivers específicos, servidores ou downloads externos: apenas o jogo e o próprio mod.

## Novos módulos da v0.1.8-dev

- `shared/SupraNPC/Orders.lua`: ordens manuais, regras de interrupção, decisão por sinais e snapshots para um futuro save.
- `shared/SupraNPC/Config.lua`: parâmetros com limites seguros, defaults e validação; não habilita spawn.
- `shared/SupraNPC/NavMonitor.lua`: detector puro de travamento de navegação; sinaliza REPATH ou BLOCKED sem movimentar entidades.
- `docs/DETERMINISTIC_ENGINE.md`: contratos, prioridades e lacunas de integração.
- `docs/QA_MATRIX_B42_13_1.md`: matriz de teste in-game com status não executado.

**Atenção:** os novos módulos de IA determinística **ainda não foram ligados** ao `IsoPlayer` experimental. Não há combate, seguimento ou proteção jogável. Nenhuma dependência de modelos de IA, Python, Ollama ou servidores foi adicionada.

## Vestuário e HUD — 0.1.9-dev

O teste de 31/10/2026 exibiu **2 NPCs humanos próximos ao player**, mas ambos apareceram de roupa íntima. O `SpawnAdapter` anterior aplicava somente um kit fixo de três peças e podia falhar por incompatibilidade de body location.

A rotina `client/SupraNPC/Wardrobe.lua` lê as peças realmente escolhidas do `SurvivorDesc:getWornItems()` na conclusão do editor e salva os tipos, tint, hue e índices visuais em cada ficha. No primeiro spawn, tenta gerar e vestir os itens correspondentes via inventário do NPC e `setWornItem`, com logs de sucesso/falha. **Agora há tentativa de restaurar cores, tonalidades e variações de textura pela API ItemVisual; fidelidade total ainda não foi verificada in-game.** O resultado ainda necessita teste na B42.13.1.

**Faça um save novo para esse teste:** os saves criados com versões anteriores não possuem `appearance.clothing` na ficha e podem manter NPCs já spawnados sem reaplicar roupa. Não clonar o NPC novamente automaticamente.

A janela adicional **"Vida do Jogador"** mostrada no teste foi registrada como problema de interface: o motor pode identificar um `IsoPlayer` extra como personagem jogável. Nenhuma modificação invasiva no HUD foi feita para não comprometer a câmera ou o player principal.

## Painel de NPCs e comandos — 0.1.10-dev

O novo `client/SupraNPC/NPCUI.lua` cria uma **barra lateral de equipe** com nomes e porcentagens de vida de até cinco NPCs e um painel independente de inspeção médica. Clique no nome para consultar a vida real via `BodyDamage` (saúde geral, ferimentos, sangramento, dor e necessidades). Dados ausentes aparecem como N/D, não são inventados. A janela vanilla adicional "Vida do Jogador" observada anteriormente ainda não foi removida por depender da engine.

No botão `>` de cada NPC, um menu de contexto com **submenus**:

- **Ordens:** Seguir o jogador (navegação experimental), Aguardar aqui, Guardar esta posição, Guardar ponto do jogador.
- **Postura:** Passiva, Defensiva ou Agressiva. **Atualmente apenas salva a preferência; combate ainda não foi implementado.**

As ordens são guardadas por personagem no `ModData` e no roster do save. O `NPCController.lua` solicita caminhos por APIs nativas disponíveis do IsoPlayer, sem teleporte. **O deslocamento efetivo e a estabilidade dessas chamadas precisam ser testados no jogo.** Ao voltar ao menu, o painel é removido para evitar interfaces duplicadas.

**Roteiro completo:** [docs/TEST_CHECKLIST_0.1.10.md](docs/TEST_CHECKLIST_0.1.10.md). Use save novo e descartável: as roupas de builds anteriores não continham o snapshot de todos os detalhes.

## Correções de regressão observadas na v0.1.10 (versão 0.1.11-dev)

As capturas de teste confirmaram: menu e painel lateral abrem, mas **nenhum NPC obedeceu às ordens**, ambos aparecem sem roupa e a UI médica era diferente da vanilla.

O controlador agora mantém e atualiza `PathFindBehavior2` durante a navegação, em vez de apenas solicitar a rota; também cancela a rota anterior ao mandar aguardar, informa falhas na barra lateral e desativa tentativas após erros repetidos. **Movimento real ainda não comprovado na Build 42.13.1.**

As roupas escolhidas agora são equipadas no próprio `SurvivorDesc` antes de construir o `IsoPlayer`, como faz o editor vanilla. Se faltarem peças após o spawn, são equipadas individualmente sem duplicar as existentes. Os retratos usam `ISUI3DModel`; o painel de saúde tenta usar `ISNewHealthPanel` para exibir a silhueta corporal original do jogo, com fallback.

**Essas alterações foram publicadas, mas não foram executadas neste ambiente do jogo.** O resultado de renderização, movimentação, roupas, estabilidade e ausência de crashes depende de novo teste.

Checklist: [v0.1.11-dev](docs/TEST_CHECKLIST_0.1.11.md).

## Validar o próximo marco

Siga [TEST_CHECKLIST_0.1.7.md](docs/TEST_CHECKLIST_0.1.7.md). O primeiro teste deve ser **1 NPC, save novo e descartável**. Procure `HUMAN SPAWN`, `Render humano ativo` e erros do `IsoPlayer` no arquivo `%USERPROFILE%\Zomboid\console.txt`.

Atenção à persistência: se um personagem já foi marcado `humanSpawned`, o mod não recria outro indiscriminadamente ao carregar. Ele procura reaproveitar o objeto existente para não gerar clones; se o motor não o persistiu, isso precisa ser investigado.

## Testes

GitHub Actions está configurado para executar `luac5.1 -p` e testes puros (a execução precisa ser verificada no Actions):

```bash
lua5.1 tests/roster_spec.lua
lua5.1 tests/team_flow_spec.lua
lua5.1 tests/spawn_proxy_spec.lua
lua5.1 tests/renderer_spec.lua
lua5.1 tests/orders_engine_spec.lua
lua5.1 tests/config_spec.lua
lua5.1 tests/nav_monitor_spec.lua
lua5.1 tests/wardrobe_spec.lua
lua5.1 tests/wardrobe_visual_spec.lua
lua5.1 tests/health_spec.lua
lua5.1 tests/npc_controller_spec.lua
```

Os testes verificam a lógica simulada, **não substituem o teste in-game de B42.13.1**.

### Relatórios anteriores

- [Crash de carregamento 0.1.6](docs/CRASH_0.1.6_LOG_ANALYSIS.md)
- [Tentativa inválida de zumbi proxy 0.1.3 — não executar](docs/TEST_CHECKLIST_0.1.3.md)
- [Arquitetura original](docs/ARCHITECTURE.md)

## Projeto

[Kanban no Trello](https://trello.com/b/kIsvUBhY/supranpc-project-zomboid-b42131)

Licença: GPL-2.0 — [LICENSE](LICENSE).
