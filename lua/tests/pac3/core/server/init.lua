return {
    groupName = "Init",
    cases = {
        {
            name = "Init creates all required tables and convars",
            func = function()
                expect( pac ).to.exist()
                expect( pac.Parts ).to.exist()
                expect( pac.Errors ).to.exist()
                expect( pac.resource ).to.exist()

                expect( GetConVar( "has_pac3" ) ).to.exist()
                expect( GetConVar( "pac_allow_blood_color" ) ).to.exist()
                expect( GetConVar( "pac_allow_mdl" ) ).to.exist()
                expect( GetConVar( "pac_allow_mdl_entity" ) ).to.exist()
            end
        }
    }
}
