// **********************************************************************************************************************************************
// KERNELS PRINCIPAUX POUR PROJET HPC
// ASTRID LEGAY ET MARCO NAGUIB - MAIN 5
// 15 DECEMBRE 2020
// **********************************************************************************************************************************************

// STRUCTURE UTILE
// Pour utiliser la notion de point
typedef struct
{
   int x ;
   int y ;
}  Point ;

// **********************************************************************************************************************************************
//  QUESTIONS 1
// **********************************************************************************************************************************************

// MergeSmall_k permet de merger le tableau A et B (déjà triés) dans M
// On prend en entrée le tableau A trié, le tableau B trié, le tableau M pour mettre le résultat, la taille de A et la taille de B
// Parallélisation de l'algorithme B
__global__ void MergeSmall_k(TYPE *A, TYPE *B, TYPE *M, int cardA, int cardB)
{
    Point K;
    Point P;
    Point Q;
    int offset ;
    int i = threadIdx.x ; // Id du thread, permet de savoir quelle valeur va être rangé à sa place définitive.
    {
    	if (i > cardA)
      {
    		K.x = i - cardA ; K.y = cardA ;
    		P.x = cardA ; P.y = i - cardA ;
    	}
    	else
      {
    		K.x = 0 ; K.y = i ;
    		P.x = i ; P.y = 0 ;
    	}
    	while (1)
      {
        offset = abs (K.y - P.y) / 2 ;
        Q.x = K.x + offset ; Q.y = K.y - offset ; // Q est bien sur une diagonale à 45°

    		if (((Q.y >= 0 ) && (Q.x <= cardB)) &&
    			((Q.y == cardA) || (Q.x == 0) || (A[Q.y]>B[Q.x -1]))){

    			if ((Q.x == cardB) || (Q.y == 0) || (A[Q.y-1]<=B[Q.x]))
          {
    				if((Q.y < cardA) && ((Q.x == cardB) || (A[Q.y] <= B[Q.x])))
            {  M[i]= A[Q.y] ; }
    				else
            {	 M[i] = B[Q.x] ; }
    				break;  // Pour simuler passage au thread suivant
    			}
    			else
          {  K.x = Q.x +1 ; K.y = Q.y - 1 ; }
    		}
    		else
        {	P.x = Q.x -1 ; P.y = Q.y +1 ; }
    	}
    }
}

// Ajout des lignes 68 à 82 pour travailler sur la mémoire shared
__global__ void MergeSmallShared_k(TYPE *GlobalCudaA, TYPE *GlobalCudaB, TYPE *M, int sizeA, int sizeB)
{
    extern __shared__ TYPE dataAB[] ; // j utilise la mémoire partagée entre les threads
    unsigned int tid = threadIdx.x; // numéro du thread dans le block courant
    unsigned int i   = blockIdx.x*blockDim.x + threadIdx.x; // numéro du thread  sur l ensemble des blocks

    if (tid >= (sizeA + sizeB)) { return ;  }  // On gère les ébordements

 // Chargement des données dans la mémoire partagée par le thread ;
     dataAB[tid] = (i < sizeA)?GlobalCudaA[i]:GlobalCudaB[i-sizeA] ;  // voir si on travaille sur le vecteur A ou B

 // On attend que tous les threads aient faits le travail ( chargé la mémoire)
    __syncthreads();  //

 // On recadre nos pointeurs pourqu'ils pointent vers la mémoire partagée et non la globale
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

}

// **********************************************************************************************************************************************
// QUESTION 2
// **********************************************************************************************************************************************


__global__ void PathBig(TYPE * CudaVecteurA, TYPE * CudaVecteurB, int sizeA , int sizeB, int * CudaDiagBx, int * CudaDiagAy, int nbthread, int NbWindows)
{
    // A : an array of size sizeA
    // B : an array of size sizeB
    // (CudaDiagBx,CudaDiagAy) recieve the respective coordinates of the "red points"
    // nbthread : Number of threads, preferably 1024
    // NbWindows : Number of windows

    //Initialisation diagolane
    CudaDiagBx[0] = CudaDiagAy[0] = 0 ; //(0,0)
    CudaDiagBx[NbWindows] = sizeB ;
    CudaDiagAy[NbWindows] = sizeA ; //(sizeA,sizeB)

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
}

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

// **********************************************************************************************************************************************
// QUESTION  3
// **********************************************************************************************************************************************

// Nous vous avons expliquer l'algortihme de Merge Sort précédement, donc nous travaillons par taille  : t = t*2
// Tout d'abord, il est important de noter qu'on ne travaille en parallèle qu'à partir de la taille 4 pour optimiser le code
// Taille 1 : tri à la "main" sur le HOST
// Taille 2 : tri de l'algorithme A de l'anoncé sur le HOST
// A partir de la taille 4 : mise en place de CUDA sur GPU pour paralléliser : si size A + sizeB <= 1024 : appelle MergeSmall sinon PathBig et MergeBig
// Ensuite nous avons une notion de FLIP/FLOP : mis en place pour éviter de nombreuses copies et ainsi gagner du temps
// Concernant la notion de FLIP/FLOP, je vais l'expliquer avec un schéma avant de monter sur le code

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

// **********************************************************************************************************************************************
// QUESTION 5
// **********************************************************************************************************************************************

__global__ void MergeSmallBatch_k(TYPE *ABAB, int sizeM_tot, TYPE* MM, int d)
{
    int i = threadIdx.x%d;
    int Qt = (threadIdx.x-i)/d;
    int gbx = Qt + blockIdx.x*(blockDim.x/d);
    if (threadIdx.x + blockIdx.x*blockDim.x >= sizeM_tot) return;

    int t = d/2;
    int sizeA = t;
    int sizeB = t;

    ABAB=ABAB+gbx*d;
    TYPE* A=ABAB;
    TYPE* B=A+sizeA;
    TYPE* M=MM+gbx*d;


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
}

