--ALERTA OPERATIVA: Refacciones Críticas en Desabasto o Punto de Reorden 
SELECT  
    sucursal, 
    refaccion_id, 
    nombre_parte, 
    categoria, 
    stock_actual, 
    stock_minimo, 
    ventas_ultimo_mes, 
    estado_inventario, 
    ROUND((stock_actual::numeric / NULLIF(ventas_ultimo_mes, 0)) * 30, 1) AS dias_cobertura_estimados 
FROM stg_refacciones_inventario 
WHERE estado_inventario IN ('DESABASTO_CRITICO', 'REORDEN_REQUERIDO') 
ORDER BY stock_actual ASC, ventas_ultimo_mes DESC; 