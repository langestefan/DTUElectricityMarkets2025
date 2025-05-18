

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

function plot_demands(demands::Vector{<:AbstractVector{<:Real}}; colors = nothing)
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
            ylabel = "Demand [MW]",
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

function plot_demands(demands::DataFrame; colors = nothing)
    plot_demands(
        [demands[!, col] for col in names(demands) if col != :hour],
        colors = colors,
    )
end