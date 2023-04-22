# This file contains methods to solve an instance (heuristically or with CPLEX)
using CPLEX
using JuMP
using Base

include("io.jl")
include("generation.jl")
include("connexe.jl")

TOL = 0.00000001

"""
Solve an instance with CPLEX
"""
function cplexSolve(t::Matrix{Int})

    # Taille de la grille
    n = size(t, 1)
    #nums = 1:n # ensemble des chiffres possibles

    # Créer le modèle
    m = Model(CPLEX.Optimizer)

    ### Variables
    #x[i,j] : variable binaire qui indique si la case (i,j) est masquée (1) ou non
    @variable(m, x[1:n,1:n], Bin)

    #on va créer des ensembles qui repertorient les places des chiffres dans la matrice

    ensembles = [[] for i in 1:9]

    for i in 1:n, j in 1:n
        chiffre = t[i,j]
        push!(ensembles[chiffre], (i,j))
    end

    println("\nEnsembles : ", ensembles, "\n")

    #OK ca fonctionne ! vérifié !

    #maintenant on veut vérifier dans chaque ensemble que les chiffres n'ont pas des positions avec ligne/colonne identique
    #on veut dans un premier temps, identifier toutes les positions qui posent problème (on pourrait avoir x=1)
    #puis, dire pour chaque ligne et chaque colonne combien de cases doivent etre grisées

    #on va faire une boucle qui pour chaque ensemble compte  le nombre de positions sur la même ligne/colonne

    m2 = zeros(Int8, (n, n))

    for i in 1:9
        for j in 1:length(ensembles[i])
            for k in j+1:length(ensembles[i])
                case1=ensembles[i][j]
                case2=ensembles[i][k]
                if case1[1]==case2[1] || case1[2]==case2[2]
                    m2[case1[1],case1[2]]=1
                    m2[case2[1],case2[2]]=1
                end
            end
        end
    end

    println("\nm2 : ",m2,"\n")
    #OK!!! vérifié !

    #a ce stade on a dans m2 les endroits qui sont à 0 qui seront définitivement à 0 dans m1
    #ce sont les locations qui ne posent pas de soucis ! donc qu'on est surs qu'on ne les grisera pas
    @constraint(m, [i in  1:n, j in 1:n], x[i,j] <= m2[i,j])


    for i in 1:n #pour chaque ligne
        for chiffre in 1:9 #pour chaque chiffre
            apparitions = []
            for j  in 1:length(ensembles[chiffre])
                if ensembles[chiffre][j][1] == i 
                    push!(apparitions,ensembles[chiffre][j])
                end
            end
            if length(apparitions) >= 2
                @constraint(m, sum(x[apparitions[j][1],apparitions[j][2]] for j in 1:length(apparitions)) >= length(apparitions)-1)        
            end
        end
    end

    for i in 1:n #pour chaque Colonne
        for chiffre in 1:9 #pour chaque chiffre
            apparitions = []
            for j  in 1:length(ensembles[chiffre])
                if ensembles[chiffre][j][2] == i 
                    push!(apparitions,ensembles[chiffre][j])
                end
            end
            if length(apparitions) >= 2
                @constraint(m, sum(x[apparitions[j][1],apparitions[j][2]] for j in 1:length(apparitions)) >= length(apparitions)-1)        
            end
        end
    end


    #Deux cellules collées ne peuvent être masquées = un cellule masquée ne peut avoir aucune voisine masquée
    @constraint(m, [i in 1:n-1, j in 1:n], x[i+1,j] + x[i,j] <= 1)
    @constraint(m, [i in 1:n, j in 1:n-1], x[i,j+1] + x[i,j] <= 1)

    # L'objectif est peu important
    @objective(m, Max, 1)

    # Start a chronometer
    start = time()

    # Solve the model
    optimize!(m)

    if JuMP.primal_status(m) != JuMP.FEASIBLE_POINT
        println("No solution.")
        return false, x, time() - start
    end
    display(JuMP.value.(x))

    while est_connexe(JuMP.value.(x))==false
        #je veux qu'il recommence mais différemment
        #on veut quil y ait au plus n-1 cases grises au meme endroit
        #donc la somme des x[i,j] doit être inferieure ou égale à n-1
        p=sum(JuMP.value.(x)[i,j] for i in 1:n, j in 1:n)
        println(p)
        coord=[] #va contenir les coordonées des cases précédemment grisées
        for i in 1:n, j in 1:n
            if JuMP.value.(x)[i,j]==1
                push!(coord, (i,j))
            end
        end
        println(coord)
        @constraint(m, sum(x[coord[i][1],coord[i][2]] for i in 1:length(coord)) <= p-1)
        optimize!(m)
        if JuMP.primal_status(m) != JuMP.FEASIBLE_POINT
            println("No solution.")
            return false, x, time() - start
        end
        display(JuMP.value.(x))
    end
    # Return:
    # 1 - the matrix with 1 where the case have to be colored
    # 2 - true if an optimum is found
    # 3 - the resolution time
    
    return JuMP.primal_status(m) == JuMP.FEASIBLE_POINT, x, time() - start
    
