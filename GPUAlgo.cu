#include "MyInc.h" 

// Question 1 en mémoire globale
// Mergesmall_k
__global__ void MergePathGPU_1024(TYPE *A, TYPE *B, TYPE *M, int sizeA, int sizeB)
{
    int i = threadIdx.x ;   
    Point K, P, Q;
    int offset ;

    if (i >= (sizeA + sizeB)) { return ;  }  // On gère les ébordements

    if (i > sizeA) 
    {
       K.x = i - sizeA ; K.y = sizeA ;
       P.x = sizeA ; P.y = i - sizeA ;
    }
    else // x ~ horizontal
    {
       K.x = 0 ; K.y = i ;
       P.x = i ; P.y = 0 ;
    }
    while (1)
    {
         offset = abs(K.y - P.y) / 2 ; 
         Q.x = K.x + offset ; Q.y = K.y - offset ; 

         if ( (Q.y >= 0) && (Q.x <= sizeB) &&
              ( (Q.y == sizeA) || (Q.x == 0) || (A[Q.y] > B[Q.x -1])) )
         {
              if ((Q.x == sizeB) || (Q.y == 0) || (A[Q.y-1] <= B[Q.x]))
              {
                   if ((Q.y < sizeA) && ((Q.x == sizeB) || (A[Q.y] <= B[Q.x])))
                   {  M[i] = A[Q.y] ; }
                   else
                   {  M[i] = B[Q.x] ; }
                   break ; 
              }
              else
              {  K.x = Q.x + 1 ; K.y = Q.y - 1 ; }
         }
         else
         { P.x = Q.x -1 ; P.y = Q.y + 1 ; }
    }

} // End of MergePathGPU_1024

//Question 1 en mémoire shared 
// Mergesmall_k_shared
__global__ void MergePathGPU_1024_shared(TYPE *GlobalCudaA, TYPE *GlobalCudaB, TYPE *M, int sizeA, int sizeB)
{
    extern __shared__ TYPE dataAB[] ; 
    unsigned int tid = threadIdx.x;
    unsigned int i   = blockIdx.x*blockDim.x + threadIdx.x;

    if (tid >= (sizeA + sizeB)) { return ;  }  // On gère les ébordements

 // Chargement des données dans la mémoire partagée par le thread ; 
     dataAB[tid] = (i < sizeA)?GlobalCudaA[i]:GlobalCudaB[i-sizeA] ; 

 // On attend qur tous les threads aient faits le travail
    __syncthreads(); 

 // On recadre nos pointeurs pourqu'ils pointent vers la mémoire partagée et la globale
    TYPE * A = dataAB ; 
    TYPE * B = dataAB + sizeA ; 

    Point K, P, Q;
    int offset ;

    if (i > sizeA) 
    {
       K.x = i - sizeA ; K.y = sizeA ;
       P.x = sizeA ; P.y = i - sizeA ;
    }
    else // x ~ horizontal
    {
       K.x = 0 ; K.y = i ;
       P.x = i ; P.y = 0 ;
    }
    while (1)
    {
         offset = abs(K.y - P.y) / 2 ; 
         Q.x = K.x + offset ; Q.y = K.y - offset ; 

         if ( (Q.y >= 0) && (Q.x <= sizeB) &&
              ( (Q.y == sizeA) || (Q.x == 0) || (A[Q.y] > B[Q.x -1])) )
         {
              if ((Q.x == sizeB) || (Q.y == 0) || (A[Q.y-1] <= B[Q.x]))
              {
                   if ((Q.y < sizeA) && ((Q.x == sizeB) || (A[Q.y] <= B[Q.x])))
                   {  M[i] = A[Q.y] ; }
                   else
                   {  M[i] = B[Q.x] ; }
                   break ; 
              }
              else
              {  K.x = Q.x + 1 ; K.y = Q.y - 1 ; }
         }
         else
         { P.x = Q.x -1 ; P.y = Q.y + 1 ; }
    }

} // End of MergePathGPU_1024

