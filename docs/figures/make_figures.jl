# Generates every figure used by the documentation (REQ-307 – REQ-311).
#
#     julia --project=docs docs/figures/make_figures.jl
#
# Output: `docs/src/assets/figures/*.png`, raster because the LaTeX
# toolchain cannot include SVG and one file has to serve both the site
# and the PDFs (REQ-308). Rendered at four times the figure's own units,
# which puts a full-text-width figure above 300 dpi in the PDF.
#
# The figures are committed, and continuous integration re-runs this
# script and fails if the working tree moves (REQ-310). That is the only
# guarantee that what the documentation shows is what the code computes.

using CairoMakie
using Distributions
using MonteCarloMeasurements
using Random
using Symbolics
using SymbolicUncertainties

include(joinpath(@__DIR__, "fixtures.jl"))

const OUT = joinpath(@__DIR__, "..", "src", "assets", "figures")
const PX_PER_UNIT = 4

# Seeded once, for the one figure that draws at random (REQ-309,
# REQ-317): `monte_carlo` has no `rng` argument, so the global
# generator is the only seam there is.
const SEED = 20261014

CairoMakie.activate!(type = "png")
set_theme!(
    Theme(
        fontsize = 16,
        Axis = (
            xgridvisible = false,
            ygridvisible = true,
            ygridstyle = :dot,
            spinewidth = 0.8,
            titlegap = 12,
        ),
    ),
)

"""
    number(expr, values) -> Float64

Insert the fixture's numbers into a symbolic expression and reduce it.
`Symbolics.substitute` inserts without reducing, so the `eval` of the
built expression is what actually produces a number — the same idiom
the Expanded Uncertainty page uses.
"""
number(expr, values::AbstractDict) =
    Float64(eval(Symbolics.toexpr(Symbolics.substitute(expr, values))))

save_figure(name, fig) = begin
    path = joinpath(OUT, "$(name).png")
    save(path, fig; px_per_unit = PX_PER_UNIT)
    @info "figure written" name path
    return path
end

# ---------------------------------------------------------------- 1/5
# Where the variance comes from, ordered. The EA-4/02 §7.3
# "percentage of variance" column as a picture.
function figure_budget_pareto()
    fx = voltage_divider()
    shares = [
        (
            name = string(name),
            share = 100 * number(
                relative_sensitivity(fx.measurement, var, sigma),
                fx.values,
            ),
        ) for (name, var, sigma) in fx.sources
    ]
    sort!(shares; by = s -> s.share, rev = true)

    fig = Figure(size = (820, 480))
    ax = Axis(
        fig[1, 1];
        title = "Contribution to the variance of Vout = Vin·R2/(R1+R2)",
        ylabel = "share of u²(Vout)  [%]",
        xticks = (1:length(shares), [s.name for s in shares]),
    )
    barplot!(
        ax,
        1:length(shares),
        [s.share for s in shares];
        color = :steelblue4,
        strokewidth = 0,
    )
    text!(
        ax,
        1:length(shares),
        [s.share for s in shares];
        text = [string(round(s.share; digits = 1), " %") for s in shares],
        align = (:center, :bottom),
        offset = (0, 6),
        fontsize = 14,
    )
    ylims!(ax, 0, 1.15 * maximum(s.share for s in shares))
    return save_figure("budget-pareto", fig)
end

# ---------------------------------------------------------------- 2/5
# The sensitivity coefficients are functions, not constants: sweeping
# one input shows which source a design is actually exposed to.
function figure_sensitivity_sweep()
    fx = voltage_divider()
    r2s = range(200.0, 5_000.0; length = 160)
    curves = map(fx.sources) do (name, var, _)
        c = sensitivity_coefficient(fx.measurement, var)
        ys = [
            abs(number(c, merge(fx.values, Dict(fx.R2sym => r2)))) for r2 in r2s
        ]
        (name = string(name), ys = ys)
    end

    fig = Figure(size = (860, 500))
    ax = Axis(
        fig[1, 1];
        title = "Sensitivity coefficients of Vout against R2  (R1 = 1 kΩ, Vin = 12 V)",
        xlabel = "R2  [Ω]",
        ylabel = "|∂Vout/∂xᵢ|  (V/V, V/Ω)",
        yscale = log10,
    )
    for curve in curves
        lines!(ax, r2s, curve.ys; linewidth = 2, label = "xᵢ = $(curve.name)")
    end
    axislegend(ax; position = :rc, framevisible = false)
    return save_figure("sensitivity-sweep", fig)
