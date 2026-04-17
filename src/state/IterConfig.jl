
function iter_config!(
    config::Component,
    handler::Function,
    name_stack=String[]
)
    name_stack = push!(name_stack, config.id)
    current_id = join(name_stack, ".")
    handler(config, current_id)

    pop!(name_stack)
    return Dict(config.id => nothing)
end


function iter_config!(
    config::SystemConfig,
    handler::Function,
    name_stack=String[]
)
    name_stack = push!(name_stack, config.id)
    current_id = join(name_stack, ".")

    namespace = Dict{String,Any}()
    for sys in config.systems
        subspace = iter_config!(sys, handler, name_stack)
        namespace = merge(namespace, subspace)
    end

    handler(config, current_id)
    pop!(name_stack)
    return Dict(config.id => namespace)
end
