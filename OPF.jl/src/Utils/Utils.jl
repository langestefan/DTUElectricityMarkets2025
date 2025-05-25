module Utils

using CSV
using DataFrames
using CairoMakie
using Statistics
using StatsBase
using Random
using JuMP
using Reexport

include("data.jl")
include("plotting.jl")


export prepare_demands,
    prepare_generation_fixed,
    prepare_generation_wind,
    prepare_network,
    prepare_demand_pricing

# plotting
export plot_value, plot_powers, plot_merit_order

# re-export some convenient JuMP functions
@reexport using JuMP: value

end
