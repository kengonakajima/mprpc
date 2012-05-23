-- test on luvit

local table = require("table")
local uv = require("uv_native")
local net = require("net") -- luvit
local timer = require("timer")


local mprpc = require("./mprpc")
local osxres,osxout
osxres,osxout = pcall( function() return require( "./bindeps/darwin/msgpack" ) end)
amires,amiout = pcall( function() return require( "./bindeps/linux64ami/msgpack") end)
linres,linout = pcall( function() return require( "./bindeps/linux64linode/msgpack") end)

if not osxres and not amires and not linres then
  print("msgpack not found:",osxout,amiout )
  error("fatal")
end
local mp
if osxres then mp = osxout end
if amires then mp = amiout end
if linres then mp = linout end

local svrpc = mprpc.create(net,mp)
assert(svrpc)
local clrpc = mprpc.create(net,mp)
assert(clrpc)

-----------------------

function deepcompare(t1,t2,ignore_mt,eps)
  local ty1 = type(t1)
  local ty2 = type(t2)
  if ty1 ~= ty2 then
    return false
  end    
  -- non-table types can be directly compared
  if ty1 ~= 'table' then
    if ty1 == 'number' and eps then
      return abs(t1-t2) < eps
    end
    return t1 == t2
  end
  -- as well as tables which have the metamethod __eq
  local mt = getmetatable(t1)
  if not ignore_mt and mt and mt.__eq then
    return t1 == t2
  end
  for k1,v1 in pairs(t1) do
    local v2 = t2[k1]
    if v2 == nil or not deepcompare(v1,v2,ignore_mt,eps) then
      return false
    end
  end
  for k2,v2 in pairs(t2) do
    local v1 = t1[k2]
    if v1 == nil or not deepcompare(v1,v2,ignore_mt,eps) then
      return false
    end
  end
  return true
end


-- test data

function iary(n)
  local t={}
  for i=1,n do table.insert( t, i ) end
  return t
end

testTables = {
  {1,iary(100)},
  {1,iary(1000)},
  {1,iary(10000)},
  {2,iary(10000)},
  {4,iary(10000)},
  {6,iary(10000)},      
--  {1,iary(20000)},
--  {1,iary(40000)},
--  {1,iary(80000)},
--  {2,iary(80000)},
--  {4,iary(80000)},    
}
dones = {}

-----------------------
PORT = 56789
listenOK = false
svrpc:createServer( function(cli)
    print("new con")
    cli.doLog = not false
    cli.doSelfTest = true
    cli.autoPollMessage = true

    cli:on("error",function(e)
        print("SV: ERROR!",e)
        error("fatal")
      end)
    cli:call( "test", { n=1, ind=1,total=1,tbl=testTables[1][2]} )
    cli:on("test_done", function(arg)
        print("sv: recv test_done. n:",arg.n)
        assert( deepcompare( arg.tbl, testTables[arg.n][2]), "sv: table mismatch. cnt:", arg.ind )
        if arg.ind < arg.total then
          print("continued..")
          return
        end

        print("sv: compare ok.")
        if arg.n == #testTables then
          print("test done!")
          process.exit(0)
        else
          for i=1,testTables[arg.n+1][1] do
            cli:call( "test", { n=arg.n+1, ind=i,total=testTables[arg.n+1][1], tbl=testTables[arg.n+1][2]} )
          end
          print("sent calls")
        end
      end)
  end):listen( PORT, "127.0.0.1", function(er)
    print("server listen ok" )
    listenOK = true
  end)


timer.setInterval( 10,function()
    if listenOK then
      if not con then
        initClient()
      else
      end
    end
  end)


function initClient()
  con = clrpc:connect( "127.0.0.1", PORT,function(err)
      if err then error(err) end
      print("Connected.. conn:",conn)
    end)
  assert(con)
  con.doLog = not false
  con.doSelfTest = true
  con.autoPollMessage = true
  con:on("error",function(e)
      print("CL: ERROR!",e)
      error("fatal")
    end)  
  con:on("test",function(arg)
      print("cl: recv test. n:", arg.n, "cnt:", arg.ind, "/",arg.total )
      for i=1,arg.total do
        assert( deepcompare( testTables[arg.n][2], arg.tbl ), "cl:table mismatch, cnt:"..i )
      end      
      print("cl: compare OK")
      con:call("test_done",{n=arg.n,tbl=arg.tbl,ind=arg.ind,total=arg.total})
    end)

  print("con init")
end

