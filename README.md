# SupraNPC

Mod open source de companheiros humanos para **Project Zomboid Build 42.13.1** (Lua/Kahlua 5.1), em desenvolvimento.

**Versão atual: 0.1.14-dev — táticas de combate: empurrar/recuar, aproximar de zumbi caído, fuga sozinho e apoio com aliados.** O spawn e a renderização dos dois NPCs `IsoPlayer` foram **observados em jogo** nas capturas de 31/10/2026, mas navegação, HUD, save/load, IA e roupas novas ainda precisam de validação. O editor sequencial de jogador e NPCs já foi validado em jogo. O código de spawn foi integrado a partir do protótipo [ArayHumanNPCTest](https://github.com/llongaray/ArayHumanNPCTest), mas **a integração nova ainda não foi validada in-game**. Use um **save novo e descartável**.

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
