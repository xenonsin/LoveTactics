-- The HIRING HALL ROSTER: thirty-eight named heroes, one per discipline, each carrying a bound relic.
--
-- This file is the contract for the whole set, and it exists because the individual pieces already pass
-- every generic contract in the suite while still being wrong in the ways that matter here. Three of
-- those were found by hand during the build and are pinned so they cannot come back:
--
--   * A KIT CAN NAME AN ITEM THAT DOES NOT EXIST. Nothing validates a blueprint's startingItems until
--     something instantiates it, and a hall body may go a long time without being hired. Three bad ids
--     shipped in one kit before this case existed.
--   * A RELIC CAN DRIFT OFF ITS BEARER. The relic is the reason the hero is on the roster; a hero whose
--     grid has lost it is a body with somebody else's stat line.
--   * A DISCIPLINE CAN END UP WITH TWO HEROES, OR NONE. The roster is one per discipline by definition,
--     and the failure mode is silent -- a duplicate simply means one discipline is unrepresented.
--
-- It also pins the two rules the design was argued down to: every relic is BOUND (so it can never be
-- moved, stowed, sold or stolen), and every relic is a BUILD-AROUND -- its discipline stocks other
-- items, so the eight cells around it are a build rather than filler.

local Character = require("models.character")
local Discipline = require("models.discipline")
local Item = require("models.item")

-- The thirty-eight, by hero id -> the relic that makes them one. Written out rather than derived: a
-- derived list would pass by construction, and the point of this file is to disagree with the data.
local ROSTER = {
    -- subclasses (17)
    character_brann = "utility_red_account",
    character_marek = "utility_last_order",
    character_ilse = "armor_standing_debt",
    character_dov = "utility_doorstone",
    character_vess = "utility_quiet_errand",
    character_pim = "utility_bag_of_holding",
    character_cass = "utility_with_interest",
    character_mira = "utility_borrowed_pelt",
    character_tola = "utility_second_leash",
    character_sela = "utility_patient_line",
    character_nio = "utility_ninth_sigil",
    character_isa = "utility_court_kept_waiting",
    character_cael = "utility_second_reading",
    character_sunho = "utility_unheld_hand",
    character_nell = "utility_rite_unspoken",
    character_zosia = "utility_mother_vat",
    character_pol = "utility_short_fuse",
    -- multiclasses (21)
    character_aldo = "armor_crowds_due",
    character_elio = "weapon_long_bout",
    character_fen = "utility_ground_given",
    character_garan = "utility_folded_word",
    character_osric = "armor_marching_vow",
    character_hilde = "utility_last_call",
    character_dray = "utility_the_wedge",
    character_corin = "utility_bound_mile",
    character_ivo = "utility_dry_word",
    character_solene = "armor_held_oath",
    character_grell = "utility_sealed_bell",
    character_rask = "utility_quarrys_end",
    character_miro = "utility_fourth_shadow",
    character_calla = "utility_written_charge",
    character_nix = "utility_the_signal",
    character_ondo = "utility_old_wind",
    character_tuva = "utility_standing_stone",
    character_sorrel = "utility_cullers_basket",
    character_ilan = "utility_unbroken_vigil",
    character_wick = "utility_standing_order",
    character_ansel = "utility_open_ward",
}