//Question 2 
// Pour merge à partir des fenetre obetnue 
// mergeBig k
__global__ void mergeGPU(TYPE * CudaVecteurA, TYPE * CudaVecteurB, TYPE * CudaVecteurC, int * CudaDiagAy, int * CudaDiagBx , int nbthread) 
{ 	
    // int i = threadIdx.x ;     // On renge le Ieme element
    int i = blockIdx.x * blockDim.x + threadIdx.x; // On range le ieme elet 
    int diag = (i / nbthread)  ;   // Dans quel fenêtre est-il ?  
    int indC = nbthread * diag ; 
    
    TYPE *A = CudaVecteurA+CudaDiagAy[diag] ; 
    TYPE *B = CudaVecteurB+CudaDiagBx[diag] ; 
    TYPE *M = CudaVecteurC + indC  ;  
    int sizeA = CudaDiagAy[diag+1]-CudaDiagAy[diag] ; 
    int sizeB = CudaDiagBx[diag+1]-CudaDiagBx[diag] ; 

    Point K, P, Q;
    int offset ;
 
    i = i % nbthread ; // On recadre i dans le nouvel espace
    if (i >= (sizeA + sizeB)) { return ;  }  // On gère les ébordements
    if (i > sizeA) 
    {
       K.x = i - sizeA ; K.y = sizeA ;
       P.x = sizeA ; P.y = i - sizeA ;
    }
    else // x ~ horizontal
    {
       K.x = 0 ; K.y = i ;
       P.x = i ; P.y = 0 ;
    }
    while (1)
    {
         offset = abs(K.y - P.y) / 2 ; 
         Q.x = K.x + offset ; Q.y = K.y - offset ; 

         if ( (Q.y >= 0) && (Q.x <= sizeB) &&
              ( (Q.y == sizeA) || (Q.x == 0) || (A[Q.y] > B[Q.x -1])) )
         {
              if ((Q.x == sizeB) || (Q.y == 0) || (A[Q.y-1] <= B[Q.x]))
              {
                   if ((Q.y < sizeA) && ((Q.x == sizeB) || (A[Q.y] <= B[Q.x])))
                   {  M[i] = A[Q.y] ; }
                   else
                   {  M[i] = B[Q.x] ; }
                   break ; 
              }
              else
              {  K.x = Q.x + 1 ; K.y = Q.y - 1 ; }
         }
         else
         { P.x = Q.x -1 ; P.y = Q.y + 1 ; }
    }

} // End of MergeGPU

// Initialiser les diagonale
__global__ void initDiagGPU(int SizeA , int SizeB, int * CudaDiagBx, int * CudaDiagAy, int NbWindows)  
{ 
   CudaDiagBx[0] = CudaDiagAy[0] = 0 ; 
   CudaDiagBx[NbWindows] = SizeB ;  
   CudaDiagAy[NbWindows] = SizeA ; 
} 

// Question 2
// Pour obtenir les diagolane 
// PathBig k
__global__ void AnalyseDiagonalesGPU(TYPE * CudaVecteurA, TYPE * CudaVecteurB, int sizeA , int sizeB, int * CudaDiagBx, int * CudaDiagAy, int nbthread)  
{
    // int i = blockIdx.x * blockDim.x + threadIdx.x; // On range le ieme elet 
    int nth = threadIdx.x; // On explore le nth diagonale 
    Point K, P, Q ; 
    int   px , py ; 
    TYPE * A = CudaVecteurA ; 
    TYPE * B = CudaVecteurB ; 
    int offset ; 
    int numDiag  = (nth+1) * nbthread -1 ; // Les tableaux vont de 0 à N-1 
	if (numDiag > sizeA) 
        {
    		K.x = numDiag - sizeA ; K.y = sizeA ;
    		P.x = sizeA ; P.y = numDiag - sizeA ;
    	}
    	else // x ~ horizontal
        {
    		K.x = 0 ; K.y = numDiag ;
    		P.x = numDiag ; P.y = 0 ;
    	}
    	while (1)
        {
             offset = abs(K.y - P.y) / 2 ; 
             Q.x = K.x + offset ; Q.y = K.y - offset ; 

             if ( (Q.y >= 0) && (Q.x <= sizeB) &&
                  ( (Q.y == sizeA) || (Q.x == 0) || (A[Q.y] > B[Q.x -1])) )
             {
                  if ((Q.x == sizeB) || (Q.y == 0) || (A[Q.y-1] <= B[Q.x]))
                  {
                       px = Q.x ; py = Q.y ;
                       if ((Q.y < sizeA) && ((Q.x == sizeB) || (A[Q.y] <= B[Q.x])))
                       {  // v = A[Q.y] ; 
                          py ++ ; 
                       }
                       else
                       {  // v = B[Q.x] ; 
                          px ++ ; 
                       }
                       // printf("Analyse Diagonale Point de Sortie ref %d - M %" FMT " Q (A Q.y %d) (B Q.x %d) rv.x %d rv.y %d\n",i,v,Q.y,Q.x,rv->x,rv->y) ; 
                       CudaDiagBx[nth+1] = px ; CudaDiagAy[nth+1] = py ; 
                       break ; // Pour simuler passage au thread suivant
                  }
                  else
                  {  K.x = Q.x + 1 ; K.y = Q.y - 1 ;  }
             }
             else
             { P.x = Q.x -1 ; P.y = Q.y + 1 ; }
    	}
} // End of AnalyseDiagonales
