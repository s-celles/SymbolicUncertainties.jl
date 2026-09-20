module SymbolicUncertaintiesLatexifyExt

# Full LaTeX rendering — replaces the M7 stub with a
# `Latexify.latexify`-backed implementation when Latexify.jl is
# loaded. See `specs/010-package-extensions/contracts/ext_latexify.md`.

import SymbolicUncertainties
import Symbolics
import Latexify

# `env = :raw` keeps the fragment free of math delimiters and of
# the `\begin{equation}` wrapper Latexify emits by default. The
# contract specifies plain fragments: the caller (a certificate
# template, or the `MIME"text/latex"` show method) owns the
# delimiters, and a wrapper nested inside them renders as literal
# text in KaTeX/MathJax.
_raw_latex(expr) = string(Latexify.latexify(expr; env = :raw))

# Math-mode rendering hook used by
# `Base.show(io, MIME"text/latex", m)` in `src/latex.jl`.
SymbolicUncertainties._latex_expr(expr::Symbolics.Num) = _raw_latex(expr)

function SymbolicUncertainties.latex(
    m::SymbolicUncertainties.SymbolicMeasurement,
)
    return string(_raw_latex(m.val), " \\pm ", _raw_latex(m.err))
end

end
