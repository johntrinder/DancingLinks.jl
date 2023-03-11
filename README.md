## DancingLinks
## Exported:
+ exact_cover(matrix::Matrix{Bool}; do_check::Bool) 

        'matrix' is the 'Exact Cover' incidence matrix
        Initializes global vars `incidence_matrix`, `nrows`, `ncols`.
        This must be executed before function `solve` is called.
+ solve(; verbose=false, max_solutions=1, deterministic=false)::Bool

         Solve the matrix with no starting state.
+ solve(starting_state::Vector{Int64}; verbose=false, max_solutions=1, deterministic=false)::Bool

        starting_state    List of rows' by indices into the provided constraint matrix 
                            (global var `incidence_matrix`)
                           that should be removed - they are "given" as part of the solution.`
        [verbose]         Sets global `VERBOSE` flag; print timings, etc.
        [max_solutions]   Sets global `SOLUTIONSMAX`; number of solutions to find before returning.
        [deterministic]   Sets global `DO_DETERMINISTICALLY; false=select rows at random.
        
+ solutions

        The resulting list of solutions found (each solution is a Vector{Int64} of row indices into the global
        `incidence_matrix` and is ordered).
+ convert_nanoseconds(nanosecs::Real; ncols::Integer=0, units::Union{Nothing, Symbol}=nothing, omitunits::Bool=false)::String

        Helper
+ vector_sans_type(vec::AbstractVector)::String

        Helper
## Example:
    # build your incidence matrix first, a Matrix{Bool}
    exact_cover(matrix)
    solve() # get a random solution (without 'givens')
            # the result will be in exported global `solutions`

Refer to the package "Sudoku2" for a thorough testing of this "DancingLinks" implementation.
