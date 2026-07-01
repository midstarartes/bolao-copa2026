# AGENTS.md

## 1. Visão geral do projeto

Este projeto é um bolão da Copa do Mundo 2026 com interface web, autenticação própria via Supabase, ranking em tempo real, palpites por jogo, palpites extras, sistema de moedas, buffs, histórico de desempenho e painel administrativo. No estado atual, os resultados oficiais devem ser lançados manualmente pelo ADMIN; a sincronização por API externa foi desativada para não interferir no bolão.

O estado atual do projeto indica que a aplicação principal está concentrada em um único arquivo frontend grande, [design-lab.html](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\design-lab.html), enquanto as regras críticas de negócio estão centralizadas em funções SQL do Supabase.

## 2. Objetivo do bolão

Permitir que participantes:

- criem conta;
- registrem palpites por partida;
- registrem palpites extras do torneio;
- usem moedas e buffs estratégicos;
- acompanhem ranking e histórico;
- comparem palpites após o fechamento de cada jogo.

Também permitir que um administrador:

- gerencie usuários;
- ajuste moedas;
- altere palpites e extras manualmente;
- lance resultados oficiais manualmente;
- acompanhe auditoria;
- mantenha o lançamento manual como fonte principal de verdade dos resultados.

## 3. Stack usada

- Frontend: HTML + CSS + JavaScript vanilla.
- Backend lógico: Supabase via tabelas, RPCs, RLS e patches SQL.
- API externa de resultados: TheSportsDB, atualmente desativada.
- Função serverless: Vercel Function em `api/the-sports-sync.js`, atualmente respondendo como desativada e sem gravar resultados.
- Deploy: Vercel.
- Automação de sincronização: GitHub Actions mantido apenas como workflow manual/no-op, sem agenda automática.
- Build: script Node.js simples via `npm run build`.

## 4. Como rodar localmente

O que foi confirmado nos arquivos:

- Não existe script `dev` em [package.json](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\package.json).
- Existe script `build`:
  - `npm run build`
- O build copia os arquivos para `dist` via [scripts/build-vercel.mjs](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\scripts\build-vercel.mjs).
- O [index.html](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\index.html) redireciona para `design-lab.html`.

Forma local confirmada:

- abrir [design-lab.html](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\design-lab.html) no navegador para testar a interface;
- ou gerar `dist` com `npm run build`.

Forma ideal de preview local: `a confirmar`.
Não há servidor local configurado explicitamente no projeto.

## 5. Como funciona o deploy

O deploy é preparado para a Vercel.

Arquivos envolvidos:

- [vercel.json](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\vercel.json)
- [package.json](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\package.json)
- [scripts/build-vercel.mjs](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\scripts\build-vercel.mjs)

Fluxo confirmado:

1. A Vercel executa `npm run build`.
2. O script monta a pasta `dist`.
3. Os arquivos estáticos principais são copiados para `dist`.
4. A função `api/the-sports-sync.js` é tratada como rota serverless pela Vercel.

## 6. Como funciona o GitHub

O repositório usa GitHub como origem principal de versão.

O que foi confirmado:

- branch principal atual: `main`;
- existe workflow em [.github/workflows/sync-results.yml](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\.github\workflows\sync-results.yml);
- esse workflow foi desativado como automação: não possui mais `schedule` e, quando executado manualmente com `workflow_dispatch`, apenas informa que a sincronização por API está desativada.

Últimos commits lidos durante a análise:

- `463fde0 Destaca palpites por resultado no modal`
- `cea769d Corrige pareamento de resultados da API`
- `2b74be6 Destaca acertos na lista de palpites por jogo`
- `e850d38 Evita mostrar extras locais como se estivessem salvos`
- `969ef06 Corrige status padrão no lançamento manual de resultados`
- `db0d5b1 Refina destaque do pódio e remove divisor do top 8`
- `7ddc98c Refina cores dos quatro últimos no ranking`
- `516be2e Ajusta cores da zona de rebaixamento no ranking`
- `eac3433 fix: endurecer cron da API e persistir falhas`
- `7297324 Corrige aposta de moedas com saldo 1`

## 7. Como funciona a Vercel

O projeto está preparado para:

- hospedar o frontend estático;
- expor a rota `/api/the-sports-sync`, atualmente bloqueada para impedir gravações por API;
- usar variáveis de ambiente para Supabase, API externa, admin e cron.

Variáveis observadas no código da função:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `THE_SPORTS_DB_API_KEY`
- `THE_SPORTS_DB_WORLD_CUP_LEAGUE_ID`
- `ADMIN_USERNAME`
- `ADMIN_PASSWORD`
- `CRON_SECRET`
- `QUICK_SWITCH_PERSONAL_USERNAME`
- `QUICK_SWITCH_PERSONAL_PASSWORD`

## 8. Como funciona o Supabase

O Supabase é o backend real do sistema.

Ele concentra:

- cadastro e login;
- sessões;
- partidas;
- palpites;
- buffs;
- extras;
- ranking;
- histórico;
- status de sincronização da API;
- auditoria admin;
- diversas RPCs consumidas diretamente pelo frontend.

Arquivos principais:

- [supabase/schema.sql](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\supabase\schema.sql)
- [supabase/patch-010-admin-account.sql](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\supabase\patch-010-admin-account.sql)
- [supabase/patch-011-admin-audit.sql](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\supabase\patch-011-admin-audit.sql)
- [supabase/patch-015-api-sync-status.sql](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\supabase\patch-015-api-sync-status.sql)
- [supabase/patch-026-match-predictions-viewer.sql](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\supabase\patch-026-match-predictions-viewer.sql)
- [supabase/patch-029-new-scoring-system.sql](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\supabase\patch-029-new-scoring-system.sql)
- [supabase/patch-030-zebra-multiplier.sql](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\supabase\patch-030-zebra-multiplier.sql)
- [supabase/patch-031-fix-mission-progress-columns.sql](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\supabase\patch-031-fix-mission-progress-columns.sql)

## 9. Estrutura de pastas e arquivos importantes

- `.github/`
  - workflows do GitHub Actions.
- `.vercel/`
  - artefatos locais da Vercel, se presentes.
- `api/`
  - função serverless da API de sincronização.
- `dist/`
  - saída do build.
- `public/`
  - assets e uma estrutura frontend mais antiga/modular.
- `scripts/`
  - scripts utilitários de build e teste.
- `supabase/`
  - schema, seed e patches SQL do projeto.
- `design-lab.html`
  - aplicação principal atual.
- `index.html`
  - redirecionador para `design-lab.html`.
- `package.json`
  - scripts do projeto.
- `vercel.json`
  - configuração de deploy e headers.
- `README.md`
  - documentação antiga, parcialmente desatualizada.
- `manifest.json`
  - manifesto PWA.

## 10. Principais telas e componentes

Pelo que foi confirmado em [design-lab.html](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\design-lab.html), as principais áreas são:

- tela principal do bolão;
- aba `Jogos`;
- aba `Extras`;
- aba `Moedas`;
- aba `Ranking`;
- aba `Regras`;
- aba `Admin`;
- modal de login/cadastro;
- modal de buffs;
- modal de palpites por jogo;
- modal/lista de “ver palpites”;
- painel de resultados oficiais;
- painel admin completo.

## 11. Fluxo de autenticação

Fluxo confirmado:

1. Usuário se cadastra por RPC `app_register_user`.
2. Usuário faz login por RPC `app_login_user`.
3. O banco cria uma sessão em `app_sessions`.
4. O frontend passa a trabalhar com um token de sessão.
5. As RPCs usam `app_get_user_by_token` para validar a sessão.
6. Logout via `app_logout_user`.

O frontend também possui cache local de sessão para manter estado no navegador.

## 12. Fluxo de usuário comum

Fluxo normal confirmado:

1. cadastrar ou logar;
2. ver jogos disponíveis;
3. registrar ou editar palpites antes do fechamento;
4. registrar palpites extras antes do fechamento global;
5. acompanhar moedas, missões e buffs;
6. usar buffs em jogos elegíveis;
7. ver ranking e histórico;
8. após o fechamento de um jogo, abrir “ver palpites” para comparar palpites.

## 13. Fluxo de administrador

Fluxo admin confirmado:

1. login com conta marcada como `is_admin`;
2. acesso à aba `Admin`;
3. gerenciamento de usuários;
4. ajuste de moedas;
5. edição manual de palpites e extras;
6. aplicação/remoção manual de buffs;
7. lançamento manual de resultados oficiais;
8. consulta de auditoria;
9. uso da sincronização via API como apoio;
10. alteração da própria senha admin.

## 14. Regras de palpites

Regras confirmadas:

- palpite normal por jogo;
- fechamento 30 minutos antes do início da partida;
- edição permitida até esse mesmo prazo;
- admin não participa como competidor;
- extras são salvos em tabela separada;
- extras respeitam `bonus_lock_at` em `app_settings`.

Visibilidade de palpites dos outros:

- somente após o fechamento do mercado do jogo, via `app_get_match_predictions`.

## 15. Regras de pontuação

Fonte principal confirmada:

- [supabase/patch-029-new-scoring-system.sql](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\supabase\patch-029-new-scoring-system.sql)

Resumo confirmado:

- Fase de grupos:
  - placar exato: `+1.0`
  - acertar resultado: `+0.5`
  - errar: `-0.1`
  - ausência: `-0.2`
- Mata-mata inicial:
  - placar exato: `+2.0`
  - acertar vencedor ou empate no placar de 90 min + acrescimos: `+1.0`
  - errar: `-0.2`
  - ausência: `-0.2`
- Mata-mata decisivo:
  - placar exato: `+3.0`
  - acertar vencedor ou empate no placar de 90 min + acrescimos: `+2.0`
  - errar: `-0.5`
  - ausência: `-0.5`

Extras:

- a pontuação dos extras é calculada por `app_score_bonus_prediction`;
- a zebra usa multiplicador por dificuldade em [patch-030-zebra-multiplier.sql](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\supabase\patch-030-zebra-multiplier.sql).

## 16. Regras de ranking

O ranking é calculado no banco por RPC.

Pontos confirmados:

- o frontend consome `app_get_leaderboard`;
- o cálculo considera palpites concluídos e extras;
- admin e usuários bloqueados ficam fora do ranking competitivo;
- a ordem de desempate atual vem do SQL, não do frontend.

Desempates atuais: `a confirmar` em detalhe fino no estado final consolidado, porque houve reescritas em patches.

## 17. Regras de partidas, resultados e status

Tabela central: `matches`.

Campos observados:

- identificação do jogo;
- número da partida;
- fase;
- grupo;
- data/hora;
- times e códigos;
- placar oficial;
- prorrogação;
- vencedor/quem avança;
- status;
- informações de provedor/API.

Status confirmados no ecossistema:

- `scheduled`
- `completed`
- `cancelled`
- `live` ou equivalentes tratados pela API: `a confirmar` no banco final

## 18. Travas, prazos e validações

Confirmados:

