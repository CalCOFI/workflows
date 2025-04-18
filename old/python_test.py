# load python libraries
import psycopg2
# import sys
# import os
# import datetime
# import time
# import csv
# import pandas
# import numpy
# import matplotlib
# import seaborn
# import sklearn
# import statsmodels

# set variables
dbname      = 'gis'
host        = 'localhost' 
port        = 5432
user        = 'admin'
db_pass_txt = '/Users/bbest/My Drive/private/calcofi_password.txt'

# read database password
with open(db_pass_txt, 'r') as f:
    db_pass = f.read().strip('\n')

# connect to a postgres database
con = psycopg2.connect(f'host={host} dbname={dbname} user={user} password={db_pass}')

# list tables in database and load into pandas dataframe
cur = con.cursor()
cur.execute("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")
tables = cur.fetchall()
