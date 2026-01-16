# Formatter configuration with Styler plugin
# Copy this to your project root as .formatter.exs

[
  # Styler plugin for automatic code style improvements
  plugins: [Styler],

  # Input files to format
  inputs: [
    "*.{ex,exs}",
    "{config,lib,test}/**/*.{ex,exs}"
  ],

  # Import dependencies for proper formatting
  import_deps: [:ecto, :phoenix],

  # Line length (default: 98)
  line_length: 98,

  # Subdirectories with their own formatting rules
  subdirectories: []
]
