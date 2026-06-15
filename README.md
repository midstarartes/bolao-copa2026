# Bolao Copa 2026

Sistema completo de bolao da Copa do Mundo 2026, feito em `HTML + CSS + JavaScript`, com foco em simplicidade, custo zero, responsividade e deploy estatico.

## Stack escolhida

- Frontend: `HTML`, `CSS`, `JavaScript` moderno sem build
- Backend: `Supabase`
- Banco: `Postgres do Supabase`
- Tempo real leve: `Supabase Realtime`
- Armazenamento de avatar: `Supabase Storage`
- Deploy: `GitHub Pages`, `Vercel` ou `Netlify`
- Fonte de dados esportivos: `TheSportsDB` como integracao sugerida + fallback manual no admin / SQL seed

## O que ja vem pronto

- Login por apelido sem e-mail
- Cadastro com nome, senha e avatar
- 20 avatares padrao com tema futebol
- Upload leve de foto
- Ranking geral com desempate
- Palpites por jogo
- Palpites extras pre-copa
- Fechamento automatico 30 minutos antes
- Liberacao de visualizacao dos palpites apos o fechamento
- Chat geral
- Banner de avisos
- Painel administrativo
- Tema claro/escuro
- Dados mock para testes imediatos
- Estrutura de backend em SQL para producao

## Estrutura

```text
world-cup-bolao-2026/
|- index.html
|- public/
|  |- css/
|  |  `- styles.css
|  |- data/
|  |- assets/
|  |  `- avatars/
|  `- js/
|     |- app.js
|     `- modules/
|        |- api.js
|        |- config.js
|        |- mock-data.js
|        `- utils.js
`- supabase/
   |- schema.sql
   `- seed.sql
```

## Rodando localmente

Como o projeto e estatico, voce pode abrir com um servidor local simples.

### Opcao 1: VS Code Live Server

Abra a pasta e rode `index.html` com Live Server.

### Opcao 2: Python

```bash
python -m http.server 5500
```

Depois acesse:

`http://localhost:5500`

## Teste imediato com mock

Sem configurar nada, o sistema ja funciona em modo local mock.

Usuarios de teste:

- `capitao` / `1234`
- `maria10` / `1234`
- `pedrinho` / `1234`

Os dados ficam salvos no `localStorage`.

## Configurando producao com Supabase

### 1. Criar projeto

Crie um projeto gratuito em [Supabase](https://supabase.com/).

### 2. Executar SQL

No SQL Editor do Supabase:

1. Rode [`schema.sql`](./supabase/schema.sql)
2. Rode [`seed.sql`](./supabase/seed.sql)

### 3. Criar bucket de avatar

No painel Storage, crie um bucket chamado:

`avatars`

Sugestao:

- Publico para simplificar
- Limite de upload no frontend: 2MB

### 4. Atualizar configuracao

Edite [`public/js/modules/config.js`](./public/js/modules/config.js):

```js
export const SUPABASE_CONFIG = {
  url: "SUA_URL",
  anonKey: "SUA_ANON_KEY",
  storageBucket: "avatars",
  enabled: true,
};
```

Observacao:

- A `anon key` do Supabase e publica por natureza em apps frontend.
- O controle real vem das funcoes RPC e das regras de acesso.

### 5. Integrar RPCs no frontend

O projeto ja esta preparado com a camada `api.js`.

No momento:

- O modo `mock` esta funcional
- O modo `Supabase` ja esta conectado aos RPCs e tabelas principais
- Depois de preencher `url` e `anonKey`, o frontend passa a usar o banco real

As funcoes SQL ja previstas no backend sao:

- `app_register_user`
- `app_login_user`
- `app_logout_user`
- `app_save_prediction`
- `app_save_bonus_prediction`
- `app_send_chat_message`
- `app_admin_update_user`
- `app_admin_delete_user`
- `app_admin_delete_message`
- `app_admin_set_banner`

## Sugestao de integracao de resultados

### Estrategia recomendada

1. Sincronizar agenda e resultados de API gratuita
2. Salvar no Supabase
3. Usar o banco como fonte oficial do app

Isso evita depender diretamente da API a cada acesso.

### API gratuita sugerida

`TheSportsDB`

Motivos:

- possui plano gratuito
- simples para consumo por `fetch`
- boa para atualizacao leve de eventos

### Fallback

Se a API estiver fora ou incompleta:

- admin atualiza manualmente placar/vencedor
- ou usa importacao SQL/JSON no Supabase

## Regras implementadas

### Fase de grupos

- Placar exato: `+1`
- Resultado correto: `+0.5`
- Erro de resultado: `-0.25`

### Mata-mata

- Placar exato no tempo normal: `+1.5`
- Prorrogacao exata: `+0.5`
- Resultado correto no tempo normal: `+0.5`
- Acerto de quem avanca: `+0.5`
- Erro de quem avanca: `-0.5`

### Extras

- Campeao: `+5`
- Vice: `+3`
- 3o lugar: `+2`
- 4o lugar: `+2`
- Artilheiro: `+1.5`
- Melhor campanha na fase de grupos: `+2`
- Total de gols: `+1` para quem chegar mais perto

## Funcionalidades admin previstas

- Bloquear / desbloquear usuario
- Resetar senha
- Excluir usuario
- Alterar nome e avatar
- Publicar banner de aviso
- Atualizar resultados
- Gerenciar dados do sistema

## Deploy

### GitHub Pages

- Suba a pasta em um repositorio
- Ative GitHub Pages apontando para a branch principal
- Se usar Supabase, mantenha as chaves em `config.js`

### Vercel

- Importe o repositorio
- Framework preset: `Other`
- Output: raiz estatica

### Netlify

- Importe o repositorio
- Publish directory: `.`
- Sem build command

## Limitacoes atuais da entrega

- O frontend ja esta funcional em modo mock
- O schema e seed do Supabase ja estao prontos
- A camada `SupabaseApiClient` ficou como ponto de conexao final para plugar producao real
- A tabela completa oficial da Copa 2026 ainda depende da confirmacao oficial/API, entao o projeto usa um template completo de estrutura do torneio com partidas programaveis e exemplos preenchidos

## Proximo passo recomendado

Se quiser colocar em uso real imediatamente, a ordem ideal e:

1. Configurar o Supabase
2. Ligar `SupabaseApiClient`
3. Importar tabela oficial dos jogos assim que a agenda estiver disponivel
4. Publicar no Vercel ou Netlify

## Licenca

Uso livre para bolao privado entre amigos.

## Trava de commit do AGENTS.md

Este projeto possui uma trava de `pre-commit` versionada em `.githooks/` para evitar commits sem atualizar a memoria oficial do projeto.

Ela serve para:

- bloquear commit se `AGENTS.md` nao existir;
- bloquear commit quando houver arquivos do projeto staged sem o `AGENTS.md` staged junto;
- orientar a atualizar o `AGENTS.md` antes do commit.

### Como ativar em um PC novo

Rode:

```bash
git config core.hooksPath .githooks
```

Ou, neste projeto, execute:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-githooks.ps1
```

Antes de cada commit, o `AGENTS.md` deve estar atualizado e incluido no commit.
