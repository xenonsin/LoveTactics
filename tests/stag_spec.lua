-- THE MEANDERING STAG and what it becomes: the fight whose first half has no attack in it, and the
-- threshold that turns every tile it laid.
--
-- Four claims are worth holding here, and they are the four that would fail SILENTLY -- a body that
-- quietly grew a weapon, a trail that quietly stopped being unsided, a conversion that quietly missed
-- half the board, and a magazine that quietly refilled.

local Item = require("models.item")
local Character = require("models.character")
local Hazard = require("models.hazard")
local Status = require("models.status")

local STAG = "character_meandering_stag"
local SPIRIT = "character_vengeful_spirit"

-- A small walkable board. Hazard.place refuses any tile that is off the map or not walkable -- "nothing
-- to stand on, so no hazard takes" -- so a combat with only a hazard list silently places nothing and
-- every claim below would pass by never running.
local function bareCombat()
    local tiles = {}
    for y = 1, 12 do
        tiles[y] = {}
        for x = 1, 12 do tiles[y][x] = { walkable = true } end
    end
    return { hazards = {}, units = {}, clock = 0, arena = { tiles = tiles, w = 12, h = 12 } }
end

local function body(name, hp)
    return {
        char = { name = name, stats = { health = { current = hp, max = hp }, speed = 5,
                 damage = 5, defense = 0 }, inventory = {}, statuses = {} },
        side = "party", alive = true, x = 1, y = 1, statuses = {},
    }
end

