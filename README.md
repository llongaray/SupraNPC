# SupraNPC

Mod open source para **Project Zomboid Build 42**, com desenvolvimento direcionado à **B42.13.1**. Objetivo: permitir criar companheiros NPC antes de começar o jogo, spawná-los próximos ao jogador e comandá-los com lógica determinística (sem IA externa).

> **Estado: v0.1.3-dev / protótipo inicial.** O jogo ainda não foi utilizado para validar esta implementação. O mod já tem estrutura B42, seletor de quantidade, fichas serializáveis, lógica de ordens e adaptadores experimentais. **Criacao sequencial validada pelo usuario na B42.13.1.** O spawn de teste foi habilitado em novas partidas, mas usa um CORPO PROXY baseado em IsoZombie, nao um IsoPlayer ou NPC humano completo. Teste somente em saves descartaveis.

## Instalar via git clone diretamente na pasta `mods`

No PowerShell (Windows):

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\Zomboid\mods" | Out-Null
Set-Location "$env:USERPROFILE\Zomboid\mods"
git clone https://github.com/llongaray/SupraNPC.git SupraNPC
```

A estrutura final é:

```text
Zomboid/
└── mods/
    └── SupraNPC/                 <- raiz do proprio repositorio
        ├── 42/
        │   ├── mod.info
        │   └── media/lua/
        │       ├── shared/SupraNPC/
        │       │   ├── Constants.lua
        │       │   ├── Roster.lua
        │       │   └── Orders.lua
        │       └── client/SupraNPC/
        │           ├── Boot.lua
        │           ├── TeamSetup.lua
        │           ├── SpawnAdapter.lua
        │           └── Follow.lua
        ├── common/
        ├── docs/
        └── tests/
