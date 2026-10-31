# SupraNPC 0.1.17-dev — testes de acompanhamento e portas/janelas na Build 42.13.1

**Status:** implementação e testes Lua automatizados concluídos; movimento, interações e animações reais do Project Zomboid 42.13.1 ainda precisam ser confirmados em jogo. Use save de teste descartável.

## Comportamentos implementados

### FOLLOW
- Distância padrão reduzida de 2,5 para **1,3 tile** (núcleo e Config).
- Usa pequenos **waypoints navegáveis** em vez de escolher apenas a casa mais próxima do jogador em linha reta.
- Se o jogador se deslocar mais de **1,25 tile** desde o alvo registrado, o NPC invalida a rota antiga e planeja novamente.
- Conserva o mesmo controle da fila `ISWalkToTimedAction` e não teleporta NPCs.

### Portas, janelas e obstáculos
- `NPCNavigation.edge()`: detecta barreiras entre tiles adjacentes com `IsoGridSquare:getDoorTo`, `getWindowTo`, `isBlockedTo`, `isWallTo`.
- Porta fechada **destrancada, não barricada e não obstruída**: quando o NPC chega ao lado, uma tentativa `ToggleDoor(npc)`; verifica `IsOpen()` / `isOpen()` após chamada. Nunca usa `setLocked(false)`, nunca quebra porta.
- Janela fechada: uma tentativa local `ToggleWindow(npc)` quando a busca já concluiu que a rota direta está bloqueada. **Janela aberta não é atravessável nesta versão**, porque subir ou escalar precisa de outro estado de animação.
- Se tentativa falhar ou continuar fechada, marca objeto como obstáculo a evitar por **14 segundos**, recalcula caminho por tiles carregados.
- Busca em grade 4 direções, raio máximo **16 tiles / 640 nós** para evitar explosão de CPU e passagem diagonal através de paredes. Não atravessa portas trancadas, janelas fechadas, paredes ou cercas intransponíveis.
- Quando não existe caminho até o zumbi, marca-o como inacessível por **14 segundos** e retorna à ordem solicitada em vez de empurrar infinitamente uma parede ou ficar travado. Se o obstáculo abrir, ele pode voltar a ser candidato antes do fim do bloqueio.
- `NPCNativeAttack` e ataques alternativos checam `Navigation.attackAccessible` antes de causar dano para não atingir zumbi através de janela/porta fechada.

## Testes em jogo (somente SupraNPC ligado)

1. **Seguir no campo aberto.** Caminhe alguns tiles, pare e depois mude de direção. NPC deve se aproximar de ~1,3 tile e corrigir o caminho sem parar atrás da rota antiga.
2. **Porta destrancada.** Player entra em casa e fecha a porta. NPC deve chegar ao lado correto, tentar abrir e prosseguir. Confirmar se a animação/abertura funcionou na Build 42; falha deve aparecer no `console.txt`.
3. **Porta trancada e sem entrada.** NPC não pode destrancar nem romper. Ele deverá registrar impossibilidade de rota, não tentar empurrar a porta como se fosse zumbi.
4. **Casa com duas portas.** Uma porta trancada, outra aberta: verificar se procura caminho alternativo.
5. **Janela fechada.** NPC pode tentar abrir uma vez, porém não deve caminhar através dela. Se não existir porta/alternativa, permanece do lado acessível.
6. **Zumbi atrás de janela/porta fechada.** Com modo agressivo, verificar que o NPC detecta a presença mas não aplica dano nem empurra através do obstáculo; se uma porta puder ser aberta, ele tenta a rota.
7. **Fuga diante de grupo com barreiras.** Verificar que o NPC não tenta fugir para o outro lado de cerca ou porta trancada.
8. **Ambiente de mapa grande.** Se alvo >16 tiles, o NPC deve usar progresso local e recalcular; se não houver carregamento de square, não deve teleportar.
9. **Regressão de FOLLOW/IDLE/GUARD e combate.** Garantir que mod não cancela ações do jogador.

## Diagnóstico

Enviar `%USERPROFILE%\Zomboid\console.txt` se observar `REPATH`, `TARGET_BLOCKED`, `OPEN_DOOR`, `door failed`, `NAV`, `WALK`, `DEFENSE`, `Exception`.

## Limitações conhecidas

- Busca em grade de curta distância, sem planejador global de mapa. Distâncias acima do limite exigem múltiplos waypoints.
- Janelas não são escaladas automaticamente; somente abertura tentativa. Portas dupla/garagem e portões especiais podem exigir tratamento separado.
- Abrir/fechar portas pelo `ToggleDoor` é uma integração experimental com a entidade `IsoPlayer` do NPC. O teste Lua usa mock; não valida todas as portas de mapas/mods.
- O sistema não deve abrir fechaduras ou contornar barricadas artificialmente.
- A movimentação com TimedAction depende de pathfinding interno do jogo; animações e colisões ainda precisam ser testadas na B42.13.1.

Referências oficiais: IsoGridSquare, IsoDoor, IsoWindow em https://projectzomboid.com/modding/.
