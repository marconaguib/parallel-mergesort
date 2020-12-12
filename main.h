// Pour que les vecteurs A et B soient consécutifs lorsqu'on fait le flip- flop de la question 3
#undef DOUBLE  
// #DEFINE DOUBLE : donc c'est défini on peut utiliser les boucles ligne 81 à 84

// Mécanisme de remplissage ou d'initialisation des vecteurs
   char MSGRemplir[RemplirEnd][64] =
       { // AlgoPairImpair
            "Algo A Pair et B Impair" ,                  
          // AlgoBinaire
             "Algo binaire (tous à la même valeur) 1/2",
          // AlgoRandom
             "Algo remplissage aléatoire dispersion 10/150" ,
          // AlgoRandom2
             "Algo remplissage aléatoire dispersion 150/150" ,
          // AlgoPetit
             "Algo Plus Petit - Plus grand"
          // AlgoEnd
      } ;
 
// Algo de Merge
   char MSGMerge[TriEnd][64] =
     { "Merge via Simple sur HOST" ,          // TriMergeSimpleHOST
       "Merge via MergePath sur HOST"   ,     // TriMergePathHOST
       "Merge via MergePath sur GPU < 1024"    ,     // TriMergePathGPU_1024
       "Merge via MergePath sur GPU < 1024 + Shared" ,  // TriMergePath_1024_shared, 
       "Merge via Fenetre glissante avec GPU - Full Para"   // TriWindowsGPU_Para
     } ;
     
// Pour avoir les caractérisques de la carte GPU
void getInfoCuda()
{
    int nDevices;
    cudaGetDeviceCount(&nDevices);
   
    if (nDevices != 1)
    {   printf("getInfoCuda nDevices %d != 1 - Est-ce que GPU est activé ?\n",nDevices) ;
        exit(0) ;
    }
   
    for (int i = 0; i < nDevices; i++)
    {
        cudaDeviceProp prop;
        cudaGetDeviceProperties(&prop, i);
        printf("Device Number: %d\n", i);
        printf( "Taille grille : %d %d %d", prop.maxGridSize[0],prop.maxGridSize[1], prop.maxGridSize[2]);
        printf("  Device name: %s\n", prop.name);
        printf("  Memory Clock Rate (KHz): %d\n", prop.memoryClockRate);
        printf("  Memory Bus Width (bits): %d\n", prop.memoryBusWidth);
        printf("  Peak Memory Bandwidth (GB/s): %f\n\n", 2.0*prop.memoryClockRate*(prop.memoryBusWidth/8)/1.0e6);
        printf("Dimention maximal des threads %d %d %d  \n", prop.maxThreadsDim[0],prop.maxThreadsDim[1], prop.maxThreadsDim[2]);
        printf("Nombre maximal de threads par block %d \n", prop.maxThreadsPerBlock);
        printf("totalGlobalMem %lu - sharedMemPerBlock %lu\n",prop.totalGlobalMem, prop.sharedMemPerBlock) ;
        printf("multiProcessorCount %d - multiProcessorCount %d\n", prop.multiProcessorCount, prop.multiProcessorCount) ;
    }
    printf("SizeOf long %lu - SizeOf float %lu - SizeOf Double %lu\n",sizeof(long),sizeof(float),sizeof(double)) ;
 
}  // End of getInfoCuda
 
// Nos allocations dynamiques sur Host 
TYPE * HostVecteurA = NULL ;
TYPE * HostVecteurB = NULL ;
TYPE * HostVecteurC = NULL ;
TYPE * HostVecteurD = NULL ;
int  * HostDiagBx   = NULL ; // Contient la moitié de la coordonnée d'un point.
int  * HostDiagAy   = NULL ; 

// Nos allocations dynamiques sur le device (Cuda)
TYPE * CudaVecteurA = NULL ;
TYPE * CudaVecteurB = NULL ;
TYPE * CudaVecteurC = NULL ;
int  * CudaDiagBx   = NULL ;
int  * CudaDiagAy   = NULL ;
 
