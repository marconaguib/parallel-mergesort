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

void MergeSimpleHOST(TYPE *A, TYPE *B, TYPE *M, int cardA, int cardB)
{
    int j = 0;
    int i = 0;

    // On utilise comme pointeurs les arguments de la fonctions
    while (i + j < cardA + cardB )
    {
        if (i >= cardA ) // On a épuisé tout les elts de A, donc on complete avec B
        {  *M = *B; // on utilise les pointeurs pour éviter de faire l opération i+j et se déplacer  = gain de performance
            M = M + 1 ; // Je déplace les pointeurs
            B = B + 1 ;
            j = j + 1 ;
        }
        else if ((j >= cardB) || (*A < *B))
        {   *M = *A ; M = M + 1 ; A = A + 1 ; i = i + 1 ; }
        else
        {   *M = *B ; M = M + 1 ; B = B + 1 ; j = j + 1 ; }
    }
} // End of MergeSimpleHOST

__global__ void MergeSmall_k(TYPE *A, TYPE *B, TYPE *M, int sizeA, int sizeB)
{
    int i = threadIdx.x ;
    Point K, P, Q;
    int offset ;

    if (i >= (sizeA + sizeB)) { return ;  }  // On gère les ébordements
    if ((sizeA == 0) || (sizeB == 0)) { return ; } // Un vecteur "NULL", donc l'autre est trie par hypothese

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

__global__ void PathBig(TYPE * CudaVecteurA, TYPE * CudaVecteurB, int sizeA , int sizeB, int * CudaDiagBx, int * CudaDiagAy, int nbthread,int NbWindows)
{
    // Initiaise les diagonales
    if(threadIdx.x == 0)
      {
      CudaDiagBx[0] = CudaDiagAy[0] = 0 ;
      CudaDiagBx[NbWindows] = sizeB ;
      CudaDiagAy[NbWindows] = sizeA ;
      }
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

void MergeSort(TYPE * M, int sizeM)
{

    //Declarations
    cudaError_t errCuda;
    TYPE * ptori  = NULL ; // pointeur origine
    TYPE * ptdest = NULL ; // pointeur destination
    TYPE * pttmp ;

    TYPE * cudaOri  = NULL ; // pointeur orgine dans CUDA
    TYPE * cudaDest = NULL ; // pointeur dest dans CUDA

    int t ;
    int  * CudaDiagBx   = NULL ;
    int  * CudaDiagAy   = NULL ;

    //Allocation
    if ((ptdest = (TYPE *) malloc(sizeM * sizeof(TYPE))) == NULL)
        { printf("PB allocation VecteurM2n") ; exit (1) ; }

    if (cudaSuccess != (errCuda = cudaMalloc((void**)&cudaOri, sizeM * sizeof(TYPE))))
        { printf("PB allocation CudaOri - %d - %s \n",errCuda,cudaGetErrorName(errCuda)) ; fflush(stdout); exit (1) ; }

    if (cudaSuccess != (errCuda = cudaMalloc((void**)&cudaDest, sizeM * sizeof(TYPE))))
        { printf("PB allocation CudaDest - %d - %s \n",errCuda,cudaGetErrorName(errCuda)) ; fflush(stdout); exit (1) ; }

    if (cudaSuccess != (errCuda = cudaMalloc((void**)&CudaDiagBx, (1025 + 1) * sizeof(int))))
        { printf("PB allocation CudaDiagBx pour  - %d - %s \n", errCuda,cudaGetErrorName(errCuda)) ; fflush(stdout); exit (1) ; }

     if (cudaSuccess != (errCuda = cudaMalloc((void**)&CudaDiagAy, (1025 + 1)* sizeof(int))))
         { printf("PB allocation CudaDiagAy - %d - %s \n",errCuda,cudaGetErrorName(errCuda)) ; fflush(stdout);  exit (1) ; }

    ptori  = M ;

    // Première itération on le trie à la main pour gagner du temps
    for (int i = 0 ; i < sizeM ; i += 2 )
    {
        if (ptori[i] > ptori[i+1])
        {
            ptdest[i+1] = ptori[i];
            ptdest[i]   = ptori[i+1] ;
        }
	      else
	      {
            ptdest[i]   = ptori[i];
            ptdest[i+1] = ptori[i+1];
      	}
    }

    // Flip Flop entre ptori et ptdest
    pttmp = ptdest ;
    ptdest= ptori ;
    ptori = pttmp ;

    t=2;
    // Seconde itération on le fait en séquentiel avec l'algo A du sujet pour gagner du temps
    for (int i = 0 ; i < sizeM ; i = i+(2*t))
    {
        int sizeA = min(t,sizeM-i);
        int sizeB = min(t,max(sizeM-(i+t),0));
        TYPE * ptA = ptori + i;
        TYPE * ptB = ptori + i + sizeA ;
        TYPE * ptM = ptdest + i ;
        MergeSimpleHOST(ptA, ptB, ptM, sizeA , sizeB) ;
      }

    if (cudaSuccess != (errCuda = cudaMemcpy(cudaOri, ptdest, sizeM * sizeof(TYPE), cudaMemcpyHostToDevice)))
    { printf("PB Copie Host ptDest -> cudaOri - %d - %s \n",errCuda,cudaGetErrorName(errCuda)) ; fflush(stdout); exit (1) ; }

    //Le reste des itérations on utilise mergesmall et mergebig
    for ( t = 4 ; t < sizeM ; t= t*2)
    {
        for ( int i = 0 ; i < sizeM ; i = i + (2*t))
        {
            int sizeA = min(t,sizeM-i);
            int sizeB = min(t,max(sizeM-(i+t),0));

	          TYPE * CudaVecteurA = cudaOri + i ;
	          TYPE * CudaVecteurB = cudaOri + i + sizeA ;

	          if ((sizeA == 0) || (sizeB == 0))
	          {
                if (sizeA != 0)
                {
                   if (cudaSuccess != (errCuda = cudaMemcpy(cudaDest + i, CudaVecteurA , sizeA * sizeof(TYPE), cudaMemcpyDeviceToDevice)))
                   { printf("PB Copie Cuda A -> ptDes rab %d - %d - %s \n",sizeA, errCuda,cudaGetErrorName(errCuda)) ; fflush(stdout); exit (1) ; }
		            }
                continue ;
	          }

            //Merge
            if (sizeA+sizeB <= 1024)
            {
                MergeSmall_k<<<1,sizeA+sizeB>>> (CudaVecteurA,CudaVecteurB,cudaDest+i,sizeA,sizeB);
            }
            else
            {
	        	    int nbthread = 1024;
                int NbDiagonale  = (sizeA + sizeB) / nbthread ;
		            if (NbDiagonale > 1024)
		            { printf("Oups, on n'a pas fait le code pour nbDiag %d > 1024\n",NbDiagonale) ;
		              return ;
		            }
                int NbWindows    = NbDiagonale ;
                NbWindows   += (((sizeA + sizeB) % nbthread) == 0)?0:1 ;  // si (SizeA + SizeB) % nbthread == 0 alors nbWindows = 0  sinon = 1
                PathBig<<<1,NbDiagonale>>>(CudaVecteurA, CudaVecteurB, sizeA , sizeB, CudaDiagBx, CudaDiagAy, nbthread,NbWindows) ;
                int nbBlock  = (sizeA+sizeB) / 1024 ;
       	        nbBlock += ((sizeA+sizeB) % 1024)?1:0 ;
       	        MergeBig_k<<<nbBlock,1024>>> (CudaVecteurA, CudaVecteurB, cudaDest+i, CudaDiagAy, CudaDiagBx, nbthread) ;
            }
          }// End for i
	    // Flip Flop entre les bancs cudaOri et cudaDest
	    TYPE * cudaTmp = cudaDest ;
	    cudaDest = cudaOri ;
	    cudaOri  = cudaTmp ;
    } // End of loop t

    if (cudaSuccess != cudaMemcpy(M, cudaOri, sizeM * sizeof(TYPE), cudaMemcpyDeviceToHost))
    { printf("PB copie cuda M -> host M \n") ; fflush(stdout);  exit(2) ; }

    // Free
    if (cudaOri != NULL) { cudaFree(cudaOri) ; cudaOri = NULL ; }
    if (cudaDest != NULL) { cudaFree(cudaDest) ; cudaDest = NULL ; }
    if (CudaDiagAy != NULL) { cudaFree(CudaDiagAy) ; CudaDiagAy = NULL ; }
    if (CudaDiagBx != NULL) { cudaFree(CudaDiagBx) ; CudaDiagBx = NULL ; }
}

int main(int argc, char ** argv)
{
    //déclaration
    int sizeM;
    TYPE* M;
    cudaEvent_t Start; cudaEvent_t Stop; cudaEventCreate(&Start) ; cudaEventCreate(&Stop) ;
    float temps_iter;
    srand(1998);
    for (int i=0; i<11; i++)
    {
        temps_iter=0;
        sizeM = (1024*pow(2,i));
        M = (TYPE *) malloc(sizeM * sizeof(TYPE));
        for (int i =0; i<sizeM; i++) M[i]=rand();

        cudaEventRecord(Start);
        MergeSort(M,sizeM);
        cudaEventRecord(Stop) ;

        check("tableau M après", sizeM, M);
        cudaEventElapsedTime(&temps_iter, Start, Stop) ;

        free(M);
        printf("Duree pour %d : %f s\n",sizeM,temps_iter/1000) ;
    }

    return 0 ;
}
