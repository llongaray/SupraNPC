# Changelog — SupraNPC

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
