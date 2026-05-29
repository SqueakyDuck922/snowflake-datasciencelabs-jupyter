# Batch scoring

# To execute this program:
# 1. Open up a terminal and navigate to the lab directory with the following statement:
#      cd ~/ds_notebooks/8_deploy_models/Labs/batch_scoring/r
# 2. Execute the command below in the terminal window:
#      R -f 02_batch_scoring.R

# This program first predicts churn for new customer data in table
# DATA_SCIENCE_DB.NEW_DATA.CUSTOMERS.

# Then it saves the predictions in table
# <user>_DB.PUBLIC.CHURN_PREDICTIONS_R

# This program does the following steps:
# 1. Load model
# 2. Connect
# 3. Load new customer data
# 4. Feature engineering
# 5. Make predictions
# 6. Save predictions


# 1. Load model

model <- readRDS("model.rds")


# 2. Connect

library(DBI)
library(tidyverse)
library(tidymodels)

config_dir = "/home/jovyan/.ssh"
config_file = paste0(config_dir, "/sf_config")
key_file = paste0(config_dir, "/rsa_key.pem")

props = read.delim(config_file, header=FALSE, sep="=")

account = props[props$V1=="ACCOUNT", 2]
user = props[props$V1=="USER", 2]
user_db = paste0(user, "_DB")

conn <- dbConnect(
          odbc::odbc(),
          .connection_string = sprintf(
              "Driver={SnowflakeDSIIDriver};
               server={%s};
               uid={%s};
               authenticator=snowflake_jwt;
               priv_key_file={%s}",
              paste0(account, '.snowflakecomputing.com'),
              user,
              key_file),
          timeout = 10)

# 3. Load new customer data

new_customers <- conn %>%
    dbGetQuery(sql("SELECT * FROM DATA_SCIENCE_DB.NEW_DATA.CUSTOMERS"))


# 4. Feature engineering

new_customer_features <-
    new_customers %>%
    select(CREDIT_SCORE:ESTIMATED_SALARY) %>%
    mutate(across( c(TENURE, NUM_OF_PRODUCTS, ESTIMATED_SALARY), as.numeric)) %>%
    mutate(across( c(GEOGRAPHY, GENDER, HAS_AIRLINE_CREDIT_CARD, IS_ACTIVE_MEMBER), as.factor))


# 5. Make predictions

churn_predictions <-
    predict(model, new_customer_features) %>%
    bind_cols(predict(model, new_customer_features, type="prob")) %>%
    bind_cols(new_customers %>% select(CUSTOMER_ID))

prediction_table <- 
    rename(churn_predictions,
        PREDICTION = .pred_class,
        PROB_0 = .pred_0,
        PROB_1 = .pred_1) %>%
    relocate(CUSTOMER_ID, PROB_0, PROB_1, PREDICTION)   

# 6. Save predictions

sch = "PUBLIC"
table_name = "CHURN_PREDICTIONS_R"
full_table_name = paste0(user_db, ".", sch, ".", table_name)

conn %>% dbGetQuery(sql(paste0("DROP TABLE IF EXISTS ", full_table_name)))

dbWriteTable(conn,
            Id(database = user_db,
              catalog = sch,
              table = table_name),
            prediction_table)

# 7. In the Snowflake UI, navigate to your login database in the PUBLIC schema and view
#    the CHURN_PREDICTIONS_R table to verify the predictions were written.
