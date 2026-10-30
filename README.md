# Inventory API — análisis de inventario de refacciones

## Descripción

Proyecto de ejemplo que simula la extracción de inventario de refacciones, transforma los registros con Python y pandas, genera respaldos CSV/JSON y prepara una tabla de staging para PostgreSQL. Incluye consultas SQL para analizar rotación, valor de inventario y riesgo de desabasto.

La extracción es **sintética**: no consume una API externa ni representa datos operativos reales. El generador crea registros aleatorios, por lo que cada ejecución puede producir resultados diferentes.

## Flujo de datos

1. **Generación / extracción simulada**
   - [`raw_data/data_generation.py`](./raw_data/data_generation.py) define `fetch_inventory()`.
   - Genera 100 refacciones con IDs `KW-1001` a `KW-1100`, nombre de componente, categoría, sucursal, existencias, mínimo, costo unitario en USD, ventas del último mes y fecha de actualización.
   - Usa cuatro sucursales (`Comanjilla`, `Leon Centro`, `Silao Ops`, `Celaya Hub`) y cinco categorías (`Sistema de frenos`, `Motor PACCAR`, `Filtracion`, `Suspension`, `Electrico`).
   - Los valores aleatorios incluyen stock actual de 0 a 50, stock mínimo de 5 a 15, costo unitario de USD 50 a USD 3,500, ventas mensuales de 0 a 80 y fechas dentro de los últimos 30 días. No se fija una semilla aleatoria.
   - La función devuelve los datos en memoria; por sí sola no escribe archivos.

2. **Limpieza y transformación**
   - [`etl_refacciones.py`](./etl_refacciones.py) (not commited) contiene la ruta principal: genera los registros, convierte `fecha_ultima_actualizacion` a fecha, calcula `valor_inventario_total = stock_actual * costo_unitario_usd` y asigna `estado_inventario`.
   - La regla de estado de este script es:
     - `DESABASTO_CRITICO`: stock igual a 0.
     - `REORDEN_REQUERIDO`: stock menor o igual al mínimo.
     - `SOBRESTOCK`: stock mayor a tres veces el mínimo.
     - `NORMAL`: cualquier otro caso.
   - Al ejecutarse, guarda `backup_refacciones.csv` en el directorio actual y reemplaza la tabla `stg_refacciones_inventario` en PostgreSQL.
   - [`ETL_inventory.ipynb`](./ETL_inventory.ipynb) es otra ruta que lee [`raw_data/inventory_data_raw.json`](./raw_data/inventory_data_raw.json), convierte la fecha, calcula el valor del inventario y produce respaldos CSV y JSON. Su regla de estados no coincide con la del script: clasifica como sobrestock cualquier stock por encima del mínimo, y utiliza etiquetas con espacios/acento en algunos estados. Tenerlo en cuenta al comparar sus salidas.

3. **Análisis SQL**
   Las consultas leen la tabla `stg_refacciones_inventario`:
   - [`queries/Rotacion_inventario.sql`](./queries/Rotacion_inventario.sql): agrupa por sucursal y categoría, calcula unidades disponibles y vendidas, capital invertido e índice de rotación (ventas del último mes / stock actual). Clasifica los grupos como baja rotación, saludable o alta rotación/riesgo de desabasto.
   - [`queries/Ranking_valor_Inventario.sql`](./queries/Ranking_valor_Inventario.sql): usa `DENSE_RANK()` para obtener las tres refacciones con mayor valor por sucursal.
   - [`queries/Alerta_operativa_desabasto.sql`](./queries/Alerta_operativa_desabasto.sql): lista artículos en desabasto crítico o punto de reorden y estima días de cobertura como `stock_actual / ventas_ultimo_mes * 30`. Si las ventas son cero, la cobertura resulta `NULL`.

## Datos y campos transformados

| Campo | Descripción |
|---|---|
| `refaccion_id` | Identificador sintético de la refacción. |
| `nombre_parte` | Nombre sintético del componente. |
| `categoria`, `sucursal` | Clasificación y ubicación del artículo. |
| `stock_actual`, `stock_minimo` | Existencias y umbral mínimo. |
| `costo_unitario_usd` | Costo unitario en dólares estadounidenses. |
| `ventas_ultimo_mes` | Unidades vendidas durante el último mes. |
| `fecha_ultima_actualizacion` | Fecha convertida a tipo fecha durante la transformación. |
| `valor_inventario_total` | Stock actual multiplicado por el costo unitario. |
| `estado_inventario` | Indicador derivado del stock y el mínimo; consultar las reglas y nota de consistencia anteriores. |

