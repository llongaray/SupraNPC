# SupraNPC

Mod open source para **Project Zomboid Build 42**, com desenvolvimento direcionado à **B42.13.1**. Objetivo: permitir criar companheiros NPC antes de começar o jogo, spawná-los próximos ao jogador e comandá-los com lógica determinística (sem IA externa).

> **Estado: v0.1.2-dev / protótipo inicial.** O jogo ainda não foi utilizado para validar esta implementação. O mod já tem estrutura B42, seletor de quantidade, fichas serializáveis, lógica de ordens e adaptadores experimentais. **Não há garantia de NPCs funcionais neste commit.** O fluxo de criação sequencial agora está implementado, mas precisa ser validado no jogo; o spawn estável ainda é uma etapa posterior.

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
- **Spawn e seguimento:** protótipos isolados e **desativados por padrão**, pois ainda não testados na B42.13.1.

**Ainda não implementado/validado:** a aplicação completa de todos os detalhes visuais de cada NPC no mundo, spawn conjunto validado, sistema de combate, looting, autoequipar, crafting, necessidades, cura, Base Zone e missões. Também falta verificar se o jogo salva/carrega entidades NPC criadas por Lua sem problemas.

Para experimentar o protótipo de spawn **somente em save descartável**, edite `42/media/lua/shared/SupraNPC/Constants.lua` e ajuste `EXPERIMENTAL_SPAWN = true`. O resultado pode falhar ou ser incompatível; ainda não é um modo de jogo pronto.

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

Checklist detalhado: [docs/TEST_CHECKLIST_0.1.2.md](docs/TEST_CHECKLIST_0.1.2.md).

1. Execute `git pull` na pasta do mod e **reinicie completamente o jogo**.
2. Crie **nova partida** com somente SupraNPC ativo; escolha **2** no seletor.
3. Conclua profissão/traits/aparência do **jogador**.
4. A tela de **profissão** deve abrir para **NPC 1/2**; escolha seus traits e vá à aparência. Finalize.
5. A tela de **profissão** deve abrir para **NPC 2/2**; personalize e finalize.
6. Só então deve aparecer a tela de carregamento da partida.
7. Se alguma transição falhar, envie `%USERPROFILE%\\Zomboid\\console.txt`, especialmente linhas com `[SupraNPC]`.

**Atenção:** como `EXPERIMENTAL_SPAWN=false`, os NPCs configurados ainda **não aparecerão no mundo**. Esta etapa valida o fluxo e a serialização das fichas, antes do desenvolvimento seguro do spawn real.

## Correção de navegação do editor — 0.1.2-dev

Correção da troca de avatar/descriptor entre jogador e NPCs, interceptação de próximo na tela de profissão, estados explícitos profissão→aparência e retorno seguro em falhas. A correção não significa que o spawn foi implementado ou validado. Para testar, use [o roteiro da v0.1.2-dev](docs/TEST_CHECKLIST_0.1.2.md) e envie o `console.txt` se a mensagem ERROR aparecer.
