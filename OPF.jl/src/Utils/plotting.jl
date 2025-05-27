
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
    idx = offset:length(x)+offset

    fig = Figure(size = (800, 300))
    ax = Axis(
        fig[1, 1],
        xlabel = "Hour [-]",
        ylabel = ylabel,
        xticks = (0:length(x), string.(idx)),
        xticksize = 5.5,
        xlabelsize = 18,
        ylabelsize = 18,
        xticklabelsize = 14,
        limits = (0.25, 24.75, nothing, nothing),
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
            xticks = (1:n_hours, string.(1:n_hours))
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
            ylabel = "Power [p.u.]",
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
            string.(Int64.(0:500:maximum(cumsum(first.(generation_bids))))),
        ),
    )

    # Plot stepwise lines
    stairs!(ax, qd, pd, label = "Demand", linewidth = 2)
    stairs!(ax, qg, pg, label = "Supply", linewidth = 2)

    axislegend(ax; position = :rt)

    return fig
end


function plot_powerflow(model::JuMP.Model)

    B = model[:sets][:B]
    L = model[:sets][:L]
    T = model[:sets][:T]
    θ = model[:θ]
    P_line_expr = model[:P_line]
    t = first(T)

    ieee24_coords = Dict(
        1 => Point2f(0.15, 0.05),
        2 => Point2f(0.40, 0.05),
        3 => Point2f(0.085, 0.2),
        4 => Point2f(0.25, 0.2),
        5 => Point2f(0.45, 0.2),
        6 => Point2f(0.75, 0.2),
        7 => Point2f(0.55, 0.05),
        8 => Point2f(0.71, 0.05),
        9 => Point2f(0.25, 0.35),
        10 => Point2f(0.45, 0.35),
        11 => Point2f(0.2, 0.5),
        12 => Point2f(0.5, 0.55),
        13 => Point2f(0.72, 0.45),
        14 => Point2f(0.04, 0.5),
        15 => Point2f(0.15, 0.65),
        16 => Point2f(0.04, 0.68),
        17 => Point2f(0.05, 0.8),
        18 => Point2f(0.22, 0.9),
        19 => Point2f(0.4, 0.7),
        20 => Point2f(0.6, 0.7),
        21 => Point2f(0.45, 0.9),
        22 => Point2f(0.6, 0.9),
        23 => Point2f(0.75, 0.6),
        24 => Point2f(0.15, 0.55),
    )

    bus_coords = Dict(b => ieee24_coords[b] for b in B if haskey(ieee24_coords, b))
    if length(bus_coords) < length(B)
        missing = setdiff(B, keys(bus_coords))
        error("Missing layout coordinates for buses: $missing")
    end

    fig = Figure(size = (900, 900))
    ax = Axis(
        fig[1, 1];
        aspect = 1,
        title = "DC Power Flow at t = $t",
        xgridvisible = false,
        ygridvisible = false,
        xticklabelsvisible = false,
        xticksvisible = false,
        yticklabelsvisible = false,
        yticksvisible = false,
    )


    # --- Plot buses and annotated demand/generation/net ---
    P_G = model[:P_G]
    P_D = model[:P_D]


    # --- Plot arrows for line flows ---
    # --- Plot arrows for line flows ---
    for (i, j) in L
        Pi = value(P_line_expr[(i, j), t])
        p_i = bus_coords[i]
        p_j = bus_coords[j]
        capacity = model[:P_line_max][(i, j)]

        # Flow direction
        from, to = Pi ≥ 0 ? (p_i, p_j) : (p_j, p_i)
        vec = to - from

        # Shorten line to avoid overlap
        shrink = 0.025
        from_adj = from + shrink * vec
        to_adj = to - shrink * vec
        vec_adj = to_adj - from_adj

        # Normalize flow for color (0 = no flow, 1 = full capacity)
        flow_frac = abs(Pi / capacity)

        arrows!(
            ax,
            [from_adj],
            [vec_adj];
            linewidth = 6,
            arrowsize = 22,
            color = flow_frac,
            colormap = cgrad([:lightgreen, :red]),
            colorrange = (0.0, 1.0),  # Adjust range for better visibility
        )

        mid = from_adj + 0.5 * vec_adj
        angle = atan(vec[2], vec[1])

        # keep text upright: flip if angle is outside [-π/2, π/2]
        upright_angle = abs(angle) > π / 2 ? angle + π : angle

        text!(
            ax,
            "$(round(abs(Pi), digits = 2))/$(round(capacity, digits = 2))",
            position = (mid[1], mid[2] + 0.01),
            align = (:center, :bottom),
            fontsize = 15,
            color = :black,
            font = :bold,
            rotation = upright_angle,  # rotate label to follow arrow
        )
    end

    for b in B
        pos = bus_coords[b]
        scatter!(ax, [pos[1]], [pos[2]], markersize = 19, color = :blue)

        label = "B$b"
        text!(
            ax,
            label,
            position = (pos[1], pos[2] + 0.035),
            align = (:center, :top),
            fontsize = 17,
            color = :black,
            font = :bold,
        )
    end


    return fig
end
