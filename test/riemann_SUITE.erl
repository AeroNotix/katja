% Copyright (c) 2014, Daniel Kempkens <daniel@kempkens.io>
%
% Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted,
% provided that the above copyright notice and this permission notice appear in all copies.
%
% THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
% WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL
% DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
% NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
%
% This suite expects Riemann to be running on 127.0.0.1:5555.
% Since events from <em>katja</em> have to indexed in order to be queried, the following configuration
% options are required:
%   (where (service "katja 1") index)
%   (where (service "katja 2") index)

-module(riemann_SUITE).

-include_lib("common_test/include/ct.hrl").

% Common Test
-export([
  all/0,
  init_per_suite/1,
  init_per_testcase/2,
  end_per_suite/1,
  end_per_testcase/2
]).

% Tests
-export([
  send_event/1,
  send_events/1,
  send_state/1,
  send_states/1,
  send_entities/1,
  send_udp/1,
  send_tcp/1,
  query/1,
  query_event/1
]).

% Common Test

all() ->
  [
    send_event,
    send_events,
    send_state,
    send_states,
    send_entities,
    send_udp,
    send_tcp,
    query,
    query_event
  ].

init_per_suite(Config) ->
  ok = application:start(katja),
  Config.

init_per_testcase(_Test, Config) ->
  {ok, WPid} = katja_writer:start_link(),
  {ok, RPid} = katja_reader:start_link(),
  [{pid_writer, WPid}, {pid_reader, RPid} | Config].

end_per_suite(_Config) ->
  ok = application:stop(katja),
  ok.

end_per_testcase(_Test, Config) ->
  WPid = ?config(pid_writer, Config),
  RPid = ?config(pid_reader, Config),
  ok = katja_writer:stop(WPid),
  ok = katja_reader:stop(RPid),
  ok.

% Tests

send_event(Config) ->
  ok = katja:send_event([{service, "katja 1"}, {metric, 9001}]),
  ok = katja:send_event([{service, <<"katja 1">>}, {metric, 9001}]),
  ok = katja:send_event([{service, ["kat", $j, $a, " 1"]}, {metric, 9001}]),
  Description = lists:flatten(lists:duplicate(4096, "abcd")),
  ok = katja:send_event([{service, "katja 1"}, {metric, 9001}, {description, Description}]),
  ok = katja:send_event([{service, "katja 1"}, {metric, 9002}, {attributes, [{"foo", "bar"}]}]),
  WPid = ?config(pid_writer, Config),
  ok = katja:send_event(WPid, [{service, "katja 1"}, {metric, 9001}]),
  ok = katja:send_event(WPid, [{service, "katja 1"}, {metric, 9001}, {description, Description}]).

send_events(Config) ->
  Description = lists:flatten(lists:duplicate(4096, "abcd")),
  Event = [{service, "katja 1"}, {metric, 9001}, {description, Description}],
  ok = katja:send_events([Event, Event]),
  WPid = ?config(pid_writer, Config),
  ok = katja:send_events(WPid, [Event, Event]).

send_state(Config) ->
  ok = katja:send_state([{service, "katja 1"}, {state, "testing"}]),
  WPid = ?config(pid_writer, Config),
  ok = katja:send_state(WPid, [{service, "katja 1"}, {state, "testing"}]).

send_states(Config) ->
  State = [{service, "katja 1"}, {state, "testing"}],
  ok = katja:send_states([State, State]),
  WPid = ?config(pid_writer, Config),
  ok = katja:send_states(WPid, [State, State]).

send_entities(Config) ->
  Description = lists:flatten(lists:duplicate(4096, "abcd")),
  Event = [{service, "katja 1"}, {metric, 9001}, {description, Description}],
  State = [{service, "katja 1"}, {state, "testing"}],
  ok = katja:send_entities([{events, [Event]}]),
  ok = katja:send_entities([{states, [State]}]),
  ok = katja:send_entities([{states, [State, State]}, {events, [Event, Event]}]),
  WPid = ?config(pid_writer, Config),
  ok = katja:send_entities(WPid, [{states, [State, State]}, {events, [Event, Event]}]).

