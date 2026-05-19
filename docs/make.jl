using SMoRe
using Documenter

DocMeta.setdocmeta!(SMoRe, :DocTestSetup, :(using SMoRe); recursive=true)

makedocs(;
    modules=[SMoRe],
    authors="Daniel Bergman <danielrbergman@gmail.com> and contributors",
    sitename="SMoRe.jl",
    format=Documenter.HTML(;
        canonical="https://Daniel Bergman.github.io/SMoRe.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/Daniel Bergman/SMoRe.jl",
    devbranch="main",
)
