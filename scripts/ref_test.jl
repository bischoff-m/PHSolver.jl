# Demonstrate using Refs in a matrix and evaluating them

a = Ref(2)
b = Ref(3)

# create a 2x2 matrix holding Ref{Int} values
M = [a b;
    b a]

# Square
M = M * M
println("matrix of refs:")
println(M)

# "evaluate" the matrix by dereferencing each Ref
N = map(x -> x[], M)
println("\nevaluated matrix (normal Ints):")
println(N)

# change one of the referenced values and show the effect
M[1, 1][] = 10
println("\nafter modifying M[1,1] to 10:")
println("matrix of refs:")
println(M)
println("evaluated:")
println(map(x -> x[], M))