- palpites normais fecham 30 minutos antes do jogo;
- buffs do jogo também respeitam o fechamento do mercado do jogo;
- extras fecham em `bonus_lock_at`;
- admin não pode competir;
- nickname único;
- troca de senha do perfil exige senha atual;
- várias RPCs validam token e permissão admin;
- `match_predictions` só abre depois do fechamento do jogo para palpitar.

## 19. Tabelas do banco e finalidade de cada uma

Confirmadas em [supabase/schema.sql](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\supabase\schema.sql):

- `app_users`
  - usuários, perfil, admin, bloqueio, moedas, flags.
- `app_sessions`
  - sessões/autenticação por token.
- `app_settings`
  - configurações do sistema, incluindo lock dos extras e status da API.
- `matches`
  - calendário e resultados oficiais.
- `predictions`
  - palpites normais por jogo.
- `match_buffs`
  - buffs usados por usuário em cada jogo.
- `bonus_predictions`
  - palpites extras do torneio.
- `chat_messages`
  - mensagens do chat, se ainda estiver em uso.
- `admin_audit_log`
  - trilha de auditoria administrativa, criada em patch.

## 20. Policies, functions, triggers, views e patches SQL importantes

### Triggers confirmados

- `trg_app_users_updated_at`
- `trg_matches_updated_at`
- `trg_predictions_updated_at`

### RLS confirmado

As tabelas principais têm RLS habilitado:

- `app_users`
- `matches`
- `predictions`
- `match_buffs`
- `bonus_predictions`
- `chat_messages`
- `app_settings`

### Policies confirmadas no schema base

- políticas de leitura pública para as tabelas principais.

Observação importante:

- o projeto depende bastante de RPCs `security definer`, então a leitura pública convive com funções SQL protegidas por token e validação de admin.

### Functions importantes confirmadas

- `app_hash_password`
- `app_get_user_by_token`
- `app_register_user`
- `app_login_user`
- `app_logout_user`
- `app_save_prediction`
- `app_save_bonus_prediction`
- `app_get_match_buffs`
- `app_apply_match_buff`
- `app_cancel_match_buff`
- `app_send_chat_message`
- `app_prediction_exact_hit`
- `app_prediction_result_hit`
- `app_prediction_points`
- `app_prediction_score_context`
- `app_get_leaderboard`
- `app_get_user_history`
- `app_get_match_predictions`
- `app_get_current_user_mission_progress`
- `app_update_current_user_profile`
- `app_update_current_user_state`
- `app_admin_list_users`
- `app_admin_update_user`
- `app_admin_delete_user`
- `app_admin_set_user_prediction`
- `app_admin_set_user_bonus_prediction`
- `app_admin_set_user_buff`
- `app_admin_remove_user_buff`
- `app_admin_set_user_coins`
- `app_admin_adjust_user_coins`
- `app_admin_set_match_result`
- `app_admin_clear_match_result`
- `app_admin_get_audit_log`
- `app_admin_set_api_sync_status`
- `app_admin_set_bonus_results`
- `app_settle_pending_coin_bets`

Views materializadas ou SQL views: `a confirmar`.
Não foram confirmadas views explícitas na leitura já feita.

### Patches mais importantes

- `patch-010-admin-account.sql`
- `patch-011-admin-audit.sql`
- `patch-015-api-sync-status.sql`
- `patch-023-fix-profile-update-ambiguity.sql`
- `patch-026-match-predictions-viewer.sql`
- `patch-029-new-scoring-system.sql`
- `patch-030-zebra-multiplier.sql`
- `patch-031-fix-mission-progress-columns.sql`

## 21. APIs, serviços e integrações

### Supabase

Principal backend do sistema.

### TheSportsDB

Integracao externa que ja foi usada como apoio para puxar resultados oficiais, mas esta desativada no estado atual. A fonte principal de resultado correto agora e o lancamento manual pelo ADMIN.

### Vercel Function

[api/the-sports-sync.js](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\api\the-sports-sync.js) faz:

- atualmente responde que a sincronizacao por API esta desativada;
- nao consulta a TheSportsDB;
- nao grava resultados no Supabase;
- nao altera ranking, pontuacao, palpites ou historico;
- deve ser reativada somente com revisao cuidadosa do provedor/API, do pareamento e da protecao contra sobrescrever resultado manual.

### GitHub Actions

Workflow em [.github/workflows/sync-results.yml](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\.github\workflows\sync-results.yml) esta desativado como automacao. Ele nao agenda chamadas automaticas e, quando rodado manualmente, apenas registra no log que a API esta desativada.

## 22. Padrões visuais

Padrões confirmados visualmente no código:

- interface escura;
- textura pontilhada no fundo;
- estética de cards metálicos/brilhantes;
- tabs com aparência de botões;
- ranking com destaque visual forte para topo e parte de baixo;
- foco grande em visual “gameificado”;
- design responsivo com bastante ajuste manual no próprio HTML/CSS.

## 23. Decisões técnicas existentes

Decisões confirmadas:

- concentrar o frontend principal em um único arquivo `design-lab.html`;
- deixar a lógica de negócio sensível no Supabase;
- usar RPCs em vez de backend REST próprio tradicional;
- usar TheSportsDB como apoio automático;
- manter admin como fallback oficial para resultados;
- usar GitHub Actions para disparar a sincronização automática;
- manter um conjunto legado em `public/js`, mas não como fonte principal.

## 24. Pontos sensíveis que não devem ser alterados sem cuidado

- nomes das RPCs do Supabase, porque o frontend chama várias diretamente;
- lógica de `app_prediction_score_context`, porque ela afeta ranking, histórico, buffs e missões;
- regras do patch 029, porque elas redefinem o sistema atual do bolão;
- status e resultado oficial das partidas;
- `bonus_lock_at` e travas de prazo;
- diferenciação entre usuário comum e admin;
- payload de sincronização da API e credenciais da Vercel;
- qualquer mudança estrutural no `design-lab.html`, porque ele concentra muita responsabilidade.

## 25. Problemas conhecidos

Confirmados ou fortemente indicados pelos arquivos:

- o [README.md](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\README.md) parece desatualizado;
- existem trechos com problemas de encoding/mojibake em documentação e arquivos antigos;
- coexistem uma arquitetura antiga modular e uma arquitetura atual monolítica;
- isso aumenta risco de confusão sobre qual é a fonte real de verdade;
- algumas funções do schema base foram substituídas por patches posteriores;
- por isso, nunca assumir que `schema.sql` sozinho representa o estado final.

## 26. Próximos passos recomendados

- consolidar documentação atualizada do projeto;
- mapear exatamente quais patches são obrigatórios no estado final de produção;
- validar se todos os arquivos legados em `public/js` ainda precisam existir;
- documentar melhor o fluxo de deploy e variáveis;
- considerar separar no futuro partes críticas do `design-lab.html`, se isso for feito com muito cuidado;
- revisar encoding dos textos.

## 27. Histórico resumido das últimas alterações

Baseado nos últimos commits lidos:

- destaque de palpites por resultado no modal;
- correção do pareamento de resultados da API;
- destaque de acertos na lista de palpites por jogo;
- ajuste para não fingir que extras locais foram salvos;
- correção de status padrão no lançamento manual de resultados;
- refinamento visual do pódio e da parte de baixo do ranking;
- endurecimento do cron da API;
- correção do buff de aposta de moedas com saldo 1.
- desativacao segura da sincronizacao por API para que os resultados manuais do ADMIN sejam a fonte principal.
- ampliacao de fotos enviadas por usuarios na aba Ranking via modal visual.
- ajuste do modal de fotos do ranking para exibir imagem bem maior, mantendo proporcao.
- correcao manual no Supabase em producao:
  - `jogo-20` AUT x JOR: `starts_at = 2026-06-17T04:00:00.000Z`;
  - `jogo-36` TUN x JPN: `starts_at = 2026-06-21T04:00:00.000Z`;
  - motivo: estavam com um dia a menos e fechavam palpites antes da hora correta.

## 28. Lista dos arquivos mais importantes e função de cada um

- [design-lab.html](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\design-lab.html)
  - aplicação principal atual.
- [index.html](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\index.html)
  - redireciona para a aplicação principal.
- [package.json](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\package.json)
  - scripts de build e teste.
- [vercel.json](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\vercel.json)
  - configuração de deploy e segurança.
- [api/the-sports-sync.js](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\api\the-sports-sync.js)
  - rota de sincronizacao por API atualmente desativada; nao deve gravar resultados.
- [api/quick-switch-user.js](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\api\quick-switch-user.js)
  - troca rapida protegida entre `LORDEWEL` e `ADMIN`, validando a sessao atual antes de autenticar o perfil destino.
- [scripts/build-vercel.mjs](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\scripts\build-vercel.mjs)
  - gera a pasta `dist`.
- [supabase/schema.sql](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\supabase\schema.sql)
  - base das tabelas e funções iniciais.
- [supabase/patch-029-new-scoring-system.sql](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\supabase\patch-029-new-scoring-system.sql)
  - regra de pontuação atual.
- [supabase/patch-030-zebra-multiplier.sql](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\supabase\patch-030-zebra-multiplier.sql)
  - regra atual da zebra/extras.
- [supabase/patch-031-fix-mission-progress-columns.sql](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\supabase\patch-031-fix-mission-progress-columns.sql)
  - conserto de missão/moedas após mudança de regra.
- [.github/workflows/sync-results.yml](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\.github\workflows\sync-results.yml)
  - workflow manual/no-op; nao agenda sincronizacao automatica.
- [README.md](C:\Users\dunor\OneDrive\Área de Trabalho\PROGRAMAÇÃO\bolao-copa2026\README.md)
  - documentação histórica, possivelmente desatualizada.

## 29. Instruções obrigatórias para próximas sessões do Codex

- Antes de alterar qualquer regra, identificar se a fonte de verdade está no frontend, no `schema.sql` ou em algum patch posterior.
- Não confiar no `README.md` como documentação final sem validar no código atual.
- Assumir que o frontend principal é `design-lab.html`, salvo prova em contrário.
- Sempre revisar os patches do Supabase relacionados ao tema antes de mexer em lógica de negócio.
- Em mudanças de ranking, pontuação, buffs, missões ou histórico, revisar obrigatoriamente:
  - `app_prediction_score_context`
  - `app_get_leaderboard`
  - `app_get_user_history`
  - `app_get_current_user_mission_progress`
- Em mudanças de resultados oficiais, revisar:
  - `app_admin_set_match_result`
  - `app_admin_clear_match_result`
  - `api/the-sports-sync.js`
  - workflow do GitHub Actions
- Em mudanças visuais, validar desktop e mobile.
- Em mudanças administrativas, validar que a conta admin continua fora do bolão competitivo.
- Em qualquer sessão nova, começar com:
  - `git status`
  - leitura dos últimos commits
  - leitura do `AGENTS.md`
- Quando algo não estiver claramente confirmado nos arquivos, marcar como `a confirmar` em vez de assumir.

## 30. Regras obrigatórias para o Codex