## Ejecución

### Requisitos

- Python.
- Paquetes `pandas` y `SQLAlchemy`.
- Un controlador de PostgreSQL compatible con SQLAlchemy.
- Una instancia PostgreSQL y una base de datos accesibles para cargar la tabla de staging.

No hay un archivo de dependencias en el repositorio; instala esos paquetes en el entorno Python antes de ejecutar el pipeline.

### Ejecutar el pipeline principal

Antes de ejecutar cualquiera de los pipelines, crea el módulo local de configuración a partir de la plantilla:

```powershell
Copy-Item credenciales.py.example credenciales.py
```

El archivo local `credenciales.py` está ignorado por Git. `crear_db_conn()` obtiene `DB_USER` y `DB_PASSWORD` del entorno y construye una URL de SQLAlchemy, escapando correctamente caracteres especiales en las credenciales. Este escape no cifra la contraseña: no la guardes en el repositorio ni imprimas la URL en logs. También puedes definir `DB_HOST` (por defecto `localhost`), `DB_PORT` (por defecto `5432`) y `DB_NAME` (por defecto `kenworth_db`).

En PowerShell, configura las variables requeridas para la sesión:

```powershell
$env:DB_USER = "usuario"
$env:DB_PASSWORD = "contraseña"
```

Desde la raíz del proyecto:

```powershell
python main.py
```

Para ejecutar la ruta que genera un inventario nuevo:

```powershell
python etl_refacciones.py
```

El pipeline genera una muestra nueva, escribe `backup_refacciones.csv` en el directorio de ejecución y carga/reemplaza `stg_refacciones_inventario`. El resultado de las consultas requiere que esa tabla esté disponible en la base de datos. Los CSV de `queries/` son exportaciones existentes; el código del proyecto no incluye un ejecutor automático para esas consultas.

## Resultados de las consultas exportadas

Los siguientes resultados se calcularon contando y resumiendo los CSV existentes en [`queries/`](./queries/). Son **snapshots**, no resultados garantizados de una ejecución reproducible:

### Rotación de inventario

La exportación [`result_export_rotacion_inventario.csv`](./queries/result_export_rotacion_inventario.csv) contiene 20 grupos sucursal-categoría:

- 11 grupos con `ALTA ROTACION / RIESGO DESABASTO`.
- 9 grupos con `ROTACION SALUDABLE`.
- No hay grupos etiquetados como baja rotación en esta exportación.
- El índice va de 0.92 a 5.49. El mayor corresponde a Filtracion en Comanjilla (5.49); el menor, a Motor PACCAR en Silao Ops (0.92).

### Ranking por valor

La exportación [`result_export_ranking_valor_inventario.csv`](./queries/result_export_ranking_valor_inventario.csv) contiene 12 filas: tres posiciones por cada una de las cuatro sucursales. El mayor valor individual exportado es KW-1091 en Comanjilla, con USD 158,394.56.

### Alertas operativas

La exportación [`result_export_alerta_operativa_desabasto.csv`](./queries/result_export_alerta_operativa_desabasto.csv) contiene 18 artículos:

- 2 en `DESABASTO_CRITICO`: KW-1048 y KW-1070, ambos con stock cero.
- 16 en `REORDEN_REQUERIDO`.
- Los dos artículos en desabasto tienen cero días estimados de cobertura; algunos artículos en reorden tienen menos de un día.

Como referencia, el respaldo existente [`backup_refacciones.csv`](./backup_refacciones.csv) tiene 100 filas, 2,621 unidades y un valor total calculado de USD 4,778,356.55. Estos totales pertenecen a ese respaldo, no necesariamente a la misma ejecución de los resultados SQL.

## Notas de consistencia

- El generador no fija semilla aleatoria y el script ETL vuelve a generar los datos; por tanto, una ejecución nueva no tiene por qué coincidir con los respaldos o resultados exportados.
- Los respaldos y exportaciones existentes no son una única instantánea consistente: por ejemplo, el CSV de respaldo suma USD 4,778,356.55, mientras que la suma de `capital_invertido_usd` en la exportación de rotación es USD 4,782,256.04.
- Las etiquetas de estado también difieren entre los artefactos: el respaldo incluye `REORDEN REQUERIDO` con espacio, mientras que la consulta SQL filtra `REORDEN_REQUERIDO` con guion bajo. La regla del notebook, la del script ETL y las etiquetas esperadas por la consulta deben unificarse antes de usar el flujo con datos productivos.
- El análisis de rotación divide ventas del último mes entre el stock actual; es un indicador simple para este ejercicio, no una medida de rotación anualizada.