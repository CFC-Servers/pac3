return {
    groupName = "Effects",
    cases = {
        {
            name = "Creates all tables and receivers",
            func = function()
                expect( pac.EffectsBlackList ).to.exist()
                expect( pac_loaded_particle_effects ).to.exist()

                expect( net.Receivers["pac_request_precache"] ).to.exist()

                expect( pac.PrecacheEffect ).to.exist()
            end
        },

        -- pac.PrecacheEffect
        {
            name = "pac.PrecacheEffect precaches the given effect and broadcasts it to all clients",
            func = function()
                local precacheStub = stub( _G, "PrecacheParticleSystem" ).with( function( name )
                    expect( name ).to.equal( "test_effect" )
                end )

                local startStub = stub( net, "Start" ).with( function( name )
                    expect( name ).to.equal( "pac_effect_precached" )
                end )

                local writeStringStub = stub( net, "WriteString" ).with( function( name )
                    expect( name ).to.equal( "test_effect" )
                end )

                local broadcastStub = stub( net, "Broadcast" )

                pac.PrecacheEffect( "test_effect" )
                expect( precacheStub ).was.called()
                expect( startStub ).was.called()
                expect( writeStringStub ).was.called()
                expect( broadcastStub ).was.called()
            end
        },

        -- pac_request_precache receiver
        {
            name = "pac_request_precache receiver queues and calls pac.PrecacheEffect on the given effect for the given player",
            func = function()
            end
        },
        {
            name = "pac_request_precache receiver does not accept more than 50 queued effects for a single player",
            func = function()
            end
        },
        {
            name = "pac_request_precache receiver does not accept blacklisted effects",
            func = function()
            end
        },
    }
}
