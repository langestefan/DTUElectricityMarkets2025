
function add_network(
    model::Model;
    b = 1 / 0.002,  # base susceptance in p.u.
    network::DataFrame = DataFrame(),
)
    # sets 
    B = model[:sets][:B]  # all buses
    T = model[:sets][:T]  # time periods
    L = model[:sets][:L]  # all lines
    D = model[:sets][:D]  # all demand buses
    G = model[:sets][:G]  # all generation buses

    # variables
    P_D = model[:P_D]  # demand power
    P_G = model[:P_G]  # generation power

    # construct line limits Dict
    P_line_max = Dict(
        (network.from_bus[i], network.to_bus[i]) => network.capacity_pu[i] for
        i = 1:nrow(network)
    )
    model[:P_line_max] = P_line_max

    @variable(model, θ[B, T])

    # fix voltage angles at the REF bus to 0
    ref_bus = model[:sets][:ref_bus]
    fix.(θ[ref_bus, :], 0.0; force = true)

    # line power flow
    @expression(model, P_line[l in L, t in T], b * (θ[l[1], t] - θ[l[2], t]))
    @constraint(
        model,
        P_line_limits[l in L, t in T],
        -P_line_max[l] <= P_line[l, t] <= P_line_max[l]
    )

    # power balance at each bus
    @constraint(
        model,
        P_balance[b in B, t in T],

        # total demand located at bus b
        sum(P_D[d, t] for d in D if d[1] == b) +

        # total power leaving bus b
        sum(P_line[(b, j), t] for j in B if (b, j) in L) -

        # total generation located at bus b
        sum(P_G[g, t] for g in G if g[1] == b) -

        # total power into bus b
        sum(P_line[(j, b), t] for j in B if (j, b) in L) == 0
    )
end


function add_storage(
    model::Model;
    P_ch_max::Float64 = 200.0 / S_base,   # maximum charging power in MW
    P_dis_max::Float64 = 200.0 / S_base,  # maximum discharging power in MW
    E_cap::Float64 = 1000.0 / S_base,      # energy capacity in MWh
    E0::Float64 = 100.0 / S_base,           # initial energy in MWh
    η_ch::Float64 = 0.80,        # charging efficiency
    η_dis::Float64 = 0.92,       # discharging efficiency
)
    # ensure η_ch ̸= η_dis
    if η_ch == η_dis
        error("Charging and discharging efficiencies must be different")
    end
    T = model[:sets][:T]

    # total energy stored in the storage system at each time step
    @variable(model, 0.0 <= E[[0; T]] <= E_cap, base_name = "Energy stored")
    fix(E[0], E0; force = true)

    # charging and discharging power at each time step
    @variables(model, begin
        P_ch[T]     # Charging power
        P_dis[T]    # Discharging power
    end)

    @constraints(
        model,
        begin
            # charging power limits
            P_ch_up[t in T], 0 <= P_ch[t] <= P_ch_max

            # discharging power limits
            P_dis_up[t in T], 0 <= P_dis[t] <= P_dis_max

            # energy balance equation
            Storage_E_balance[t in T], E[t] == E[t-1] + η_ch * P_ch[t] - P_dis[t] / η_dis
        end
    )

    return P_ch, P_dis
end

