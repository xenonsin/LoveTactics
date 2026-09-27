-- UNMOVED: the Oni Greatblade's (utility_unmoved). The `unmoved` flag makes Status.blocksForcedMove answer yes;
-- the immunities ride the item's own `statusImmunity`.
return {
    name = "Unmoved",
    description = "Cannot be moved by a shove, a pull or a throw.",
    unmoved = true,
    notAReaction = true,
}
