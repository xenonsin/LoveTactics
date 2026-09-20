-- A wolf's bite. Four rules ride on it, and together they are what a wolf IS.
--
-- 1. THE STEP BACK. It bites an adjacent foe and immediately gives ground a tile. Because a melee
-- counter is thrown only once the WHOLE action has resolved, and re-checks reach at that point
-- (data/traits/trait_melee_counter.lua, Combat.beginAnswers), stepping back out of adjacency means the
-- bite is answered by nothing: the wolf darts in, takes its bite, and is gone before the jaws can snap
-- back. A blocked step simply doesn't move, and then the wolf eats the counter like anything else --
-- give it room and it never does.
--
-- The step belongs to the TEETH, not to the turn: `hitAndRun` declares it once and both paths honour
-- it -- the effect below on the wolf's own initiative, and Combat.answerStrike when the fangs answer a
-- blow (Feral Instinct's melee counter). A wolf that counters and then stands in reach to be worked
-- over has stopped being a wolf; it bites back and it is gone, whichever way round the exchange began.
--
-- Combat.giveGround, not a knockback: a retreat is the one move whose whole purpose is the gap, so any
-- step that opens the gap serves it. Straight back first, then either sideways lane, and nothing at all
-- when every lane is blocked -- which is why a pack no longer backs into itself, since the tile behind
-- a wolf is very often the next wolf. See models/combat.lua's give-ground section for the full argument.
--
-- 2. IT PULLS DOWN THE WOUNDED. Against prey at or below half health the bite lands heavier AND opens
-- the wound (Bleed, carried inside the damage call -- a status that rides a blow never goes through
-- fx.applyStatus). Every wolf blueprint in this game has carried the comment "a pack pulls down the
-- wounded first" since the week it was written, and an AI rule that presses the lowest-health foe; none
-- of it was true of anything the teeth actually did. This is that sentence, made mechanical.
--
-- Bleed is the right wound for it and not merely a thematic one: it is the game's only POSITIONAL
-- debuff, firing once per tile crossed and never for standing still. So a body the pack has opened has
-- to choose between running from the wolves and paying for every step of it -- which is the same
-- argument the howl makes from the other end (data/status/status_cowering.lua takes your movement;
-- this one prices what movement you have left).
--
-- 3. IT BITES TWICE WHEN IT IS FASTER. Fire Emblem's doubling rule, and the threshold is re-scaled
-- rather than copied: FE's canonical +4 sits on a speed stat running to thirty, and this game's runs
-- 0-9 with the whole cast packed into 3-6. Ported at face value the rule would fire essentially never.
-- At +2 it fires exactly where it should -- a wolf (speed 5) doubles the knight, the fighter, the mage,
-- the paladin and the bulwark (all speed 3) and does not double the rogue, archer, duelist, monk or
-- thief (all speed 5). An alpha (6) doubles the same five and no one else.
--
-- WHICH IS THE INTERESTING HALF, because it cuts against rule 2 and against the armour math. Defense is
-- subtracted from EACH instance of damage (Combat.mitigatedDamage runs per hit), so two small bites
-- lose far more to a plate coat than one big one does. The wolf doubles your armoured line, where each
-- bite is nearly all absorbed, and single-bites your soft line, where each bite lands almost whole.
-- There is no dominant target; there is a read.
--
-- Read off Combat.flatStat, so gear and statuses count -- a +speed charm really does buy you out of
-- being doubled, and a Hasted wolf really does earn it. Both sides must be legible or nothing doubles:
-- the tooltip's dry run swings at a dummy body, and a forecast is not the place to guess.
--
-- The doubling is on the TURN, not on the answer. Combat.answerStrike calls Combat.dealDamage directly
-- rather than running this effect, so a counter is one bite, always -- a wolf's reflex is a snap, not a
-- flurry.
--
-- 4. IT RUNS WITH THE PACK. `trait_runs_with_the_pack` rides the teeth rather than a separate charm
-- because every wolf carries these and nothing else does (utility_feral_instinct is shared with the
-- boar, the bear and the stag, so tagging that one would hand the pack aura to half the wilds). The
-- trait reads outward for a lead -- an Alpha Wolf's ring, or the White Wolf's whole board -- and is
-- worth nothing to a wolf standing alone. See data/traits/trait_pack_lead.lua.
--
-- Distinct from the still bite of data/items/weapon/weapon_fangs.lua, which a stag or boar makes
-- standing its ground. The White Wolf carries her own teeth (weapon_white_wolf_fangs.lua): the same
-- weapon with the doubling swapped for a count of her pack.
local Curve = require("models.curve")

local GIVE_GROUND = 1   -- tiles, stated once so the bite and the counter can never drift apart
local DOUBLE_GAP = 2    -- speed advantage needed to bite twice (FE's rule, re-scaled -- see the header)
local WOUNDED = 0.5     -- "the wounded": at or below half health
local WOUNDED_BONUS = 4 -- extra damage against one, on top of opening the wound

-- A body's effective speed, or nil when it cannot be read. Nil is a REFUSAL, not a zero: the inventory
-- tooltip dry-runs this effect against a stand-in target, and a forecast that invented a doubling
-- because a dummy read as speed 0 would be a promise the board never keeps.
local function speedOf(unit)
    if not (unit and unit.char and unit.char.stats) then return nil end
    local Combat = require("models.combat") -- inside the call: a data file must not close a load cycle
    local v = Combat.flatStat(unit, "speed")
    return (type(v) == "number") and v or nil
end

return {
    name = "Fangs",
    description = "Bites an adjacent foe, then gives ground a tile. Bites twice when much faster, and tears at wounded prey.",
    flavor = "A wolf is born holding it. It does not trade blows; it takes one and is gone.",
    sprite = "assets/items/fangs.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "bite", "physical", "melee" },
    noSteal = true, -- a pickpocket cannot lift the teeth out of a wolf's head
    hitAndRun = GIVE_GROUND, -- gives ground when it ANSWERS a blow too (Combat.answerStrike)
    traits = { "trait_runs_with_the_pack" }, -- see rule 4 in the header
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(5, 15),
        effect = function(fx)
            local target = fx.target
            if not target then return end

            -- Rule 2: the wounded. Built once and handed to both bites, so a doubled attack on failing
            -- prey is two heavy bites rather than one of each.
            local hp = target.char and target.char.stats and target.char.stats.health
            local wounded = hp and hp.max and hp.max > 0 and (hp.current / hp.max) <= WOUNDED
            local function blow()
                if not wounded then return {} end
                return { amount = (fx.amount or 0) + WOUNDED_BONUS, inflicts = "status_bleed" }
            end

            fx.damage(target, blow())

            -- Rule 3: the second bite. Nothing to bite twice if the first one finished it.
            local mine, theirs = speedOf(fx.user), speedOf(target)
            if target.alive and mine and theirs and (mine - theirs) >= DOUBLE_GAP then
                fx.damage(target, blow())
            end

            -- Rule 1: give ground a tile away from the foe just bitten -- ONCE, however many times the
            -- teeth landed. Out of adjacency, the melee counter that would answer this finds nothing in
            -- reach to answer (see the header).
            fx.retreat(target, GIVE_GROUND)
        end,
    },
}
