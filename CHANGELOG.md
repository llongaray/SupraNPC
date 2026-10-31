# Changelog — SupraNPC
## 0.1.20-dev — 2026-10-31

- Novo `StancePolicy.lua`: PASSIVE evita combate (FLEE diante de qualquer zumbi visível dentro de 9 tiles); DEFENSIVE prefere SHOVE/SWING/PIN/STOMP e recua apenas diante de risco elevado; AGGRESSIVE persegue até 12 tiles, prioriza eliminar zumbis, nunca opta por fuga automática devido a desvantagem.
- `NPCDefense.lua` passa os estados e o alcance da política ao planejador, com respeito a aliados, obstáculos e bloqueio de alvo.
- `CombatTactics.lua`: PASSIVE jamais executa golpes, AGGRESSIVE não herda o estado escape, grupos e zumbis caídos ao longe continuam sendo perseguidos.
- Mudança de postura em `NPCController.lua` reinicia estado de defesa e interrompe fuga anterior, preservando a ordem solicitada pelo jogador.
- Menu de posturas e falas descrevem as prioridades. Novos testes `stance_policy_spec.lua`, integração em `risk_combat_spec.lua`, `combat_tactics_spec.lua` e `defense_controller_integration_spec.lua`.
- **Pendente:** validar animações e aplicação de dano no Project Zomboid 42.13.1; modo AGGRESSIVE pode morrer contra hordas e não inclui IA de armas de fogo.

## 0.1.18-dev — 2026-10-31

- Movimento IsoPlayer: WALK/SNEAK/RUN por setSneaking/setRunning, conforme risco, postura do player, distancia de FOLLOW e retirada; sem alterar o player nem usar velocidade artificial.
- Roteador evita tiles de zumbis e permite se afastar se cercado. Fuga escolhe waypoint seguro e base marcada como destino preferencial; fallback para retirada local.
- Portas/janelas: estende abertura segura de janela com canClimbThrough e climbThroughWindow, destino livre, validação de vidro perigoso/ameaça, cooldown e bloqueio de novas ordens durante a animação.
- Territory.lua: area BASE:A/BASE:B retangular, BASE unico como regiao pontual, pontos NPC:LOOT/CLEAR/DANGER/RALLY/SUPPLY/HOSPITAL, notas livres e icones.
- NPCMapKnowledge.lua: leitura de MapItem e API UIWorldMap com coordenadas, sincronização com ModData do player, preservação se API de coordenadas não estiver disponível.
- Menu e voz adicionam RETURN_BASE; HUD mostra base e numero de anotações.
- Novas regressões: territory_spec, map_knowledge_spec, movement_style_spec, window climb e risk_combat com base. CI Lua 5.1.
- **Pendente in-game:** se IsoPlayer adicional respeita setSneaking/setRunning e climbThroughWindow na B42.13.1; disponibilidade real das coordenadas de anotações da UI; base é um perímetro manual, não é validação de segurança; missões não são executadas.

## 0.1.17-dev — 2026-10-31

- Follow reduzido para 1,3 tile; movimento agora usa waypoints adjacentes acessíveis em grade (16 tiles/640 nos) e recalcula quando player muda de posicao, sem teleporte.
- Novo `NPCNavigation.lua`: detecta portas, janelas, paredes e rotas bloqueadas; tenta abrir localmente portas destrancadas e janelas fechadas usando ToggleDoor/ToggleWindow, apenas uma vez; replaneja/evita por 14s ao falhar.
- Janelas abertas **não** habilitam travessia ou teleporte. Escalada, garagem e portas especiais ainda pendentes.
- Combate e ataque nativo checam acessibilidade por tile, impedindo contato atraves de janela/porta fechada.
- Alvos zumbis sem acesso sao ignorados temporariamente para evitar loop infinito de empurrões ou NPC parado.
- Testes de navegação `navigation_obstacle_spec.lua` e ajustes de seguimento/combate integrados ao CI.
- **Pendente in-game:** conferir abre de fato portas e janelas na B42.13.1, caminho alternativo com casa real, distância e tempo de resposta.

## 0.1.15-dev — 2026-10-31

