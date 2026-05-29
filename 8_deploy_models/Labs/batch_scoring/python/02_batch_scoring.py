# Batch scoring

# To execute this program:
# 1. Open up a terminal and navigate to the lab directory with the following statement:
#      cd ~/ds_notebooks/8_deploy_models/Labs/batch_scoring/python
# 2. Execute the command below in the terminal window:
#      python 02_batch_scoring.py

# This program predicts churn for new customer data in table
# DATA_SCIENCE_DB.NEW_DATA.CUSTOMERS.

# Then it saves the predictions in table
# [login]_DB.PUBLIC.CHURN_PREDICTIONS_PYTHON

# The program executes the steps below:
# 1. Load model
# 2. Connect
# 3. Load new customer data
# 4. Feature engineering
# 5. Make predictions
# 6. Save predictions

import snowflake.connector
from snowflake.connector import pandas_tools
import pandas as pd
import pickle

config_dir = '/home/jovyan/.ssh'
configfile = config_dir + '/sf_config'


# 1. Load model

with open('batch_model_py.pkl', 'rb') as f:
    model = pickle.load(f)

# 2. Connect

with open(configfile) as f:
    lines = f.readlines()

props = {}
for line in lines:
    (key, value) = line.split('=')
    props.update({key.lower() : value[0:-1]})

# Convert the private key to a DER-encoded bytes object
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend

with open(props['private_key_file'], "rb") as key:
    private_key = serialization.load_pem_private_key(
        key.read(),
        password=None,
        backend=default_backend()
    )
    
private_key_bytes = private_key.private_bytes(
    encoding=serialization.Encoding.DER,
    format=serialization.PrivateFormat.PKCS8,
    encryption_algorithm=serialization.NoEncryption()
)

# Add properly encoded private key to connection properties
props['private_key'] = private_key_bytes

# Keep only user, account, and private_key connection properties
del props['url']
del props['private_key_file']

# Connect to Snowflake
con = snowflake.connector.connect(**(props))


# 3. Load new customer data

new_customers = pd.read_sql("select * from data_science_db.new_data.customers", con)


# 4. Feature engineering

cust_features = new_customers.drop(columns=['CUSTOMER_ID', 'SURNAME_MASKED'])
cust_features[['TENURE', 'NUM_OF_PRODUCTS', 'MILEAGE_POINTS', 'ESTIMATED_SALARY']] = \
    cust_features[['TENURE', 'NUM_OF_PRODUCTS', 'MILEAGE_POINTS', 'ESTIMATED_SALARY']].apply(pd.to_numeric)
cust_features = pd.get_dummies(cust_features)


# 5. Make predictions

prediction_probabilities = model.predict_proba(cust_features)
predictions = model.predict(cust_features)

# Combine predictions with ids
cust_ids = new_customers['CUSTOMER_ID'].to_numpy()
predictions_df = pd.DataFrame({"CUSTOMER_ID" : cust_ids,
                               "PROB_0" : prediction_probabilities[:,0],
                               "PROB_1" : prediction_probabilities[:,1],
                               "PREDICTION" : predictions})

# 6. Save predictions

cur = con.cursor()
cur.execute(f"USE DATABASE {props['user']}_DB;")
cur.execute('USE SCHEMA PUBLIC;')
#cur.execute(f"USE WAREHOUSE {props['warehouse']};")
cur.execute('CREATE OR REPLACE TABLE \
                CHURN_PREDICTIONS_PYTHON( \
                    CUSTOMER_ID STRING, \
                    PROB_0 FLOAT, \
                    PROB_1 FLOAT, \
                    PREDICTION INT)')

pandas_tools.write_pandas(con, predictions_df, "CHURN_PREDICTIONS_PYTHON")
