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
  - acertar classificado/vencedor: `+1.0`
  - errar: `-0.2`
  - ausência: `-0.2`
- Mata-mata decisivo:
  - placar exato: `+3.0`
  - acertar classificado/vencedor: `+2.0`
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
