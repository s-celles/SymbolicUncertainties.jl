# Offline Documentation

This site serves a reader who is online and browsing. It does not serve
a metrologist who has to attach a method description to a calibration
file, a reviewer working from a printed copy, or an integrator on a
network with no route to the internet. For them the package builds a
second deliverable: **one PDF per audience**, produced by the
repository's own tooling, with a title page and a table of contents.

## The three audiences

| Audience | For | Chapters |
|---|---|---|
| `metrologist` | Computing, reporting and certifying a budget | Getting Started, Uncertainty Sources, Sensitivity Analysis, Uncertainty Budget, Expanded Uncertainty, Reporting, Calibration Certificate, Worked Examples, Metrology Gallery, Power & Resistance Metrology, Limitations |
| `integrator` | Embedding the library in a program | Getting Started, Display/Substitution/Safety, Code Generation, Dimensional Analysis, Interoperability, ODE Integration, Limitations |
| `reviewer` | Validating the method and its limits | Methodology Reference, Linearity Check, Monte Carlo Cross-Validation, Protocol Optimisation, Inverse Inference, Limitations |

The page lists live in `docs/audiences.jl` as data. Adding an audience
is one entry there and nothing else.

**Every PDF carries the Limitations chapter.** A PDF is detached from
its context the moment it is attached to a calibration file, so the
assumptions and the liability notice travel with it. The build fails
rather than emit a PDF without that chapter.

Two pages of this site appear in no PDF, by decision: the landing page,
which is a layout and not content, and the Causal Graphs page, whose
Mermaid diagram is rendered by JavaScript in a browser and has no LaTeX
equivalent. A PDF with a hole where a diagram belongs would be worse
than a PDF without the chapter.

## Building them

```
just pdf                 # all three
just pdf metrologist     # one
```

or, without `just`:

```
julia --project=docs docs/make_pdf.jl
```

The PDFs land in `docs/build/pdf/` as
`symbolicuncertainties-<audience>-v<version>.pdf`, with the version read
from `Project.toml` and printed on the cover page together with the
authors and the licence.

**No LaTeX installation is needed.** The PDFs are compiled with
[Tectonic](https://tectonic-typesetting.github.io/), obtained as the
`tectonic_jll` artifact, so the toolchain comes with the documentation
environment rather than from the machine. Tectonic downloads its support
files once and caches them: the first build on a fresh machine needs the
network, later ones do not.

One kind of host cannot run that artifact: a distribution whose dynamic
loader refuses binaries linked for a generic Linux, NixOS among them.
Naming a tectonic of its own is then enough, and the build uses it in
place of the artifact:

```
SYMBOLICUNCERTAINTIES_TECTONIC=$(command -v tectonic) \
    julia --project=docs docs/make_pdf.jl
```

Pointed at something that is not a file, the build stops and says so,
rather than falling back to the artifact that cannot run.

Two things the toolchain does expect from the machine, both because
Documenter's own LaTeX preamble asks for them:

- the **DejaVu Sans** and **DejaVu Sans Mono** fonts, which `fontspec`
  looks up by name — without them the build stops on
  `Package fontspec Error: The font "DejaVu Sans" cannot be found`;
- **Pygments**, whose `pygmentize` the `minted` package shells out to in
  order to colour the code listings.

Both come with most desktop installations. On a bare build host, the
`dejavu-fonts` and `pygments` packages (and a refreshed font cache) are
what turn those two errors into a PDF.

## Figures are generated, never drawn

Every figure in this documentation is produced by a program from
fixtures in `docs/figures/fixtures.jl`:

```
just figures
```

Each one is computed by the package itself — the contributions come from
`relative_sensitivity`, the coverage factors from
`expanded_uncertainty`, the nonlinearity indicators from
`check_linearity`, the Monte Carlo intervals from `monte_carlo`. None of
them reproduces a table or a figure from JCGM 100:2008 or any other
standard, in keeping with the copyright of the issuing bodies.

Continuous integration re-runs the generator and fails if the working
tree moves:

```
just figures-reproducible
```

That check is the only thing that makes a figure evidence rather than
decoration: it proves the picture still shows what the code computes.

Five figures carry this through the documentation: the variance Pareto
on [Uncertainty Budget](uncertainty-budget.md), the swept sensitivity
coefficients on [Sensitivity Analysis](sensitivity-analysis.md), the two
coverage intervals on
[Monte Carlo Cross-Validation](monte-carlo-validation.md), the
nonlinearity indicator on [Linearity Check](linearity-check.md) and the
coverage factor on [Expanded Uncertainty](expanded-uncertainty.md).

The figures are PNG rather than SVG. The site would prefer vector, but
the LaTeX toolchain cannot include SVG, and one figure rendered two
different ways in two deliverables is a defect waiting to happen. They
are rendered at four times the figure's own units, which keeps a
full-width figure above 300 dpi in the PDF.

## Reproducibility

The Monte Carlo figure draws at random, and it is the one figure whose
reproducibility had to be argued rather than stated: the generator used
to seed the global generator before the call, which holds only as long
as nothing else draws from it.

`monte_carlo` now takes an `rng` keyword, so the figure passes its own
seeded generator and no longer depends on the state of the session it
runs in. Every other figure is a deterministic computation.
