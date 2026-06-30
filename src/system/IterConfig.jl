
function iter_config!(
    config::Union{Component,SystemConfig};
    on_enter::Union{Function,Nothing}=nothing,
    on_exit::Union{Function,Nothing}=nothing,
    name_stack=String[]
)
    name_stack = push!(name_stack, config.id)
    isnothing(on_enter) || on_enter(config, name_stack[2:end])

    namespace = Dict{String,Any}()
    if isa(config, SystemConfig)
        for sys in config.systems
            subspace = iter_config!(sys; on_enter, on_exit, name_stack)
            namespace = merge(namespace, subspace)
        end
    end

    isnothing(on_exit) || on_exit(config, name_stack[2:end])
    pop!(name_stack)
    return Dict(config.id => isa(config, SystemConfig) ? namespace : nothing)
end
