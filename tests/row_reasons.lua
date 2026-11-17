-- The picker asks the kind about this row, not just its historical type.
-- These invented kinds exercise the registry contract independently of
-- any one detection and keep existing string reasons working unchanged.

local T = ...
local ns = T.Boot()
local Eq, Check, Section = T.Eq, T.Check, T.Section
local F = T.F

Section("static, row-dependent and absent picker reasons")

ns.Rows.Register("reason_static", { reason = "a fixed reason" })
ns.Rows.Register("reason_evidence", { reason = function(row)
    return row.context and row.context.confirmed and "a confirmed encounter" or "an older encounter"
end })
ns.Rows.Register("reason_empty", { reason = function() return "" end })
ns.Rows.Register("reason_invalid", { reason = function() return false end })

Eq(ns.Rows.Reason({ type = "reason_static" }), "a fixed reason", "existing string reason")
Eq(ns.Rows.Reason({ type = "reason_evidence" }), "an older encounter", "missing context remains usable")
Eq(ns.Rows.Reason({ type = "reason_evidence", context = { confirmed = true } }),
    "a confirmed encounter", "the actual row reaches its reason")
Eq(ns.Rows.Reason({ type = "reason_empty" }), nil, "empty reason keeps the picker fallback")
Eq(ns.Rows.Reason({ type = "reason_invalid" }), nil, "a non-string never reaches the UI")
Eq(ns.Rows.Reason({ type = "reason_unknown" }), nil, "unknown kinds retain the fallback")
Eq(ns.Rows.Reason(nil), nil, "an absent row has no reason")

Section("the picker renders reasons rather than function values")

T.BlankDiary()
T.mock.ClearUnits()
T.mock.SetUnit("player", F.SELF)
ns.Characters.Observe(F.STRANGER.guid, { first = "Bram" })
ns.Characters.Observe(F.FRIEND.guid, { first = "Numa" })
ns.Interactions.Add(F.STRANGER.guid, "reason_evidence", { context = { confirmed = true } })
ns.Interactions.Add(F.FRIEND.guid, "reason_static", {})
local found = {}
for _, candidate in ipairs(ns.Candidates()) do found[candidate.guid] = candidate.why end
Eq(found[F.STRANGER.guid], "a confirmed encounter", "the picker uses the row's evidence")
Eq(found[F.FRIEND.guid], "a fixed reason", "the picker keeps its old static reason")
Check(type(found[F.STRANGER.guid]) == "string", "the picker never receives a function")
