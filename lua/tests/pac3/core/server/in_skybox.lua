return {
    groupName = "In Skybox",
    cases = {
        {
            name = "InSkybox creates the proper hooks and timers",
            func = function()
                expect( hook.GetTable().InitPostEntity.pac_get_sky_camera ).to.exist()
                expect( timer.Exists( "pac_in_skybox" ) ).to.beTrue()
            end
        },
        {
            name = "InSkybox sets the appropriate boolean on entities that are in the skybox and removes it from those that aren't",
            async = true,
            timeout = 1.5,
            func = function()
                local ent = {
                    SetNW2Bool = stub().with( function( _, key, value )
                        expect( key ).to.equal( "pac_in_skybox" )
                        expect( value ).to.beTrue()
                    end ),
                    IsValid = function() return true end
                }

                -- Pretend our entity is in the skybox
                local findInPVS = stub( ents, "FindInPVS" ).returns( { ent } )

                -- Wait for the the in_skybox timer to find and set the NW2Bool on our ent
                timer.Simple( 0.5, function()
                    expect( ent.SetNW2Bool ).was.called()

                    -- Restore the original FindInPVS function (so our ent isn't found anymore)
                    findInPVS:Restore()

                    -- Make a new SetNW2 stub that expects it to be called with false (since our ent isn't in the skybox anymore)
                    ent.SetNW2Bool = stub().with( function( _, key, value )
                        expect( key ).to.equal( "pac_in_skybox" )
                        expect( value ).to.beFalse()
                    end )

                    -- Wait for the in_skybox timer to run one more time
                    timer.Simple( 0.5, function()
                        expect( ent.SetNW2Bool ).was.called()
                        done()
                    end )
                end )
            end
        }
    }
}
