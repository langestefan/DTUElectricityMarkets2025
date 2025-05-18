module Utils

using CSV
using DataFrames
using CairoMakie
using Statistics
using StatsBase
using Random

include("data.jl")
include("plotting.jl")


export prepare_demands,
    prepare_generation_fixed,
    prepare_generation_wind,
    prepare_network,
    prepare_demand_pricing

# plotting
export plot_demand, plot_powers, plot_merit_order

end
