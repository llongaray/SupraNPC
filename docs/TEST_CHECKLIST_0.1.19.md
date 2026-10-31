# SupraNPC 0.1.19-dev — hotfix real de 31/10/2026

## Evidência: console(1).txt da B42.13.1
O arquivo fornecido pelo usuário possui ~22,5 mil linhas e vários carregamentos do jogo (0.1.8-dev a 0.1.18-dev). Na última sessão, a v0.1.18-dev foi carregada. A maioria dos erros repetidos tem a assinatura:

```
attempted index: getSymbolCount of non-table: zombie.worldMap.symbols.WorldMapSymbols
NPCMapKnowledge.lua line #9 -> symbols line #44 -> read -> update -> Boot.onTick
```

A mesma exceção foi registrada **352 vezes**, pois `MapKnowledge.update` era executado a cada 90 ticks. O `pcall` não evitava que Kahlua registrasse o erro no console.

Houve também duas exceções `hideAndChildren` em `ISContextMenu.get` / `NPCUI.openMenu` durante um carregamento **anterior**; não são a causa do flood do mapa na 0.1.18-dev. Avisos da engine sobre fluid containers, AnimalPacket, receita Piano e zonas Mannequin não são originados em `NPCMapKnowledge.lua`.

## Correções
1. Removida a tentativa de ler métodos de `MapItem:getSymbols()` bruto da engine. Somente a interface de símbolos do `UIWorldMap` compatível com Lua é usada; o fallback `MapItem` é restrito a *tabelas Lua* úteis para testes. Sem interface acessível, conserva o conhecimento anteriormente salvo no `ModData` e não gera exceção.
2. Memória de zumbis vistos: antiga condição mantinha FLEE enquanto os objetos permanecessem vivos e a menos de 10 tiles, mesmo sem contato visual. Agora o registro expira em **4,5 segundos sem percepção confirmada**; uma observação somente da memória NÃO renova seu prazo. Durante esse período continua se afastando em vez de retomar FOLLOW instantaneamente ao virar de costas. Se zumbis forem vistos novamente, reavalia ameaça.
3. Regressões acrescentadas em `tests/map_knowledge_spec.lua` e `tests/risk_combat_spec.lua`.

## Teste rápido
Feche o jogo; rode `git -C "$env:USERPROFILE\Zomboid\mods\SupraNPC" pull origin main` e abra a B42.13.1. A versão no carregamento deve ser 0.1.19-dev.

1. Entre em save de teste com NPC, espere um minuto. Não devem surgir dezenas de erros `getSymbolCount`.
2. Em local sem zumbis próximos, siga o jogador; o status deve voltar a `FOLLOW` depois de perder a ameaça e a memória expirar.
3. Mostre 2–3 zumbis, recue e vire as costas; a fuga deve se manter brevemente, mas não indefinidamente.
4. Abra o mapa e escreva `NPC:BASE:A` e `NPC:BASE:B` em cantos opostos. Se o HUD continuar `sem BASE`, a compatibilidade de leitura das anotações pela interface UIWorldMap precisará ser investigada à parte. Esta correção visa **eliminar o erro**, não comprovar compatibilidade total da API de mapa.
5. Salve e feche; envie novo `console.txt` se surgir exceção.

**Limites:** o CI usa mocks Lua, não roda a engine. Movimento e detecção ainda precisam de teste real B42.13.1.
