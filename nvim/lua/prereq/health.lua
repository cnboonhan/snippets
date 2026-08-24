-- Surfaced by :checkhealth prereq
local prereq = require("prereq")

return {
    check = function()
        vim.health.start("homebrew")
        local brew = prereq.brew()
        if brew then
            vim.health.ok(brew)
        else
            vim.health.error("brew not found on $PATH or in the usual prefixes",
                prereq.brew_install_hint)
        end

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
                vim.health.warn(line, { ("%s install %s"):format(brew or "brew", r.pkg) })
            else
                vim.health.warn(line, { r.manual })
            end
        end

        if next(missing) then
            vim.health.info("run :PrereqInstall to install the formulae brew carries")
        end
    end,
}
