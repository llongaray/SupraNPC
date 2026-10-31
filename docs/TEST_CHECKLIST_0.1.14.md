# SupraNPC v0.1.14-dev — Combate tatico de empurrao, recuo e zumbis caidos (B42.13.1)

## Regras executadas em ordem de prioridade

1. **Um ou dois zumbis em pe:** o NPC aproxima-se com limites de distancia, tenta EMPURRAR, observa o estado real do zumbi (`isOnFloor`, `isProne`, `isGettingUp`) e, se nao cair, recua e reavalia. A API `knockDown(false)` e usada apenas apos uma tentativa valida de empurrao com sorte/forca, nao e uma ordem que declara queda bem sucedida.
2. **Caido e nenhum de pe ao redor:** o NPC aproxima-se ate alcance curto (`PIN`) e aplica ataques de finalizacao (`STOMP`) somente enquanto o zumbi permanecer caido e visivel. Posiçao de pino depende da caminhada real e da colisao nativa; ainda NAO garante impedir que ele levante. A animação visual de stomp precisa ser testada na B42.
3. **Nao caiu:** BACKSTEP -> WAIT -> aproximar/empurrar novamente. Nunca presume queda.
4. **Tres ou mais, NPC sozinho:** abre espaco com um empurrao quando ao alcance e foge para um tile livre, sem insistir em finalizar inimigos caidos. Continua a retirada ate sair da area de perigo.
5. **Tres ou mais, com player ou outro NPC vivo a no maximo 4 tiles:** alterna SHOVE / BACKSTEP / WAIT, reavaliando os zumbis em pe; nao finaliza caidos ate todos os zumbis observados da zona estarem no chao. A ajuda de um aliado deve estar fisicamente presente; nao e suficiente estar cadastrado na equipe.

**Autodefesa mantem prioridade sobre FOLLOW, GUARD e IDLE.** A ordem solicitada continua preservada em `Orders` e e restaurada quando a percepcao nao identificar ameacas.

## Integracao

- `shared/SupraNPC/CombatTactics.lua`: planner puro, sem dano nem Java.
- `client/SupraNPC/NPCDefense.lua`: observa zumbis vivos em tiles carregados, distingue em pe/caido e valida visibilidade, mesmo andar, alcance e numero de inimigos. Faz a transicao entre as fases. Dano explicitamente direcionado a IsoZombie com `Hit` para impedir ataques a aliados pela selecao automatica da engine.
- `client/SupraNPC/NPCWalking.lua`: `pickRetreat` seleciona tile carregado livre na direcao oposta ao perigo, sem teleporte.
- `client/SupraNPC/NPCController.lua`: passa player e equipe ao modulo de defesa antes de processar ordens normais.
- Status da UI: `SHOVE`, `PIN`, `STOMP`, `BACKSTEP`, `FLEE`, `APPROACH`, `WAIT`.

## Limites tecnicos

- **Nao existe API especifica de shove/stomp visual ja validada no SupraNPC B42.13.1**. `IsoZombie:knockDown(false)` requisita uma queda no motor, com chance limitada e verificacao posterior. Isto nao comprova a animacao natural de empurrao do NPC.
- `PIN` leva o NPC a um tile adjacente seguro para atacar de perto. **Nao existe ainda imobilizacao garantida do zumbi por sobreposicao/colisao do corpo do NPC**.
- `STOMP` usa a chamada de dano ja empregada pelo mod, sem animacao vanilla de pisotear validada. Se o zumbi levantar, o planner abandona a finalizacao e volta a empurrar.
- Zumbis que nao estejam visiveis nao sao contabilizados como grupo; nao existe visao por paredes, inteligencia externa, RL ou modelos a instalar.
- O deslocamento com `ISWalkToTimedAction` nao foi validado fisicamente em todos os escenarios, especialmente interiores e entradas estreitas.
- Favor testar somente em **save descartavel**, sem outros mods de NPC.

## Teste pratico — salvar logs

1. Crie novo save com dois NPCs e desative ArayHumanNPCTest, se estiver ativo.
2. Escolha FOLLOW para o NPC A e aproxime-o de um zumbi. Observe `SHOVE`, se ele cair de fato e, apos a queda, `PIN` e `STOMP`.
3. Verifique se o zumbi recebe dano real e se ele pode levantar novamente. Nao confundir `knockDown invoked` com queda confirmada.
4. Teste um zumbi que nao caia: BACKSTEP e nova tentativa.
5. Com tres zumbis em pe e NPC A sem apoio no raio, observe se ele recua/foge, sem iniciar golpes no chao.
6. Repita com jogador ou NPC B a menos de 4 tiles: SHOVE/BACKSTEP/WAIT ate nao haver zumbis em pe na zona. Depois PIN/STOMP.
7. Durante o combate, altere ordem para GUARD ou IDLE; apos a ameaca, esta nova ordem deve assumir.
8. Confirme que o player e outros NPCs nao recebem dano da selecao de alvo.
9. Se falhar ou crashar, envie `%USERPROFILE%\\Zomboid\\console.txt` com `TACTIC`, `DEFENSE`, `WALK`, `ERROR`.

## Fontes consultadas

- API Project Zomboid Build 42: `IsoZombie:knockDown(boolean)`, `isOnFloor()`, `isProne()` e `isGettingUp()`.
- Projetos NPC GitHub: `nolanritchie/Super-Survivors`, `exe-create/KnoxSurvivors`, `Project-Zomboid-Community-Modding/PZNS` e `llongaray/ArayHumanNPCTest`.
