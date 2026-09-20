using Documenter
using DocumenterLandingPage
using DocumenterMermaid
using SymbolicUncertainties

# Loaded for the whole build, not just the pages that import it:
# `Latexify.jl` activates `SymbolicUncertaintiesLatexifyExt`, which is
# what turns a measurement's `text/latex` rendering into mathematics.
# Without it here, a page would render its measurements as LaTeX text
# mode or as mathematics depending on whether an earlier page in
# `pages.jl` happened to have loaded Latexify first.
using Latexify

include("pages.jl")

# Doctests run with these bindings in scope, so a `jldoctest` block
# does not have to repeat its imports.
DocMeta.setdocmeta!(
    SymbolicUncertainties,
    :DocTestSetup,
    :(using SymbolicUncertainties, Symbolics);
    recursive = true,
)

makedocs(;
    modules = [SymbolicUncertainties],
    authors = "Sébastien Celles <s.celles@gmail.com>",
    sitename = "SymbolicUncertainties.jl",
    format = Documenter.HTML(;
        canonical = "https://s-celles.github.io/SymbolicUncertainties.jl",
        edit_link = "main",
        # `assets/mermaid-pin.js` renders the DocumenterMermaid
        # diagrams with a pinned mermaid: the floating `mermaid@11`
        # tag DocumenterMermaid imports has been broken by RequireJS
        # since 11.17.0. See `upstream-bugs.md` UB-010.
        assets = ["assets/mermaid-pin.js"],
        # MathJax rather than the default KaTeX. Documenter loads
        # KaTeX's auto-render contrib through RequireJS, whose
        # anonymous `define` intermittently resolves to a
        # non-function — "renderMathInElement is not a function" in
        # the console — and every formula on the page then stays on
        # screen as its raw `\[...\]` source. MathJax3 is injected
        # as a plain <script> and has no such race. See
        # `upstream-bugs.md` UB-009.
        # `tags = "none"` keeps machine-generated expressions
        # un-numbered — Documenter's MathJax3 default is "ams",
        # which would number every `\begin{equation}` that
        # Symbolics emits when it renders a `Num` through Latexify.
        mathengine = Documenter.MathJax3(
            Dict(
                :tex => Dict(
                    "inlineMath" => [["\$", "\$"], ["\\(", "\\)"]],
                    "tags" => "none",
                    "packages" => ["base", "ams", "autoload"],
                ),
            ),
        ),
        # A symbolic uncertainty library emits large expressions by
        # nature; the default 200 KiB page budget is tuned for prose.
        size_threshold = 500_000,
        size_threshold_warn = 400_000,
    ),
    pages = pages,
    plugins = [LandingPage()],
    warnonly = false,
)

if get(ENV, "GITHUB_ACTIONS", "") == "true"
    deploydocs(;
        repo = "github.com/s-celles/SymbolicUncertainties.jl.git",
        devbranch = "main",
        push_preview = true,
    )
end
