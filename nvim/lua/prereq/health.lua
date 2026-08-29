-- Surfaced by :checkhealth prereq
local prereq = require("prereq")

return {
    check = function()
        vim.health.start("external tools")
        local missing = {}
        for _, r in ipairs(prereq.missing()) do
            missing[r.bin] = true
        end

        for _, r in ipairs(prereq.requirements) do
            local line = ("%s -- %s"):format(r.bin, r.why)
            if not missing[r.bin] then
                vim.health.ok(line)
            elseif r.pkg then
                vim.health.warn(line, { "./setup.sh installs it (brew formula: " .. r.pkg .. ")" })
            else
                vim.health.warn(line, { r.manual })
            end
        end

        if next(missing) then
            vim.health.info("run ./setup.sh from the nvim config repo to install them")
        end
    end,
}
