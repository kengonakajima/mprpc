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

rpc:createServer( function(cli)    print("new connection." )
    cli:call("hello", { myname = "steeve" } ) -- RPC call from server    cli:on( "sum", function(arg) -- set the RPC function name      local total = 0      for i,v in ipairs(arg.tosum) do 
        total = total + v 
      end
      cli:call( "addResult", { result= total } ) -- emit result to client    end)  end):listen( 8080, "0.0.0.0", function(e) error(e) end)</pre>  

and client is
<pre>
local conn = rpc:connect( ip_address, 8080, function(e) error(e) end)
conn:on("complete", function()
  -- call and get the result in callback function in the last argument
  conn:call( "sum", { tosum = { 1,5,9,101,48,50,10,12 } }, function(arg)
    print("sum result from server:", arg.result )
    end )
  end )

-- in the game loop
local th = MOAIThread.new()
th:run( function()
  while true do
    conn:poll()
    conn:pollMessage( function() return true end )
  end
  end)
</pre>  
