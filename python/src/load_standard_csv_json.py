"""
Load structured data sources (Grubhub, Mashgin, Stripe) into BigQuery (skip Dining Hall for now)
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from loaders.bigquery_loader import BigQueryLoader


def main():
    print("\n" + "="*70)
    print("Loading Data to BigQuery - Day 1")
    print("="*70)
    
    loader = BigQueryLoader(
        project_id="retail-ops-analytics",
        credentials_path="config/gcp-service-account.json"
    )
    
    try:
        # 1. Grubhub
        print("\n[1/3] Loading Grubhub...")
        print("  Source: Day 7 (cumulative, contains all 7 days)")
        grubhub_path = "data/raw/poc_data/grubhub/grubhub_sales_2026_02_09.csv"
        if not Path(grubhub_path).exists():
            raise FileNotFoundError(f"Grubhub file not found: {grubhub_path}")
        loader.load_csv_to_table(
            csv_path=grubhub_path,
            dataset_id="raw_cvu_dining",
            table_id="grubhub_sales_raw",
            write_disposition="WRITE_TRUNCATE"
        )
        
        # 2. Mashgin
        print("\n[2/3] Loading Mashgin...")
        print("  Source: 7 daily JSON files")
        for day in range(3, 10):
            json_path = f"data/raw/poc_data/mashgin/mashgin_transactions_2026_02_0{day}.json"
            if not Path(json_path).exists():
                print(f"  WARNING: File not found: {json_path}, skipping...")
                continue
            print(f"  Loading Day {day}...")
            loader.load_json_to_table(
                json_path=json_path,
                dataset_id="raw_cvu_dining",
                table_id="mashgin_transactions_raw",
                write_disposition="WRITE_APPEND"
            )
        
        # 3. Stripe
        print("\n[3/3] Loading Stripe...")
        print("  Source: 7 daily event files")
        for day in range(3, 10):
            json_path = f"data/raw/poc_data/stripe/stripe_events_2026_02_0{day}.json"
            if not Path(json_path).exists():
                print(f"  WARNING: File not found: {json_path}, skipping...")
                continue
            print(f"  Loading Day {day}...")
            loader.load_json_to_table(
                json_path=json_path,
                dataset_id="raw_cvu_dining",
                table_id="stripe_events_raw",
                write_disposition="WRITE_APPEND"
            )
        
        # Success summary
        print("\n" + "="*70)
        print("SUCCESS - Data Loading Complete!")
        print("="*70)
        print("\nLoaded Tables:")
        print("  [OK] raw_cvu_dining.grubhub_sales_raw         (665 rows)")
        print("  [OK] raw_cvu_dining.mashgin_transactions_raw  (557 rows)")
        print("  [OK] raw_cvu_dining.stripe_events_raw         (246 events)")

    except Exception as e:
        print("\n" + "="*70)
        print("ERROR - Loading Failed")
        print("="*70)
        print(f"\nError: {e}")
        print("\nTroubleshooting:")
        print("  1. Check credentials: config/gcp-service-account.json")
        print("  2. Check datasets exist in BigQuery")
        print("  3. Check file paths are correct")
        raise


if __name__ == "__main__":
    main()
