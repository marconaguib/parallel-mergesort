#include <stdio.h>
#include <stdlib.h>
#include "MyInc.h" 

void initVecteur(TYPE * HostVecteurA, int SizeA, TYPE * HostVecteurB, int SizeB, TYPE * HostVecteurC, enum EnumTypeRemplissage typeRemplissage, int initGene) 
{
   TYPE * ptC = HostVecteurC ; 

   for (int i = 0 ; i < SizeA + SizeB ; i ++) { *ptC ++ = -1 ; } // Inutile, sauf pour le debug 

   switch (typeRemplissage)
   { case RemplirPairImpair:
       for (int j = 0 ; j < SizeA; j ++) { HostVecteurA[j] = (TYPE) (2 * j) ; }
       for (int j = 0 ; j < SizeB; j ++) { HostVecteurB[j] = (TYPE) (2 * j + 1) ; }
       break ;
     case RemplirBinaire:
       for (int j = 0 ; j < SizeA; j ++) { HostVecteurA[j] = (TYPE) (1) ; }
       for (int j = 0 ; j < SizeB; j ++) { HostVecteurB[j] = (TYPE) (2) ; }
       break ;
     case RemplirRandom:
     {
       int a =  10 ;
       int b = 150 ;
       // srand (time (NULL));
       if (initGene !=0) { srand (initGene) ; } 
       HostVecteurA[0] = rand() % a ;
       HostVecteurB[0] = rand() % b ;
       for (int j = 1 ; j < SizeA ; j ++)
          { HostVecteurA[j] = (TYPE) (HostVecteurA[j-1] + (rand() % a)) ; }
       for (int j = 1 ; j < SizeB ; j ++)
          { HostVecteurB[j] = (TYPE) (HostVecteurB[j-1] + (rand() % b)) ; }
       break ;
     }
     case RemplirRandom2:
     {
       int a = 150 ;
       int b = 150 ;
       // srand (time (NULL));
       if (initGene !=0) { srand (initGene) ; } 

       HostVecteurA[0] = rand() % a ;
       HostVecteurB[0] = rand() % b ;
       for (int j = 1 ; j < SizeA ; j ++)
          { HostVecteurA[j] = (TYPE) (HostVecteurA[j-1] + (rand() % a)) ; }
       for (int j = 1 ; j < SizeB ; j ++)
          { HostVecteurB[j] = (TYPE) (HostVecteurB[j-1] + (rand() % b)) ; }
       break ;
     }
     case RemplirPetit: // A (1 2 3 4 ) < B (5 6 7 8 9 10)
     { TYPE v = 0 ; 
       for (int j = 0 ; j < SizeA; j ++) { HostVecteurA[j] = (TYPE) v ; v++ ; } 
       for (int j = 0 ; j < SizeB; j ++) { HostVecteurB[j] = (TYPE) v ; v++ ; }
       break ;
     }
     default:
        printf("Error code enum non traite\n") ; exit(10) ; 
  } 
} 

// Pour le debug, On peut afficher le tableau
void Affiche(char * tabMsg, TYPE * ptBuffer, int NB)
{
   TYPE * pt = ptBuffer ;
   int k ;

   for (k = 0 ; k < NB  ; k++ , pt ++)
   {   printf(" - %s[%03d] = %6" FMT, tabMsg, k , *pt) ;
       if ((k % 5) == 4) { printf("\n") ; }
   }
   printf("\n") ;
}

// Pour vérifier que le tableau est trié
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

    printf("Check %s pour %d est OK \n", msg, Nb) ;
    return 0 ;
}

int compare(TYPE * tab1 , TYPE * tab2 , int Nb)
{   int nberr = 0 ; 

    for (int i = 0 ; i < Nb ; i ++ , tab1 ++ , tab2 ++)
    {  if (*tab1 != *tab2) 
       { if (nberr ++ < 16) 
         {  printf("Error Ref[%3d] = %" FMT " != tabC[%3d] = %" FMT "\n",i,*tab1,i,*tab2) ; } 
       } 
   }
   if (nberr == 0)
   { printf("Comparaison OK pour %d elements\n",Nb) ; 
     return 0 ; 
   }
   else
   { printf("Erreur, il y a %d / %d différences !\n",nberr,Nb) ; 
     return nberr ;
   }    

}

void AfficheDiag(int * ADiag,int * BDiag, int nb) 
{
   for (int i = 0 ; i <= nb ; i ++)
   {  printf("Diag[%4d] = (Bx %6d , Ay = %6d)\n",i,BDiag[i], ADiag[i]) ; } 
} 
