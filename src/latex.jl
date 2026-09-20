# LaTeX display for `SymbolicMeasurement` — JCGM 100:2008 §7.2.2
# textual presentation convention, extended to rich-display
# consumers (Jupyter, Pluto, VS Code notebooks, Documenter).
#
# The output includes surrounding `$...$` inline math delimiters
# per Clarifications Q1 so notebooks render the output as math
# without caller intervention.
#
# Rendering an expression fragment is delegated to the
# `_latex_expr` hook, which `SymbolicUncertaintiesLatexifyExt`
# implements with `Latexify.latexify` — the only component of the
# stack that knows how to turn `sqrt(x^2)` into `\sqrt{x^{2}}`.
# Without `Latexify.jl` loaded the hook returns `nothing` and the
# fragment falls back to LaTeX *text* mode: the plain-text form of
# the expression, escaped so that it is valid LaTeX rather than
# math-mode markup that no engine can parse.

# Hook for the expression-to-LaTeX conversion.
#
# Declared `(args...; kwargs...)` — strictly more general than the
# extension's `::Symbolics.Num` method — so that loading
# `Latexify.jl` *adds* a method instead of overwriting this one.
# Julia >= 1.12 makes method overwriting during module
# precompilation a hard error. This mirrors the `src/latex_stub.jl`
# and `src/mtk_stubs.jl` pattern.
#
# Returns `nothing` when no math-mode rendering is available.
_latex_expr(args...; kwargs...) = nothing

# `Base.show` specialisation for MIME"text/latex" — emits
# `$val \pm err$` with inline math delimiters included per
# Clarifications Q1. See `docs/src/display-substitute-safety.md`
# for the full user-facing documentation. Traces REQ-112
# (JCGM 100:2008 §7.2.2).
function Base.show(io::IO, ::MIME"text/latex", m::SymbolicMeasurement)
    val_s = _latex_fragment(m.val)
    err_s = _latex_fragment(m.err)
    print(io, "\$", val_s, " \\pm ", err_s, "\$")
end

# LaTeX fragment for a `Symbolics.Num`. Concrete numeric values
# print as themselves; symbolic expressions go through the
# `_latex_expr` hook, and fall back to escaped LaTeX text mode
# when no LaTeX backend is loaded.
function _latex_fragment(expr::Symbolics.Num)
    raw = Symbolics.value(expr)
    if raw isa Real && !(raw isa Symbolics.Num)
        return string(raw)
    end
    rendered = _latex_expr(expr)
    rendered === nothing && return _latex_text_fallback(expr)
    return rendered
end

# Escaped LaTeX text-mode rendering of an expression. The result
# reads exactly like the `text/plain` display — `V / I` rather
# than `\frac{V}{I}` — but is valid LaTeX, which the previous
# bare `string(expr)` fragment was not: `sqrt(x^2)*σ` placed in
# math mode renders as an italic product of the letters `s`, `q`,
# `r`, `t`.
function _latex_text_fallback(expr::Symbolics.Num)
    return string("\\text{", _escape_latex_text(string(expr)), "}")
end

# Escape the characters that are special in LaTeX text mode.
function _escape_latex_text(s::AbstractString)
    io = IOBuffer()
    for c in s
        if c == '\\'
            print(io, "\\textbackslash{}")
        elseif c in ('{', '}', '&', '%', '$', '#', '_')
            print(io, '\\', c)
        elseif c == '^'
            print(io, "\\^{}")
        elseif c == '~'
            print(io, "\\~{}")
        else
            print(io, c)
        end
    end
    return String(take!(io))
end
