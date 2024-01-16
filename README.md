# MCN Model
MCN model used to detect malware by using GNN model, details can be found in the paper: DISCOVERING MALICIOUS SIGNATURES IN SOFTWARE FROM STRUCTURAL INTERACTIONS
This GitHub repository encompasses two integral components:
1. LLVM tool: mgn_llvm.pl
2. MGN model: mgn_model.ipynb

## Tutorials
1. Install Ubuntu 12.04/14.04/16.04
2. Once Ubuntu installation is complete, please intall LLVM and make sure you allocate at least 50-60GB in virtual memory
3. Once steps 1 & 2 are complete, you can use our tools. But every time when you boot up Ubuntu to use our tools, make sure you type “export CONTECH_HOME=/where/you/place/tools”. If you follow my style, you should type “export CONTECH_HOME=/home/xiaoyao/Simulator/EE454”
4. You should go to scripts folder in MCN-LLVM by typing “cd /MCN-LLVM”.
5. Choose two C files you like and feel free to modify the number of iterations, but please do not make it too large because you have to wait hours or even days for it to finish. Lets say you choose “triad.c”, you can type “perl mgn_llvm.pl triad.c” to profile “triad.c” this C program. It should look like this if it is successful.
6. If step 6 is complete, you will get several extra files. The most important files to you are “triad.c-assortativity.py” where assortativity is calculated using NetworkX; “triad.c-dependency.wpairs” representing application dependency graph; “triad.c-gexf” where it is used by Gephi to vitualize the graph and perform community detection.

## Ackonowledge
I would like to express my sincere gratitude to Yao for creating the tool that I have used. The tool has been incredibly helpful, and I appreciate the effort put into its development.
Tool Source: https://github.com/xiaoyao0512/CompNetOpt
