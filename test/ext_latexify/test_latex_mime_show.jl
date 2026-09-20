@testitem "SymbolicUncertaintiesLatexifyExt: MIME\"text/latex\" is real math" begin
    using SymbolicUncertainties
    using Symbolics
    using Latexify

    @variables V I σV σI
    m = (V ± σV) / (I ± σI)

    io = IOBuffer()
    show(io, MIME"text/latex"(), m)
    s = String(take!(io))

    @test startswith(s, "\$")
    @test endswith(s, "\$")
    @test occursin("\\pm", s)
    # Math-mode markup, not the Julia call syntax the minimal
    # in-library formatter used to emit.
    @test occursin("\\sqrt{", s)
    @test occursin("\\frac{", s)
    @test !occursin("sqrt(", s)
    @test !occursin("\\text{", s)
    # A nested equation environment inside `$...$` is what breaks
    # the rendered documentation.
    @test !occursin("\\begin{equation}", s)
end

@testitem "SymbolicUncertaintiesLatexifyExt: latex(m) emits bare fragments" begin
    using SymbolicUncertainties
    using Symbolics
    using Latexify

    @variables V I σV σI
    m = (V ± σV) / (I ± σI)
    s = latex(m)

    @test occursin("\\pm", s)
    # The contract specifies no math-delimiter wrapping at this
    # layer — the caller owns the delimiters.
    @test !occursin("\$", s)
    @test !occursin("\\begin{equation}", s)
    @test !occursin("sqrt(", s)
end
