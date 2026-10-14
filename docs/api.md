# API de avaliações (schema `api`)

Contrato das views que o Grupo de Desenvolvimento expõe pela API REST do Supabase para o gerador de relatórios e para os outros consumidores internos da empresa.

**Estado:** provisório. Os nomes das colunas não mudam sem aviso no grupo. Os valores de exemplo são fictícios (`exemplos/api/`). As regras por teste (unidade, direção, faixa plausível) ficam marcadas como **não confirmadas** até a PKZ validar o catálogo.

## Como chamar

A API é a REST automática do Supabase (PostgREST). Cada view vira um endpoint:

```
GET {SUPABASE_URL}/rest/v1/<view>?<filtros>
```

Cabeçalhos obrigatórios:

| Cabeçalho | Valor |
|---|---|
| `apikey` | chave do projeto (publishable no front; secret só no backend) |
| `Authorization` | `Bearer <token>`: JWT do usuário logado, ou a secret key no gerador de relatórios |
| `Accept-Profile` | `api` (sem isso o PostgREST procura a view em `public`) |

Sem login não há resposta: o schema `api` só tem permissão para o papel `authenticated`. Para o schema aparecer na API, ele precisa estar em **Project Settings → Data API → Exposed schemas** no painel do Supabase.

Filtros seguem a sintaxe do PostgREST: `?atleta_id=eq.<uuid>`, `&order=data_avaliacao.asc`, `&select=teste,valor`.

Exemplo em Python (gerador de relatórios, com a secret key):

```python
import os, requests

base = os.environ["SUPABASE_URL"] + "/rest/v1/"
key = os.environ["SUPABASE_SECRET_KEY"]
headers = {"apikey": key, "Authorization": f"Bearer {key}", "Accept-Profile": "api"}

atleta_id = "a1b2c3d4-0000-4000-8000-000000000001"
comparacao = requests.get(base + "comparacao", headers=headers,
                          params={"atleta_id": f"eq.{atleta_id}"}).json()
evolucao = requests.get(base + "evolucao", headers=headers,
                        params={"atleta_id": f"eq.{atleta_id}", "order": "data_avaliacao.asc"}).json()
```

A resposta é sempre um array JSON de linhas, no mesmo formato dos arquivos em `exemplos/api/`. Enquanto a API não existe, o gerador lê esses arquivos.

## Views

### `atleta`: identificação e filtros

Uma linha por atleta. É a única view com nome; as de desempenho não trazem nome, para que a IA receba só id, idade e números.

| Coluna | Tipo | Descrição |
|---|---|---|
| `atleta_id` | uuid | id do atleta no banco novo |
| `unidade` | text | `PKZ` ou `ONE_TO_ONE` |
| `nome` | text | nome do atleta |
| `idade` | int | idade em anos na data da consulta |
| `categoria` | text | categoria do cadastro; pode ser nulo |
| `ativo` | bool | atleta ativo no app |
| `total_avaliacoes` | int | avaliações físicas com pelo menos uma medida válida |
| `ultima_avaliacao_em` | date | data da última avaliação; nulo se nunca avaliado |

Exemplo: `exemplos/api/atleta.json`.

### `evolucao`: histórico de cada teste do atleta

Uma linha por atleta, avaliação e teste. O valor é a **melhor tentativa válida** da avaliação (menor tempo ou maior distância), já na unidade padrão do catálogo. Avaliação sem tentativa válida para um teste não gera linha: o valor foi para `revisao_dados`.

| Coluna | Tipo | Descrição |
|---|---|---|
| `atleta_id` | uuid | |
| `avaliacao_id` | uuid | id da avaliação no banco novo |
| `data_avaliacao` | date | |
| `teste` | text | código do teste no catálogo (ex.: `sprint_20m`) |
| `teste_nome` | text | nome para exibir |
| `unidade_medida` | text | `s`, `cm`, `m` ou `pontos` |
| `maior_melhor` | bool | `true`: maior valor é melhor; `false`: menor é melhor |
| `confirmado` | bool | `true` só depois que a PKZ validou a regra do teste |
| `valor` | numeric | melhor tentativa válida, na unidade padrão |
| `tentativas_validas` | int | quantas tentativas entraram na escolha |

Serve para o gráfico de evolução: filtrar por `atleta_id`, agrupar por `teste`, ordenar por `data_avaliacao`.

Exemplo: `exemplos/api/evolucao.json`.

### `comparacao`: avaliação atual contra a anterior

Uma linha por atleta e teste, comparando a última avaliação com a imediatamente anterior em que o teste tem valor válido.

| Coluna | Tipo | Descrição |
|---|---|---|
| `atleta_id` | uuid | |
| `teste`, `teste_nome`, `unidade_medida`, `maior_melhor`, `confirmado` | | como em `evolucao` |
| `data_anterior` | date | nulo quando só existe uma avaliação do teste |
| `valor_anterior` | numeric | idem |
| `data_atual` | date | |
| `valor_atual` | numeric | |
| `variacao_abs` | numeric | `valor_atual - valor_anterior`, na unidade do teste |
| `variacao_pct` | numeric | `(valor_atual - valor_anterior) / valor_anterior * 100`, 1 casa decimal |
| `situacao` | text | `melhorou`, `piorou`, `estavel` ou `sem_comparacao` |

Regras de `situacao`:

- `estavel`: `abs(variacao_pct)` abaixo do parâmetro `variacao_estavel_pct` (2% provisório).
- `melhorou` / `piorou`: pela direção do teste (`maior_melhor`). Variação negativa num teste de tempo é melhora.
- `sem_comparacao`: não há avaliação anterior com valor válido.

**Regra para o relatório dos pais:** escrever "melhorou" ou "piorou" só quando `confirmado = true`. Teste não confirmado aparece com os valores, sem classificação.

Exemplo: `exemplos/api/comparacao.json`.

### `reavaliacao`: reavaliações vencidas e a vencer

Uma linha por atleta com pelo menos uma avaliação. Ainda sem arquivo de exemplo.

| Coluna | Tipo | Descrição |
|---|---|---|
| `atleta_id` | uuid | |
| `unidade` | text | |
| `ultima_avaliacao_em` | date | |
| `vence_em` | date | `ultima_avaliacao_em + reavaliacao_dias` (90 provisório) |
| `dias_para_vencer` | int | negativo quando vencida |
| `situacao` | text | `vencida`, `a_vencer` (dentro de `reavaliacao_aviso_dias`, 30 provisório) ou `em_dia` |

## Parâmetros

Os números das regras ficam em `trat.parametro` (`04_trat_parametros_catalogo.sql`), para a PKZ ajustar sem mexer em código:

| Chave | Valor provisório |
|---|---|
| `variacao_estavel_pct` | 2 |
| `reavaliacao_dias` | 90 |
| `reavaliacao_aviso_dias` | 30 |

As regras por teste (unidade padrão, direção, faixa plausível, conversão, confirmado) ficam em `trat.catalogo_teste`, no mesmo script.

## O que ainda falta

- Confirmar com a PKZ a unidade, a direção e a faixa plausível de cada teste, e se algum teste usa média em vez da melhor tentativa.
- Separação por unidade (PKZ e One to One) para usuário logado: depende de como o Grupo de Desenvolvimento vai ler o banco novo do grupo de Banco de Dados.
- Views de treino (`ultimo_treino`, `treino_mes`) para o relatório One to One: tarefa separada.
