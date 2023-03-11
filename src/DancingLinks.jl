"""
## DancingLinks
# Exported:
+ exact_cover(matrix::Matrix{Bool}; do_check::Bool) # `matrix` is the 'Exact Cover' incidence matrix
Initializes global vars `incidence_matrix`, `nrows`, `ncols`.
This must be executed before function `solve` is called.
    
+ solve(; verbose=false, max_solutions=1, deterministic=false) ::Bool
+ 
+ solve(starting_state::Vector{Int64}; verbose=false, max_solutions=1, deterministic=false) ::Bool

        starting_state    `List of rows by indices into the provided constraint matrix (global var `incidence_matrix`)
                           that should be removed - they are "given" as part of the solution.`
        [verbose]         `Sets global `VERBOSE` flag; print timings, etc.`
        [max_solutions]   `Sets global `SOLUTIONSMAX`; number of solutions to find before returning.`
        [deterministic]   `Sets global `DO_DETERMINISTICALLY; false=select rows at random.`
+         
+ solutions
The resulting list of solutions found (each solution is a Vector{Int64} of row indices into the global
`incidence_matrix` and is ordered).
+ 
+ convert_nanoseconds(nanosecs::Real; ncols::Integer=0, units::Union{Nothing, Symbol}=nothing, omitunits::Bool=false)::String
+
+ vector_sans_type(vec::AbstractVector)::String
# Example:
    `# build your incidence matrix first, a Matrix{Bool}`
    exact_cover(matrix)
    solve() # get a random solution (without 'givens')

Refer to the package "Sudoku2" for a thorough testing of this "DancingLinks" implementation.
"""
module DancingLinks

using Random

export exact_cover, solve, solutions, convert_nanoseconds, vector_sans_type

include("helpers.jl")

DO_DETERMINISTICALLY::Bool = false # true=don't select a random row during the search operation
SOLUTIONS_MAX::Int64 = 1 # max number of solutions found upon which to return from searching
solutions::Vector{Vector{Int64}} = [] # a list of lists of all rows (by index into the `incidence_matrix`) found for a solution
VERBOSE::Bool = false # PO timings, etc

mutable struct LinkedNode
    above::Union{Nothing, LinkedNode}
    below::Union{Nothing, LinkedNode}
    left::Union{Nothing, LinkedNode}
    right::Union{Nothing, LinkedNode}
    head::Union{Nothing, LinkedNode}
    id::String # == "[{row_ix}, {col_ix}]" for non-root and non-head nodes
    row_ix::Int64 # for tracking the solution
    removed::Bool # safety check for duplicate givens
end
LinkedNode() = LinkedNode(nothing, nothing, nothing, nothing, nothing, "", -1, false)

root::LinkedNode = LinkedNode()
right_most::Vector{Union{Nothing, LinkedNode}} = [] # rightmost link for each row
solution_state::Vector{Int64} = [] # state of matrix - which rows (by index) have been eliminated
incidence_matrix::Union{Nothing, Matrix{Bool}} = nothing  # to be set to the incidence matrix to be solved for Exact Cover
nrows::Int64 = 0 # row count in incidence_matrix (NB equals Julia n columns)
ncols::Int64 = 0  # column count in incidence_matrix (NB equals Julia n rows)


"""
        exact_cover(matrix::Matrix{Bool}; do_check::Bool)
            matrix      `The incidence matrix`
            do_check    `Whether to check for invalid rows or columns.
                        (This will slow the execution time.)`

Initialize globals `incidence_matrix`, `nrows`, `ncols`.
"""
function exact_cover(matrix::Matrix{Bool}; do_check::Bool)
    global incidence_matrix = matrix
    r, c = size(matrix)
    global nrows = r; global ncols = c
    do_check || return

    # check for empty|full rows|columns:
    str(list) = "$(Tuple(list)) in the passed arg `matrix`"
    listfull::Vector{Int64} = []
    listempty::Vector{Int64} = []

    for i in 1:nrows
        c = count(matrix[i, 1:end])
        c == ncols && push!(listfull, i)
        c == 0 && push!(listempty, i)
    end
    !isempty(listempty) && error("Row(s) $(str(listempty)) are empty.")
    !isempty(listfull) && error("Row(s) $(str(listfull)) are full.")

    for i in 1:ncols
        c = count(matrix[1:end, i])
        c == nrows && push!(listfull, i)
        c == 0 && push!(listempty, i)
    end
    !isempty(listempty) && error("Column(s) $(str(listempty)) are empty.")
    !isempty(listfull) && error("Column(s) $(str(listfull)) are full.")
end

