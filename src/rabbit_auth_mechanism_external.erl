%%   The contents of this file are subject to the Mozilla Public License
%%   Version 1.1 (the "License"); you may not use this file except in
%%   compliance with the License. You may obtain a copy of the License at
%%   http://www.mozilla.org/MPL/
%%
%%   Software distributed under the License is distributed on an "AS IS"
%%   basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
%%   License for the specific language governing rights and limitations
%%   under the License.
%%
%%   The Original Code is RabbitMQ.
%%
%%   The Initial Developers of the Original Code are LShift Ltd,
%%   Cohesive Financial Technologies LLC, and Rabbit Technologies Ltd.
%%
%%   Portions created before 22-Nov-2008 00:00:00 GMT by LShift Ltd,
%%   Cohesive Financial Technologies LLC, or Rabbit Technologies Ltd
%%   are Copyright (C) 2007-2008 LShift Ltd, Cohesive Financial
%%   Technologies LLC, and Rabbit Technologies Ltd.
%%
%%   Portions created by LShift Ltd are Copyright (C) 2007-2010 LShift
%%   Ltd. Portions created by Cohesive Financial Technologies LLC are
%%   Copyright (C) 2007-2010 Cohesive Financial Technologies
%%   LLC. Portions created by Rabbit Technologies Ltd are Copyright
%%   (C) 2007-2010 Rabbit Technologies Ltd.
%%
%%   All Rights Reserved.
%%
%%   Contributor(s): ______________________________________.
%%

-module(rabbit_auth_mechanism_external).
-include("rabbit.hrl").

-behaviour(rabbit_auth_mechanism).

-export([description/0, should_offer/1, init/1, handle_response/2]).

-include("rabbit_auth_mechanism_spec.hrl").

-include_lib("public_key/include/public_key.hrl").

-rabbit_boot_step({?MODULE,
                   [{description, "auth mechanism external"},
                    {mfa,         {rabbit_registry, register,
                                   [auth_mechanism, <<"EXTERNAL">>, ?MODULE]}},
                    {requires,    rabbit_registry},
                    {enables,     kernel_ready}]}).

-record(state, {username = undefined}).

%% SASL EXTERNAL. SASL says EXTERNAL means "use credentials
%% established by means external to the mechanism". We define that to
%% mean the peer certificate's subject's CN.

description() ->
    [{name, <<"EXTERNAL">>},
     {description, <<"SASL EXTERNAL authentication mechanism">>}].

%% TODO: safety check, don't offer unless verify_peer set
should_offer(Sock) ->
    case peer_subject(Sock) of
        none -> false;
        _    -> true
    end.

init(Sock) ->
    {ok, C} = rabbit_net:peercert(Sock),
    CN = case rabbit_ssl:peer_cert_subject_item(C, ?'id-at-commonName') of
             not_found -> not_found;
             CN0       -> list_to_binary(CN0)
         end,
    #state{username = CN}.

handle_response(_Response, #state{username = Username}) ->
    case Username of
        not_found -> {refused, Username};
        _         -> rabbit_access_control:lookup_user(Username)
    end.

%%--------------------------------------------------------------------------

peer_subject(Sock) ->
    case rabbit_net:peercert(Sock) of
        nossl                -> none;
        {error, no_peercert} -> none;
        {ok, C}              -> rabbit_ssl:peer_cert_subject(C)
    end.
