# Projeto BI / SQL

Repositório do **Grupo de Desenvolvimento** do Projeto BI (PKZ / One to One): tratamento das medidas das avaliações, API de dados e geração e envio dos relatórios. O banco novo é carregado pelo grupo de Banco de Dados; este grupo só lê esse banco.

Este projeto cria os schemas iniciais e configura uma conexão FDW para um banco remoto.

## Estrutura
- `01_schemas.sql`: cria os schemas `origem`, `trat` e `api`
- `02_fdw.sql`: configura o PostgreSQL Foreign Data Wrapper para acessar o banco remoto. O script importa o schema `public`; o banco novo do grupo de Banco de Dados usa o schema `novo`, então confira antes de rodar
- `03_storage.sql`: cria o bucket privado `relatorios` para os PDFs
- `04_trat_parametros_catalogo.sql`: parâmetros de negócio (`trat.parametro`) e catálogo de regras por teste (`trat.catalogo_teste`)
- `docs/api.md`: contrato das views do schema `api` (colunas, regras e como chamar)
- `exemplos/api/`: respostas de exemplo da API, no formato que o Supabase devolve, para o gerador de relatórios começar sem esperar a API
- `.env`: arquivo local com as variáveis de ambiente

## Arquivo .env
Crie um arquivo `.env` na raiz do projeto com este formato:

```env
SUPABASE_DB_URL=postgresql://usuario:senha@host:5432/banco
REMOTO_HOST=host_remoto
REMOTO_PORT=5432
REMOTO_DB=nome_do_banco_remoto
REMOTO_USER=usuario_remoto
REMOTO_PASSWORD=senha_remota
```

---

## Linux / macOS
No terminal, na raiz do projeto:

```bash
set -a
source .env
set +a

psql "$SUPABASE_DB_URL" -f 01_schemas.sql
psql "$SUPABASE_DB_URL" \
  -v REMOTO_HOST="$REMOTO_HOST" \
  -v REMOTO_PORT="$REMOTO_PORT" \
  -v REMOTO_DB="$REMOTO_DB" \
  -v REMOTO_USER="$REMOTO_USER" \
  -v REMOTO_PASSWORD="$REMOTO_PASSWORD" \
  -f 02_fdw.sql
psql "$SUPABASE_DB_URL" -f 03_storage.sql
psql "$SUPABASE_DB_URL" -f 04_trat_parametros_catalogo.sql
```

---

## Windows (PowerShell)
No PowerShell, na raiz do projeto:

```powershell
$env:SUPABASE_DB_URL = "postgresql://usuario:senha@host:5432/banco"
$env:REMOTO_HOST = "host_remoto"
$env:REMOTO_PORT = "5432"
$env:REMOTO_DB = "nome_do_banco_remoto"
$env:REMOTO_USER = "usuario_remoto"
$env:REMOTO_PASSWORD = "senha_remota"

psql "$env:SUPABASE_DB_URL" -f .\01_schemas.sql
psql "$env:SUPABASE_DB_URL" `
  -v REMOTO_HOST="$env:REMOTO_HOST" `
  -v REMOTO_PORT="$env:REMOTO_PORT" `
  -v REMOTO_DB="$env:REMOTO_DB" `
  -v REMOTO_USER="$env:REMOTO_USER" `
  -v REMOTO_PASSWORD="$env:REMOTO_PASSWORD" `
  -f .\02_fdw.sql
psql "$env:SUPABASE_DB_URL" -f .\03_storage.sql
psql "$env:SUPABASE_DB_URL" -f .\04_trat_parametros_catalogo.sql
```

Ou, se quiser carregar o `.env` em uma sessão do PowerShell:

```powershell
Get-Content .env | ForEach-Object {
    if ($_ -match "^\s*#" -or $_ -match "^\s*$") { return }
    $key, $value = $_ -split "=", 2
    $env:$key = $value.Trim('"')
}
```

## Segredos
- A `SUPABASE_SECRET_KEY` ignora todas as permissões. Só vai no `.env` do backend/gerador de relatórios.
- Nunca no GitHub, no front ou em chat. Se vazar: *Project Settings → API Keys*, gere outra e apague a antiga.
- O front usa apenas a publishable key.

