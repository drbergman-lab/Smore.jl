using SMoRe
using Documenter

DocMeta.setdocmeta!(SMoRe, :DocTestSetup, :(using SMoRe); recursive=true)

makedocs(;
    modules=[SMoRe],
    authors="Daniel Bergman <danielrbergman@gmail.com> and contributors",
    sitename="SMoReVerse.jl",
    format=Documenter.HTML(;
        canonical="https://bergman-lab.github.io/SMoReVerse.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/drbergman-lab/SMoReVerse.jl",
    devbranch="main",
)
