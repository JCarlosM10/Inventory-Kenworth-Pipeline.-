import pandas as pd

from credenciales import crear_db_conn
from load_SQL import load_to_postgres


if __name__ == '__main__':
    try:
        DB_CONN = crear_db_conn()
        clean_df = pd.read_json('backup_refacciones.json')
        load_to_postgres(clean_df, DB_CONN)

        print(clean_df[['refaccion_id', 'sucursal', 'stock_actual', 'estado_inventario', 'valor_inventario_total']].head())

    except Exception as e:
        print(f'Error en el pipeline ETL {e}')
