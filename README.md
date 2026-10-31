# SupraNPC

Mod open source de companheiros humanos para **Project Zomboid Build 42.13.1** (Lua/Kahlua 5.1), em desenvolvimento.

**Versão atual: 0.1.7-dev — spawn humano `IsoPlayer` e renderização experimentais.** O editor sequencial de jogador e NPCs já foi validado em jogo. O código de spawn foi integrado a partir do protótipo [ArayHumanNPCTest](https://github.com/llongaray/ArayHumanNPCTest), mas **a integração nova ainda não foi validada in-game**. Use um **save novo e descartável**.

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
| Instanciação de corpo humano com `IsoPlayer.new` e `setNPC(true)` | Integrada, **em teste** |
| Spawn próximo do jogador em tile livre | Integrado, **em teste** |
| Render extra via `RenderOpaqueObjectsInWorld` (FBO) | Integrado do ArayHumanNPCTest, **em teste** |
| Restaurar jogador/câmera após criar um IsoPlayer | Implementado, **em teste** |
| Recuperação do NPC após carregar save | Parcial; sem duplicação automática |
| Nome/aparência/roupas do editor | Nome/gênero, cabelo/barba e pele parciais; roupas básicas provisórias |
| Seguir jogador, guarda, defesa, looting, crafting, comida, cura, Base Zone e missões | **Não funcionais nesta versão** |

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

## Validar o próximo marco

Siga [TEST_CHECKLIST_0.1.7.md](docs/TEST_CHECKLIST_0.1.7.md). O primeiro teste deve ser **1 NPC, save novo e descartável**. Procure `HUMAN SPAWN`, `Render humano ativo` e erros do `IsoPlayer` no arquivo `%USERPROFILE%\Zomboid\console.txt`.

Atenção à persistência: se um personagem já foi marcado `humanSpawned`, o mod não recria outro indiscriminadamente ao carregar. Ele procura reaproveitar o objeto existente para não gerar clones; se o motor não o persistiu, isso precisa ser investigado.

## Testes

GitHub Actions executa `luac5.1 -p` e testes puros:

```bash
lua5.1 tests/roster_spec.lua
lua5.1 tests/team_flow_spec.lua
lua5.1 tests/spawn_proxy_spec.lua
lua5.1 tests/renderer_spec.lua
```

Os testes verificam a lógica simulada, **não substituem o teste in-game de B42.13.1**.

### Relatórios anteriores

- [Crash de carregamento 0.1.6](docs/CRASH_0.1.6_LOG_ANALYSIS.md)
- [Tentativa inválida de zumbi proxy 0.1.3 — não executar](docs/TEST_CHECKLIST_0.1.3.md)
- [Arquitetura original](docs/ARCHITECTURE.md)

## Projeto

[Kanban no Trello](https://trello.com/b/kIsvUBhY/supranpc-project-zomboid-b42131)

Licença: GPL-2.0 — [LICENSE](LICENSE).
