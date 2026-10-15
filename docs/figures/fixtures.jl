# Fixtures for the generated figures (REQ-307).
#
# Everything plotted in the documentation comes from here: a named
# measurement model, the numbers it is evaluated at, and nothing
# reproduced from a standard (REQ-312). A figure that needs new numbers
# gets a new fixture, so that the figure scripts stay plotting code.

using Symbolics
using SymbolicUncertainties

# `SymbolicMeasurement(x, s)` rather than the ± operator: the figure
# scripts also load MonteCarloMeasurements and, through Makie,
# IntervalSets, and all three export that operator. Under `using` of
# all three the name is ambiguous and resolves to nothing at all.

"""
    voltage_divider()

`Vout = Vin·R2/(R1+R2)`, the textbook three-source model used by the
budget and sensitivity figures. Returns the measurement, the symbols,
and the numbers to evaluate at (volts and ohms, dimensionless).

Not a GUM worked example — a textbook illustration, as REQ-162 requires
this one to be labelled.
"""
function voltage_divider()
    @variables Vin σVin R1 σR1 R2 σR2
    Vout = propagate(
        (vin, r1, r2) -> vin * r2 / (r1 + r2),
        [
            SymbolicMeasurement(Vin, σVin),
            SymbolicMeasurement(R1, σR1),
            SymbolicMeasurement(R2, σR2),
        ],
    )
    values = Dict(
        Vin => 12.0,
        σVin => 0.1,     # V
        R1 => 1_000.0,
        σR1 => 10.0,   # Ω
        R2 => 2_000.0,
        σR2 => 20.0,   # Ω
    )
    sources = [(:Vin, Vin, σVin), (:R1, R1, σR1), (:R2, R2, σR2)]
    return (; measurement = Vout, values, sources, R2sym = R2)
end

"""
    ohms_law()

`R = V/I`, the model whose nonlinearity in `I` is worth a figure: the
quotient is linear in `V` and not in `I`, which is the whole point of
the linearity check.
"""
function ohms_law()
    @variables V σV I σI
    R = SymbolicMeasurement(V, σV) / SymbolicMeasurement(I, σI)
    values = Dict(V => 5.0, σV => 0.01, I => 0.1, σI => 0.001)
    return (;
        measurement = R,
        values,
        f = (v, i) -> v / i,
        inputs = [SymbolicMeasurement(V, σV), SymbolicMeasurement(I, σI)],
        Vsym = V,
        σVsym = σV,
        Isym = I,
        σIsym = σI,
    )
end