- Sempre ler o `AGENTS.md` antes de iniciar qualquer tarefa.
- Sempre rodar `git status` antes de alterar arquivos.
- Sempre analisar commits recentes ao iniciar uma nova sessão ou quando o usuário estiver usando outro PC.
- Não alterar regras de pontuação, ranking, palpites, banco de dados, autenticação, permissões, Supabase ou deploy sem explicar o impacto antes.
- Antes de alterar muitos arquivos, apresentar um plano curto.
- Ao terminar qualquer tarefa, atualizar o `AGENTS.md`.
- Toda alteração feita deve ser registrada no `AGENTS.md`, explicando:
  - o que foi alterado;
  - por que foi alterado;
  - quais arquivos foram modificados;
  - qual impacto a mudança tem no bolão;
  - se afeta pontuação, ranking, palpites, usuários, Supabase, API, visual, Vercel ou GitHub;
  - quais testes ou verificações foram feitos;
  - quais pendências ficaram.
- Antes de qualquer commit, verificar se o `AGENTS.md` foi atualizado.
- Se o usuário pedir para commitar ou subir para o GitHub, primeiro conferir se o `AGENTS.md` está atualizado.
- Se o `AGENTS.md` não estiver atualizado, atualizá-lo antes do commit.
- Nunca fazer commit ou push sem incluir no `AGENTS.md` um resumo fiel das mudanças da sessão.
- Não apagar contexto antigo importante; quando necessário, resumir e mover para uma seção de histórico.
- Se houver dúvida sobre alguma regra do bolão, perguntar antes de alterar.

## 31. Trava de commit do AGENTS.md

O projeto possui uma trava versionada em `.githooks/pre-commit`.

Objetivo:

- impedir commit se `AGENTS.md` não existir;
- impedir commit quando houver arquivos staged do projeto sem `AGENTS.md` staged junto;
- permitir commit quando somente `AGENTS.md` estiver staged;
- orientar explicitamente a atualizar o `AGENTS.md` antes do commit.

### Como ativar em um PC novo

Comando direto:

```bash
git config core.hooksPath .githooks
```

Script auxiliar deste projeto:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-githooks.ps1
```

### Regra operacional

Antes de qualquer commit:

1. atualizar o `AGENTS.md`;
2. rodar `git add AGENTS.md`;
3. confirmar que a trava está ativa neste PC.

## 32. Registro de mudanças do AGENTS.md

### Sessao 2026-06-30 - fundo preto aplicado no poster

- O que foi alterado:
  - o fundo do `body` e do `html` foi reduzido para preto solido;
  - a textura pontilhada preta passou a ser aplicada diretamente no `.poster`, que acompanha todo o conteudo visivel da pagina;
  - o uso de `background-attachment: fixed` foi removido do fundo para evitar diferenca de tonalidade entre topo e fim em navegadores mobile.
  - a textura foi movida para uma camada fixa de viewport e teve a opacidade reduzida para manter a pagina preta de forma uniforme.
  - a textura teve a intensidade visual restaurada para as bolinhas voltarem a aparecer;
  - a logo do topo passou a renderizar um `26` atras da taca para manter a numeracao visivel sobre fundo escuro.
  - o `26` manual foi removido depois que a numeracao original da logo voltou a aparecer corretamente.
  - a textura foi reequilibrada para manter as bolinhas visiveis sem deixar o fundo geral acinzentado;
  - a logo original recebeu reforco de sombra/recorte sem adicionar numeracao manual.
  - depois de validacao visual pelo usuario, o CSS global de fundo foi revertido ao estado anterior as edicoes de fundo, incluindo variaveis `#0c0c0e`, textura original, camada diagonal e brilho radial do `.poster::before`;
  - o reforco de sombra da logo tambem foi removido, voltando ao filtro anterior.
  - o card visual `Edicao especial entre amigos` foi removido do topo;
  - a frase passou a aparecer como texto puro em duas linhas abaixo de `Bolao Copa`: `EDICAO ESPECIAL` e `ENTRE AMIGOS`, com largura alinhada ao titulo.
  - a frase foi ajustada para uma unica linha pequena, `EDICAO ESPECIAL ENTRE AMIGOS`, logo abaixo de `Bolao Copa`.
  - a frase foi movida para dentro do bloco do titulo, ficando diretamente abaixo das palavras `Bolao Copa` e antes da logo.
  - os tres cards de estatisticas do topo (`Posicao`, `Pontos` e `Moedas`) passaram a usar preenchimento com textura verde escuro.
  - o tom dos cards verdes do topo foi fechado para reduzir o destaque visual.
- Por que foi alterado:
  - corrigir a diferenca visual em que o topo da pagina aparecia mais acinzentado e o fim mais escuro.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao apenas visual global do fundo;
  - nao altera saldos, historico, pontuacao, ranking, palpites, usuarios, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/fundo: afetado em todas as abas.
- Testes ou verificacoes feitos:
  - `git status`;
  - leitura dos commits recentes;
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar no celular apos publicacao usando URL com cache bust.

### Sessao 2026-06-30 - resumo no card amarelo do topo

- O que foi alterado:
  - o fundo global do site foi padronizado para preto sem gradiente vertical, mantendo a textura pontilhada;
  - a luz radial do topo do `poster` foi removida para evitar diferenca de tonalidade entre topo e fim da pagina;
  - a camada diagonal clara da textura global foi removida, mantendo apenas os pontos em opacidade menor.
  - a textura do fundo passou a ser aplicada diretamente no `body`, sobre `#000`, sem pseudo-elemento, blend ou camada de brilho.
  - o card amarelo superior deixou de exibir apenas moedas;
  - o resumo do participante passou a usar tres cards amarelos separados para `Posicao`, `Pontos` e `Moedas`;
  - cada coluna amarela passou a ter dois mini-cards empilhados, um para o rotulo e outro para o numero, com separacao visual entre eles;
  - o icone de moeda de fundo foi removido;
  - os numeros foram mantidos em negrito com sombra e distribuidos nas tres estatisticas;
  - o titulo `Bolao Copa` com a logo foi movido para aparecer acima dos cards do topo.
  - o card verde `Edicao especial entre amigos` passou a ficar logo abaixo do titulo, em largura total, com menor altura, fonte ajustada e maior espacamento entre letras.
  - os mini-cards de rotulo/numero e o card de titulo passaram para o visual preto metalico dos cards de palpite;
  - os numeros das estatisticas do topo foram aumentados.
  - no mobile, a linha dos tres cards e do login passou a usar grid responsivo para evitar corte do botao de login.
- Por que foi alterado:
  - concentrar no topo os principais dados do participante sem aumentar a area ocupada.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao apenas visual;
  - nao altera saldos, historico, pontuacao, ranking, palpites, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/topo/ranking/moedas: afetado.
- Testes ou verificacoes feitos:
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - publicar somente se autorizado.

### Sessao 2026-06-30 - ajuste retroativo do historico de moedas legado

- O que foi alterado:
  - o historico local de moedas passou a registrar um ajuste legado de `-2` moedas para `LORDEWEL`, `Carneiro` e `tDniels`;
  - o ajuste representa debitos antigos de buffs removidos pela migracao de regras, sem detalhe original recuperavel em `match_buffs`;
  - o saldo real do usuario `LORDEWEL` foi definido para `7` moedas via RPC administrativa, refletindo o debito de `-4` do buff `palpite-duplo` aplicado pelo ADMIN no jogo 76, Brasil x Japao.
- Por que foi alterado:
  - eliminar a diferenca generica entre historico reconstruido e saldo atual;
  - manter o historico transparente sobre o debito legado que ja afetava o saldo, mas perdeu a linha original na migracao;
  - corrigir o saldo real do `LORDEWEL`, que nao havia sido debitado quando o ADMIN aplicou o buff.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - afeta a exibicao local do historico de moedas;
  - afeta o saldo real do `LORDEWEL` no Supabase, de `11` para `7` moedas;
  - nao altera pontuacao, ranking, palpites, resultados oficiais, Vercel ou GitHub.
- Areas afetadas:
  - moedas/historico: afetado;
  - Supabase/usuarios: saldo do `LORDEWEL` ajustado via ADMIN;
  - visual local: historico passa a explicar o debito legado.
- Testes ou verificacoes feitos:
  - `git status`;
  - leitura dos commits recentes;
  - consulta via Supabase REST/RPC para auditar `LORDEWEL`, `Carneiro` e `tDniels`;
  - verificacao de que os tres fecharam com diferenca `0` entre saldo atual e historico reconstruido apos o ajuste legado.
- Pendencias:
  - aplicar no Supabase, em momento autorizado, o patch definitivo para futuros buffs do ADMIN debitarem/devolverem moedas automaticamente.

### Sessao 2026-06-30 - mercado fechado e debito admin de buffs

- O que foi alterado:
  - no historico local de moedas, apostas de moeda com mercado fechado e ainda sem settlement passaram a entrar no card do jogo como `Aposta` com `Retorno: pendente`;
  - criado o patch SQL `supabase/patch-037-admin-buff-coins.sql` para fazer buffs aplicados manualmente pelo ADMIN debitarem moedas quando criados e devolverem moedas quando removidos;
  - o patch SQL tambem registra no payload da auditoria o custo/devolucao e saldo apos a operacao.
- Por que foi alterado:
  - considerar moedas retidas em jogos cujo mercado ja fechou;
  - evitar que futuros buffs adicionados pelo ADMIN fiquem sem debitar o saldo do usuario.
- Arquivos modificados:
  - `design-lab.html`
  - `supabase/patch-037-admin-buff-coins.sql`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao local no historico de moedas;
  - patch de Supabase criado, mas ainda nao aplicado no banco;
  - se aplicado no Supabase, afeta futuras aplicacoes/remocoes manuais de buffs pelo ADMIN, debitando/devolvendo moedas.
- Areas afetadas:
  - visual/moedas/historico: afetado localmente;
  - Supabase/admin/buffs/moedas: patch criado, pendente de aplicacao.
- Testes ou verificacoes feitos:
  - `git diff --check`;
  - `npm.cmd run build`;
  - consulta read-only para recalcular categorias de moedas do LORDEWEL.
- Pendencias:
  - decidir se o historico deve refletir saldo real atual ou saldo esperado com debitos administrativos retroativos;
  - aplicar o patch SQL no Supabase apenas com autorizacao explicita.

### Sessao 2026-06-30 - data de buffs no historico pela hora do jogo

- O que foi alterado:
  - no historico de moedas, buffs que nao sao aposta de moeda passaram a usar como data da movimentacao o dia do jogo, com horario de 1 hora antes do inicio;
  - isso faz os buffs fechados aparecerem no historico cronologico do jogo correspondente, incluindo os casos de LORDEWEL nos jogos 17 e 31.
- Por que foi alterado:
  - refletir no historico os gastos de buffs que estavam registrados no jogo, mas precisavam aparecer na linha cronologica correta para conferencia de saldo.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao visual/local no historico de moedas;
  - nao altera saldos gravados, regras, pontuacao, ranking, palpites, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/moedas/historico: afetado.
