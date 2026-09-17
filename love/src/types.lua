local M = {}

-- Block: {id, x, y, color, value, jolly}
-- Special: {id, x, y, kind, expiresAt}

M.PENDING_KINDS = {grow=true, jolly=true, clone=true}
M.INSTANT_KINDS = {laser=true, levelup=true, points=true}

function M.isPendingKind(k) return M.PENDING_KINDS[k] end
function M.isInstantKind(k) return M.INSTANT_KINDS[k] end

return M
