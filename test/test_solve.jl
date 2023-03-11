using DancingLinks

m::Matrix{Bool} = [0 0]

function solve_simple()
    global m = # 2 solutions
        [1 0 1;
        0 1 1; 
        0 1 0;
        1 0 0 ]
    exact_cover(m, do_check=true)
    solve(verbose=true, max_solutions=10, deterministic=true)
    println(m, " -> [[1, 3], [2, 4]] ?")
    println("Result = ", vector_sans_type(solutions))
    println()
end

function unsolvable()
    global m =
    [1 0 0 1;
    0 1 0 1;
    0 0 1 0]
    exact_cover(m, do_check=true)
    solve(verbose=true, max_solutions=10, deterministic=true)
    println(m, " -> [] ?")
    println("Result = ", vector_sans_type(solutions))
    println()
end

function latin_square()
    # taken from figure 2 at: https://garethrees.org/2007/06/10/zendoku-generation/#section-4.1
    global m =
    [
        1 0 0 0   1 0 0 0   1 0 0 0; # 1 at col 1, row 1
        1 0 0 0   0 0 1 0   0 0 1 0; # 2 at col 1, row 1
        0 1 0 0   0 1 0 0   1 0 0 0; # 1 at col 1, row 2
        0 1 0 0   0 0 0 1   0 0 1 0; # 2 at col 1, row 2
        
        0 0 1 0   1 0 0 0   0 1 0 0; # 1 at col 2, row 1
        0 0 1 0   0 0 1 0   0 0 0 1; # 2 at col 2, row 1
        0 0 0 1   0 1 0 0   0 1 0 0; # 1 at col 2, row 2
        0 0 0 1   0 0 0 1   0 0 0 1  # 2 at col 2, row 2
    ]
    exact_cover(m, do_check=true)
    solve(verbose=true, max_solutions=10, deterministic=true)
    println("Latin Square -> [[1, 4, 6, 7], [2, 3, 5, 8]] ?")
    println("Result = ", vector_sans_type(solutions))
    println()
end

solve_simple()
unsolvable()
latin_square()