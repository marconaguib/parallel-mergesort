# Parallel mergesort using CUDA

This repo contains scripts we wrote for our HPC project : mergesorting C arrays using Cuda parallelism.

## Scripts :
- [go](go) : cmd file for compilation
- For question 1 (as well as getting familiar with GPU kernels):
  - [main.h](main.h) : Various Allocation/Free functions
  - [MyInc.h](MyInc.h) : Function headers
  - [GPUAlgo.cu](GPUAlgo.cu) : Sorting functions on device
  - [HostAlgo.cu](HostAlgo.cu) : Sorting functions on host (for comparison)
  - [HostTools.cu](HostTools.cu) : Testing and measuring tools (on host)
  - [testerCuda.cu](testerCuda.cu) : `MergeSmall_k`: a function that merges two sorted arrays of a total size smaller than 1024, using 1 block and multiple threads
- [question2.cu](question2.cu) : `MergeBig_k`: a function that merges two sorted "big" arrays using multiple block and multiple threads
- [question3.cu](question3.cu) : `MergeSort` : looping on `MergeSmall_k` and `MergeBig_k`, this is **NOT** the best we did.
- [question5.cu](question5.cu) : `MergeSmallBatch_k` : a function that merges two batches of sorted arrays (each of a size smaller than 512), two by two, using multiple block and multiple threads
- [partie3.cu](partie3.cu) : `MergeSort` : looping on `MergeSmallBatch_k` and `MergeBig_k`, this is **THE** best mergesort we managed to code, nearly twice as fast as the Numpy sequential mergesort function 
- [PresentationHPC.pdf](PresentationHPC.pdf) : Our presentation in French
- [PresentationHPCAnglais.pdf](PresentationHPCAnglais.pdf) : Our presentation in English

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
