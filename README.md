lua-mprpc
====
lua-mprpc is a small RPC stub for both [lua-msgpack](https://github.com/kengonakajima/lua-msgpack) and [lua-msgpack-native](https://github.com/kengonakajima/lua-msgpack-native) .

It provides some simple RPC syntax similar to Socket.io .

Usable under luvit and MoaiSDK environment.


Adder server/client for luvit
====
<pre>
local net = require("net") -- from luvit
local msgpack = require("msgpack") -- from lua-msgpack or lua-msgpack-native

local mprpc = require("mprpc") -- this repository provides this

local rpc = mprpc.create(net,msgpack)

rpc:createServer( "0.0.0.0", 8080, function(cli)    print("new connection." )
    cli:emit("hello", { myname = "steeve" } ) -- RPC call from server    cli:on( "sum", function(arg) -- set the RPC function name      local total = 0      for i,v in ipairs(arg.tosum) do 
        total = total + v 
      end
      cli:emit( "addResult", { result= total } ) -- emit result to client    end)  end)</pre>  

and client is
<pre>
local conn = rpc:connect( ip_address, 8080 )
conn:on("complete", function()
  -- call and get the result in callback function in the last argument
  conn:emit( "sum", { tosum = { 1,5,9,101,48,50,10,12 } }, function(arg)
    print("sum result from server:", arg.result )
    end )
  end )
</pre>  
