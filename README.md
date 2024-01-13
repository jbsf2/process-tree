# ProcessTree

<!-- MDOC -->
<!-- INCLUDE -->

`ProcessTree` is a module for navigating the Elixir process ancestry hierachy.

## Motivation

`ProcessTree` was originally developed as a tool for avoiding global state & global references in Elixir applications. 

It's common in Elixir apps to rely on global references or global variables for locating application services or configuration parameters. This presents problems when we test our code. We need to work around our global data, for example by setting/resetting environment variables and using `async: false`.

`ProcessTree` solves the problem by localizing data to a particular branch of the Elixir process tree. When testing with ExUnit, each ExUnit test process, and all processes spawned by the test process, can use `get/1` or `get/2` to see their own private copy of the data of interest.

## How to use `get()`

`get/1` and `get/2` can be used to make child processes "see" values stored in the process dictionaries of their ancestor processes. This is useful, for example, in ExUnit tests that spawn processes, such as tests that start LiveViews and GenServers.

To make data visible to child processes via `get/1` and `get/2`, we first put the data into the process dictionary of an ancestor process - in this case, an ExUnit test pid:

``` elixir
test "some test that starts a GenServer" do
  # ...
  # add the data of interest to the process dictionary of the test pid
  Process.put(:some_key, some_value)

  # The GenServer process started here can use ProcessTree.get() to see
  # the value we've bound to :some_key
  server = MyGenserver.start_link()
  # ...
end
```

## Example use case

[Customizing environment variables](./examples/environment-variable-example.md) in ExUnit tests while preserving `async: true`.


## Smoothing over process ancestry complications

OTP 25 [introduced](https://github.com/erlang/otp/pull/5768) the ability to find the parent of a process via `Process.info/2`. Prior to OTP 25, it was possible to find the parent of a process only for specific processes such as Task, GenServer, Agent, and Superivsor.

Even under OTP 25+, `Process.info/2` is only useful for processes that are still alive, meaning it can't be used, for example, to find the grandparent of a process if the parent of the process has died. 

`ProcessTree` accounts for all complicating factors. Each of the functions exposed by `ProcessTree` will return the most complete answer possible, regardless of how the processes in the ancestry hierarchy are started or managed, regardless of which OTP version is in use, and so on.

Put another way, `ProcessTree` is a "no-judgments zone". If you're following recommended guidelines for starting/running Elixir processes, `ProcessTree` will almost certainly meet your needs. But even in situations typically considered inadvisable or totally crazy, `ProcessTree` will do its very best to provide meaningful answers.















