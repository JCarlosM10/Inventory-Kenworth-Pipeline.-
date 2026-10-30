-- CTE COMPUESTA: Rotación de inventarios y cobertura de stock
WITH StockMetrics AS (
    SELECT
        sucursal,
        categoria,
        COUNT(refaccion_id) AS total_skus,
        SUM(stock_actual) AS total_unidades_stock,
        SUM(ventas_ultimo_mes) AS total_unidades_vendidas,
        SUM(valor_inventario_total) AS capital_invertido_usd
    FROM stg_refacciones_inventario
    GROUP BY sucursal, categoria
),
TurnoverCalculations AS (
    SELECT
        sucursal,
        categoria,
        total_skus,
        total_unidades_stock,
        total_unidades_vendidas,
        capital_invertido_usd,
        CASE
            WHEN total_unidades_stock > 0 THEN ROUND((total_unidades_vendidas::numeric / total_unidades_stock::numeric), 2)
            ELSE 0
        END AS indice_rotacion
    FROM StockMetrics
)
SELECT *,
    CASE
        WHEN indice_rotacion < 0.5 THEN 'BAJA ROTACION / RIESGO de OBSOLECENCIA'
        WHEN indice_rotacion BETWEEN 0.5 AND 1.5 THEN 'ROTACION SALUDABLE'
        ELSE 'ALTA ROTACION / RIESGO DESABASTO'
    END AS diagnostico_categoria
FROM TurnoverCalculations
ORDER BY capital_invertido_usd DESC;
