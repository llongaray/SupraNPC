# SupraNPC 0.1.18-dev — QA Build 42.13.1

Código e testes automatizados Lua 5.1 concluídos; interações nativas e desempenho exigem validação no jogo. Faça backup ou use um save descartável.

## 1. Movimento

- WALK: NPC acompanha o jogador.
- SNEAK: NPC tenta agachar quando o jogador agacha, ou quando percebe zumbis ao longe e ainda não combate.
- RUN: NPC tenta correr se fica mais de 5,5 tiles para trás, ou entra em FLEE/FLEE_BASE/RETURN_BASE.
- Ao RETREAT, a rota evita tiles que aproximem o NPC de zumbis sempre que possível. Se cercado, deve conseguir afastar-se progressivamente.
- APIs utilizadas: setSneaking(bool), setRunning(bool), setSprinting(false). Confirmar animação e velocidade reais na B42.

## 2. Portas e janelas

- Porta destrancada: abertura por ToggleDoor e continuação do percurso (0.1.17).
- Janela fechada, destrancada e não barricada: tentativa ToggleWindow, sem quebrar.
- Janela aberta, sem vidro perigoso, destino livre, sem zumbis a 3 tiles: consultar canClimbThrough(npc) e executar climbThroughWindow(window).
- Durante a escalada, nenhuma outra ação de ataque ou pathfinding inicia até trocar de tile ou passar 4,5 segundos.
- Janela trancada, barricada, vidro perigoso, local ocupado ou zumbis próximos: não atravessar; procurar alternativa.
- Não teleporta, não força trancas e não executa salto de andares.

## 3. BASE com lápis/caneta no mapa

1. Pegue lápis ou caneta e abra mapa com M.
2. Na ferramenta de anotações de TEXTO, escreva NPC:BASE:A num canto da casa.
3. Escreva NPC:BASE:B no canto oposto da mesma casa/estrutura.
4. O mod interpreta os cantos como retângulo da base (incluindo os tiles dentro). É uma área designada pelo jogador, NÃO uma verificação de que a casa está cercada ou sem zumbis.
5. Se quiser somente um ponto inicial de referência, escreva NPC:BASE (raio inicial de 3 tiles, área 7x7).
6. Verifique no painel SupraNPC: Mapa: BASE RECT / BASE POINT e quantidade de marcações.
7. O NPC escolhe a base como alvo preferencial de fuga; se rota sem barreiras/zumbis não existir, ele usa fuga local. Pode receber menu Retornar para base ou frase "Yong, volta para base".
8. Salve/recarregue o jogo e confirme persistência; console.txt deve ter MAP_KNOWLEDGE sync.

## 4. POIs e missões futuras

Anotações textuais que os NPCs interpretam:
- NPC:LOOT Mercado — área para saque futuro
- NPC:CLEAR Escola — área para limpar zumbis futuramente
- NPC:DANGER Rua — área perigosa
- NPC:RALLY Praça — ponto de encontro
- NPC:SUPPLY Posto — suprimentos
- NPC:HOSPITAL Farmácia — atenção médica

Outras anotações livres são NOTE. Ícones de mapas são importados como SYMBOL ou categorizados quando ID é reconhecido. O conhecimento de notas e coordenadas é compartilhado pela equipe. **O mod ainda não executa missões de loot/limpeza por esses pontos**; isso será fase posterior. A região é um retângulo lógico, sem sobreposição gráfica adicional no mapa.

O adaptador usa UIWorldMap:getSymbolsAPI (getWorldX/getWorldY) quando disponível, e fallback via MapItem. Se a B42 esconder coordenadas, mantém o último conhecimento salvo, mas a atualização automática pode exigir abrir o mapa.

## 5. Regressões

Testar FOLLOW, IDLE, GUARD, combate e saúde; fuga com 2 NPCs versus 3 zumbis; não atravessar janelas barricadas; não causar ações ao jogador principal; desempenho com vários NPCs. Logs: %USERPROFILE%/Zomboid/console.txt — MOVEMENT, MAP_KNOWLEDGE, FLEE_BASE, CLIMB_WINDOW, WALK, DEFENSE e Exception.
