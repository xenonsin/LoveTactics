-- THE MEANDERING STAG and what it becomes: the fight whose first half has no attack in it, and the
-- threshold that turns every tile it laid.
--
-- Four claims are worth holding here, and they are the four that would fail SILENTLY -- a body that
-- quietly grew a weapon, a trail that quietly stopped being unsided, a conversion that quietly missed
-- half the board, and a magazine that quietly refilled.
--
-- AND THEN THE LESSER STAG, at the bottom of the file. The Ancient Stag (character_stag_beast) is the
-- other member of this family, and it shares the family's two marks -- a rack and the wood mending
-- around it -- while sharing none of the apex's premise. Its cases hold the three that would fail
-- silently in the same way: a sweep that quietly narrowed to one tile, a herd rule that quietly paid a
-- body standing alone, and a drop list that quietly started handing out the animal's own kit.

local Item = require("models.item")
local Character = require("models.character")
local Hazard = require("models.hazard")
local Status = require("models.status")
local Combat = require("models.combat")

local STAG = "character_meandering_stag"
local SPIRIT = "character_vengeful_spirit"
local LESSER = "character_stag_beast"

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

-- A board somebody can actually WALK and SWING on, which bareCombat above deliberately is not:
-- Hazard.place reads `walkable` and nothing else, while movement and the recovery loop want the
-- arena's bounds and real terrain under the body.
local function walkableCombat()
    local c = bareCombat()
    for y = 1, 12 do
        for x = 1, 12 do
            c.arena.tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    c.arena.cols, c.arena.rows = 12, 12
    return c
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
    -- ------------------------------------------------------------------------------------------
    -- THE LESSER STAG (character_stag_beast). Everything above is the apex; everything below is the
    -- other animal in its family -- antlers and a herd, and none of the chase.
    -- ------------------------------------------------------------------------------------------
    {
        name = "the Ancient Stag carries its own rack and no wolf's teeth",
        fn = function()
            local stag = Character.instantiate(LESSER)
            local ids = {}
            for _, it in ipairs(Character.eachItem(stag)) do ids[it.id] = true end
            assert(ids.weapon_stag_antlers, "it sweeps with antlers")
            assert(ids.utility_herd_warmth, "and the herd rule is in the kit, not just in the folder")
            -- It was the LAST body in the game on weapon_fangs -- a blueprint authored for the wolves,
            -- whose own flavor line says so -- which weapon_tusks.lua named when it took the boar off
            -- that same item. Nothing bites with it now.
            assert(not ids.weapon_fangs,
                "weapon_fangs is the wolves' blueprint (its own flavor says so) -- a stag does not bite")
            -- Feral Instinct is the shared wilds package; the rack is the same instinct with this
            -- animal's name on it, and carrying both is two reflexes answering one blow.
            assert(not ids.utility_feral_instinct,
                "the stag carries Feral Instinct as well as its rack: one blow, two answers")

            -- THE RETAG, which is the half that was quietly broken: nothing in the game carries a
            -- `bite` resist, so for as long as this animal bit you its ordinary blow was a melee attack
            -- no coat could answer. The same assertion tests/boar_spec.lua makes about the tusks.
            local tags = {}
            for _, t in ipairs(Item.defs.weapon_stag_antlers.tags or {}) do tags[t] = true end
            assert(tags.pierce, "a tine is a point, and `pierce` is the tag a coat can answer")
            assert(not tags.bite, "it is not a bite")
        end,
    },
    {
        name = "the rack sweeps a rank, on the contract both other antlered bodies already declare",
        fn = function()
            -- THE FAMILY, ASSERTED RATHER THAN WRITTEN DOWN. Two apex bodies carry antlers and both
            -- sweep three wide; a tier-2 member that quietly narrowed to a single target would be a
            -- jab wearing the family's name, and nothing else in the suite reads this footprint.
            local family = { "weapon_hoarfrost_antlers", "weapon_antler_crown", "weapon_stag_antlers" }
            for _, id in ipairs(family) do
                local ab = Item.defs[id] and Item.defs[id].activeAbility
                assert(ab and ab.aoe, id .. " no longer sweeps anything")
                assert(ab.aoe.shape == "front" and ab.aoe.width == 3, string.format(
                    "%s sweeps %s/%s, not a three-wide front arc",
                    id, tostring(ab.aoe.shape), tostring(ab.aoe.width)))
            end

            -- ...AND IT PAYS FOR THE RANK. The two apexes carry a status rider each (Freeze, Charm) and
            -- sit on 2x2 bodies; this one's whole price is that each body in the arc takes less than a
            -- single-target jab would deal. A sweep that matched the jab would make this strictly
            -- better than the boar's blow at no cost, which a tier-2 road body is not entitled to.
            local rack = Item.defs.weapon_stag_antlers.activeAbility
            local jab = Item.defs.weapon_tusks.activeAbility
            -- Curve.ramp returns a plain array, one entry per forge level, so the comparison is an
            -- index rather than a call. Written the long way ON PURPOSE: the first cut of this case
            -- guarded on an `Item.curveAt` that does not exist, so every assertion inside it was
            -- skipped and the case passed while proving nothing at all.
            assert(type(rack.damage) == "table" and type(jab.damage) == "table",
                "one of the two weapons stopped growing on the forge, so there is nothing to compare")
            assert(#rack.damage == #jab.damage, "the two curves are different lengths")
            for level = 1, #rack.damage do
                assert(rack.damage[level] < jab.damage[level], string.format(
                    "at forge level %d the sweep deals %d against the jab's %d -- the rank is free",
                    level - 1, rack.damage[level], jab.damage[level]))
            end
        end,
    },
    {
        name = "the rack throws what reaches in, and it is the shield's instinct without the shield",
        fn = function()
            local toss = require("models.trait").defs["trait_antler_toss"]
            local shove = require("models.trait").defs["trait_shield_shove"]
            assert(toss and shove, "one of the two shoving reflexes is gone")
            assert(toss.counter and toss.counter.shoves, "the rack no longer shoves anything")

            -- THE TWO DIFFERENCES ARE THE ITEM, and both are one word away from being erased by a
            -- tuning pass that never reads either header.
            assert(toss.counter.shoves < shove.counter.shoves, string.format(
                "the rack throws %d tiles against the shield's %d -- an animal now drives a body "
                .. "further than a braced guard does", toss.counter.shoves, shove.counter.shoves))
            assert(not toss.counter.answersReactions, string.format(
                "the rack answers answers as well as attacks, so two of them across one exchange "
                .. "toss each other until somebody runs out of stamina"))

            -- ...and it rides the RACK, not a shared charm -- otherwise every animal wearing the wilds
            -- package inherits a stag's reflex (weapon_wolf_fangs' own argument for the same choice).
            local carried = false
            for _, t in ipairs(Item.defs.weapon_stag_antlers.traits or {}) do
                if t == "trait_antler_toss" then carried = true end
            end
            assert(carried, "the toss has come off the antlers")
        end,
    },
    {
        name = "herd warmth pays for company and pays nothing at all to a body standing alone",
        fn = function()
            -- THE WHOLE RULE, BEHAVIOURALLY. The apex heals by WALKING and heals whoever stands on what
            -- it left; this heals by STANDING and heals only itself. Paying a lone animal would make
            -- every solitary stag an attrition sink, and nothing else in the suite reads this branch.
            -- (It used to name the lone-stag encounter as the case that would break; that blueprint is
            -- deleted -- it fielded encounter_the_herd's cast at a smaller count -- and this rule is
            -- exactly why deleting it cost nothing: warmth was worth zero there by construction.)
            local c = walkableCombat()
            local alone = { char = Character.instantiate(LESSER), side = "enemy", alive = true,
                            x = 2, y = 2, statuses = {} }
            local left = { char = Character.instantiate(LESSER), side = "enemy", alive = true,
                           x = 8, y = 8, statuses = {} }
            local right = { char = Character.instantiate(LESSER), side = "enemy", alive = true,
                            x = 9, y = 8, statuses = {} }
            c.units = { alone, left, right }
            -- A unit's traits are collected once, when it joins the field (models/trait.lua), and
            -- these three were built by hand. Without this the herd rule is attached to nobody and
            -- every assertion below passes by measuring a body that carries nothing.
            local Trait = require("models.trait")
            for _, u in ipairs(c.units) do
                Trait.attach(u, c)
                u.char.stats.health.current = 20
            end
            assert(Trait.has(left, "trait_herd_warmth"), "the harness did not attach the herd rule")

            Combat.regenerate(c, 5)

            assert(alone.char.stats.health.current == 20, string.format(
                "a stag standing on its own mended to %d: the herd rule pays a lone animal",
                alone.char.stats.health.current))
            local gained = left.char.stats.health.current - 20
            assert(gained > 0, "two stags standing together mended nothing")
            assert(right.char.stats.health.current - 20 == gained,
                "the rule is not mutual: only one of the pair mended")
            -- FLAT, NOT PER-ALLY (see the trait's header): a herd of four must not heal its middle
            -- body three times over, which on a fight already carrying a recorded overrun would be an
            -- attrition sink rather than a decision.
            local third = { char = Character.instantiate(LESSER), side = "enemy", alive = true,
                            x = 8, y = 9, statuses = {} }
            third.char.stats.health.current = 20
            Trait.attach(third, c)
            c.units[#c.units + 1] = third
            left.char.stats.health.current = 20
            Combat.regenerate(c, 5)
            assert(left.char.stats.health.current - 20 == gained, string.format(
                "a stag with two neighbours mended %d against one neighbour's %d -- the rate scales "
                .. "with the herd", left.char.stats.health.current - 20, gained))
        end,
    },
    {
        name = "the lesser stag's own kit is creature kit, and what it drops is not",
        fn = function()
            -- docs/bestiary.md's rule: creature kit carries no axis at all, so neither the drop pool
            -- nor a counter can mint an animal's own rack or its herd.
            for _, id in ipairs({ "weapon_stag_antlers", "utility_herd_warmth" }) do
                local def = Item.defs[id]
                assert(def, id .. " does not exist")
                assert(def.class == "creature", id .. " is not creature kit")
                assert(def.price == nil and def.unlockLevel == nil,
                    id .. " carries an axis, so the drop pool can mint the animal's own fight")
                assert(def.noSteal, id .. " can be lifted off the animal")
            end

            -- ...and the drops are the opposite: real gear, at real depths, ordered by rarity.
            local last
            for _, id in ipairs(Character.defs[LESSER].drops or {}) do
                local def = Item.defs[id]
                assert(def, "the stag drops " .. id .. ", which does not exist")
                assert(def.class ~= "creature", id .. " is creature kit and cannot be carried home")
                assert(def.unlockLevel, id .. " has no depth, so no floor can pay it")
                assert(def.unstocked, id .. " is still dealt by a counter")
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
        name = "the two drops that are RULES hand over the animal's own, unchanged",
        fn = function()
            -- The split utility_feral_instinct and the Reprisal Quiver already are: a body part cannot
            -- be looted, but a RULE can be learned -- so the player's charm must grant the SAME trait
            -- the animal fights with, or the drop is a lookalike wearing the fight's name.
            -- Quoted ids rather than bare table keys, deliberately: tests/item_coverage_spec.lua
            -- counts an item as covered only when its id appears as a quoted string in a spec, so a
            -- bare key here would leave both of these reading as untested while this case tests them.
            local learned = {
                ["utility_the_close_herd"] = { "trait_herd_warmth", "utility_herd_warmth" },
                ["utility_lowered_crown"]  = { "trait_antler_toss", "weapon_stag_antlers" },
            }
            for id, pair in pairs(learned) do
                local trait, source = pair[1], pair[2]
                local def = Item.defs[id]
                assert(def, id .. " is gone")
                local has, from = false, false
                for _, t in ipairs(def.traits or {}) do if t == trait then has = true end end
                for _, t in ipairs(Item.defs[source].traits or {}) do if t == trait then from = true end end
                assert(has, id .. " no longer grants " .. trait)
                assert(from, source .. " no longer carries " .. trait .. ", so the drop teaches nothing")
                -- A learned rule is carryable by construction: the animal's copy is noSteal and the
                -- player's must not be, or the drop cannot reach a grid.
                assert(not def.noSteal, id .. " cannot be picked up")
                assert(def.class ~= "creature", id .. " is on no shelf")
            end
        end,
    },
    {
        name = "armor_bellowhide keeps the animal's resist and leaves the hole on the animal",
        fn = function()
            local hide = Item.defs["armor_bellowhide"]
            assert(hide, "armor_bellowhide is gone")

            -- THE RULE THIS PIECE WAS ALMOST AUTHORED AGAINST. A CREATURE's three physical lines must
            -- sum to zero -- the negative is what buys the positive (docs/bestiary.md) -- but a COAT
            -- plays by different rules: a negative resist amplifies the hit, and a player who picks a
            -- coat up mid-run must not be quietly handed one. tests/armor_spec.lua holds the two
            -- wearable exceptions by name, and this asserts from the other end, on the one piece whose
            -- source body has a negative line sitting right there to be copied.
            local stag = Character.defs[LESSER]
            assert((stag.resist.impact or 0) > 0 and (stag.resist.pierce or 0) < 0,
                "the stag's own line no longer has a half worth keeping and a half worth leaving")
            assert(hide.resist.impact == stag.resist.impact,
                "the hide stopped carrying the animal's own mitigation")
            for _, tag in ipairs({ "slash", "pierce", "impact", "physical" }) do
                assert((hide.resist[tag] or 0) >= 0, string.format(
                    "Bellowhide sells a negative %s: the stag's price belongs on the stag", tag))
            end

            -- Every armour costs a square of pace (docs/classes.md, pinned by tests/armor_spec.lua).
            assert((hide.bonus and hide.bonus.movement or 0) < 0,
                "a coat that costs no pace is a coat with no downside")
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
