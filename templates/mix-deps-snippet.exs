# Add these dependencies to your mix.exs file
# Copy and paste into the deps() function

# Required for production-quality Elixir development
{:credo, "~> 1.7", only: [:dev, :test], runtime: false},
{:styler, "~> 1.0", only: [:dev, :test], runtime: false},

# Recommended for testing
{:mox, "~> 1.0", only: :test},
{:stream_data, "~> 0.6", only: [:dev, :test]},

# Recommended for HTTP clients (prefer over HTTPoison/Tesla)
{:req, "~> 0.4"},

# Recommended for background jobs
{:oban, "~> 2.19"},

# JSON: Built-in since Elixir 1.18 (JSON module). Only add Jason for pre-1.18 projects:
# {:jason, "~> 1.4"},

# Optional but valuable
{:ex_doc, "~> 0.30", only: :dev, runtime: false},
{:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false},  # Less critical on 1.18+ (compiler handles most type checks)
{:benchee, "~> 1.1", only: :dev}
