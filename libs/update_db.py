import numpy as np
import pandas as pd
from collections import Counter
from urllib.parse import quote_plus
from sqlalchemy.engine import create_engine
from sqlalchemy import text
import os
import requests
from dotenv import load_dotenv

load_dotenv()  # take environment variables from .env file in root directory of repo
dbpass = os.getenv("dbpass") 

#basepath='/Users/marinafrants/Documents/CalCOFI/'
#dirpath=f'{basepath}DBqueryTables/' #directory where the csv files are read from
basepath = '/share/data/'
dirpath=f'{basepath}data_uploads'

def get_dbconnection():
    engine = create_engine("postgresql+psycopg2://admin:%s@localhost/gis" % quote_plus(dbpass))
    dbConnection = engine.connect()
    return dbConnection

def get_taxon_ranks(st_df):
    # placeholder until I can get ITIS to work
    URL = 'https://itis.gov/ITISWebService/jsonservice/getTaxonomicRankNameFromTSN'
    ranks=[]
    lim=len(st_df)
    itis_ids=st_df['itis_tsn']
    for ii in range(lim):
        ranks.append('')
    st_df['taxon_rank'] = ranks
    return st_df

def fill_gebco_depth(st_df):
    file2read = nc.Dataset(
        f'{basepath}GEBCO_11_Oct_2023_404cffc44b29/gebco_2023_n46.9336_s15.293_w-136.582_e-104.2383.nc',
        'r')
    lat = np.array(file2read.variables['lat'])
    lon = np.array(file2read.variables['lon'])
    el = np.array(file2read.variables['elevation'])
    lim=len(st_df)
    gebco_depth=[]
    for ii in range(lim):
        lon_input = st_df.iloc[ii]['longitude']
        lat_input = st_df.iloc[ii]['latitude']
        lat_index = np.nanargmin((lat - lat_input) ** 2)
        long_index = np.nanargmin((lon - lon_input) ** 2)
        gebco_depth.append(el[lat_index][long_index] * -1)

    st_df['gebco_depth'] = gebco_depth
    return st_df

def update_table(tablename, filename):
    '''filename: name of .csv file containing the new data
       clear the data currently in table and replace with new values from file'''
    fpath=os.path.join(dirpath,filename)
    data_df = pd.read_csv(fpath)
    table_fields = [s.lower() for s in data_df.columns.tolist()]
    data_df.columns = table_fields
    print(table_fields)


    with get_dbconnection() as conn:
        sql = f"SELECT table_schema, table_name, column_name, data_type FROM INFORMATION_SCHEMA.COLUMNS WHERE table_schema = 'public' AND table_name = '{tablename}'"
        db_df = pd.read_sql(sql, conn)
        db_fields = db_df['column_name'].tolist()
        print(db_fields)

        #Additional processing for gebco depth and geom columns, if needed
        if (('gebco_depth' in db_fields) and ('gebco_depth' not in table_fields)):
            data_df = fill_gebco_depth(data_df)
        if (('geom' in db_fields) and ('geom' not in table_fields)):
            data_df['geom']=np.nan

        # Additional processing for taxon_rank, if needed (for species table)
        # Currently not working because of security certificate issues
        # So just fill in empty string for taxon rank, it doesn't seem to be
        # in use anyway
        if(('taxon_rank' in db_fields) and ('taxon_rank' not in table_fields)):
            data_df = get_taxon_ranks(data_df)
            data_df.reset_index(drop=True, inplace=True)
            data_df['id']=data_df.index

        table_fields = [s.lower() for s in data_df.columns.tolist()]

        # Check if fields match
        if Counter(db_fields) != Counter(table_fields):
            print('Table fields mismatch -- update failed')
            print(f'Database columns are: {db_fields}')
            print(f'Table columns are: {table_fields}')
        else:
            print('Fields match, updating table...')
            print('Clear data from table')
            sql=text(f"TRUNCATE TABLE {tablename};")
            conn.execution_options(autocommit=True).execute(sql)
            print('Write new data')
            rcount=data_df.to_sql(name=tablename,con=conn, if_exists='append', index=False, chunksize=500)
            if('geom' in db_fields):
                # Recalculate geometry column
                print('Table has geometry column, recalculating values...')
                sql=(f"UPDATE {tablename}  SET geom = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326);")
                conn.execution_options(autocommit=True).execute(sql)
            print('All done!')


if __name__ == "__main__":
    import sys
    csvfile = sys.argv[1]
    table = sys.argv[2]

    update_table(table, csvfile)
