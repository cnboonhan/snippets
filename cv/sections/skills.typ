#import "@preview/modern-cv:0.10.0": *

= Systems Experience

// One column per skill category: the category name as a heading, with its
// items stacked vertically underneath.
#let resume-skill-column(category, items) = {
  set text(size: 11pt, style: "normal", weight: "light")
  block[
    #resume-skill-category(category)
    #v(0.5em, weak: true)
    #grid(columns: 1, row-gutter: 0.4em, ..items)
  ]
}

#pad(top: 2pt)[
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 16pt,
    align: left + top,
    resume-skill-column(
      "Cloud & Platform",
      (
        "AWS",
        "OpenShift & Red Hat Enterprise Linux",
        "GitLab",
        "Keycloak OIDC",
      ),
    ),
    resume-skill-column(
      "Physical AI",
      (
        "Multimodal Agentic Models",
        "3D Simulation and World Modelling",
        "Vision Language (Action) Models",
        "Humanoid Robot Data Collection",
      ),
    ),
  )
]
#block(below: 0.65em)
