module Utils

using CSV
using DataFrames
using CairoMakie
using Statistics
using StatsBase
using Random

include("data.jl")
include("plotting.jl")


export prepare_demands, prepare_generation_fixed, prepare_generation_wind

# plotting
export plot_demand, plot_demands

end
