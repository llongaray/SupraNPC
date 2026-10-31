# SupraNPC 0.1.16-dev — QA Build 42.13.1

> A automação Lua não executa a engine Project Zomboid: **testar com save descartável**. Build e testes sintáticos não provam ataque, dano, mira, animação ou captura de voz no jogo.

## Combate (prioridade P0)

1. Carregue com um NPC em postura AGRESSIVA. Posicione um zumbi à frente, cerca de 7 tiles do NPC, com caminho livre. Esperado: NPC começa a interceptar antes de o zumbi encostar no jogador. `TACTIC ... stance=AGGRESSIVE ... APPROACH`.
2. Coloque zumbi em pé e desarmado a ~0.9 tile do NPC. Esperado: `NATIVE_ATTACK SHOVE accepted`, seguida da animação real de empurrão. Não considerar apenas a queda do zumbi como confirmação do ataque nativo.
3. Equipado com arma melee, a ~1.5 tile do zumbi, esperado: `NATIVE_ATTACK SWING accepted`, animação de golpe e redução de saúde apenas no zumbi. A menos de ~1 tile, o NPC deve forçar SHOVE.
4. Zumbi caído a ~1.0 tile, NPC com e sem arma. Esperado: `NATIVE_ATTACK GROUND accepted`, pisão desarmado ou ataque para baixo armado e dano real. **Se apenas aparecer accepted sem dano/animação**, capturar `console.txt` e registrar incompatibilidade entre `DoAttack` e entidade NPC IsoPlayer.
5. Aproximar NPC pelas costas de zumbi a 1 tile: percepção deve reconhecer após checar tiles adjacentes livres, sem atravessar paredes/portas. Coloque parede entre NPC/zumbi para garantir que não ataca através dela.
6. Repetir ataque com aliado entre NPC e zumbi: o mod deve bloquear ataque devido a risco de acertar aliado, registrando `ally in swing arc`.
7. Verificar que 3+ zumbis seguem gatilhos de fuga, e que, após ameaça desaparecer, o NPC retoma FOLLOW.
8. Testar postura PASSIVA (reage só próximo, ~2.2 tiles), DEFENSIVA (~5 tiles) e AGRESSIVA (~9 tiles). A postura não deve cancelar a autodefesa a curta distância.

A implementação usa `IsoPlayer:DoAttack(1.0)` para tentar transferir a seleção de golpe/empurrão/chão ao motor. Se a função rejeitar porque a entidade IsoPlayer do NPC não é registrada como personagem controlado, o mod registra o erro e **não duplica dano com `Hit()`**. Falta comprovação em jogo.

## Voz: Windows 11 e Português (Brasil)

1. Com equipe criada, na lateral esquerda selecione o campo **COMANDO DE VOZ (WIN+H)**.
2. Pressione **Win+H**, diga **"Yong, me segue"** ou **"Todos, me sigam"**; confira que aparece texto na caixa.
3. Pressione **Enter** (ou o botão Enviar). Esperado: `FOLLOW` é emitido via `NPCController.order`, com balão do jogador e resposta textual do NPC.
4. Diga **"Yong, aguarde aqui"**, **"Yong, guarda aqui"**, **"Yong, guarda minha posição"**, **"Alex, postura agressiva"**, **"Pessoal, postura defensiva"**.
5. Frases ambíguas/desconhecidas ou sem nome, quando existem vários NPCs, devem ser rejeitadas sem alterar qualquer ordem.
6. Testar envio via teclado, sem ditado: deve produzir o mesmo resultado.
7. O campo aceita somente os comandos existentes: FOLLOW, IDLE, GUARD e STANCE. Ataque pontual, fuga manual e saque não são implementados nesta interface.

**Importante:** a digitação por voz do Windows usa um serviço online da Microsoft, exigindo microfone e Internet. Não é escuta passiva. Sem Windows 11, o campo funciona por teclado. O mod não acessa microfone, não envia áudio e não depende de IA/Ollama.

## Diagnóstico de falhas

Enviar `C:\Users\<usuario>\Zomboid\console.txt` depois do teste (principalmente linhas com `NATIVE_ATTACK`, `TACTIC`, `WALK`, `VOICE`, `DoAttack error`, `DoAttack rejected`).

Fontes técnicas: `IsoPlayer:DoAttack` e `IsoLivingCharacter:setDoShove` do JavaDoc PZ, comportamento condicional inspirado na arquitetura do Conditional Speech de Chuckleberry Finn (sem copiar o código fonte).
