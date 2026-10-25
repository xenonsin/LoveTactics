-- BONDS ON THE BOARD (models/combat.lua's bond block, models/bond.lua). Holds what the review approved:
--
--   * a ranked partner within RANGE of the living avatar gains Hit and Avoid, and nothing out of range;
--   * Trade Places (B) swaps tiles and spends the move, not the action -- once a fight;
--   * Teamwork (B) ends the avatar's turn and the partner acts next -- once a fight;
--   * an A partner beside the foe follows up the avatar's blow, free, once a round, and the forecast says so;
--   * a covering deed (a blow taken for the other) is banked on the fight's ledger;
--   * all of it travels as a `bond` command, so a peer resolves the same board.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Command = require("models.command")
local Bond = require("models.bond")
local Status = require("models.status")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do tiles[y][x] = { type = "ground", moveCost = 1, walkable = true } end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function armed(id)
    local ch = Character.instantiate(id)
    ch.inventory[1] = Item.instantiate("weapon_iron_sword")
    return ch
end

-- The avatar at (2,2), a partner at (px,py) with `rank`, a bandit at (fx,fy). Bonds stamped before the
-- fight opens, as the battle screen does.
local function fight(rank, px, py, fx, fy)
    local c = Combat.new(arena(10, 6),
        { { char = armed("character_avatar"), x = 2, y = 2 }, { char = armed("character_rowan"), x = px, y = py } },
        { { char = Character.instantiate("character_bandit"), x = fx or 9, y = fy or 5 } },
        { deferOpen = true })
    c.bonds = { character_rowan = rank }
    Combat.openBattle(c)
    local avatar, rowan, foe = c.units[1], c.units[2], c.units[3]
    return c, avatar, rowan, foe
end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

return {
    {
        name = "a ranked partner near the avatar gains its rank's Hit and Avoid, and none out of range",
        fn = function()
            local c, avatar, rowan = fight("B", 3, 2)
            assert(Combat.bondBonus(c, rowan) == Bond.HIT.B, "Rowan beside the avatar should get +" .. Bond.HIT.B)
            assert(Combat.bondBonus(c, avatar) == 0, "the avatar lends, it does not borrow")
            rowan.x, rowan.y = 8, 5
            assert(Combat.bondBonus(c, rowan) == 0, "out of range: nothing")
            rowan.x, rowan.y = 3, 2
            avatar.alive = false
            assert(Combat.bondBonus(c, rowan) == 0, "a fallen avatar lends nothing")
        end,
    },
    {
        name = "the bonus moves the real Hit and Avoid figures",
        fn = function()
            local c, _, rowan, foe = fight("A", 3, 2, 4, 2)
            local weapon = Combat.defaultWeapon(rowan.char)
            local near = Combat.hitChance(c, rowan, foe, weapon)
            local nearAvoid = Combat.avoid(c, rowan)
            c.bonds = {}
            local bare = Combat.hitChance(c, rowan, foe, weapon)
            local bareAvoid = Combat.avoid(c, rowan)
            assert(nearAvoid - bareAvoid == Bond.HIT.A, "Avoid should rise by the A bonus")
            assert(near >= bare, "Hit should not fall")
        end,
    },
    {
        name = "Trade Places swaps tiles, spends the move not the action, and only once a fight",
        fn = function()
            local c, avatar, rowan = fight("B", 5, 2)
            openTurn(c, avatar)
            local targets = Combat.bondVerbTargets(c, avatar, "trade")
            assert(#targets == 1 and targets[1] == rowan, "Rowan within 4 is the one trade partner")
            local result = Command.apply(c, avatar, { kind = "bond", verb = "trade", target = 2 })
            assert(result, "the trade command should apply")
            assert(avatar.x == 5 and rowan.x == 2, "the two traded tiles")
            assert(c.turn.moved and c.turn.unit == avatar, "the move is spent and the turn is still open")
            assert(#Combat.bondVerbTargets(c, avatar, "trade") == 0, "once a fight")
        end,
    },
    {
        name = "C rank opens no verb; nobody but the avatar has one",
        fn = function()
            local c, avatar, rowan = fight("C", 3, 2)
            openTurn(c, avatar)
            assert(#Combat.bondVerbTargets(c, avatar, "trade") == 0)
            assert(#Combat.bondVerbTargets(c, avatar, "teamwork") == 0)
            c.bonds.character_rowan = "B"
            openTurn(c, rowan)
            assert(#Combat.bondVerbTargets(c, rowan, "trade") == 0, "Rowan has no verbs of her own")
        end,
    },
    {
        name = "Teamwork ends the avatar's turn and puts the partner next",
        fn = function()
            local c, avatar, rowan = fight("B", 3, 2)
            openTurn(c, avatar)
            avatar.initiative, rowan.initiative = 0, 40
            local result = Command.apply(c, avatar, { kind = "bond", verb = "teamwork", target = 2 })
            assert(result and result.acted, "teamwork should end the turn")
            assert(Combat.turnOrder(c)[1] == rowan, "Rowan acts next")
            assert(avatar.bondUsed and avatar.bondUsed.teamwork, "spent for the fight")
        end,
    },
    {
        name = "an illegal bond command is refused by validation",
        fn = function()
            local c, avatar = fight("B", 9, 1)
            openTurn(c, avatar)
            assert(not Command.validate(c, avatar, { kind = "bond", verb = "trade", target = 2 }), "too far")
            assert(not Command.wellFormed({ kind = "bond", verb = "hug", target = 2 }), "unknown verb")
        end,
    },
    {
        name = "an A partner beside the foe follows up the avatar's blow, once a round, and the forecast names it",
        fn = function()
            -- Avatar (2,2) strikes the bandit at (3,2); Rowan stands at (3,3), beside it.
            local c, avatar, rowan, foe = fight("A", 3, 3, 3, 2)
            foe.char.stats.health.current, foe.char.stats.health.max = 300, 300
            openTurn(c, avatar)
            local weapon = Combat.defaultWeapon(avatar.char)
            local follows = Combat.previewFollowUps(c, avatar, weapon, foe, {})
            assert(follows and #follows == 1 and follows[1].ally == rowan and follows[1].bond,
                "the forecast should name Rowan's bond follow-up")
            local solo = Combat.computeDamage(c, avatar, foe, weapon)
            local stamina = Combat.resource(rowan.char, "stamina")
            local before = foe.char.stats.health.current
            Combat.dealDamage(c, avatar, foe, weapon)
            assert(before - foe.char.stats.health.current > solo, "Rowan added a blow")
            assert(Combat.resource(rowan.char, "stamina") == stamina, "the bond follow-up is free")
            local mid = foe.char.stats.health.current
            Combat.dealDamage(c, avatar, foe, weapon)
            assert(mid - foe.char.stats.health.current == solo, "only once a round")
            assert(Combat.previewFollowUps(c, avatar, weapon, foe, {}) == nil, "and the forecast agrees")
        end,
    },
    {
        name = "a B partner does not follow up",
        fn = function()
            local c, avatar, _, foe = fight("B", 3, 3, 3, 2)
            foe.char.stats.health.current, foe.char.stats.health.max = 300, 300
            local weapon = Combat.defaultWeapon(avatar.char)
            local solo = Combat.computeDamage(c, avatar, foe, weapon)
            local before = foe.char.stats.health.current
            Combat.dealDamage(c, avatar, foe, weapon)
            assert(before - foe.char.stats.health.current == solo)
        end,
    },
    {
        name = "Stand Firm: the avatar falling surges its A partner",
        fn = function()
            local c, avatar, rowan = fight("A", 3, 2)
            avatar.alive = false
            require("models.trait").onAnyDeath(c, avatar)
            assert(Status.has(rowan, "status_hasted") and Status.has(rowan, "status_aegis"), "Rowan stands firm")
            -- ...and the other way round: the avatar surges when its A partner falls.
            local c2, avatar2, rowan2 = fight("A", 3, 2)
            rowan2.alive = false
            require("models.trait").onAnyDeath(c2, rowan2)
            assert(Status.has(avatar2, "status_hasted"), "the avatar stands firm for Rowan")
            -- A B partner does not.
            local c3, avatar3, rowan3 = fight("B", 3, 2)
            avatar3.alive = false
            require("models.trait").onAnyDeath(c3, avatar3)
            assert(not Status.has(rowan3, "status_hasted"), "Stand Firm is A rank only")
        end,
    },
    {
        name = "covering deeds bank on the fight's ledger for the pair",
        fn = function()
            local c, avatar, rowan = fight(nil, 3, 2)
            c.bonds = {}
            Combat.bondDeed(c, avatar, rowan)
            Combat.bondDeed(c, rowan, avatar)
            assert(c.bondDeeds.character_rowan == 2)
            local foe = c.units[3]
            rowan.lastAttacker = foe
            Combat.bondAvenged(c, avatar, foe)
            assert(c.bondDeeds.character_rowan == 3, "felling the foe that last hit the partner is a deed")
        end,
    },
}
