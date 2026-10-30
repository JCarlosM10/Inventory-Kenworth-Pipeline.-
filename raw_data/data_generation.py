import json
import random
from datetime import datetime, timedelta
import pandas as pd


# API Extraction simulation function

def fetch_inventory():
    print('[ETL] Extrayendo datos de la API de refacciones...')
    sucursales = ['Comanjilla', 'Leon Centro', 'Silao Ops', 'Celaya Hub']
    categorias = ['Sistema de frenos', 'Motor PACCAR', 'Filtracion', 'Suspension', 'Electrico']

    data = []

    for i in range(1, 101):
        stock_actual = random.randint(0,50)
        stock_minimo = random.randint(5,15)
        precio_unitario = round(random.uniform(50.00, 3500.00), 2)

        item = {
            'refaccion_id' : f'KW-{1000+i}',
            'nombre_parte' : f'componente_{i}',
            'categoria' : random.choice(categorias),
            'sucursal' : random.choice(sucursales),
            'stock_actual' : stock_actual,
            'stock_minimo' : stock_minimo,
            'costo_unitario_usd' : precio_unitario,
            'ventas_ultimo_mes' : random.randint(0,80),
            'fecha_ultima_actualizacion' : (datetime.now() - timedelta(days=random.randint(0,30))).strftime('%Y-%m-%d')
        }
        data.append(item)

    return data

pd.DataFrame(fetch_inventory()).to_json('raw_data/inventory_data_raw.json', orient='records', indent=4)