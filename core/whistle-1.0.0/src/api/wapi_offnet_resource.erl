%%%-------------------------------------------------------------------
%%% @copyright (C) 2011-2015, 2600Hz INC
%%% @doc
%%%
%%% @end
%%% @contributors
%%%   James Aimonetti
%%%   Karl Anderson
%%%-------------------------------------------------------------------
-module(wapi_offnet_resource).

-export([req/1, req_v/1]).
-export([resp/1, resp_v/1]).
-export([publish_req/1, publish_req/2]).
-export([publish_resp/2, publish_resp/3]).
-export([bind_q/2]).
-export([unbind_q/2]).
-export([declare_exchanges/0]).

-include_lib("whistle/include/wh_api.hrl").
-include_lib("whistle/include/wh_amqp.hrl").

%% Offnet Resource Request
-define(OFFNET_RESOURCE_REQ_HEADERS, [<<"Application-Name">>
                                      ,<<"Resource-Type">>
                                      ,<<"To-DID">>
                                     ]).
-define(OPTIONAL_OFFNET_RESOURCE_REQ_HEADERS
        ,[<<"Account-ID">>
          ,<<"Account-Realm">>
          ,<<"Application-Data">>
          ,<<"B-Leg-Events">>
          ,<<"Body">>
          ,<<"Bypass-E164">>
          ,<<"Call-ID">>
          ,<<"Call-ID">>
          ,<<"Control-Queue">>
          ,<<"Custom-Channel-Vars">>
          ,<<"Custom-SIP-Headers">>
          ,<<"Emergency-Caller-ID-Name">>
          ,<<"Emergency-Caller-ID-Number">>
          ,<<"Enable-T38-Fax">>
          ,<<"Enable-T38-Fax-Request">>
          ,<<"Enable-T38-Gateway">>
          ,<<"Enable-T38-Passthrough">>
          ,<<"Fax-Identity-Name">>
          ,<<"Fax-Identity-Number">>
          ,<<"Fax-Timezone">>
          ,<<"Flags">>
          ,<<"Force-Fax">>
          ,<<"Force-Outbound">>
          ,<<"Format-From-URI">>
          ,<<"From-URI-Realm">>
          ,<<"Group-ID">>
          ,<<"Hold-Media">>
          ,<<"Hunt-Account-ID">>
          ,<<"Hunt-Account-ID">>
          ,<<"Ignore-Early-Media">>
          ,<<"Inception">>
          ,<<"Media">>
          ,<<"Message-ID">>
          ,<<"Mode">>
          ,<<"Outbound-Call-ID">>
          ,<<"Outbound-Caller-ID-Name">>
          ,<<"Outbound-Caller-ID-Number">>
          ,<<"Presence-ID">>
          ,<<"Ringback">>
          ,<<"Timeout">>
         ]).
-define(OFFNET_RESOURCE_REQ_VALUES
        ,[{<<"Event-Category">>, <<"resource">>}
          ,{<<"Event-Name">>, <<"offnet_req">>}
          ,{<<"Resource-Type">>, [<<"audio">>, <<"video">>, <<"originate">>, <<"sms">>]}
          ,{<<"Application-Name">>, [<<"park">>, <<"bridge">>, <<"transfer">>
                                     ,<<"fax">>, <<"eavesdrop">>, <<"sms">>
                                    ]}
          ,{<<"Media">>, [<<"process">>, <<"bypass">>, <<"auto">>]}
          %% Eavesdrop
          ,{<<"Mode">>, [<<"full">>     % talk to both sides
                         ,<<"listen">>  % hear both sides - default
                         ,<<"whisper">> % talk to one side
                        ]}
         ]).
-define(OFFNET_RESOURCE_REQ_TYPES
        ,[{<<"Account-ID">>, fun is_binary/1}
          ,{<<"B-Leg-Events">>, fun wapi_dialplan:b_leg_events_v/1}
          ,{<<"Call-ID">>, fun is_binary/1}
          ,{<<"Control-Queue">>, fun is_binary/1}
          ,{<<"Custom-Channel-Vars">>, fun wh_json:is_json_object/1}
          ,{<<"Custom-SIP-Headers">>, fun wh_json:is_json_object/1}
          ,{<<"Enable-T38-Gateway">>, fun is_binary/1}
          ,{<<"Flags">>, fun is_list/1}
          ,{<<"Force-Fax">>, fun wh_util:is_boolean/1}
          ,{<<"Force-Outbound">>, fun wh_util:is_boolean/1}
          ,{<<"To-DID">>, fun is_binary/1}
         ]).