- Testes ou verificacoes feitos:
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no navegador local antes de publicar.

### Sessao 2026-06-30 - ajuste do card edicao especial

- O que foi alterado:
  - o texto do card `Edicao especial entre amigos` foi aumentado;
  - a quebra foi controlada em duas linhas equilibradas;
  - o texto passou a ocupar melhor o card sem cortar palavras.
- Por que foi alterado:
  - melhorar o preenchimento visual do card central do topo.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao apenas visual/local no topo da interface;
  - nao altera saldos, regras, pontuacao, ranking, palpites, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/topo: afetado.
- Testes ou verificacoes feitos:
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no navegador local antes de publicar.

### Sessao 2026-06-30 - centralizacao do saldo no card de moedas

- O que foi alterado:
  - o numero do card de moedas superior foi centralizado horizontal e verticalmente em relacao ao card;
  - o numero foi aumentado novamente;
  - a palavra `Moedas` foi fixada na parte inferior do card.
- Por que foi alterado:
  - melhorar o enquadramento visual do saldo no card superior.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao apenas visual/local no topo da interface;
  - nao altera saldos, regras, pontuacao, ranking, palpites, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/moedas/topo: afetado.
- Testes ou verificacoes feitos:
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no navegador local antes de publicar.

### Sessao 2026-06-30 - numero do card de moedas 30 por cento maior

- O que foi alterado:
  - o numero do card de moedas superior foi aumentado em cerca de 30%;
  - o numero foi centralizado no card;
  - o tamanho responsivo no mobile tambem foi ajustado na mesma proporcao.
- Por que foi alterado:
  - dar mais destaque ao saldo de moedas no topo.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao apenas visual/local no topo da interface;
  - nao altera saldos, regras, pontuacao, ranking, palpites, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/moedas/topo: afetado.
- Testes ou verificacoes feitos:
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no navegador local antes de publicar.

### Sessao 2026-06-30 - refinamento do numero no card de moedas do topo

- O que foi alterado:
  - o numero de moedas no card superior ficou maior;
  - a palavra `Moedas` foi deslocada mais para baixo;
  - o ajuste responsivo do tamanho do numero tambem foi ampliado.
- Por que foi alterado:
  - melhorar a hierarquia visual do saldo de moedas.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao apenas visual/local no topo da interface;
  - nao altera saldos, regras, pontuacao, ranking, palpites, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/moedas/topo: afetado.
- Testes ou verificacoes feitos:
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no navegador local antes de publicar.

### Sessao 2026-06-30 - card de moedas do topo com icone grande

- O que foi alterado:
  - o card de moedas do topo passou a usar o icone de moeda preenchendo o fundo do card com 80% de opacidade;
  - o numero de moedas ficou maior e sobreposto ao icone;
  - a palavra `Moedas` ficou abaixo do numero em tamanho menor;
  - ajustes responsivos foram feitos para nao reduzir o numero no mobile.
- Por que foi alterado:
  - dar mais destaque visual ao saldo de moedas do usuario no topo da tela.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao apenas visual/local no topo da interface;
  - nao altera saldos, regras, pontuacao, ranking, palpites, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/moedas/topo: afetado.
- Testes ou verificacoes feitos:
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no navegador local antes de publicar.

### Sessao 2026-06-30 - destaque do titulo historico de moedas

- O que foi alterado:
  - o titulo `Historico de moedas` ficou maior;
  - passou a usar vermelho sem transparencia;
  - foi deslocado uma linha abaixo da posicao anterior.
- Por que foi alterado:
  - aumentar o destaque visual da divisao entre missoes e historico.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao apenas visual/local na aba Moedas;
  - nao altera saldos, regras, pontuacao, ranking, palpites, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/moedas: afetado.
- Testes ou verificacoes feitos:
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no navegador local antes de publicar.

### Sessao 2026-06-30 - ajuste visual e ordenacao das missoes

- O que foi alterado:
  - na aba Moedas, a linha de acoes das missoes passou a usar proporcao aproximada de 20% para o progresso e 80% para o botao de resgate;
  - as missoes sao reordenadas para mostrar primeiro as nao resgatadas, priorizando as mais proximas de completar;
  - missoes ja resgatadas aparecem abaixo e com 50% de transparencia;
  - nos botoes de missoes resgatadas, a quantidade de moedas aparece antes de `Resgatado`.
- Por que foi alterado:
  - melhorar a leitura e priorizar as missoes ainda acionaveis pelo usuario.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao visual/local na aba Moedas;
  - nao altera saldos, regras, pontuacao, ranking, palpites, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/moedas/missoes: afetado.
- Testes ou verificacoes feitos:
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no navegador local antes de publicar.

### Sessao 2026-06-30 - cards expansivos no historico de moedas

- O que foi alterado:
  - os cards do historico de moedas passaram a iniciar recolhidos;
  - por padrao exibem apenas titulo e saldo do card;
  - uma seta clicavel expande o card para mostrar data, detalhamento e saldo parcial;
  - a seta muda de orientacao quando o card esta aberto.
- Por que foi alterado:
  - reduzir a poluicao visual do historico mantendo o detalhamento disponivel sob demanda.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao apenas visual/local no historico de moedas;
  - nao altera saldos gravados, regras, pontuacao, ranking, palpites, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/moedas: afetado.
- Testes ou verificacoes feitos:
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no navegador local antes de publicar.

### Sessao 2026-06-30 - visual das moedas em espera por linha

- O que foi alterado:
  - no card `Moedas em espera`, cada jogo passou a ocupar uma linha dentro do mesmo card;
  - as siglas dos jogos pendentes usam fonte cinza com transparencia;
  - os detalhes de jogos pendentes passaram a exibir bolinhas de bandeiras ao lado das siglas, no mesmo padrao dos titulos dos cards de jogos.
- Por que foi alterado:
  - melhorar a leitura das moedas pendentes sem poluir o card com detalhes de buff/aposta.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao apenas visual/local no historico de moedas;
  - nao altera saldos gravados, regras, pontuacao, ranking, palpites, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/moedas: afetado.
- Testes ou verificacoes feitos:
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no navegador local antes de publicar.

### Sessao 2026-06-30 - rotulos curtos de buffs no historico de moedas

- O que foi alterado:
  - no historico de moedas, os buffs passaram a usar rotulos curtos:
    - `Dobrou`;
    - `Proteger`;
    - `Anular`;
    - `Meiar`;
  - o buff de aposta de moeda permanece como aposta.
- Por que foi alterado:
  - reduzir o tamanho dos detalhes dentro dos cards do historico de moedas.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao apenas visual/local no historico de moedas;
  - nao altera saldos, regras, pontuacao, ranking, palpites, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/moedas: afetado.
- Testes ou verificacoes feitos:
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no navegador local antes de publicar.

### Sessao 2026-06-30 - alinhamento das bandeiras no titulo de moedas

- O que foi alterado:
  - nos titulos dos cards de jogos do historico de moedas, a bandeira do time da casa passou a ficar a direita da sigla;
  - a bandeira do visitante permanece antes da sigla;
  - o separador do confronto usa `x` minusculo.
- Por que foi alterado:
  - alinhar o titulo ao formato visual esperado `AAA bandeira x bandeira BBB`.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao apenas visual/local no historico de moedas;
  - nao altera saldos, regras, pontuacao, ranking, palpites, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/moedas: afetado.
- Testes ou verificacoes feitos:
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no navegador local antes de publicar.

### Sessao 2026-06-30 - titulos com siglas e bandeiras no historico de moedas

- O que foi alterado:
  - os cards de jogos no historico de moedas passaram a usar o titulo `Moedas em AAA x BBB`;
  - `AAA` e `BBB` sao as siglas das selecoes;
  - cada sigla exibe ao lado uma bolinha com a bandeira da selecao, em tamanho reduzido e alinhado na mesma linha.
- Por que foi alterado:
  - melhorar a identificacao visual dos jogos no historico de moedas sem usar nomes longos.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao apenas visual/local no historico de moedas;
  - nao altera saldos, regras, pontuacao, ranking, palpites, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/moedas: afetado.
- Testes ou verificacoes feitos:
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no navegador local antes de publicar.

### Sessao 2026-06-30 - moedas em espera resumidas por jogo

- O que foi alterado:
  - o card `Moedas em espera` deixou de detalhar tipo de aposta ou buff;
  - agora ele agrupa por jogo e mostra apenas o confronto e a quantidade total de moedas pendentes naquele jogo;
  - o saldo do card e o saldo parcial geral foram mantidos.
- Por que foi alterado:
  - simplificar a leitura das moedas ainda pendentes em jogos futuros.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao apenas visual/local no historico de moedas;
  - nao altera saldos gravados, regras, pontuacao, ranking, palpites, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/moedas: afetado.
- Testes ou verificacoes feitos:
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no navegador local antes de publicar.

### Sessao 2026-06-30 - moedas em espera no historico

- O que foi alterado:
  - o historico de moedas passou a exibir ao final um card `Moedas em espera`;
  - esse card lista jogos futuros com mercado ainda aberto em que o usuario tem moedas aplicadas em buff ou aposta;
  - cada detalhe mostra o confronto e o valor pendente;
  - o saldo do card e o saldo parcial consideram essas moedas em espera e mudam conforme o usuario aplica ou remove moedas nesses jogos.
- Por que foi alterado:
  - separar movimentacoes efetivadas de moedas ainda reversiveis em jogos futuros.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao visual/local no historico de moedas;
  - nao altera saldos gravados, regras, pontuacao, ranking, palpites, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/moedas: afetado.
- Testes ou verificacoes feitos:
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no navegador local antes de publicar.

### Sessao 2026-06-30 - titulo de jogo simplificado no historico de moedas

- O que foi alterado:
  - os cards de jogos no historico de moedas passaram a usar apenas o titulo `A x B`, sem o prefixo `Moedas em`.
- Por que foi alterado:
  - deixar o historico mais limpo visualmente.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao apenas visual/local no historico de moedas;
  - nao altera saldos, regras, pontuacao, ranking, palpites, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/moedas: afetado.
- Testes ou verificacoes feitos:
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no navegador local antes de publicar.

### Sessao 2026-06-30 - titulos resumidos no historico de moedas

- O que foi alterado:
  - o card de missoes no historico de moedas passou a usar o titulo `Missoes resgatadas`;
  - os cards de jogos passaram a usar o formato `Moedas em A x B`.
- Por que foi alterado:
  - deixar os titulos do historico de moedas mais curtos e legiveis.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao apenas visual/local no historico de moedas;
  - nao altera saldos, regras, pontuacao, ranking, palpites, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/moedas: afetado.
- Testes ou verificacoes feitos:
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no navegador local antes de publicar.

### Sessao 2026-06-30 - saldo parcial no historico de moedas

- O que foi alterado:
  - cada card do historico de moedas passou a exibir abaixo do saldo do card a linha `S. Parcial: X 🪙`;
  - o saldo parcial e calculado cronologicamente conforme a ordem dos cards;
  - o texto do saldo parcial usa fonte menor e cinza com 50% de transparencia.
