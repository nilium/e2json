e2json
======

e2json is an escript to read Erlang term files (`file:consult`) and convert them
to JSON. Each file's JSON is printed separated by a newline, and the final JSON
has a trailing newline ("\n").

If an error occurs, e2json will exit with a status of 1.

Build
-----

    $ rebar3 escriptize

After building, you may want to copy `_build/default/bin/e2json` to
`$HOME/bin/e2json` to install it locally.
