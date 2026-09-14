-- ============================================================================
-- MINI-PROJETO Modulo II - Pata Amiga
-- 05-respostas-negocio.sql
-- Responde as cinco perguntas de negocio a partir do modelo estrela.
-- Pre-requisitos: arquivos 01, 02, 03 e 04 executados com sucesso.
-- Regra do edital: sem CTE (WITH) e sem window function em lugar nenhum.
-- Subconsulta e permitida apenas aqui, nas perguntas de negocio.
-- ============================================================================


-- ============================================================================
-- RECONCILIACAO INICIAL (nao e uma das 5 perguntas; confere a base antes)
-- ============================================================================
SELECT
    'Faturamento Total da Rede' AS metrica,
    ROUND(SUM(vl_liquido), 2)   AS valor
FROM fato_pedido;


-- ============================================================================
-- P1 - Onde esta o gargalo da entrega?
-- Uma unica consulta responde as tres partes da pergunta:
--   1) tempo medio total ate a entrega (linha etapa = 'TOTAL...', grupo = 'Rede Toda')
--   2) qual das 4 etapas e a mais lenta (compare as 4 linhas de etapa dentro de 'Rede Toda')
--   3) se o gargalo se repete nos 3 portes (compare as mesmas 4 etapas dentro
--      de cada porte)
-- Formato do resultado: grupo | etapa | ordem_etapa | media_dias
-- Grafico: Eixo X = etapa | Eixo Y = media_dias | Serie/cor = grupo
-- (pedidos com entrega ainda nao concluida, sk_tempo_entrega = -1, entram
-- com dias_* = NULL e sao ignorados automaticamente pelo AVG(); pedidos sem
-- loja identificada, sk_loja = -1, ficam fora das linhas por porte, pois nao
-- tem porte, mas continuam dentro de 'Rede Toda')
-- ============================================================================
SELECT 'Rede Toda' AS grupo, 'Integracao -> Separacao' AS etapa, 1 AS ordem_etapa,
       ROUND(AVG(dias_integracao_separacao), 2) AS media_dias
FROM fato_pedido

UNION ALL

SELECT 'Rede Toda', 'Separacao -> Nota', 2,
       ROUND(AVG(dias_separacao_nota), 2)
FROM fato_pedido

UNION ALL

SELECT 'Rede Toda', 'Nota -> Despacho', 3,
       ROUND(AVG(dias_nota_despacho), 2)
FROM fato_pedido

UNION ALL

SELECT 'Rede Toda', 'Despacho -> Entrega', 4,
       ROUND(AVG(dias_despacho_entrega), 2)
FROM fato_pedido

UNION ALL

SELECT 'Rede Toda', 'TOTAL (Integracao->Entrega)', 5,
       ROUND(AVG(dias_total_ate_entrega), 2)
FROM fato_pedido

UNION ALL

SELECT l.porte, 'Integracao -> Separacao', 1,
       ROUND(AVG(f.dias_integracao_separacao), 2)
FROM fato_pedido f
JOIN dim_loja l ON l.sk_loja = f.sk_loja
WHERE l.sk_loja <> -1
GROUP BY l.porte

UNION ALL

SELECT l.porte, 'Separacao -> Nota', 2,
       ROUND(AVG(f.dias_separacao_nota), 2)
FROM fato_pedido f
JOIN dim_loja l ON l.sk_loja = f.sk_loja
WHERE l.sk_loja <> -1
GROUP BY l.porte

UNION ALL

SELECT l.porte, 'Nota -> Despacho', 3,
       ROUND(AVG(f.dias_nota_despacho), 2)
FROM fato_pedido f
JOIN dim_loja l ON l.sk_loja = f.sk_loja
WHERE l.sk_loja <> -1
GROUP BY l.porte

UNION ALL

SELECT l.porte, 'Despacho -> Entrega', 4,
       ROUND(AVG(f.dias_despacho_entrega), 2)
FROM fato_pedido f
JOIN dim_loja l ON l.sk_loja = f.sk_loja
WHERE l.sk_loja <> -1
GROUP BY l.porte

UNION ALL

SELECT l.porte, 'TOTAL (Integracao->Entrega)', 5,
       ROUND(AVG(f.dias_total_ate_entrega), 2)
FROM fato_pedido f
JOIN dim_loja l ON l.sk_loja = f.sk_loja
WHERE l.sk_loja <> -1
GROUP BY l.porte

ORDER BY grupo, ordem_etapa;


