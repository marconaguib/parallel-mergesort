%%cu
#include <stdio.h>
#include <stdlib.h>

#define TYPE long
#define FMT  "ld"

// Taille des vecteurs
//define sizeA 500
//define sizeB 500

// Algo de remplissage
enum EnumTypeRemplissage { AlgoPairImpair , AlgoRandom } ;
char MSG[sizeof(EnumTypeRemplissage)][64] =
    { "Algo A Pair et B Impair" ,
      "Algo remplissage aleatoire"
    } ;

EnumTypeRemplissage typeRemplissage = AlgoRandom ;

// Algo de Merge : Différents algorithmes pour pour faire le merge
enum EnumMerge {   AlgoMergePathGPU , AlgoMergeSmall_k, AlgoMergeSmallShared_k } ;

char MSGMerge[sizeof(EnumMerge)][64] =
   {  "Merge via MergePathGPU" ,
     "Merge via PathGPU en // pour les threads en parallèle", "Merge via PathGPU en // pour la mémoire shared"
   } ;

EnumMerge Algo = AlgoMergeSmallShared_k ;

// On parle de la notion de point d
typedef struct
{
   int x ;
   int y ;
}  Point ;

// Algorithme B en gpu
__global__ void MergePathGPU(TYPE *A, TYPE *B, TYPE *M, int cardA, int cardB)
{
    Point K;
    Point P;
    Point Q;
    int offset ;
    // int i = threadIdx.x ; // Id du thread, permet de savoir quelle valeur va être rangé à sa place définitive.
    for (int i = 0 ; i < cardA + cardB ;  i ++)
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
} // End of MergePathGPU

__global__ void MergeSmall_k(TYPE *A, TYPE *B, TYPE *M, int cardA, int cardB)
{
    Point K;
    Point P;
    Point Q;
    int offset ;
    int i = threadIdx.x ; // Id du thread, permet de savoir quelle valeur va être rangé à sa place définitive.
    // for (int i = 0 ; i < cardA + cardB ;  i ++)
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
} // End of MergeSmall_k

__global__ void MergeSmallShared_k(TYPE *GlobalCudaA, TYPE *GlobalCudaB, TYPE *M, int sizeA, int sizeB)
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

} // End of MergeSmallShared_k

// Pour le debug, On peut afficher le tableau
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

// Pour vérifier que le tableau est trié
int check(char * msg, int Nb, TYPE * pto)
{
    TYPE * pt1 = pto ;
    TYPE * pt2 = pto + 1 ;

    for (int i = 0 ; i < Nb-1 ; i ++)
    {
        if (*pt1 > *pt2)
        { printf("Check %s pour %d - Erreur en position %d %" FMT " > %" FMT " \n", msg, Nb, i, *pt1, *pt2) ;
          return i ;
        }
        pt1 ++ ; pt2 ++ ;
    }

    printf("Check %s pour %d est OK \n", msg, Nb) ;
    return 0 ;
}

// Compare 2 tableaux résultats (en fait l égalité entre 2 tableaux)
void compareResult(TYPE * res1, TYPE * res2, int Nb)
{
    int nberr = 0 ;

    for (int i = 0 ; i < Nb ; i ++, res1 ++, res2 ++)
    {
        if (*res1 != *res2)
        {   nberr ++ ;
            if (nberr < 16) // Seuil d affichage
            {
                printf("En position %d, %" FMT " != %" FMT "\n",i,*res1,*res2) ;
            }
        }
    }

    if (nberr == 0)
    { printf("Les 2 vecteurs de %d elements sont identiques.\n",Nb) ; }
    else
    { printf("Les 2 vecteurs differents en %d points (sur %d)\n",nberr, Nb) ; }
}

// Déclaration
   TYPE * HostVecteurA = NULL ;
   TYPE * HostVecteurB = NULL ;
   TYPE * HostVecteurC = NULL ;
   TYPE * HostVecteurD = NULL ;

   TYPE * CudaVecteurA = NULL ;
   TYPE * CudaVecteurB = NULL ;
   TYPE * CudaVecteurC = NULL ;