end

"""
Heuristically solve an instance
"""
function heuristicSolve(t::Matrix{Int64})

    # Heuristique : cases les plus contraintes a griser en premier

    # Taille de la grille
    n = size(t, 1)

    # True si la grille est résolue
    isSolved = false

    # True si la grille est resolvable
    gridStillFeasible = true

    # True si une case au moins est grisée | permet de voir a quel moment on ne peut plus griser de case
    OneIsGrisable = false

    #isGrisable = true si la case testée est grisable
    isGrisable = false

    # Pile : pile de cases grisées à dépiler si pas resolvable
    PileCells = []
    # Liste des cases deja passées en revue et n'offrant pas une bonne solution
    ListeNoire = []

    # Position de la cellule la plus contrainte 
    mcCell = (-1, -1)

    #on va créer des ensembles qui repertorient les places des chiffres dans la matrice
    # [ [(x1,y1),(x2,y2)], [...], ...]       (x1,y1) et (x2,y2) sont les deux positions de 1
    ensembles = [[] for i in 1:n]
    for i in 1:n, j in 1:n
        chiffre = t[i,j]
        push!(ensembles[chiffre], (i,j))
    end

    i = 0

    # Start a chronometer
    start = time()

    while !isSolved && gridStillFeasible
        i = i+1
        # Nombre de contrainte max trouvé
        max_contrainte = 0
        # Liste_Contrainte est la liste des cellules les plus contraintes non grisées, on choisi au hasard d'en griser une parmis celles-ci
        Liste_Contraintes = []

        for i in 1:n #pour chaque ligne
            for j in 1:n #Pour chaque colonne
                cell = (i,j)
                # Si [i,j] n'est pas deja grisée
                if !isIn((i,j), PileCells)
                    if (!isIn(cell, ListeNoire)) && (!isIn((i+1, j), PileCells)) && (!isIn((i-1, j), PileCells)) && (!isIn((i, j+1), PileCells)) && (!isIn((i, j-1), PileCells))
                        isGrisable = true
                    else 
                        isGrisable = false 
                    end  

                    nb_contrainte = 0
                    chiffre = t[i,j]
                    for k  in 1:length(ensembles[chiffre])
                        #si un meme chiffre est sur la meme ligne, colonne differente
                        #si la case n'est pas grisée
                        ex = ensembles[chiffre][k][1]
                        ey = ensembles[chiffre][k][2]
                        if !isIn((ex,ey), PileCells) && ey!= j && ex == i
                            nb_contrainte = nb_contrainte + 1
                        end
                    end

                    for k in 1:length(ensembles[chiffre])
                        #si un meme chiffre est sur la meme colonne, ligne differente
                        ex = ensembles[chiffre][k][1]
                        ey = ensembles[chiffre][k][2]
                        if !isIn((ex,ey), PileCells) && ex!= i && ey == j
                            nb_contrainte = nb_contrainte + 1
                        end
                    end
                    if nb_contrainte == max_contrainte 
                        if (!isIn(cell, ListeNoire)) && (!isIn((i+1, j), PileCells)) && (!isIn((i-1, j), PileCells)) && (!isIn((i, j+1), PileCells)) && (!isIn((i, j-1), PileCells))
                            isGrisable = true
                        else 
                            isGrisable = false 
                        end 
                        if isGrisable
                            push!(Liste_Contraintes, cell)
                            mcCell = rand(Liste_Contraintes)
                        end
                    end
                    if nb_contrainte > max_contrainte
                        max_contrainte = nb_contrainte
                        if (!isIn(cell, ListeNoire)) && (!isIn((i+1, j), PileCells)) && (!isIn((i-1, j), PileCells)) && (!isIn((i, j+1), PileCells)) && (!isIn((i, j-1), PileCells))
                            isGrisable = true
                        else 
                            isGrisable = false 
                        end 
                        # println(cell, " is grisable : ", isGrisable)
                        # println(max_contrainte)
                        # println(PileCells)
                        if isGrisable
                            mcCell = cell
                            push!(Liste_Contraintes, cell)
                            OneIsGrisable = true
                            # mcCell = rand(Liste_Contraintes)
                        end
                    end
                end #end cell if cell pas deja grisée

            end # end for j
        end # end for i

        if OneIsGrisable
            # Maintenant, mcCell contient les coordonnées de la cellule la plus contrainte qui n'est pas deja grisee (modulo des égalités)
            push!(PileCells, mcCell)
            if !isempty(ListeNoire)
                pop!(ListeNoire)
            end
            OneIsGrisable = false
        
        #else : aucune case n'est grisable | On verifie que le jeu est faisable (aucune contrainte)
        else
            #si max_contrainte > 0 : jeu non faisable avec PileCells, on dépile et on ajoute la case
            #dépilée en liste noire
            if max_contrainte > 0
                if !isempty(PileCells)
                    LastCell = pop!(PileCells)
                    push!(ListeNoire,LastCell)
                end
                
            end
        end
        tCopy = BuildSolution(t, PileCells)
        if max_contrainte == 0 && est_connexe(tCopy)
            isSolved = true
            println("----------------")
            println("Solution trouvée")
            DisplaySolution(t,PileCells)
        end

        if i>10
            gridStillFeasible = false
        end


    end #end while

    Sol = BuildSolution(t, PileCells)
    return isSolved, Sol, time() - start