## API
- A API é a REST automática do Supabase: cada view do schema `api` vira um endpoint. Colunas, regras e exemplos estão em [`docs/api.md`](docs/api.md).
- Para o schema `api` aparecer na API, ele precisa estar em *Project Settings → Data API → Exposed schemas* no painel. O `GRANT` do `01_schemas.sql` sozinho não basta.
- Quem chama envia o cabeçalho `Accept-Profile: api`; sem ele o Supabase procura a view em `public`.
- Só usuário logado (`authenticated`) recebe resposta. O papel `anon` não tem acesso ao schema.

## Storage
- Bucket `relatorios` é privado (criado por `03_storage.sql`).
- Usuários acessam os PDFs por URL assinada, gerada pelo backend.

## Claude + Supabase (MCP)
O arquivo `.mcp.json` na raiz conecta o Claude Code ao projeto Supabase, para ele ler as tabelas, testar consultas e conferir os schemas `origem`, `trat` e `api` sem você colar nada no chat. Ele só guarda o endereço e o ID do projeto, **sem nenhum segredo**.

A conexão é configurada como **somente leitura** (`read_only=true`) e limitada a este projeto (`project_ref`).

### Configuração (cada pessoa do grupo faz uma vez)
1. Instale o Claude Code (PowerShell): `irm https://claude.ai/install.ps1 | iex`
2. Se o comando `claude` não for reconhecido, adicione `C:\Users\<seu_usuario>\.local\bin` ao PATH do usuário e abra um terminal novo. Para testar só na sessão atual:
   ```powershell
   $env:Path += ";$env:USERPROFILE\.local\bin"
   claude --version
   ```
3. Na raiz do projeto, rode `claude`. Quando ele perguntar sobre o servidor `supabase`, escolha **"Use this MCP server"** (não use a opção que aprova todos os servidores futuros).
4. Digite `/mcp`, escolha `supabase` e depois *Authenticate*. O navegador abre: entre com **a sua conta do Supabase** e autorize a organização do projeto.
5. Teste pedindo: "liste as tabelas dos schemas origem, trat e api".

> A autenticação do Supabase tem que ser feita pelo `claude` num terminal comum. Ela não funciona pelo chat da extensão do VS Code.

### Quem acessa o quê
- A autorização é **individual**: fica salva só no computador de quem autenticou. O `.mcp.json` não dá acesso a ninguém.
- Para acessar o projeto, a pessoa precisa ser membro da organização no Supabase (*Organization → Team*).
- O login no Supabase é independente do login no Claude. Pode usar contas diferentes.

### Cuidados
- Mantenha o `read_only=true`. Sem ele, o Claude consegue alterar e apagar dados do banco (`execute_sql`, `apply_migration`).
- O Claude pede aprovação a cada chamada de ferramenta. Leia o que ele vai executar antes de aprovar e não use aprovação automática.
- Texto vindo de terceiros no banco pode conter instruções disfarçadas (prompt injection). Revise as chamadas.
- O Storage vem desativado nessa integração: o bucket `relatorios` continua sendo criado pelo script SQL.
- O MCP não substitui o `git-flow`: o agente de git continua não executando SQL nem acessando o banco.

## Fluxo de git (agente `git-flow`)
O arquivo [`agents/git_flow.md`](agents/git_flow.md) define o agente de IA responsável por enviar o trabalho ao GitHub. Ele é acionado automaticamente quando você pede algo como "commita", "sobe isso" ou "abre o PR".

O que ele faz:
- cria uma branch nova a partir da `main` (`tipo/assunto`, ex.: `feat/bucket-relatorios`);
- escreve o commit no formato `tipo(escopo): resumo` (ex.: `fix(fdw): corrige a porta do banco remoto`);
- confere se nenhum segredo (`.env`, chaves do Supabase) vai junto;
- faz o push e abre o Pull Request.

O que ele **não** faz: commit direto na `main` e merge. O PR sempre fica aguardando a revisão de alguém do grupo.

Para mudar as regras de commit, branch ou PR, edite o `agents/git_flow.md`.

---