"""
        solve(; verbose=false, max_solutions=1, deterministic=false) :: Bool
            [verbose]         `Sets global `VERBOSE` flag; print timings, etc.`
            [max_solutions]   `Sets global `SOLUTIONSMAX`; number of solutions to find before returning.`
            [deterministic]   `Sets global `DO_DETERMINISTICALLY; false=select rows at random.`

Solve the constraint matrix, global `incidence_matrix`.Solve with no givens.

Returns whether a solution was found or not.

This is useful when the matrix provided in global `incidence_matrix` is the actual matrix (ie. there are no `givens`).
"""
function solve(; verbose=false, max_solutions=1, deterministic=false) :: Bool
    return solve(Int64[], verbose=verbose, max_solutions=max_solutions, deterministic=deterministic)
end

"""
        solve(starting_state::Vector{Int64}; verbose=false, max_solutions=1, deterministic=false) :: Bool
            starting_state      `List of rows by indices into the provided constraint matrix (global `incidence_matrix`)
                                 that should be removed - they are "given" as part of the solution.`
            [verbose]           `Sets global `VERBOSE` flag; print timings.`
            [max_solutions]     `Sets global `SOLUTIONSMAX`; number of solutions to find before returning.`
            [deterministic]     `Sets global `DO_DETERMINISTICALLY; false=select rows at random.`

Solve the constraint matrix, global `incidence_matrix`.

Returns whether a solution was found or not.

You must have first set the global `incidence_matrix` with function `exact_cover()`.
"""
function solve(starting_state::Vector{Int64}; verbose=false, max_solutions=1, deterministic=false) :: Bool
    incidence_matrix === nothing && error("global `incidence_matrix` has not been set. Set this first with function `exact_cover(m::Matrix{Bool})`")
    global VERBOSE = verbose; global SOLUTIONS_MAX = max_solutions; global DO_DETERMINISTICALLY = deterministic
    empty!(solutions)
    tm = time_ns()
    build_links()

    if !isempty(starting_state)
        global solution_state = starting_state
        # remove (cover) the columns and their rows which have givens in the row
        # corresponding to the starting state of the matrix.
        for v in starting_state
            n::LinkedNode = right_most[v]
            r::LinkedNode = n
            while true
                remove_column(r.head)
                r = r.right
                r == n && break
            end
        end
    else 
        empty!(solution_state)
    end

    tm = time_ns() - tm
    str = convert_nanoseconds(tm, units=:μs)
    VERBOSE && println("LinkedNode table generation took: $str")
    
    global solutions = Vector{Vector{Int64}}()
    tm = time_ns()
    search(0) # main recursion method
    tm = time_ns() - tm
    str = convert_nanoseconds(tm, units=:μs)
    VERBOSE && println("$(length(solutions)) solution(s) found. Took $str\ndeterministic=$DO_DETERMINISTICALLY, solutions_max=$SOLUTIONS_MAX")
        
    return length(solutions) > 0
end

"""
        build_links() :: LinkedNode

Build the doubly-linked toroidal lists.

Given the matrix, this builds the linked list that models it.  It constructs all the column headers, then a node for each
element in the column that is true. It links each element to its North, South, East, and West neighbors.

There are only N + H + 1 nodes in the mesh, where N is the number of 1's in the matrix, and H is the number of
discrete columns in which those 1's appear. It is not necessary to create a LinkedNode for empty places in the
matrix.  This is especially important for sparse matrices, such as those modelling Sudoku or other problems.
"""
function build_links() :: LinkedNode
    global root = LinkedNode()
    root.id = "root"
    left_head::LinkedNode = root
    northern_neighbor::LinkedNode = LinkedNode()
    node::LinkedNode = LinkedNode()
    head::LinkedNode = LinkedNode()
    global right_most = Vector{Union{LinkedNode, Nothing}}(undef, nrows); fill!(right_most, nothing)
    left_most::Vector{Union{LinkedNode, Nothing}} = Vector{Union{LinkedNode, Nothing}}(undef, nrows); fill!(left_most, nothing)

    for j in 1:ncols # columns. vertically circular
        head = LinkedNode()
        head.id = ":$j:" # diagnostic purposes
        head.below = head
        head.above = head
        head.head = head
        head.left = left_head

        left_head.right = head
        northern_neighbor = head

        for i in 1:nrows # rows. horizontally circular
            if incidence_matrix[i, j] 
                node = LinkedNode()
                node.id = "[$i, $j], = [row, col]"
                node.head = head
                node.row_ix = i
                node.above = northern_neighbor
                northern_neighbor.below = node

                left_most[i] === nothing && (left_most[i] = node)
                if right_most[i] !== nothing
                    right_most[i].right = node
                    node.left = right_most[i]
                end
                # for the next cycle
                right_most[i] = node
                northern_neighbor = node
            end
        end

        head.above = northern_neighbor
        head.above === head && error("Column $(head.id) in global `incidence_matrix` set by function `exact_cover()` is empty.") # a column can not be empty
        northern_neighbor.below = head
        left_head = head
    end

    # close the loop on each row
    for i in 1:nrows
        left_most[i] !== nothing && right_most[i] !== nothing || error("Row $i in global `incidence_matrix` set by function `exact_cover()` is empty.") # a row can not be empty
        left_most[i].left = right_most[i]
        right_most[i].right = left_most[i]
    end    
    # close the loop on the column heads
    head.right = root # head will be right-most
    root.left = head

    return root