-- ============================================================================
-- P2 - Qual categoria concentra o faturamento?
-- Uma unica consulta responde as duas partes da pergunta:
--   1) faturamento e % do total por categoria padronizada, na rede toda
--      (linhas com grupo = 'Rede Toda')
--   2) se a categoria campea se repete nos 3 portes (compare, dentro de cada
--      porte, qual categoria tem a maior barra de faturamento)
-- Formato do resultado: grupo | nome_categoria | faturamento | percentual_do_grupo
-- Grafico 2.1: filtre grupo = 'Rede Toda' | Eixo X = nome_categoria | Eixo Y = faturamento
-- Grafico 2.2: Eixo X = nome_categoria | Eixo Y = faturamento | Serie/cor = grupo
--              (a categoria com a barra mais alta em cada porte e a campea)
-- ============================================================================
SELECT
    'Rede Toda' AS grupo,
    c.nome_categoria,
    ROUND(SUM(f.vl_liquido), 2) AS faturamento,
    ROUND(
        SUM(f.vl_liquido) / (SELECT SUM(vl_liquido) FROM fato_pedido) * 100, 2
    ) AS percentual_do_grupo
FROM fato_pedido f
JOIN dim_categoria c ON c.sk_categoria = f.sk_categoria
GROUP BY c.nome_categoria

UNION ALL

SELECT
    l.porte AS grupo,
    c.nome_categoria,
    ROUND(SUM(f.vl_liquido), 2) AS faturamento,
    ROUND(
        SUM(f.vl_liquido) / (
            SELECT SUM(f2.vl_liquido)
            FROM fato_pedido f2
            JOIN dim_loja l2 ON l2.sk_loja = f2.sk_loja
            WHERE l2.porte = l.porte AND l2.sk_loja <> -1
        ) * 100, 2
    ) AS percentual_do_grupo
FROM fato_pedido f
JOIN dim_categoria c ON c.sk_categoria = f.sk_categoria
JOIN dim_loja l ON l.sk_loja = f.sk_loja
WHERE l.sk_loja <> -1
GROUP BY l.porte, c.nome_categoria

ORDER BY grupo, faturamento DESC;


-- ============================================================================
-- P3 - O desconto funciona igual em todo canal?
-- Uma unica consulta responde as duas partes da pergunta:
--   1) ticket medio COM e SEM desconto, por canal (colunas ticket_medio,
--      agrupado por canal_pedido + houve_desconto)
--   2) participacao de cada canal no faturamento total da rede
--      (colunas faturamento_canal e percentual_canal_do_total, repetidas nas
--      duas linhas do mesmo canal, calculadas por subconsulta correlacionada)
-- Formato do resultado: canal_pedido | houve_desconto | total_pedidos |
--                        ticket_medio | faturamento_canal | percentual_canal_do_total
-- Grafico 3.1: Eixo X = canal_pedido | Eixo Y = ticket_medio | Serie/cor = houve_desconto
-- Grafico 3.2: Eixo X = canal_pedido | Eixo Y = percentual_canal_do_total
--              (repete o mesmo valor nas 2 linhas do canal; escolha uma so,
--              ex. filtrando houve_desconto = 'Sim', para nao contar 2x)
-- ============================================================================
SELECT
    fp.canal_pedido,
    fp.houve_desconto,
    COUNT(*)                  AS total_pedidos,
    ROUND(AVG(fp.vl_liquido), 2) AS ticket_medio,
    (SELECT ROUND(SUM(f2.vl_liquido), 2)
       FROM fato_pedido f2
       WHERE f2.canal_pedido = fp.canal_pedido) AS faturamento_canal,
    (SELECT ROUND(SUM(f2.vl_liquido) / (SELECT SUM(vl_liquido) FROM fato_pedido) * 100, 2)
       FROM fato_pedido f2
       WHERE f2.canal_pedido = fp.canal_pedido) AS percentual_canal_do_total
FROM fato_pedido fp
WHERE fp.houve_desconto IN ('Sim', 'Nao')
GROUP BY fp.canal_pedido, fp.houve_desconto
ORDER BY fp.canal_pedido, fp.houve_desconto;


-- ============================================================================
-- P4 - Qual praca de atendimento concentra o faturamento?
-- Uma loja pode entregar em mais de uma praca: o rateio usa o fator_publico
-- da ponte bridge_loja_praca. Pedidos sem loja (sk_loja = -1) nao entram no
-- rateio por praca, pois nao existe fator de rateio para eles.
-- Formato do resultado: nome_praca | regional | domicilios_com_pet |
--                        faturamento_rateado | faturamento_por_domicilio_com_pet
-- Grafico 4.1: Eixo X = nome_praca | Eixo Y = faturamento_rateado
-- Grafico 4.2: Eixo X = domicilios_com_pet | Eixo Y = faturamento_rateado (dispersao)
-- ============================================================================
SELECT
    p.nome_praca,
    p.regional,
    p.domicilios_com_pet,
    ROUND(SUM(f.vl_liquido * b.fator_publico), 2) AS faturamento_rateado,
    ROUND(
        SUM(f.vl_liquido * b.fator_publico) / NULLIF(p.domicilios_com_pet, 0), 4
    ) AS faturamento_por_domicilio_com_pet
FROM fato_pedido f
JOIN dim_loja l          ON l.sk_loja = f.sk_loja
JOIN bridge_loja_praca b ON b.cod_loja = l.cod_loja
JOIN dim_praca p         ON p.sk_praca = b.sk_praca
WHERE f.sk_loja <> -1
GROUP BY p.nome_praca, p.regional, p.domicilios_com_pet
ORDER BY faturamento_rateado DESC;


