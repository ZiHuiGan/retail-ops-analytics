"""
BigQuery data loader for CSV and JSON files
"""

import pandas as pd
import json
from pathlib import Path
from google.cloud import bigquery
from google.oauth2 import service_account


class BigQueryLoader:
    """Load data from CSV and JSON files into BigQuery"""
    
    def __init__(self, project_id, credentials_path):
        """
        Initialize BigQuery loader
        
        Args:
            project_id: GCP project ID
            credentials_path: Path to service account JSON file
        """
        self.project_id = project_id
        credentials = service_account.Credentials.from_service_account_file(
            credentials_path
        )
        self.client = bigquery.Client(
            project=project_id,
            credentials=credentials
        )
    
    def load_csv_to_table(
        self,
        csv_path,
        dataset_id,
        table_id,
        write_disposition="WRITE_APPEND",
        skip_rows=0
    ):
        """
        Load CSV file to BigQuery table
        
        Args:
            csv_path: Path to CSV file
            dataset_id: BigQuery dataset ID
            table_id: BigQuery table ID
            write_disposition: WRITE_APPEND or WRITE_TRUNCATE
            skip_rows: Number of rows to skip (for malformed CSVs)
        """
        print(f"  Loading {Path(csv_path).name}...")
        
        # Read CSV
        df = pd.read_csv(csv_path, skiprows=skip_rows, dtype=str)
        
        # Load to BigQuery
        table_ref = self.client.dataset(dataset_id).table(table_id)
        job_config = bigquery.LoadJobConfig(
            write_disposition=write_disposition,
            autodetect=True
        )
        
        job = self.client.load_table_from_dataframe(df, table_ref, job_config=job_config)
        job.result()  # Wait for job to complete
        
        print(f"  ✅ Loaded {len(df)} rows to {dataset_id}.{table_id}")
    
    def load_json_to_table(
        self,
        json_path,
        dataset_id,
        table_id,
        write_disposition="WRITE_APPEND"
    ):
        """
        Load JSON file to BigQuery table
        
        Args:
            json_path: Path to JSON file
            dataset_id: BigQuery dataset ID
            table_id: BigQuery table ID
            write_disposition: WRITE_APPEND or WRITE_TRUNCATE
        """
        print(f"  Loading {Path(json_path).name}...")
        
        # Read JSON
        with open(json_path, 'r') as f:
            data = json.load(f)
        
        # Convert to DataFrame
        if isinstance(data, list):
            df = pd.DataFrame(data)
        else:
            df = pd.DataFrame([data])
        
        # Load to BigQuery
        table_ref = self.client.dataset(dataset_id).table(table_id)
        job_config = bigquery.LoadJobConfig(
            write_disposition=write_disposition,
            autodetect=True
        )
        
        job = self.client.load_table_from_dataframe(df, table_ref, job_config=job_config)
        job.result()  # Wait for job to complete
        
        print(f"  ✅ Loaded {len(df)} rows to {dataset_id}.{table_id}")
    
    def load_dining_hall_csv(
        self,
        csv_path,
        dataset_id,
        table_id,
        write_disposition="WRITE_APPEND"
    ):
        """
        Load Dining Hall CSV file (special format: header on row 3)
        
        Args:
            csv_path: Path to CSV file
            dataset_id: BigQuery dataset ID
            table_id: BigQuery table ID
            write_disposition: WRITE_APPEND or WRITE_TRUNCATE
        """
        print(f"  Loading {Path(csv_path).name}...")
        
        # Read CSV with header on row 3 (0-indexed: row 2)
        df = pd.read_csv(csv_path, skiprows=2, dtype=str)
        
        # Remove the "Total Swipes" row if present
        df = df[~df['Plan ID'].str.contains('Total', case=False, na=False)]
        
        # Extract date from filename (format: dining_hall_swipes_YYYY_MM_DD.csv)
        filename = Path(csv_path).stem
        date_str = filename.split('_')[-3:]  # ['2026', '02', '03']
        date_value = '-'.join(date_str)  # '2026-02-03'
        
        # Add date column if it doesn't exist or is empty
        if 'Date' not in df.columns or df['Date'].isna().all():
            df['Date'] = date_value
        
        # Load to BigQuery
        table_ref = self.client.dataset(dataset_id).table(table_id)
        job_config = bigquery.LoadJobConfig(
            write_disposition=write_disposition,
            autodetect=True
        )
        
        job = self.client.load_table_from_dataframe(df, table_ref, job_config=job_config)
        job.result()  # Wait for job to complete
        
        print(f"  ✅ Loaded {len(df)} rows to {dataset_id}.{table_id}")
