from sqlalchemy import create_engine

def load_to_postgres(df, connection_string):
    print('Cargando Datos a Postgres...')
    engine = create_engine(connection_string)

    df.to_sql('stg_refacciones_inventario', con=engine, if_exists='replace', index=False)
    print('[ETL] Carga de datos completada con exito en la tabla -stg_refacciones_inventario- ')
