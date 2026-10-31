# SupraNPC — arquitetura inicial (Build 42.13.1)

## Requisito de instalação

Clone o repositório diretamente em `%USERPROFILE%\Zomboid\mods\SupraNPC`.
A raiz contém `42/mod.info`, `42/media/lua/` e `common/`. Não existe
subpasta `Contents/mods` para instalação manual.

## Módulos

- `shared/SupraNPC/Constants.lua`: configuração de desenvolvimento, logs, limites.
- `shared/SupraNPC/Roster.lua`: fichas independentes dos NPCs, serializáveis.
- `shared/SupraNPC/Orders.lua`: máquina de estados e precedência de defesa.
- `client/SupraNPC/TeamSetup.lua`: seletor de quantidade integrado à tela de profissões.
- `client/SupraNPC/Boot.lua`: eventos de nova partida, persistência e inicialização.
- `client/SupraNPC/SpawnAdapter.lua`: protótipo de instância NPC sob opt-in explícito.
- `client/SupraNPC/Follow.lua`: controlador inicial de seguimento desacelerado por ticks.

Não há dependências de Python, rede, serviços, Ollama, RN ou RL.
Apenas single-player faz parte do escopo atual.

## Estado implementado versus pendente

**Implementado no código, ainda não validado dentro do jogo:**
1. Manifesto e organização nativa B42.
2. Seletor de quantidade de NPCs antes da edição vanilla do player.
3. Fichas serializáveis individuais com defaults separados.
4. Eventos OnNewGame/OnGameStart e registro no modData do player.
5. Máquina determinística de ordens com interrupção por autodefesa.
6. Protótipo experimental de spawn/seguir desativado por padrão.

**Pendente:** repetir a interface vanilla de aparência/profissão/traits por NPC,
instanciar IsoPlayer como NPC de forma verificada em 42.13.1, movimento/combate real,
persistência de entidades, restauração de NPCs no load, testes in-game.
As funções de base, loot, crafting, cura, alimentação e missões seguem no Trello.

## Segurança de save

Por padrão, `EXPERIMENTAL_SPAWN = false`. Isso permite verificar reconhecimento
do mod e interface, sem adicionar objetos potencialmente incompatíveis ao mundo.
Altere para `true` em `42/media/lua/shared/SupraNPC/Constants.lua` SOMENTE
em **save descartável**. Nunca use o teste com save principal.
Com spawn ativo, o protótipo marca a tentativa para evitar duplicação;
**não existe ainda suporte comprovado para restauração de NPCs depois do load**.

## Critérios de compatibilidade

Validar em uma instalação **exatamente 42.13.1**:
1. Arquivo `console.txt` e registro do manifesto na lista de mods.
2. Tela de profissão, seletor, quantidade 0/1/3/5 e retorno à seleção.
3. `OnNewGame` preservando escolha no `getModData()` do player.
4. Teste de instância NPC e caminho em save descartável.
5. Salvar/sair/carregar sem repetição ou corrupção.
6. Corrigir APIs diferentes das referências de 42.20/42.21.

Referências externas são guias e não substituem validação de runtime.
