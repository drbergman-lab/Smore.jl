using SMoReVerse
using Documenter

DocMeta.setdocmeta!(SMoReVerse, :DocTestSetup, :(using SMoReVerse); recursive=true)

makedocs(;
    modules=[SMoReVerse],
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
