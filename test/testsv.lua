require("./testcommon")


-----------------------

rpc:createServer( function(cli)
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
--        assert( deepcompare( arg.tbl, testTables[arg.n][2]), "sv: table mismatch. cnt:", arg.ind )
        if arg.ind < arg.total then
          print("continued..")
          return
        end

        print("sv: compare ok.")
        if arg.n == #testTables then
          print("test all done!")
          cli:call("all_done",{})
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

