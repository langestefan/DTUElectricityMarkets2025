function market_clearing(
    hours::UnitRange{Int64};
    generation_wind::DataFrame = DataFrame(),
    generation_fixed::DataFrame = DataFrame(),
    demands::DataFrame = DataFrame(),
    network::DataFrame = DataFrame(),
    demand_prices::DataFrame = DataFrame(),
)
    # create problem sets
    T = hours                                           # time periods                              
    B = Set(union(network.from_bus, network.to_bus))    # all buses
    GF = Set(Int64.(generation_fixed.bus))              # fixed generation buses
    GW = Set(parse.(Int, names(generation_wind)))       # wind generation buses
    G = union(GF, GW)                                   # all generation buses
    D = Set(parse.(Int, names(demands)))                # demand buses  
    L = Set(zip(network.from_bus, network.to_bus))      # all lines

    # construct cost parameter for generation
    π_G = Dict(generation_fixed.bus .=> generation_fixed.production_cost_D_MWh)
    π_G = merge(π_G, Dict(parse.(Int, names(generation_wind)) .=> 0.0))

    # construct cost parameter for demand
    π_D = Dict(demand_prices.bus .=> demand_prices.price)

    # # construct generation upper limit
    # GW_max = generation_wind
    # GF_max = Dict(generation_fixed.bus .=> generation_fixed.capacity_MW)

    # create model
    model = Model(HiGHS.Optimizer)

    # variables
    @variables(model, begin
        P_G[G, T], (base_name = "Generation")
        P_D[D, T], (base_name = "Demand")
    end)

    @expressions(
        model,
        begin

            # per-generator cost 
            G_cost[g in G, t in T], π_G[g] * P_G[g, t]

            # per-demand cost
            D_cost[d in D, t in T], π_D[d] * P_D[d, t]

            # fixed generation upper limit
            GF_max[g in GF], generation_fixed[generation_fixed.bus.==g, :capacity_MW][1]

            # wind generation upper limit
            GW_max[g in GW, t in T], generation_wind[t+1, Symbol(g)]

            # demand upper limit
            D_max[d in D, t in T], demands[t+1, Symbol(d)]
        end
    )

    # constraints
    @constraints(
        model,
        begin
            # power balance
            P_balance[t in T], sum(P_G[g, t] for g in G) - sum(P_D[d, t] for d in D) == 0

            # fixed generation limits
            P_GF_max[g in GF, t in T], 0 <= P_G[g, t] <= GF_max[g]

            # wind generation limits
            P_GW_max[g in GW, t in T], 0 <= P_G[g, t] <= GW_max[g, t]

            # demand limits
            P_D_max[d in D, t in T], 0 <= P_D[d, t] <= D_max[d, t]
        end
    )

    # objective function
    @expression(
        model,
        SW[t in T],
        sum(D_cost[d, t] for d in D) - sum(G_cost[g, t] for g in G)
    )
    @objective(model, Max, sum(SW[t] for t in T))


    # optimize the model and return it
    optimize!(model)
    @assert is_solved_and_feasible(model)
    return model
end