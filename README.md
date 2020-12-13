# Parallel mergesort using CUDA

This repo contains scripts we wrote for our HPC project : mergesorting C arrays using Cuda parallelism.

## Scripts :
- [go](go) : cmd file for compilation
- [main.h](main.h), [MyInc.h](MyInc.h),[GPUAlgo.cu](GPUAlgo.cu),[HOSTAlgo.cu](HOSTAlgo.cu),[GPUTools.cu](GPUTools.cu)  : Various Allocation/Free functions
- [testerCuda.cu](testerCuda.cu) :
- [question2.cu](question2.cu) :
- [question3.cu](question3.cu) :
- [question5.cu](question5.cu) :
- [partie3.cu](partie3.cu) :
- [PresentationHPC.pdf](PresentationHPC.pdf) :
- [PresentationHPCAnglais.pdf](PresentationHPCAnglais.pdf) :

## Compilation and execution
Use the command `./go` to compile all the files. And then you can execute :
- `./testerCuda` : to examine our code answering question 1
- `./question2`: to examine our code answering question 2
- `./question3`: to examine our code answering question 3
- `./question5`: to examine our code answering question 5
- `/partie3` : to examine our code answering part 3 

In all this files, you can change the sizes, the values, or the filling rules of the different arrays (A, B or M) thanks to slight, intuitive modifications.

## Colab 
[Here](https://colab.research.google.com/drive/1c57rpU0Xp8E8o8AiUUeqEQTcFT9SJncS?usp=sharing) is the link of the Colab we used during the presentation. It uses most of the functions mentioned, including the MergeSort function.

Do not hesitate to contact in case of any issues.

Astrid Legay & Marco Naguib - MAIN5 - HPC project 2020