void cleanup()
{
    if (HostVecteurA != NULL) { free(HostVecteurA) ; }
    if (HostVecteurB != NULL) { free(HostVecteurB) ; }
    if (HostVecteurC != NULL) { free(HostVecteurC) ; }
    if (HostVecteurD != NULL) { free(HostVecteurD) ; }

    if (CudaVecteurA != NULL) { cudaFree(CudaVecteurA) ; }
    if (CudaVecteurB != NULL) { cudaFree(CudaVecteurB) ; }
    if (CudaVecteurC != NULL) { cudaFree(CudaVecteurC) ; }
}

int mesure(int sizeA , int sizeB , EnumMerge Algo)
{

// Hello
   printf("CardA %d - CardB %d - Algo de remplissage %s - %s\n",
          sizeA, sizeB, MSG[typeRemplissage],MSGMerge[Algo]) ;

// allocation dynamique Sur le host
   if (( HostVecteurA = (TYPE *) malloc(sizeA * sizeof(TYPE))) == NULL)
   { printf("PB allocation HostVecteurA\n") ; cleanup() ; exit(1) ; }

   if ((HostVecteurB = (TYPE *) malloc(sizeB * sizeof(TYPE))) == NULL)
   { printf("PB allocation HostVecteurB\n") ; cleanup() ; exit(1) ; }

   if ((HostVecteurC = (TYPE *) malloc((sizeA + sizeB) * sizeof(TYPE))) == NULL)
   { printf("PB allocation HostVecteurC\n") ; cleanup() ; exit(1) ; }

   if ((HostVecteurD = (TYPE *) malloc((sizeA + sizeB) * sizeof(TYPE))) == NULL)
   { printf("PB allocation HostVecteurD\n") ; cleanup() ; exit(1) ; }

// Initialisation des deux vecteurs de base sur le Host
   switch (typeRemplissage)
   { case AlgoPairImpair:
       for (int j = 0 ; j < sizeA; j ++) { HostVecteurA[j] = 2 * j ; }
       for (int j = 0 ; j < sizeB; j ++) { HostVecteurB[j] = 2 * j + 1 ; }
       break ;
     case AlgoRandom:
       int N = 100 ;
       // srand (time (NULL));
       srand (1925) ;
       HostVecteurA[0] = rand() % N ;
       HostVecteurB[0] = rand() % N ;
       for (int j = 1 ; j < sizeA ; j ++)
          { HostVecteurA[j] = HostVecteurA[j-1] + (rand() % N) ; }
       for (int j = 1 ; j < sizeB ; j ++)
          { HostVecteurB[j] = HostVecteurB[j-1] + (rand() % N) ; }
       break ;
   }

 // Vérifier qu on génére bien les tableaux
    check("Vecteur A ", sizeA, HostVecteurA) ;
    check("Vecteur B ", sizeB, HostVecteurB) ;

 // Mesures de temps
    cudaEvent_t Start, StartAllocA, StartAllocB, StartAllocC, StartPushA, StartPushB, StartGetC, StartMerge ;
    cudaEvent_t Stop,  StopAllocA, StopAllocB, StopAllocC, StopPushA, StopPushB, StopGetC, StopMerge ;

    cudaEventCreate(&Start) ; cudaEventCreate(&StartAllocA) ; cudaEventCreate(&StartAllocB) ; cudaEventCreate(&StartAllocC) ;
    cudaEventCreate(&StartPushA) ; cudaEventCreate(&StartPushB) ; cudaEventCreate(&StartGetC) ; cudaEventCreate(&StartMerge) ;

    cudaEventCreate(&Stop) ; cudaEventCreate(&StopAllocA) ; cudaEventCreate(&StopAllocB) ; cudaEventCreate(&StopAllocC) ;
    cudaEventCreate(&StopPushA) ; cudaEventCreate(&StopPushB) ; cudaEventCreate(&StopGetC) ; cudaEventCreate(&StopMerge) ;

 // Allocation dynamique sur le GPU
    cudaEventRecord(Start);
    cudaEventRecord(StartAllocA);
    if (cudaSuccess != cudaMalloc((void**)&CudaVecteurA, sizeA * sizeof(TYPE)))
    { printf("PB allocation CudaVecteurA\n") ; cleanup() ; exit (1) ; }
    cudaEventRecord(StopAllocA); cudaEventSynchronize(StopAllocA) ;

    cudaEventRecord(StartAllocB);
    if (cudaSuccess != cudaMalloc((void**)&CudaVecteurB, sizeB * sizeof(TYPE)))
    { printf("PB allocation CudaVecteurB\n") ; cleanup() ; exit (1) ; }
    cudaEventRecord(StopAllocB); cudaEventSynchronize(StopAllocB) ;

    cudaEventRecord(StartAllocC);
    if (cudaSuccess != cudaMalloc((void**) &CudaVecteurC, (sizeA + sizeB) * sizeof(TYPE)))
    { printf("PB allocation CudaVecteurC\n") ; cleanup() ; exit (1) ; }
    cudaEventRecord(StopAllocC); cudaEventSynchronize(StopAllocC) ;

// Recopie Host => GPU
   cudaEventRecord(StartPushA);
   if (cudaSuccess != cudaMemcpy(CudaVecteurA, HostVecteurA,sizeA * sizeof(TYPE), cudaMemcpyHostToDevice))
   { printf("PB copie Hosta -> cuda A\n") ; cleanup() ; exit(2) ; }
   cudaEventRecord(StopPushA); cudaEventSynchronize(StopPushA) ;

   cudaEventRecord(StartPushB);
   if (cudaSuccess != cudaMemcpy(CudaVecteurB, HostVecteurB,sizeB * sizeof(TYPE), cudaMemcpyHostToDevice))
   { printf("PB copie Hosta -> cuda B\n") ; cleanup() ; exit(2) ; }
   cudaEventRecord(StopPushB); cudaEventSynchronize(StopPushB) ;

   cudaEventRecord(StartMerge) ;
   switch(Algo)
   {
       case AlgoMergePathGPU:
            MergePathGPU<<<1,1>>>(CudaVecteurA, CudaVecteurB, CudaVecteurC, sizeA, sizeB) ;
       break ;
       case AlgoMergeSmall_k:
            if (sizeA + sizeB > 1024)
            {  printf("Cet algo ne fonctionne que pour sizeA %d + sizeB %d < 1024 (%d)\n",
                     sizeA, sizeB, (sizeA +sizeB)) ;
            }
            else //
            {  MergeSmall_k<<<1,sizeA+sizeB>>>(CudaVecteurA, CudaVecteurB, CudaVecteurC, sizeA, sizeB) ; }
        case AlgoMergeSmallShared_k:
            if (sizeA + sizeB > 1024)
            {  printf("Cet algo ne fonctionne que pour sizeA %d + sizeB %d < 1024 (%d)\n",
                     sizeA, sizeB, (sizeA +sizeB)) ;
            }
            else // 3eme argument permet de faire la réservation de la mémoire __shared__
            {  MergeSmallShared_k<<<1,sizeA+sizeB,(sizeA+sizeB) * sizeof(TYPE)>>>(CudaVecteurA, CudaVecteurB, CudaVecteurC, sizeA, sizeB) ; }

       break ;
   }

   cudaEventRecord(StopMerge) ; cudaEventSynchronize(StopMerge) ;

// On recupere le resultat donc GPU => CPU
   cudaEventRecord(StartGetC) ;
   if (cudaSuccess != cudaMemcpy(HostVecteurC, CudaVecteurC, (sizeA + sizeB) * sizeof(TYPE), cudaMemcpyDeviceToHost))
   { printf("PB copie cuda C -> host C \n") ; cleanup() ; exit(2) ; }
   cudaEventRecord(StopGetC) ; cudaEventSynchronize(StopGetC) ;

   cudaEventRecord(Stop) ; cudaEventSynchronize(Stop) ;

// --- Affichage des temps de traitement ---
   float m1;
   //float  m2, m3 ;
   //cudaEventElapsedTime(&m1, StartAllocA, StopAllocA) ;
   //cudaEventElapsedTime(&m2, StartAllocB, StopAllocB) ;
   //cudaEventElapsedTime(&m3, StartAllocC, StopAllocC) ;

  /* printf("Allocation A (sizeA %d) %f ms - B (sizeB %d) %f ms - C (sizeC %d) %f ms \n",
           sizeA, m1, sizeB , m2 , sizeA + sizeB , m3) ;

   cudaEventElapsedTime(&m1, StartPushA, StopPushA) ;
   cudaEventElapsedTime(&m2, StartPushB, StopPushB) ;
   cudaEventElapsedTime(&m3, StartGetC,  StopGetC) ;

   printf("PushA (sizeA %d) %f ms - Débit %f Mo/s - PushB (sizeB %d) %f ms - Débit %f Mo/s \n",
           sizeA*sizeof(TYPE), m1, (sizeof(TYPE) * sizeA) / m1 / 1000 ,
           sizeB*sizeof(TYPE), m2, (sizeof(TYPE) * sizeB) / m2 / 1000 ) ;

   printf("GetC (sizeC %d) %f ms - Débit %f Mo/s\n",
           (sizeA+sizeB)*sizeof(TYPE), m3, (sizeof(TYPE) * (sizeA + sizeB)) / m3 / 1000 ) ;
 */

   cudaEventElapsedTime(&m1, StartMerge, StopMerge) ;
   printf("Duree %f ms\n",m1) ;
    // cudaEvent_t Start, StartAllocA, StartAllocB, StartAllocC, StartPushA, StartPushB, StartGetC, StartMerge ;
    // cudaEvent_t Stop,  StopAllocA, StopAllocB, StopAllocC, StopPushA, StopPushB, StopGetC, StopMerge ;

// --- Un peu de travail sur le HOST, pour valider nos résultats ---
// Le vecteur résultat est trié, mais pas nécessairement juste
   check("Vecteur M ",sizeA+sizeB, HostVecteurC) ;



   // Affiche("VectC", HostVecteurC, sizeA + sizeB) ;

   cleanup() ; printf("Fin de mesure \n") ;
   return 0 ;
}

