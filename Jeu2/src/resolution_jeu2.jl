using JuMP
using CPLEX

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

    #OK ca fonctionne ! 
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
        grisables = 0
        for chiffre in 1:9 #pour chaque chiffre
            apparitions = 0
            for j  in 1:length(ensembles[chiffre])
                if ensembles[chiffre][j][1] == i 
                    apparitions += 1
                end
            end
            if apparitions >=  1
                grisables += apparitions-1
            end
        end
        @constraint(m , sum(x[i,j] for j in 1:n)>=grisables)
    end

    for i in 1:n #pour chaque colonne
        grisables = 0
        for chiffre in 1:9 #pour chaque chiffre
            apparitions = 0
            for j  in 1:length(ensembles[chiffre])
                if ensembles[chiffre][j][2] == i 
                    apparitions += 1
                end
            end
            if apparitions >=  1
                grisables += apparitions-1
            end
        end
        @constraint(m , sum(x[j,i] for j in 1:n)>=grisables)
        println(grisables)

    end



    #Deux cellules collées ne peuvent être masquées = un cellule masquée ne peut avoir aucune voisine masquée
    @constraint(m, [i in 1:n-1, j in 1:n], x[i+1,j] + x[i,j] <= 1)
    @constraint(m, [i in 1:n, j in 1:n-1], x[i,j+1] + x[i,j] <= 1)


    # L'objectif est peu important
    @objective(m, Max, 1)

    start = time()
    optimize!(m)


    ## Si une solution est trouvée, l'afficher ainsi que les valeurs des cases à choisir, et leur nombre
    if primal_status(m) == MOI.FEASIBLE_POINT
        objectiveValue = round(Int, JuMP.objective_value(m)) 
        println("Nombre de coup pour résoudre le jeu : ", round(Int, JuMP.objective_value(m))) #on print le nombre de coup à jouer
        println("Choix finaux : ") #on print la nouvelle grille avec 1 dans la case à colorier 
        @show(JuMP.value.(x))
    else                             
        println("On ne peut pas résoudre le jeu")
    end  
    displaySolution(x)
    return primal_status(m) == MOI.FEASIBLE_POINT, x, time() - start

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
                    isOptimal, x, resolutionTime = cplexSolve(t)
                    
                    # If a solution is found, write it
                    if isOptimal
                        writeSolution(fout, x)
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