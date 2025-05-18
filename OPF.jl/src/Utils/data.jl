

"""
    prepare_demands(hours::UnitRange{Int64})

Prepare demand data from the given path for the specified hours.

Arguments:
- hours::UnitRange{Int64}: The range of hours to prepare data for.

Returns:
- DataFrame: A DataFrame containing the prepared demand data.

"""
function prepare_demands(hours::UnitRange{Int64}; std::Float64 = 0.005)
    rng = MersenneTwister(123)

    # demands per id
    demands = CSV.read("data/in/demands.csv", DataFrame)
    pattern = CSV.read("data/in/pattern.csv", DataFrame)
    pattern = pattern[in.(pattern.hour, Ref(hours)), :]

    # context 
    n_hours = length(hours)
    n_demands = nrow(demands)
    bus_names = Symbol.(demands.bus)

    # we create a pseudo-random scale with a typical duck curve demand pattern
    scale = pattern.demand .* (sqrt(std) .* randn(rng, (n_hours, n_demands)) .+ 1)

    # create DataFrame with columns for each bus
    demand = DataFrame([zeros(n_hours) for _ = 1:n_demands], bus_names)
    for (i, row) in enumerate(eachrow(demands))
        demand[!, Symbol(row.bus)] = scale[:, i] .* row.consumption_MW
    end

    return demand
end

prepare_demands(hours::Int64; std::Float64 = 0.005) = prepare_demands(0:hours-1; std = std)

function prepare_generation_fixed()
    generation = CSV.read("data/in/generators.csv", DataFrame)
end

function prepare_generation_wind(
    hours::UnitRange{Int64};
    std::Float64 = 0.05,
    scenarios::Vector{String} = ["V6", "V7", "V13", "V14"],
)
    # wind generation capacity per bus
    capacity = CSV.read("data/in/wind-capacity.csv", DataFrame)
    wind_bus = Symbol.(capacity.bus)
    if length(wind_bus) !== length(scenarios)
        error("Number of wind buses and scenarios do not match")
    end

    # scenario data in p.u. per hour
    # this are 100 generation scenarios for a single zone, for 43 hours
    scenario = CSV.read("data/in/wind-scenario.csv", DataFrame)
    # make scenario hour start from 0
    scenario.hour .-= 1

    # return the generation
    generation = DataFrame([zeros(length(hours)) for _ = 1:length(wind_bus)], wind_bus)
    for (i, row) in enumerate(eachrow(capacity))
        capacity = row.capacity_MW
        # generation[:, row.bus] = scenario[hours, scenarios[i]] .* capacity
        generation[:, Symbol(row.bus)] =
            scenario[in.(scenario.hour, Ref(hours)), scenarios[i]] .* capacity

    end

    return generation
end

function prepare_generation_wind(hours::Int64; std::Float64 = 0.005)
    prepare_generation_wind(0:hours-1; std = std)
end