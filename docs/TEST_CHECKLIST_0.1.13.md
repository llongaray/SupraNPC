# SupraNPC 0.1.13-dev — teste de autodefesa B42.13.1

## O que foi implementado

- Percepção de zumbis vivos **somente** em 49 tiles ao redor do NPC, com até 280 objetos inspecionados e distância máxima de 3,2 tiles; sem carregar chunks.
- Prioridade `SELF_DEFEND` sempre acima de `FOLLOW`, `GUARD` ou `IDLE`.
- O controlador cancela a caminhada anterior no começo do combate. A ordem `requested` não é apagada; quando não houver ameaça, o NPC retoma a ordem, inclusive **Seguir o jogador**.
- Ataque corpo a corpo **exclusivo em IsoZombie** vivo e visível, no mesmo andar e próximo: `target:Hit(weapon,actor,damage,false,1.0)`. Dano limitado; intervalo de 1.050 ms entre golpes. Usa HandWeapon equipada ou arma virtual `Base.BareHands` da própria engine, se disponível.
- Aproximação curta via `NPCWalking`; proíbe perseguir alvos afastados por longas distâncias, ataques contra o jogador/outro NPC e ataques pelo interior de paredes sem visibilidade.
- Nada de IA/RN/RL, modelos externos, Python, servidores ou teleporte.

## Origem das APIs estudadas

1. [Super Survivors: AttackTask](https://github.com/nolanritchie/Super-Survivors/blob/master/media/lua/client/6_Tasks/AttackTask.lua) seleciona inimigos e usa `AttemptAttack()`, mas é um mod antigo. A nova implementação **não copia** lógica B41 desatualizada.
2. [PZNS Framework: GeneralAI](https://github.com/Project-Zomboid-Community-Modding/PZNS/blob/main/PZNS_Framework/media/lua/client/07_npc_ai/PZNS_GeneralAI.lua) identifica ameaças `IsoZombie`, verifica `CanSee` e distância do NPC.
3. [KnoxSurvivors: ZombieAwareness](https://github.com/exe-create/KnoxSurvivors/blob/main/mod/42/media/lua/client/KS_ZombieAwareness.lua) valida identificação do alvo e mantém estado de percepção da Build 42.
4. Documentação oficial: [IsoGameCharacter:Hit](https://projectzomboid.com/modding/zombie/characters/IsoGameCharacter.html) é a chamada de dano alvo-específica. Diferentemente de `AttemptAttack()`, a invocação explícita no zumbi não escolhe automaticamente outro personagem na área.

**Risco técnico:** o uso alvo-específico de `Hit` aplica dano e consequências nativas, mas pode não produzir a animação completa de swing do IsoPlayer extra. O dano ainda precisa ser medido num jogo real. Não marcar combate funcional apenas porque uma linha `DEFENSE HIT` apareceu no console.

## Roteiro de QA

1. Fechar jogo e atualizar: `git -C "$env:USERPROFILE\Zomboid\mods\SupraNPC" pull origin main`.
2. Confirmar versão `0.1.13-dev` no arquivo `42/mod.info`.
3. Ativar somente SupraNPC e criar save **novo e descartável**.
4. NPC A com Seguir; aproximar-se de **um zumbi** de modo controlado. Confirmar no console `DEFENSE ... interrompeu FOLLOW`.
5. Observar se o NPC realmente causa dano no zumbi e se este morre após golpes; verificar animação e preservação do NPC. Não assumir sucesso sem alteração observável do zumbi.
6. Após o zumbi morrer ou sair do raio, confirmar `DEFENSE ... concluida; retomando FOLLOW` e **movimentação real** em direção ao jogador.
7. Repetir com Aguardar e Guardar; após a ameaça, o NPC deve voltar a permanecer/guardar, **não** passar a seguir.
8. Dar outra ordem enquanto o combate estiver ativo: a defesa deve continuar até cessar a ameaça e então assumir a ordem nova.
9. Conferir se não causa dano ao jogador, outros NPCs nem zumbis de outro andar.
10. Testar com NPC sem arma equipada (a engine deve fornecer `Base.BareHands`). Observar se o log informa falha de arma ou `DEFENSE HIT`.
11. Testar com dois zumbis, de preferência fora de locais confinados. O NPC deve selecionar alvos válidos sem ficar preso em uma perseguição infinita.
12. Verificar falhas do motor em `%USERPROFILE%\Zomboid\console.txt`: `DEFENSE`, `NAV`, `WALK`, `ERROR`, `Exception`.

## Situação

O CI executa os testes Lua independentes do jogo. Ainda **pendente**: combate e dano real, animação, escolha de inimigos entre obstáculos, estabilidade com múltiplos zumbis, resistência e balanceamento.
