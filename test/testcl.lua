require("./testcommon")

con = rpc:connect( "127.0.0.1", PORT,function(err)
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
--    con:call("test_done",{n=arg.n,tbl=arg.tbl,ind=arg.ind,total=arg.total})
    con:call("test_done",{n=arg.n,ind=arg.ind,total=arg.total})    
  end)
con:on("all_done",function(arg)
    print("cl: all done!")
    process.exit(0)
  end)




