# Teste de regressão 0.1.12-dev — B42.13.1

Base: capturas 31/10/2026 com dois NPCs vestidos e retratos funcionais, mas sem movimento, sem interrupção real e status médicos N/D.

## Preparação
- Fechar totalmente Project Zomboid antes de atualizar.
- No PowerShell: `git -C "$env:USERPROFILE\Zomboid\mods\SupraNPC" pull origin main`
- Confirmar `0.1.12-dev` em `42/mod.info`.
- Desativar **ArayHumanNPCTest** nesta sessão se ele também estiver instalado; é referência de código e os dois mods podem disputar eventos ou UI.
- Criar save **novo, descartável**, com dois NPCs vestidos e diferentes.

## Sequência
1. Confirmar que o personagem do jogador permanece controlável e que os dois NPCs têm roupas e previews corretos. O avatar inicial não pode virar um NPC ou zumbi.
2. Usar *Seguir o jogador* no NPC A e caminhar 5–10 tiles, de preferência ao ar livre, sem obstáculos. Esperado: uma fala do jogador e o estado `FOLLOW / MOVING`; **sucesso só se NPC andar fisicamente**. O estado pode mudar para `NEAR` quando se aproximar.
3. Com o NPC A em deslocamento, selecionar *Aguardar aqui*. Esperado: outra fala, estado `IDLE / WAITING` e nenhum movimento posterior.
4. Selecionar *Guardar ponto do jogador* estando longe; verificar caminhada até o ponto. Após chegar, estado `GUARD / HOLD`.
5. Usar *Guardar esta posição*; deve parar no local e não caminhar desnecessariamente.
6. Alterar posturas; cada comando deve gerar uma fala do jogador. **Não esperar ataque automático**.
7. Em *Analisar vida / saúde* verificar valores numéricos de dor, fome, sede, energia, não apenas 100% de vida. Inspecionar ambos os NPCs; cada painel deve usar o ator certo.
8. Dar várias ordens alternadas e confirmar que não criam filas de movimento duplicadas e nem interferem no movimento do jogador.
9. Mudar entre interiores/exteriores; se houver falha, anotar se a navegação travou em portas/obstáculos.
10. Fechar e reabrir save de teste, observando duplicação de corpos e crash (persistência ainda experimental).

## Quando falhar
Copiar `%USERPROFILE%\Zomboid\console.txt` após sair do jogo; procurar mensagens:
- `[SupraNPC] WALK ... start` => ação nativa enfileirada, NÃO prova movimento.
- `[SupraNPC] WALK ... cancelado` => cancelamento por comando ou falha.
- `[SupraNPC] NAV ... falha` => problema de fila, tile, timeout ou ausência de progresso.
- `[SupraNPC] SPEECH PLAYER` => texto da fala emitido pelo dispatcher.

O adaptador usa `ISWalkToTimedAction` e cancela **somente** a ação pertencente ao NPC. Não há teleporte de substituição, manipulação da câmera nem spawn de zumbis.

## Limites
Testes automatizados usam mocks; não comprovam o comportamento nativo da engine 42.13.1. Se mover só ao ar livre e falhar em casas, é necessário trabalhar pathfinding/portas; não marcar o requisito como resolvido.