- Por que foi alterado:
  - facilitar a conferencia do saldo acumulado ao longo do historico.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao apenas visual/local no historico de moedas;
  - nao altera saldos, regras, pontuacao, ranking, palpites, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/moedas: afetado.
- Testes ou verificacoes feitos:
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no navegador local antes de publicar.

### Sessao 2026-06-30 - historico de moedas agrupado por jogo

- O que foi alterado:
  - no historico de moedas, gastos e retornos de moedas ligados a jogos passaram a ser agrupados em um unico card por confronto;
  - o titulo do card usa o formato `Moedas no jogo A x B`;
  - a data permanece abaixo do titulo, sem incluir o texto de resultado da aposta;
  - cada card detalha apostas, retornos e buffs daquele jogo, com o saldo final do jogo exibido a direita.
- Por que foi alterado:
  - facilitar a conferencia das movimentacoes de moedas por partida.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao visual/local no historico de moedas;
  - nao altera saldos, pontuacao, ranking, palpites, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/moedas: afetado.
- Testes ou verificacoes feitos:
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no navegador local antes de publicar.

### Sessao 2026-06-30 - retrospecto sem abreviacao no ranking

- O que foi alterado:
  - removida a abreviacao `aproveit.` do ranking;
  - o ranking passou a mostrar somente os numeros do retrospecto no formato `placar exato - vencedor/empate - erro`;
  - a publicacao foi feita isoladamente por uma worktree limpa para nao incluir alteracoes locais de historico de moedas.
- Por que foi alterado:
  - deixar a linha do ranking mais limpa e direta no celular.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao apenas visual no ranking;
  - nao altera pontuacao, regras, palpites, usuarios, Supabase, API, moedas ou GitHub.
- Areas afetadas:
  - visual/ranking: afetado;
  - Vercel: publicado somente este ajuste visual.
- Testes ou verificacoes feitos:
  - `git status`;
  - leitura do `AGENTS.md`;
  - leitura dos commits recentes;
  - validacao na worktree limpa com `node --check` do JavaScript embutido;
  - `git diff --check`;
  - `npm.cmd run build`;
  - deploy de producao na Vercel para `bolao-copa2026`;
  - verificacao do HTML publicado confirmando ausencia de `aproveit.`.
- Pendencias:
  - nenhuma para este ajuste;
  - alteracoes locais de historico de moedas continuam nao publicadas.

### Sessao 2026-06-29 - botao ver do ranking no apelido

- O que foi alterado:
  - no ranking, o selo/botao `ver` saiu da coluna de pontos e passou a aparecer antes do apelido do participante;
  - a coluna de pontos ficou sem o selo sobreposto, evitando cobrir a pontuacao no celular;
  - o botao `ver` usa o mesmo detalhamento de pontos ja existente.
- Por que foi alterado:
  - corrigir sobreposicao visual no mobile em que o `VER` tampava os pontos.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao visual no ranking;
  - nao altera pontuacao, ranking real, moedas, historico de moedas, palpites, usuarios, Supabase, API ou GitHub.
- Areas afetadas:
  - visual/ranking: afetado;
  - Vercel: publicado em producao somente com este ajuste visual;
  - historico de moedas: nao publicado nesta alteracao.
- Testes ou verificacoes feitos:
  - worktree temporaria limpa baseada em `HEAD` para publicar somente este ajuste;
  - verificacao de sintaxe do JavaScript embutido como modulo ESM;
  - `git diff --check`;
  - `npm.cmd run build`;
  - validacao mobile local em `127.0.0.1:4174`;
  - deploy de producao no projeto correto `bolao-copa2026`;
  - validacao mobile em `https://bolao-copa2026-alpha.vercel.app/design-lab.html`, confirmando `overlap: false` entre `ver` e pontos.
- Pendencias:
  - nenhuma para o ajuste visual publicado;
  - as alteracoes locais de historico de moedas continuam nao publicadas.

### Sessao 2026-06-29 - aposta e ganho de moeda no mesmo card

- O que foi alterado:
  - no historico de moedas, a movimentacao de `Aposta de moeda` passou a reunir no mesmo card o gasto da aposta e o ganho liquidado do mesmo jogo;
  - o card mostra o valor liquido no lado direito e detalha internamente `Aposta: -X` e `Ganho: +Y` ou `Ganho: pendente`;
  - a exibicao separada `Ganho da aposta de moeda` deixou de ser criada como um segundo card.
- Por que foi alterado:
  - facilitar a conferencia visual de cada aposta de moeda por jogo.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao apenas visual/organizacional no historico de moedas;
  - nao altera saldo real, ranking, pontuacao, palpites, usuarios, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/moedas: afetado;
  - demais areas: sem alteracao funcional.
- Testes ou verificacoes feitos:
  - `git status`;
  - leitura dos commits recentes;
  - verificacao de sintaxe do JavaScript embutido como modulo ESM;
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no navegador local logado em usuario com aposta de moeda.

### Sessao 2026-06-29 - selecoes no historico de moedas

- O que foi alterado:
  - no historico de moedas, linhas que referenciam `Jogo X` agora tambem mostram as selecoes da partida.
- Por que foi alterado:
  - facilitar a conferencia das movimentacoes de moedas ligadas a buffs e apostas.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao apenas visual/consultiva na aba Moedas;
  - nao altera saldos, pontuacao, regras, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/moedas: afetado.
- Testes ou verificacoes feitos:
  - verificacao de sintaxe do JavaScript embutido como modulo ESM;
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente na previa local.

### Sessao 2026-06-29 - historico pessoal de moedas

- O que foi alterado:
  - a aba Moedas ganhou uma secao `Historico de moedas` abaixo das missoes;
  - o historico e reconstruido retroativamente para o usuario logado com base nos dados efetivos salvos;
  - entram no historico: moedas iniciais, missoes resgatadas, gastos em buffs ativos, apostas de moedas ativas, ganhos de apostas ja liquidadas e ajustes administrativos quando houver auditoria disponivel;
  - buffs/apostas cancelados nao aparecem, porque nao permanecem em `match_buffs`;
  - ganhos de aposta so aparecem quando a aposta esta `settled = true`;
  - quando o saldo atual nao fecha com as transacoes retroativas reconstruiveis, aparece uma linha explicita de reconciliacao `Saldo efetivado sem detalhe retroativo`.
- Por que foi alterado:
  - dar transparencia pessoal sobre entradas e saidas de moedas sem criar transacoes falsas para eventos que nao possuem timestamp historico salvo.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao visual/consultiva na aba Moedas;
  - nao altera saldo de moedas, missoes, buffs, apostas, usuarios, Supabase, API, Vercel ou GitHub;
  - nao executa liquidacao de apostas, apenas le dados ja salvos.
- Areas afetadas:
  - visual/moedas: afetado;
  - transparencia pessoal: afetado;
  - banco/Supabase: sem patch SQL nesta alteracao.
- Testes ou verificacoes feitos:
  - `git status`;
  - leitura dos commits recentes;
  - revisao dos trechos de missoes, buffs, coin-bet e auditoria admin;
  - consulta read-only de `app_users` para confirmar formato de `mission_claims`;
  - verificacao de sintaxe do JavaScript embutido como modulo ESM;
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente na aba Moedas com usuarios reais apos deploy.

### Sessao 2026-06-29 - liberar detalhamento de pontos para todos

- O que foi alterado:
  - o botao `ver` no total de pontos do ranking passou a aparecer para todos os usuarios, nao apenas para ADMIN;
  - usuarios comuns podem abrir o mesmo modal de detalhamento de pontos de qualquer participante;
  - para ADMIN, o modal continua usando a RPC `app_get_user_history`;
  - para usuario comum, o detalhamento e montado por leitura das tabelas publicas `matches`, `predictions`, `match_buffs` e `app_users`, evitando a restricao atual da RPC para `p_user_id` de terceiros.
- Por que foi alterado:
  - dar transparencia para todos conferirem a pontuacao dos participantes no ranking.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - altera a visibilidade do detalhamento de pontos no frontend;
  - nao altera pontuacao, regras, palpites, usuarios, Supabase, API, Vercel ou GitHub;
  - nao muda permissoes no banco, apenas reutiliza leituras ja publicas para montar o modal.
- Areas afetadas:
  - visual/ranking: afetado;
  - transparencia/historico: afetado no frontend;
  - Supabase: sem patch SQL nesta alteracao.
- Testes ou verificacoes feitos:
  - `git status`;
  - leitura dos commits recentes;
  - verificacao de sintaxe do JavaScript embutido como modulo ESM;
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar como usuario comum abrindo o `ver` de outro participante apos deploy.

### Sessao 2026-06-29 - limite de nome real no ranking

- O que foi alterado:
  - o nome real exibido abaixo do apelido no ranking passou a mostrar no maximo dois nomes;
  - quando houver apenas um nome, ele permanece com apenas um nome;
  - a alteracao afeta somente a exibicao no ranking, mantendo o nome completo original nos dados e demais fluxos.
- Por que foi alterado:
  - melhorar o encaixe visual dos cards do ranking.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao apenas visual no ranking;
  - nao altera usuarios, cadastro, pontuacao, regras, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/ranking: afetado.
- Testes ou verificacoes feitos:
  - `git status`;
  - verificacao de sintaxe do JavaScript embutido como modulo ESM;
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - nenhuma.

### Sessao 2026-06-29 - transparencia no detalhamento de extras do ranking

- O que foi alterado:
  - o detalhamento `(Y + Z de Ex.)` no ranking passou a ter 50% de transparencia.
- Por que foi alterado:
  - reduzir o peso visual do detalhamento dos extras em relacao a pontuacao principal.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao apenas visual no ranking;
  - nao altera pontuacao, regras, palpites, usuarios, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/ranking: afetado.
- Testes ou verificacoes feitos:
  - `git status`;
  - verificacao de sintaxe do JavaScript embutido como modulo ESM;
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - nenhuma.

### Sessao 2026-06-29 - extras abaixo da pontuacao e cards com acerto/erro

- O que foi alterado:
  - no ranking, o detalhamento `X (Y + Z de Ex.)` passou a exibir `Y + Z de Ex.` abaixo da pontuacao principal, dentro do mesmo card;
  - o destaque verde de `Z de Ex.` foi mantido;
  - na aba Extras, cards com resultado oficial lançado passam a ficar verdes quando o usuario acertou e vermelhos quando errou;
  - cards sem resultado oficial lancado permanecem no visual normal.
- Por que foi alterado:
  - melhorar a leitura da pontuacao total no ranking e dar feedback visual imediato dos palpites extras ja apurados.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao visual no ranking e na aba Extras;
  - nao altera pontuacao, regras, palpites salvos, usuarios, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/ranking: afetado;
  - visual/extras: afetado;
  - demais areas: sem alteracao funcional.
