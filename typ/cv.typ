#let cv(author: "", contacts: (), body) = {
  set document(author: author, title: author)
  set text(font: "Source Code Pro", size: 12pt, spacing: 30%)
  
  show heading: it => [
    #pad(bottom: -5pt, [#smallcaps(it.body)])
    #line(length: 100%, stroke: 1pt)
  ]

  // Author
  align(center)[
    #block(text(weight: 700, 1.75em, author))
  ]

  // Contact information.
  pad(
    top: 0.05em,
    bottom: 0.05em,
    x: 1em,
    align(center)[
      #grid(
        columns: 4,
        gutter: 0.5em,
        ..contacts
      )
    ],
  )

  // Main body.
  set par(justify: true)

  body
}

#let icon(name, baseline: 1.5pt) = {
  box(
    baseline: baseline,
    height: 10pt,
    image(name)
  )
}

#let exp(place, title, location, time, details) = {
  pad(
    bottom: 010%,
    grid(
      columns: (auto, 1fr),
      align(left)[
        *#place* \
        #emph[#title]
      ],
      align(right)[
        #location \
        #time
      ]
    )
  )
  details
}

#let codeText(textStr) = {
  text(blue)[*#textStr*]
}

#let codeInline(textStr) = {
  emph(text(rgb("#F7743C"))[*#textStr*])
}
