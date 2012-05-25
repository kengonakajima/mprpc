-- test on luvit

local table = require("table")
local uv = require("uv_native")
local net = require("net") -- luvit
local timer = require("timer")


local mprpc = require("../mprpc")
local osxres,osxout
osxres,osxout = pcall( function() return require( "../bindeps/darwin/msgpack" ) end)
amires,amiout = pcall( function() return require( "../bindeps/linux64ami/msgpack") end)
linres,linout = pcall( function() return require( "../bindeps/linux64linode/msgpack") end)

if not osxres and not amires and not linres then
  print("msgpack not found:",osxout,amiout )
  error("fatal")
end
local mp
if osxres then mp = osxout end
if amires then mp = amiout end
if linres then mp = linout end

_G.rpc = mprpc.create(net,mp)




-----------------------

function _G.deepcompare(t1,t2,ignore_mt,eps)
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

_G.testTables = {
  {1,iary(100)},
  {1,iary(1000)},
  {1,iary(10000)},
  {2,iary(10000)},
  {4,iary(10000)},
  {5,iary(10000)},
  {6,iary(10000)},      
  {7,iary(10000)},        
  {1,iary(20000)},
  {1,iary(40000)},
  {1,iary(80000)},
  {2,iary(80000)},
  {4,iary(80000)},    
}

_G.PORT = 56789