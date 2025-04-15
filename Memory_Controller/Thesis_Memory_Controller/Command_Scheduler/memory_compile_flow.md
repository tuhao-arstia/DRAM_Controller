##===============================
##===  TN16 memory compiler   ===
##===============================

# Important: Memory Compiler for TN16 is only available in 50 server, other server will get license fail ***
## The compiler can only be used to the registered IP!!!!!!!!

## 01 create a directory where you want to generate the memory at
mkdir memory (just an example)
cd memory

## 02 source mc2 cshrc (license)
cp /home/process/TN16FFC/IP/CBTK_TSMC16FFC_core_TSMC_v2.0/CIC/Memory/mc2.cshrc ./

- Change the directory in mc2.cshrc to the correct one

source mc2.cshrc

## 03 source compiler cshrc 
## take dual port SRAM as example, you can find what ever you want at /home/process/TN16FFC/IP/CBTK_TSMC16FFC_core_TSMC_v2.0/CIC/Memory/sram/Compiler/
cp /home/process/TN16FFC/IP/CBTK_TSMC16FFC_core_TSMC_v2.0/CIC/Memory/sram/Compiler/tsn16ffclldpsram_20131200_130a.csh ./
cp /home/process/TN16FFC/IP/CBTK_TSMC16FFC_core_TSMC_v2.0/CIC/Memory/sram/Compiler/tsn16ffcll2prf_20131200_170a.csh ./
cp /home/process/TN16FFC/IP/CBTK_TSMC16FFC_core_TSMC_v2.0/CIC/Memory/sram/Compiler/tsn16ffcllspsram_20131200_120a.csh ./

- Change the directory in these .csh

#### dualport sram
source tsn16ffclldpsram_20131200_130a.csh 
#### 2 port rf 
source tsn16ffcll2prf_20131200_170a.csh
### Single port sram
source tsn16ffcllspsram_20131200_120a.csh
## 04 copy config file to rundir
cp /home/process/TN16FFC/IP/CBTK_TSMC16FFC_core_TSMC_v2.0/CIC/Memory/sram/Compiler/tsn16ffclldpsram_20131200_130a/config.txt .
cp /home/process/TN16FFC/IP/CBTK_TSMC16FFC_core_TSMC_v2.0/CIC/Memory/sram/Compiler/tsn16ffcll2prf_20131200_170a/config.txt .
cp /home/process/TN16FFC/IP/CBTK_TSMC16FFC_core_TSMC_v2.0/CIC/Memory/sram/Compiler/tsn16ffcllspsram_20131200_120a/config.txt .


## 05 modify  config.txt
## Example config: 2048x64m4
## (number of word)x(word size)m(mux), note that number of word can only be multiples of 64
## For the available config, please refer to databook and look-up-table for further details 
## Databook: /mnt/NAS/CAD/TN16FFC_P/PDF/TN16s081/mnt/test/20241227-002277-TN16-PDF/IP/CBTK_TSMC16FFC_core_TSMC_v2.0/orig_lib/TSMCHOME/sram/Documentation/documents/

## 06 run generate (take dual port SRAM as example)
cp /home/process/TN16FFC/IP/CBTK_TSMC16FFC_core_TSMC_v2.0/CIC/Memory/sram/Compiler/tsn16ffclldpsram_20131200_130a/tsn16ffclldpsram_130a.pl ./
cp /home/process/TN16FFC/IP/CBTK_TSMC16FFC_core_TSMC_v2.0/CIC/Memory/sram/Compiler/tsn16ffcll2prf_20131200_170a/tsn16ffcll2prf_170a.pl ./
cp /home/process/TN16FFC/IP/CBTK_TSMC16FFC_core_TSMC_v2.0/CIC/Memory/sram/Compiler/tsn16ffcllspsram_20131200_120a/tsn16ffcllspsram_120a.pl ./

#### dualport sram
perl tsn16ffclldpsram_130a.pl 
#### 2 port rf 
perl tsn16ffcll2prf_170a.pl
### Single port sram
perl tsn16ffcllspsram_120a.pl


## 07 Note that the error after generate is normal, just make sure the verilog code is available.