# Run 01_generate_cfgs.py
echo "Running 01_generate_cfgs.py..."
python3 01_generate_cfgs.py

# Run 02_run_stats.py
echo "Running 02_run_stats.py..."
python3 02_run_stats.py

# Run 03_analyze_results.py
echo "Running 03_extract_info.py..."
python3 03_extract_info.py

# Run 04_copy_csv_to_local.sh
echo "Running 04_copy_csv_to_local.sh..."
./04_copy_csv_to_local.sh

echo "All scripts executed successfully."