```

**Não** crie outra subpasta `Contents/mods` dentro do clone. Em B42, o `mod.info` fica dentro da pasta `42/`, não na raiz do repositório.

Depois abra o jogo, ative **SupraNPC** no menu **Mods** e ative-o também na configuração de mods da partida, caso necessário. Inicie **um save novo e descartável** e verifique a tela de seleção de quantidade quando aparecer a etapa de profissão. Depois finalize o personagem principal; o mod deve voltar à tela de profissão para o NPC 1, permitir escolher profissão/traits e aparência, repetir para NPC 2, e somente depois do último NPC iniciar o mundo. Use `console.txt` em `%USERPROFILE%\Zomboid\console.txt` para erros de inicialização.

## O que funciona no código agora

- **Configuração inicial:** quantidade de 0 a 5 NPCs adicionais ao jogador, antes da edição vanilla do personagem.
- **Editor sequencial (ainda não validado in-game):** ao concluir o player, o mod intercepta o último botão Próximo; reaproveita as telas vanilla de profissão, traços e aparência para cada NPC e só libera o carregamento do mundo ao finalizar todos. Preserva e restaura o descritor, a profissão e os traços do jogador.
- **Modelo de fichas:** identificadores e nomes padrão próprios (NPC 1, NPC 2...), profissão, skills, traits, aparência, status e ordem independentes. Validação de fichas completas, IDs únicos, nomes e níveis de skill; cópia sem compartilhamento de objetos.
- **Captura visual incremental:** cabelo, barba, gênero, índice de pele, cores RGB e voz quando presentes na API. A aplicação desses atributos em entidades NPC ainda não está pronta.
- **Integração inicial:** evento `OnNewGame` para transferir fichas ao `modData` do personagem principal.
- **Ordens:** máquina de estados com seguir, guardar, autodefesa, proteção e tarefas futuras (as que faltam ainda não executam ações).
- **Spawn (v0.1.3-dev, experimental):** para novas partidas, tenta criar uma entidade proxy (chassi IsoZombie com outfit de humano) para cada ficha, proxima ao jogador e em tiles livres, com tentativas limitadas, anticlone e logs de erro. **Nao e IsoPlayer** e pode se comportar de modo inadequado ate os testes in-game.
- **Seguimento:** o Follow permanece inativo para os proxies por seguranca. Nenhuma IA externa.

**Ainda não implementado/validado:** um NPC humano real (IsoPlayer), aplicação completa de aparencia e roupas, persistencia de entidades em save/load, seguimento, spawn conjunto definitivo, sistema de combate, looting, autoequipar, crafting, necessidades, cura, Base Zone e missões. Também falta verificar se o jogo salva/carrega entidades NPC criadas por Lua sem problemas.

O prototipo de spawn proxy está **habilitado** na v0.1.3-dev para **novas partidas descartáveis**. Para desativar, defina `EXPERIMENTAL_SPAWN = false` em `42/media/lua/shared/SupraNPC/Constants.lua` antes de abrir o jogo. Se a entidade aparecer, **isso nao significa que seja segura/aliada**: o motor a identifica internamente como zumbi. Nao use em saves importantes.

## Atualizações

```powershell
git -C "$env:USERPROFILE\Zomboid\mods\SupraNPC" pull
```

## Desenvolvimento

- Código do mod: `42/media/lua/` (Lua / Kahlua 5.1).
- Sem instalação de Python, Ollama, APIs remotas, redes neurais ou aprendizagem por reforço.
- Testes puros: `lua5.1 tests/roster_spec.lua` e `lua5.1 tests/team_flow_spec.lua`, incluindo nomes separados, validação da equipe, fluxo jogador→NPC1→NPC2 e callbacks dos botões.
- CI GitHub Actions: parse do Lua 5.1 e testes unitários.
- Arquitetura e próximos passos: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
- Quadro Kanban: https://trello.com/b/kIsvUBhY/supranpc-project-zomboid-b42131

## Licença

GNU General Public License v2.0 — veja [LICENSE](LICENSE).

## Teste de regressão B42.13.1 — criação de 2 NPCs

Checklist detalhado: [docs/TEST_CHECKLIST_0.1.3.md](docs/TEST_CHECKLIST_0.1.3.md).

1. Execute `git pull` na pasta do mod e **reinicie completamente o jogo**.
2. Crie **nova partida** com somente SupraNPC ativo; escolha **2** no seletor.
3. Conclua profissão/traits/aparência do **jogador**.
4. A tela de **profissão** deve abrir para **NPC 1/2**; escolha seus traits e vá à aparência. Finalize.
5. A tela de **profissão** deve abrir para **NPC 2/2**; personalize e finalize.
6. Só então deve aparecer a tela de carregamento da partida.
7. Se alguma transição falhar, envie `%USERPROFILE%\\Zomboid\\console.txt`, especialmente linhas com `[SupraNPC]`.

**Atenção:** como `EXPERIMENTAL_SPAWN=false`, os NPCs configurados ainda **não aparecerão no mundo**. Esta etapa valida o fluxo e a serialização das fichas, antes do desenvolvimento seguro do spawn real.

## Correção de navegação do editor — 0.1.3-dev

Correção da troca de avatar/descriptor entre jogador e NPCs, interceptação de próximo na tela de profissão, estados explícitos profissão→aparência e retorno seguro em falhas. A correção não significa que o spawn foi implementado ou validado. Para testar, use [o roteiro da v0.1.3-dev](docs/TEST_CHECKLIST_0.1.3.md) e envie o `console.txt` se a mensagem ERROR aparecer.


## Marco v0.1.3-dev — spawn proxy (ainda sem NPC real)

A criação de jogador e 2 NPCs já foi exercitada com sucesso na B42.13.1. O problema de nenhum spawn ocorria porque `EXPERIMENTAL_SPAWN` estava `false`; foi substituído o construtor `IsoPlayer.new` não validado por uma camada de protótipo sem dependências externas, baseada em `addZombiesInOutfit`. Os NPCs criados no editor ainda não têm aplicação completa de aparência/atributos/ordens no mundo. O adapter marca entidades como `SupraNPC_Proxy` e tenta neutralizar seus ataques (sem garantia nesta build); não as registra para seguir.

Para validar a primeira aparição com segurança, use **uma nova partida descartável** e o [checklist 0.1.3-dev](docs/TEST_CHECKLIST_0.1.3.md). Uma partida antiga marcada `awaiting_validation` não recebe NPCs automaticamente, para evitar duplicação.
