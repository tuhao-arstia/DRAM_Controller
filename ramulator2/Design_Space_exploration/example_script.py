import os
import yaml  # YAML parsing provided with the PyYAML package

baseline_config_file = "./example_config.yaml"
nRCD_list = [10, 15, 20, 25]

base_config = None
with open(baseline_config_file, 'r') as f:
  base_config = yaml.safe_load(f)

for nRCD in nRCD_list:
  config = base_config.copy()  # 初始化 config 變量
  config["MemorySystem"]["DRAM"]["timing"]["nRCD"] = nRCD
  cmds = ["./ramulator2", str(config)]
  os.system(" ".join(cmds))  # 使用 os.system() 運行命令