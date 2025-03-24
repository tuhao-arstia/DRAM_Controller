import os
import subprocess

def run_cacti_on_configs(configs_dir, output_dir):
    # Ensure the output directory exists
    os.makedirs(output_dir, exist_ok=True)

    # List all configuration files in the configs directory
    config_files = [f for f in os.listdir(configs_dir) if f.endswith('.cfg')]

    for config_file in config_files:
        config_path = os.path.join(configs_dir, config_file)
        log_file = os.path.join(output_dir, f'{os.path.splitext(config_file)[0]}.log')

        # Run the cacti command and redirect output to a log file
        cacti_command = './cacti'
        try:
            with open(log_file, 'w') as log:
                subprocess.run([cacti_command, '-infile', config_path], stdout=log, stderr=subprocess.STDOUT, check=True)
        except subprocess.CalledProcessError as e:
            print(f"Error running CACTI for {config_file}: {e}")

# Usage
configs_dir = 'scripts_design_space_exploration/3DDRAM_Design_Exploration/Configs'
output_dir = 'scripts_design_space_exploration/3DDRAM_Design_Exploration/Logs'

run_cacti_on_configs(configs_dir, output_dir)