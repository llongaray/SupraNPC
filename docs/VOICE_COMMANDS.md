# SupraNPC — Comandos e tecla de fala (Build 42.13.1)

## Funciona nesta etapa

- Categoria **SupraNPC** em Opções > Teclas, com **Falar com NPC (segurar tecla)**, sem atalho padrão para evitar conflitos com o jogo.
- Ajuda **?** no painel da equipe, com exemplos reais para FOLLOW, IDLE, GUARD, RETURN_BASE, PASSIVE, DEFENSIVE e AGGRESSIVE.
- Entrada manual por texto mantida; os comandos executam e o NPC responde no mundo por balão de fala sem aguardar mensagens antigas.
- Contrato `VoiceHotkey.installRecognizer(provider)` aceita backend de fala com `start(callback)` e `stop()`. Ao concluir uma frase o backend deve chamar `callback(transcricao)`. O mesmo parser PT-BR e alvo por nome / Todos são reutilizados.

## Microfone PT-BR integrado via companion local (0.1.27-dev)

A engine Lua da Build 42 não oferece API de captura de microfone nem STT. A versão 0.1.27-dev adiciona `VoiceBridge.lua` e um processo portátil externo `SupraNPCVoice.exe` (Whisper `base` local) que recebe as bordas do botão e devolve a transcrição ao mesmo parser das ordens digitadas. A fala **não é enviada para servidores externos**.

O HUD permanece em `STT PENDENTE` enquanto o companion não estiver rodando. Quando o programa publicar heartbeat, passa para `READY`; ao pressionar exibe `LISTENING` e ao soltar `PROCESSING`. A resposta do NPC acontece após o reconhecimento. Não é garantida latência zero, especialmente em CPUs lentas. Veja [instalação e download do pacote Windows](VOICE_BRIDGE.md).

**Não use o atalho Win+H:** ele não faz parte deste sistema. O companion deve ser iniciado pelo jogador; o mod sozinho não consegue iniciar executáveis nativos. Ainda é obrigatório validar o áudio no jogo e a compatibilidade do Windows.

## Validação

1. Atualize o mod e abra Opções > Teclas > SupraNPC.
2. Atribua tecla que não colida com outros atalhos; sem teclado configurado aparece `SEM TECLA`.
3. Abra o painel SupraNPC e clique **?** para ver os exemplos.
4. Digite `Yong, me segue` e clique Enviar: o NPC recebe FOLLOW e responde.
5. Pressione o atalho: sem recognizer instalado, aparece mensagem de STT ainda não integrado; não aparece estado falso `LISTENING`.
6. Baixe e inicie o pacote portátil descrito em `VOICE_BRIDGE.md`. Verifique o HUD mudar para `READY`; segure Mouse Btn 3, fale e solte. Confirme o texto na janela do companion e a resposta do NPC. Isso requer validação em jogo real.
