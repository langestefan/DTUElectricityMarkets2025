module Utils

using CSV
using DataFrames
using CairoMakie
using Statistics
using StatsBase
using Random
using JuMP
using Reexport
using LinearAlgebra: norm

include("data.jl")
include("plotting.jl")


export prepare_demands,
    prepare_generation_fixed,
    prepare_generation_wind,
    prepare_network,
    prepare_demand_pricing

# plotting
export plot_value, plot_powers, plot_merit_order, plot_powerflow

# re-export some convenient JuMP functions
@reexport using JuMP: value

# base power in MVA
S_base = 100.0
export S_base

end
