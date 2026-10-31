# Changelog — SupraNPC

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
