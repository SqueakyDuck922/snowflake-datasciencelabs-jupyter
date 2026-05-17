''' pipeline_string_to_upper.py '''

# Module defining custom class for use a machine learning pipeline
from typing import Iterable
from snowflake.snowpark import DataFrame
from snowflake.snowpark.functions import upper

class StringToUpper():
    def __init__(self, 
                 input_cols: Iterable[str]=None, 
                 output_cols: Iterable[str]=None):
        self.input_cols = input_cols
        self.output_cols = output_cols
        
    def get_input_cols(self):
        return self.input_cols
    
    def get_output_cols(self):
        return self.output_cols
    
    def fit(self, dataset: DataFrame):
        return self
    
    def transform(self, dataset: DataFrame):
        for i in range(len(self.input_cols)):
            dataset = dataset.with_column(self.output_cols[i], upper(dataset[self.input_cols[i]])) 
        return dataset