end 

# NE MARCHE PAS ??
# function isGrisable(cell::Vector{Int64},PileCells::Vector{Any}, ListeNoire::Vector{Any})
#     #PileCells est la pile des cellules grisées, à dépiler si le jeu n'est pas résolvable
#     #coordonnées de la cellule dont on veut savoir si elle est grisable
#     x = cell[1]
#     y = cell[2]

#     #verifier q'aucun voisin direct n'est grisé
#     if (isIn(cell, PileCells)) || (isIn(cell, ListeNoire)) || (isIn((x+1, y), PileCells)) || (isIn((x-1, y), PileCells)) || (isIn((x, y+1), PileCells)) || (isIn((x, y-1), PileCells))
#         return false
#     else 
#         return true 
#     end   
# end

function BuildSolution(t::Matrix{Int64}, PileCells::Vector)
    n = size(t,1)
    tCopy = copy(t)

    for i in 1:n
        for j in 1:n
            if isIn((i,j), PileCells)
                tCopy[i,j]  = 1
            else
                tCopy[i,j] = 0
            end

        end
    end

    return tCopy	

end

function DisplaySolution(t::Matrix{Int64},PileCells::Vector{Any})
    n = size(t,1)
    println(" ", "-"^(3*n))
    for i in 1:n
        print("|")
        for j in 1:n 
            
            print(" ")
            if (i,j) in PileCells
                print("1")
            else
                print("-")
            end
            print(" ")
        
        end
        println("|")
    end
    println(" ", "-"^(3*n))
end

function isIn(cell::Vector{Int64},PileCells::Vector{Any})  
    for a_cell in PileCells
        if cell == a_cell
            return true
        end
    end
    return false
end

function isIn(cell::Tuple{Int64, Int64},PileCells::Vector{Any})  
    for a_cell in PileCells
        if cell == a_cell
            return true
        end
    end
    return false
end

"""
Solve all the instances contained in "../data" through CPLEX and heuristics

The results are written in "../res/cplex" and "../res/heuristic"

Remark: If an instance has previously been solved (either by cplex or the heuristic) it will not be solved again
"""
function solveDataSet()

    dataFolder = "../data/"
    resFolder = "../res/"

    # Array which contains the name of the resolution methods
    #resolutionMethod = ["cplex"]
    resolutionMethod = ["cplex","heuristique"]

    # Array which contains the result folder of each resolution method
    resolutionFolder = resFolder .* resolutionMethod

    # Create each result folder if it does not exist
    for folder in resolutionFolder
        if !isdir(folder)
            mkdir(folder)
        end
    end
            
    global isOptimal = false
    global solveTime = -1

    # For each instance
    # (for each file in folder dataFolder which ends by ".txt")
    for file in filter(x->occursin(".txt", x), readdir(dataFolder))  
        
        println("-- Resolution of ", file)
        t = readInputFile(dataFolder * file)

        # For each resolution method
        for methodId in 1:size(resolutionMethod, 1)
            
            outputFile = resolutionFolder[methodId] * "/" * file

            # If the instance has not already been solved by this method
            if !isfile(outputFile)
                
                fout = open(outputFile, "w")  

                resolutionTime = -1
                isOptimal = false
                
                # If the method is cplex
                if resolutionMethod[methodId] == "cplex"  
                    # Solve it and get the results
                    isOptimal, x, resolutionTime = cplexSolve(t)
                    
                    # If a solution is found, write it
                    if isOptimal
                        writeSolution(fout, x)                    
                    end

                # If the method is one of the heuristics
                else
                    
                    # Start a chronometer 
                    startingTime = time()

                    #While the grid is not solved and less than 10 seconds are elapsed
                    while !isOptimal && resolutionTime < 10
                        
                        # Solve it and get the results
                        isOptimal,x, resolutionTime = heuristicSolve(t)

                        # Stop the chronometer
                        resolutionTime = time() - startingTime
                        
                    end

                    # Write the solution (if any)
                    if isOptimal
                        writeSolution(fout, x)  
                    end 
                end

                println(fout, "solveTime = ", resolutionTime) 
                println(fout, "isOptimal = ", isOptimal)                
                close(fout)
            end


            # Display the results obtained with the method on the current instance
            include(outputFile)
            println(resolutionMethod[methodId], " optimal: ", isOptimal)
            println(resolutionMethod[methodId], " time: " * string(round(solveTime, sigdigits=2)) * "s\n")
        end         
    end 
end
