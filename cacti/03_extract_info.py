import os
import re
import csv

def extract_log_info(log_file):
    info = {}
    with open(log_file, 'r') as file:
        lines = file.readlines()

    timing_section = False
    power_section = False
    area_section = False
    tsv_section = False

    for line in lines:
        if "Timing Components:" in line:
            timing_section = True
            power_section = False
            area_section = False
            tsv_section = False
            continue
        elif "Power Components:" in line:
            timing_section = False
            power_section = True
            area_section = False
            tsv_section = False
            continue
        elif "Area Components:" in line:
            timing_section = False
            power_section = False
            area_section = True
            tsv_section = False
            continue
        elif "TSV Components:" in line:
            timing_section = False
            power_section = False
            area_section = False
            tsv_section = True
            continue

        # Extract memory parameters
        if "Total memory size (Gb)" in line:
            info['Total memory size/Layer (Gb)'] = float(line.split(':')[1].strip().split()[0])
        elif "Stacked die count" in line:
            info['Stacked die count'] = int(line.split(':')[1].strip().split()[0])
        elif "Page size" in line:
            # Divide by 1024 to convert from bits to bytes
            info['Page size(KB)'] = int(int(line.split(':')[1].strip().split()[0]) / int(1024*8))
        elif "Chip IO width" in line:
            info['Chip IO width'] = int(line.split(':')[1].strip().split()[0])
        elif "Number of banks" in line:
            info['Number of banks/Layer'] = int(line.split(':')[1].strip().split()[0])

        if timing_section:
            def calculate_time_in_tck(value,clk_frequency_mHz=1000):
                time_in_tck = (value*clk_frequency_mHz) / clk_frequency_mHz
                return round(time_in_tck) if time_in_tck % 1 >= 0.5 else round(time_in_tck) + 1

            if "t_RCD" in line:
                value = float(line.split(':')[1].strip().split()[0])
                info['t_RCD'] = calculate_time_in_tck(value)
            elif "t_RAS" in line:
                value = float(line.split(':')[1].strip().split()[0])
                info['t_RAS'] = calculate_time_in_tck(value)
            elif "t_RC" in line:
                value = float(line.split(':')[1].strip().split()[0])
                info['t_RC'] = calculate_time_in_tck(value)
            elif "t_CAS" in line:
                value = float(line.split(':')[1].strip().split()[0])
                info['t_CAS'] = calculate_time_in_tck(value)
            elif "t_RP" in line:
                value = float(line.split(':')[1].strip().split()[0])
                info['t_RP'] = calculate_time_in_tck(value)
            elif "t_RRD" in line:
                value = float(line.split(':')[1].strip().split()[0])
                info['t_RRD'] = calculate_time_in_tck(value)

        if power_section:
            if "Activation energy" in line:
                info['Activation energy nJ'] = float(line.split(':')[1].strip().split()[0])
            elif "Read energy" in line:
                info['Read energy nJ'] = float(line.split(':')[1].strip().split()[0])
            elif "Write energy" in line:
                info['Write energy nJ'] = float(line.split(':')[1].strip().split()[0])
            elif "Precharge energy" in line:
                info['Precharge energy nJ'] = float(line.split(':')[1].strip().split()[0])

        if area_section:
            if "Area efficiency" in line:
                info['Area efficiency'] = float(line.split(':')[1].strip().split()[0].replace('%', ''))
            elif "DRAM core area" in line:
                info['DRAM core area(mm^2)'] = float(line.split(':')[1].strip().split()[0])

        if tsv_section:
            if "TSV area overhead" in line:
                info['TSV area overhead'] = float(line.split(':')[1].strip().split()[0])
            elif "TSV latency overhead" in line:
                info['TSV latency overhead'] = float(line.split(':')[1].strip().split()[0])
            elif "TSV energy overhead per access" in line:
                info['TSV energy overhead per access'] = float(line.split(':')[1].strip().split()[0])

    # Calculate total memory size
    if 'Total memory size/Layer (Gb)' in info and 'Stacked die count' in info:
        info['Total memory size (Gb)'] = info['Total memory size/Layer (Gb)'] * info['Stacked die count']

    # Calculate size of bank in Mb
    if 'Total memory size/Layer (Gb)' in info and 'Number of banks/Layer' in info:
        info['Size of bank (Mb)'] = (info['Total memory size/Layer (Gb)'] * 1024) / info['Number of banks/Layer']

    # Calculate total number of banks
    if 'Number of banks/Layer' in info and 'Stacked die count' in info:
        info['Total number of banks'] = info['Number of banks/Layer'] * info['Stacked die count']

    return info

def save_to_csv(infos, csv_file, memory_size=64):
    # Define the order of headers, with Memory Parameters at the front
    memory_headers = ['Total memory size/Layer (Gb)', 'Stacked die count', 'Page size(KB)', 'Chip IO width', 'Number of banks/Layer', 'Size of bank (Mb)', 'Total number of banks']
    other_headers = sorted(set(infos[0].keys()) - set(memory_headers))
    headers = memory_headers + other_headers

    with open(csv_file, 'w', newline='') as file:
        writer = csv.writer(file, delimiter='\t')
        writer.writerow(headers)
        for info in infos:
            if info.get('Total memory size (Gb)', 0) == memory_size:
                row = [info.get(header, '') for header in headers]
                # Add extra tabs for spacing
                spaced_row = ['\t' + str(value) + '\t'+' ' for value in row]
                writer.writerow(spaced_row)

if __name__ == "__main__":
    log_dir = './scripts_design_space_exploration/3DDRAM_Design_Exploration/Logs'  # Replace with your log directory path
    csv_file = './scripts_design_space_exploration/extracted_info.csv'  # Replace with your desired CSV file path

    infos = []
    for log_file in os.listdir(log_dir):
        if log_file.endswith('.log'):
            log_file_path = os.path.join(log_dir, log_file)
            info = extract_log_info(log_file_path)
            infos.append(info)

    save_to_csv(infos, csv_file)
    print(f"Extracted information saved to {csv_file}")
