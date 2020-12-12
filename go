#!/bin/bash

# Sur google, le compilateur conserver parfois le .o, même en cas d'erreur de syntaxe, donc on a pris l'habitude de supprimler le .o
# Au depart, on avait 3 fichier donc le go suffisait, maintenant on pourrait presque faire un makefile

# gestion des executables 
rm testerCuda
rm question2
rm question3
rm question5
rm partie3

# gestion des .o
rm *.o

# Compilation separe
nvcc -c HostTools.cu 
nvcc -c HostAlgo.cu
nvcc -c GPUAlgo.cu
nvcc -c MixteAlgo.cu

# Les programmes autonomes 
nvcc -c question2.cu
nvcc -c question3.cu
nvcc -c question5.cu
nvcc -c partie3.cu
nvcc -c testerCuda.cu

# Assemblage des executables 
nvcc -o testerCuda testerCuda.o HostTools.o HostAlgo.o GPUAlgo.o MixteAlgo.cu
nvcc -o question2 question2.o
nvcc -o question3 question3.o 
nvcc -o question5 question5.o
nvcc -o partie3  partie3.o 

# ./mesCudai2