- Testes ou verificacoes feitos:
  - `git status`;
  - leitura dos commits recentes;
  - verificacao de sintaxe do JavaScript embutido como modulo ESM;
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no ranking e na aba Extras apos deploy.

### Sessao 2026-06-29 - exibicao detalhada de extras no ranking

- O que foi alterado:
  - a pontuacao total no ranking passou a exibir, quando houver extras, o formato `X (Y + Z de Ex.)`;
  - `X` representa o total geral, `Y` representa pontos sem extras e `Z` representa apenas os pontos obtidos em extras;
  - o trecho `Z de Ex.` foi destacado em verde.
- Por que foi alterado:
  - deixar claro quanto da pontuacao total veio dos palpites extras.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao apenas visual no ranking;
  - nao altera pontuacao, ranking real, palpites, usuarios, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/ranking: afetado;
  - demais areas: sem alteracao funcional.
- Testes ou verificacoes feitos:
  - `git status`;
  - leitura dos commits recentes;
  - verificacao de sintaxe do JavaScript embutido como modulo ESM;
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no ranking publicado apos deploy.

### Sessao 2026-06-29 - correcao do ranking apos resultado extra parcial

- O que foi alterado:
  - identificado que salvar `FRANCA/FRANÇA` como melhor campanha da fase de grupos ativou o calculo de extras e quebrou a RPC `app_get_leaderboard`;
  - o erro real vinha de `app_score_bonus_prediction`, que podia retornar literais `integer` em colunas declaradas como `numeric`;
  - criado o patch SQL `patch-036-fix-bonus-score-return-types.sql` para corrigir os casts de retorno da funcao de bonus;
  - o frontend ganhou um fallback de ranking por tabelas publicas quando a RPC `app_get_leaderboard` falhar;
  - o fallback calcula pontos principais, ausencia, buffs principais, extras ja lancados e o novo aproveitamento `exato - resultado - erro`.
- Por que foi alterado:
  - impedir que um resultado extra parcial deixe o ranking principal vazio.
- Arquivos modificados:
  - `design-lab.html`
  - `supabase/patch-036-fix-bonus-score-return-types.sql`
  - `AGENTS.md`
- Impacto no bolao:
  - restaura a exibicao do ranking quando a RPC falhar por erro no calculo de bonus;
  - nao altera dados de usuarios, palpites, resultados oficiais, moedas, buffs, Vercel ou GitHub por si so;
  - a correcao definitiva do banco depende de aplicar o patch SQL no Supabase.
- Areas afetadas:
  - ranking/frontend: afetado com fallback de contingencia;
  - Supabase: patch criado, pendente de aplicacao;
  - pontuacao oficial no banco: sem alteracao ate aplicar o patch.
- Testes ou verificacoes feitos:
  - `git status`;
  - leitura dos commits recentes;
  - consulta read-only de `app_get_bonus_results`, confirmando `best_group_stage_team = FRANÇA`;
  - consulta read-only de `app_get_leaderboard`, confirmando erro SQL `Returned type integer does not match expected type numeric`;
  - verificacao de sintaxe do JavaScript embutido como modulo ESM;
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - aplicar `supabase/patch-036-fix-bonus-score-return-types.sql` no Supabase de producao;
  - depois de aplicar, confirmar que `app_get_leaderboard` volta a responder sem usar fallback.

### Sessao 2026-06-29 - aproveitamento em formato exato-resultado-erro

- O que foi alterado:
  - o aproveitamento deixou de ser exibido como percentual no ranking e passou ao formato `placar exato - vencedor/empate - erro`;
  - jogos encerrados sem palpite passam a contar como erro no aproveitamento;
  - a ordenacao visual do ranking passou a considerar, apos pontos e placares exatos, mais acertos de vencedor/empate e menos erros;
  - a aba Regras foi atualizada para explicar o novo formato de aproveitamento e os criterios de desempate;
  - foi criado o patch SQL `patch-035-leaderboard-record-aproveitamento.sql` para ajustar a RPC `app_get_leaderboard` no Supabase com os novos campos e a nova ordenacao real.
- Por que foi alterado:
  - substituir a regra percentual por um registro de desempenho semelhante ao modelo de vitorias/empates/derrotas da NFL.
- Arquivos modificados:
  - `design-lab.html`
  - `supabase/patch-035-leaderboard-record-aproveitamento.sql`
  - `AGENTS.md`
- Impacto no bolao:
  - afeta a exibicao do aproveitamento no ranking e a regra de desempate relacionada ao aproveitamento;
  - nao altera pontos ja calculados, moedas, buffs, extras, usuarios, autenticacao, API, Vercel ou GitHub;
  - enquanto o patch SQL nao for aplicado no Supabase, o frontend calcula um fallback visual usando `matches`, `predictions` e `app_users`.
- Areas afetadas:
  - ranking: afetado;
  - regras: afetada;
  - Supabase: patch criado, pendente de aplicacao no banco;
  - pontuacao por jogo: sem alteracao.
- Testes ou verificacoes feitos:
  - `git status`;
  - leitura do `AGENTS.md`;
  - leitura dos commits recentes;
  - verificacao localizada da RPC `app_get_leaderboard`;
  - verificacao de sintaxe do JavaScript embutido como modulo ESM;
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - aplicar `supabase/patch-035-leaderboard-record-aproveitamento.sql` no Supabase de producao;
  - validar visualmente o ranking em desktop e celular apos deploy;
  - publicar somente apos revisao/autorizacao do usuario.

### Sessao 2026-06-29 - ranking de inativos por falta de palpite

- O que foi alterado:
  - o ranking principal passou a separar visualmente participantes que estejam entre os 10 ultimos colocados e nao tenham palpite registrado nos ultimos 5 jogos com resultado oficial;
  - esses participantes deixam de aparecer no ranking principal enquanto atenderem ao criterio de inatividade;
  - foi criada uma secao abaixo do ranking principal, com divisoria e titulo `INATIVO, SEM PALPITE NOS ULTIMOS 5 JOGOS`;
  - os cards da secao inativa reutilizam o visual do ranking, mas sem numeracao de posicao e com elementos em cinza;
  - a verificacao e recalculada no carregamento do ranking, entao o participante volta automaticamente ao ranking principal quando tiver palpite em algum dos 5 ultimos jogos com resultado oficial.
- Por que foi alterado:
  - manter o ranking principal focado nos participantes ativos, sem remover o historico visual de quem parou de palpitar.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - afeta somente a exibicao do ranking no frontend;
  - nao altera pontuacao, regras, palpites salvos, usuarios, moedas, buffs, Supabase, SQL, API, Vercel ou GitHub;
  - a RPC `app_get_leaderboard` continua sendo a fonte de pontuacao e ordenacao antes da separacao visual.
- Areas afetadas:
  - visual/ranking: afetado;
  - Supabase: apenas leitura da tabela `predictions` para identificar atividade recente;
  - pontuacao, historico, missoes, API, deploy e GitHub: sem alteracao funcional.
- Testes ou verificacoes feitos:
  - `git status`;
  - leitura do `AGENTS.md`;
  - leitura dos commits recentes;
  - verificacao de sintaxe do JavaScript embutido como modulo ESM;
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no celular e desktop se a secao inativa aparece abaixo do ranking principal quando houver participantes no criterio;
  - publicar somente apos revisao/autorizacao do usuario.

### Sessao 2026-06-29 - mata-mata por resultado do placar

- O que foi alterado:
  - textos da aba `Regras` foram atualizados para trocar `Acertar quem avança` por `Acertar vencedor ou empate (90 min + acréscimos)`;
  - palpites empatados no mata-mata voltaram a poder ser salvos pelos usuarios;
  - a compensacao visual temporaria do frontend passou a considerar acerto de resultado no mata-mata igual a fase de grupos: vitoria da casa, empate ou vitoria do visitante no placar de 90 min + acrescimos;
  - foi criado o patch SQL `patch-034-knockout-result-by-score.sql`, que sobrescreve `app_prediction_result_hit` para usar resultado do placar em todas as fases e tambem ajusta a missao das oitavas para contar `result_hit`.
- Por que foi alterado:
  - a regra desejada para o mata-mata passou a ser igual a fase de grupos no criterio de resultado, mantendo apenas pontuacoes maiores;
  - a trava anterior impedia palpite de empate no mata-mata, o que contrariava a nova regra.
- Arquivos modificados:
  - `design-lab.html`
  - `supabase/patch-034-knockout-result-by-score.sql`
  - `AGENTS.md`
- Impacto no bolao:
  - afeta pontuacao, ranking, historico e missoes de resultado no mata-mata;
  - nao altera resultados oficiais, usuarios, moedas, extras, API, Vercel ou GitHub por si so;
  - ate aplicar o patch SQL no Supabase, a correcao continua sendo compensada visualmente no frontend.
- Areas afetadas:
  - regras/visual: textos ajustados;
  - frontend/palpites: empate liberado no mata-mata;
  - frontend/ranking/historico: compensacao visual ajustada;
  - Supabase/pontuacao: patch criado, pendente de aplicacao no banco.
- Testes ou verificacoes feitos:
  - `git status`;
  - leitura do `AGENTS.md`;
  - leitura dos commits recentes;
  - revisao de trechos relacionados a `app_prediction_result_hit`, compensacao de ranking/historico e salvamento de palpites.
  - verificacao de sintaxe do JavaScript embutido com `node --check` em arquivo temporario;
  - `npm.cmd run build`.
- Pendencias:
  - aplicar `supabase/patch-034-knockout-result-by-score.sql` no Supabase de producao;
  - validar no site publicado um palpite empatado em jogo de mata-mata.

### Sessao 2026-06-28 - correcao de pontuacao do mata-mata

- O que foi alterado:
  - palpites normais de jogos de mata-mata passaram a salvar `winner_team` automaticamente a partir do placar;
  - quando o palpite de mata-mata tem placar empatado, o salvamento e bloqueado porque nao ha seletor manual de quem avanca no fluxo padrao;
  - palpites de mata-mata ja salvos passam a restaurar o campo `winner_team` quando existir no banco;
  - foi criado o patch SQL `patch-033-knockout-winner-fallback.sql` para a funcao `app_prediction_result_hit` aceitar a direcao do placar como fallback em mata-mata quando `winner_team` antigo estiver vazio e o placar oficial nao for empate.
  - como paliativo ate aplicar o SQL no Supabase, o frontend compensa visualmente ranking, historico e detalhamento admin para palpites antigos de mata-mata sem `winner_team`, quando o placar permite inferir o classificado;
  - a compensacao visual considera `palpite-duplo`, `zerar-adversario` e `meia-adversario` quando os dados estao disponiveis no frontend.
- Por que foi alterado:
  - a pontuacao de mata-mata dependia de `winner_team`, mas o frontend salvava palpites normais com `p_winner_team = null`;
  - isso fazia palpites corretos por vencedor/classificado nao pontuarem corretamente.
- Arquivos modificados:
  - `design-lab.html`
  - `supabase/patch-033-knockout-winner-fallback.sql`
  - `AGENTS.md`