return {
    {
        name = "the stag cannot strike anything, and the spirit can",
        fn = function()
            local stag = Character.defs[STAG]
            assert(stag, "no Meandering Stag blueprint")

            -- NOT A LOW NUMBER -- THE ABSENCE OF THE FIELD. The whole first half of this fight is a
            -- boss that takes nothing off anybody, and a 1 here would be a different fight nobody
            -- designed. The three ways it could quietly come back are all checked: a damage stat, a
            -- weapon in the grid, and the fists every other body in the game falls back to.
            assert((stag.stats.damage or 0) == 0,
                "the Meandering Stag declares " .. tostring(stag.stats.damage) .. " damage")
            assert(stag.unarmed == false,
                "the stag has fists: `unarmed = false` is what makes it unable to strike at all")
            for _, id in ipairs(stag.startingItems or {}) do
                local def = Item.defs[id]
                assert(def and def.type ~= "weapon",
                    "the Meandering Stag is carrying a weapon (" .. id .. ")")
            end

            -- ...and the arrival of one is the second half. A spirit that opened with no weapon would
            -- be a transform into the same fight.
            local spirit = Character.defs[SPIRIT]
            assert(spirit, "no Vengeful Spirit blueprint")
            assert((spirit.stats.damage or 0) > 0, "the Vengeful Spirit still cannot hit anybody")
            local armed = false
            for _, id in ipairs(spirit.startingItems or {}) do
                local def = Item.defs[id]
                if def and def.type == "weapon" then armed = true end
            end
            assert(armed, "the Vengeful Spirit carries no weapon")
        end,
    },
    {
        name = "the bar does not jump when the animal does, and the mana carries as the magazine",
        fn = function()
            local stag, spirit = Character.defs[STAG], Character.defs[SPIRIT]
            -- The Turning's rule: the transform changes what a body can do, never how much killing it
            -- takes. Health is CARRIED by models/transform.lua, so this figure only decides the ceiling
            -- the bar is drawn against -- and a mismatch is a bar that visibly jumps at the threshold.
            assert(stag.stats.health == spirit.stats.health, string.format(
                "the stag is %d health and the spirit %d: the bar jumps at the threshold",
                stag.stats.health, spirit.stats.health))

            -- THE POOL IS THE SECOND HALF'S AMMUNITION, and it is declared on a body that never spends
            -- a point of it. If the stag's pool ever drops below the spirit's, the spirit opens short.
            assert(stag.stats.mana >= spirit.stats.mana, string.format(
                "the stag carries %d mana forward into a body that declares %d",
                stag.stats.mana, spirit.stats.mana))

            -- ...and it has to buy at least a few casts, or the detonation is not the second half's
            -- mechanic, it is a one-off.
            local swail = Item.defs["ability_swailing"]
            local cost = swail and swail.activeAbility and swail.activeAbility.cost
            assert(cost and cost.stat == "mana", "Swailing no longer costs mana -- see the magazine")
            local casts = math.floor(stag.stats.mana / cost.amount)
            assert(casts >= 3, string.format(
                "%d mana against a cost of %d buys %d detonations, which is not a magazine",
                stag.stats.mana, cost.amount, casts))
        end,
    },
    {
        name = "both grounds are unsided: they answer whoever is standing on them",
        fn = function()
            -- THE LINE EVERY OTHER FRIENDLY ZONE HAS AND THESE TWO DO NOT. Sanctuary, Renewing Ground
            -- and the Wellspring all open with an allegiance check and pay one side only; the whole
            -- character of this animal is that its ground does not ask. The check is behavioural rather
            -- than a grep for `isAlly`, because a guard could come back in any shape.
            for _, pair in ipairs({ { "hazard_bloom", "status_regen" },
                                    { "hazard_blight", "status_blighted" } }) do
                local id, expected = pair[1], pair[2]
                for _, side in ipairs({ "party", "enemy" }) do
                    local combat = bareCombat()
                    local u = body("standing", 40)
                    u.side = side
                    combat.units = { u }
                    -- Sided to the ENEMY deliberately: if either def learns an allegiance check, the
                    -- party-side body below stops being touched and this reddens.
                    local zone = Hazard.place(combat, 1, 1, id, { side = "enemy" })
                    assert(zone, id .. " could not be placed")
                    assert(Status.has(u, expected), string.format(
                        "%s did not reach a %s-side body: it has taken a side", id, side))
                end
            end
        end,
    },
    {
        name = "the threshold turns the whole board, not the tiles laid after it",
        fn = function()
            local combat = bareCombat()
            -- Ten prints, the way a trail accumulates -- and one unrelated zone, which must survive.
            for i = 1, 10 do Hazard.place(combat, i, 1, "hazard_bloom", { side = "enemy" }) end
            Hazard.place(combat, 1, 5, "hazard_fire", { side = "enemy" })

            local turned = Hazard.convert(combat, "hazard_bloom", "hazard_blight")
            assert(turned == 10, "converted " .. turned .. " tiles of ten")

            local blooms, blights, fires = 0, 0, 0
            for _, h in ipairs(combat.hazards) do
                if h.id == "hazard_bloom" then blooms = blooms + 1 end
                if h.id == "hazard_blight" then blights = blights + 1 end
                if h.id == "hazard_fire" then fires = fires + 1 end
            end
            -- ALL of them, not the new ones -- the party is standing on the old ones, which is the
            -- entire point of the beat.
            assert(blooms == 0, blooms .. " squares of New Growth survived the threshold")
            assert(blights == 10, "the board carries " .. blights .. " blighted tiles, not ten")
            -- ...and nothing else on the floor was touched. A conversion that took every zone would
            -- quietly delete the party's own sanctuaries at the same moment.
            assert(fires == 1, "the conversion ate ground that was not its own")

            -- THE NEW GROUND IS NEW. A blight that inherited what was left of a bloom's clock would
            -- wink out the oldest half of the board on the instant it turned -- the half that took the
            -- longest to earn.
            for _, h in ipairs(combat.hazards) do
                if h.id == "hazard_blight" then
                    assert(h.remaining == h.def.duration, string.format(
                        "a turned tile opened with %s of its own %s ticks",
                        tostring(h.remaining), tostring(h.def.duration)))
                end
            end
        end,
    },
    {
        name = "the relic scripts the board before the body, and only at half",
        fn = function()
            local relic = Item.defs["utility_what_the_wood_owes_it"]
            assert(relic and relic.phases and #relic.phases == 1,
                "the stag's relic no longer carries exactly one stage")
            local stage = relic.phases[1]
            assert(stage.at == 0.5, "the threshold is at " .. tostring(stage.at) .. ", not half")

            -- ORDER IS THE BEAT. The floor turning is what the transform is a consequence OF, so the
            -- player has to see the board go first; reversed, it reads as a monster casting a spell.
            local groundAt, transformAt
            for i, r in ipairs(stage.responses or {}) do
                if r.kind == "ground" then groundAt = i end
                if r.kind == "transform" then transformAt = i end
            end
            assert(groundAt and transformAt, "the stage no longer both turns the ground and transforms")
            assert(groundAt < transformAt, "the body changes before the floor does")

            local ground = stage.responses[groundAt]
            assert(ground.from == "hazard_bloom" and ground.to == "hazard_blight",
                "the conversion no longer points at the pair the fight lays")
            assert(stage.responses[transformAt].id == SPIRIT,
                "the stage transforms into something other than the Vengeful Spirit")
        end,
    },
    {
        name = "the spirit is the one thing its own ground cannot touch, and it lays no green",
        fn = function()
            local hide = Item.defs["utility_the_turned_year"]
            assert(hide, "the Vengeful Spirit's hide is gone")

            local immune = false
            for _, id in ipairs(hide.statusImmunity or {}) do
                if id == "status_blighted" then immune = true end
            end
            -- Arithmetic as much as image: the blight is unsided, so without this the board kills the
            -- boss for the party.
            assert(immune, "the Vengeful Spirit is not immune to its own ground")

            -- ONE-WAY. A spirit that laid any New Growth would hand the party a road back to the first
            -- half, and the threshold is meant to be a door that shuts.
            assert(hide.trail and hide.trail.hazard == "hazard_blight",
                "the spirit's trail is not blight")
            for _, id in ipairs(Character.defs[SPIRIT].startingItems or {}) do
                local def = Item.defs[id]
                assert(not (def and def.trail and def.trail.hazard == "hazard_bloom"),
                    id .. " lays New Growth: the threshold is no longer one-way")
            end
        end,
    },
    {
        name = "the magazine cannot refill: blight does not spread, and each cast spends a tile",
        fn = function()
            -- THE LOOP. The spirit's ammunition is the trail the STAG laid while running away, and how
            -- much room the company gave it is how much it has to throw. Ground that made more of
            -- itself would refill that forever and the loop would stop closing -- so the absence of
            -- `spread` on the blight is load-bearing, not an omission.
            local blight = Hazard.defs["hazard_blight"]
            assert(blight, "no blight blueprint")
            assert(not blight.spread, "blight has learned to spread: the magazine now refills")

            -- ...and a cast genuinely takes the tile off the board rather than merely firing it.
            local combat = bareCombat()
            local zone = Hazard.place(combat, 2, 2, "hazard_blight", { side = "enemy" })
            assert(#combat.hazards == 1, "the board did not take the zone")
            assert(Hazard.consume(combat, zone), "a live zone refused to be spent")
            assert(#combat.hazards == 0, "the spent tile is still on the board")
            -- A double-spend is inert rather than an error: two effects racing one zone must not fault.
            assert(not Hazard.consume(combat, zone), "spending a gone zone reported success")
        end,
    },
    {
        name = "a detonation is whatever it ate: the zone's own hook, run where nobody walked",
        fn = function()
            -- The claim the whole ability rests on. Hazard.applyTo runs the def's onEnter against a
            -- body that has entered nothing, which is what lets one ability burn, charm or heal with
            -- no table of per-hazard blast effects to keep in step.
            local combat = bareCombat()
            local u = body("bystander", 40)
            u.x, u.y = 9, 9 -- deliberately NOWHERE NEAR the zone: it is being set off, not walked into
            combat.units = { u }
            local zone = Hazard.place(combat, 2, 2, "hazard_blight", { side = "enemy" })

            assert(not Status.has(u, "status_blighted"), "the bystander was blighted by proximity")
            assert(Hazard.applyTo(combat, zone, u), "the zone refused to be applied")
            assert(Status.has(u, "status_blighted"),
                "setting the ground off did not do what standing on it does")

            -- A dead zone does nothing, so an ability that spends first and touches second is inert
            -- rather than faulty.
            Hazard.consume(combat, zone)
            assert(not Hazard.applyTo(combat, zone, u), "a spent zone still went off")
        end,
    },
    {
        name = "the stag's whole kit is creature gear, and what it drops is not",
        fn = function()
            -- docs/bestiary.md: a boss's own fight is never handed to the player. Creature kit carries
            -- no axis at all -- no price, no unlockLevel -- so neither the pool nor a counter can mint it.
            for _, id in ipairs({ "utility_what_the_wood_owes_it", "utility_the_turned_year",
                                  "weapon_deadfall", "ability_swailing" }) do
                local def = Item.defs[id]
                assert(def, id .. " does not exist")
                assert(def.class == "creature", id .. " is not creature kit")
                assert(def.price == nil and def.unlockLevel == nil,
                    id .. " carries an axis, so the drop pool can mint a boss's own fight")
                assert(def.noSteal, id .. " can be lifted off the boss")
            end

            -- ...and the drops are the opposite: real gear, at real depths, ordered by rarity.
            local stag = Character.defs[STAG]
            local last
            for _, id in ipairs(stag.drops or {}) do
                local def = Item.defs[id]
                assert(def, "the stag drops " .. id .. ", which does not exist")
                assert(def.class ~= "creature", id .. " is creature kit and cannot be carried home")
                assert(def.unlockLevel, id .. " has no depth, so no floor can pay it")
                assert(def.unstocked, id .. " is still dealt by a counter")
                -- DEPTH IS RARITY (docs/drops.md), so the ORDER of the numbers is the drop-rate design:
                -- the print you meet, the rule, the chase.
                if last then
                    assert(def.unlockLevel > last, string.format(
                        "%s sits at rank %d, not deeper than the entry before it (%d)",
                        id, def.unlockLevel, last))
                end
                last = def.unlockLevel
            end
        end,
    },
    {
        -- Named cases for the two pieces this fight adds to the catalogue, which
        -- tests/item_coverage_spec.lua requires by id: an item nothing tests is an item that can be
        -- quietly re-shaped by a sweep and never noticed.
        name = "utility_the_second_hound answers the SECOND foe and never the first",
        fn = function()
            local def = Item.defs["utility_the_second_hound"]
            assert(def, "utility_the_second_hound is gone")
            assert(def.type == "utility" and def.class == "skirmisher",
                "The Second Hound has left the shelf it was filed on")

            local trait = require("models.trait").defs["trait_the_second_hound"]
            assert(trait, "the charm names a trait that does not exist")
            -- THE COUNT IS THE ITEM. A version that fired on the first attacker is a different charm --
            -- "you cannot be meleed" rather than "you cannot be surrounded" -- and the difference is
            -- one comparison that a tuning pass could flip without anybody reading the name again.
            assert(trait.onDamaged, "the charm no longer answers a blow")
            assert((trait.cooldown or 0) >= 10,
                "the step is off cooldown inside a turn, so a surrounded bearer cannot be hit twice")
        end,
    },
    {
        name = "utility_swailing_brand is Second Growth at a price: it spends ground, never owns it",
        fn = function()
            local def = Item.defs["utility_swailing_brand"]
            assert(def, "utility_swailing_brand is gone")
            local ab = def.activeAbility
            assert(ab, "the Brand has stopped being something you cast")

            -- THE REBALANCE, PINNED. The piece it replaces was cut for being passive and permanent:
            -- "you're essentially immune to hazards". Every clause below is one of the four prices that
            -- answer that, and any of them silently coming off puts the cut item back.
            assert(ab.cost and ab.cost.stat == "mana",
                "the Brand costs no mana, so a bearer can spend ground every turn for free")
            assert(ab.target == "tile", "the Brand no longer aims at ground")
            assert(def.class == "druid", "the Brand has left the druid's shelf")
            assert(def.unstocked, "the Brand is dealt by a counter")

            -- Matched to the spirit's own figures, so the item a player carries and the ability it was
            -- taken from cannot quietly disagree about what a detonation is worth.
            local spirit = Item.defs["ability_swailing"]
            assert(spirit and spirit.activeAbility.cost.amount == ab.cost.amount,
                "the Brand and Swailing have drifted apart on cost")
            assert(spirit.activeAbility.range == ab.range,
                "the Brand and Swailing have drifted apart on range")
        end,
    },
    {
        name = "the quarry posture is offerable, refuses to engage, and carries no rules",
        fn = function()
            local AI = require("models.ai")
            local q = AI.POSTURES.quarry
            assert(q, "the quarry posture is gone")
            assert(q.move == "flee", "quarry no longer flees")
            assert(q.engage() == false, "a quarry will take a swing")
            assert(#(q.rules or {}) == 0,
                "quarry carries rules, so AI.plan will not drop to the walk")

            -- Every posture has to be in the offered list or it is one the player cannot choose.
            local listed = false
            for _, name in ipairs(AI.POSTURE_ORDER) do
                if name == "quarry" then listed = true end
            end
            assert(listed, "quarry is not in AI.POSTURE_ORDER, so no Tactics tab can pick it")

            assert(Character.defs[STAG].archetype == "quarry",
                "the Meandering Stag is no longer a quarry")
        end,
    },
}
