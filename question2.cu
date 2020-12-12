// Version single file 
#include <stdlib.h> 
#include <stdio.h>

// Pour pouvoir experimenter les performances avec les différents types
// FMT  Permet d'avoir un % adapté pour le printf et donc de pas avoir de warning
#define TYPE int 
#define FMT  "d"

typedef struct 
{
   int x ; 
   int y ; 
}  Point ; 


__global__ void PathBig(TYPE * CudaVecteurA, TYPE * CudaVecteurB, int sizeA , int sizeB, int * CudaDiagBx, int * CudaDiagAy, int nbthread, int NbWindows)  
{
    //Initialisation diagolane 
    CudaDiagBx[0] = CudaDiagAy[0] = 0 ; 
    CudaDiagBx[NbWindows] = sizeB ;  
    CudaDiagAy[NbWindows] = sizeA ;  
   
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
} // End of PathBig

__global__ void MergeBig_k(TYPE * CudaVecteurA, TYPE * CudaVecteurB, TYPE * CudaVecteurC, int * CudaDiagAy, int * CudaDiagBx , int nbthread) 
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

}

int check(char * msg, int Nb, TYPE * pto)
{
    TYPE * pt1 = pto ;
    TYPE * pt2 = pto + 1 ;
    int i ;

    for (i = 0 ; i < Nb-1 ; i ++)
    {
        if (*pt1 > *pt2)
        { printf("Check %s pour %d - Erreur en position %d %" FMT " > %" FMT " \n", msg, Nb, i, *pt1, *pt2) ;
          return i ;
        }
        pt1 ++ ; pt2 ++ ;
    }
    printf("Premiere valeur de %s = %" FMT ", deuxième valeur = %" FMT ", troisième valeur = %" FMT " \n", msg, pto[0], pto[1], pto[2]);
    printf("Check %s pour %d est OK \n", msg, Nb) ;
    return 0 ;
}

void Affiche(char * tabMsg, TYPE * ptBuffer, int NB)
{  
   TYPE * pt = ptBuffer ; 
   for ( int k = 0 ; k < NB  ; k++ , pt ++) 
   {   printf(" - %s[%03d] = %6" FMT, tabMsg, k , *pt) ; 
       if ((k % 5) == (4)) 
       {  printf("\n") ; }
   }
   printf("\n") ;
}