void cleanup()
{
#ifdef DOUBLE 
    if (HostVecteurA != NULL) { free(HostVecteurA) ; HostVecteurA = NULL ; }
    if (HostVecteurB != NULL) { free(HostVecteurB) ; HostVecteurB = NULL ; }
#else 
    if (HostVecteurA != NULL) { free(HostVecteurA) ; HostVecteurA = NULL ; HostVecteurB = NULL ; }
#endif 
    if (HostVecteurC != NULL) { free(HostVecteurC) ; HostVecteurC = NULL ; }
    if (HostVecteurD != NULL) { free(HostVecteurD) ; HostVecteurD = NULL ; }
 
    if (CudaVecteurA != NULL) { cudaFree(CudaVecteurA) ; CudaVecteurA = NULL ; }
    if (CudaVecteurB != NULL) { cudaFree(CudaVecteurB) ; CudaVecteurA = NULL ; }
    if (CudaVecteurC != NULL) { cudaFree(CudaVecteurC) ; CudaVecteurA = NULL ; }
}

void allocVecteur(int SizeA, int SizeB, int nbthread)
{ 

   cudaError_t errCuda ;
   
// On fait quelques calculs, même si non utilisés par l'algo cible
   int NbDiagonale  = (SizeA + SizeB) / nbthread ;
   int NbWindows    = NbDiagonale ; 
   // Nombre de trie à faire, c'est le nombre de diagonale +1, sauf si la dernière diagonale est sur 
   // le coin en bas à droite
   NbWindows       += (((SizeA + SizeB) % nbthread) == 0)?0:1 ;  

// Allocation dynamique Sur le host
#ifdef DOUBLE
   if ((HostVecteurA = (TYPE *) malloc(SizeA * sizeof(TYPE))) == NULL)
   { printf("PB allocation HostVecteurA\n") ; cleanup() ; exit(1) ; }
 
   if ((HostVecteurB = (TYPE *) malloc(SizeB * sizeof(TYPE))) == NULL)
   { printf("PB allocation HostVecteurB\n") ; cleanup() ; exit(1) ; }
#else 
   if ((HostVecteurA = (TYPE *) malloc((SizeA + SizeB) * sizeof(TYPE))) == NULL)
   { printf("PB allocation HostVecteurA in double\n") ; cleanup() ; exit(1) ; }
   HostVecteurB = HostVecteurA + SizeA ; 
#endif 

   if ((HostVecteurC = (TYPE *) malloc((SizeA + SizeB) * sizeof(TYPE))) == NULL)
   { printf("PB allocation HostVecteurC\n") ; cleanup() ; exit(1) ; }
 
   if ((HostVecteurD = (TYPE *) malloc((SizeA + SizeB) * sizeof(TYPE))) == NULL)
   { printf("PB allocation HostVecteurD\n") ; cleanup() ; exit(1) ; }

// Les vecteurs Diag sur le Host sont surtout utiles pour du debug
   if ((HostDiagBx = (int *) malloc((NbWindows + 1) * sizeof(int))) == NULL)
   { printf("PB allocation HostDiagBx\n") ; cleanup() ; exit(1) ; }

   if ((HostDiagAy = (int *) malloc((NbWindows + 1) * sizeof(int))) == NULL)
   { printf("PB allocation HostDiagAy\n") ; cleanup() ; exit(1) ; }
 
// Allocation dynamique Sur le device
   if (cudaSuccess != (errCuda = cudaMalloc((void**)&CudaVecteurA, SizeA * sizeof(TYPE))))
   { printf("PB allocation CudaVecteurA - %d - %s \n",errCuda,cudaGetErrorName(errCuda)) ; cleanup() ; exit (1) ; }
 
   if (cudaSuccess != (errCuda = cudaMalloc((void**)&CudaVecteurB, SizeB * sizeof(TYPE))))
   { printf("PB allocation CudaVecteurB - %d - %s \n",errCuda,cudaGetErrorName(errCuda)) ; cleanup() ; exit (1) ; }
 
   if (cudaSuccess != (errCuda = cudaMalloc((void**)&CudaVecteurC, (SizeA + SizeB) * sizeof(TYPE))))
   { printf("PB allocation CudaVecteurC - %d - %s \n",errCuda,cudaGetErrorName(errCuda)) ; cleanup() ; exit (1) ; }
   
   if (cudaSuccess != (errCuda = cudaMalloc((void**)&CudaDiagBx, (NbWindows + 1) * sizeof(int))))
   { printf("PB allocation CudaDiagBx - %d - %s \n",errCuda,cudaGetErrorName(errCuda)) ; cleanup() ; exit (1) ; }
   
   if (cudaSuccess != (errCuda = cudaMalloc((void**)&CudaDiagAy, (NbWindows + 1)* sizeof(int))))
   { printf("PB allocation CudaDiagAy - %d - %s \n",errCuda,cudaGetErrorName(errCuda)) ; cleanup() ; exit (1) ; }
 
} 