// **********************************************************************************************************************************************
// PARTIE 3
// **********************************************************************************************************************************************

void MergeSort(TYPE * M, int sizeM)
{
    //Declarations
    cudaError_t errCuda;
    TYPE * cudaOri  = NULL ; // pointeur orgine dans CUDA
    TYPE * cudaDest = NULL ; // pointeur dest dans CUDA

    int  * CudaDiagBx   = NULL ;
    int  * CudaDiagAy   = NULL ;

    int t ;

    //Allocation
    if (cudaSuccess != (errCuda = cudaMalloc((void**)&cudaOri, sizeM * sizeof(TYPE))))
        { printf("PB allocation CudaVecteurM1 - %d - %s \n",errCuda,cudaGetErrorName(errCuda)) ; fflush(stdout); exit (1) ; }  // cleanup a rajouter pour plus propre

    if (cudaSuccess != (errCuda = cudaMalloc((void**)&cudaDest, sizeM * sizeof(TYPE))))
        { printf("PB allocation CudaVecteurM2 - %d - %s \n",errCuda,cudaGetErrorName(errCuda)) ; fflush(stdout); exit (1) ; }

    if (cudaSuccess != (errCuda = cudaMalloc((void**)&CudaDiagBx, 1026 * sizeof(int))))
       { printf("PB allocation CudaDiagBx %d - %d - %s \n", errCuda,cudaGetErrorName(errCuda)) ; fflush(stdout); exit (1) ; }

    if (cudaSuccess != (errCuda = cudaMalloc((void**)&CudaDiagAy, 1026 * sizeof(int))))
       { printf("PB allocation CudaDiagAy - %d - %s \n",errCuda,cudaGetErrorName(errCuda)) ; fflush(stdout);  exit (1) ; }

    //Initialiser cudaOri
    if (cudaSuccess != (errCuda = cudaMemcpy(cudaOri, M, sizeM * sizeof(TYPE), cudaMemcpyHostToDevice)))
       { printf("PB Copie Host ptDest -> cudaOri - %d - %s \n",errCuda,cudaGetErrorName(errCuda)) ; fflush(stdout); exit (1) ; }

    //Trier cudaOri par blocs de 2, puis par blocs de 4, etc jusqua 512
    for ( t = 1 ; t <= 512 and t<sizeM ; t= t*2){
        //partie divisible par d
        int d=t*2;
        int size_AetB = sizeM%d;//taille restante
        MergeSmallBatch_k<<<1024,1024>>>(cudaOri,sizeM-size_AetB,cudaDest,t*2);

        //partie restante
        int sizeA = min(size_AetB,t);
        int sizeB = size_AetB - sizeA;
        TYPE* cudaM = cudaDest+sizeM-size_AetB;
        TYPE* cudaA = cudaOri+sizeM-size_AetB;
        TYPE* cudaB = cudaA+sizeA;
        MergeSmall_k<<<1,sizeA+sizeB>>> (cudaA,cudaB,cudaM,sizeA,sizeB);

        // Flip Flop entre les bancs cudaDest et cudaOri
        TYPE * cudaTmp = cudaDest ;
        cudaDest = cudaOri ;
        cudaOri  = cudaTmp ;
    }

    //t=512 on trie par blocs de taille supérieure à laide de PathBig et MergeBig
    for ( t = t ; t < sizeM ; t= t*2)
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
            if (sizeA+sizeB <= 1024) { printf("Oups, on est censé avoir traité ce cas par le merge batch\n") ; return ;}
            int nbthread = 1024;
            int NbDiagonale  = (sizeA + sizeB) / nbthread ;
            if (NbDiagonale > 1024) { printf("Oups, on n'a pas fait le code pour nbDiag %d > 1024\n",NbDiagonale) ; return ; }
            int NbWindows    =  NbDiagonale ;
            NbWindows   += (((sizeA + sizeB) % nbthread) == 0)?0:1 ;  // si (SizeA + SizeB) % nbthread == 0 alors nbWindows = 0  sinon = 1


            PathBig<<<1,NbDiagonale>>>(CudaVecteurA, CudaVecteurB, sizeA , sizeB, CudaDiagBx, CudaDiagAy, nbthread,NbWindows) ;
            int nbBlock  = (sizeA+sizeB) / 1024 ;
            nbBlock += ((sizeA+sizeB) % 1024)?1:0 ;
            MergeBig_k<<<nbBlock,1024>>> (CudaVecteurA, CudaVecteurB, cudaDest+i, CudaDiagAy, CudaDiagBx, nbthread) ;
        } // End for i

        // Flip Flop entre les bancs cudaDest et cudaOri
        TYPE * cudaTmp = cudaDest ;
        cudaDest = cudaOri ;
        cudaOri  = cudaTmp ;

    }
    //cudaOri est entièrement trié

    //remettre dans M
    if (cudaSuccess != cudaMemcpy(M, cudaOri, sizeM * sizeof(TYPE), cudaMemcpyDeviceToHost))
    { printf("PB copie cuda M -> host M \n") ; fflush(stdout);  exit(2) ; }


    // Free
    if (cudaOri != NULL) { cudaFree(cudaOri) ; cudaOri = NULL ; }
    if (cudaDest != NULL) { cudaFree(cudaDest) ; cudaDest = NULL ; }
    if (CudaDiagAy != NULL) { cudaFree(CudaDiagAy) ; CudaDiagAy = NULL ; }
    if (CudaDiagBx != NULL) { cudaFree(CudaDiagBx) ; CudaDiagBx = NULL ; }
}
