{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2020 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{             Distributed under GNU AGPL v3.0 with Commons Clause              }
{                                                                              }
{   This program is free software: you can redistribute it and/or modify       }
{   it under the terms of the GNU Affero General Public License as published   }
{   by the Free Software Foundation, either version 3 of the License, or       }
{   (at your option) any later version.                                        }
{                                                                              }
{   This program is distributed in the hope that it will be useful,            }
{   but WITHOUT ANY WARRANTY; without even the implied warranty of             }
{   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the              }
{   GNU Affero General Public License for more details.                        }
{                                                                              }
{   You should have received a copy of the GNU Affero General Public License   }
{   along with this program.  If not, see <https://www.gnu.org/licenses/>      }
{                                                                              }
{                  https://geth.ethereum.org/docs/rpc/pubsub                   }
{                                                                              }
{******************************************************************************}

unit web3.eth.pubsub;

{$I web3.inc}

interface

uses
  // Delphi
  System.JSON,
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.types;

type
  TSubscription = (
    logs,
    newHeads,
    newPendingTransactions,
    syncing
  );

procedure subscribe(
  client      : IWeb3Ex;
  subscription: TSubscription;
  callback    : TAsyncString;     // one-time callback (subscribed, or a JSON-RPC error)
  notification: TAsyncJsonObject; // continuous notifications (or a JSON-RPC error)
  onError     : TAsyncError;      // non-JSON-RPC-error handler (probably a socket error)
  onDisconnect: TProc);           // connection closed

procedure unsubscribe(
  client   : IWeb3Ex;
  const sub: string;         // as returned by the eth_subscribe callback
  callback : TAsyncBoolean); // true if successful, otherwise false

function blockNumber(notification: TJsonObject): BigInteger;

implementation

uses
  // Delphi
  System.TypInfo,
  // web3
  web3.json;

{---------------------------- TSubscriptionHelper -----------------------------}

type
  TSubscriptionHelper = record helper for TSubscription
  public
    function ToString: string;
  end;

function TSubscriptionHelper.ToString: string;
begin
  Result := GetEnumName(TypeInfo(TSubscription), Ord(Self));
end;

{---------------------------------- globals -----------------------------------}

procedure subscribe(
  client      : IWeb3Ex;
  subscription: TSubscription;
  callback    : TAsyncString;
  notification: TAsyncJsonObject;
  onError     : TAsyncError;
  onDisconnect: TProc);
begin
  client.OnError(onError);
  client.OnDisconnect(onDisconnect);

  client.Call('eth_subscribe', [subscription.ToString], procedure(resp: TJsonObject; err: IError)
  begin
    if Assigned(err) then
    begin
      callback('', err);
      EXIT;
    end;

    const result = web3.json.getPropAsStr(resp, 'result');
    callback(result, nil);

    client.Subscribe(result, notification);
  end);
end;

procedure unsubscribe(
  client   : IWeb3Ex;
  const sub: string;
  callback : TAsyncBoolean);
begin
  client.Call('eth_unsubscribe', [sub], procedure(resp: TJsonObject; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(False, err);
      EXIT;
    end;

    const result = web3.json.getPropAsStr(resp, 'result').Equals('true');
    callback(result, nil);

    if result then
      client.Unsubscribe(sub);
  end);
end;

function blockNumber(notification: TJsonObject): BigInteger;
begin
  Result := 0;
  const params = web3.json.getPropAsObj(notification, 'params');
  if Assigned(params) then
  begin
    const _result = web3.json.getPropAsObj(params, 'result');
    if Assigned(_result) then
      Result := web3.json.getPropAsStr(_result, 'number');
  end;
end;

end.