%% Offnet Resource Response
-define(OFFNET_RESOURCE_RESP_HEADERS, [<<"Response-Message">>]).
-define(OPTIONAL_OFFNET_RESOURCE_RESP_HEADERS, [<<"Error-Message">>, <<"Response-Code">>
                                                ,<<"Call-ID">>, <<"Resource-Response">>
                                                ,<<"Control-Queue">>
                                               ]).
-define(OFFNET_RESOURCE_RESP_VALUES, [{<<"Event-Category">>, <<"resource">>}
                                      ,{<<"Event-Name">>, <<"offnet_resp">>}
                                     ]).
-define(OFFNET_RESOURCE_RESP_TYPES, []).

%%--------------------------------------------------------------------
%% @doc Offnet resource request - see wiki
%% Takes proplist, creates JSON string or error
%% @end
%%--------------------------------------------------------------------
-spec req(api_terms()) ->
                 {'ok', iolist()} |
                 {'error', string()}.
req(Prop) when is_list(Prop) ->
    case req_v(Prop) of
        'true' -> wh_api:build_message(Prop, ?OFFNET_RESOURCE_REQ_HEADERS, ?OPTIONAL_OFFNET_RESOURCE_REQ_HEADERS);
        'false' -> {'error', "Proplist failed validation for offnet_resource_req"}
    end;
req(JObj) -> req(wh_json:to_proplist(JObj)).

-spec req_v(api_terms()) -> boolean().
req_v(Prop) when is_list(Prop) ->
    wh_api:validate(Prop, ?OFFNET_RESOURCE_REQ_HEADERS, ?OFFNET_RESOURCE_REQ_VALUES, ?OFFNET_RESOURCE_REQ_TYPES);
req_v(JObj) -> req_v(wh_json:to_proplist(JObj)).

%%--------------------------------------------------------------------
%% @doc Offnet resource request - see wiki
%% Takes proplist, creates JSON string or error
%% @end
%%--------------------------------------------------------------------
-spec resp(api_terms()) ->
                  {'ok', iolist()} |
                  {'error', string()}.
resp(Prop) when is_list(Prop) ->
    case resp_v(Prop) of
        'true' -> wh_api:build_message(Prop, ?OFFNET_RESOURCE_RESP_HEADERS, ?OPTIONAL_OFFNET_RESOURCE_RESP_HEADERS);
        'false' -> {'error', "Proplist failed validation for offnet_resource_resp"}
    end;
resp(JObj) -> resp(wh_json:to_proplist(JObj)).

-spec resp_v(api_terms()) -> boolean().
resp_v(Prop) when is_list(Prop) ->
    wh_api:validate(Prop, ?OFFNET_RESOURCE_RESP_HEADERS, ?OFFNET_RESOURCE_RESP_VALUES, ?OFFNET_RESOURCE_RESP_TYPES);
resp_v(JObj) -> resp_v(wh_json:to_proplist(JObj)).

-spec bind_q(ne_binary(), proplist()) -> 'ok'.
bind_q(Queue, _Props) ->
    amqp_util:bind_q_to_resource(Queue, ?KEY_OFFNET_RESOURCE_REQ).

-spec unbind_q(ne_binary(), wh_proplist()) -> 'ok'.
unbind_q(Queue, _Props) ->
    amqp_util:unbind_q_from_resource(Queue, ?KEY_OFFNET_RESOURCE_REQ).

%%--------------------------------------------------------------------
%% @doc
%% declare the exchanges used by this API
%% @end
%%--------------------------------------------------------------------
-spec declare_exchanges() -> 'ok'.
declare_exchanges() ->
    amqp_util:resource_exchange().

-spec publish_req(api_terms()) -> 'ok'.
-spec publish_req(api_terms(), ne_binary()) -> 'ok'.
publish_req(JObj) ->
    publish_req(JObj, ?DEFAULT_CONTENT_TYPE).
publish_req(Req, ContentType) ->
    {'ok', Payload} = wh_api:prepare_api_payload(Req, ?OFFNET_RESOURCE_REQ_VALUES, fun ?MODULE:req/1),
    amqp_util:offnet_resource_publish(Payload, ContentType).

-spec publish_resp(ne_binary(), api_terms()) -> 'ok'.
-spec publish_resp(ne_binary(), api_terms(), ne_binary()) -> 'ok'.
publish_resp(TargetQ, JObj) -> publish_resp(TargetQ, JObj, ?DEFAULT_CONTENT_TYPE).
publish_resp(TargetQ, Resp, ContentType) ->
    {'ok', Payload} = wh_api:prepare_api_payload(Resp, ?OFFNET_RESOURCE_RESP_VALUES, fun ?MODULE:resp/1),
    amqp_util:targeted_publish(TargetQ, Payload, ContentType).
