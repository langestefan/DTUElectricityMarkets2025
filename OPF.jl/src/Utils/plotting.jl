
function plot_value(
    model::Model,
    variable::Symbol;
    color = :blue,
    ylabel = "Value",
    offset = 0,
)
    # extract the variable values from the model
    x = Vector(value.(model[variable]))

    return plot_value(x; color = color, ylabel = ylabel, offset = offset)
end

function plot_value(x::Vector{<:Real}; color = :blue, ylabel = "Value", offset = 0)

    idx = offset:length(x)+offset-1

    fig = Figure(size = (800, 300))
    ax = Axis(
        fig[1, 1],
        xlabel = "Hour [-]",
        ylabel = ylabel,
        xticks = (0:length(x)-1, string.(idx)),
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

    # sort demand by descending price (price takers willing to pay more are first)
    sorted_demand = sort(demand_bids; by = x -> -x[2])
    qd = cumsum(first.(sorted_demand))  # Cumulative demand quantities
    pd = last.(sorted_demand)           # Corresponding prices

    # sort generation by ascending price (cheapest generators first)
    sorted_generation = sort(generation_bids; by = x -> x[2])
    qg = cumsum(first.(sorted_generation))  # Cumulative gen quantities

    # ensure the first point for generation starts at 0 MW
    qg = [0.0; qg]
    pg = last.(sorted_generation)
    pg = [0.0; pg]

    # ensure last point for demand is at the maximum cumulative quantity and drops down
    qd = [qd; qd[end]]
    pd = [pd; 0.0]  # Demand price drops to 0 at the end

    # create figure and axis
    fig = Figure(size = (800, 500))
    ax = Axis(
        fig[1, 1],
        xlabel = "Cumulative Quantity [MW]",
        ylabel = "Price [€/MWh]",
        title = "Merit Order Curve",
        yticks = (0:5:100, string.(0:5:100)),
        xticks = (
            0:500:maximum(cumsum(first.(generation_bids))),
            string.(0:500:maximum(cumsum(first.(generation_bids)))),
        ),
    )

    # Plot stepwise lines
    stairs!(ax, qd, pd, label = "Demand", linewidth = 2)
    stairs!(ax, qg, pg, label = "Generation", linewidth = 2)

    axislegend(ax; position = :rb)

    return fig
end
