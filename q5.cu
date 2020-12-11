%%cu
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define BILLION  1000000000.0F

// Pour pouvoir experimenter les performances avec les différents types
// FMT  Permet d'avoir un % adapté pour le printf et donc de pas avoir de warning
#define TYPE int
#define FMT  "d"

typedef struct
{
   int x ;
   int y ;
}  Point ;


void Affiche (char * tabMsg, TYPE * ptBuffer, int NB)
{
   TYPE * pt = ptBuffer ;
   for ( int k = 0 ; k < NB  ; k++ , pt ++)
   {   printf(" - %s[%03d] = %6" FMT, tabMsg, k , *pt) ;
       if ((k % 5) == (4))
       {  printf("\n") ; fflush(stdout);  }

   }
   printf("\n") ;
  fflush(stdout);
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
    //	return i ;
	exit(25) ;
        }
        pt1 ++ ; pt2 ++ ;
    }

    printf("Check %s pour %d est OK \n", msg, Nb) ;
    return 0 ;
}
__global__ void MergeSmallBatch_k(TYPE *M, int sizeM_tot, TYPE* N, int d)
{
    int i = threadIdx.x%d;
    int Qt = (threadIdx.x-i)/d;
    int gbx = Qt + blockIdx.x*(blockDim.x/d);
    if (threadIdx.x + blockIdx.x*blockDim.x >= sizeM_tot) return; //gerer les débordements

    int t = d/2;
    int sizeA = t;
    int sizeB = t;

    M=M+gbx*d;
    TYPE* A=M;
    TYPE* B=A+sizeA;


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
                   {  N[i+gbx*d] = A[Q.y] ; }
                   else
                   {  N[i+gbx*d] = B[Q.x] ; }
                   break ;
              }
              else
              {  K.x = Q.x + 1 ; K.y = Q.y - 1 ; }
         }
         else
         { P.x = Q.x -1 ; P.y = Q.y + 1 ; }
    }
}
int main(int argc, char ** argv)
{
    //déclaration
    int N = 10000;
    cudaError_t errCuda;
    TYPE* ABAB; //[A_0,B_0,A_1,B_1,...]
    TYPE* MM; // [M_0,M_1,...], les merges respectifs de [A_0,B_0,A_1,B_1,...]
    TYPE* cudaABAB;
    TYPE* cudaMM;


    for (int d=4; d<=1024; d=d*2)
    {
        float m1;
       cudaEvent_t Start; cudaEvent_t Stop; cudaEventCreate(&Start) ; cudaEventCreate(&Stop) ;


        int size_total=d*N;

        //allocation
        if ((ABAB = (TYPE *) malloc(size_total * sizeof(TYPE))) == NULL)
            { printf("PB allocation Vecteur Ori\n") ; exit (1) ; }
        if ((MM = (TYPE *) malloc(size_total * sizeof(TYPE))) == NULL)
            { printf("PB allocation Vecteur Dest\n") ; exit (1) ; }

        //initialisation
        srand(5);
        for (int i =0; i<size_total; i++)
        {
            if (i%(d/2)==0) ABAB[i] = rand()%100;
            else ABAB[i]=ABAB[i-1]+rand()%100;
        }
        // Il faut que tous les A et les B soient triés
        // Donc ABAB est trié par blocs de taille (d/2)


        //Allocation
        if (cudaSuccess != (errCuda = cudaMalloc((void**)&cudaABAB, size_total * sizeof(TYPE))))
            { printf("PB allocation CudaVecteurABAB - %d - %s \n",errCuda,cudaGetErrorName(errCuda)) ; fflush(stdout); exit (1) ; }  // cleanup a rajouter pour plus propre
        if (cudaSuccess != (errCuda = cudaMalloc((void**)&cudaMM, size_total * sizeof(TYPE))))
            { printf("PB allocation CudaVecteurMM - %d - %s \n",errCuda,cudaGetErrorName(errCuda)) ; fflush(stdout); exit (1) ; }  // cleanup a rajouter pour plus propre

        if (cudaSuccess != (errCuda = cudaMemcpy(cudaABAB, ABAB, size_total * sizeof(TYPE), cudaMemcpyHostToDevice)))
        { printf("PB Copie ABAB -> cudaABAB - %d - %s \n",errCuda,cudaGetErrorName(errCuda)) ; fflush(stdout); exit (1) ; }

        cudaEventRecord(Start);
        MergeSmallBatch_k<<<1024,1024>>>(cudaABAB,size_total,cudaMM,d); //a revoir
        cudaEventRecord(Stop);

        if (cudaSuccess != cudaMemcpy(MM, cudaMM, size_total * sizeof(TYPE), cudaMemcpyDeviceToHost))
          { printf("PB copie cudaMM -> MM \n") ; fflush(stdout);  exit(2) ; }

        cudaEventElapsedTime(&m1, Start, Stop) ;
        printf("Duree pour d = %4d : %f ms\n",d,m1) ;

        //free
        free(MM);
        free(ABAB);
        if (cudaABAB != NULL) { cudaFree(cudaABAB) ; cudaABAB = NULL ; }
        if (cudaMM != NULL) { cudaFree(cudaMM) ; cudaMM = NULL ; }

    }
    return 0 ;
}
