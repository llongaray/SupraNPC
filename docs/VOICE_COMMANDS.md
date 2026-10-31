# SupraNPC — Comandos e tecla de fala (Build 42.13.1)

## Funciona nesta etapa

- Categoria **SupraNPC** em Opções > Teclas, com **Falar com NPC (segurar tecla)**, sem atalho padrão para evitar conflitos com o jogo.
- Ajuda **?** no painel da equipe, com exemplos reais para FOLLOW, IDLE, GUARD, RETURN_BASE, PASSIVE, DEFENSIVE e AGGRESSIVE.
- Entrada manual por texto mantida; os comandos executam e o NPC responde no mundo por balão de fala sem aguardar mensagens antigas.
- Contrato `VoiceHotkey.installRecognizer(provider)` aceita backend de fala com `start(callback)` e `stop()`. Ao concluir uma frase o backend deve chamar `callback(transcricao)`. O mesmo parser PT-BR e alvo por nome / Todos são reutilizados.

## Importante: microfone ainda NÃO está integrado

A Build 42 fornece suporte a entrada de teclado e VOIP, mas **não fornece API Lua de speech-to-text**. Portanto uma tecla ou o VOIP nativo não transcrevem palavras. Nesta implementação **nenhum código captura microfone**, e a tela mostra **STT PENDENTE** em vez de fingir que está gravando. Vincular a tecla sem um backend informa isso claramente e não interfere com o jogo.

Para obter um push-to-talk realmente funcional, será necessário empacotar e validar um reconhecedor PT-BR compatível (offline, modelo embarcado, ou um serviço de STT local) com acesso ao áudio e ponte suportada para Lua. Integrações Java não são oficialmente suportadas pelo projeto; não injetar Java ou executar processos arbitrários sem revisão de segurança. Não presumir compatibilidade de System.Speech (Windows Speech Recognition) com PT-BR: o motor de desktop tradicional não oferece esse idioma por padrão. `Win+H` não é considerado solução interna.

## Validação

1. Atualize o mod e abra Opções > Teclas > SupraNPC.
2. Atribua tecla que não colida com outros atalhos; sem teclado configurado aparece `SEM TECLA`.
3. Abra o painel SupraNPC e clique **?** para ver os exemplos.
4. Digite `Yong, me segue` e clique Enviar: o NPC recebe FOLLOW e responde.
5. Pressione o atalho: sem recognizer instalado, aparece mensagem de STT ainda não integrado; não aparece estado falso `LISTENING`.
6. Uma implementação futura do backend deve ser validada no jogo B42.13.1 com microfone PT-BR real e latência medida.
