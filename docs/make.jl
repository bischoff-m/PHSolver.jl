using Documenter
using DocumenterCitations

bib = CitationBibliography(
    joinpath(@__DIR__, "src", "references.bib");
    style=:numeric
)
makedocs(
    sitename="PHSolver Documentation",
    format=Documenter.HTML(assets=["assets/custom.css"]),
    plugins=[bib],
    pages=[
        "Home" => "index.md",
        "Basics" => "basics.md",
        "Notation" => "notation.md",
        "Port-Hamiltonian Systems" => "linear-phs.md",
        "Control of Port-Hamiltonian Systems" => "control-of-phs.md",
        "References" => "references.md",
    ],
)
deploydocs(
    repo="github.com/bischoff-m/hamilton-sim.git",
)
