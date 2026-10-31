# Teste 0.1.1-dev — criação de NPCs (Build 42.13.1)

> **Não é teste de spawn.** O spawn de entidades continua desligado e não deve ser habilitado em saves importantes.

## Preparação

1. Feche completamente o Project Zomboid.
2. Execute no PowerShell:
   ```powershell
   git -C "$env:USERPROFILE\Zomboid\mods\SupraNPC" pull origin main
   ```
3. Inicie o jogo, confirme **SupraNPC 0.1.1-dev** no menu de mods e deixe outros mods de NPC desativados.
4. Crie uma **partida descartável** (novo save). Escolha 2 NPCs.

## Fluxo esperado

- [ ] Seletor mostra **2** após clicar em + duas vezes.
- [ ] Criar jogador normalmente, selecionar profissão/traços e aparência/nome.
- [ ] Clicar em **Próximo** após o jogador abre **profissão NPC 1/2**, não o carregamento.
- [ ] No NPC 1, profissão e traços começam independentes; nome inicial **NPC 1**, alterável.
- [ ] Finalizar aparência do NPC 1 abre profissão do **NPC 2/2**.
- [ ] NPC 2 inicia com nome **NPC 2**, sem herdar o nome do NPC 1; profissão/traços configuráveis.
- [ ] Finalizar o NPC 2 inicia o carregamento do mundo **uma única vez**.
- [ ] O personagem principal mantém nome, profissão e traços originalmente escolhidos.
- [ ] `console.txt` registra fichas 1 e 2 e `OnNewGame: ...` / `OnGameStart: ...` conforme callbacks.
- [ ] Nenhum NPC aparece fisicamente no jogo ainda (spawn experimental desligado por padrão).

## Casos de regressão

- [ ] Escolher 0 NPCs: criação vanilla e início de jogo sem abrir outros editores.
- [ ] Escolher 1 NPC: uma única etapa adicional antes de iniciar.
- [ ] Clicar Voltar na profissão de um NPC: retorna à aparência do jogador (cancela as fichas parciais).
- [ ] Sair e iniciar outra nova partida: seletor reaparece com contagem reiniciada.
- [ ] Criar 2 NPCs com nomes diferentes; verificar no log nomes e profissões distintos.
- [ ] Voltar ao menu, carregar save existente: NPCs não são gerados novamente.

## Diagnóstico

Arquivo: `%USERPROFILE%\Zomboid\console.txt`

Buscar os trechos `[SupraNPC]` e linhas de `ERROR` próximas. Evidências especialmente úteis:

- `Editor sequencial e callbacks dos botoes NEXT/BACK instalados.`
- `Nova equipe definida: 2 NPC(s).`
- `Criando NPC 1 de 2`
- `Ficha NPC 1 finalizada:`
- `Criando NPC 2 de 2`
- `Ficha NPC 2 finalizada:`
- `Todas as fichas concluidas.`
- `Nova partida: 2 companheiros configurados.`
- `OnGameStart: equipe detectada no modData`

Caso o fluxo não avance, **não** altere `EXPERIMENTAL_SPAWN`. Envie `console.txt` para depuração.

## Fora do escopo deste teste

Instanciação `IsoPlayer` de NPC, spawn conjunto, seguidor funcional, persistência de entidades e equipamentos. Os campos de aparência estão sendo capturados parcialmente em tabela serializável; roupas e visuais ainda precisam de aplicação e validação reais.
