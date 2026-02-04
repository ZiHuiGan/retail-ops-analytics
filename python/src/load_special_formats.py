"""
Load unstructured data sources (Dining Hall) into BigQuery. Special formats handling. Example: header on row 3, missing date column.
We will use the BigQueryLoader class to load the data into BigQuery. There are other formats in the future we may need to handle. 
For example, pdf files, etc.
"""

import sys
import csv
import io
from pathlib import Path
import pandas as pd
from google.cloud import bigquery
from typing import Literal
from loaders.bigquery_loader import BigQueryLoader
from datetime import datetime

sys.path.insert(0, str(Path(__file__).parent))


def load_dining_hall_csv(
    loader: BigQueryLoader,
    csv_path: str,
    dataset_id: str,
    table_id: str,
    write_disposition: Literal["WRITE_APPEND", "WRITE_TRUNCATE"] = "WRITE_APPEND"
):
    """
    Load Dining Hall malformed CSV
    Handles: header on row 3, missing date column
    
    Args:
        loader: BigQueryLoader instance
        csv_path: Path to CSV file
        dataset_id: BigQuery dataset ID
        table_id: BigQuery table ID
        write_disposition: WRITE_APPEND or WRITE_TRUNCATE
    """
    # Read file
    with open(csv_path, 'r') as f:
        lines = f.readlines()
    
    # Extract date from row 1
    # Example: "Cascade Dining Hall Report - February 03, 2026"
    header_line = lines[0].strip().strip('"')
    
    try:
        date_str = header_line.split(' - ')[1]
        date_obj = datetime.strptime(date_str, "%B %d, %Y")
        date_iso = date_obj.strftime("%Y-%m-%d")
    except Exception as e:
        print(f"  WARNING: Could not parse date from header: {e}")
        # Extract from filename as fallback
        filename = Path(csv_path).stem
        date_parts = filename.replace('dining_hall_swipes_', '').split('_')
        if len(date_parts) >= 3:
            date_iso = '-'.join(date_parts[-3:])  # ['2026', '02', '03'] -> '2026-02-03'
        else:
            print(f"  ERROR: Could not extract date from filename: {filename}")
            return
    
    # Skip first 2 rows, read from row 3 onwards (row 3 is header)
    # Create a string from lines starting at index 2
    csv_content = ''.join(lines[2:])
    reader = csv.DictReader(io.StringIO(csv_content))
    
    data_rows = []
    for row in reader:
        # Skip empty rows and total rows
        plan_id = row.get('Plan ID', '').strip() if row.get('Plan ID') else ''
        if not plan_id:
            continue
        if 'Total' in plan_id:
            continue
        
        # Add date column
        row['Date'] = date_iso
        data_rows.append(row)
    
    if not data_rows:
        print(f"  WARNING: No valid data in {csv_path}")
        return
    
    # Convert to DataFrame
    df = pd.DataFrame(data_rows)
    
    # Load to BigQuery
    table_ref = loader.client.dataset(dataset_id).table(table_id)
    
    job_config = bigquery.LoadJobConfig(
        write_disposition=write_disposition,
        autodetect=True
    )
    
    print(f"  Loading {len(df)} rows to {dataset_id}.{table_id}...")
    
    try:
        # Ensure dataset exists
        try:
            loader.client.get_dataset(dataset_id)
        except Exception:
            print(f"  Creating dataset {dataset_id}...")
            loader.client.create_dataset(dataset_id, exists_ok=True)
        
        job = loader.client.load_table_from_dataframe(
            df, 
            table_ref, 
            job_config=job_config
        )
        print(f"  Job started: {job.job_id}")
        job.result(timeout=300)  # 5 minute timeout
        
        if job.errors:
            print(f"  ERROR: Job errors: {job.errors}")
            raise Exception(f"BigQuery job failed: {job.errors}")
        
        print(f"  SUCCESS: Loaded {len(df)} rows from {Path(csv_path).name}")
    except Exception as e:
        print(f"  ERROR: Error loading {Path(csv_path).name}: {e}")
        raise


def main():
    print("\n" + "="*70)
    print("Loading Dining Hall Data")
    print("="*70)
    
    loader = BigQueryLoader(
        project_id="retail-ops-analytics",
        credentials_path="config/gcp-service-account.json"
    )
    
    print("\nLoading 7 days of dining hall swipes...")
    
    for day in range(3, 10):
        csv_path = f"data/raw/poc_data/dining_hall/dining_hall_swipes_2026_02_0{day}.csv"
        
        if not Path(csv_path).exists():
            print(f"  WARNING: File not found: {csv_path}, skipping...")
            continue
        
        load_dining_hall_csv(
            loader=loader,
            csv_path=csv_path,
            dataset_id="raw_cvu_dining",
            table_id="dining_hall_swipes_raw",
            write_disposition="WRITE_APPEND" if day > 3 else "WRITE_TRUNCATE"
        )
    
    print("\n" + "="*70)
    print("SUCCESS: Dining Hall data loaded!")
    print("="*70)


if __name__ == "__main__":
    main()