using CPLEX
using JuMP


function bfs(grid, i, j)
    # Initialiser le tableau visited et l'ensemble Q
    visited = falses(size(grid)) #au départ on marque toutes les cases de la grille comme non visitées
    Q = [(i, j)] #Q contient les cases à visiter
    
    # Parcourir le graphe en utilisant l'algorithme BFS
    while !isempty(Q) #on parcours Q tant qu'il n'est pas vide 
        i, j = pop!(Q) #récupère les coordonnées de la prochaine case à visiter dans la grille
        visited[i, j] = true #marque toutes les cases visitées dans la grille pour éviter de les revisiter plus tard dans l'algorithme.
        
        # Parcourir les cases adjacentes non visitées
        for (dx, dy) in ((-1, 0), (1, 0), (0, -1), (0, 1))
            ni, nj = i + dx, j + dy
            if ni >= 1 && ni <= size(grid, 1) && nj >= 1 && nj <= size(grid, 2) &&
                grid[ni, nj] == 0 && !visited[ni, nj]
                push!(Q, (ni, nj)) #on ajoute à la liste des cases à visiter et dont on devra etudier les voisines
            end
        end
    end
    # Retourner le tableau visited
    return visited
end



function est_connexe(t::Matrix{Float64}) #on doit prendre en entrée la matrice 
    #Taille de la grille
    n = size(t,1)
    
    # Vérifier la connexité
    start_node = findfirst(t .== 0) # prendre le premier nœud blanc trouvé
    #visited = falses(n*n)
    visited=bfs(t, start_node[1], start_node[2])

    #println(convert(Matrix{Int}, visited))
    return all(visited[t .== 0]) # renvoie true si toutes les cases visibles sont visitées
end

#ce programme permet de renvoyer un ensemble de 0 connexe. Si le tableau de booléens renvoyé ne comprends pas des 1 sur tous les emplacements où il y a des 
# cases visibles, alors c'est que l'ensemble formé n'est pas connexe

#la contrainte va être:  il faut que partout ou je veux mettre un 0, la fonction renvoie 'est_connexe' renvoie un 1 à cet endroit 