end

# ---------------------------------------------------------------- 3/5
# JCGM 101:2008 §8 validation, as the two intervals side by side.
# `MonteCarloComparison` exposes the intervals and not the samples
# (REQ-318), so this draws the intervals.
function figure_gum_vs_montecarlo()
    fx = ohms_law()
    Random.seed!(SEED)
    c = monte_carlo(
        fx.measurement,
        Dict(fx.Vsym => Normal(5.0, 0.01), fx.Isym => Normal(0.1, 0.001));
        n = 200_000,
    )

    los = [c.interval_gum[1], c.interval_mc[1]]
    his = [c.interval_gum[2], c.interval_mc[2]]
    mids = [c.estimate_gum, c.estimate_mc]

    fig = Figure(size = (860, 360))
    ax = Axis(
        fig[1, 1];
        title = "R = V/I: $(Int(round(100 * c.coverage_probability)))% coverage interval, GUM against Monte Carlo (n = $(c.n), seed $(SEED))",
        xlabel = "R  [Ω]",
        yticks = ([1, 2], ["GUM", "Monte Carlo"]),
    )
    rangebars!(
        ax,
        [1, 2],
        los,
        his;
        direction = :x,
        whiskerwidth = 22,
        linewidth = 3,
        color = [:steelblue4, :darkorange3],
    )
    scatter!(ax, mids, [1, 2]; markersize = 12, color = :black)
    ylims!(ax, 0.4, 2.6)
    return save_figure("gum-vs-montecarlo", fig)
end

# ---------------------------------------------------------------- 4/5
# The GUM §5.1.1 note made visible: the first-order form is fine until
# the input's relative uncertainty stops being small.
function figure_nonlinearity_eta()
    fx = ohms_law()
    rels = range(0.002, 0.25; length = 120)
    etas = map(rels) do rel
        values = merge(fx.values, Dict(fx.σIsym => rel * fx.values[fx.Isym]))
        eta = check_linearity(fx.f, fx.inputs; values = values)
        # `check_linearity` keys its result by the uncertainty symbol
        # (`result[m.err]`), not by the variable it belongs to.
        abs(number(eta[fx.σIsym], values))
    end

    fig = Figure(size = (860, 480))
    ax = Axis(
        fig[1, 1];
        title = "Nonlinearity indicator of R = V/I against the current's relative uncertainty",
        xlabel = "u(I)/I",
        ylabel = "|η[I]|",
    )
    lines!(ax, rels, etas; linewidth = 2, color = :steelblue4)
    hlines!(ax, [0.1]; linestyle = :dash, color = :firebrick)
    text!(
        ax,
        0.01,
        0.105;
        text = "η = 0.1 — above this a Monte Carlo check is warranted",
        align = (:left, :bottom),
        fontsize = 14,
        color = :firebrick,
    )
    return save_figure("nonlinearity-eta", fig)
end

# ---------------------------------------------------------------- 5/5
# Why a small sample cannot use k = 2: the coverage factor the package
# derives from the effective degrees of freedom.
function figure_coverage_factor()
    dofs = 1:60
    ks = map(dofs) do nu
        m = SymbolicMeasurement(
            Symbolics.Num(1.0),
            Symbolics.Num(0.1),
            Symbolics.Num(nu),
        )
        e = expanded_uncertainty(m; coverage_probability = 0.95)
        Float64(Symbolics.value(e.k))
    end

    fig = Figure(size = (860, 480))
    ax = Axis(
        fig[1, 1];
        title = "Coverage factor at 95% against effective degrees of freedom",
        xlabel = "ν_eff",
        ylabel = "k",
    )
    lines!(ax, dofs, ks; linewidth = 2, color = :steelblue4)
    hlines!(ax, [1.96]; linestyle = :dash, color = :grey30)
    text!(
        ax,
        30,
        2.0;
        text = "k → 1.96 as ν_eff → ∞",
        align = (:left, :bottom),
        fontsize = 14,
        color = :grey30,
    )
    return save_figure("coverage-factor", fig)
end

function main()
    mkpath(OUT)
    figure_budget_pareto()
    figure_sensitivity_sweep()
    figure_gum_vs_montecarlo()
    figure_nonlinearity_eta()
    figure_coverage_factor()
    @info "all figures written" dir = OUT
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
