# Matriz de testes in-game — Project Zomboid B42.13.1

Checklist de testes **manuais**, não considerados executados.

| Caso | Passos | Resultado esperado |
|---|---|---|
| Instalação | `git clone` direto em `Zomboid/mods/SupraNPC` | Mod listado; sem subpasta extra |
| Sem companheiros | Nova partida, selecionar 0 | Entrar no mundo sem novo NPC |
| Um companheiro | Nova partida, selecionar 1 | Player → Profissão NPC 1 → Aparência NPC 1 → Mundo |
| Três companheiros | Nova partida, selecionar 3 | Três fichas únicas; nenhum salto de tela |
| Cinco companheiros | Nova partida, selecionar 5 | Cinco fichas únicas; limite respeitado |
| Isolamento de fichas | Profissões e traits diferentes | Jogador/NPCs preservam escolhas individuais |
| Crash anterior | Finalizar o último NPC | Mundo carrega sem fechamento; preservar console se falhar |
| Spawn experimental | Novo save descartável, 1 NPC | IsoPlayer extra **somente se validado**, sem zumbis |
| Segurança do jogador | Após criação de NPC | Câmera/input continuam controlando o player |
| Spawn em ambiente fechado | Novo save em casa | Não atravessar paredes; evitar tiles ocupados |
| Recarregar save | Sair, voltar ao jogo | Sem NPCs duplicados; registrar ausência de entidade |
| Mods concorrentes | Apenas após teste isolado | Ausência de conflitos documentados |
| Performance | 0, 1, 3, 5 NPCs | Registrar FPS/uso CPU, sem inventar métricas |
| Sem dependências | PC sem Ollama/Python | Mod funciona apenas com o jogo |
| Erros | Anexar `console.txt` após falha | Evidência com versão exata e etapa do fluxo |

**Não marcar testes de spawn, combate ou persistência de entidades como aprovados enquanto a integração 0.1.7+ não for observada em jogo.**

Antes de testar: fechar o jogo, atualizar `main`, escolher save novo e descartável. Os experimentos anteriores (IsoZombie proxy) podem deixar entidades em saves antigos; não reutilizá-los.

Diagnóstico: `%USERPROFILE%\Zomboid\console.txt`. Anotar a versão registrada por `[SupraNPC] Versao` e o último estágio antes de `ERROR`.
