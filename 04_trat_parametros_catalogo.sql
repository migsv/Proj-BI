-- Parâmetros de negócio e catálogo de regras por teste (schema trat).
-- Não depende do banco do grupo de Banco de Dados: pode rodar logo depois do 01_schemas.sql.
-- Pode rodar quantas vezes quiser: CREATE IF NOT EXISTS e ON CONFLICT DO NOTHING,
-- então um valor ajustado à mão no banco não é sobrescrito.

-- ---------------------------------------------------------------------------
-- Parâmetros: os números das regras ficam aqui, não no código das views.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS trat.parametro (
  chave         text PRIMARY KEY,
  valor         numeric NOT NULL,
  descricao     text NOT NULL,
  atualizado_em timestamptz NOT NULL DEFAULT now()
);

INSERT INTO trat.parametro (chave, valor, descricao) VALUES
  ('variacao_estavel_pct',   2,  'Variação (em %, valor absoluto) abaixo da qual a comparação é "estável". Provisório.'),
  ('reavaliacao_dias',       90, 'Dias após a última avaliação para a reavaliação vencer. Provisório.'),
  ('reavaliacao_aviso_dias', 30, 'Dias de antecedência em que a reavaliação aparece como "a vencer". Provisório.')
ON CONFLICT (chave) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Catálogo de regras por teste.
-- O banco do app não grava unidade nem direção do teste, então estas regras
-- são HIPÓTESES, marcadas como não confirmadas até a PKZ validar.
-- O código de cada teste precisa bater com a métrica do banco novo
-- (tabela de métricas do grupo de Banco de Dados). Ajustar quando o DDL chegar.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS trat.catalogo_teste (
  codigo          text PRIMARY KEY,              -- código usado nas views da api (ex.: sprint_20m)
  nome            text NOT NULL,                 -- nome exibido no relatório
  unidade_padrao  text NOT NULL,                 -- s, cm, m ou pontos
  maior_melhor    boolean,                       -- true: maior é melhor; false: menor é melhor; NULL: não se classifica (medida antropométrica)
  faixa_min       numeric,                       -- faixa plausível, na unidade padrão; fora dela vai para revisão
  faixa_max       numeric,
  regra_conversao text,                          -- como padronizar a unidade quando a origem mistura (texto, aplicado na view de medidas)
  usa_media       boolean NOT NULL DEFAULT false,-- false: melhor tentativa válida; true: média das tentativas
  confirmado      boolean NOT NULL DEFAULT false,-- true só depois da PKZ validar unidade, direção e faixa
  observacao      text,
  atualizado_em   timestamptz NOT NULL DEFAULT now()
);

-- Faixas e conversões vêm das anomalias encontradas nas 59 avaliações da cópia de
-- desenvolvimento (AP1): saltos em m e cm no mesmo teste, VO2 em km e m, tempos impossíveis.
INSERT INTO trat.catalogo_teste
  (codigo, nome, unidade_padrao, maior_melhor, faixa_min, faixa_max, regra_conversao, observacao) VALUES
  ('sprint_10m',          'Sprint 10 m',          's',      false, 1.2,  4.0,  'mm:ss vira segundos; vírgula decimal vira ponto',                         'Ex.: 10 m em 17 s é impossível e vai para revisão.'),
  ('sprint_20m',          'Sprint 20 m',          's',      false, 2.3,  6.0,  'mm:ss vira segundos; vírgula decimal vira ponto',                         NULL),
  ('agilidade',           'Agilidade',            's',      false, 5.0,  25.0, 'mm:ss vira segundos; vírgula decimal vira ponto',                         'Confirmar com a PKZ qual é o protocolo (nome do teste no app).'),
  ('slalom',              'Slalom',               's',      false, 5.0,  60.0, 'mm:ss vira segundos; vírgula decimal vira ponto',                         'Ex.: valor 400 é impossível e vai para revisão.'),
  ('salto_horizontal',    'Salto horizontal',     'cm',     true,  50,   350,  'valor abaixo de 10 está em metros: multiplicar por 100',                   'Origem mistura 1,22 (m) e 545 (cm).'),
  ('salto_vertical',      'Salto vertical',       'cm',     true,  10,   100,  'valor abaixo de 2 está em metros: multiplicar por 100',                    NULL),
  ('cross_hop',           'Cross hop',            'cm',     true,  100,  600,  'valor abaixo de 10 está em metros: multiplicar por 100',                   'Origem mistura 4,01 (m) e 543 (cm); sem conversão daria melhora de 13.000%.'),
  ('vo2_distancia',       'VO2 (distância)',      'm',      true,  400,  4000, 'valor abaixo de 10 está em km: multiplicar por 1000',                      'Origem mistura 1,02 (km) e 2.880 (m). Confirmar o protocolo (tempo fixo?).'),
  ('aquabag_estabilidade','Aquabag (estabilidade)','pontos', true,  0,    6,    NULL,                                                                      'Escala de 0 a 6 no app; o que ela mede ainda não foi confirmado com a PKZ.'),
  ('altura',              'Altura',               'cm',     NULL,  90,   220,  'valor abaixo de 3 está em metros: multiplicar por 100',                    'Medida antropométrica: aparece no relatório, mas não é classificada.')
ON CONFLICT (codigo) DO NOTHING;
