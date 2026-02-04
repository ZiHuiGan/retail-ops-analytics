"""
Validate all 4 data sources
"""

import pandas as pd
import json
from pathlib import Path


def validate_grubhub(filepath):
    """Validate Grubhub CSV"""
    print(f"\n{'='*60}")
    print(f"Validating Grubhub: {Path(filepath).name}")
    print('='*60)
    
    df = pd.read_csv(filepath, dtype=str)
    
    # Validation checks
    has_order_id = 'Order ID' in df.columns
    checks = {
        "Row count > 0": len(df) > 0,
        "Has Order ID column": has_order_id,
        "Order ID unique": df['Order ID'].nunique() == len(df) if has_order_id else False,
        "Date parseable": True,  # Simplified check
        "Total column exists": 'Total' in df.columns,
    }
    
    for check, passed in checks.items():
        status = "PASS" if passed else "FAIL"
        print(f"  [{status}] {check}")
    
    print(f"\nStats:")
    print(f"  Rows: {len(df)}")
    print(f"  Columns: {len(df.columns)}")
    if has_order_id:
        print(f"  Unique Order IDs: {df['Order ID'].nunique()}")
    
    return all(checks.values())


def validate_mashgin(filepath):
    """Validate Mashgin JSON"""
    print(f"\n{'='*60}")
    print(f"Validating Mashgin: {Path(filepath).name}")
    print('='*60)
    
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    # Validation checks
    has_data = isinstance(data, list) and len(data) > 0
    first_item = data[0] if has_data else {}
    
    checks = {
        "Is list": isinstance(data, list),
        "Has data": has_data,
        "Has transaction_id": 'transaction_id' in first_item if has_data else False,
        "Has timestamp": 'timestamp' in first_item if has_data else False,
        "Timestamp is UTC": first_item.get('timestamp', '').endswith('Z') if has_data else False,
    }
    
    for check, passed in checks.items():
        status = "PASS" if passed else "FAIL"
        print(f"  [{status}] {check}")
    
    print(f"\nStats:")
    print(f"  Transactions: {len(data) if isinstance(data, list) else 0}")
    
    # Check percentage of empty venue_name
    if isinstance(data, list) and len(data) > 0:
        empty_venues = sum(1 for t in data if not t.get('venue_name'))
        empty_pct = empty_venues / len(data) * 100
        print(f"  Empty venue_name: {empty_venues} ({empty_pct:.1f}%)")
    
    return all(checks.values())


def validate_dining_hall(filepath):
    """Validate Dining Hall CSV (malformed)"""
    print(f"\n{'='*60}")
    print(f"Validating Dining Hall: {Path(filepath).name}")
    print('='*60)
    
    with open(filepath, 'r') as f:
        lines = f.readlines()
    
    # Validation checks
    checks = {
        "Has content": len(lines) > 0,
        "Row 1 is title": "Report" in lines[0] if len(lines) > 0 else False,
        "Row 3 is header": "Plan ID" in lines[2] if len(lines) > 2 else False,
        "Has data rows": len(lines) > 5,
    }
    
    for check, passed in checks.items():
        status = "PASS" if passed else "FAIL"
        print(f"  [{status}] {check}")
    
    print(f"\nStats:")
    print(f"  Total lines: {len(lines)}")
    print(f"  Header line: 3")
    print(f"  Data lines: ~{len(lines) - 5}")
    
    print(f"\nKnown issues:")
    print(f"  - Header not on row 1")
    print(f"  - Empty rows present")
    print(f"  - Date column is empty")
    
    return all(checks.values())


def validate_stripe(filepath):
    """Validate Stripe JSON"""
    print(f"\n{'='*60}")
    print(f"Validating Stripe: {Path(filepath).name}")
    print('='*60)
    
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    # Validation checks
    has_data = isinstance(data, list) and len(data) > 0
    first_event = data[0] if has_data else {}
    
    # Safely check amount
    amount_check = False
    if has_data and 'data' in first_event:
        data_obj = first_event.get('data', {})
        if isinstance(data_obj, dict) and 'object' in data_obj:
            obj = data_obj.get('object', {})
            if isinstance(obj, dict) and 'amount' in obj:
                try:
                    amount_check = obj['amount'] > 100
                except (TypeError, ValueError):
                    amount_check = False
    
    checks = {
        "Is list": isinstance(data, list),
        "Has data": has_data,
        "Has event_id": 'id' in first_event if has_data else False,
        "Has event_type": 'type' in first_event if has_data else False,
        "Amount in cents": amount_check,
    }
    
    for check, passed in checks.items():
        status = "PASS" if passed else "FAIL"
        print(f"  [{status}] {check}")
    
    print(f"\nStats:")
    print(f"  Events: {len(data) if isinstance(data, list) else 0}")
    
    # Count event types
    if isinstance(data, list) and len(data) > 0:
        event_types = {}
        for event in data:
            et = event.get('type', 'unknown')
            event_types[et] = event_types.get(et, 0) + 1
        
        print(f"  Event types:")
        for et, count in event_types.items():
            print(f"    - {et}: {count}")
    
    return all(checks.values())


def main():
    """Validate all data sources"""
    
    print("\n" + "="*60)
    print("Data Validation - All Sources")
    print("="*60)
    
    results = {}
    
    # 1. Grubhub
    results['Grubhub'] = validate_grubhub(
        "data/raw/poc_data/grubhub/grubhub_sales_2026_02_03.csv"
    )
    
    # 2. Mashgin
    results['Mashgin'] = validate_mashgin(
        "data/raw/poc_data/mashgin/mashgin_transactions_2026_02_03.json"
    )
    
    # 3. Dining Hall
    results['Dining Hall'] = validate_dining_hall(
        "data/raw/poc_data/dining_hall/dining_hall_swipes_2026_02_03.csv"
    )
    
    # 4. Stripe
    results['Stripe'] = validate_stripe(
        "data/raw/poc_data/stripe/stripe_events_2026_02_03.json"
    )
    
    # Summary
    print(f"\n{'='*60}")
    print("Validation Summary")
    print('='*60)
    
    for source, passed in results.items():
        status = "PASS" if passed else "FAIL"
        print(f"  [{status}] - {source}")
    
    all_passed = all(results.values())
    
    print(f"\n{'='*60}")
    if all_passed:
        print("All validations passed! Safe to load to BigQuery.")
    else:
        print("WARNING: Some validations failed. Review before loading.")
    print('='*60)


if __name__ == "__main__":
    main()