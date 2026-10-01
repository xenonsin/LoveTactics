-- Tests for the PRIDE CIRCLE: the castle's five bodies, its mini sin, and the rule they share.
--
-- THE LIEUTENANT IS SUBLIMITAS NOW (2026-10-01). She moved down from the general's seat, an elf archmage
-- whose Already Known unravels any spell she has seen (tests/sublimitas_spec.lua pins the rule), and the
-- contract the deleted Marginalia case used to hold is held against her body below. The Marginal Note is
-- still on disk and still pinned on the ITEM alone; its comparison against her old Counter Magic went with
-- the Counter Magic.
--
-- The circle's own design property: POWER IS ADJACENCY. Both halves of the rank rule are measured live
-- off the board (Trait.liveBonus), so a Pride body is genuinely bipolar rather than merely buffed -- and
-- the `rooms` carve is what makes that a puzzle, because a doorway is where a rank comes apart.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Item = require("models.item")
local Trait = require("models.trait")
local Fixture = require("tests.support.fixture")

local unit = Fixture.unit

return {
    {
        -- THE MARKER WAS ANSWERED (2026-10-01). The slot held the gilded sworn as a stand-in after
        -- Marginalia was cut; Sublimitas holds it now, moved down when the general became Superbia, and the
        -- contract at the foot of this file sizes her.
        name = "Pride's lieutenant is Sublimitas over the elves, and its general is the Morning Star",
        fn = function()
            local sin
            for _, s in ipairs(Descent.SINS) do if s.id == "pride" then sin = s end end
            assert(sin and sin.minor.lead == "character_sublimitas", "Sublimitas holds the approach stair")
            assert(sin.minor.filler == "character_elf_retainer", "over the approach's own filler")
            assert(sin.guardian.lead == "character_general_pride" and sin.guardian.filler == "character_seraph",
                "the Morning Star holds the seat, with the Seraphs of her old court")
            assert(not Character.defs["character_marginalia"], "Marginalia is gone")
        end,
    },

    -- ------------------------------------------------------------ power is adjacency
    {
        name = "a gilded body is enormous in rank and ordinary alone",
        fn = function()
            local map = Fixture.new(14, 14)
            -- Alone in one corner; a closed block of four in the other.
            local c = Fixture.combat(map,
                { unit("character_knight", 1, 12) },
                { unit("character_gilded_sworn", 12, 1),
                  unit("character_gilded_sworn", 5, 5), unit("character_gilded_sworn", 6, 5),
                  unit("character_gilded_sworn", 5, 6), unit("character_gilded_sworn", 6, 6) })

            local lone, inRank
            for _, u in ipairs(c.units) do
                if u.char.id == "character_gilded_sworn" then
                    if u.x == 12 then lone = u elseif u.x == 5 and u.y == 5 then inRank = u end
                end
            end
            assert(lone and inRank, "both a lone body and one in the block took the field")

            -- Read through the live-bonus seam, which is what combat itself adds in.
            local function damageOf(u) return Trait.liveBonus(u, "damage") end
            local function guardOf(u) return Trait.liveBonus(u, "defense") end

            assert(damageOf(lone) == 0 and guardOf(lone) == 0,
                "a suit of armour standing by itself gets nothing from the rank rule")
            assert(damageOf(inRank) > 0, "and one standing in the block hits harder for every neighbour")
            assert(guardOf(inRank) > 0, "...and is armoured for them too")
        end,
    },
    {
        name = "the rank rule is measured live, so breaking the line removes it at once",
        fn = function()
            local map = Fixture.new(14, 14)
            local c = Fixture.combat(map,
                { unit("character_knight", 1, 12) },
                { unit("character_gilded_sworn", 5, 5), unit("character_gilded_sworn", 6, 5) })
            local a, b
            for _, u in ipairs(c.units) do
                if u.char.id == "character_gilded_sworn" then
                    if u.x == 5 then a = u else b = u end
                end
            end
            assert(Trait.liveBonus(a, "damage") > 0, "standing together, it is paid")
            Combat.teleportUnit(c, b, 12, 12)
            assert(Trait.liveBonus(a, "damage") == 0,
                "pulled apart, it loses it in the same instant -- nothing is banked")
        end,
    },

    -- ------------------------------------------------------------ the apex inverts its own circle
    {
        name = "the Peerless is paid for being alone, which is the opposite of its own stratum",
        fn = function()
            local map = Fixture.new(14, 14)
            local c = Fixture.combat(map,
                { unit("character_knight", 5, 5), unit("character_knight", 5, 7) },
                { unit("character_the_peerless", 6, 5) })
            local peerless, second
            for _, u in ipairs(c.units) do
                if u.char.id == "character_the_peerless" then peerless = u
                elseif u.y == 7 then second = u end
            end
            assert(Trait.liveBonus(peerless, "damage") > 0,
                "one foe beside it: the duel rule pays")
            -- Step the second knight in. The whole counterplay is that surrounding it turns it off.
            Combat.teleportUnit(c, second, 6, 6)
            assert(Trait.liveBonus(peerless, "damage") == 0,
                "two foes beside it and the duel is over -- take it into the open and swarm it")
        end,
    },
    {
        name = "the Peerless is an Elite that reads, not a health pool with a sword",
        fn = function()
            local def = Character.defs["character_the_peerless"]
            assert(def.kind == "humanoid" and def.tier == 3, "it is an Elite humanoid")
            local n = 0
            for _, entry in ipairs(def.startingItems or {}) do
                if type(entry) == "string" then n = n + 1 end
            end
            assert(n >= 3, "tests/bestiary_spec.lua holds the Elite rung to three items")
            assert(not def.footprint,
                "and it is the ONE apex in the descent that does not occupy four tiles -- it refuses to "
                .. "be surrounded rather than blocking a door")
        end,
    },

    -- ------------------------------------------------------------ the tier's rule
    {
        name = "Marginalia's second phase calls in the rank",
        fn = function()
            local note = Item.defs["utility_marginal_note"]
            assert(note, "the Marginal Note exists")
            local opens = false
            for _, t in ipairs(note.traits or {}) do
                if t == "trait_answered_once" then opens = true end
            end
            assert(opens, "it opens on the one-spell deflection")
            assert(note.phases and #note.phases == 1, "a mini sin gets ONE phase")
            assert(note.phases[1].at == 0.5, "and it turns at half health")
            local summons = false
            for _, r in ipairs(note.phases[1].responses or {}) do
                if r.kind == "summon" then summons = true end
            end
            assert(summons, "the phase adds neighbours, which in this circle IS power")
        end,
    },
    {
        -- THE CASE THAT SIZED MARGINALIA, held against the body that replaced her:
        --
        --     boss = true and a referenceLevel        a centrepiece that scales toward the shallows
        --     health above character_gilded_sworn      it outweighs its circle's line body (its stand-in)
        --     health 60-85% of the general's           and stands below the sin whose stair it holds
        --
        -- The same band tests/wrath_circle_spec.lua argues out in full.
        name = "Sublimitas is sized as a lieutenant: over the line body, under the general",
        fn = function()
            local her = Character.defs["character_sublimitas"]
            assert(her and her.boss and her.referenceLevel, "a centrepiece that scales toward the shallows")
            local hp = her.stats.health
            assert(hp > Character.defs["character_gilded_sworn"].stats.health, "she outweighs the line body")
            local general = Character.defs["character_general_pride"].stats.health
            assert(hp >= general * 0.6 and hp <= general * 0.85, string.format(
                "she stands below the sin whose stair she holds: %d against %d", hp, general))
        end,
    },

    -- ------------------------------------------------------------ the mythic tops the rank up
    {
        name = "the Gallery repairs the formation while you dismantle it",
        fn = function()
            local gal = Item.defs["utility_the_gallery"]
            assert(gal and gal.phases and #gal.phases == 2, "it stands two more suits up")
            for _, phase in ipairs(gal.phases) do
                for _, r in ipairs(phase.responses or {}) do
                    if r.kind == "summon" then
                        assert(r.id == "character_gilded_sworn",
                            "the suits it adds carry the rank rule, so each one makes the others stronger")
                    end
                end
            end
        end,
    },
    {
        name = "every Pride item is natural kit and nothing else",
        fn = function()
            for _, id in ipairs({ "weapon_gilded_pike", "utility_rank_and_file", "utility_gilded_standard",
                                  "utility_the_gallery", "utility_marginal_note", "utility_first_blade" }) do
                local def = Item.defs[id]
                assert(def, id .. " does not exist")
                assert(def.noSteal and not def.price and def.class == "creature",
                    id .. ": nothing here is for sale -- the house has been dead four hundred years")
            end
        end,
    },
}
