# OBSOLETO — não executar o teste de spawn da v0.1.3

**ATENÇÃO:** o teste em jogo de 31/10/2026 confirmou que o antigo `addZombiesInOutfit` criava zumbis reais. A tentativa de neutralização NÃO gerou NPCs humanos.

Todas as instruções desta versão para ativar `EXPERIMENTAL_SPAWN` e criar entidades são canceladas.

## O que fazer

- Atualize para o **SupraNPC v0.1.4-dev**.
- Feche o Project Zomboid, execute `git -C "$env:USERPROFILE\Zomboid\mods\SupraNPC" pull origin main`.
- Abandone o save descartável usado para gerar os dois zumbis. O mod não realiza remoção automática desses zumbis antigos.
- O editor sequencial de jogadores/NPCs continua disponível, mas o spawn humano permanece **não implementado**.
- Para detalhes: [README](../README.md).

**Critério para reintroduzir spawn:** implementação com semântica comprovada de NPC aliado/controlável na B42.13.1; não basta um zumbi com roupa humana nem um construtor experimental sem validação.
