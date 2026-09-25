-- Tests for the SUCCUBUS LINE -- the Lust circle's third animal, which is not one.
--
-- The stratum's other two bill POSITION: a harpy decides where your body is, a lamia decides it does
-- not get to be anywhere else (tests/greed_lust_circle_spec.lua holds both). This line bills
-- ALLEGIANCE, which is the fifth verb in Descent.SINS' Lust entry and the one that had no rollable
-- body behind it until now -- the Suppliant charms, and she is SEATED: one landing, once, at the end
-- of the circle.
--
-- WHY THESE ARE CASES AND NOT A HEADER. "She arrives with an escort" is a composition, and what is
-- really happening is a `status_charm` with a side-effect on her death -- the two are indistinguishable
-- on the board until somebody kills her, and the difference is the whole fight. Three rules are pinned
-- here and each one shipped broken in an obvious way first:
--
--   the binding     a charm landed by somebody already on your side must TAKE NOTHING. The fallback in
--                   status_charm reads "a charm always changes hands" and would flip her own thralls
--                   to the player at the opening bell.
--   the release     a bound body has no side to be handed back to, so the release is it LEAVING.
--   the split       a wound meant for her opens in everyone she holds -- and, crucially, does not when
--                   she holds nobody, or the rule reads as invulnerability.
--
-- Pure logic over Combat/Status/Trait. No love.graphics, headless.

local Combat = require("models.combat")
local Item = require("models.item")
local Status = require("models.status")
local Trait = require("models.trait")
local Fixture = require("tests.support.fixture")

local unit = Fixture.unit

