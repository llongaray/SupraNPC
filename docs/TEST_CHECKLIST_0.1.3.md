# SupraNPC 0.1.3-dev — teste de spawn B42.13.1

**Escopo: comprovar que 2 entidades provisórias aparecem perto do jogador em uma partida NOVA.**

## Limite arquitetural

A Build 42 não oferece, de maneira comprovada neste projeto, criação de NPCs humanos completos por `IsoPlayer.new` em jogo normal. Este checkpoint experimental usa o motor `IsoZombie` com aparência de sobrevivente e scripts Lua que tentam suprimir o comportamento hostil. **Não é um NPC humano definitivo; não possui as skills, comportamento, inventário e autonomia do personagem criado.**

Apesar dos bloqueios defensivos, **não há garantia de neutralidade na B42.13.1**. Jogue em save **descartável**, isolado de qualquer partida principal. Não use em jogo cooperativo/multiplayer.

## Atualização

Feche o jogo completamente:

```powershell
git -C "$env:USERPROFILE\Zomboid\mods\SupraNPC" pull origin main
```

Verifique `42/mod.info` com `modversion=0.1.3-dev` e `Constants.lua` com `EXPERIMENTAL_SPAWN = true`.

## Teste do zero

1. Inicie novo jogo single-player com **apenas SupraNPC** habilitado.
2. Escolha **2 NPCs** no seletor.
3. Personalize jogador, NPC 1 e NPC 2, seguindo Profissão/Traços → Aparência em cada caso.
4. Aguarde o jogo terminar o carregamento e observe os **4 tiles** ao redor do jogador, inclusive áreas externas; o adaptador procura tiles livres em até 4 tiles.
5. **Esperado:** duas entidades de teste com roupa humana (mas chassi interno de zumbi) surgem perto do jogador. Elas devem permanecer paradas neste marco, sem seguir nem lutar.
6. A aparência pode diferir do editor: a aplicação de roupas/skills completas não foi implementada. Isto não configura ainda um NPC pronto.
7. Abra `%USERPROFILE%\Zomboid\console.txt` e procure:
   - `[SupraNPC] Versao 0.1.3-dev`
   - `Nova partida: 2 NPC(s). Modo de spawn=pending_proxy`
   - `PROXY spawn: supranpc_1`
   - `PROXY spawn: supranpc_2`
   - `Spawn PROXY concluido 2/2`
8. Se não nascerem, procure `Spawn proxy tentativa`, `addZombiesInOutfit`, `bloqueado` e `ERROR`.

## Falhas esperadas / como tratar

- `nenhum tile livre`: proximidades ocupadas/incompatíveis, tentativa automática limitada de 8 ciclos.
- `addZombiesInOutfit nao retornou entidade`: verificar configurações de população de zumbis e APIs da B42.13.1.
- `OnGameStart: sem roster`: a equipe não foi transferida ao save; enviar log após recriar partida.
- `Equipe no save: ... awaiting_validation`: save gerado por uma versão antiga; **não reusar** para validar este checkpoint.
- `proxy_spawned` com personagens ausentes após recarregar: persistência de entidades ainda não está validada. O mod não faz respawn automático em saves já marcados para evitar clones.

## Compartilhar logs

```powershell
Select-String -Path "$env:USERPROFILE\Zomboid\console.txt" -Pattern "SupraNPC|ERROR|Exception" -Context 3,5 |
  Out-File "$env:USERPROFILE\Desktop\SupraNPC-spawn-log.txt" -Encoding utf8
```

Envie `console.txt` completo ou o arquivo `SupraNPC-spawn-log.txt` junto da captura do mundo. Não teste em uma partida principal.

## Próximo marco

Depois de confirmar spawn de 2 corpos: validar mecanismo para entidades humanas genuínas (sem programa externo), inventário independente, aplicação completa de roupas/traços/skills, navegação/seguir e preservação da neutralidade.
