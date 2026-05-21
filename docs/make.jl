using Smore
using Documenter

DocMeta.setdocmeta!(Smore, :DocTestSetup, :(using Smore); recursive=true)

makedocs(;
    modules=[Smore],
    authors="Daniel Bergman <danielrbergman@gmail.com> and contributors",
    sitename="Smore.jl",
    format=Documenter.HTML(;
        canonical="https://bergman-lab.github.io/Smore.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/drbergman-lab/Smore.jl",
    devbranch="main",
)