- **Visão:** `NPCPerception.lua` detecta zumbis à frente em cone de 130° até 12 tiles e consciência próxima; usa visibilidade de `CanSee` e lista de zumbis carregados, com fallback por squares. Avisos e interceptação de alvos até ~8 tiles.
- **Armas e risco:** avaliação dos equipamentos melee/firearm/desarmado do NPC e de aliados próximos. Escore heurístico compara capacidade de combate, número de zumbis e saúde, não declara porcentagem de morte.
- **Combate:** 1–2 inimigos levam a empurrões persistentes com cooldown, recuo somente sob pressão. Horde com apoio insuficiente prioriza fuga desde a detecção, sem esperar o player morrer.
- **Movimento:** `FLEE` não cancela `ISWalkToTimedAction` ativo em cada decisão. Memória de até 16 ameaças vistas na horda evita retornar ao FOLLOW ao virar de costas antes de ganhar segurança.
- **Comunicação:** NPC responde a cada comando, dá alertas de zumbis/horda, informa falta de armas, pede ajuda ao ferir-se, avisa quando se retira e quando retoma a ordem.
- **Testes:** novos `perception_spec.lua`, `risk_combat_spec.lua` e extensões dos testes de combat tactics, speech e fuga sem visão; CI verde em Lua 5.1 com mocks.
- **Ainda não validado no PZ B42.13.1:** ângulo de FOV real, movimento/interceptação/fuga em terrenos cercados, acerto de ataques, animações e desempenho com muitos zumbis.

## 0.1.14-dev — 2026-10-31

- Novo `CombatTactics.lua`: decisão determinística baseada na quantidade de zumbis em pé/caídos, distância e apoio físico de aliado.
- `NPCDefense.lua`: observação de `isOnFloor/isProne/isGettingUp`, grupo de inimigos visíveis, knockDown probabilístico, fases SHOVE/BACKSTEP/WAIT/PIN/STOMP/FLEE/APPROACH e retomada de ordens.
- `NPCWalking.lua`: escolher tile livre e carregado na direção contrária a zumbis, sem teleporte.
- `NPCController.lua`: informação de player/equipe e execução tática antes de ordens comuns.
- Testes `combat_tactics_spec.lua`, `npc_defense_spec.lua`, `defense_controller_integration_spec.lua` revisados.
- **Avisos:** queda nativa não comprova animação de shove, posicionamento próximo não garante pinar fisicamente, `Hit` não comprova animação de stomp. Movimentação e combate requerem teste real na B42.13.1.

## 0.1.13-dev — 2026-10-31

- Adicionado `NPCDefense.lua` com varredura limitada de zumbis `IsoZombie` carregados e visíveis, prioridade máxima de autodefesa e seleção de alvo exclusivo.
- Golpe corpo a corpo pelo `IsoZombie:Hit(weapon,actor,damage,false,1.0)` da engine, com alcance real da arma, limite de dano e intervalo mínimo entre golpes. Usa `Base.BareHands` oficial se disponível e NPC não possui arma melee.
- Se houver zumbi próximo, cancela caminhada e muda somente `active` para SELF_DEFEND; a ordem `requested` permanece intacta. Ao encerrar, retorna à ordem anterior (FOLLOW/IDLE/GUARD).
- Acrescentada aproximação curta pelo `NPCWalking`; não persegue zumbi além da região imediata.
- Testes `npc_defense_spec.lua`: prioridade, cooldown, dano alvo-específico, não atingir jogadores/NPCs, filtro de visão e andar, arma desarmada e restauração da tarefa.
- **QA in-game pendente:** dano efetivo, animações, contato, navegação em interiores e estabilidade contra múltiplos zumbis.


## 0.1.12-dev — 2026-10-31

- **Correção arquitetural:** retirado o controlador manual de `PathFindBehavior2:update()`; caminhar agora é uma `ISWalkToTimedAction` na `ISTimedActionQueue` separada por ator, adaptada do `ArayHumanNPCTest/ArayHumanWalking.lua`. Sem teleporte, zumbi ou interferência deliberada na fila do jogador.
- **Ordens:** Seguir, Aguardar e Guardar ponto agora iniciam/cancelam ações nativas; Aguardar força parada e remove apenas a ação do NPC, inclusive quando existe caminho ativo.
- **Navegação:** escolhe tile próximo livre, acompanha alvo móvel, inspeciona falhas, cancela timeout e falta de progresso. Não confundir estado da UI com movimento confirmado.
- **Saúde:** fome, sede, dor e energia passam a ler `Stats:get(CharacterStat.*)` na B42; mantido fallback anterior.
- **Falas:** bolhas de texto do jogador ao dar cada ordem ou modificar postura, com frases relacionadas ao NPC e à ordem; inspiradas no `ArayHumanSpeechBubble.lua`.
- **UI:** adiciona estados operacionais MOVING / WAITING / HOLD / NEAR / FAILED / BLOCKED ao lado da ordem solicitada.
- **QA:** testes isolados novos/ajustados e checklist 0.1.12. Testes CI em mocks passam; engine B42.13.1 ainda aguarda validação de movimento.