-- The charmer and the bodies standing with her, off a board seated the way an encounter seats one:
-- the congregation walks in on HER side, because it walked in with her.
--
-- HELD IS THE BOUND ONES ONLY, and the distinction is the whole reason this helper exists rather than
-- a sweep of `side == "enemy"`. The Abbess also TAKES one of the company at the bell
-- (trait_the_first_yes), and that body is standing on her side too -- so a sweep by side counts the
-- player's own anvil as part of her congregation and every count in this file comes out one high.
-- `bound` is what tells the two apart, which is exactly what status_charm stamps it for.
local function chapel(c, charmerId)
    local charmer, held = nil, {}
    for _, u in ipairs(c.units) do
        if u.char.id == charmerId then
            charmer = u
        else
            local st = Status.get(u, "status_charm")
            if st and st.bound then held[#held + 1] = u end
        end
    end
    return charmer, held
end

return {
    {
        name = "a succubus arrives holding the church's own, and the binding takes nothing",
        fn = function()
            local map = Fixture.new(12, 12)
            local c = Fixture.combat(map, { unit("character_knight", 5, 5) },
                { unit("character_lesser_succubus", 5, 9), unit("character_knight", 6, 9) })
            local succubus, held = chapel(c, "character_lesser_succubus")
            assert(succubus and #held == 1, "the Long Gallery seats a charmer and somebody to hold")
            local thrall = held[1]

            local st = Status.get(thrall, "status_charm")
            assert(st, "the blooded walks on already Charmed -- a real status, not a flag of its own")
            assert(st.charmer == succubus, "and the charm knows whose it is")
            assert(st.bound, "a charm landed by somebody already on your side is a BINDING")

            -- THE FAILURE THIS IS WRITTEN AGAINST, and it is one line of status_charm: the fallback
            -- reads "a charm is a body changing hands, and it always changes", which for a turner
            -- standing on the victim's own side flips the body to the FAR side -- handing the
            -- succubus's congregation to the player before anybody has moved.
            assert(thrall.side == "enemy", "the binding must not hand her congregation to the party")
            assert(thrall._charmSide == nil, "a bound body stashes no allegiance: it has none left")
            assert(thrall.control == "ai", "bound or taken, nobody drives a charmed body by hand")
        end,
    },
    {
        name = "cut the charmer and the blooded walks out rather than changing hands",
        fn = function()
            local map = Fixture.new(12, 12)
            local c = Fixture.combat(map, { unit("character_knight", 5, 5) },
                { unit("character_lesser_succubus", 5, 9), unit("character_knight", 6, 9) })
            local succubus, held = chapel(c, "character_lesser_succubus")
            local thrall = held[1]
            assert(Status.get(thrall, "status_charm"), "held before she falls")

            Combat.dealFlatDamage(c, succubus, 9999, { "physical" })
            assert(not succubus.alive, "she is down")

            -- THIS CIRCLE'S LAW AT ITS LARGEST PAYOUT. Combat.releaseCharmedBy frees everyone a fallen
            -- charmer was holding; a bound body has no side to be handed back to, so the release IS it
            -- leaving. Dismissed rather than killed -- nothing struck him, so he leaves no corpse,
            -- feeds no death reflex and pays no spoils.
            assert(not thrall.alive, "the blooded does not go on fighting for a corpse")
            assert(not thrall.corpse, "he walked out; he did not die")
        end,
    },
    {
        name = "a wound meant for the Abbess opens in the bodies she is holding, split whole",
        fn = function()
            local map = Fixture.new(14, 14)
            local c = Fixture.combat(map, { unit("character_knight", 5, 5) },
                { unit("character_succubus_abbess", 5, 10),
                  unit("character_knight", 6, 10, { stats = { health = 200 } }),
                  unit("character_priest", 7, 10, { stats = { health = 200 } }) })
            local abbess, held = chapel(c, "character_succubus_abbess")
            assert(abbess and #held == 2, "she stands with two of them")

            local before = Fixture.hp(abbess)
            local was = { Fixture.hp(held[1]), Fixture.hp(held[2]) }
            Combat.dealFlatDamage(c, abbess, 60, { "physical" })

            -- SHE IS NEVER THE THING YOU ARE HITTING. The blow never reaches her: each share is
            -- re-thrown through Combat.dealFlatDamage at a body she holds, so that body's own armour,
            -- resists, barrier and reflexes all answer it.
            assert(Fixture.hp(abbess) == before, "the Congregation takes the wound, not the Abbess")
            assert(Fixture.hp(held[1]) < was[1] and Fixture.hp(held[2]) < was[2],
                "and it is split across everyone she holds rather than dumped on one of them")
        end,
    },
    {
        name = "cure your own and the Abbess has nowhere to put the next blow",
        fn = function()
            -- THE HALF THAT MAKES THE FIGHT WINNABLE, and the one a split rule forgets.
            -- Trait.shareTargets answers nil when the flag is present and the congregation is not,
            -- which is the caller's signal to deal the blow the ordinary way. Without it the rule is
            -- invulnerability rather than hiding.
            --
            -- Fought here as the counterplay actually reads on the board: she walks on with nobody but
            -- the company's own anvil (trait_the_first_yes), the party frees it, and she is a thin
            -- caster standing in the open. Cure and Panacea reach Charm because it is a `debuff`, and
            -- Status.remove fires onExpire, so freeing the body also hands it home.
            local map = Fixture.new(12, 12)
            local c = Fixture.combat(map, { unit("character_knight", 5, 5) },
                                          { unit("character_succubus_abbess", 5, 9) })
            local abbess, held = chapel(c, "character_succubus_abbess")
            assert(#held == 0, "she brought nobody of her own to this one")

            local taken
            for _, u in ipairs(c.units) do
                if u ~= abbess and Status.get(u, "status_charm") then taken = u end
            end
            assert(taken, "she opened by taking the anvil")

            -- Still hidden while she holds it: the blow lands on the company's own knight.
            local before = Fixture.hp(abbess)
            Combat.dealFlatDamage(c, abbess, 20, { "physical" })
            assert(Fixture.hp(abbess) == before, "while she holds one, she is not the thing you hit")

            Status.remove(c, taken, "status_charm")
            assert(taken.side == "party", "freeing a TAKEN body hands it back to its own side")
            Combat.dealFlatDamage(c, abbess, 20, { "physical" })
            assert(Fixture.hp(abbess) < before, "a charmer holding nobody takes her own wounds")
        end,
    },
    {
        name = "Borrowed Blood drinks off what she holds, and off nothing else",
        fn = function()
            local map = Fixture.new(12, 12)
            local c = Fixture.combat(map, { unit("character_knight", 5, 5) },
                { unit("character_succubus", 5, 9), unit("character_knight", 6, 9),
                  unit("character_harpy", 7, 9) })
            local succubus, harpy, thrall, victim
            for _, u in ipairs(c.units) do
                if u.char.id == "character_succubus" then succubus = u
                elseif u.char.id == "character_harpy" then harpy = u
                elseif u.side == "enemy" then thrall = u
                else victim = u end
            end
            succubus.char.stats.health.current = succubus.char.stats.health.max - 20
            local hurt = Fixture.hp(succubus)

            -- A blow by a body she HOLDS feeds her. The gate is the charm's own `charmer` stamp.
            Trait.onAllyStrike(c, thrall, victim)
            assert(Fixture.hp(succubus) > hurt, "she drinks what her congregation does")

            -- ...and one by an ordinary ally does not. A rule that paid out whenever any chaff on her
            -- side landed a blow would be a lifesteal aura wearing a charm's name.
            local fed = Fixture.hp(succubus)
            Trait.onAllyStrike(c, harpy, victim)
            assert(Fixture.hp(succubus) == fed, "a harpy beside her is an ally, not a congregation")
        end,
    },
    {
        name = "the First Yes takes the biggest body in the company, free and unrolled",
        fn = function()
            local map = Fixture.new(14, 14)
            local c = Fixture.combat(map, {
                    unit("character_mage", 4, 5, { stats = { health = 40 } }),
                    unit("character_knight", 6, 5, { stats = { health = 180 } }) },
                { unit("character_succubus_abbess", 5, 10) })
            -- Found by BLUEPRINT and not by side: she has already moved it onto hers, which is the
            -- thing this case is here to prove.
            local anvil
            for _, u in ipairs(c.units) do
                if u.char.id == "character_knight" then anvil = u end
            end
            -- THE ONE PLACE THIS CIRCLE PICKS ON THE STRONG. Everything else on the stratum reaches for
            -- whoever is already giving way -- the Matriarch's cry is `lowest_hp`, and the charm's own
            -- curve pays out best against a body nearly down. The opening takes what the party BUILT,
            -- read off max health so a hard walk down does not change who she wants.
            assert(anvil, "the company fielded an anvil")
            assert(Status.get(anvil, "status_charm"), "the opening takes it")
            assert(anvil.side == "enemy", "and THAT one is a taking -- it really changes hands")
            assert(anvil._charmSide == "party", "so it stashes a side to go home to")
        end,
    },
    {
        name = "the charm curve has one owner, and both deliverers read it",
        fn = function()
            -- TWO DELIVERERS NOW (ability_charm and weapon_the_anointing), so the softening curve moved
            -- to Status.charmChance. Two copies of `25 + (1 - frac) * 60` is a number that drifts the
            -- first time anybody tunes it, with the tuning landing on whichever file was open.
            local map = Fixture.new(10, 10)
            local c = Fixture.combat(map, { unit("character_knight", 5, 5) },
                                          { unit("character_succubus", 5, 8) })
            local knight
            for _, u in ipairs(c.units) do if u.char.id == "character_knight" then knight = u end end
            assert(Status.charmChance(knight) == 25, "a whole body refuses three asks in four")
            knight.char.stats.health.current = 0
            assert(Status.charmChance(knight) == 85, "and one nearly down is taken five times in six")
        end,
    },
    {
        name = "the kiss trades tiles: the body that reached her ends up where she was",
        fn = function()
            local map = Fixture.new(12, 12)
            local c = Fixture.combat(map, { unit("character_knight", 5, 5) },
                                          { unit("character_lesser_succubus", 5, 6) })
            local succubus, knight
            for _, u in ipairs(c.units) do
                if u.char.id == "character_lesser_succubus" then succubus = u else knight = u end
            end
            local sx, sy, kx, ky = succubus.x, succubus.y, knight.x, knight.y
            Fixture.strike(c, succubus, knight, "weapon_parting_kiss")
            -- THE THIRD DISPLACEMENT VERB ON THIS GROUND. The talons haul IN, the gust drives OUT, this
            -- one exchanges -- nobody is disengaged, and what changed is which side of the line each of
            -- them is on. In the Thinwall Keep that is a body standing past the doorway its own rank
            -- was holding, with the room's other occupants for company.
            assert(knight.x == sx and knight.y == sy, "the kissed body is standing where she was")
            assert(succubus.x == kx and succubus.y == ky, "and she is standing where it was")
        end,
    },
    {
        name = "Lust's ground fields the succubus line, and all three of its stops are reachable",
        fn = function()
            local Encounter = require("models.encounter")
            local seen = {}
            -- The fen since the 2026-09-25 swap: the church is drowned, and its chapels went with it.
            for _, rung in ipairs({ 1, 2 }) do
                for _, row in ipairs(Encounter.pool({ biome = "swamp", depth = 3, rung = rung,
                                                      quest = { sin = "lust" } })) do
                    seen[row.id] = true
                end
            end
            -- The two ordinary stops close the hole the 2026-09-22 human-body sweep left on this
            -- ground; the elite is a SPARE rather than a billing, because both of this circle's elite
            -- rungs are already argued to its two animals (Descent.SINS).
            for _, id in ipairs({ "encounter_lust_the_long_gallery", "encounter_lust_the_chapter_house",
                                  "encounter_lust_the_lady_chapel" }) do
                assert(seen[id], id .. " never rolls on the ground it was written for")
            end
        end,
    },
    {
        name = "her kit is natural, and the two things the rift pays out are not",
        fn = function()
            for _, id in ipairs({ "weapon_parting_kiss", "weapon_the_anointing", "utility_the_blooded",
                                  "utility_the_anointed", "utility_borrowed_blood",
                                  "utility_fallen_wings" }) do
                local def = Item.defs[id]
                assert(def, id .. " does not exist")
                assert(def.noSteal and not def.price and def.class == "creature",
                    id .. ": creature kit is unpriced, unshelved and unstealable")
            end
            -- ...and what a company carries OUT is shelf stock: a rung on a class ladder, no price,
            -- found in the rift rather than dealt over a counter (docs/shelf.md).
            for _, id in ipairs({ "utility_the_offered_place", "utility_the_congregation" }) do
                local def = Item.defs[id]
                assert(def, id .. " does not exist")
                assert(def.class ~= "creature" and not def.price and def.unlockLevel,
                    id .. ": a rift find shelves on a class and carries no price")
            end
        end,
    },
}
