local string = require('string')
local os = require("os")

local strdump = function(s)
  local out = ""
  
  for i=1,#s do
    if i>80 and i < #s-4 then
      if (i%1000)==0 then
        out = out .. "."
      end
    else
      out = out .. s:byte( i ) .. " "
    end
  end
  return out
end

-- copied from penlight. 
-- true if identical
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


function mprpc_init_conn(conn)
  conn.super_on = conn.on -- replace superclass "on" func..
  conn.super_emit = conn.emit
  conn.doLog = false

  conn.packetID = 0
  
  conn.roundTripFuncID = 1
  
  conn.recvbuf = ""
  conn.log = function(self,...)
    if self.doLog then print(...) end
  end

  conn.doSelfTest = false

  conn.packetID = 0
  conn.waitfuncs = {}
  
  conn.rpcfuncs = {}
  conn.on = function(self,evname,fn)
    if evname == "data" then
      error("MP need data event!")
    elseif evname == "complete" or evname == "end" then
      self:super_on(evname,fn)
      self:log("added default callback:", evname)
    else -- rpcs
      self.rpcfuncs[evname] = fn
      self:log("added rpc func:", evname )
    end
  end
  -- cb can be nil
  conn.emit = function(self,meth,arg,cb)
    if type(arg) ~= "table" then 
      return self:super_emit(meth,arg) -- fallback to super class' emit function
    end
    if type(meth) ~= "string" then error("method name required") end
    
    local t = { 1, meth, arg }
    
    if cb then
      t[4] = self.roundTripFuncID
      self.waitfuncs[ self.roundTripFuncID ] = cb
      self.roundTripFuncID = self.roundTripFuncID + 1
    end
    if self.last_call_id and ( meth == self.last_call_method .. "Result" or meth == self.last_call_method .. "_result" )  then
      t[4] = self.last_call_id 
      self.last_call_id = nil
    end

--    print("emit meth:", meth )
    -- number, table, number, table, ..... number=length of the following packed table data.
    --                  local ahost = MOAISim.getDeviceTime()
    local packed = self.rpc.mp.pack(t)
    --                  local ahoet = MOAISim.getDeviceTime()
    --                  print("packtime:", (ahoet-ahost) )

    if self.doSelfTest then
      local nread,resulttbl = self.rpc.mp.unpack(packed)
      local isok = deepcompare(resulttbl,t)
      assert(isok, "deepcompare")
    end
    
    local payloadlen = #packed
    local lenpacked = self.rpc.mp.pack(payloadlen) 
    local tosend = lenpacked .. packed

    self.packetID = self.packetID + 1
    self:log("sending actual data bytes:", #tosend, "payloadlen:", payloadlen, "packetID:", self.packetID )
    
    self:write( tosend, nil )
  end

  conn:super_on("data", function (chunk)
      conn.lastAliveAt = os.time()
      conn.recvbuf = conn.recvbuf .. chunk
      conn:log("data. chunklen:", string.len(chunk), " recvbuf:", string.len(conn.recvbuf), "alive:", conn.lastAliveAt )
      if conn.autoPollMessage then
        conn:pollMessage()
      end                            
    end)
  function conn:pollMessage(continueFunc )      
    local offset=1

    while true do
      if continueFunc and continueFunc() == false then
        break
      end         
      if #conn.recvbuf == 0 then
        break
      end

      local pcallret, nread,res
      pcallret, nread,res = pcall( function()
          return conn.rpc.mp.unpack(string.sub(conn.recvbuf,offset,offset+8) ) -- 8 bytes are enough for payloadlen
        end )
      if not pcallret or not nread then
        --            print("need number first!: ",pcallret, nread,res )
        break
      end

      local payloadlen = res
      local bufleft = ( #conn.recvbuf - offset + 1 ) - nread

      self.packetID = self.packetID + 1
      self:log("mprpc: offset:", offset, "payload len:", payloadlen, "envelopelen:", nread, "#recvbuf:", #conn.recvbuf, "bufleft:",bufleft, "packetID:", self.packetID )

      
      if bufleft < payloadlen then
        self:log("wantread!")
        break
      end

      offset = offset + nread
      local toread = string.sub(conn.recvbuf,offset,offset+payloadlen)  -- should never throws exception
      
      nread,res = conn.rpc.mp.unpack(toread)            

      if type(res) ~= "table" or res[1] ~= 1 or type(res[2]) ~= "string" or type(res[3]) ~= "table" then
        self:log("rpc format error. offset:", offset, "res:", res, "data:", strdump(toread) )
        return false
      else
        local meth = res[2]
        local arg = res[3]
        local call_id = res[4]
--        print("recv meth:", meth )
        
        local f = self.rpcfuncs[meth]
        if not f and not self.waitfuncs[call_id] then
          self:log("receiver func not found:",meth )
        else
          if call_id then
            local wf = self.waitfuncs[call_id]
            if wf then
              self:log( "waitfunc found. call_id:", call_id )
              wf(arg)
              self.waitfuncs[call_id]=nil
            else
              self:log( "waitfunc not found. call_id:", call_id )
              self.last_call_id = call_id
              self.last_call_method = meth
              self:log("last_call_id set:", self.last_call_id)
              f(arg)
            end
          else
            f( arg )
          end                                     
        end
      end
      offset = offset + nread
    end
    if offset > 1 then
      self.recvbuf = string.sub( self.recvbuf, offset)
    end
    return true
  end
end

function mprpc_createServer(self,ip,port,cb)
  assert(self.net and self.mp )
  local sv = self.net.createServer( function(client)
      client.lastAliveAt = os.time()
      mprpc_init_conn(client)
      client.rpc = self
      cb(client)
    end)
  sv:listen( port, ip, function(err)
      print("tcp listen at:", ip, port,err )
    end)
  
  sv:on("error", function (err)  p("ERROR", err) end)

  return sv
end

function mprpc_connect(self,ip,port)
  assert(self.net and self.mp )   
  local conn = self.net.new()
  mprpc_init_conn(conn)
  conn.rpc = self
  conn:connect(ip,port)
  conn:read_start()

  return conn
end

function mprpc_create_with_net_and_mp(net,mp)
  assert(mp and mp.pack and mp.unpack)
  local mod = {}
  mod.net = net
  mod.mp = mp
  mod.createServer = mprpc_createServer
  mod.connect = mprpc_connect
  return mod
end

mprpc = {
  create = mprpc_create_with_net_and_mp
}

return mprpc