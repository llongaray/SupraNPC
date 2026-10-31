# SupraNPC — núcleo determinístico de comportamento

**Escopo técnico:** lógica pura em Lua/Kahlua 5.1. Não utiliza IA generativa, RN, RL, Ollama, Python, web, API externa, servidor HTTP nem programa adicional. O funcionamento dentro do Project Zomboid depende de um adaptador para personagens reais, que continua experimental na versão atual.

## Separação de responsabilidades

- `Roster.lua`: dados e fichas independentes do personagem, serializáveis.
- `Orders.lua`: intenções do jogador, prioridades, interrupções e restauração de ordens.
- `Config.lua`: parâmetros limitados/validados (sem ativar o spawn).
- `SpawnAdapter.lua` / `Renderer.lua`: interface experimental com o motor B42.
- **Pendente:** `PerceptionAdapter` lendo ameaças reais, `MovementAdapter` executando caminho e `CombatAdapter` verificando interações reais da engine.

A lógica pura **não pode** spawnar, mover, atingir, coletar ou alimentar personagens sozinha.

## Estados e prioridades

`Orders.new("FOLLOW")` cria uma ordem inicial. `Orders.set(state, "GUARD")` registra uma nova ordem do jogador. `Orders.setGuardPoint(state, x, y, z)` armazena um tile inteiro para guarda. Nenhum estado de emergência pode ser injetado como ordem do jogador.

A função `Orders.evaluate(state, sinais)` aplica, em ordem:

1. **RETREAT** — necessidade de retirada comprovada (`mustRetreat`);
2. **SELF_DEFEND** — ameaça direta contra o NPC (`selfThreat`);
3. **PROTECT** — jogador sob ameaça (`playerThreat`);
4. **PROTECT** — ameaça à região guardada (`guardThreat`), somente com ordem GUARD e tile definido;
5. **Ordem solicitada** — FOLLOW, GUARD, IDLE etc.

A prioridade acima é **de execução**, não a ordem das 11 entregas. O controlador não infere ameaças sozinho: um adaptador precisa passar booleanos a partir do mundo real.

**Exemplo puro:**

```lua
local Orders = require("SupraNPC/Orders")
local state = Orders.new("FOLLOW")
Orders.setGuardPoint(state, 10600, 9800, 0)
Orders.set(state, "GUARD")
Orders.evaluate(state, { guardThreat = true })
assert(state.active == "PROTECT")
Orders.evaluate(state, {}) -- ameaça terminou
assert(state.active == "GUARD")
```

Se o jogador enviar uma nova ordem durante um ataque, a ordem fica em `requested`; a ação de emergência continua até cessar a ameaça. A próxima avaliação retorna ao pedido mais recente.

## Estado salvo

`Orders.snapshot(state)` devolve **somente** primitivos Lua/tabelas novas, seguros para integrar ao `ModData`; não retorna referências Java. `Orders.restore(snapshot)` devolve o pedido e o ponto de guarda, mas **não restaura combate em andamento**: o ambiente deve reavaliar perigos reais depois de carregar o save.

É necessário ligar esse snapshot ao salvamento de ordens de cada NPC antes de marcar a persistência como funcional. O `Roster` atual ainda não chama `Orders.snapshot` automaticamente.

## Configurações disponíveis para o futuro adaptador

| Campo | Padrão | Intervalo |
|---|---:|---|
| followDistance | 2,5 | 1–8 tiles |
| guardRadius | 5 | 1–20 tiles |
| protectRadius | 8 | 2–25 tiles |
| thinkInterval | 20 | 5–120 ticks |
| stuckAfterTicks | 150 | 30–600 ticks |
| lowHealthThreshold | 0,25 | 0,05–0,70 |
| maxCompanions | 5 | 0–5 |
| autoDefend | true | Boolean |
| protectPlayer | true | Boolean |
| debug | false | Boolean |

`Config.sanitize(raw)` fornece uma tabela completa mais avisos; não altera `Core.EXPERIMENTAL_SPAWN`. Configurações não foram ligadas ainda aos controles in-game: são apenas base validada.

## Testes sem executar o jogo

```bash
lua5.1 tests/orders_engine_spec.lua
lua5.1 tests/config_spec.lua
```

CI: `.github/workflows/lua-check.yml`. Esses testes cobrem prioridades e limites do controlador, mas **não verificam** spawn humano, renderização, colisões, combate ou save/load da B42.13.1.

## Próxima integração, bloqueada por validação do NPC real

1. Confirmar identidade/câmera/renderização dos NPCs `IsoPlayer` na B42.13.1.
2. Criar adaptador de percepção com APIs comprovadas, sem suposições.
3. Executar somente FOLLOW e IDLE primeiro, sem ataques ou efeitos permanentes.
4. Integrar ponto de GUARDA e interrupções após testes de navegação.
5. Aplicar snapshots em saves somente depois de validar serialização e restauração real.

Não utilizar zumbis disfarçados: o protótipo `addZombiesInOutfit` foi descontinuado após gerar zumbis no teste.