int main(int argc, char ** argv) 
{
    //déclaration
    int sizeA = 1600;
    int sizeB = 1000 ;
    int sizeM = sizeA + sizeB ; 
    TYPE* A; 
    TYPE* B ; 
    TYPE* M;
 
    float m1; 
    cudaEvent_t Start; cudaEvent_t Stop; cudaEventCreate(&Start) ; cudaEventCreate(&Stop) ; 
 
    //allocation
    if ((A = (TYPE *) malloc(sizeA * sizeof(TYPE))) == NULL)
        { printf("PB allocation VecteurA\n") ; exit (1) ; }
 
    if ((B= (TYPE *) malloc(sizeB * sizeof(TYPE))) == NULL)
        { printf("PB allocation VecteurB\n") ; exit (1) ; }
 
    if ((M= (TYPE *) malloc(sizeM * sizeof(TYPE))) == NULL)
        { printf("PB allocation VecteurM\n") ; exit (1) ; }
 
    //initialisation
    srand(1925);
    A[0] = B[0] = rand()%100;
    for (int i =1; i<sizeA; i++)
    {
        A[i]=A[i-1]+rand()%100;
    }
    for (int i =1; i<sizeB; i++)
    {
        B[i]=B[i-1]+rand()%100;
    }
 
  //Declarations
    cudaError_t errCuda;
    TYPE * CudaVecteurA = NULL ; 
    TYPE * CudaVecteurB = NULL ; 
    TYPE * CudaVecteurM = NULL ; 

    int nbthread = 512;  // a verifier 
    int NbDiagonale  = (sizeA + sizeB) / nbthread ;
    int NbWindows    = NbDiagonale ; 
    NbWindows       += (((sizeA + sizeB) % nbthread) == 0)?0:1 ;  // si (SizeA + SizeB) % nbthread == 0 alors nbWindows = 0  sinon = 1
    int  * CudaDiagBx   = NULL ;
    int  * CudaDiagAy   = NULL ;
 
    //Allocation 
    if (cudaSuccess != (errCuda = cudaMalloc((void**)&CudaVecteurA, sizeA * sizeof(TYPE))))
        { printf("PB allocation CudaVecteurA - %d - %s \n",errCuda,cudaGetErrorName(errCuda)) ; fflush(stdout) ; exit (1) ; } // cleanup a rajouter pour plus propre
    if (cudaSuccess != (errCuda = cudaMalloc((void**)&CudaVecteurB, sizeB * sizeof(TYPE))))
        { printf("PB allocation CudaVecteurB - %d - %s \n",errCuda,cudaGetErrorName(errCuda)) ; fflush(stdout); exit (1) ; }  // cleanup a rajouter pour plus propre
    if (cudaSuccess != (errCuda = cudaMalloc((void**)&CudaVecteurM, sizeM * sizeof(TYPE))))
        { printf("PB allocation CudaVecteurM - %d - %s \n",errCuda,cudaGetErrorName(errCuda)) ; fflush(stdout); exit (1) ; } 

     if (cudaSuccess != (errCuda = cudaMalloc((void**)&CudaDiagBx, (NbWindows + 1) * sizeof(int))))
        { printf("PB allocation CudaDiagBx - %d - %s \n",errCuda,cudaGetErrorName(errCuda)) ; fflush(stdout); exit (1) ; }
   
     if (cudaSuccess != (errCuda = cudaMalloc((void**)&CudaDiagAy, (NbWindows + 1)* sizeof(int))))
       { printf("PB allocation CudaDiagAy - %d - %s \n",errCuda,cudaGetErrorName(errCuda)) ; fflush(stdout);  exit (1) ; }
    
    if (cudaSuccess != cudaMemcpy(CudaVecteurA, A, sizeA * sizeof(TYPE), cudaMemcpyHostToDevice))
        { printf("PB copie host A -> cuda A \n") ; fflush(stdout);  exit(2) ; } 
    
    if (cudaSuccess != cudaMemcpy(CudaVecteurB, B, sizeB * sizeof(TYPE), cudaMemcpyHostToDevice))
        { printf("PB copie host B -> cuda B \n") ; fflush(stdout);  exit(2) ; } 
 
    cudaEventRecord(Start);

    PathBig<<<1,NbDiagonale>>>(CudaVecteurA, CudaVecteurB, sizeA , sizeB, CudaDiagBx, CudaDiagAy, nbthread,NbWindows) ;
 
    int nbBlock  = (sizeA+sizeB) / 1024 ; 
    nbBlock += ((sizeA+sizeB) % 1024)?1:0 ; 
 
 if (sizeM <1024)
 {
     printf("La fonction MergeBig ne peut pas être prise en compte car sizeA+sizeB <1024");
    exit(2);
 }

  else { MergeBig_k<<<nbBlock,1024>>> (CudaVecteurA, CudaVecteurB, CudaVecteurM, CudaDiagAy, CudaDiagBx, nbthread) ;}

  if (cudaSuccess != cudaMemcpy(M, CudaVecteurM, sizeM * sizeof(TYPE), cudaMemcpyDeviceToHost))
        { printf("PB copie cuda M -> host M \n") ; fflush(stdout);  exit(2) ; }
    cudaEventRecord(Stop) ; 


    check((char *)"Check tableau M après", sizeM, M);
    cudaEventElapsedTime(&m1, Start, Stop) ; 
    printf("Duree %f s\n",m1/1000) ;
    //Affiche ("Tableau M", M, sizeM); 
  
    //Free
    if (M != NULL ){ free(M); }
    if (A != NULL) { free(A) ; }
    if (B != NULL) { free(B) ; }
    if (CudaVecteurA != NULL) { cudaFree(CudaVecteurA) ; CudaVecteurA = NULL ; }
    if (CudaVecteurB != NULL) { cudaFree(CudaVecteurB) ; CudaVecteurB = NULL ; }
    if (CudaVecteurM != NULL) { cudaFree(CudaVecteurM) ; CudaVecteurM = NULL ; }
    if (CudaDiagAy != NULL) { cudaFree(CudaDiagAy) ; CudaDiagAy = NULL ; }
    if (CudaDiagBx != NULL) { cudaFree(CudaDiagBx) ; CudaDiagBx = NULL ; }
 
   return 0 ; 

}

