@testitem "LaTeX: numeric measurement rendering" begin
    using SymbolicUncertainties
    using Symbolics

    m = 5.0 ± 0.1
    io = IOBuffer()
    show(io, MIME"text/latex"(), m)
    s = String(take!(io))

    # Must include $...$ delimiters and \pm separator.
    @test startswith(s, "\$")
    @test endswith(s, "\$")
    @test occursin("\\pm", s)
    @test occursin("5", s)
    @test occursin("0.1", s)
end

@testitem "LaTeX: symbolic measurement preserves symbolic content" begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx
    io = IOBuffer()
    show(io, MIME"text/latex"(), m)
    s = String(take!(io))

    @test startswith(s, "\$")
    @test endswith(s, "\$")
    @test occursin("\\pm", s)
    # Symbolic content (x or σx) survives into the LaTeX fragment.
    @test occursin("x", s) || occursin("σ", s)
end

@testitem "LaTeX: M1 Unicode plain-text display is unchanged" begin
    using SymbolicUncertainties
    using Symbolics

    m = 5.0 ± 0.1
    io = IOBuffer()
    show(io, MIME"text/plain"(), m)
    s = String(take!(io))

    # The M1 plain-text form uses Unicode ± (not \pm, not $…$).
    @test occursin("±", s)
    @test !occursin("\\pm", s)
    @test !startswith(s, "\$")
end

@testitem "LaTeX: fallback on unknown expression form does not throw" begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    # Use a complicated propagated measurement; even if the formatter
    # cannot render every subterm, it must not error.
    m = propagate((a,) -> sin(a) + a^3, [x ± σx])
    io = IOBuffer()
    @test_nowarn show(io, MIME"text/latex"(), m)
    s = String(take!(io))
    @test startswith(s, "\$")
    @test endswith(s, "\$")
end

@testitem "LaTeX: text-mode fallback escapes LaTeX specials" begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx y σy
    m = propagate((a, b) -> a * b, [x ± σx, y ± σy])

    # Without a LaTeX backend the fragment is text mode, not bare
    # Julia call syntax dropped into math mode.
    frag = SymbolicUncertainties._latex_text_fallback(m.err)
    @test startswith(frag, "\\text{")
    @test endswith(frag, "}")
    # `^` is a LaTeX special even inside \text{}: every one of them
    # must have been escaped.
    @test !occursin("^", replace(frag, "\\^{}" => ""))

    esc = SymbolicUncertainties._escape_latex_text("a_1^2 & 50% {x} #y ~z \$q")
    @test esc == "a\\_1\\^{}2 \\& 50\\% \\{x\\} \\#y \\~{}z \\\$q"
end

@testitem "LaTeX: no LaTeX backend leaves a parseable fragment" begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx
    io = IOBuffer()
    show(io, MIME"text/latex"(), m)
    s = String(take!(io))

    # Either the Latexify extension rendered real math mode, or
    # the text-mode fallback ran — never raw Julia syntax in math
    # mode.
    @test occursin("\\text{", s) || !occursin("(", s)
end
