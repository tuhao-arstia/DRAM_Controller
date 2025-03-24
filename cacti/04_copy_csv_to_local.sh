#!/bin/bash

# 定義 WSL 中的文件路徑
WSL_FILE_PATH="/home/sicajc/user/Master_Thesis_MC/cacti/scripts_design_space_exploration/extracted_info.csv"

# 定義本地機器上的目標路徑
LOCAL_FILE_PATH="/mnt/c/Users/gota/Desktop/Master_Thesis_MC/trace_analysis/extracted_info.csv"

# 複製文件
cp $WSL_FILE_PATH $LOCAL_FILE_PATH

# 檢查複製是否成功
if [ $? -eq 0 ]; then
    echo "文件已成功複製到本地機器：$LOCAL_FILE_PATH"
else
    echo "文件複製失敗"
    exit 1
fi
