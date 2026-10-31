# SupraNPC 0.1.6-dev — diagnóstico de crash baseado no log real

## Evidências do usuário (31/10/2026)

Arquivo recebido: `SupraNPC-crash.txt` (1.546 linhas).
O último ciclo registrado carregou **v0.1.4-dev**, não a atualização 0.1.5. A sequência foi:
- Seleção de **1 NPC**;
- Profissão/traços do NPC 1/1;
- Aparência do NPC 1/1;
- `[SupraNPC] Finalizando APARENCIA NPC 1/1`;
- `[SupraNPC] Ficha NPC 1 finalizada: Derick Byrd / lumberjack`;
- Fim abrupto do arquivo, sem `Nova partida` nem confirmação de carregamento.

A ausência de stack trace FINAL significa que o `console.txt` sozinho NÃO comprova causa nativa/JVM, mas restringe o erro para depois de `captureNPC()` e antes de completar `finishNPCs()`. A região inclui validação, restauração do descritor, manipulação das telas e chamada do jogo. Um log anterior do mesmo arquivo (v0.1.1) mostra exceções Lua em `resetProfession`/`disableBtn`, mas não são o mesmo crash final.

## Causa provável / alteração preventiva

Na 0.1.4, `restorePlayer()` acionava `setAvatarFromUI()` e `restoreProfession()` (que chama `resetBuild()` e `onSelectProf()`) exatamente durante a transição para `LoadingQueueState`. Isso força operações de UI e objeto Java quando o jogador deveria apenas ser restaurado.

No 0.1.5, foi retirada a sobrescrita temporária de `initPlayer()`; o teste recebido ainda não exercitava essa correção.

No **0.1.6**, a restauração passou a:
1. Recuperar referências originais `MainScreen.desc` e `MainScreen.avatar`;
2. Repor `listboxTraitSelected.items` por um snapshot das linhas originais escolhido pelo jogador;
3. Recuperar seleção da profissão e nome/voz sem chamar reconstrução do avatar ou `onSelectProf`;
4. Preservar a execução de `CharacterCreationMain:initPlayer()` do jogo;
5. Registrar marcadores `FINISH-1`, `FINISH-2`, `RESTORE-1/2/3` e `PRE-LOAD` para identificar o último estágio executado.

**Não significa que o crash foi corrigido**. Sem log JVM fatal (`hs_err_pid*.log`) e novo teste em B42.13.1, a causa não é conclusiva.

## Próximo teste controlado

1. Preserve o log antigo.
2. Feche o jogo, execute `git -C "$env:USERPROFILE\Zomboid\mods\SupraNPC" pull origin main`.
3. Verifique `0.1.6-dev` em `42/mod.info`.
4. Inicie partida NOVA descartável com SupraNPC e apenas 1 NPC.
5. Se o jogo fechar novamente, não o reabra antes de copiar `%USERPROFILE%\Zomboid\console.txt`. Envie o log e, se houver, o relatório `hs_err_pid*.log`.
6. Busque os marcadores do fluxo. A ausência de `RESTORE-1` após `FINISH-2` indica que a falha antecede a restauração; último marcador `RESTORE-2` restringe a outra etapa.

**Spawn de zumbis (v0.1.3) permanece absolutamente bloqueado. Nenhum NPC real será criado ainda.**
