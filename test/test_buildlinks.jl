using DancingLinks
import DancingLinks: * 

const DL = DancingLinks

m::Matrix{Bool} = 
    [1 0 1;
    0 1 1; 
    1 1 0]
    
# m = [ 0 1 0; 
#     1 0 1]

# m = [ 1 1 1; # full row error 
#       1 0 0;
#       1 1 1;
#       0 0 1 ]

# m = [ 1 0 1 1; # full column error 
#       1 1 0 1;
#       1 0 1 1]

# m = [ 1 1 1; # empty row error 
#       0 0 0]

# m = [ 1 1 0; # empty column error
#       1 0 0]

exact_cover(m, do_check=true)

root = DL.build_links()

function ncols()
    count = 0
    head = root.right
    while head !== root
        count += 1
        head = head.right
    end
    return count
end

function nrows()
    st = Set{Int64}()
    head = root.right
    while head !== root
        head.head !== head && error("head.head !== head") 
        node = head.below
        node === head && error("Column $(head.id) is empty")
        while node !== head
            node.head !== head && error("node.head !== head") 
            push!(st, node.row_ix)
            node = node.below
        end
        head = head.right
    end
    return length(st)
end

# println("DL.ncols=$(DL.ncols), ncols=$(ncols()), DL.nrows=$(DL.nrows), nrows=$(nrows())")
# solve(verbose=true)
root = DL.root
println("DL.ncols=$(DL.ncols), ncols=$(ncols()), DL.nrows=$(DL.nrows), nrows=$(nrows())")
;