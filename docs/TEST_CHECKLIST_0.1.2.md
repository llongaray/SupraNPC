# SupraNPC v0.1.2-dev — Teste de regressão de telas (PZ B42.13.1)

Versão do jogo usada pelo usuário: **42.13.1**. Testar apenas com uma partida nova e descartável.

## Antes de abrir o jogo

```powershell
git -C "$env:USERPROFILE\Zomboid\mods\SupraNPC" pull origin main
```

Fechar o jogo por completo ANTES do pull. Reiniciar, ativar somente SupraNPC e criar **Nova Partida**, sem usar o save do teste anterior. O spawn experimental segue desligado: nenhum NPC físico será criado nesta etapa.

## Esperado para dois companheiros

1. Selecionar quantidade **2**.
2. Configurar **Jogador** (profissão/traits → aparência). Clicar em JOGAR.
3. Abrir **NPC 1/2 — profissão e traços**. Personalizar, clicar Próximo.
4. Abrir **NPC 1/2 — aparência**. Escolher nome, gênero, cabelo e roupas. Clicar JOGAR.
5. Abrir **NPC 2/2 — profissão e traços**, com profissão/traits independentes. Clicar Próximo.
6. Abrir **NPC 2/2 — aparência**, com nome próprio. Clicar JOGAR.
7. Somente depois: iniciar carregamento do mundo com o jogador original.
8. `console.txt` deve mostrar `Etapa PROFISSAO NPC 1/2`, `Etapa APARENCIA NPC 1/2`, `Etapa PROFISSAO NPC 2/2` e `Etapa APARENCIA NPC 2/2`.
9. Sem NPCs no mundo até validação do spawn/instância IsoPlayer; isso é esperado.

## Se o erro vermelho aparecer

O número no canto inferior direito (por exemplo, `ERROR 2`) é apenas o **contador de erros**, não contém a mensagem técnica. É preciso identificar as exceções no arquivo:

```text
C:\Users\llongaray\Zomboid\console.txt
```

Para obter um recorte útil no PowerShell:

```powershell
Get-Content "$env:USERPROFILE\Zomboid\console.txt" -Tail 2000 |
  Select-String -Pattern "SupraNPC|ERROR|Exception|stack trace" -Context 3,6 |
  Out-File "$env:USERPROFILE\Desktop\SupraNPC-erros.txt" -Encoding utf8
```

Envie `console.txt` completo (preferível) ou `SupraNPC-erros.txt`. Faça isso após um teste em jogo, antes de iniciar outra partida que possa sobrescrever mensagens.

## Mudanças desta versão

- Troca sincronizada de `MainScreen.instance.desc` e `MainScreen.instance.avatar` ao alternar jogador/NPC.
- Restituição da referência de avatar do jogador ao concluir a equipe.
- Etapas de UI explícitas `profession` e `appearance`.
- Interceptação de `NEXT` na tela de profissão e de `NEXT` na tela de aparência, mantendo comportamento vanilla fora do fluxo do mod.
- Verificação de que a profissão já foi concluída antes de aceitar o avanço pela tela de aparência.
- Rollback ao editor do NPC anterior em caso de falha na abertura do próximo.
- Ampliação de testes unitários para transições.

**Limitação:** a correção ainda não foi validada executando o jogo. As duas exceções capturadas nas imagens anteriores permanecem sem diagnóstico exato até análise do `console.txt`.
