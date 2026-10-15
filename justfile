# Entry points for SymbolicUncertainties.jl.
#
#     just            # list the recipes
#     just check      # what CI runs
#
# `just` is https://github.com/casey/just. Nothing here is required to
# use the package: every recipe is a `julia` command you can also type
# by hand.

julia := env_var_or_default("JULIA", "julia")

# List the recipes.
default:
    @just --list

# ---------------------------------------------------------------- code

# Run the test suite.
test:
    {{julia}} --project=. -e 'using Pkg; Pkg.test()'

# Resolve the test and docs environments against the current sources.
instantiate:
    {{julia}} --project=. -e 'using Pkg; Pkg.instantiate()'
    {{julia}} --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'

# --------------------------------------------------------- documentation

# Regenerate every figure the documentation shows (REQ-307).
figures:
    {{julia}} --project=docs docs/figures/make_figures.jl

# Build the HTML site, warnings fatal.
docs:
    {{julia}} --project=docs docs/make.jl

# Pass an audience to build only that one: `just pdf metrologist`.
# Build one PDF per audience: metrologist, integrator, reviewer.
pdf audience="":
    {{julia}} --project=docs docs/make_pdf.jl {{audience}}

# Figures, site and PDFs, in the order their inputs require.
docs-all: figures docs pdf

# Regenerate, then fail if the committed figures moved (REQ-310).
figures-reproducible: figures
    git diff --exit-code -- docs/src/assets/figures

# ------------------------------------------------------------- the lot

# Everything CI checks.
check: test figures-reproducible docs