end

"""
Actually perform the search for the exact cover.

It does its work recursively, choosing a column heuristically and covering it, then
randomly choosing a row to "try" when searching for the next candidate.

The solution state is maintained in global `solution_state`, a Vector. When the matrix is solved, `solution_state` lists 
the rows that provide the exact cover (the solution).
"""
function search(depth::Int64)
    length(solutions) >= SOLUTIONS_MAX && return    
    if root.left == root.right == root
        push!(solutions, sort!(copy(solution_state)))
        return
    end

    # choose column [non]deterministically (heuristically)
    candidate::Union{Nothing, LinkedNode} = choose_column() # -> the head of the column
    candidate === nothing && return

    remove_column(candidate)

    rows::Vector{LinkedNode} = active_rows_in_column(candidate) 
    DO_DETERMINISTICALLY || shuffle!(rows)

    for node in rows
        # Add the node's row index to solution_state, and remove(cover) the node's column along with it's rows
        push!(solution_state, node.row_ix)
        nright::LinkedNode = node.right
        while nright != node
            remove_column(nright.head)
            nright = nright.right
        end
    
        search(depth+1) # recurse
        length(solutions) >= SOLUTIONS_MAX && return

        # put the pointers back, in reverse order
        nleft::LinkedNode = node.left
        while nleft != node
            reinsert_column(nleft.head)
            nleft = nleft.left
        end

        pop!(solution_state)
    end

    reinsert_column(candidate)
end

"""
        choose_column() :: Union{Nothing, LinkedNode} -> column.head

Choose and return a column's head deterministically to eliminate from the matrix.

The heuristic of using a column with the fewest 1's tends to make the search run much more quickly.
"""
function choose_column() :: Union{Nothing, LinkedNode}
    lowest_count::Int64 = length(incidence_matrix)
    column::LinkedNode = LinkedNode()

    head::LinkedNode = root.right
    chosen_column::LinkedNode = head
    while head != root
        # Cannot rely on the ColumnCount field - some nodes may have
        # been removed from this column already.
        cc::Int64 = get_cell_count_for_column(head)
        cc == 0 && return nothing # invalid matrix
        cc == 1 && return head
        if cc < lowest_count
            lowest_count = cc
            column = head
        end
        head = head.right
    end
    return chosen_column
end

get_cell_count_for_column(head::LinkedNode) :: Int64 = length(active_rows_in_column(head))

function active_rows_in_column(head) :: Vector{LinkedNode}
    rows::Vector{LinkedNode} = []
    node = head.below
    while node != head
        push!(rows, node)
        node = node.below
    end
    return rows
end

"""
        remove_column(head::LinkedNode)

Remove(cover) the head from the links-matrix along with all of it's rows.

Guard against removing the same column twice.

If we try to remove the same column twice, the pointers get corrupted. Must not do this!

Normally, there's no need to check to see if a column has already been removed. If the algorithm is correctly
implemented, it will never try to remove a column twice. 

BUT ! Supposing an incorrect Sudoku puzzle, which is not solvable (for example, there are two 9's in a single row), then
it can result in the same column being removed twice, for the "givens".

So this safety flag protects against bad input.
"""
function remove_column(head::LinkedNode)
    head.removed && return

    # remove(cover) the column's head
    head.right.left = head.left
    head.left.right = head.right
    # remove(cover) all rows in the matrix from this column
    b::LinkedNode = head.below
    while b != head
        r::LinkedNode = b.right
        while r != b
            r.above.below = r.below
            r.below.above = r.above
            r = r.right
        end
        b = b.below
    end
end

"""
        reinsert_column(head::LinkedNode)
"""
function reinsert_column(head::LinkedNode)
    # reinsert rows in reverse order from removal
    a = head.above
    while a != head
        l = a.left
        while l != a
            l.above.below = l
            l.below.above = l
            l = l.left
        end
        a = a.above
    end
	# reinsert the head
    head.right.left = head
    head.left.right = head
    head.removed = false
#=
	// reinsert rows in reverse order from removal
	for (LinkedNode r1 = colNode.Above; r1 != colNode; r1 = r1.Above)
	{
		for (LinkedNode n = r1.Left; n != r1; n = n.Left)
		{
			n.Above.Below = n;
			n.Below.Above = n;
		}
	}
	// reinsert the head, colNode
	colNode.Right.Left = colNode;
	colNode.Left.Right = colNode;
	colNode.Removed = false;
=#
end

end # module DancingLinks
