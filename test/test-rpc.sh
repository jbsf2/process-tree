#!/bin/bash

set -e

cleanup() {
    kill $beam_a_pid
}

# 1 running beam: Beam A
elixir --sname beam_a@localhost --cookie secret -S mix run --no-halt &
beam_a_pid=$!
trap cleanup EXIT

# 2nd beam starts, connects to Beam A and runs ProcessTree.get()
code="""
Node.spawn_link(:beam_a@localhost, fn -> dbg(ProcessTree.get(:some_key)) end) |> dbg()
"""
elixir --sname beam_b@localhost --cookie secret -S mix run --eval "$code"
