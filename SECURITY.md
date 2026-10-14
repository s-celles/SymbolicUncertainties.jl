# Security Policy

## Scope

SymbolicUncertainties.jl propagates measurement uncertainty through
symbolic expressions, following JCGM 100:2008 (the GUM). It is a library,
not a service: it opens no socket, listens on no port, authenticates
nobody, and runs with exactly the privileges of the Julia process that
loaded it. There is no deployment to attack. The attack surface is the
API, and what a calling program feeds into it.

### Trust boundaries

Four places where the library turns data into something that runs, or
reaches outside the process:

1. **Symbolic expressions are code.** To reduce an expression to a number
   the library evaluates it (`eval(Symbolics.toexpr(...))`, in
   `src/certified.jl`, `src/linearity.jl`, `src/dominant.jl`) or compiles
   it (`Symbolics.build_function(...; expression = Val{false})`, in
   `src/source.jl` and under `build_evaluator` in `src/codegen.jl`). An
   expression assembled from input you do not control is therefore
   untrusted code: a program that builds one out of, say, an HTTP request
   body has handed that request its Julia process. Validate before you
   build, not after.
2. **Model strings.** With the CausalGraphs extension loaded,
   `parse_measurement_model` and `evaluate_measurement_model` read the
   `:expr` metadata of a graph node, parse it with `Meta.parse`, and walk
   the result through a deliberately small interpreter: an allowlist of
   `+ - * / ^ sin cos exp log sqrt` plus the graph's own variables,
   accepting only `Symbol`, `Number` and `:call` nodes
   (`ext/SymbolicUncertaintiesCausalGraphsExt.jl`). Everything else
   raises. This is the one place that is meant to survive a hostile
   string, so an escape from that allowlist is a vulnerability.
3. **Generated code.** `build_evaluator(m, variables; target = ...)`
   either compiles a Julia callable (`JuliaTarget()`) or returns C source
   as a `String` (`CTarget()`, `src/codegen.jl`). Both are derived from
   your expressions and are exactly as trustworthy as they are; the C
   string becomes code the moment you compile it.
4. **An out-of-process CAS.** With the Giac extension loaded, expressions
   are handed to Giac and the results parsed back
   (`ext/SymbolicUncertaintiesGiacExt.jl`). That is a separate program,
   with its own security posture.

### What counts as a vulnerability

- Code execution through an API documented as accepting data — above all
  an escape from the allowlisted interpreter of boundary 2.
- Code generation that emits code executing content it was given as data.
- A vulnerability in a dependency that is reachable through a documented
  API of this package.

### What does not

- **A wrong number.** An incorrect combined uncertainty, a wrong coverage
  factor, a correlation term silently dropped: in a metrology library
  that is the most consequential kind of bug there is, and we do want to
  hear about it — but in public, as an ordinary issue, because every user
  needs to know. `docs/src/limitations.md` records the limits that are
  already known and documented.
- An exception or a stack overflow on expressions the calling program
  built itself.
- A bug in Symbolics.jl or SymbolicUtils.jl: report those to the upstream
  project. The ones this package has hit are listed in `upstream-bugs.md`.

## Supported versions

The package is pre-1.0 under Semantic Versioning 2.0.0, so the public API
may change on a minor bump. It is not yet registered in Julia's General
registry and carries no release tags, which means there is exactly one
supported version: `main`, declared as 0.10.0 in `Project.toml`. Security
fixes land there and in the next published version; no older line is
maintained.

| Version   | Supported          |
| --------- | ------------------ |
| `main`    | :white_check_mark: |
| anything earlier | :x:         |

Supported Julia: 1.10 and later (`julia = "1.10"` in `[compat]`).

## Reporting a vulnerability

**Please do not open a public issue for a vulnerability.**

Report it privately through GitHub's private vulnerability reporting, at
<https://github.com/s-celles/SymbolicUncertainties.jl/security/advisories/new>.
That opens a draft advisory visible only to you and the maintainer.

Please include, as far as you can:

- **Component** — the file or extension, and the function you called.
- **Versions** — SymbolicUncertainties, Julia, Symbolics, and any
  extension dependencies that were loaded.
- **Reproduction** — a minimal script that can be run as is.
- **Impact** — what an attacker gains, and what access they need first.
- Your own severity assessment, if you have one.

What to expect:

- acknowledgement within **7 days**;
- a first assessment within **30 days**;
- an advisory published with **credit to you**, unless you would rather
  stay anonymous.

If the flaw turns out to be upstream, in Symbolics.jl, SymbolicUtils.jl or
another dependency, it belongs to that project's disclosure process. We
will not file it there on your behalf without your agreement.