- Impacto no bolao:
  - afeta pontuacao, ranking, historico e missoes ligados aos jogos de mata-mata;
  - nao altera regras de fase de grupos;
  - nao altera dados de usuarios, moedas, buffs, API, Vercel ou GitHub por si so;
  - ate aplicar o patch SQL, a correcao fica visual no frontend e a fonte real do banco continua pendente.
- Areas afetadas:
  - frontend/palpites: afetado;
  - Supabase/pontuacao: patch criado, pendente de aplicacao no banco;
  - ranking/historico/missoes: afetados apos aplicacao do patch.
- Testes ou verificacoes feitos:
  - `git status`;
  - leitura dos commits recentes;
  - revisao de `app_prediction_points`, `app_prediction_score_context`, `app_get_leaderboard` e `app_get_user_history`;
  - identificacao de que `savePredictionForFixture` salvava `p_winner_team: null`.
  - verificacao de sintaxe do JavaScript embutido com `node --check` em arquivo temporario;
  - `npm.cmd run build`.
- Pendencias:
  - aplicar `supabase/patch-033-knockout-winner-fallback.sql` no Supabase de producao;
  - validar no ranking/historico apos o deploy do paliativo;
  - validar novamente apos aplicar o patch SQL definitivo.

### Sessao 2026-06-28 - preenchimento visual dos 16 avos

- O que foi alterado:
  - os jogos da fase `16 AVOS DE FINAL` passaram a resolver automaticamente os placeholders `1A`, `2B`, `3ABCDF` e equivalentes usando os resultados oficiais ja salvos na tabela `matches`;
  - os primeiros e segundos colocados sao calculados por pontos, saldo de gols e gols pro;
  - os melhores terceiros seguem a ordem oficial informada/confirmada: `COD`, `SWE`, `GHA`, `ECU/EQU`, `BIH`, `ALG`, `PAR`, `SEN`, usando `EQU` como codigo interno do projeto para Equador;
  - a distribuicao dos terceiros nos confrontos usa a matriz oficial da combinacao atual de terceiros classificados `B/D/E/F/I/J/K/L`;
  - a resolucao acontece apenas em memoria no frontend, antes de renderizar os cards e preencher selects administrativos.
- Por que foi alterado:
  - apos o fim da fase de grupos, os cards do mata-mata ainda exibiam placeholders em vez das selecoes classificadas.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao visual/operacional nos jogos de mata-mata;
  - nao altera pontuacao, ranking, palpites existentes, usuarios, moedas, Supabase, banco de dados, API, Vercel ou GitHub;
  - as opcoes exibidas para palpites/resultados dos 16 avos passam a mostrar as selecoes reais calculadas pelos resultados oficiais.
- Areas afetadas:
  - visual/jogos: afetado;
  - admin/resultados: afetado apenas na exibicao/opcoes dos jogos de 16 avos;
  - Supabase/API/deploy: sem alteracao.
- Testes ou verificacoes feitos:
  - `git status`;
  - leitura do `AGENTS.md`;
  - leitura dos commits recentes;
  - consulta read-only da tabela `matches` no Supabase;
  - comparacao dos melhores terceiros com a imagem oficial fornecida pelo usuario.
  - verificacao da matriz oficial de terceiros para a combinacao `B/D/E/F/I/J/K/L`;
  - verificacao de sintaxe do JavaScript embutido com `node --check` em arquivo temporario;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no navegador/celular se os cards dos 16 avos aparecem com as selecoes corretas;
  - publicar somente apos revisao/autorizacao do usuario.

### Sessao 2026-06-23 - ordenacao e exibicao da aba FILTROS

- O que foi alterado:
  - na subaba `Palpites` da aba `Filtros`, a lista passou a ordenar os palpites pelo saldo previsto `gols casa - gols fora`, do maior para o menor, mantendo usuarios sem palpite ao final;
  - na subaba `Buffs`, a lista passou a ordenar participantes pelo nome do primeiro buff em ordem alfabetica;
  - quando um usuario possui mais de um buff no jogo, os buffs tambem sao exibidos em ordem alfabetica;
  - na subaba `Extras`, respostas textuais passam a ordenar de A a Z e respostas numericas de forma decrescente;
  - a exibicao dos buffs foi simplificada: `Aposta de Moedas`, `Empate Protegido` e `Pontuacao Dobrada` mostram apenas o nome; `Zerar Adversario` e `Meiar Adversario` mostram o alvo.
- Por que foi alterado:
  - facilitar a auditoria visual do ADMIN na nova aba consultiva `Filtros`.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao somente visual/consultiva para ADMIN;
  - nao altera pontuacao, ranking, palpites, moedas, buffs, extras, Supabase, RPCs, banco de dados, Vercel ou GitHub.
- Areas afetadas:
  - visual/admin: afetado;
  - JavaScript: ajustes de ordenacao e formatacao da aba `Filtros`;
  - Supabase/API/deploy: sem alteracao.
- Testes ou verificacoes feitos:
  - `git status`;
  - leitura do `AGENTS.md`;
  - leitura dos commits recentes;
  - verificacao de sintaxe do JavaScript embutido com `node --check` em arquivo temporario;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente como ADMIN se a ordenacao bate com a expectativa em jogos/extras reais.

### Sessao 2026-06-23 - aba ADMIN FILTROS consultiva

- O que foi alterado:
  - foi criada uma nova aba principal `Filtros`, visivel somente para usuarios ADMIN;
  - a aba `Filtros` possui tres subabas internas: `Palpites`, `Buffs` e `Extras`;
  - `Palpites` permite selecionar um jogo e consultar todos os participantes, com avatar, apelido, nome real e palpite ou `Sem palpite`;
  - jogos com resultado oficial reutilizam a logica visual existente de acerto exato/erro de resultado para destacar os cards;
  - `Buffs` permite selecionar um jogo, filtrar por `Todos`, `Com buff` e `Sem buff`, e consultar os buffs usados por participante;
  - `Extras` permite selecionar um dos oito extras e consultar as respostas de todos os participantes, com resultado oficial quando disponivel;
  - a aba `ADMIN` reorganizada anteriormente nao foi modificada estruturalmente.
- Por que foi alterado:
  - dar ao administrador uma area separada e somente leitura para auditar rapidamente palpites, buffs e extras sem entrar no gerenciamento individual de usuarios.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao visual/consultiva para ADMIN;
  - nao altera pontuacao, ranking, palpites, moedas, buffs, resultados oficiais, Supabase, RPCs, permissoes, banco de dados, Vercel ou GitHub.
- Areas afetadas:
  - visual/admin: afetado;
  - JavaScript: adicionadas consultas read-only e renderizacao da aba `Filtros`;
  - Supabase: sem patch e sem RPC nova; usa tabelas/funcoes ja existentes em leitura.
- Testes ou verificacoes feitos:
  - `git status`;
  - leitura do `AGENTS.md`;
  - leitura dos commits recentes;
  - verificacao de sintaxe do JavaScript embutido com `node --check` em arquivo temporario;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no navegador como ADMIN em desktop e celular;
  - publicar somente apos revisao/autorizacao do usuario.

### Sessao 2026-06-22 - reorganizacao visual do painel ADMIN

- O que foi alterado:
  - a aba ADMIN foi reorganizada em tres subabas internas: `Palpites / Buffs`, `Config. Gerais` e `Resultados / Auditoria`;
  - foi criado um seletor compacto e compartilhado de participante, com busca, filtro, lista limitada e resumo do usuario selecionado;
  - as areas de palpite normal, palpites extras, moedas, buffs e historico de buffs foram agrupadas em accordions;
  - configuracoes gerais de conta, solicitacoes de troca de nome e senha do ADMIN foram separadas da area operacional de palpites;
  - resultados finais e auditoria foram movidos para uma area propria, com listas longas usando rolagem interna;
  - a subaba ADMIN ativa fica salva em `sessionStorage` durante a sessao do navegador.
- Por que foi alterado:
  - reduzir a altura e a carga visual do painel ADMIN, facilitando a gestao em desktop e celular.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao estrutural e visual do painel administrativo;
  - nao altera regras de pontuacao, ranking, palpites, moedas, buffs, resultados, Supabase, RPCs, permissoes ou banco de dados.
- Areas afetadas:
  - visual/admin: afetado;
  - JavaScript: apenas controle de subabas, accordions e resumo do usuario selecionado;
  - Supabase, API, Vercel, GitHub e regras de negocio: sem alteracao funcional.
- Testes ou verificacoes feitos:
  - `git status`;
  - leitura do `AGENTS.md`;
  - leitura dos commits recentes;
  - mapeamento dos IDs/listeners da aba ADMIN;
  - verificacao de IDs duplicados;
  - `git diff --check`;
  - `npm.cmd run build`.
- Pendencias:
  - revisar visualmente no navegador como ADMIN em desktop e celular;
  - validar manualmente as acoes administrativas antes de publicar.

### Sessao 2026-06-20 - ajuste mobile do Meu Historico no ranking

- O que foi alterado:
  - os cards da area `Meu historico` na aba Ranking receberam ajustes responsivos para telas de celular;
  - no mobile, o card passa a controlar melhor a largura do conteudo e do selo/status da direita;
  - os textos, espacamentos e badges do historico foram reduzidos apenas em breakpoints pequenos para evitar corte lateral.
- Por que foi alterado:
  - em celulares, o status/resultado do historico estava ficando cortado na lateral direita da tela.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao apenas visual/responsiva na aba Ranking;
  - nao altera pontuacao, ranking, historico calculado, palpites, usuarios, Supabase, API, Vercel ou GitHub.
- Areas afetadas:
  - visual/mobile: afetado;
  - regras de negocio, banco de dados, API e deploy: sem alteracao funcional.
- Testes ou verificacoes feitos:
  - `git status`;
  - leitura do `AGENTS.md`;
  - leitura dos commits recentes;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no celular apos o deploy publicado.

### Sessao 2026-06-18 - detalhamento admin de pontos no ranking

- O que foi alterado:
  - no ranking, quando o usuario logado e ADMIN, a pontuacao total de cada participante vira um botao clicavel;
  - ao clicar, abre um modal com o detalhamento dos pontos daquele jogador por jogo concluido;
  - o modal usa a RPC existente `app_get_user_history` com `p_user_id`, que ja permite consulta por admin;
  - o detalhamento mostra palpite, resultado oficial, pontos positivos/negativos, status e buffs aplicados quando houver.
- Por que foi alterado:
  - facilitar a auditoria administrativa da pontuacao de cada participante sem precisar consultar o banco manualmente.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao de visual/UX administrativa;
  - nao altera calculo de pontuacao, ranking, palpites, usuarios, Supabase, API, moedas, buffs, resultados ou regras de fechamento.
- Areas afetadas:
  - ranking/admin: afetado visualmente para ADMIN;
  - Supabase: sem patch novo, apenas consumo de RPC existente;
  - regras de negocio, API, GitHub e Vercel: sem alteracao funcional nesta tarefa.
