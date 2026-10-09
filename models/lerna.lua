-- LERNA: the Lernaean Hydra's rule and the three pieces it hands over, as one model so the heads, the blows they
-- turn into and the pieces built from them read the same facts. Reviewed 2026-10-09 ("The Crown's Bestiary",
-- slice E): the beast that guarded the way down at Lerna, set at the bottom of this one.
--
--   TWO FOR ONE   it opens with three heads, one bite each. An edge (slash) blow worth a tenth of its bar takes
--                 a head, and two grow back (up to 6). Fire or Burn on it cauterises: no head grows for 2 turns
--                 (trait_two_for_one, status_hydra_heads, status_cauterised)
--   TWO HEADS     each slash blow that strikes the wearer banks one more strike on its next attack, up to 3
--                 (trait_two_heads, status_two_heads)
--   CAUTERISE     Burn and an Unclosing Wound together; and an Unclosing Wound now refuses a body standing back
--                 up too (Combat.reanimate), which is what stops an Archon's wisp (models/spirit.lua)
--   HYDRA'S BLOOD the bearer's blows Poison; a Poisoned foe that falls passes its Poison to every foe beside it
--                 (trait_hydras_blood)
--
-- HEADS ARE BITES, AND A BITE IS A STRIKE. The smallest coherent reading of "one bite each": the Hydra's jaws
-- land once per head on the body it bites, each landing its own hit roll -- the brave rule (Item.strikes) that
-- The Second Bite already rides, with the count read off the heads badge rather than off the blueprint. So the
-- hover, the live blow and the badge are one number. The heads are a stack on the body, not units of their own:
-- the Chimera's heads are bodies because each acts on its own turn, and these only add mouths to one.
--
-- THE LAST HEAD DOES NOT COME OFF. A cut while cauterised loses a head and grows none, so a burned hydra can be
-- cut down to one mouth -- never to none. Heracles buried the last one under a rock; it did not stop biting.
--
-- "A TENTH OF ITS BAR" is read as the blow's size: a slash wound of at least 10% of its maximum health. That is a
-- number a player can check against the hover before swinging, where "crossing a tenth-mark" would make the same
-- cut count or not depending on where the bar happened to sit.

local Lerna = {}

Lerna.HEADS = "status_hydra_heads"
Lerna.SEARED = "status_cauterised"
Lerna.TWO_HEADS = "status_two_heads"
Lerna.START = 3
Lerna.MAX = 6
Lerna.MIN = 1
Lerna.GROW = 2
Lerna.CUT_SHARE = 0.1
Lerna.SEAR_TICKS = 10 -- ~2 turns at Status.TICKS_PER_TURN

local function Status() return require("models.status") end
local function Combat() return require("models.combat") end

local function name(u) return (u and u.char and u.char.name) or "It" end

local function hasTag(tags, want)
    for _, t in ipairs(tags or {}) do if t == want then return true end end
    return false
end

-- ------------------------------------------------------------------------------------------- the heads

function Lerna.heads(unit)
    return Status().stacksOf(unit, Lerna.HEADS)
end

local function setHeads(combat, unit, n)
    n = math.max(Lerna.MIN, math.min(Lerna.MAX, n))
    local s = Status().get(unit, Lerna.HEADS)
    if s then s.magnitude = n else Status().apply(combat, unit, Lerna.HEADS, { magnitude = n }) end
    return n
end

-- The bell: three heads.
function Lerna.open(combat, unit)
    if not (unit and unit.alive) then return end
    setHeads(combat, unit, Lerna.START)
end

-- Fire on it, or Burn landing on it: no head grows back for two turns.
function Lerna.sear(combat, unit)
    if not (unit and unit.alive) then return end
    local fresh = not Status().has(unit, Lerna.SEARED)
    Status().apply(combat, unit, Lerna.SEARED, { duration = Lerna.SEAR_TICKS })
    if fresh then
        Combat().logEvent(combat, "status", string.format("%s's necks are cauterised.", name(unit)), unit)
    end
end

-- A blow landed and it lived (trait_two_for_one's onDamaged). Fire sears first, so a burning edge cuts a head
-- and grows none.
function Lerna.struck(combat, unit, amount, tags)
    if not (unit and unit.alive) then return end
    if hasTag(tags, "fire") then Lerna.sear(combat, unit) end
    if not hasTag(tags, "slash") then return end
    local max = Combat().unreservedMax(unit.char, "health")
    if (amount or 0) < math.max(1, math.ceil(max * Lerna.CUT_SHARE)) then return end
    local before = Lerna.heads(unit)
    if Status().has(unit, Lerna.SEARED) then
        local now = setHeads(combat, unit, before - 1)
        Combat().logEvent(combat, "action", now < before
            and string.format("A head comes off %s, and the seared neck grows nothing.", name(unit))
            or string.format("The last head of %s will not come off.", name(unit)), unit)
    else
        local now = setHeads(combat, unit, before - 1 + Lerna.GROW)
        Combat().logEvent(combat, "action",
            string.format("A head comes off %s, and two grow back (%d).", name(unit), now), unit)
    end
end

-- ------------------------------------------------------------------------------------------- the strikes

-- How many times `item`'s swing lands for `unit`: the brave rule (Item.strikes), the Hydra's jaws once per head
-- (`strikesPerHead`), plus whatever Two Heads has banked on a weapon. `consume` spends that bank -- the real cast
-- passes it, the hover never does.
function Lerna.strikes(unit, item, ab, consume)
    local Item = require("models.item")
    local n = Item.strikes(ab)
    if not unit then return n end
    if ab and ab.strikesPerHead then n = math.max(1, Lerna.heads(unit)) end
    if item and item.type == "weapon" then
        local banked = Status().stacksOf(unit, Lerna.TWO_HEADS)
        if banked > 0 then
            n = n + banked
            if consume then Status().remove(unit.combat, unit, Lerna.TWO_HEADS) end
        end
    end
    return n
end

-- A slash blow struck the wearer of Two Heads: one more strike banked, up to the badge's cap.
function Lerna.growHead(combat, unit, tags)
    if not (unit and unit.alive and hasTag(tags, "slash")) then return end
    Status().apply(combat, unit, Lerna.TWO_HEADS)
end

-- ------------------------------------------------------------------------------------------- the blood

-- `fallen` dropped while Poisoned, and `bearer` carries Hydra's Blood: every foe of the bearer beside the body
-- takes Poison. Beside is one step (Combat.unitGap), so a 2x2 body counts every tile around its footprint.
function Lerna.spreadPoison(combat, bearer, fallen)
    if not (combat and bearer and bearer.alive and fallen and fallen.side ~= bearer.side) then return 0 end
    if not Status().has(fallen, "status_poison") then return 0 end
    local n = 0
    for _, u in ipairs(combat.units or {}) do
        if u ~= fallen and u.alive and u.side ~= bearer.side and Combat().unitGap(fallen, u) == 1 then
            if Status().apply(combat, u, "status_poison", { applier = bearer }) then n = n + 1 end
        end
    end
    if n > 0 then
        Combat().logEvent(combat, "status",
            string.format("The poison runs out of %s into the bodies beside it.", name(fallen)), fallen)
    end
    return n
end

return Lerna
