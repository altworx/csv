%% @author     Dmitry Kolesnikov, <dmkolesnikov@gmail.com>
%% @copyright  (c) 2012 Dmitry Kolesnikov. All Rights Reserved
%%
%%    Licensed under the 3-clause BSD License (the "License");
%%    you may not use this file except in compliance with the License.
%%    You may obtain a copy of the License at
%%
%%         http://www.opensource.org/licenses/BSD-3-Clause
%%
%%    Unless required by applicable law or agreed to in writing, software
%%    distributed under the License is distributed on an "AS IS" BASIS,
%%    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%    See the License for the specific language governing permissions and
%%    limitations under the License
%%
-module(csv_tests).
-author("Dmitry Kolesnikov <dmkolesnikov@gmail.com>").
-include_lib("eunit/include/eunit.hrl").

test_data() -> [[a, b, c], [1, 2, 3], [d, e, f], [4, 5, 6]].

to_iolist(A) when is_atom(A) ->
  atom_to_binary(A, latin1);
to_iolist(I) when is_integer(I) ->
  integer_to_binary(I);
to_iolist(F) when is_float(F) ->
  float_to_binary(F);
to_iolist(X) when is_list(X); is_binary(X) -> X.

to_bin(X) -> iolist_to_binary(to_iolist(X)).

quote(X) ->
  [$", to_iolist(X), $"].

nl() -> "\n".

crln() -> "\r\n".

fs() -> ",".

data_to_csv(Data) ->
  data_to_csv(Data, fun to_iolist/1).

data_to_csv(Data, F) ->
  data_to_csv(Data, F, nl()).

data_to_csv(Data, F, LS) ->
  data_to_csv(Data, F, fs(), LS).

data_to_csv(Data, F, FS, LS) ->
  iolist_to_binary([[line_to_csv(X, F, FS), LS] || X <- Data]).

line_to_csv([H | T], F, FS) ->
  [F(H) | [[FS | F(X)] || X <- T]].

data_to_result(Data) ->
  [[to_bin(X) || X <- L] || L <- Data].

test_handler({line, L}, Acc) ->
  [lists:reverse(L) | Acc];
test_handler(eof, Acc) ->
  lists:reverse(Acc);
test_handler(_, Acc) -> Acc.

parse(CSV) ->
  csv:parse(CSV, fun test_handler/2, []).

parse_file(F) ->
  csv:parse(F, fun test_handler/2, []).

pparse(CSV) ->
  csv:pparse(CSV, 3, fun test_handler/2, []).

trim_nl(Bin) ->
  Size = byte_size(Bin) - 1,
  Size2 = Size - 1,
  case Bin of
    <<Res:Size2/binary, $\r, $\n>> -> Res;
    <<Res:Size/binary, $\n>> -> Res;
    _ -> Bin
  end.

test_cases() ->
  Data = test_data(),
  Expect = data_to_result(Data),
  CSV = data_to_csv(Data),
  QCSV = data_to_csv(Data, fun quote/1),
  CSV_DOS = data_to_csv(Data, fun to_iolist/1, crln()),
  QCSV_DOS = data_to_csv(Data, fun quote/1, crln()),
  QQCSV = <<"\"foo\"\"bar\",1,\" baz \",\"\"\"\"\n">>,
  QQExp = [[<<"foo\"bar">>, <<"1">>, <<" baz ">>, <<"\"">>]],
  [{"simple", CSV, Expect}
    , {"simple trim nl", trim_nl(CSV), Expect}
    , {"simple dos", CSV_DOS, Expect}
    , {"simple dos trim nl", trim_nl(CSV_DOS), Expect}
    , {"quoted", QCSV, Expect}
    , {"quoted trim nl", trim_nl(QCSV), Expect}
    , {"quoted dos", QCSV_DOS, Expect}
    , {"quoted dos trim nl", trim_nl(QCSV_DOS), Expect}
    , {"quoted escape", QQCSV, QQExp}
  ].

parse_file_1_test() ->
  FileLines = parse_file({"test/FL_insurance_sample.csv", [read]}),
  ?assertEqual(1002, length(FileLines)).

parse_test_() ->
  [{N, ?_assertEqual(Expect, parse(CSV))}
    || {N, CSV, Expect} <- test_cases()].

pparse_test_() ->
  [{N, ?_assertEqual(Expect, pparse(CSV))}
    || {N, CSV, Expect} <- test_cases()].
