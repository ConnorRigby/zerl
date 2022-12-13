for f <- Path.wildcard("src/*.zig"), do: File.read!(f) |> String.replace("  ", " ") |> fn(s) -> File.write!(f, s) end .()
