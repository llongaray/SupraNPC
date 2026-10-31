# SupraNPC 0.1.5-dev — crash ao clicar JOGAR após criar 1 NPC

**Incidente reportado em 31/10/2026 na B42.13.1:** jogo encerra abruptamente após finalizar o personagem principal e 1 NPC, ao clicar JOGAR na última tela.

## Diagnóstico ainda NÃO concluído

Sem os logs completos, não é possível afirmar se o crash veio do callback Lua, de uma exceção Java ou de uma falha nativa/driver.

O código anterior substituía temporariamente `CharacterCreationMain.initPlayer` por uma função vazia, antes de chamar o botão original de loading. **Isto foi removido na 0.1.5-dev.** Essa mudança corrige uma interferência indevida na rotina vanilla de nome/voz, mas **não prova que o crash esteja resolvido**.

A versão inclui verificações para:
- Descritor do jogador idêntico ao original;
- Avatar do jogador restaurado;
- Método `initPlayer` presente e não sobrescrito;
- Logs `PRE-LOAD`, `LOADING` ou `ABORTANDO` antes da transição;
- Testes unitários do callback padrão (sem executável do jogo).

O spawn de NPCs reais segue não implementado e `EXPERIMENTAL_SPAWN=false`. Não ativar o mecanismo antigo de zumbis.

## Coleta imediata após o crash

**Antes de reabrir o jogo**, copie `%USERPROFILE%\Zomboid\console.txt` para outro local e anexe na conversa. Se existir, anexe também `%USERPROFILE%\Zomboid\logs.zip`.

PowerShell:

```powershell
$source = Join-Path $env:USERPROFILE "Zomboid\console.txt"
$dest = Join-Path $env:USERPROFILE "Desktop\SupraNPC-crash-console.txt"
if (Test-Path $source) { Copy-Item $source $dest -Force }
```

Se houve crash nativo da JVM, procure também por `hs_err_pid*.log` na pasta do jogo (e/ou no diretório em que ele foi iniciado); arquivo pode não existir em todos os crashes.

Indicações úteis no log:
- `[SupraNPC] Finalizando APARENCIA NPC 1/1`
- `[SupraNPC] PRE-LOAD...`
- `[SupraNPC] LOADING...`
- `ERROR`, `Exception`, `Stack trace` e `hs_err_pid`

## Recuperação segura

1. Não reutilizar save descartável usado na v0.1.3 para geração de zumbis.
2. Para jogar sem entrar no fluxo adicional de NPCs, selecionar **0 NPCs** no seletor, ou desativar SupraNPC no menu de mods.
3. Evitar novas tentativas com NPC até coletar o log, para não sobrescrever evidências.
4. Quando houver nova tentativa controlada, atualizar para 0.1.5-dev e criar um novo save descartável.

Atualização:
```powershell
git -C "$env:USERPROFILE\Zomboid\mods\SupraNPC" pull origin main
```

Este documento não declara o crash corrigido; a confirmação depende de teste real na Build 42.13.1 e análise dos registros.
