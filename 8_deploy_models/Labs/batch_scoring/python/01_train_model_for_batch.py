# Create and Save Binary Classifier for Batch Scoring

# To execute this program:
# 1. Open up a terminal and navigate to the lab directory with the following statement:
#      cd ~/ds_notebooks/8_deploy_models/Labs/batch_scoring/python
# 2. Execute the command below in the terminal window:
#      python 01_train_model_for_batch.py

# The program executes the steps below:
# 1. Connect
# 2. Get Data
# 3. Feature Engineering
# 4. Train Model
# 5. Save Model


# 1. Connect

import snowflake.connector
from snowflake.connector import pandas_tools
import pandas as pd
import pickle

config_dir = '/home/jovyan/.ssh'
configfile = config_dir + '/sf_config'

# Get connection details

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


# 2. Get Data

churn_df = pd.read_sql("select * from data_science_db.public.customer_churn", con)


# 3. Feature Engineering

churn_features = churn_df.drop(columns=['CUSTOMER_ID', 'SURNAME_MASKED'])

churn_features[['CHURNED', 'TENURE', 'NUM_OF_PRODUCTS', 'MILEAGE_POINTS', 'ESTIMATED_SALARY']] = \
    churn_features[['CHURNED', 'TENURE', 'NUM_OF_PRODUCTS', 'MILEAGE_POINTS', 'ESTIMATED_SALARY']].apply(pd.to_numeric)

churn_features = pd.get_dummies(churn_features)


# 4. Train Model

from sklearn.naive_bayes import GaussianNB
gnb = GaussianNB()

X, y = churn_features.drop(columns=['CHURNED']), churn_features['CHURNED']

gnb_model = gnb.fit(X, y) # Using all available data


# 5. Save Model

f = open('batch_model_py.pkl', 'wb')
pickle.dump(gnb_model, f)
f.close()