function market_clearing(
    hours::UnitRange{Int64};
    generation_wind::DataFrame = DataFrame(),
    generation_fixed::DataFrame = DataFrame(),
    demands::DataFrame = DataFrame(),
    network::DataFrame = DataFrame(),
    demand_prices::DataFrame = DataFrame(),
    use_storage::Bool = false,
    use_network::Bool = false,
)
    # use_storage and use_network can't be both true at the same time
    if use_storage && use_network
        error("simultaneously using use_storage and use_network is not supported")
    end

    # create model
    model = Model(HiGHS.Optimizer)
    set_silent(model)

    # create problem sets
    T = hours                                           # time periods                              
    B = Set(union(network.from_bus, network.to_bus))    # all buses
    GF = Set(Int64.(generation_fixed.bus))              # fixed generation buses
    GW = Set(parse.(Int, names(generation_wind)))       # wind generation buses
    G = union(GF, GW)                                   # all generation buses
    D = Set(parse.(Int, names(demands)))                # demand buses  
    L = Set(zip(network.from_bus, network.to_bus))      # all lines

    # add sets to model
    model[:sets] = Dict(
        :T => T,
        :B => B,
        :GF => GF,
        :GW => GW,
        :G => G,
        :D => D,
        :L => L,
        :ref_bus => 1,
    )

    # construct cost parameter for generation
    π_G = Dict(generation_fixed.bus .=> generation_fixed.production_cost_D_pu)
    π_G = merge(π_G, Dict(parse.(Int, names(generation_wind)) .=> 0.0))

    # construct cost parameter for demand
    π_D = Dict(demand_prices.bus .=> demand_prices.price_pu)

    @variables(model, begin
        P_GW[GW, T]     # Wind generation
        P_GF[GF, T]     # Fixed generation
        P_D[D, T]       # Demand
    end)

    @expression(
        model,
        P_G[g in G, t in T],
        (g in GF ? P_GF[g, t] : 0) + (g in GW ? P_GW[g, t] : 0)
    )

    @expressions(
        model,
        begin
            # per-generator cost 
            G_cost[g in G, t in T], π_G[g] * P_G[g, t]

            # per-demand cost
            D_cost[d in D, t in T], π_D[d] * P_D[d, t]

            # fixed generation upper limit
            GF_max[g in GF], sum(generation_fixed[generation_fixed.bus.==g, :capacity_pu])

            # wind generation upper limit
            GW_max[g in GW, t in T], generation_wind[t, Symbol(g)]

            # demand upper limit
            D_max[d in D, t in T], demands[t, Symbol(d)]
        end
    )

    # constraints
    @constraints(model, begin
        # fixed generation limits
        P_GF_max[g in GF, t in T], 0 <= P_GF[g, t] <= GF_max[g]

        # wind generation limits
        P_GW_max[g in GW, t in T], 0 <= P_GW[g, t] <= GW_max[g, t]

        # demand limits
        P_D_max[d in D, t in T], 0 <= P_D[d, t] <= D_max[d, t]
    end)

    # if storage is enabled, add storage constraints
    P_ch = zeros(T)
    P_dis = zeros(T)
    if use_storage
        P_ch, P_dis = add_storage(model)
    end

    # if network is enabled, add network constraints
    if use_network
        add_network(model; network = network)
    end

    # energy balance constraint
    @constraint(
        model,
        E_balance[t in T],
        sum(P_G[g, t] for g in G) - sum(P_D[d, t] for d in D) - P_ch[t] + P_dis[t] == 0
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

    @expressions(model, begin
        # clearing price at each time step
        CP[t in T], dual(E_balance[t])

        # utility of each demand, defined as:
        # Utility = Power Consumption × (Bid Price − Market-Clearing Price)
        Utility[d in D, t in T], P_D[d, t] * (π_D[d] - CP[t])

        # profit of each generator, defined as:
        # Profit = Power Generation × (Market-Clearing Price − Production Cost)
        Profit[g in G, t in T], P_G[g, t] * (CP[t] - π_G[g])

        # total generation cost 
        Cost[g in G, t in T], π_G[g] * P_G[g, t]

        # total generation power
        P_G_total[t in T], sum(P_G[g, t] for g in G)

        # total demand power
        P_D_total[t in T], sum(P_D[d, t] for d in D)
    end)

    system = DataFrame(
        CP = [value(CP[t]) for t in T],
        SW = [value(SW[t]) for t in T],
        P_G_total = [value(P_G_total[t]) for t in T],
        P_D_total = [value(P_D_total[t]) for t in T],
    )

    P_D = DataFrame([Symbol("$(d)") => [value(P_D[d, t]) for t in T] for d in D]...)
    P_G = DataFrame([Symbol("$(g)") => [value(P_G[g, t]) for t in T] for g in G]...)
    utility = DataFrame([Symbol("$(d)") => [value(Utility[d, t]) for t in T] for d in D]...)
    profit = DataFrame([Symbol("$(g)") => [value(Profit[g, t]) for t in T] for g in G]...)
    cost = DataFrame([Symbol("$(g)") => [value(G_cost[g, t]) for t in T] for g in G]...)

    results = Dict(
        :system => system,
        :P_D => P_D,
        :utility => utility,
        :P_G => P_G,
        :profit => profit,
        :cost => cost,
    )

    # storage total profit 
    if use_storage
        @expression(model, S_profit, sum(P_dis[t] * CP[t] - P_ch[t] * CP[t] for t in T))
        @info "Total profit from storage: $(value(S_profit))"
    end

    return model, results
end