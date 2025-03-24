#!/bin/bash

# 更新包列表
sudo apt update

# 安裝 pip3
sudo apt install -y python3-pip

# 使用 pip3 安裝 pandas 和 matplotlib
pip3 install pandas matplotlib