int main(int argc , char ** argv)
{

    mesure( 50,  50, AlgoMergePathGPU) ;
    mesure(100, 100, AlgoMergePathGPU) ;
    mesure(150, 150, AlgoMergePathGPU) ;
    mesure(200, 200, AlgoMergePathGPU) ;
    mesure(250, 250, AlgoMergePathGPU) ;
    mesure(300, 300, AlgoMergePathGPU) ;
    mesure(350, 350, AlgoMergePathGPU) ;
    mesure(400, 400, AlgoMergePathGPU) ;
    mesure(450, 450, AlgoMergePathGPU) ;
    mesure(500, 500, AlgoMergePathGPU) ;

    mesure( 50,  50, AlgoMergeSmall_k) ;
    mesure(100, 100, AlgoMergeSmall_k) ;
    mesure(150, 150, AlgoMergeSmall_k) ;
    mesure(200, 200, AlgoMergeSmall_k) ;
    mesure(250, 250, AlgoMergeSmall_k) ;
    mesure(300, 300, AlgoMergeSmall_k) ;
    mesure(350, 350, AlgoMergeSmall_k) ;
    mesure(400, 400, AlgoMergeSmall_k) ;
    mesure(450, 450, AlgoMergeSmall_k) ;
    mesure(500, 500, AlgoMergeSmall_k) ;

    mesure( 50,  50, AlgoMergeSmallShared_k) ;
    mesure(100, 100, AlgoMergeSmallShared_k) ;
    mesure(150, 150, AlgoMergeSmallShared_k) ;
    mesure(200, 200, AlgoMergeSmallShared_k) ;
    mesure(250, 250, AlgoMergeSmallShared_k) ;
    mesure(300, 300, AlgoMergeSmallShared_k) ;
    mesure(350, 350, AlgoMergeSmallShared_k) ;
    mesure(400, 400, AlgoMergeSmallShared_k) ;
    mesure(450, 450, AlgoMergeSmallShared_k) ;
    mesure(500, 500, AlgoMergeSmallShared_k) ;

    return 0 ;
}
