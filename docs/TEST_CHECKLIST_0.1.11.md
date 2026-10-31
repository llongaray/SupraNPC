# SupraNPC 0.1.11-dev — regressao apos capturas reais B42.13.1

Problemas observados pelo usuario no 0.1.10: ordens nao movimentavam NPCs; painel de saude nao seguia a interface vanilla; NPCs sem retrato; NPCs sem vestuario configurado.

## Correcao do ciclo de ordens

Antes: `NPCController` so chamava `pathToCharacter()`/ `pathToLocation()` a cada 45 ticks. O `IsoPlayer` criado fora da lista de players pode nao executar automaticamente o comportamento de IA.

Agora: o controlador tenta obter `getPathFindBehavior2()`, requisita rota por `PathFindBehavior2:pathToCharacter` ou `:pathToLocation`, e chama `:update()` a cada tick enquanto o pedido esta ativo. Detecta resultado Failed/Cancelled e nenhum progresso, limita repeticoes e registra `[SupraNPC] NAV ...`. Aguardar cancela a rota anterior com `:cancel()`. **Isso ainda precisa de teste no jogo.** Se a engine nao mover o ator, a funcao falha fechada e desativa as tentativas; NAO teletransporta, atravessa paredes ou altera os controles do player.

## Roupa escolhida no editor

- `Wardrobe.capture` guarda fullType, body location e propriedades visuais serializaveis.
- `Wardrobe.dressDescriptor` aplica roupas no SurvivorDesc ANTES de IsoPlayer.new, como o editor vanilla.
- Depois do spawn, `Wardrobe.missing` calcula apenas o que faltou vestir, evitando duplicacao.
- Logs mostram: roupas registradas, vestidas no descriptor, faltantes, falhas de item/slot. Se o editor gravou zero itens, o problema aparece no console, nao e mascarado.

## Preview e painel de saude vanilla

- `NPCUI` usa `ISUI3DModel:setCharacter` para retrato 3D individual, se a engine permitir.
- `Details` instancia o `ISNewHealthPanel` (mesmo componente corporal do jogador), quando disponivel, com corpo/sinais reais obtidos de `BodyDamage`.
- Mantem diagnostico de HP e lesoes, sem executar curas nem modificar dados.
- Se API 3D/Java falhar, registra no console e continua com fallback, sem tratar o NPC como jogador adicional.

## Teste obrigatorio em save NOVO descartavel

1. Fechar o jogo, executar `git -C "$env:USERPROFILE\Zomboid\mods\SupraNPC" pull origin main`.
2. Confirmar `0.1.11-dev` em `42/mod.info` e somente SupraNPC habilitado.
3. Criar 2 NPCs com vestuario diferente do default.
4. Observar se ambos aparecem vestidos. Console: `roupas registradas`, `roupas no descriptor`, `pecas desejadas`, `faltando`, `vestidos`.
5. Verificar retrato 3D na barra lateral para cada NPC.
6. Abrir ficha medica: validar o contorno corporal do jogo, HP e ferimentos individuais.
7. Sair da casa com o jogador; escolher `Seguir o jogador`; esperar e observar se eles deslocam pelo caminho. O estado textual FOLLOW sozinho **nao** e sucesso.
8. Escolher `Aguardar aqui` durante deslocamento e verificar parada. `Guardar ponto do jogador` deve solicitar rota para o local selecionado.
9. Caso fiquem parados, enviar `console.txt` com as mensagens `NAV NPC` e `NAV requisitada`, evitando adicionar movimento artificial sem diagnostico.
10. Testar reabrir o menu e reiniciar save sem duplicar NPCs ou UIs.

**Pendente:** estabilidade do pathfinding nativo para IsoPlayer extra, roupas fielmente reproduzidas no mundo, preview sem travamentos e persistencia das entidades.
