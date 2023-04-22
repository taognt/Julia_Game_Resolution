# This file contains methods to generate a data set of instances (i.e., sudoku grids)
include("io.jl")

"""
Generate an n*n grid with a given density

Argument
- n: size of the grid
- density: percentage in [0, 1] of initial values in the grid
"""
function generateInstance(n::Int64, density::Float64)

    # True if the current grid has no conflicts
    isGridValid = false

    t = []

    # While a valid grid is not obtained 
    while !isGridValid

        isGridValid = true
        
        # Array that will contain the generated grid
        t = zeros(Int64, n, n)
        i = 1

        # While the grid is valid and the required number of cells is not filled
        while isGridValid && i < (n*n*density)

            # Randomly select a cell and a value
            l = ceil.(Int, n * rand())
            c = ceil.(Int, n * rand())
            v = ceil.(Int, rand())

            # True if a value has already been assigned to the cell (l, c)
            isDark = t[l, c] == 0

            # Number of value that we already tried to assign to cell (l, c)
            attemptCount = 0
            
            # True if a value has already been assigned to the cell (l, c)
            isCellFree = t[l, c] == 0

            # Number of cells considered in the grid
            testedCells = 1

            # While is it not possible to assign the value to the cell
            # (we assign a value if the cell is free and the value is valid)
            # and while all the cells have not been considered
            while !(isCellFree) && testedCells < n*n

                # If the cell has already been assigned a number or if all the values have been tested for this cell
                if !isCellFree || attemptCount == n
                    
                    # Go to the next cell                    
                    if c < n
                        c += 1
                    else
                        if l < n
                            l += 1
                            c = 1
                        else
                            l = 1
                            c = 1
                        end
                    end

                    testedCells += 1
                    isDark = t[l, c] == 0
                    attemptCount = 0
                    
                    # If the cell has not already been assigned a value and all the value have not all been tested
                else
                    attemptCount += 1
                    v = rem(v, n) + 1
                end 
            end

            if testedCells == n*n
                isGridValid = false
            else 
                t[l, c] = v
            end

            i += 1
        end
    end

    return t
    
end  

"""
Generate all the instances

Remark: a grid is generated only if the corresponding output file does not already exist
"""
function generateDataSet()

    # For each grid size considered
    for size in [3, 4,5]

        # For each grid density considered
        for density in 0.2:0.3:0.5

            # Generate 10 instances
            for instance in 1:4

                fileName = "../data/instance_t" * string(size) * "_d" * string(density) * "_" * string(instance) * ".txt"

                if !isfile(fileName)
                    println("-- Generating file " * fileName)
                    saveInstance(generateInstance(size, density), fileName)
                end 
            end
        end
    end
    
end




