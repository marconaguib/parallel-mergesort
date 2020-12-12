#include <stdio.h>
#include <stdlib.h>
#include "MyInc.h"
 
#include "main.h" 
 
int main(int argc, char ** argv)
{
   int nbtest = 0 ;
   int SizeA = 800 ;  // Vertical ~ Y
   int SizeB = 200 ;  // Horizontal ~ x
   int nbthread = 512 ;
   int maxTest  =  2 * (int) RemplirEnd ;  
   cudaError_t errCuda ;
   
// Info sur la carte
   getInfoCuda() ;

// Hello
    enum EnumMerge AlgoMerge = TriMergePath_1024_shared ; // On choisi le nom de l'algo qu'on veut essayer 
// Rappel :
  //TriMergeSimpleHOST : en séquentiel : algo A 
  //TriMergePathHOST : en séquentiel algo B
  //TriMergePathGPU_1024 : question 1 mémoire globale
  //TriMergePath_1024_shared  : question 1 mémoire shared 
  //TriWindowsGPU_Para : question 2 
  // La question 3 et 5 sont dans des fichiers sépares 


// On fait quelques calculs, même si non utilisés par l'algo cible
   int NbDiagonale  = (SizeA + SizeB) / nbthread ;
   int NbWindows    = NbDiagonale ; 
   // Nombre de trie à faire, c'est le nombre de diagonale +1, sauf si la dernière diagonale est sur 
   // le coin en bas à droite
   NbWindows       += (((SizeA + SizeB) % nbthread) == 0)?0:1 ;  

// Allocation dynamique Sur le host
   allocVecteur(SizeA, SizeB, nbthread)   ; 
 
// Vérifie que la carte et les dimensions sont compatibles avec la carte 
   switch(AlgoMerge)
   {
        case TriMergePathGPU_1024:
             if ((SizeA + SizeB) > 1024)
             { printf("TriMergePathGPU_1024 SizeA + SizeB %d > 1024\n",SizeA + SizeB) ; 
               exit(0) ; 
             }
             break ;
        case TriMergePath_1024_shared:
             if ((SizeA + SizeB) > 1024)
             { printf("TriMergePath_1024_shared SizeA + SizeB %d > 1024\n",SizeA + SizeB) ; 
               exit(0) ; 
             }
             break ;
   }

// Pour chaque génération disponible
    for (int e = 0 ; e < (int)RemplirEnd ; e++)
    {    nbtest ++ ;
         printf("CardA %d - CardB %d - NBThread %d - Algo de remplissage %s - %s\n",
                 SizeA, SizeB, nbthread, MSGRemplir[e],MSGMerge[AlgoMerge]) ;
 
         initVecteur(HostVecteurA, SizeA, HostVecteurB, SizeB, HostVecteurC, (enum EnumTypeRemplissage) e, 1925) ;
 
         if (cudaSuccess != (errCuda = cudaMemcpy(CudaVecteurA, HostVecteurA, SizeA * sizeof(TYPE), cudaMemcpyHostToDevice)))
         { printf("PB copie HostA -> cudaA - %d - %s\n",errCuda,cudaGetErrorName(errCuda)) ; cleanup() ; exit(2) ; }
 
         if (cudaSuccess != (errCuda = cudaMemcpy(CudaVecteurB, HostVecteurB, SizeB * sizeof(TYPE), cudaMemcpyHostToDevice)))
         { printf("PB copie HostB -> cudaB - %d - %s\n",errCuda,cudaGetErrorName(errCuda)) ; cleanup() ; exit(2) ; }
 
      // Le resultat est le meme quelque soit l'ordre dans lequel on fait le tri.
         MergeSimpleHOST(HostVecteurA, HostVecteurB, HostVecteurD, SizeA, SizeB) ;
         switch(AlgoMerge)
         {
             case TriMergeSimpleHOST:
                  MergeSimpleHOST(HostVecteurA, HostVecteurB, HostVecteurC, SizeA, SizeB) ; // 1 thread pour 1 grille
             break ;
             case TriMergePathHOST:
                  MergePathHOST(HostVecteurA, HostVecteurB, HostVecteurC, SizeA, SizeB);
             break ;
             case TriMergePathGPU_1024:
                  MergePathGPU_1024<<<1,SizeA+SizeB>>>(CudaVecteurA, CudaVecteurB, CudaVecteurC, SizeA, SizeB) ;
                  if (cudaSuccess != (errCuda = cudaMemcpy(HostVecteurC, CudaVecteurC,
                                           (SizeA + SizeB) * sizeof(TYPE), cudaMemcpyDeviceToHost)))
                  { printf("Error copie cuda C -> host C  - %d - %s\n",errCuda,cudaGetErrorName(errCuda)) ; 
                    cleanup() ; exit(2) ; 
                  }
	     break ; 
             case TriMergePath_1024_shared: 
                  MergePathGPU_1024_shared<<<1,SizeA+SizeB, (SizeA+SizeB) * sizeof (TYPE)>>>(CudaVecteurA, CudaVecteurB, CudaVecteurC, SizeA, SizeB) ;
                  if (cudaSuccess != (errCuda = cudaMemcpy(HostVecteurC, CudaVecteurC,
                                           (SizeA + SizeB) * sizeof(TYPE), cudaMemcpyDeviceToHost)))
                  { printf("Error copie cuda C -> host C  - %d - %s\n",errCuda,cudaGetErrorName(errCuda)) ; 
                    cleanup() ; exit(2) ; 
                  }
             break ;
             case TriWindowsGPU_Para:
                  MergeWindowsGPU(CudaVecteurA, CudaVecteurB, CudaVecteurC, SizeA, SizeB , 
                                  CudaDiagAy  , CudaDiagBx , HostDiagAy, HostDiagBx ,  
                                  HostVecteurA , HostVecteurB, HostVecteurC, nbthread, NbDiagonale, NbWindows) ;
                              
                  if (cudaSuccess != (errCuda = cudaMemcpy(HostVecteurC, CudaVecteurC,
                                           (SizeA + SizeB) * sizeof(TYPE), cudaMemcpyDeviceToHost)))
                  { printf("Error copie cuda C -> host C  - %d - %s\n",errCuda,cudaGetErrorName(errCuda)) ; 
                    cleanup() ; exit(2) ; 
                  }
             break ;
         }

         printf("Verif A versus B %d / %d \n",nbtest, maxTest) ;
         if (compare(HostVecteurD, HostVecteurC, SizeA + SizeB) != 0)
         {   printf("Errorr in %d / %d \n",nbtest, maxTest) ;
             printf("Vect En erreur\n") ;
             //  Affiche((char *)"VectC", HostVecteurC, SizeA+SizeB) ;
             exit(0) ;
         }

         nbtest ++ ; // Pour trier 2 fois A et B, pour vérier que ça marche dans les 2 sens 
         printf("Card First %d - Card Second %d - NBThread %d - Algo de remplissage %s - %s\n",
                 SizeB, SizeA, nbthread, MSGRemplir[e],MSGMerge[AlgoMerge]) ;
         switch(AlgoMerge)
         {
             case TriMergeSimpleHOST:
                  MergeSimpleHOST(HostVecteurB, HostVecteurA, HostVecteurC, SizeB, SizeA) ; // 1 thread pour 1 grille
             break ;
             case TriMergePathHOST:
                  MergePathHOST(HostVecteurB, HostVecteurA, HostVecteurC, SizeB, SizeA);
             break ;
             case TriMergePathGPU_1024:
                  MergePathGPU_1024<<<1,SizeA+SizeB>>>(CudaVecteurB, CudaVecteurA, CudaVecteurC, SizeB, SizeA); 
                  if (cudaSuccess != (errCuda = cudaMemcpy(HostVecteurC, CudaVecteurC,
                                              (SizeA + SizeB) * sizeof(TYPE), cudaMemcpyDeviceToHost)))
                  {  printf("PB copie 2 cuda C -> host C  - %d - %s\n",errCuda,cudaGetErrorName(errCuda)) ; 
                     cleanup() ; exit(2) ; 
                  }
             break ;
             case TriMergePath_1024_shared: 
                  MergePathGPU_1024_shared<<<1,SizeA+SizeB, (SizeA+SizeB) * sizeof (TYPE)>>>(CudaVecteurB, CudaVecteurA, CudaVecteurC, SizeB, SizeA) ;
                  if (cudaSuccess != (errCuda = cudaMemcpy(HostVecteurC, CudaVecteurC,
                                           (SizeA + SizeB) * sizeof(TYPE), cudaMemcpyDeviceToHost)))
                  { printf("Error copie cuda C -> host C  - %d - %s\n",errCuda,cudaGetErrorName(errCuda)) ; 
                    cleanup() ; exit(2) ; 
                  }
             break ;
             case TriWindowsGPU_Para:
                  MergeWindowsGPU(CudaVecteurA, CudaVecteurB, CudaVecteurC, SizeA, SizeB , 
                                  CudaDiagAy  , CudaDiagBx , HostDiagAy, HostDiagBx ,  
                                  HostVecteurA , HostVecteurB, HostVecteurC, nbthread, NbDiagonale, NbWindows) ;
                              
                  if (cudaSuccess != (errCuda = cudaMemcpy(HostVecteurC, CudaVecteurC,
                                           (SizeA + SizeB) * sizeof(TYPE), cudaMemcpyDeviceToHost)))
                  {  printf("Error copie cuda C -> host C  - %d - %s\n",errCuda,cudaGetErrorName(errCuda)) ; 
                     cleanup() ; exit(2) ; 
                  }
             break ;
        }
 
        printf("Verif B versus A %d / %d \n",nbtest, maxTest) ;
        if (compare(HostVecteurD, HostVecteurC, SizeA + SizeB) != 0)
        {   printf("PHL Erreur in %d - \n",nbtest) ; exit(0) ; }
         
    }
    printf("NB test %d  / %d Pour %s\n",nbtest,  maxTest, MSGMerge[AlgoMerge]) ;

    cleanup() ; printf("Bye Bye\n") ;
 
    return 0 ;
 
}
 
