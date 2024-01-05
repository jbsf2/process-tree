# ProcessTree

<!-- MDOC -->
<!-- INCLUDE -->

ProcessTree is a module for avoiding global variables & gloabal references in Elixir applications.

## Motivation / use case

It's common in Elixir apps to rely on global references or global variables for locating application
services or configuration parameters. This presents problems when we test our code. We need to work
around our global data, for example by mocking GenServers, or by setting/resetting environment variables 
and using `async: false`.

ProcessTree solves the problem by localizing data to a particular branch of the Elixir process tree.
When testing with ExUnit, each ExUnit test process, and all processes spawned by the test process, see
their own private copy of the data of interest. 

## How it works

ProcessTree reads data from the process dictionary. get/1 and get/2 first look for data in the dictionary
of the calling process. If no value is found, get/1 and get/2 move up the process ancestry hierarchy, 
looking in the dictionaries of the calling process' parent, grandparent, and so on, until a value is found or 
until there are no more ancestor processes to check.

As an optimization, if get/1 and get/2 find a value up the process hierarchy, the value is then cached in 
the process dictionary of the calling process.

get/2 provides a hook for using a default value as a fallback in case no value is found in the process hierarchy. 


## An example

Suppose our application has the concept of a "cutoff date", such that our code behaves differently before 
the cutoff date than after. We might normally expose the cutoff date as an Application environment variable,
using `async: false` when changing the cutoff date in our tests.


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `process_tree` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:process_tree, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/process_tree>.

