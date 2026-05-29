# Create and Save Binary Classifier for Batch Scoring

# To execute this program:
# 1. Open up a terminal and navigate to the lab directory with the following statement:
#      cd ~/ds_notebooks/8_deploy_models/Labs/batch_scoring/r
# 2. Execute the command below in the terminal window:
#      R -f 01_train_model_for_batch.R

# The program executes the steps below:
# 1. Connect
# 2. Get Data
# 3. Feature Engineering
# 4. Train Model
# 5. Save Model


# 1. Connect

library(DBI)
library(tidyverse)
library(tidymodels)

config_dir = "/home/jovyan/.ssh"
config_file = paste0(config_dir, "/sf_config")
key_file = paste0(config_dir, "/rsa_key.pem")

props = read.delim(config_file, header=FALSE, sep="=")

account = props[props$V1=="ACCOUNT", 2]
user = props[props$V1=="USER", 2]

conn <- dbConnect(
          odbc::odbc(),
          .connection_string = sprintf(
              "Driver={SnowflakeDSIIDriver};
               server={%s};
               uid={%s};
               authenticator=snowflake_jwt;
               priv_key_file={%s};
               database=DATA_SCIENCE_DB;
               schema=PUBLIC",               
              paste0(account, '.snowflakecomputing.com'),
              user,
              key_file),
          timeout = 10)

# 2. Get Data

churn_df <-  conn %>% dbGetQuery("SELECT *
                                 FROM DATA_SCIENCE_DB.PUBLIC.CUSTOMER_CHURN")


# 3. Feature Engineering

churn_features <- churn_df %>%
    select(CHURNED, CREDIT_SCORE:ESTIMATED_SALARY) %>%
    mutate(across( c(TENURE, NUM_OF_PRODUCTS, ESTIMATED_SALARY), as.numeric)) %>%
    mutate(across( c(GEOGRAPHY, GENDER, HAS_AIRLINE_CREDIT_CARD, IS_ACTIVE_MEMBER, CHURNED), as.factor))


# 4. Train Model

log_reg_mod <- logistic_reg() %>%
                set_engine("glm") %>%
                set_mode("classification")

log_reg_fit <- log_reg_mod %>%
                fit(CHURNED ~ ., data = churn_features)


# 5. Save Model

saveRDS(log_reg_fit, "model.rds")
