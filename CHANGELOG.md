# Changelog — SupraNPC

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
