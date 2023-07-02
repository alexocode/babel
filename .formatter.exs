# Used by "mix format"
locals_without_parens = []

[
  inputs: ["{mix,.credo,.formatter,.dialyzer_ignore}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: locals_without_parens ++ [deflifted: 1, defmock: 2, send: 2],
  export: [locals_without_parens: locals_without_parens]
]
