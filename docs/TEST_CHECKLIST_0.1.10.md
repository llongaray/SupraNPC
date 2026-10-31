# SupraNPC 0.1.10-dev — Teste de roupas, saude e comandos (B42.13.1)

**Codigo publicado; novos recursos ainda nao validados dentro do jogo.** Teste somente save novo e descartavel.

## Preparacao

Feche o jogo, execute PowerShell:
```powershell
cd "$env:USERPROFILE\Zomboid\mods\SupraNPC"
git pull origin main
```
Confirme `42/mod.info` = `0.1.10-dev`. Ative apenas SupraNPC. Crie 2 NPCs com roupas nitidamente diferentes.

## Vestuario

- [ ] Cada NPC usa as roupas escolhidas, inclusive varias camadas e calcados.
- [ ] Cores/tint, tonalidade e variacoes de textura coincidem quando API suporta.
- [ ] Nenhum item do NPC aparece ou desaparece do inventario do jogador.
- [ ] Log registra `roupas registradas: N`, `vestidos=M/N falhas=K`.
- [ ] Se M=0 ou K>0, copiar mensagem `motivo=` do log.

## Avaliar saude

- [ ] Painel lateral `SUPRANPC - EQUIPE` lista os 2 NPCs com barras de vida.
- [ ] Clicar no nome abre a avaliacao medica especifica do NPC.
- [ ] Saude geral, dor, sede, fome, energia e ferimentos usam valores reais ou `N/D`.
- [ ] Ferimentos, sangramentos, bandagens e fraturas aparecem se API retornar sinais.
- [ ] Fechar a tela medica nao afeta a vida/interface do jogador.
- [ ] NPCs diferentes mostram nomes e dados separados.

A janela vanilla extra `Vida do Jogador` vista no teste anterior ainda nao foi removida: origem de ownership do IsoPlayer precisa ser estudada.

## Submenus basicos

No painel lateral, botao `>` ao lado do NPC:

- [ ] Abrir `Ordens`: Seguir o jogador, Aguardar aqui, Guardar esta posicao, Guardar ponto do jogador.
- [ ] Abrir `Postura`: Passiva, Defensiva, Agressiva.
- [ ] Ordem escolhida aparece na faixa inferior do NPC e no log.
- [ ] Seguir solicita caminho ao IsoPlayer extra; movimento real **ainda nao validado**.
- [ ] Aguardar nao emite novas rotas; pode haver rota ja enfileirada no motor.
- [ ] Guardar registra destino e solicita retorno, sem combate implementado.
- [ ] Postura apenas registra preferencias; nao ha combate automatico ainda.

## Regressao

- [ ] Câmera e teclado continuam controlando o jogador original.
- [ ] Sem NPCs duplicados apos carregar save.
- [ ] Voltando ao menu, painel SupraNPC desaparece.
- [ ] Sem erros vermelhos ou crash do jogo.

## Logs para depuracao

```powershell
Select-String -Path "$env:USERPROFILE\Zomboid\console.txt" -Pattern "SupraNPC|ERROR|Exception" -Context 3,5 | Out-File "$env:USERPROFILE\Desktop\SupraNPC-0.1.10-log.txt" -Encoding utf8
```

Envie `console.txt` completo, se possivel. Nenhum programa externo de IA ou servidor e necessario.
