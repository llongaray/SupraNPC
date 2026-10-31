# SupraNPC

Mod open source de companheiros humanos para **Project Zomboid Build 42.13.1** (Lua/Kahlua 5.1), em desenvolvimento.

**Versão atual: 0.1.11-dev — correção de navegação, roupas pré-spawn, retratos 3D e avaliação médica com o componente corporal vanilla.** O spawn e a renderização dos dois NPCs `IsoPlayer` foram **observados em jogo** nas capturas de 31/10/2026, mas navegação, HUD, save/load, IA e roupas novas ainda precisam de validação. O editor sequencial de jogador e NPCs já foi validado em jogo. O código de spawn foi integrado a partir do protótipo [ArayHumanNPCTest](https://github.com/llongaray/ArayHumanNPCTest), mas **a integração nova ainda não foi validada in-game**. Use um **save novo e descartável**.

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
