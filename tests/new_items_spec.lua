-- Tests for the new tactical kit added on top of the summon/status/trait systems: the AoE control
-- bombs, the priest's Banish and Renewal, the banner aura, the Wolfsong Horn's charged Quieting Howl
-- and the wolf's hit-and-run bite, and the rule that a hard-controlled unit cannot react. Pure logic,
-- runs headless. See tests/summon_spec.lua for the fixture style these borrow.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Summon = require("models.summon")
local Status = require("models.status")
local Hazard = require("models.hazard")

local function arena(cols, rows, objective)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = objective or { type = "killAll" } }
end

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

local function itemNamed(char, id)
    for i = 1, Character.MAX_INVENTORY do
        local it = char.inventory[i]
        if it and it.id == id then return it end
    end
    return nil
end

local function equip(char, ids)
    char.inventory = {}
    for _, id in ipairs(ids) do Character.addItem(char, Item.instantiate(id)) end
end

-- A character stripped of its blueprint kit. What a spec wants when the stock inventory would answer
-- for the body: a knight's reflexes (Parry, a guard that takes an adjacent ally's blow) would otherwise
-- intercept the very thing being measured.
local function bare(id)
    local char = Character.instantiate(id)
    char.inventory = {}
    return char
end

-- Plant a banner at (x, y) and lay the 3x3 zone it owns, exactly as the banner abilities do
-- (data/items/ability/ability_rally_banner.lua) -- without going through the item, so a spec can put
-- one on the board in one line. Returns the banner unit.
local function plantBanner(c, summoner, x, y, zoneId)
    local banner = Summon.spawn(c, summoner, "character_banner", x, y, { control = "none", timeless = true })
    for dy = -1, 1 do
        for dx = -1, 1 do
            Hazard.place(c, x + dx, y + dy, zoneId, { side = banner.side, owner = banner })
        end
    end
    return banner
end