## 0.1.11-dev — 2026-10-31

- **Navegação:** o comando seguir/guardar requisita rotas diretamente ao PathFindBehavior2 e chama update por tick; agora registra resultado, falhas e falta de progresso. Aguardar cancela a rota anterior.
- **Vestuario:** o outfit configurado no editor é aplicado primeiro no SurvivorDesc antes de IsoPlayer.new, preservando item/body location/visual; peças que faltarem são equipadas após o spawn sem duplicar.
- **UI:** retratos 3D por NPC com ISUI3DModel e avaliação médica com silhueta corporal ISNewHealthPanel do jogo (fallback se API não estiver disponível).
- **Diagnosticos:** confirmar ordens e falhas no painel de equipe; log mais claro de roupas capturadas/aplicadas.
- **Testes:** suite de pathfinding, cancelamento, falha segura e novos testes de roupas do descriptor. O CI está configurado, sem validação executada neste ambiente.
- **Pendência:** todas as mudanças exigem nova execução in-game B42.13.1; ainda não considerar movimento/vestuario/preview aprovados.


## 0.1.10-dev — 2026-10-31

- Novo `Health.lua`: leitura individual de BodyDamage e sinais reais de ferimentos, dor e necessidades; sem mutação e sem criar segundo jogador.
- Novo `NPCUI.lua`: painel lateral da equipe, barra de HP, exame médico independente e submenus Ordens/Postura.
- Novo `NPCController.lua`: seguir (requisição de pathfinding nativo experimental), aguardar e guardar posição; preferências de postura sem combate ativo.
- `Wardrobe.lua` captura/restaura nome de itens, tint, hue, baseTexture e textureChoice, quando métodos existem; validações e logs.
- `Boot.lua` integra registro de NPCs ao controlador, painel e limpeza ao voltar ao menu.
- Suites Lua novas: `health_spec.lua`, `npc_controller_spec.lua`, `wardrobe_visual_spec.lua`.
- **Atenção:** funcionalidades ainda não testadas em jogo nesta versão. Ver `docs/TEST_CHECKLIST_0.1.10.md`.


## 0.1.9-dev — 2026-10-31

### Teste real
- Capturas do PZ 42.13.1 confirmam jogador + dois personagens humanos extras no spawn.
- Ambos aparecem apenas de roupa íntima; janela adicional "Vida do Jogador" indica problema de UI ainda aberto.

### Código
- Captura de roupa escolhida no editor via `SurvivorDesc:getWornItems()`, sem armazenar referências Java.
- Novo `Wardrobe.lua` cria as peças no inventário do NPC e tenta equipá-las com `setWornItem`.
- Logs para identificar quantas peças foram vestidas e qual falhou.
- Teste `wardrobe_spec.lua` e regressão de captura em `team_flow_spec.lua`.

### Pendente
- Confirmar roupas no mundo e fidelidade das cores/texturas em save novo.
- Isolar HUD/câmera do NPC do controle do jogador.
- Seguir, combate, persistência de entidade e demais funções não validadas.


## 0.1.8-dev — 2026-10-31

### Adicionado
- Máquina de estados determinística em `Orders.lua`: estados solicitados pelo jogador, proteção, retirada, guarda e autodefesa sem redes neurais.
- Preservação da ordem solicitada durante interrupções, retomada segura e snapshot serializável.
- `Config.lua` com valores padrão, limites, sanitização e rejeição de configurações inválidas.
- `NavMonitor.lua` com detecção de falta de progresso e solicitações `REPATH`/`BLOCKED` limitadas.
- Testes puros de ordens (incluindo todas as 16 combinações de sinais), configurações e anti-stuck.
- Regra de CI que impede uso de `addZombiesInOutfit(` no código cliente.
- Documentação de arquitetura e matriz de testes da B42.13.1.

### Limitações
- Núcleos de ordens, configuração e navegação **ainda não estão ligados aos NPCs reais**.
- Integração experimental de `IsoPlayer`/renderização 0.1.7-dev não foi confirmada em jogo.
- A ausência de dependências de IA externa permanece.
- Testes GitHub Actions configurados, resultados de execução ainda sujeitos a verificação.

## 0.1.7-dev — experimental

- Integrada tentativa de spawn humano `IsoPlayer` e renderização do ArayHumanNPCTest.
- Sem validação de estabilidade/spawn/controle após a integração.

## 0.1.3-dev e 0.1.4-dev

- Tentativa de spawn com `addZombiesInOutfit` gerou zumbis reais, não NPCs.
- Abordagem descontinuada; nunca reutilizar esse adaptador.
