-- CTE y WINDOW FUNCTION: renking de refacciones con mayor valor por sucursal
WITH ValuedInventory AS (
    SELECT
        sucursal,
        refaccion_id,
        nombre_parte,
        categoria,
        stock_actual,
        costo_unitario_usd,
        (stock_actual * costo_unitario_usd) AS valor_total_usd,
        DENSE_RANK() OVER(
            PARTITION BY sucursal
            ORDER BY (stock_actual * costo_unitario_usd) DESC
        ) AS rank_valor
    FROM stg_refacciones_inventario
)
SELECT  
    sucursal, 
    rank_valor, 
    refaccion_id, 
    nombre_parte, 
    categoria, 
    stock_actual, 
    valor_total_usd 
FROM ValuedInventory 
WHERE rank_valor <= 3 
ORDER BY sucursal, rank_valor;