send_udp(_Config) ->
  ok = katja:send_event(katja_writer, udp, [{service, "katja 1"}, {metric, 9001}]),
  ok = katja:send_state(katja_writer, udp, [{service, "katja 1"}, {state, "testing"}]).

send_tcp(_Config) ->
  ok = katja:send_event(katja_writer, tcp, [{service, "katja 1"}, {metric, 9001}]),
  ok = katja:send_state(katja_writer, tcp, [{service, "katja 1"}, {state, "testing"}]).

query(Config) ->
  RPid = ?config(pid_reader, Config),
  ok = katja:send_event([{service, "katja 2"}, {metric, 9001}, {tags, ["tq1"]}]),
  {ok, [ServiceEvent]} = katja:query("service = \"katja 2\" and tagged \"tq1\""),
  {ok, [ServiceEvent]} = katja:query(RPid, "service = \"katja 2\" and tagged \"tq1\""),
  {metric, 9001} = lists:keyfind(metric, 1, ServiceEvent),
  ok = katja:send_event([{service, "katja 2"}, {metric, 9002}, {tags, ["tq2"]}, {attributes, [{"foo", "bar"}]}]),
  {ok, [AttrEvent]} = katja:query("service = \"katja 2\" and tagged \"tq2\""),
  {ok, [AttrEvent]} = katja:query(RPid, "service = \"katja 2\" and tagged \"tq2\""),
  {attributes, [{"foo", "bar"}]} = lists:keyfind(attributes, 1, AttrEvent),
  ok = katja:send_event([{service, ["kat", [$j], $a, <<" 2">>]}, {metric, 9001}, {tags, [<<"tq3">>]}]),
  {ok, [IolistEvent]} = katja:query("service = \"katja 2\" and tagged \"tq3\""),
  {ok, [IolistEvent]} = katja:query(RPid, "service = \"katja 2\" and tagged \"tq3\""),
  {metric, 9001} = lists:keyfind(metric, 1, IolistEvent).

query_event(Config) ->
  RPid = ?config(pid_reader, Config),
  ok = katja:send_event([{service, "katja 2"}, {metric, 9001}, {tags, ["tqe1"]}]),
  {ok, [ServiceEvent]} = katja:query_event([{service, "katja 2"}, {tags, ["tqe1"]}]),
  {ok, [ServiceEvent]} = katja:query_event(RPid, [{service, "katja 2"}, {tags, ["tqe1"]}]),
  {metric, 9001} = lists:keyfind(metric, 1, ServiceEvent),
  ok = katja:send_event([{service, ["kat", [$j], $a, <<" 2">>]}, {metric, 9001}, {tags, [<<"tq3">>]}]),
  {ok, [IolistEvent]} = katja:query_event([{service, ["kat", [$j], $a, <<" 2">>]}, {metric, 9001}, {tags, ["tq3"]}]),
  {ok, [IolistEvent]} = katja:query_event(RPid, [{service, ["kat", [$j], $a, <<" 2">>]}, {metric, 9001}, {tags, ["tq3"]}]),
  {metric, 9001} = lists:keyfind(metric, 1, IolistEvent),
  ok = katja:send_event([{service, "katja 2"}, {metric, 9002}, {tags, ["tqe4", "tqe5"]}]),
  {ok, [MultipleTags]} = katja:query_event([{service, "katja 2"}, {tags, ["tqe4", "tqe5"]}]),
  {ok, [MultipleTags]} = katja:query_event(RPid, [{service, "katja 2"}, {tags, ["tqe4", "tqe5"]}]),
  {metric, 9002} = lists:keyfind(metric, 1, MultipleTags),
  Description = lists:flatten(lists:duplicate(4096, "abcd")),
  ok = katja:send_event([{service, "katja 2"}, {metric, 9001}, {description, Description}, {tags, ["tqe6"]}]),
  {ok, [LargeEvent]} = katja:query_event([{service, "katja 2"}, {tags, ["tqe6"]}]),
  {ok, [LargeEvent]} = katja:query_event(RPid, [{service, "katja 2"}, {tags, ["tqe6"]}]),
  {description, Description} = lists:keyfind(description, 1, LargeEvent).
