#include "MyInc.h"

// Pour la question 2 
void MergeWindowsGPU(TYPE * CudaVecteurA, TYPE * CudaVecteurB, TYPE * CudaVecteurC, int SizeA, int SizeB, int * CudaDiagAy , int * CudaDiagBx , int * HostDiagAy, int * HostDiagBx ,  
                     TYPE * HostVecteurA , TYPE * HostVecteurB, TYPE * HostVecteurC , int nbthread, int NbDiagonale, int NbWindows)
{

   cudaError_t errCuda ;

   if (1024 < NbDiagonale) 
   {  printf("Mode TriWindowsGPU_para code réduit pour NBDiag < 1024\n") ; return ; }  

/* Le caclul des diagonales peut se faire soit en local soit en CGPU. 
   Quelque soit le lieu de calcul, il sera néceassaire de recopuer les vecteur A et B sur la carte GPU. 
   Si la cul est local, il est nécessaire d'en faire la copie vers la carte GPU. 
   Pour un petit nombre de diagonale, le celcul peut être intéressant, s'il est plus court que l'initialiasitation
   des cacluls sur la carte. 
*/

   if (0) // Pour la construction par étape
   {
       HostDiagBx[0] = HostDiagAy[0] = 0 ; // Top en haut à gauche
       HostDiagBx[NbWindows] = SizeB ; HostDiagAy[NbWindows] = SizeA ; // Coin n bas à droite

    // Calcul de la position basse des fenêtres
       for (int i = 0 ; i < NbDiagonale ; i ++) // Simul le // 
       {
           AnalyseDiagonales(HostVecteurA, HostVecteurB, SizeA , SizeB, HostDiagBx, HostDiagAy, nbthread, i)   ;
       } 

    // On recopie notre vecteur diagonale vers le device
       if (cudaSuccess != (errCuda = cudaMemcpy(CudaDiagBx, HostDiagBx, (NbWindows+1) * sizeof(int), cudaMemcpyHostToDevice)))
       { printf("PB copie DiagBx -> cuda - %d - %s\n",errCuda,cudaGetErrorName(errCuda)) ; cleanup() ; exit(2) ; }
 
       if (cudaSuccess != (errCuda = cudaMemcpy(CudaDiagAy, HostDiagAy, (NbWindows+1) * sizeof(int), cudaMemcpyHostToDevice)))
       { printf("PB copie DiagAy -> cuda - %d - %s\n",errCuda,cudaGetErrorName(errCuda)) ; cleanup() ; exit(2) ; }
 
       // AfficheDiag(HostDiagAy,HostDiagBx,NbWindows) ; 

   }
   else
   {
      // Il faut initialisaer le vecteur des diagonales - Soit on fait une copie full, soit on fait une oppie en debut et en fin de veteur, soit on fait un appel à 
      // une fonction sur le GPU 
         initDiagGPU<<<1,1>>>(SizeA , SizeB, CudaDiagBx, CudaDiagAy, NbWindows)   ;
      // Pour l'instant on ne sait faire que nbDiagonale < 1024 (pas de gestion de bloc)A
         AnalyseDiagonalesGPU<<<1,NbDiagonale>>>(CudaVecteurA, CudaVecteurB, SizeA , SizeB, CudaDiagBx, CudaDiagAy, nbthread) ; 

      // Dans le cas où nous aurions besoin des coordonnées de la diagonale en local, il faudrait refaire la copie 
       if (cudaSuccess != (errCuda = cudaMemcpy(HostDiagBx, CudaDiagBx, (NbWindows+1) * sizeof(int), cudaMemcpyDeviceToHost)))
       { printf("PB copie cuda -> DiagBx - %d - %s\n",errCuda,cudaGetErrorName(errCuda)) ; cleanup() ; exit(2) ; }
 
       if (cudaSuccess != (errCuda = cudaMemcpy(HostDiagAy, CudaDiagAy, (NbWindows+1) * sizeof(int), cudaMemcpyDeviceToHost)))
       { printf("PB copie cuda -> DiagAy - %d - %s\n",errCuda,cudaGetErrorName(errCuda)) ; cleanup() ; exit(2) ; }

//       AfficheDiag(HostDiagAy,HostDiagBx,NbWindows) ; 
 
   }  

   if ((SizeA + SizeB) < 1024) 
   {   mergeGPU<<<1,SizeA+SizeB>>> (CudaVecteurA, CudaVecteurB, CudaVecteurC, CudaDiagAy, CudaDiagBx, nbthread) ; } 
   else // Il faut decouper en bloc 
   { // Traille d'un bloc et nb bloc  
        int nbBlock  = (SizeA+SizeB) / 1024 ; 
        nbBlock += ((SizeA+SizeB) % 1024)?1:0 ; 
        mergeGPU<<<nbBlock,1024>>> (CudaVecteurA, CudaVecteurB, CudaVecteurC, CudaDiagAy, CudaDiagBx, nbthread) ; 
   } 

} 
