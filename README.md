# SupraNPC

Mod open source para **Project Zomboid Build 42**, com desenvolvimento direcionado à **B42.13.1**. Objetivo: permitir criar companheiros NPC antes de começar o jogo, spawná-los próximos ao jogador e comandá-los com lógica determinística (sem IA externa).

> **Estado: v0.1.0-dev / protótipo inicial.** O jogo ainda não foi utilizado para validar esta implementação. O mod já tem estrutura B42, seletor de quantidade, fichas serializáveis, lógica de ordens e adaptadores experimentais. **Não há garantia de NPCs funcionais neste commit.** O editor individual de aparência/profissão/skills e o spawn estável são as próximas etapas.

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

Depois abra o jogo, ative **SupraNPC** no menu **Mods** e ative-o também na configuração de mods da partida, caso necessário. Inicie **um save novo e descartável** e verifique a tela de seleção de quantidade quando aparecer a etapa de profissão. Use `console.txt` em `%USERPROFILE%\Zomboid\console.txt` para erros de inicialização.

## O que funciona no código agora

- **Configuração inicial:** quantidade de 0 a 5 NPCs adicionais ao jogador, antes da edição vanilla do personagem, com UI própria experimental.
- **Modelo de fichas:** identificadores, nomes padrão, profissão, skills, traits, aparência, status e ordem independentes para cada NPC; validação e cópia de dados.
- **Integração inicial:** evento `OnNewGame` para transferir fichas ao `modData` do personagem principal.
- **Ordens:** máquina de estados com seguir, guardar, autodefesa, proteção e tarefas futuras (as que faltam ainda não executam ações).
- **Spawn e seguimento:** protótipos isolados e **desativados por padrão**, pois ainda não testados na B42.13.1.

**Ainda não implementado:** editor completo de cada NPC após criar o jogador, spawn conjunto validado, sistema de combate, looting, autoequipar, crafting, necessidades, cura, Base Zone e missões. Também falta verificar se o jogo salva/carrega entidades NPC criadas por Lua sem problemas.

Para experimentar o protótipo de spawn **somente em save descartável**, edite `42/media/lua/shared/SupraNPC/Constants.lua` e ajuste `EXPERIMENTAL_SPAWN = true`. O resultado pode falhar ou ser incompatível; ainda não é um modo de jogo pronto.

## Atualizações

```powershell
git -C "$env:USERPROFILE\Zomboid\mods\SupraNPC" pull
```

## Desenvolvimento

- Código do mod: `42/media/lua/` (Lua / Kahlua 5.1).
- Sem instalação de Python, Ollama, APIs remotas, redes neurais ou aprendizagem por reforço.
- Testes puros: `lua5.1 tests/roster_spec.lua`.
- CI GitHub Actions: parse do Lua 5.1 e testes unitários.
- Arquitetura e próximos passos: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
- Quadro Kanban: https://trello.com/b/kIsvUBhY/supranpc-project-zomboid-b42131

## Licença

GNU General Public License v2.0 — veja [LICENSE](LICENSE).