-- ============================================================================
-- P5 - Onde abrir a proxima loja, e o que os dados NAO permitem afirmar?
-- Esta e a UNICA pergunta que o proprio edital divide em letras (a, b, c),
-- entao as tres consultas abaixo seguem a numeracao oficial do enunciado.
-- ============================================================================

-- P5.a - Ranking de lojas por itens vendidos por MIL HABITANTES da cidade
-- (nao em valor absoluto), cruzado com o tempo medio de entrega.
-- Grafico: Eixo X = itens_por_mil_habitantes | Eixo Y = tempo_medio_entrega_dias (dispersao)
SELECT
    l.nome_loja,
    l.cidade,
    l.populacao_cidade,
    SUM(f.qt_itens)                                            AS itens_vendidos,
    ROUND(SUM(f.qt_itens) / (l.populacao_cidade / 1000.0), 4)  AS itens_por_mil_habitantes,
    ROUND(AVG(f.dias_total_ate_entrega), 2)                    AS tempo_medio_entrega_dias
FROM fato_pedido f
JOIN dim_loja l ON l.sk_loja = f.sk_loja
WHERE l.sk_loja <> -1
GROUP BY l.nome_loja, l.cidade, l.populacao_cidade
ORDER BY itens_por_mil_habitantes DESC;

-- P5.b - Faturamento por faixa de franquia ATUAL (Diamante/Ouro/Prata/Bronze).
-- ATENCAO / LIMITACAO DO DADO: a coluna faixa_franquia em dim_loja e uma foto
-- de HOJE. O cadastro de origem nao guarda historico: se uma loja mudou de
-- faixa ao longo do periodo analisado, o passado foi SOBRESCRITO. Por isso,
-- esta consulta responde "quanto a faixa ATUAL fatura", e NAO responde
-- "quanto veio de lojas que JA ERAM Ouro na data do pedido" -- exigiria uma
-- dimensao de loja com historico (SCD Tipo 2), que este modelo nao tem.
-- Grafico: Eixo X = faixa_franquia | Eixo Y = faturamento_atual
SELECT
    l.faixa_franquia,
    COUNT(f.sk_pedido)          AS total_pedidos,
    ROUND(SUM(f.vl_liquido), 2) AS faturamento_atual
FROM fato_pedido f
JOIN dim_loja l ON l.sk_loja = f.sk_loja
WHERE l.sk_loja <> -1
GROUP BY l.faixa_franquia
ORDER BY faturamento_atual DESC;

-- P5.c - O que ficou de fora: mede a lacuna dos dados, para deixar claro o
-- que NAO pode ser afirmado com o que se tem hoje.
-- Grafico: Eixo X = lacuna | Eixo Y = quantidade
SELECT 'Pedidos sem loja identificada (sk_loja = -1)' AS lacuna,
       COUNT(*) AS quantidade
FROM fato_pedido WHERE sk_loja = -1
UNION ALL
SELECT 'Entregas ainda nao concluidas (sk_tempo_entrega = -1)',
       COUNT(*)
FROM fato_pedido WHERE sk_tempo_entrega = -1
UNION ALL
SELECT 'Pedidos com quantidade de itens em branco (qt_itens NULL)',
       COUNT(*)
FROM fato_pedido WHERE qt_itens IS NULL
UNION ALL
SELECT 'Pedidos com valor liquido em branco (vl_liquido NULL)',
       COUNT(*)
FROM fato_pedido WHERE vl_liquido IS NULL;


-- ============================================================================
-- VERIFICACAO DE INTEGRIDADE (nao e uma das 5 perguntas; apoia a secao 8 do
-- edital, "Numeros de Conferencia": confirma que o rateio por praca fecha
-- com o faturamento dos pedidos com loja identificada -- diferenca tem de dar 0)
-- ============================================================================
SELECT
    (SELECT ROUND(SUM(vl_liquido), 2) FROM fato_pedido WHERE sk_loja <> -1) AS faturamento_com_loja,
    (SELECT ROUND(SUM(f.vl_liquido * b.fator_publico), 2)
       FROM fato_pedido f
       JOIN dim_loja l          ON l.sk_loja = f.sk_loja
       JOIN bridge_loja_praca b ON b.cod_loja = l.cod_loja
       WHERE f.sk_loja <> -1) AS soma_rateada_por_praca,
    ROUND(
        (SELECT SUM(vl_liquido) FROM fato_pedido WHERE sk_loja <> -1)
        - (SELECT SUM(f.vl_liquido * b.fator_publico)
             FROM fato_pedido f
             JOIN dim_loja l          ON l.sk_loja = f.sk_loja
             JOIN bridge_loja_praca b ON b.cod_loja = l.cod_loja
             WHERE f.sk_loja <> -1)
    , 2) AS diferenca_tem_de_dar_ZERO;