return {
    {
        name = "the Ice Bomb freezes everything in its 3x3 blast",
        fn = function()
            local thrower = Character.instantiate("character_knight")
            equip(thrower, { "consumable_ice_bomb" })
            local c = Combat.new(arena(8, 8), { unit(thrower, 2, 2) },
                { unit("character_bandit", 4, 2), unit("character_bandit", 4, 3) })
            local a, b = c.units[2], c.units[3]
            openTurn(c, c.units[1])

            assert(Combat.useItem(c, c.units[1], itemNamed(thrower, "consumable_ice_bomb"), 4, 2), "the bomb bursts")
            assert(Status.has(a, "status_freeze"), "the foe at the center is frozen")
            assert(Status.has(b, "status_freeze"), "and so is the one caught at the edge of the blast")
        end,
    },
    {
        name = "the Lightning Bomb stuns everything in its 3x3 blast",
        fn = function()
            local thrower = Character.instantiate("character_knight")
            equip(thrower, { "consumable_lightning_bomb" })
            local c = Combat.new(arena(8, 8), { unit(thrower, 2, 2) },
                { unit("character_bandit", 4, 2), unit("character_bandit", 4, 3) })
            openTurn(c, c.units[1])

            assert(Combat.useItem(c, c.units[1], itemNamed(thrower, "consumable_lightning_bomb"), 4, 2), "the bomb bursts")
            -- Stun's badge is short (5 ticks) and the bomb's own turn resolving ages it past that, so we
            -- read the application from the log rather than the badge: both foes in the blast were stunned
            -- (the lasting effect -- the initiative shove from onApply -- has already landed permanently).
            local stunned = 0
            for _, e in ipairs(c.log) do
                if e.text:find("afflicted with Stun") then stunned = stunned + 1 end
            end
            assert(stunned == 2, "both foes in the blast were stunned, got " .. stunned)
        end,
    },
    {
        name = "Renewal grants an ally Regeneration",
        fn = function()
            local priest = Character.instantiate("character_priest")
            equip(priest, { "ability_renewal" })
            local c = Combat.new(arena(8, 8), { unit(priest, 2, 2), unit("character_knight", 3, 2) },
                { unit("character_bandit", 8, 8) })
            local ally = c.units[2]
            openTurn(c, c.units[1])

            assert(Combat.useItem(c, c.units[1], itemNamed(priest, "ability_renewal"), 3, 2), "the grace lands")
            assert(Status.has(ally, "status_regen"), "the ally is regenerating")
        end,
    },
    {
        name = "a hard-controlled beast cannot counter a melee blow",
        fn = function()
            -- A wolf carries Feral Instinct (melee_counter): struck in melee, it bites straight back.
            local without = Combat.new(arena(8, 8), { unit("character_wolf_grunt", 3, 2) }, { unit("character_bandit", 2, 2) })
            local wolf, bandit = without.units[1], without.units[2]
            local hp0 = bandit.char.stats.health.current
            Combat.dealFlatDamage(without, wolf, 5, { "physical" }, nil, bandit)
            assert(bandit.char.stats.health.current < hp0, "unhindered, the struck beast counters")

            -- The same blow, but the beast is stunned first: its reflex is shut down and it eats the hit.
            local with = Combat.new(arena(8, 8), { unit("character_wolf_grunt", 3, 2) }, { unit("character_bandit", 2, 2) })
            local wolf2, bandit2 = with.units[1], with.units[2]
            Status.apply(with, wolf2, "status_stun")
            local hp1 = bandit2.char.stats.health.current
            Combat.dealFlatDamage(with, wolf2, 5, { "physical" }, nil, bandit2)
            assert(bandit2.char.stats.health.current == hp1, "a stunned beast cannot counter")
        end,
    },
    {
        name = "a Banner's ground inspires allies in the 3x3 around it, but not foes or itself",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_archer", 2, 2), unit("character_knight", 5, 4) },
                { unit("character_bandit", 6, 4) })
            local archer, knight, bandit = c.units[1], c.units[2], c.units[3]

            -- Plant a rally banner beside the knight (and one tile from the bandit).
            local banner = plantBanner(c, archer, 4, 4, "hazard_rally")

            assert(Status.has(knight, "status_inspiration"), "the ally standing in its square is inspired")
            assert(Status.statBonus(knight, "damage") == 4, "which raises its Damage")
            assert(not Status.has(bandit, "status_inspiration"), "the enemy in the square gets nothing")
            assert(not Status.has(banner, "status_inspiration"), "and the banner does not rally itself")
        end,
    },
    {
        name = "a Banner's Inspiration is zone-bound: it does not age, and ends the beat an ally leaves",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_archer", 2, 2), unit(bare("character_knight"), 5, 4) },
                { unit("character_bandit", 8, 8) })
            local archer, knight = c.units[1], c.units[2]
            plantBanner(c, archer, 4, 4, "hazard_rally")
            assert(Status.has(knight, "status_inspiration"), "the knight starts in the banner's shadow")

            -- Far longer than Inspiration's own duration (8): a zone-bound status does not age, so
            -- standing put holds it indefinitely rather than letting it lapse under the banner.
            Status.tick(c, 50)
            Hazard.tick(c, 50)
            assert(Status.has(knight, "status_inspiration"), "it holds while the knight stands in the square")

            -- Step out of the square (x 3..5): gone on that beat, not `duration` ticks later.
            openTurn(c, knight)
            assert(Combat.moveUnit(c, knight, 6, 4), "the knight steps clear of the banner's shadow")
            assert(not Status.has(knight, "status_inspiration"), "and its Inspiration ends the instant it does")
        end,
    },
    {
        name = "cutting down a Banner takes its ground, and the rally with it",
        fn = function()
            -- A BARE knight: a blueprint's stock kit carries a guard reflex, and Combat.dealFlatDamage
            -- offers an adjacent guardian the blow first -- so a kitted knight standing in the square
            -- would throw itself in front of the axe and the banner would never fall at all.
            local c = Combat.new(arena(8, 8), { unit("character_archer", 2, 2), unit(bare("character_knight"), 5, 4) },
                { unit("character_bandit", 8, 8) })
            local archer, knight, bandit = c.units[1], c.units[2], c.units[3]
            local banner = plantBanner(c, archer, 4, 4, "hazard_rally")
            assert(Status.has(knight, "status_inspiration"), "the knight is inspired while it stands")

            -- Cut the standard down. Its ground goes on the same beat (Hazard.dropOwnedBy)...
            Combat.dealFlatDamage(c, banner, 9999, { "physical" }, nil, bandit)
            assert(not banner.alive, "the banner falls")
            assert(not Hazard.at(c, 5, 4, "hazard_rally"), "and its square stops being rallying ground")

            -- ...and the buff unwinds by the ordinary rule, with nobody having moved at all.
            Hazard.tick(c, 1)
            assert(not Status.has(knight, "status_inspiration"),
                "the rally ends for an ally who never moved, because the ground under it is gone")
        end,
    },
    {
        name = "a Banner is an object, not a combatant: it never appears in the turn order",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_archer", 2, 2) }, { unit("character_bandit", 6, 4) })
            local archer = c.units[1]
            local banner = Summon.spawn(c, archer, "character_banner", 4, 4, { control = "none", timeless = true })

            assert(banner.alive, "the standard stands on the board")
            assert(Combat.unitAt(c, 4, 4) == banner, "and holds its tile like any other body")
            for _, u in ipairs(Combat.turnOrder(c)) do
                assert(u ~= banner, "but it takes no slot in the turn order")
            end
            for _, e in ipairs(Combat.buildTimeline(c, {})) do
                assert(e.unit ~= banner, "nor a card in the timeline strip the player reads")
            end
        end,
    },
    {
        name = "a Banner outside the timeline does not stall the combat clock",
        fn = function()
            -- The banner is never charged an initiative, so were it still counted in Combat.rebase's
            -- minimum it would sit at 0 forever, pin the rebase amount to 0, and freeze every status,
            -- hazard and summon duration in the battle.
            local c = Combat.new(arena(8, 8), { unit("character_knight", 2, 2) }, { unit("character_bandit", 6, 4) })
            local knight = c.units[1]
            local banner = Summon.spawn(c, knight, "character_banner", 4, 4, { control = "none", timeless = true })

            -- Push every real combatant off 0 (whatever the field holds), leaving the knight soonest.
            for _, u in ipairs(c.units) do
                if not u.timeless then u.initiative = 9 end
            end
            knight.initiative = 7
            local bannerInit, before = banner.initiative, c.clock

            Combat.rebase(c)
            assert(c.clock == before + 7, "the clock still advances by the soonest real actor's initiative")
            assert(knight.initiative == 0, "and the next real actor rebases to 0")
            assert(banner.initiative == bannerInit, "the banner is left out of the rebase entirely")
        end,
    },
    {
        name = "Banish unmakes summoned creatures in its blast but leaves real ones",
        fn = function()
            local mage = Character.instantiate("character_mage")
            equip(mage, { "ability_banish" })
            local c = Combat.new(arena(8, 8), { unit(mage, 4, 4) }, { unit("character_bandit", 5, 6) })
            local bandit = c.units[2]
            local wolf = Summon.spawn(c, bandit, "character_wolf_grunt", 6, 6) -- an enemy conjuration
            openTurn(c, c.units[1])

            assert(Combat.useItem(c, c.units[1], itemNamed(mage, "ability_banish"), 6, 6), "the word of unmaking lands")
            assert(not wolf.alive, "the summoned wolf is banished")
            assert(bandit.alive, "but the real bandit in the blast is untouched")
        end,
    },
    {
        name = "the Wolfsong Horn charges as the wolf draws blood, and only sounds while the wolf lives",
        fn = function()
            local c = Combat.new(arena(10, 10),
                { unit("character_archer", 5, 5) },
                { unit("character_bandit", 5, 9) }) -- prey for the wolf to bite
            local u = c.units[1]
            local wolf = u.wolfCompanion
            assert(wolf and wolf.char.id == "character_wolf_grunt", "a wolf answers the horn at the opening bell")
            local horn = itemNamed(u.char, "utility_wolfsong_horn")

            -- Silent from the start: no blood drawn yet, so the howl is still locked.
            local blocked = Combat.itemBlockReason(u, horn)
            assert(blocked and blocked.kind == "locked", "the horn will not sound until the wolf has drawn blood")

            -- The wolf's blow banks onto the archer that fields it (companionDamage routes to the summoner).
            Combat.teleportUnit(c, wolf, 5, 8)
            openTurn(c, wolf)
            assert(Combat.useItem(c, wolf, itemNamed(wolf.char, "weapon_wolf_fangs"), 5, 9), "the wolf bites")
            assert(Combat.tallyCount(u, "companionDamage") > 0, "and the archer's horn feels every drop it draws")

            -- Brimmed AND the wolf alive: the howl is ready.
            Combat.tally(u, "companionDamage", 40)
            assert(Combat.itemBlockReason(u, horn) == nil, "brimmed over a living wolf, the horn is ready")

            -- The wolf falls: it cannot be resummoned, and the horn falls silent with it.
            Combat.dealFlatDamage(c, wolf, 9999, {}, "test")
            assert(not wolf.alive, "the wolf is cut down")
            local silenced = Combat.itemBlockReason(u, horn)
            assert(silenced and silenced.kind == "locked", "a dead wolf silences the horn, brimmed or not")
            openTurn(c, u)
            assert(not Combat.useItem(c, u, horn, u.x, u.y), "and it will not sound without the wolf")
        end,
    },
    {
        name = "the Quieting Howl roots every foe within two tiles of Kaya or her wolf, and spares the distant",
        fn = function()
            local c = Combat.new(arena(16, 16),
                { unit("character_archer", 5, 5) },
                { unit("character_bandit", 5, 7),   -- two tiles from Kaya
                  unit("character_bandit", 10, 11), -- one tile from where the wolf will stand
                  unit("character_bandit", 1, 1) }) -- far from both
            local u = c.units[1]
            local wolf = u.wolfCompanion
            Combat.teleportUnit(c, wolf, 10, 10)
            local nearKaya, nearWolf, distant
            for _, x in ipairs(c.units) do
                if x.char.id == "character_bandit" then
                    if x.x == 5 and x.y == 7 then nearKaya = x
                    elseif x.x == 10 and x.y == 11 then nearWolf = x
                    else distant = x end
                end
            end
            Combat.tally(u, "companionDamage", 40)
            openTurn(c, u)
            assert(Combat.useItem(c, u, itemNamed(u.char, "utility_wolfsong_horn"), u.x, u.y), "the horn sounds")
            assert(Status.has(nearKaya, "status_root"), "the foe near Kaya is rooted")
            assert(Status.has(nearWolf, "status_root"), "the foe near the wolf is rooted")
            assert(not Status.has(distant, "status_root"), "the distant foe is spared")
        end,
    },
    {
        name = "a wolf's bite gives ground and slips the melee counter",
        fn = function()
            -- Attacker: a party wolf. Defender: another wolf, which carries the melee counter (Feral Instinct).
            local c = Combat.new(arena(10, 10),
                { unit("character_wolf_grunt", 4, 4) },
                { unit("character_wolf_grunt", 5, 4) })
            local attacker = c.units[1]
            local defender
            for _, x in ipairs(c.units) do
                if x ~= attacker and x.char.id == "character_wolf_grunt" then defender = x end
            end
            local hpBefore = attacker.char.stats.health.current
            openTurn(c, attacker)
            assert(Combat.useItem(c, attacker, itemNamed(attacker.char, "weapon_wolf_fangs"), 5, 4), "the wolf bites")
            -- It stepped a tile straight back from the foe it bit...
            assert(attacker.x == 3 and attacker.y == 4,
                "the wolf gives ground, got " .. attacker.x .. "," .. attacker.y)
            -- ...so the defender's held melee counter, re-checked against the final board, finds nothing in reach.
            assert(attacker.char.stats.health.current == hpBefore, "the counter whiffs; the wolf is untouched")
            assert(defender.char.stats.health.current < defender.char.stats.health.max, "the bite still landed")
        end,
    },
}