- Testes ou verificacoes feitos:
  - `git status`;
  - leitura do `AGENTS.md`;
  - leitura dos commits recentes;
  - `npm.cmd run build`;
  - `git diff --check`.
- Pendencias:
  - validar no navegador logado como ADMIN clicando na pontuacao total de alguns usuarios do ranking.

### Sessao 2026-06-18 - abertura automatica na pagina do proximo jogo

- O que foi alterado:
  - a aba Jogos agora calcula, na primeira renderizacao da lista, qual pagina contem o proximo jogo futuro sem resultado oficial;
  - se os filtros estiverem no padrao (`STATUS`, `FASE`, `GRUPO`), a pagina inicial passa a ser a pagina desse proximo jogo;
  - depois da primeira renderizacao, paginacao e filtros continuam respeitando a escolha manual do usuario.
- Por que foi alterado:
  - evitar que usuarios abram o bolao sempre nos primeiros jogos ja concluidos, como Mexico x Africa do Sul;
  - facilitar o acesso direto aos proximos jogos a palpitar.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao apenas de navegacao/UX na aba Jogos;
  - nao altera pontuacao, ranking, palpites, usuarios, Supabase, API, moedas, buffs, resultados ou regras de fechamento.
- Areas afetadas:
  - visual/navegacao: afetado;
  - regras de negocio, Supabase, API, GitHub e Vercel: sem alteracao funcional nesta tarefa.
- Testes ou verificacoes feitos:
  - `git status`;
  - leitura do `AGENTS.md`;
  - leitura dos commits recentes;
  - `npm.cmd run build`.
- Pendencias:
  - validar no site publicado se a aba Jogos abre diretamente na pagina do proximo jogo conforme o calendario atual.

### Sessao 2026-06-18 - correcao visual do lancamento de resultados admin

- O que foi alterado:
  - a lista de jogos do modal `Resultado oficial` agora corrige nomes com encoding quebrado na apresentacao;
  - jogos que ja possuem resultado oficial (`score_home` e `score_away`) recebem marcador `✓` no texto da opcao;
  - essas opcoes tambem recebem fundo verde no dropdown para facilitar identificar jogos ja lancados;
  - os selects administrativos de jogo reutilizam a mesma formatacao corrigida.
- Por que foi alterado:
  - alguns nomes de selecoes apareciam com mojibake, como `TchÃ©quia` e `Ãfrica do Sul`;
  - o ADMIN precisava visualizar rapidamente quais jogos ja tiveram resultado oficial lancado.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao visual/de apresentacao no painel ADMIN;
  - nao altera pontuacao, ranking, palpites, usuarios, Supabase, API, moedas, buffs ou resultados salvos.
- Areas afetadas:
  - visual/admin: afetado;
  - Supabase, API, GitHub, Vercel e regras de negocio: sem alteracao funcional.
- Testes ou verificacoes feitos:
  - `git status`;
  - leitura do `AGENTS.md`;
  - leitura dos commits recentes;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no navegador se o dropdown nativo aplica o fundo verde em todos os ambientes; o marcador `✓` permanece como fallback visual.

### Sessao 2026-06-17 - ampliacao de fotos no ranking

- O que foi alterado:
  - fotos enviadas por usuarios no ranking agora podem ser ampliadas ao clicar na miniatura;
  - foi criado um modal visual com fundo escurecido, imagem proporcional e fechamento por `X`, clique fora ou tecla `Esc`;
  - avatares sem foto enviada continuam com o comportamento anterior e nao abrem modal.
  - ajuste posterior ampliou o tamanho maximo do modal/imagem para ocupar mais a tela sem distorcer.
- Por que foi alterado:
  - permitir ver melhor a foto dos participantes diretamente na aba Ranking.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao apenas visual/UX na aba Ranking;
  - nao altera ranking, pontuacao, dados dos usuarios, upload de imagens, Supabase, API, moedas, buffs ou palpites.
- Areas afetadas:
  - visual: afetado;
  - Vercel/GitHub: afetados apenas pela publicacao da alteracao;
  - Supabase e regras de negocio: sem alteracao.
- Testes ou verificacoes feitos:
  - `git status`;
  - leitura do `AGENTS.md`;
  - leitura dos commits recentes;
  - `npm.cmd run build`.
- Pendencias:
  - validar visualmente no site publicado com usuario que tenha foto enviada no ranking.

### Sessao 2026-06-15 - resultado oficial no rodape dos cards de jogos

- O que foi alterado:
  - cards da aba Jogos passam a esconder data/hora quando o jogo tem resultado oficial (`score_home` e `score_away`);
  - no lugar da data/hora aparece `CONCLUÍDO | AAA X-X BBB`;
  - o trecho do placar oficial fica vermelho e apenas os numeros ficam em negrito;
  - o timer/countdown ignora cards que ja possuem resultado oficial para nao sobrescrever o texto.
- Por que foi alterado:
  - deixar mais claro para todos os usuarios quais jogos ja foram concluidos e qual foi o placar oficial.
- Arquivos modificados:
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - alteracao visual/informativa na aba Jogos;
  - vale para jogos ja lancados e proximos jogos assim que o ADMIN salvar resultado oficial;
  - nao altera pontuacao, ranking, historico, missoes, palpites, usuarios, Supabase, RLS ou SQL.
- Areas afetadas:
  - visual: afetado;
  - regras de negocio, Supabase, API, GitHub e Vercel: sem alteracao funcional nesta tarefa.
- Testes ou verificacoes feitos:
  - `git status`;
  - leitura do `AGENTS.md`;
  - leitura dos commits recentes;
  - `npm.cmd run build`;
  - `git diff --check`.
- Pendencias:
  - validar visualmente no site publicado em jogos ja concluidos apos deploy.

### Sessao 2026-06-15 - troca rapida protegida entre LORDEWEL e ADMIN

- O que foi alterado:
  - criacao da rota serverless `api/quick-switch-user.js`;
  - criacao de botao visual abaixo do card de login/logout para troca entre perfis;
  - o botao mostra `ADMIN` somente quando o usuario logado e `LORDEWEL`;
  - o botao mostra `LORDEWEL` somente quando o usuario logado e `ADMIN`;
  - a rota valida o token atual no Supabase antes de autenticar o perfil destino;
  - correcao da chave anon fallback da nova Function para bater com a chave usada pelo frontend.
- Por que foi alterado:
  - facilitar a alternancia operacional entre usuario pessoal e administrador sem expor o botao para outros participantes.
- Arquivos modificados:
  - `design-lab.html`
  - `api/quick-switch-user.js`
  - `AGENTS.md`
- Impacto no bolao:
  - melhora de fluxo administrativo;
  - nao altera pontuacao, ranking, palpites, moedas, buffs ou resultados;
  - afeta autenticacao apenas para a troca controlada entre `LORDEWEL` e `ADMIN`.
- Areas afetadas:
  - autenticacao: afetada de forma pontual;
  - Vercel: exige variavel segura `QUICK_SWITCH_PERSONAL_PASSWORD`;
  - visual: adiciona botao de troca quando aplicavel;
  - Supabase: nao houve patch SQL nem mudanca de banco.
- Testes ou verificacoes feitos:
  - `git status`;
  - leitura do `AGENTS.md`;
  - leitura dos commits recentes;
  - `node --check api/quick-switch-user.js`;
  - `npm.cmd run build`;
  - configuracao da variavel `QUICK_SWITCH_PERSONAL_PASSWORD` na Vercel Production;
  - teste controlado em producao da troca `LORDEWEL` -> `ADMIN` -> `LORDEWEL`, sem imprimir tokens.
- Pendencias:
  - validar visualmente no navegador logado como `LORDEWEL` e como `ADMIN`.

### Sessao 2026-06-15 - API desativada e resultados manuais como fonte principal

- O que foi alterado:
  - desativacao segura da rota `/api/the-sports-sync`;
  - remocao do agendamento automatico do GitHub Actions;
  - remocao dos botoes visuais de sincronizar/buscar resultado pela API;
  - remocao da exibicao de ultima sincronizacao na aba Jogos;
  - atualizacao desta memoria oficial do projeto.
- Por que foi alterado:
  - impedir que a API externa interfira, sobrescreva ou gere conflito com resultados oficiais lancados manualmente;
  - manter o painel ADMIN como fonte principal de verdade dos resultados neste momento.
- Arquivos modificados:
  - `api/the-sports-sync.js`
  - `.github/workflows/sync-results.yml`
  - `design-lab.html`
  - `AGENTS.md`
- Impacto no bolao:
  - resultados oficiais passam a depender do lancamento manual pelo ADMIN;
  - pontuacao, ranking, historico e acertos continuam sendo atualizados pelo fluxo manual existente;
  - a API nao grava mais resultados e nao deve alterar placares.
- Areas afetadas:
  - API: afetada, agora desativada;
  - Vercel: afetada somente na rota serverless, que responde como desativada;
  - GitHub: afetado no workflow, que nao agenda mais chamadas;
  - Visual: afetado pela retirada dos atalhos/status da API;
  - Supabase, pontuacao, ranking, palpites e usuarios: nao foram alterados.
- Testes ou verificacoes feitos:
  - `git status` antes das alteracoes;
  - leitura dos commits recentes;
  - revisao do fluxo de API, workflow, frontend e AGENTS;
  - `node --check api/the-sports-sync.js`;
  - `npm.cmd run build`;
  - revisao de `git diff --stat` e diff dos arquivos funcionais alterados.
- Pendencias:
  - fazer deploy na Vercel apos commit/push para a desativacao valer em producao;
  - se no futuro for contratar/pagar outra API, reativar apenas com protecao explicita para nao sobrescrever resultado manual sem validacao.

### Sessão 2026-06-15 - trava prática para commits sem memória atualizada

- O que foi alterado:
  - criação de hook versionado `.githooks/pre-commit`;
  - criação do script `scripts/install-githooks.ps1`;
  - documentação da trava no `AGENTS.md`;
  - documentação curta da trava no `README.md`.
- Por que foi alterado:
  - evitar commits sem atualização da memória oficial do projeto.
- Arquivos modificados:
  - `.githooks/pre-commit`
  - `scripts/install-githooks.ps1`
  - `AGENTS.md`
  - `README.md`
- Impacto no bolão:
  - nenhum impacto funcional no sistema do bolão;
  - impacto apenas no fluxo de trabalho Git local.
- Áreas afetadas:
  - GitHub / Git local;
  - documentação do projeto.
- Testes ou verificações feitos:
  - leitura do estado atual com `git status`;
  - revisão do `AGENTS.md` e `README.md`;
  - implementação da lógica de bloqueio por staging do `AGENTS.md`;
  - ativação local do hook com `git config core.hooksPath .githooks`;
  - teste real por `git commit` em repositórios temporários, validando:
    - bloqueio sem `AGENTS.md`;
    - bloqueio com arquivo do projeto staged sem `AGENTS.md` staged;
    - liberação quando somente `AGENTS.md` está staged;
    - liberação quando `AGENTS.md` e outro arquivo estão staged.
- Pendências:
  - repetir a ativação em cada PC novo usado no projeto.
