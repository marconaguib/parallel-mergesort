#include <stdio.h>
#include <stdlib.h>

// Pour pouvoir experimenter les performances avec les différents types
// FMT  Permet d'avoir un % adapté pour le printf et donc de pas avoir de warning
#define TYPE int
#define FMT  "d"

// Pour le calcul de temps
#define BILLION  1000000000.0F

// On parle de la notion de point dans l algo B
typedef struct
{
   int x ;
   int y ;
}  Point ;

// Méthode de remplissage ou d initialisation des vecteurs à trier
// Pair / Impair : A[0] = 0 / B[0] = 1 etc
// Binaire  : A[i] = 1  / B[i] = 2
// Random et Random2 : donne des valeurs aléatoires mais garentie que A et B restent triés 
// Petit :  A vaut 1 à n et B de n+1 à m 
// End :  savoir nombre de message pour printer
   enum EnumTypeRemplissage { RemplirPairImpair, RemplirBinaire, RemplirRandom , RemplirRandom2, RemplirPetit , RemplirEnd } ;
  
   extern char MSGRemplir[RemplirEnd][64] ;
  
// Algo de Merge de vecteur 
   enum EnumMerge { TriMergeSimpleHOST, TriMergePathHOST, TriMergePathGPU_1024, 
	TriMergePath_1024_shared,TriWindowsGPU_Para, TriEnd} ;
   extern char MSGMerge[TriEnd][64] ;

// Nettoyer 
   void cleanup() ;

// Nos outils sur le Host 
// Pour initilaiser les vecteurs (initGene : mettre des valeurs dans A et B)
   void initVecteur(TYPE * HostVecteurA, int SizeA, TYPE * HostVecteurB, int SizeB, TYPE * HostVecteurC, enum EnumTypeRemplissage typeRemplissage, int initGene)  ; 
// Pour afficher un vecteur 
   void Affiche(char * tabMsg, TYPE * ptBuffer, int NB) ;
// Verifier qu'un tableau est trié 
   int  check(char * msg, int Nb, TYPE * pto) ;
// Pour compare 2 vecteurs : verifier que ça soit égaux  
   int  compare(TYPE * tab1 , TYPE * tab2 , int Nb) ;
// Pour afficher les diagonales 
   void AfficheDiag(int * ADiag, int * BDiag, int sz) ; 

// Implementation des Algos sur Host pour comprendre les mécanismes
   void MergeSimpleHOST(TYPE *A, TYPE *B, TYPE *M, int sizeA, int sizeB) ;
   void MergePathHOST(TYPE *A, TYPE *B, TYPE *M, int sizeA, int sizeB) ;
   void cleaner() ;
   void MergeWindowsGPU(TYPE * HostVecteurA, TYPE * HostVecteurB, TYPE * HostVecteurC, int sizeA, int sizeB, int nbthread, int NbDiagonale, int * HostDiagBx, int * HostDiagAy, int NbWindows) ;
   void AnalyseDiagonales(TYPE * A, TYPE * B, int sizeA, int sizeB, int * DiagBx, int * DiagAy, int nbthread, int nth) ; 

// Les fonctions sur le device 
    __global__ void MergePathGPU_1024(TYPE *A, TYPE *B, TYPE *M, int sizeA, int sizeB) ; 
    __global__ void MergePathGPU_1024_shared(TYPE *A, TYPE *B, TYPE *M, int sizeA, int sizeB) ;
    __global__ void mergeGPU(TYPE * CudaVecteurA, TYPE * CudaVecteurB, TYPE * CudaVecteurC, int * CudaDiagAy, int * CudaDiagBx , int nbthread) ; 
    __global__ void AnalyseDiagonalesGPU(TYPE * CudaVecteurA, TYPE * CudaVecteurB, int SizeA , int SizeB, int * CudaDiagBx, int * CudaDiagAy, int nbthread) ;
    __global__ void initDiagGPU(int SizeA , int SizeB, int * CudaDiagBx, int * CudaDiagAy, int NbWindows) ;

// Fonctions Intermédiares qui fera un ou des appels au GPU
   void MergeWindowsGPU(TYPE * CudaVecteurA, TYPE * CudaVecteurB, TYPE * CudaVecteurC, int SizeA, int SizeB, 
                        int * CudaDiagAy , int * CudaDiagBx , int * HostDiagAy, int * HostDiagBx,  
                        TYPE * HostVecteurA , TYPE * HostVecteurB, TYPE * HostVecteurC , int nbthread, int NbDiagonale, 
                        int NbWindows) ;



