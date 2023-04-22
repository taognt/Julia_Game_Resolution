Pour résoudre une grille test : 
Commandes à taper dans Julia : 

using Pkg
using CPLEX

aller dans le bon path :cd("path")

dans data :

include("instanceTest.txt")

dans src  :

include("resolution.jl")
include("io.jl")
cplexSolve(readInputFile("../data/instanceTest.txt"))
displaySolution(cplexSolve(readInputFile("../data/instanceTest.txt"))[2])

La matrice qui s'affiche représente par des 1 les cases à griser

Pour résoudre une instance aléatoire : 


