

function plot_demand(x::Vector{Float64}; color = :blue)
    fig = Figure(size = (800, 300))
    ax = Axis(
        fig[1, 1],
        xlabel = "Hour [-]",
        ylabel = "Demand [MW]",
        xticks = (1:length(x), string.(0:length(x)-1)),
        xticksize = 5.5,
        xlabelsize = 18,
        ylabelsize = 18,
        xticklabelsize = 14,
    )
    barplot!(ax, x, color = color)
    return fig
end

function plot_powers(demands::Vector{<:AbstractVector{<:Real}}; colors = nothing)
    n = length(demands)
    n_hours = length(demands[1])

    # stack vertically
    fig = Figure(size = (800, 200 * n))

    for (i, d) in enumerate(demands)
        color = isnothing(colors) ? :blue : colors[i]

        if i == length(demands)
            xticklabelsvisible = true
            xticks = (1:n_hours, string.(0:n_hours-1))
            xlabel = "Hour [-]"
        else
            xticklabelsvisible = false
            xticks = 1:n_hours
            xlabel = ""
        end
        # create a new axis for each demand
        ax = Axis(
            fig[i, 1],
            xlabel = xlabel,
            ylabel = "Power [MW]",
            xticks = xticks,
            xticksize = 5.5,
            xlabelsize = 18,
            ylabelsize = 18,
            xticklabelsize = 14,
            xticklabelsvisible = xticklabelsvisible,
        )
        barplot!(ax, d, color = color)
    end
    return fig
end

function plot_powers(demands::DataFrame; colors = nothing)
    plot_powers(
        [demands[!, col] for col in names(demands) if col != :hour],
        colors = colors,
    )
end

using CairoMakie

"""
    plot_merit_order(demand_bids, generation_bids)

Create a merit order plot from vectors of (quantity, price) tuples.

- `demand_bids`: Vector of (quantity, price) tuples for demand (unsorted).
- `generation_bids`: Vector of (quantity, price) tuples for generation (unsorted).

Returns a `Figure`.
"""
function plot_merit_order(
    demand_bids::Vector{Tuple{Float64,Float64}},
    generation_bids::Vector{Tuple{Float64,Float64}},
)

    # Sort demand by descending price (price takers willing to pay more are first)
    sorted_demand = sort(demand_bids; by = x -> -x[2])
    qd = cumsum(first.(sorted_demand))  # Cumulative demand quantities
    pd = last.(sorted_demand)           # Corresponding prices

    # Sort generation by ascending price (cheapest generators first)
    sorted_generation = sort(generation_bids; by = x -> x[2])
    qg = cumsum(first.(sorted_generation))  # Cumulative gen quantities
    pg = last.(sorted_generation)           # Corresponding prices

    # Create figure and axis
    fig = Figure(size = (800, 500))
    ax = Axis(
        fig[1, 1],
        xlabel = "Cumulative Quantity [MW]",
        ylabel = "Price [€/MWh]",
        title = "Merit Order Curve",
    )

    # Plot stepwise lines
    stairs!(ax, qd, pd, label = "Demand", linewidth = 2)
    stairs!(ax, qg, pg, label = "Generation", linewidth = 2)

    axislegend(ax; position = :rb)

    return fig
end
