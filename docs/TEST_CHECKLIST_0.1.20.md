# SupraNPC 0.1.20-dev — validação das três posturas B42.13.1

Escopo: prioridades efetivas PASSIVE, DEFENSIVE e AGGRESSIVE no `StancePolicy.lua`, integradas ao `NPCDefense.lua` e `CombatTactics.lua`. Testes Lua 5.1 aprovados; engine ainda precisa ser verificada em gameplay.

## PASSIVE (não combate)
1. Com o NPC em PASSIVE, aproxime-se de 1 zumbi em campo aberto. Quando visível a até ~9 tiles, deve executar FLEE ou FLEE_BASE.
2. Aproxime o zumbi até 1 tile. NPC **não deve** dar shove, golpe ou pisão; deve tentar fugir.
3. Mesmo com arma corpo a corpo equipada, permanece sem atacar.
4. Ao perder contato visual, conserva a memória por no máximo 4,5 s; depois retoma a ordem do player se não houver nova ameaça.

## DEFENSIVE (combate primeiro)
1. Com 1 ou 2 zumbis, deve executar SELF_DEFEND (SHOVE, SWING, PIN, STOMP conforme distância e condição), mesmo desarmado.
2. Com 3 zumbis contra um grupo sem armas/suporte, pode entrar em RETREAT e fugir para base ou recuar localmente.
3. Com 3 zumbis e equipe armada forte, deve manter SELF_DEFEND, não fugir por padrão.
4. Com saúde crítica e ameaça próxima, pode escolher RETREAT.

## AGGRESSIVE (prioridade matar)
1. Zumbi visível a 7–12 tiles: deve interromper FOLLOW/GUARD e realizar APPROACH.
2. Com 3+ zumbis, mesmo desarmado, o NPC permanece em SELF_DEFEND, não FLEE automaticamente.
3. Quando zumbi cai, tenta PIN/STOMP ou golpe para baixo.
4. Zumbi caído distante também é considerado alvo.
5. Se mudar a postura PASSIVE -> AGGRESSIVE durante fuga, o estado anterior é cancelado, a ordem solicitada é preservada e a defesa deve iniciar nova estratégia.

## Limites de segurança e compatibilidade
- AGGRESSIVE **não é invulnerável** e pode morrer tentando combater hordas. Não habilita disparos automáticos de armas de fogo; combate atual é majoritariamente corpo a corpo e experimental.
- NÃO ataca através de portas/janelas/paredes; não seleciona aliados como alvo.
- Sem mods de IA externos; usa o motor da B42 e heurísticas Lua.
- O CI Lua não certifica dano, animações, travessia nem sobrevivência. Registrar logs `STANCE`, `DEFENSE`, `TACTIC`, `WALK`, `NATIVE_ATTACK` em `%USERPROFILE%\Zomboid\console.txt`.

## PowerShell
```powershell
cd "$env:USERPROFILE\Zomboid\mods\SupraNPC"
git pull origin main
Get-Content ".\42\mod.info" | Select-String "modversion"
```
Esperado: `0.1.20-dev`.
