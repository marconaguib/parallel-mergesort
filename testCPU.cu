%%cu
#include <stdio.h>
#include <stdlib.h>

// Pour pouvoir experimenter les performances avec les différents types
// FMT  pour print comme on change de type
#define TYPE long
#define FMT  "ld"
#define sizeA 10
#define sizeB 20

// Algorithme A
void MergeSimpleHOST(TYPE *A, TYPE *B, TYPE *M, int cardA, int cardB)
{
    int j = 0;
    int i = 0;

    // On utilise comme pointeurs les arguments de la fonctions
    while (i + j < cardA + cardB )
    {
        if (i >= cardA ) // On a épuisé A, donc on complete avec B
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

// Algorithme B

// On parle de la notion de point dans l algo B
typedef struct
{
   int x ;
   int y ;
}  Point ;

void MergePathHOST(TYPE *A, TYPE *B, TYPE *M, int cardA, int cardB)
{
    Point K;
    Point P;
    Point Q;
    int offset ;

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
}

// Fonctions utiles : permet d afficher le tableau

void Affiche(char * tabMsg, TYPE * ptBuffer, int NB)
{
   TYPE * pt = ptBuffer ;
   for ( int k = 0 ; k < NB  ; k++ , pt ++)
   {   printf(" - %s[%03d] = %6" FMT, tabMsg, k , *pt) ;
       if ((k % 5) == 0) { printf("\n") ; }
   }
   printf("\n") ;
}

// Fonctions utiles : Pour vérifier que le tableau est trié
int check(char * msg, int Nb, TYPE * pto)
{
    TYPE * pt1 = pto ;
    TYPE * pt2 = pto + 1 ;

    for (int i = 0 ; i < Nb-1 ; i ++)
    {
        if (*pt1 > *pt2)
        { printf("Check %s pour %d - Erreur en position %d %"FMT" > %"FMT" \n", msg, Nb, i, *pt1, *pt2) ;

          return i ;
        }
        pt1 ++ ; pt2 ++ ;
    }

    printf("Check %s pour %d est OK \n", msg, Nb) ;
    return 0 ;
}

int main(int argc, char ** argv)
{

   TYPE * vecteurA ;
   TYPE * vecteurB ;
   TYPE * vecteurC ;
   int cas = 1;

// allocation dynamique
   if ((vecteurA = (TYPE *) malloc(sizeA * sizeof(TYPE))) == NULL)
   { printf("PB allocation VecteurA\n") ; exit (1) ; }

   if ((vecteurB = (TYPE *) malloc(sizeB * sizeof(TYPE))) == NULL)
   { printf("PB allocation VecteurB\n") ; exit (1) ; }

   if ((vecteurC = (TYPE *) malloc((sizeA + sizeB) * sizeof(TYPE))) == NULL)
   { printf("PB allocation VecteurC\n") ; exit (1) ; }

// Initialisation des deux vecteurs de base
   if (cas == 1)
   {
       printf("A pair %d B impair %d\n",sizeA,sizeB) ;
       for (int j = 0 ; j < sizeA; j ++) { vecteurA[j] = 2 * j ; }
       for (int j = 0 ; j < sizeB; j ++) { vecteurB[j] = 2 * j + 1 ; }
   }

// vérifier qu'on génére bien les tableaux
   check("Vecteur A ", sizeA, vecteurA) ;
   check("Vecteur B ", sizeB, vecteurB) ;
   Affiche("VectA", vecteurA, sizeA) ;

   //MergeSimpleHOST(vecteurA, vecteurB, vecteurC, sizeA,sizeB) ;
   MergePathHOST(vecteurA, vecteurB, vecteurC, sizeA,sizeB);
   Affiche("VectC", vecteurC, sizeA + sizeB) ;
   check("Vecteur M ",sizeA+sizeB, vecteurC) ;

   return 0 ;
}
