# Bolão Copa 2026

Sistema completo de bolão da Copa do Mundo 2026, feito em `HTML + CSS + JavaScript`, com foco em simplicidade, custo zero, responsividade e deploy estático.

## Stack escolhida

- Frontend: `HTML`, `CSS`, `JavaScript` moderno sem build
- Backend: `Supabase`
- Banco: `Postgres do Supabase`
- Tempo real leve: `Supabase Realtime`
- Armazenamento de avatar: `Supabase Storage`
- Deploy: `GitHub Pages`, `Vercel` ou `Netlify`
- Fonte de dados esportivos: `TheSportsDB` como integração sugerida + fallback manual no admin / SQL seed

## O que já vem pronto

- Login por apelido sem e-mail
- Cadastro com nome, senha e avatar
- 20 avatares padrão com tema futebol
- Upload leve de foto
- Ranking geral com desempate
- Palpites por jogo
- Palpites extras pré-copa
- Fechamento automático 30 minutos antes
- Liberação de visualização dos palpites após o fechamento
- Chat geral
- Banner de avisos
- Painel administrativo
- Tema claro/escuro
- Dados mock para testes imediatos
- Estrutura de backend em SQL para produção

## Estrutura

```text
world-cup-bolao-2026/
├─ index.html
├─ public/
│  ├─ css/
│  │  └─ styles.css
│  ├─ data/
│  ├─ assets/
│  │  └─ avatars/
│  └─ js/
│     ├─ app.js
│     └─ modules/
│        ├─ api.js
│        ├─ config.js
│        ├─ mock-data.js
│        └─ utils.js
└─ supabase/
   ├─ schema.sql
   └─ seed.sql
```

## Rodando localmente

Como o projeto é estático, você pode abrir com um servidor local simples.

### Opção 1: VS Code Live Server

Abra a pasta e rode `index.html` com Live Server.

### Opção 2: Python

```bash
python -m http.server 5500
```

Depois acesse:

`http://localhost:5500`

## Teste imediato com mock

Sem configurar nada, o sistema já funciona em modo local mock.

Usuários de teste:

- `capitao` / `1234`
- `maria10` / `1234`
- `pedrinho` / `1234`

Os dados ficam salvos no `localStorage`.

## Configurando produção com Supabase

### 1. Criar projeto

Crie um projeto gratuito em [Supabase](https://supabase.com/).

### 2. Executar SQL

No SQL Editor do Supabase:

1. Rode [`schema.sql`](./supabase/schema.sql)
2. Rode [`seed.sql`](./supabase/seed.sql)

### 3. Criar bucket de avatar

No painel Storage, crie um bucket chamado:

`avatars`

Sugestão:

- Público para simplificar
- Limite de upload no frontend: 2MB

### 4. Atualizar configuração

Edite [`public/js/modules/config.js`](./public/js/modules/config.js):

```js
export const SUPABASE_CONFIG = {
  url: "SUA_URL",
  anonKey: "SUA_ANON_KEY",
  storageBucket: "avatars",
  enabled: true,
};
```

Observação:

- A `anon key` do Supabase é pública por natureza em apps frontend.
- O controle real vem das funções RPC e das regras de acesso.

### 5. Integrar RPCs no frontend

O projeto já está preparado com a camada `api.js`.

No momento:

- O modo `mock` está funcional
- O modo `Supabase` ja esta conectado aos RPCs e tabelas principais
- Depois de preencher `url` e `anonKey`, o frontend passa a usar o banco real

As funções SQL já previstas no backend são:

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

## Sugestão de integração de resultados

### Estratégia recomendada

1. Sincronizar agenda e resultados de API gratuita
2. Salvar no Supabase
3. Usar o banco como fonte oficial do app

Isso evita depender diretamente da API a cada acesso.

### API gratuita sugerida

`TheSportsDB`

Motivos:

- possui plano gratuito
- simples para consumo por `fetch`
- boa para atualização leve de eventos

### Fallback

Se a API estiver fora ou incompleta:

- admin atualiza manualmente placar/vencedor
- ou usa importação SQL/JSON no Supabase

## Regras implementadas

### Fase de grupos

- Placar exato: `+1`
- Resultado correto: `+0.5`
- Erro de resultado: `-0.25`

### Mata-mata

- Placar exato no tempo normal: `+1.5`
- Prorrogação exata: `+0.5`
- Resultado correto no tempo normal: `+0.5`
- Acerto de quem avança: `+0.5`
- Erro de quem avança: `-0.5`

### Extras

- Campeão: `+5`
- Vice: `+3`
- 3º lugar: `+2`
- 4º lugar: `+2`
- Artilheiro: `+1.5`
- Melhor campanha na fase de grupos: `+2`
- Total de gols: `+1` para quem chegar mais perto

## Funcionalidades admin previstas

- Bloquear / desbloquear usuário
- Resetar senha
- Excluir usuário
- Alterar nome e avatar
- Publicar banner de aviso
- Atualizar resultados
- Gerenciar dados do sistema

## Deploy

### GitHub Pages

- Suba a pasta em um repositório
- Ative GitHub Pages apontando para a branch principal
- Se usar Supabase, mantenha as chaves em `config.js`

### Vercel

- Importe o repositório
- Framework preset: `Other`
- Output: raiz estática

### Netlify

- Importe o repositório
- Publish directory: `.`
- Sem build command

## Limitações atuais da entrega

- O frontend já está funcional em modo mock
- O schema e seed do Supabase já estão prontos
- A camada `SupabaseApiClient` ficou como ponto de conexão final para plugar produção real
- A tabela completa oficial da Copa 2026 ainda depende da confirmação oficial/API, então o projeto usa um template completo de estrutura do torneio com partidas programáveis e exemplos preenchidos

## Próximo passo recomendado

Se quiser colocar em uso real imediatamente, a ordem ideal é:

1. Configurar o Supabase
2. Ligar `SupabaseApiClient`
3. Importar tabela oficial dos jogos assim que a agenda estiver disponível
4. Publicar no Vercel ou Netlify

## Licença

Uso livre para bolão privado entre amigos.
