# Retail Ops Analytics

Campus dining operations analytics pipeline using BigQuery, dbt, and Python.

---

## 🚀 Quick Start

### Prerequisites
- Python 3.13+ or Anaconda
- Google Cloud Platform account
- BigQuery access

### Environment Setup

#### Option 1: Using Conda (Recommended)
```bash
# Clone repository
git clone https://github.com/ZiHuiGan/retail-ops-analytics.git
cd retail-ops-analytics

# Create environment
conda env create -f environment.yml

# Activate environment
conda activate retail-ops

# Verify installation
python --version  # Should show Python 3.13.x
```

#### Option 2: Using venv
```bash
# Create virtual environment
python3.13 -m venv venv

# Activate
source venv/bin/activate  # macOS/Linux
# or
venv\Scripts\activate  # Windows

# Install dependencies
pip install -r requirements.txt
```

### Configuration

1. **BigQuery Credentials**
```bash
   # Place your service account key
   cp your-key.json config/gcp-service-account.json
```

2. **Verify connection**
```bash
   cd python/src
   python -c "from loaders.bigquery_loader import BigQueryLoader; print('Connection ready')"
```

### Load Data
```bash
# Load standard formats (Grubhub, Mashgin, Stripe)
python python/src/load_standard_csv_json.py

# Load special formats (Dining Hall)
python python/src/load_special_formats.py
```

---

## 📁 Project Structure
```
retail-ops-analytics/
├── config/                  # Configuration files
│   └── gcp-service-account.json  # (Not tracked in git)
├── cvu_dining/              # dbt project
│   ├── models/
│   └── dbt_project.yml
├── data/                    # Data files (not tracked)
│   ├── raw/
│   └── seed/
├── docs/                    # Documentation
├── python/                  # Python code
│   └── src/
│       ├── loaders/         # Data loading classes
│       └── load_*.py        # Loading scripts
├── environment.yml          # Conda environment
└── requirements.txt         # pip dependencies
```

---

## 🛠️ Tech Stack

- **Data Warehouse:** Google BigQuery
- **Transformation:** dbt (Data Build Tool)
- **Language:** Python 3.13
- **Key Libraries:** pandas, google-cloud-bigquery
- **Environment:** Conda

---

## 📊 Data Sources

- **Grubhub:** Retail sales transactions (665 records)
- **Mashgin:** Kiosk transactions (1038 records)
- **Stripe:** Payment events (246 records)
- **Dining Hall:** Meal plan swipes (28 records)

---

## 📝 Development Notes

### Daily Workflow
```bash
# Start working
conda activate retail-ops

# Run data loading
python python/src/load_standard_csv_json.py

# Run dbt models
cd cvu_dining
dbt run

# Exit environment
conda deactivate
```

### Common Issues

**Issue: Python version mismatch**
```bash
# Check version
python --version

# Should be 3.13+, if not:
conda activate retail-ops
```

**Issue: Import errors**
```bash
# Reinstall dependencies
pip install -r requirements.txt
```

---

## 👤 Author

Grace Gan - [GitHub](https://github.com/ZiHuiGan)

---

## 📄 License

This project is for portfolio purposes.
