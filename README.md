# ProcessTree

<!-- MDOC -->
<!-- INCLUDE -->

`ProcessTree` is a module for navigating the process ancestry hierachy.

## Motivation

`ProcessTree` was originally developed as a tool for avoiding global state & global references in Elixir applications. 

It's common in Elixir apps to rely on global references or global variables for locating application services or configuration parameters. This presents problems when we test our code. We need to work around our global data, for example by setting/resetting environment variables and using `async: false`.

`ProcessTree` solves the problem by localizing data to a particular branch of the Elixir process tree. When testing with ExUnit, each ExUnit test process, and all processes spawned by the test process, can use `get/1` or `get/2` to see their own private copy of the data of interest. 

## Example use case

[Customizing environment variables](./examples/environment-variable-example.md) in ExUnit tests while preserving `async: true`.


## Smoothing over process ancestry complications

OTP 25 introduced the ability to find the parent of a process via `Process.info/2`. Prior to OTP 25, it was possible to find the parent of a process only for specific processes such as Task, GenServer, Agent, and Superivsor.

Even under OTP 25+, `Process.info/2` is only useful for processes that are still alive, meaning it can't be used, for example, to find the grandparent of a process if the parent of the process has died. 

`ProcessTree` accounts for all complicating factors. Each of the functions exposed by `ProcessTree` will return the most complete answer possible, regardless of how the processes in the ancestry hierarchy are started or managed, regardless of which OTP version is in use, and so on.

Put another way, `ProcessTree` is a "no-judgments zone". If you're following recommended guidelines for starting/running Elixir processes, `ProcessTree` will almost certainly meet your needs. But even in situations typically considered inadvisable or even crazy, `ProcessTree` functions will do their very best to provide meaningful answers.