local function kitOf(def)
    local out = {}
    for _, entry in ipairs(def.startingItems or {}) do
        if type(entry) == "string" then out[#out + 1] = entry
        elseif type(entry) == "table" and entry.id then out[#out + 1] = entry.id end
    end
    return out
end

return {
    {
        name = "every hall hero exists, is named, and carries its own relic in its grid",
        fn = function()
            for heroId, relicId in pairs(ROSTER) do
                local def = Character.defs[heroId]
                assert(def, heroId .. ": no blueprint")
                -- A NAME, not a job title. The whole premise of the roster is that the hall stops
                -- handing out classes, so a hero called "Assassin" would be the bug this file is for.
                assert(type(def.name) == "string" and def.name ~= "", heroId .. ": no name")
                assert(def.name ~= (Discipline.defs[def.discipline] and Discipline.defs[def.discipline].name),
                    heroId .. ": is named after its discipline rather than being somebody")

                assert(Item.defs[relicId], heroId .. ": relic " .. relicId .. " does not exist")
                local carried = false
                for _, id in ipairs(kitOf(def)) do
                    if id == relicId then carried = true end
                end
                assert(carried, heroId .. ": does not carry " .. relicId .. " -- the relic is the reason"
                    .. " this body is on the roster, so a grid without it is somebody else's stat line")
                -- Named as one of the two signature slots, because Draft strips a bought body down to
                -- exactly those (models/draft_chassis.lua) and a chassis without the relic is not this
                -- character. WHICH slot depends on what the relic is: Elio's is a sword, so it is his
                -- signatureWeapon; the other thirty-seven are the signatureAbility.
                assert(def.signatureAbility == relicId or def.signatureWeapon == relicId,
                    heroId .. ": neither signature slot names its relic (Draft strips a bought body to them)")
            end
        end,
    },
    {
        name = "every item a hall hero carries actually exists",
        fn = function()
            -- Nothing else in the suite checks this: a blueprint's kit is not validated until something
            -- instantiates it, and a hall body can sit unhired for a long time. Three bad ids shipped in
            -- one kit during the build, and this is the case that would have caught them.
            local missing = {}
            for heroId in pairs(ROSTER) do
                for _, id in ipairs(kitOf(Character.defs[heroId] or {})) do
                    if not Item.defs[id] then missing[#missing + 1] = heroId .. " -> " .. id end
                end
            end
            assert(#missing == 0, "kits name items that do not exist: " .. table.concat(missing, ", "))
        end,
    },
    {
        name = "one hero per discipline, and every discipline has one",
        fn = function()
            local byDiscipline = {}
            for heroId in pairs(ROSTER) do
                local d = Character.defs[heroId].discipline
                assert(d, heroId .. ": declares no discipline")
                assert(not byDiscipline[d], d .. ": two heroes (" .. tostring(byDiscipline[d])
                    .. " and " .. heroId .. ") -- which means some other discipline has none")
                byDiscipline[d] = heroId
            end
            for id, def in pairs(Discipline.defs) do
                assert(byDiscipline[id], id .. ": no hall hero. The roster is one per discipline, so a"
                    .. " gap here is a shelf the hall can never offer a body for")
                -- AND THE DATA HAS TO AGREE WITH THIS FILE. The discipline blueprint names its hero
                -- (`hire`), which is what the floors actually deal off (models/descent_recruit.lua) --
                -- so a roster that is right here and wrong there means a body nobody can ever meet.
                assert(def.hire == byDiscipline[id], id .. ": names " .. tostring(def.hire)
                    .. " as its hire, but its hero is " .. byDiscipline[id])
            end
        end,
    },
    {
        name = "every relic is bound, unpriced, and tagged to its bearer's discipline",
        fn = function()
            for heroId, relicId in pairs(ROSTER) do
                local relic = Item.defs[relicId]
                -- BOUND is the whole contract: never moved, stowed, given away, sold or stolen, only
                -- forged. Every mutation path in the game reads this one flag (Item.isBound).
                assert(relic.bound == true, relicId .. ": a signature relic must be bound")
                assert(relic.price == nil, relicId .. ": no vendor may stock or buy a relic")
                assert(relic.discipline == Character.defs[heroId].discipline,
                    relicId .. ": tagged to " .. tostring(relic.discipline) .. " but carried by a "
                        .. tostring(Character.defs[heroId].discipline))
            end
        end,
    },
    {
        name = "every relic is a build-around: its discipline stocks other items to feed it",
        fn = function()
            -- The design rule, pinned as far as a test can reach it. A relic authored against a shelf
            -- with nothing else on it cannot be built around by definition -- the eight cells beside it
            -- would be filler, which is the one thing the whole roster was cut against.
            local stock = {}
            for id, def in pairs(Item.defs) do
                if def.discipline then stock[def.discipline] = (stock[def.discipline] or 0) + 1 end
            end
            for _, relicId in pairs(ROSTER) do
                local d = Item.defs[relicId].discipline
                assert((stock[d] or 0) >= 4, d .. " stocks only " .. tostring(stock[d]) .. " items"
                    .. " including the relic -- there is nothing for " .. relicId .. " to read")
            end
        end,
    },
    {
        name = "every gated relic says what earning it does, and no gate is a bare yes/no",
        fn = function()
            for _, relicId in pairs(ROSTER) do
                local ab = Item.defs[relicId].activeAbility
                assert(ab, relicId .. ": a relic is an ultimate; it needs an active")
                assert(type(ab.description) == "string" and ab.description ~= "",
                    relicId .. ": no ability description -- say what earning it DOES")
                local gate = ab.unlock
                if gate then
                    -- Either a counted census or a counted tally. A `when`-only gate reports no
                    -- progress, so the slot would say "Not ready" and nothing else -- which for a
                    -- state the player is meant to build toward is the number they actually need.
                    assert((gate.field and gate.field.count) or gate.count,
                        relicId .. ": gates on a bare predicate, so its badge can show no progress")
                    assert(type(gate.text) == "string" and gate.text ~= "",
                        relicId .. ": a gate needs text the badge can print")
                else
                    -- The weapon exception, and it must be exactly one item. A greyed weapon slot costs
                    -- its bearer the thing a weapon is for, so a weapon relic wears a never-greying
                    -- counter instead of a gate.
                    assert(Item.defs[relicId].type == "weapon",
                        relicId .. ": only a weapon relic may go ungated")
                    assert(ab.counter and ab.counterGates == false,
                        relicId .. ": an ungated weapon relic must wear a counter that never greys")
                end
            end
        end,
    },
}
