%% Copyright 2017, Noel Cower <ncower@gmail.com>.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.

-module(e2json).

-define(PROGRAM, "e2json").

%% API exports
-export([main/1]).

%%====================================================================
%% API functions
%%====================================================================

%% escript Entry point
-spec main(list(string())) -> no_return().
main([]) -> main(["-h"]);
main(["--help"|_]) -> main([]);
main(["-h"|_]) -> % usage
    usage(),
    erlang:halt(2);

main(Files) ->
    Status =
    try consult_to_json(case Files of ["--"|Tail] -> Tail; _ -> Files end) of
        ok -> 0
    catch
        error:{Reason, File} ->
            Desc = case Reason of
                       {_L, _M, _T} -> ["parse error: ", file:format_error(Reason)];
                       enoent -> "no such file";
                       eacces -> "permission denied";
                       eisdir -> "file is a directory";
                       enotdir -> "invalid path";
                       enomem -> "cannot read file - out of memory";
                       _ -> io_lib:format("unrecognized error (~w)", [Reason])
                   end,
            io:format(standard_error, ?PROGRAM ": ~s: ~s~n", [File, Desc]),
            1
    end,
    erlang:halt(Status).

%%====================================================================
%% Internal functions
%%====================================================================

-define(STR(Arg), ??Arg).

-spec usage() -> ok.
usage() ->
    io:put_chars(standard_error,
                 << ?PROGRAM " [-h|--help] [--] FILE [FILE...]\n"
                   "\n"
                   "Reads each FILE as a list of Erlang terms and converts them to JSON.\n"
                   "It will attempt to convert property-list like files to JSON objects\n"
                   "according to jsx mapping rules (plus Unicode lists as strings).\n"
                   "\n"
                   "JSON Mappings\n"
                   "--------------------------------------------------------\n"
                   "(Erlang)                            (JSON)\n"
                   "[{Key, Value}, ...]                 {\"Key\":Value, ...}\n"
                   "[{}]                                {}\n"
                   "[unicode(Value), ...]               \"String\"\n"
                   "[Value, ...]                        [Value, ...]\n"
                   "{Value, ...} (or {})                [Value, ...]\n"
                   "[]                                  []\n"
                   "#{Key => Value}                     {\"Key\":Value}\n"
                   "atom()                              \"atom\"\n"
                   "boolean(), null                     true, false, null\n"
                   "integer(), float()                  number\n"
                 >>).

-spec consult_to_json(list(file:filename_all())) -> ok.
consult_to_json([]) ->
    ok;
consult_to_json([File|Files]) ->
    Data = case consult(case File of "-" -> standard_io; _ -> File end) of
               {ok, Terms} -> Terms;
               {error, Reason} -> error({Reason, File})
           end,
    io:put_chars(<<(jsx:encode(map_json(Data)))/binary, $\n>>),
    consult_to_json(Files).

-spec is_proplist(term()) -> boolean().
is_proplist([]) ->
    false;
is_proplist(List) when is_list(List) ->
    is_proplist1(List);
is_proplist(_) ->
    false.

-spec is_proplist1(term()) -> boolean().
is_proplist1([]) ->
    true;
is_proplist1([{_, _}|Tail]) ->
    is_proplist1(Tail);
is_proplist1(_) ->
    false.

-spec map_json(term()) -> term().
map_json(Atom) when is_atom(Atom) ->
    atom_to_binary(Atom, utf8);
% Special cases supported by jsx
map_json([{}] = Term) -> Term;
map_json([] = Term) -> Term;
% Map proplists and such -- proplist keys are untouched
map_json(Term) when is_list(Term) ->
    case is_proplist(Term) of
        true -> [{K, map_json(V)} || {K, V} <- Term];
        false ->
            case io_lib:printable_unicode_list(Term) of
                true -> list_to_binary(Term);
                false -> [map_json(E) || E <- Term]
            end
    end;
map_json(Term) when is_tuple(Term) ->
    [map_json(T) || T <- tuple_to_list(Term)];
map_json(Term) ->
    Term.

-spec consult(file:filename_all()) -> term();
             (standard_io) -> term().
consult(standard_io) ->
    consult_stdin();
consult(File) when is_list(File) ->
    file:consult(File).

-spec consult_stdin() -> no_return() | term().
consult_stdin() ->
    consult_stdin(io:read(standard_io, '', 1), []).

-spec consult_stdin({ok, term(), term()}, list()) -> term();
                   ({eof, term()}, list()) -> term();
                   ({error, term()}, list()) -> no_return();
                   ({error, term(), term()}, list()) -> no_return().
consult_stdin({ok, Term, Loc}, Acc) ->
    consult_stdin(io:read(standard_io, '', Loc), [Term|Acc]);
consult_stdin(eof, Acc) ->
    {ok, lists:reverse(Acc)};
consult_stdin({error, Info, _Location}, _Acc) ->
    {error, Info};
consult_stdin({error, Reason}, _Acc) ->
    {error, Reason}.
