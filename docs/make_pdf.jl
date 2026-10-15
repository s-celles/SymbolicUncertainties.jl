# Builds one PDF per audience (REQ-300 – REQ-306, REQ-313 – REQ-315).
#
#     julia --project=docs docs/make_pdf.jl              # all audiences
#     julia --project=docs docs/make_pdf.jl metrologist   # just one
#
# Output: `docs/build/pdf/symbolicuncertainties-<audience>-v<version>.pdf`.
# Under `docs/build/`, which `.gitignore` already excludes — a repository
# whose ignore file is an allowlist should not need a new rule to hold a
# build artefact.
#
# Compiled with `tectonic` from `tectonic_jll`: no system LaTeX, no
# latexmk, no Docker (REQ-313). Tectonic fetches its support files once
# and caches them, so the first run of a fresh machine needs the network
# and every run after it does not.
#
# `SYMBOLICUNCERTAINTIES_TECTONIC` names a tectonic of the host's own
# instead, for a distribution whose loader cannot run the generic-Linux
# binary that the artefact ships (NixOS, for one).

using Documenter
using Latexify
using SymbolicUncertainties
using Symbolics
using TOML
using tectonic_jll

include(joinpath(@__DIR__, "pages.jl"))
include(joinpath(@__DIR__, "audiences.jl"))

# Symbolics shows a symbolic expression as `$$ \begin{equation} ... $$`:
# two wrappers, one inside the other. MathJax tolerates it, LaTeX refuses
# it outright ("Bad math environment delimiter"), and Documenter writes a
# `text/latex` MIME into the document untouched. Asking Latexify for the
# bare expression drops the inner wrapper. See upstream-bugs.md UB-011.
Latexify.set_default(env = :raw)

# The outer `$$` is Symbolics' own, and it is display math, which is
# illegal inside a table cell. DataFrames builds a `tabular` out of
# exactly those cells, so a budget rendered `as = :dataframe` ends the
# build with "\mathtt allowed only in math mode". Inline math set in
# `\displaystyle` reads the same and is legal everywhere, in a cell as
# in a paragraph.
#
# Replacing a method of another package is not something to do in a
# library; this is a build script, the replacement lives for the length
# of the build, and the alternative is a deliverable that does not
# exist. UB-011 carries the report.
Base.show(io::IO, ::MIME"text/latex", x::Symbolics.Num) =
    print(io, "\$\\displaystyle ", Latexify.latexify(x; env = :raw), "\$")

const ROOT = normpath(joinpath(@__DIR__, ".."))
const PDF_DIR = joinpath(@__DIR__, "build", "pdf")

# The version is read, never written here (REQ-304).
const VERSION =
    VersionNumber(TOML.parsefile(joinpath(ROOT, "Project.toml"))["version"])
const AUTHORS = "Sébastien Celles <s.celles@gmail.com>"

# REQ-313 asks that the PDF be compiled by tectonic, not that the binary
# come from an artefact. The artefact is the default because it needs no
# LaTeX installed; a host that cannot execute it may name its own:
#
#     SYMBOLICUNCERTAINTIES_TECTONIC=$(which tectonic) \
#         julia --project=docs docs/make_pdf.jl
#
function tectonic_binary()
    override = get(ENV, "SYMBOLICUNCERTAINTIES_TECTONIC", "")
    isempty(override) && return tectonic_jll.tectonic()
    isfile(override) || error(
        "SYMBOLICUNCERTAINTIES_TECTONIC is set to \"$override\", which is not a file",
    )
    return override
end

"""
    licence() -> String

The licence identifier, taken from the first non-empty line of
`LICENSE.md` so that the cover page cannot disagree with the file it
claims to quote (REQ-304).
"""
function licence()
    for line in eachline(joinpath(ROOT, "LICENSE.md"))
        isempty(strip(line)) || return strip(line)
    end
    error("LICENSE.md is empty: the cover page has no licence to state")
end

"""
    check_licence_matches_cover()

`docs/src/assets/custom.sty` prints the licence on the cover page, and
LaTeX has no way to read `LICENSE.md`. Rather than let the two drift,
the build compares them and refuses to produce a PDF that would state a
licence the repository does not carry (REQ-304).
"""
function check_licence_matches_cover()
    sty = joinpath(@__DIR__, "src", "assets", "custom.sty")
    text = read(sty, String)
    m = match(r"\\providecommand\{\\DocLicence\}\{([^}]*)\}", text)
    isnothing(m) && error("no \\DocLicence definition in $(sty)")
    stated = strip(m.captures[1])
    actual = licence()
    stated == actual || error(
        "the cover page would state \"$(stated)\" but LICENSE.md says " *
        "\"$(actual)\": fix $(sty) (REQ-304)",
    )
    return actual
end

"""
    build(audience, titles) -> String

Render one audience to PDF and return the path of the file.

`doctest = false`: the HTML build runs the doctests, and running them
once per audience would triple a build that validates nothing new
(REQ-315).

`remotes = nothing`: no source links in a PDF, hence no need for a git
remote, hence no dependency on a git binary at build time.

`warnonly`: a PDF holds a subset of the pages, so a cross-reference to
a page this audience does not carry is expected rather than wrong. The
HTML build, with `warnonly = false`, stays the gate on the content
itself; this build re-renders content that has already passed it.
"""
function build(audience, titles)
    build_dir = joinpath("build", "latex-$(audience.key)")   # under docs/build/
    @info "building PDF" audience = audience.key pages = length(audience.pages)

    makedocs(;
        modules = [SymbolicUncertainties],
        authors = AUTHORS,
        sitename = audience.title,
        root = @__DIR__,
        build = build_dir,
        pages = audience_pages(audience, titles),
        doctest = false,
        # A PDF has no "edit this page on GitHub" link, so it needs no
        # remote — and asking for one would make the build depend on a
        # runnable `git`, which is not a property of the deliverable.
        # Documenter names this exact option for the case.
        remotes = nothing,
        warnonly = [
            :cross_references,
            :missing_docs,
            :docs_block,
            :autodocs_block,
        ],
        format = Documenter.LaTeX(;
            platform = "tectonic",
            tectonic = tectonic_binary(),
            version = string(VERSION),
        ),
    )

    # `LaTeXWriter` names the file after the sitename with the spaces
    # removed, then appends the version. Renaming it gives the
    # deliverable the stable name of REQ-306.
    produced = only(
        filter(
            f -> endswith(f, ".pdf"),
            readdir(joinpath(@__DIR__, build_dir); join = true),
        ),
    )
    mkpath(PDF_DIR)
    final = joinpath(
        PDF_DIR,
        "symbolicuncertainties-$(audience.key)-v$(VERSION).pdf",
    )
    mv(produced, final; force = true)
    @info "PDF written" audience = audience.key path = final licence = licence()
    return final
end

function main(selected = String[])
    check_licence_matches_cover()
    titles = site_titles(pages)
    wanted =
        isempty(selected) ? AUDIENCES :
        filter(a -> a.key in selected, AUDIENCES)

    if isempty(wanted)
        error(
            "no audience matches $(selected); known audiences: " *
            join((a.key for a in AUDIENCES), ", "),
        )
    end

    built = [build(audience, titles) for audience in wanted]
    @info "done" count = length(built) dir = PDF_DIR
    return built
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end
