#!/usr/bin/env julia

function quiet_pkg_test()
    # Run a separate Julia process to execute Pkg.test() and capture combined output.
    # Pipe through `sed` to remove the verbose package status lines.
    # Force color output even when output is being piped
    # Use awk: strip ANSI escapes for matching but print the original (colored) line.
    shcmd = raw"""julia --color=yes --project=. -e 'using Pkg; Pkg.test()' 2>&1 | awk '{ orig=$0; clean=$0; gsub(/\033\[[0-9;]*[mK]/, "", clean); if (clean ~ /^\s*Status .*Project\.toml/) next; if (clean ~ /^\s*Manifest\.toml/) next; if (clean ~ /^\s*\[[0-9a-f]{8}\]/) next; if (clean ~ /^\s*[⌃⌅]/) next; if (clean ~ /Packages marked with/) next; print orig }'"""
    s = read(`bash -c $shcmd`, String)
    lines = split(s, '\n')

    # Find the start of the Status blocks and the start of the Testing output
    first_status_idx = findfirst(l -> occursin(r"^\s*Status `.*Project\.toml`", l), lines)
    testing_idx = findfirst(l -> occursin(r"^\s*Testing", l), lines)

    if first_status_idx !== nothing && testing_idx !== nothing && testing_idx > first_status_idx
        # Keep everything before the Status block and everything from Testing onward
        keep = vcat(lines[1:first_status_idx-1], lines[testing_idx:end])
    else
        keep = lines
    end

    println(join(keep, "\n"))
end

quiet_pkg_test()
