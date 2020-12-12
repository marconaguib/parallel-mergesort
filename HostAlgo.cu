#include <stdio.h>
#include <stdlib.h>
#include "MyInc.h" 

// Algorithme A
void MergeSimpleHOST(TYPE *A, TYPE *B, TYPE *M, int sizeA, int sizeB)
{
    int j = 0;
    int i = 0;

    // On utilise comme pointeurs les arguments de la fonctions
    while (i + j < sizeA + sizeB )
    {
        if (i >= sizeA ) // On a épuisé tout les elts de A, donc on complete avec B
        {  *M = *B; // on utilise les pointeurs pour éviter de faire l opération i+j et se déplacer  = gain de performance
            M = M + 1 ; // Je déplace les pointeurs
            B = B + 1 ;
            j = j + 1 ;
        }
        else if ((j >= sizeB) || (*A < *B))
        {   *M = *A ; M = M + 1 ; A = A + 1 ; i = i + 1 ; }
        else
        {   *M = *B ; M = M + 1 ; B = B + 1 ; j = j + 1 ; }
    }
} // End of MergeSimpleHOST

// Algorithme B
void MergePathHOST(TYPE *A, TYPE *B, TYPE *M, int sizeA, int sizeB)
{
    Point K;
    Point P;
    Point Q;

    int i ; int offset ; 
    for (i = 0 ; i < sizeA + sizeB ; i ++)
    {
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
                       break ; // Pour simuler passage au thread suivant
                  }
                  else
                  {  K.x = Q.x + 1 ; K.y = Q.y - 1 ; }
             }
             else
             { P.x = Q.x -1 ; P.y = Q.y + 1 ; }
    	}
    }
} // End of MergePathHOST

// Travail  préparation, afin d'avoir un code parallélsable sur GPU
void AnalyseDiagonales(TYPE * A, TYPE * B, int sizeA, int sizeB, int * DiagBx, int * DiagAy, int nbthread, int nth) 
{
    Point K, P, Q ; 
    int   px , py ; 
    TYPE  v;  // Génère un warning sur les ppti-gpu* 
 
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
                       {  v = A[Q.y] ; 
                          py ++ ; 
                       }
                       else
                       {  v = B[Q.x] ; 
                          px ++ ; 
                       }
                       // printf("Analyse Diagonale Point de Sortie ref %d - M %" FMT " Q (A Q.y %d) (B Q.x %d) rv.x %d rv.y %d\n",i,v,Q.y,Q.x,rv->x,rv->y) ; 
                       DiagBx[nth+1] = px ; DiagAy[nth+1] = py ; 
                       break ; // Pour simuler passage au thread suivant
                  }
                  else
                  {  K.x = Q.x + 1 ; K.y = Q.y - 1 ;  }
             }
             else
             { P.x = Q.x -1 ; P.y = Q.y + 1 ; }
    	}
} // End of AnalyseDiagonales

