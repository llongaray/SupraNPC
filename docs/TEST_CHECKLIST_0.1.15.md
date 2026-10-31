# SupraNPC v0.1.15-dev — Teste em jogo na B42.13.1

Estado: implementação em Lua publicada; testes automatizados cobrem a lógica, mas NÃO comprovam movimento físico, acerto de golpes, desempenho nem animações da engine.

## Alterações

- Visão em funil de **130° / 12 tiles**, com detecção de curta distância ao redor, sujeita ao `CanSee()` nativo e obstáculos. Prioriza `getZombieList()` carregada e possui fallback em tiles. Alerta zumbis vistos ao longe; intercepta até ~8 tiles e detecta horda para fugir antes de contato.
- Equipamento do NPC, player e aliados: desarmado, corpo a corpo, arma de fogo ou arma indisponível/sem munição. O poder de grupo é um **escore heurístico**, e não uma probabilidade real de morte; armas de fogo não contam como combatentes corpo a corpo habilitados, pois disparo autônomo ainda não existe.
- Contra 1–2 zumbis em pé, tenta empurrar continuamente no alcance (com cooldown), em vez de fugir após um único empurrão. Se muitos empurrões falharem e a distância ficar crítica, recua.
- Se houver 3+ zumbis e o grupo tiver capacidade insuficiente (incluindo dois desarmados), começa a fuga antecipadamente, mesmo com o jogador ainda vivo. Não cancela repetidamente a mesma caminhada FLEE: conserva `ISWalkToTimedAction` enquanto ativa.
- Com apoio e armas corpo a corpo adequadas, mantém controle por empurrão/recuo; finalização de zumbis caídos só quando não houver inimigos em pé no raio próximo.
- Balões de fala: jogador emite ordens; NPC responde; NPC avisa sobre zumbis, horda, falta de armas, necessidade de ajuda, fuga e retomada. Debounce/cooldown para evitar spam.

## Testes sugeridos

1. Crie **save novo e descartável** com 1 NPC. Atualize antes de abrir jogo: `git -C "$env:USERPROFILE\Zomboid\mods\SupraNPC" pull origin main`. Confirme 0.1.15-dev em `42/mod.info`.
2. No campo aberto, observe um zumbi a 8–12 tiles **à frente** do NPC. Ele deve anunciar presença sem atravessar paredes ou precisar receber dano primeiro. Um alvo nas costas distante deve normalmente não entrar no cone.
3. Entre na zona de aproximação (até ~8 tiles): NPC deve iniciar interceptação; dentro do alcance deve tentar empurrar **repetidamente**, até cair ou ter necessidade de recuar.
4. Ao derrubar, confirme que o motor mostra `isOnFloor` e que o NPC só finaliza se não houver outros de pé na região próxima. Verifique animações: a implementação atual pode não reproduzir o swing/stomp vanilla.
5. Coloque três zumbis visíveis a ~8 tiles com NPC e jogador desarmados próximos. Esperado: NPC alerta `Sem armas, melhor fugir!` ou equivalente e **começa** a fugir imediatamente, antes de o jogador morrer. Testar se não fica `FLEE` parado por colisão/caminho.
6. Repita com NPC e player **ambos usando armas melee**. Esperado: controlar o grupo por empurrão/recuo e não priorizar fuga automática enquanto a força avaliada for suficiente.
7. NPC sozinho diante de três ou mais: deve fugir, com ou sem arma. Com 1 ou 2 zumbis, lutar conforme distância/equipamento.
8. Dar `Seguir`, `Aguardar`, `Guardar` e `Postura`: NPC deve responder em balão. Com ameaça, ordens permanecem registradas e voltam a ser executadas ao sumir o perigo.
9. Derrube um NPC e confira a própria vida/ferimentos. O mod não pode dar dano ao player ou outro NPC como alvo de `Hit()`.
10. Teste em interiores e saídas cercadas; caso `FLEE` fique parado, enviar `console.txt`, pois a navegabilidade depende da engine/colisões e precisa de correção separada.

## Logs úteis

- `PERCEPTION`, `TACTIC ... near= visible= weapon= allies= risk=`
- `DEFENSE`, `WALK`, `SPEECH`, `ERROR` e `Exception`

A leitura de ameaça não é onisciência: zumbis atrás de obstáculos ou fora do funil/raio podem não ser percebidos. Visão/identificação usa métodos documentados `getForwardDirectionX/Y`, `CanSee`, `HandWeapon:isRanged`/ `isAimedFirearm`.

**Limitações mantidas:** combate com armas de fogo não implementado; predição de probabilidade real de morte não existe; animações de empurrão/pisoteio e bloqueio de levantamento por colisão ainda requerem adaptação/validação.
