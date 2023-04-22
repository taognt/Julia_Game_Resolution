using JuMP
using CPLEX
# using GLPK

include("io.jl")

function cplexSolve(t::Matrix{Int})

    # Taille de la grille
    n = size(t, 1)

    # Créer le modèle
    m = Model(CPLEX.Optimizer)

    ### Variables
    @variable(m, y[1:n, 1:n]>=0, Int) #Nos choix
    @variable(m, z[1:n, 1:n], Int) #Des entiers

    # L'objectif est de minimiser le nombre de choix à jouer donc 
    @objective(m, Min, sum(y[i,j] for i in 1:n for j in 1:n))

    ### Contraintes
    #on veut que toutes les cases soient blanches en choisissant blanc = 1
    #Pour une case = 1, on veut la changer un nombre pair de fois
    #Pour une case = 0, on veut la changer un nombre impair de fois

    #Domaine du milieu (sans les bords) :
    @constraint(m, [i in 2:n-1, j in 2:n-1], y[i,j]+y[i-1,j]+y[i+1,j]+y[i,j-1]+y[i,j+1] == 2*z[i,j]+t[i,j]+1)

    #Bord haut :
    @constraint(m, [j in 2:n-1], y[1, j-1]+y[1,j+1]+y[1,j]+y[2,j] == 2*z[1,j]+t[1,j]+1)

    #Bord gauche :
    @constraint(m, [i in 2:n-1], y[i+1,1]+y[i-1,1]+y[i,1]+y[i,2] == 2*z[i,1]+t[i,1]+1)

    #Bord bas : 
    @constraint(m, [j in 2:n-1], y[n,j]+y[n,j-1]+y[n,j+1]+y[n-1,j] == 2*z[n,j]+t[n,j]+1)

    #bord droit :
    @constraint(m, [i in 2:n-1], y[i,n]+y[i-1,n]+y[i+1,n]+y[i,n-1] == 2*z[i,n]+t[i,n]+1)

    #Coin haut-droit
    @constraint(m, y[1,n]+y[1,n-1]+y[2,n] == 2*z[1,n]+t[1,n]+1)

    #Coin haut-gauche :
    @constraint(m, y[1,1]+y[2,1]+y[1,2] == 2*z[1,1]+t[1,1]+1)

    #Coin bas-gauche : 
    @constraint(m, y[n,1]+y[n,2]+y[n-1,1] == 2*z[n,1]+t[n,1]+1)

    #Coin bas-doit :
    @constraint(m, y[n,n]+y[n-1,n]+y[n,n-1] == 2*z[n,n]+t[n,n]+1)

    ### Résoudre le problème
    start = time()
    optimize!(m)

    ### Si une solution est trouvée, l'afficher ainsi que les valeurs des cases à choisir, et leur nombre
    if primal_status(m) == MOI.FEASIBLE_POINT
        objectiveValue = round(Int, JuMP.objective_value(m)) 
        println("Nombre de coup pour résoudre le jeu flip : ", round(Int, JuMP.objective_value(m))) #on print le nombre de coup à jouer
        println("Les cases à choisir sont : " ) #on veut afficher les coordonnées (i,j) des cases dont le y[i,j] vaut 1
        
        # TODO: Récupérer la solution
        println("Choix finaux : ")
        println("erbesr")
        @show(JuMP.value.(y))

    else                             
        println("On ne peut pas résoudre le jeu")
    end   
    println(typeof(y)) 

    return primal_status(m) == MOI.FEASIBLE_POINT, y, time() - start

end
    


function solveDataSet()

    dataFolder = "../data/"
    resFolder = "../res/"

    # Array which contains the name of the resolution methods
    resolutionMethod = ["cplex"]
    #resolutionMethod = ["cplex", "heuristique"]

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
                    isOptimal, y, resolutionTime = cplexSolve(t)
                    
                    # If a solution is found, write it
                    if isOptimal
                        writeSolution(fout, y)
                    end

                # If the method is one of the heuristics
                else
                    
                    isSolved = false

                    # Start a chronometer 
                    startingTime = time()
                    
                    # While the grid is not solved and less than 100 seconds are elapsed
                    while !isOptimal && resolutionTime < 100
                        
                        # TODO 
                        println("In file resolution.jl, in method solveDataSet(), TODO: fix heuristicSolve() arguments and returned values")
                        
                        # Solve it and get the results
                        isOptimal, resolutionTime = heuristicSolve()

                        # Stop the chronometer
                        resolutionTime = time() - startingTime
                        
                    end

                    # Write the solution (if any)
                    if isOptimal

                        # TODO
                        println("In file resolution.jl, in method solveDataSet(), TODO: write the heuristic solution in fout")
                        
                    end 
                end

                println(fout, "solveTime = ", resolutionTime) 
                println(fout, "isOptimal = ", isOptimal)
                
                # TODO
                println("In file resolution.jl, in method solveDataSet(), TODO: write the solution in fout") 
                close(fout)
            end


            # Display the results obtained with the method on the current instance
            include(outputFile)
            println(resolutionMethod[methodId], " optimal: ", isOptimal)
            println(resolutionMethod[methodId], " time: " * string(round(solveTime, sigdigits=2)) * "s\n")
        end         
    end 
end