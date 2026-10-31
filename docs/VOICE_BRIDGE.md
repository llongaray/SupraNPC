# SupraNPC — voz PT-BR por microfone

## Implementação

A API Lua da B42 não captura áudio. O mod usa exclusivamente `getFileWriter/getFileReader` no cache permitido pelo Project Zomboid; um executável portátil abre o microfone padrão e usa um modelo **Whisper base multilíngue local**. A fala não é enviada a serviços externos. É necessário abrir o executável na sessão, pois o mod não pode iniciá-lo internamente com segurança.

## Usando a versão portátil (Windows)

1. No GitHub abra **Actions → Build portable PT-BR voice bridge (Windows)** e a execução mais recente que esteja verde. Baixe o artefato **SupraNPCVoice-Windows-PTBR**.
2. Extraia o ZIP numa pasta (mantenha `models/base` e `_internal` junto ao executável). Execute `SupraNPCVoice.exe` e deixe sua janela aberta enquanto joga. Não exige instalar Python.
3. Deixe o microfone correto como dispositivo **padrão de gravação do Windows**. Se necessário configure antes de iniciar o executável.
4. Abra PZ com o mod 0.1.27-dev ou superior. Aguarde o HUD mudar de `STT PENDENTE` para `READY`.
5. **Segure Mouse Btn 3** (ou tecla atribuída), fale `Yong, me segue`, **solte**. O programa transcreve o trecho e envia o texto ao mod, que executa o mesmo parser dos comandos digitados.
6. A primeira execução pode aquecer o modelo e demorar. As seguintes usam o modelo local. Com modelo `base`, existe latência após soltar a tecla, dependente do processador; não prometer tempo fixo.

## Alternativa para quem possui Python

Na pasta do repositório:

```powershell
py -3 -m pip install -r companion/requirements.txt
py -3 companion/supranpc_voice.py --model base
```

Esta alternativa **instala dependências** e pode baixar o modelo da internet na primeira execução. O pacote portátil é a opção para jogadores sem Python.

## Segurança e limitações

- Sem servidor HTTP aberto, credenciais, permissões elevadas ou acesso externo às conversas. Somente comandos de texto em `%USERPROFILE%\Zomboid\Lua\SupraNPC_voice_request.txt` e `SupraNPC_voice_result.txt`, com `SupraNPC_voice_status.txt` para heartbeat.
- O binário é gerado pelo GitHub Actions do próprio repositório; não execute binários recebidos de terceiros como se fossem oficiais.
- `getFileWriter` só pode acessar o cache Lua permitido pelo jogo. Se o diretório de usuário tiver sido alterado por opções de inicialização, o companion precisa usar `--directory` apontando para o **mesmo** diretório `Lua`.
- O jogo só reconhece voz enquanto o companion estiver rodando. Se ele fechar, o HUD volta a `STT PENDENTE`. A gravação só ocorre entre pressionar e soltar o atalho.
- Confirme a saída do reconhecedor no console do companion caso o parser não aceite a frase.
- Reconhecimento e controle por voz ainda precisam de teste real no Windows com B42.13.1; teste automatizado da ponte não substitui teste de microfone.
