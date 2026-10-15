# Page subsets per audience, as data (REQ-301).
#
# `make_pdf.jl` builds one PDF per entry below. A page is named by its
# file, and its title is taken from `pages.jl`, so a title can never
# drift between the site and the PDFs.
#
# Adding an audience means adding an entry here and nothing else.
#
# Two pages of the site appear in no PDF, by decision and not by
# oversight (REQ-316):
#
#   * `index.md` is a DocumenterLandingPage hero block wrapped in
#     `@raw html`. It has no LaTeX rendering at all, and the PDF's own
#     title page is what replaces it.
#   * `causal-graphs.md` carries a Mermaid diagram, and Mermaid is
#     rendered by JavaScript in a browser. Until the diagram is
#     replaced by a generated figure, the page stays out rather than
#     going into a PDF with a hole where its diagram should be.

const LIMITATIONS_PAGE = "limitations.md"

# `key` names the file, `title` goes on the cover page and into
# `\title` of the LaTeX document. The title stays plain ASCII: Documenter
# names the .tex file after it, and the LaTeX toolchain hands that name
# to a shell, where an apostrophe or a dash outside ASCII ends the build.
const AUDIENCES = [
    (
        key = "metrologist",
        title = "SymbolicUncertainties.jl - Guide for Metrologists",
        blurb = "Computing, reporting and certifying an uncertainty budget.",
        pages = [
            "getting-started.md",
            "uncertainty-sources.md",
            "sensitivity-analysis.md",
            "uncertainty-budget.md",
            "expanded-uncertainty.md",
            "reporting.md",
            "calibration-certificate.md",
            "worked-examples.md",
            "metrology-gallery.md",
            "power-resistance-metrology.md",
            LIMITATIONS_PAGE,
        ],
    ),
    (
        key = "integrator",
        title = "SymbolicUncertainties.jl - Guide for Integrators",
        blurb = "Embedding the library in a program, and the boundaries that come with it.",
        pages = [
            "getting-started.md",
            "display-substitute-safety.md",
            "code-generation.md",
            "dimensional-analysis.md",
            "interoperability.md",
            "ode-integration.md",
            LIMITATIONS_PAGE,
        ],
    ),
    (
        key = "reviewer",
        title = "SymbolicUncertainties.jl - Guide for Reviewers",
        blurb = "Validating the method, its assumptions and its limits.",
        pages = [
            "methodology-reference.md",
            "linearity-check.md",
            "monte-carlo-validation.md",
            "protocol-optimisation.md",
            "inverse-inference.md",
            LIMITATIONS_PAGE,
        ],
    ),
]

"""
    site_titles(pages) -> Dict{String,String}

Flatten `pages.jl`'s nested `"Title" => "file.md"` structure into a
lookup from file to title. Documenter accepts nested vectors for
sections, so this walks rather than iterates.
"""
function site_titles(pages)
    out = Dict{String,String}()
    walk(x::Pair{<:AbstractString,<:AbstractString}) = (out[x.second] = x.first)
    walk(x::Pair) = walk(x.second)
    walk(x::AbstractVector) = foreach(walk, x)
    walk(x::AbstractString) = (out[x] = x)
    walk(pages)
    return out
end

"""
    audience_pages(audience, titles) -> Vector{Pair{String,String}}

The `pages` argument for one audience's `makedocs` call, with the titles
the site uses. Enforces REQ-302 (the Limitations page travels with every
PDF) and REQ-303 (no page that the site does not have).
"""
function audience_pages(audience, titles::AbstractDict)
    LIMITATIONS_PAGE in audience.pages || error(
        "audience $(audience.key) omits $(LIMITATIONS_PAGE): every PDF " *
        "carries the assumptions and the liability notice with it (REQ-302)",
    )
    missing_pages = filter(p -> !haskey(titles, p), audience.pages)
    isempty(missing_pages) || error(
        "audience $(audience.key) names pages the site does not have " *
        "(REQ-303): $(join(missing_pages, ", "))",
    )
    return [titles[p] => p for p in audience.pages]
end
