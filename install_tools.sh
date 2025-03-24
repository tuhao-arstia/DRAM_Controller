#!/bin/bash

# Update package list
echo "Updating package list..."
sudo apt update -y

# Install clangd
echo "Installing clangd..."
sudo apt install clangd -y

# Install cmake
echo "Installing cmake..."
sudo apt install cmake -y

# Install make
echo "Installing make..."
sudo apt install make -y

# Install git
echo "Installing git..."
sudo apt install git -y

# Install gdb
echo "Installing gdb..."
sudo apt install gdb -y

# Install python3 and pip3
echo "Installing Python 3 and pip3..."
sudo apt install python3 python3-pip python3-venv -y

# Create a virtual environment
echo "Creating a virtual environment..."
python3 -m venv /root/venv

# Activate the virtual environment
echo "Activating the virtual environment..."
source /root/venv/bin/activate

# Install additional Python libraries in the virtual environment
echo "Installing additional Python libraries..."
pip install pyyaml matplotlib numpy numba torch

# Verify installations
echo "Verifying installations..."
clangd --version
cmake --version
make --version
git --version
gdb --version
python3 --version
pip --version
pip show pyyaml matplotlib numpy numba torch

echo "All tools installed successfully!"
