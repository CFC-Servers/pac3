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

                expect( msgStub ).wasNot.called()
                expect( traceStub ).wasNot.called()
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

                expect( msgStub ).wasNot.called()
                expect( traceStub ).wasNot.called()
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

                expect( msgStub ).was.called()
                expect( traceStub ).was.called()
            end
        },

        -- pac.CallHook
        {
            name = "pac.CallHook calls the given event, prefixed with pac_",
            func = function()
                local func = stub().returns( "test-return" )
                hook.Add( "pac_TestEvent", "pac_CallHook_Test", func )

                pac.CallHook( "TestEvent", "test-arg" )

                expect( func ).was.called()
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
                expect( cb ).was.called()

                expect( messageStub ).wasNot.called()
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
                expect( cb ).was.called()

                expect( messageStub ).was.called()
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
                local ply = {}
                local messageStub = stub( pac, "Message" )

                pac.RatelimitAlert( ply, "TestID", "TestMessage" )
                expect( ply.pac_ratelimit_alerts ).to.exist()
                expect( ply.pac_ratelimit_alerts.TestID ).to.exist()
                expect( ply.pac_ratelimit_alerts.TestID ).to.beGreaterThan( CurTime() )

                expect( messageStub ).was.called()
            end
        },
        {
            name = "pac.RatelimitAlert does not send a message if still waiting",
            func = function()
                local messageStub = stub( pac, "Message" )
                local ply = { pac_ratelimit_alerts = { TestID = math.huge } }

                pac.RatelimitAlert( ply, "TestID", "TestMessage" )

                expect( messageStub ).was.called()
            end
        },
        {
            name = "pac.RatelimitAlert does not send a message if the given message is not a string or table",
            func = function()
                local ply = { pac_ratelimit_alerts = { TestID = 0 } }
                local messageStub = stub( pac, "Message" )

                pac.RatelimitAlert( ply, "TestID", 69420 )

                expect( messageStub ).wasNot.called()
            end
        },
        {
            name = "pac.RatelimitAlert sends a message if the given message is a table",
            func = function()
                local ply = { pac_ratelimit_alerts = { TestID = 0 } }
                local messageStub = stub( pac, "Message" ).with( function( first, second )
                    expect( first ).to.equal( "Test" )
                    expect( second ).to.equal( "Message" )
                end )

                pac.RatelimitAlert( ply, "TestID", { "Test", "Message" } )

                expect( messageStub ).was.called()
            end
        },

        -- pac.RatelimitPlayer
        {
            name = "pac.RatelimitPlayer sets up necessary tables and returns true on first call",
            func = function()
                local ply = {}
                local messageStub = stub( pac, "Message" )

                expect( pac.RatelimitPlayer( ply, "TestName", 1, 1, "TestMessage" ) ).to.beTrue()

                expect( ply.pac_ratelimit_TestName ).to.exist()
                expect( ply.pac_ratelimit_TestName ).to.equal( 0 )

                expect( ply.pac_ratelimit_check_TestName ).to.exist()
                expect( ply.pac_ratelimit_check_TestName ).to.equal( CurTime() )

                expect( messageStub ).wasNot.called()
            end
        },
        {
            name = "pac.RatelimitPlayer returns false if no budget is available",
            func = function()
                local ply = {
                    pac_ratelimit_TestName = 0,
                    pac_ratelimit_check_TestName = CurTime(),
                    pac_ratelimit_alerts = { TestName = 0 }
                }

                local messageStub = stub( pac, "Message" )

                expect( pac.RatelimitPlayer( ply, "TestName", 1, 1, "TestMessage" ) ).to.beFalse()
                expect( ply.pac_ratelimit_TestName ).to.equal( 0 )

                expect( messageStub ).was.called()
            end
        },
        {
            name = "pac.RatelimitPlayer returns false if no budget is available, and then true when the refill rate grants more budget",
            async = true,
            timeout = 2,
            func = function()
                local ply = {
                    pac_ratelimit_TestName = 0,
                    pac_ratelimit_check_TestName = CurTime(),
                    pac_ratelimit_alerts = { TestName = 0 }
                }

                stub( pac, "Message" )

                expect( pac.RatelimitPlayer( ply, "TestName", 1, 1, "TestMessage" ) ).to.beFalse()
                expect( ply.pac_ratelimit_TestName ).to.equal( 0 )

                timer.Simple( 1, function()
                    expect( pac.RatelimitPlayer( ply, "TestName", 1, 1, "TestMessage" ) ).to.beTrue()
                    expect( ply.pac_ratelimit_TestName ).to.equal( 0 )
                    done()
                end )
            end
        },

        -- pac.GetRateLimitPlayerBuffer
        {
            name = "pac.GetRateLimitPlayerBuffer returns the correct rate limit buffer",
            func = function()
                local ply = { pac_ratelimit_TestName = 5 }
                expect( pac.GetRateLimitPlayerBuffer( ply, "TestName" ) ).to.equal( 5 )
            end
        },
        {
            name = "pac.GetRateLimitPlayerBuffer returns 0 if the requested buffer does not exist",
            func = function()
                local ply = {}
                expect( pac.GetRateLimitPlayerBuffer( ply, "TestName" ) ).to.equal( 0 )
            end
        },
    }
}
