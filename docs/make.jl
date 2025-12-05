using Documenter
using DocumenterCitations

bib = CitationBibliography(
    joinpath(@__DIR__, "src", "references.bib");
    style=:numeric
)
makedocs(
    sitename="HamiltonSim Documentation",
    format=Documenter.HTML(assets=["assets/custom.css"]),
    plugins=[bib],
    pages=[
        "Home" => "index.md",
        "Basics" => "basics.md",
        "Preliminaries" => "preliminaries.md",
        "Port-Hamiltonian Systems" => "port-hamiltonian-systems.md",
        "Control of Port-Hamiltonian Systems" => "control-of-phs.md",
        "References" => "references.md",
    ],
)
