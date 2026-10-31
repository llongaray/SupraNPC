# Teste de spawn humano — SupraNPC v0.1.7-dev / PZ B42.13.1

> **Experimental.** Esta versão reutiliza a estratégia `IsoPlayer.new`, `setNPC(true)`, square/moving objects e render manual de `ArayHumanNPCTest`. Ela ainda não foi validada no jogo **dentro do SupraNPC**. Teste somente com um save descartável e apenas este mod ativo.

## Como atualizar

1. Fechar completamente o Project Zomboid.
2. Executar no PowerShell:

```powershell
git -C "$env:USERPROFILE\Zomboid\mods\SupraNPC" pull origin main
```

3. Verificar `42/mod.info`: `modversion=0.1.7-dev`.
4. Iniciar **Nova Partida** (preferível) com somente SupraNPC ativado e selecionar **1 NPC** para o primeiro teste.
5. Configurar profissão/traços/aparência do jogador; depois do NPC 1; clicar JOGAR.

## Resultado esperado

- O mundo deve carregar sem encerrar o jogo.
- Após ~90 ticks de jogo, o código tenta criar um `IsoPlayer` extra no mesmo cômodo, ou em outro tile livre a até 3 tiles do jogador.
- O personagem principal deve continuar controlável, com a câmera nele.
- O NPC deve ter `isNPC=true`, o nome/identificador da ficha e roupas básicas. Roupas e dados visuais detalhados do editor ainda não são recriados completamente.
- Se a renderização FBO estiver ativa, `Events.RenderOpaqueObjectsInWorld` deve desenhar o NPC criado fora de `IsoPlayer.players[]`.
- O NPC **não seguirá nem lutará** nesta etapa, pois o foco é render e spawn sem crash. `Follow` permanece desativado.
- **Nunca** deve aparecer um zumbi criado pelo mod: não existe chamada a `addZombiesInOutfit` nesse código.

## O que procurar no console

```text
[SupraNPC] Versao 0.1.7-dev carregada
[SupraNPC] Engine=iso_player | spawn experimental=true
[SupraNPC] OnGameStart: pending_human
[SupraNPC] HUMAN spawn supranpc_1 ...
[SupraNPC] HUMAN SPAWN: 1/1 NPCs IsoPlayer criados
[SupraNPC] Render humano ativo via RenderOpaqueObjectsInWorld
```

Se `HUMAN SPAWN` aparecer e o NPC for invisível, procurar `Render`, `getLightInfo`, `currentSquare` e ver se o FBO está ativo. Se `HUMAN SPAWN` não aparecer, procurar `Falha NPC` e `IsoPlayer`.

## Segurança/persistência

- O mod não usa rede neural, Ollama, Python ou qualquer programa externo.
- A v0.1.3 que criava zumbis foi descartada; não use aquele save.
- Saves 0.1.4–0.1.6 com roster `disabled` e sem tentativas de spawn podem ser migrados automaticamente. Para validar de forma limpa, crie um novo save.
- Marcadores `humanSpawned` evitam criação repetida ao carregar, mas **persistência de entidades IsoPlayer entre sessões ainda precisa de teste**. Se a entidade não existir após um reload, o mod **não** cria uma cópia às cegas.
- Até concluir testes de identidade, inventário, habilidades, movimentação e sobrevivência, o spawn não significa que o NPC está completo.

## Log após teste ou crash

```powershell
Copy-Item "$env:USERPROFILE\Zomboid\console.txt" "$env:USERPROFILE\Desktop\SupraNPC-0.1.7-console.txt" -Force
```

Anexe o arquivo à conversa, especialmente se não aparecer NPC ou o jogo fechar. Se houver `hs_err_pid*.log`, anexe também.

## Código de referência

- Origem: [ArayHumanNPCTest / ArayHumanTest.lua](https://github.com/llongaray/ArayHumanNPCTest/blob/main/42/media/lua/client/ArayHumanTest.lua)
- Novo adaptador: [SpawnAdapter.lua](../42/media/lua/client/SupraNPC/SpawnAdapter.lua)
- Renderização: [Renderer.lua](../42/media/lua/client/SupraNPC/Renderer.lua)
- Bootstrap: [Boot.lua](../42/media/lua/client/SupraNPC/Boot.lua)
