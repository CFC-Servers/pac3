return {
    groupName = "Core Utils",

    beforeEach = function( state )
        state.pac_debug = pac.debug
        state.pac_debug_trace = pac.debug_trace
    end,

    afterEach = function( state )
        pac.debug = state.pac_debug
        pac.debug_trace = state.pac_debug_trace
    end,

    cases = {
        -- pac.dprint
        {
            name = "pac.dprint prints nothing if pac.debug is not true",
            func = function()
                pac.debug = false
                pac.debug_trace = false

                local msgStub = stub( _G, "MsgN" )
                local traceStub = stub( debug, "Trace" )

                pac.dprint( "%s", "test" )

                expect( msgStub ).toNot.haveBeenCalled()
                expect( traceStub ).toNot.haveBeenCalled()
            end
        },
        {
            name = "pac.dprint prints to console if pac.debug is true",
            func = function()
                pac.debug = true
                pac.debug_trace = false

                local msgStub = stub( _G, "MsgN" )
                local traceStub = stub( debug, "Trace" )

                pac.dprint( "%s", "test" )

                expect( msgStub ).to.haveBeenCalled()
                expect( traceStub ).toNot.haveBeenCalled()
            end
        },
        {
            name = "pac.dprint prints a debug trace if pac.debug_trace is true",
            func = function()
                pac.debug = true
                pac.debug_trace = true

                local msgStub = stub( _G, "MsgN" )
                local traceStub = stub( debug, "Trace" )

                pac.dprint( "%s", "test" )

                expect( msgStub ).to.haveBeenCalled()
                expect( traceStub ).to.haveBeenCalled()
            end
        },

        -- pac.CallHook
        {
            name = "pac.CallHook calls the given event, prefixed with pac_",
            func = function()
                local func = stub().returns( "test-return" )
                hook.Add( "pac_TestEvent", "pac_CallHook_Test", func )

                pac.CallHook( "TestEvent", "test-arg" )

                expect( func ).to.haveBeenCalled()
            end
        },

        -- pac.AddHook
        {
            name = "pac.AddHook calls hook.Add with the given event, prefixed with pac_",
            func = function()
                local messageStub = stub( pac, "Message" )
                local cb = stub().returns( "hello" )

                pac.AddHook( "TestEvent", "TestID", cb )

                local hookTable = hook.GetTable()
                expect( hookTable.TestEvent ).to.exist()

                local eventFunc = hookTable.TestEvent.pac_TestID
                expect( eventFunc ).to.beA( "function" )
                expect( eventFunc ).to.succeed()
                expect( cb ).to.haveBeenCalled()

                expect( messageStub ).toNot.haveBeenCalled()
            end,

            cleanup = function()
                hook.Remove( "TestEvent", "pac_TestID" )
            end
        },
        {
            name = "pac.AddHook adds a callback that raises a pac message if the given callback errors",
            func = function()
                local messageStub = stub( pac, "Message" )
                local cb = stub().with( error )

                pac.AddHook( "TestEvent", "TestID", cb )

                local hookTable = hook.GetTable()
                expect( hookTable.TestEvent ).to.exist()

                local eventFunc = hookTable.TestEvent.pac_TestID
                expect( eventFunc ).to.beA( "function" )
                expect( eventFunc ).to.succeed()
                expect( cb ).to.haveBeenCalled()

                expect( messageStub ).to.haveBeenCalled()
            end,

            cleanup = function()
                hook.Remove( "TestEvent", "pac_TestID" )
            end
        },

        -- pac.RemoveHook
        {
            name = "pac.RemoveHook removes the given hook, prefixing the ID with pac_",
            func = function()
                hook.Add( "TestEvent", "pac_TestID", stub() )
                expect( hook.GetTable().TestEvent.pac_TestID ).to.exist()

                pac.RemoveHook( "TestEvent", "TestID" )
                expect( hook.GetTable().TestEvent.pac_TestID ).toNot.exist()
            end
        },

        -- pac.RatelimitAlert
        {
            name = "pac.RatelimitAlert sets up necessary tables and sends message on first call",
            func = function()
                local messageStub = stub( pac, "Message" )
                local ply = {}

                pac.RatelimitAlert( ply, "TestID", "TestMessage" )
                expect( ply.pac_ratelimit_alerts ).to.exist()
                expect( ply.pac_ratelimit_alerts.TestID ).to.exist()
                expect( ply.pac_ratelimit_alerts.TestID ).to.beGreaterThan( CurTime() )

                expect( messageStub ).to.haveBeenCalled()
            end
        }
    }
}
