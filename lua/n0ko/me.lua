local M = {}

local api = vim.api


--functions to look up
--vim.keymap.set()e
--nvim_get_keymap()
--lookup buffer keymaps - would be useful to set keymaps for a buffer

--vim.api (is a table with functions in it)

local find_mappings = function (maps, lhs)
   --pairs: iterates over every key (order not guarenteed -- strings)
    --ipairs: iterates only numberic keys, (order guarenteed)
    for _, value in ipairs(maps) do
        if value.lhs == lhs then
        return value
        end
    end
end

M.push =  function (name, mode, mappings)
    local maps = api.nvim_get_keymap(mode)

    local existing_maps = {}
    for lhs, rhs in pairs(mappings) do
        print("Searching for:", lhs)
        local existing = find_mappings(maps, lhs)
        if existing then
            table.insert(existing_maps, existing)
        end
    end
    P(existing_maps)
end

M.pop = function (name)
   --   
end

M.push("debug_mode", "n", {
    [",st"] = "echo 'hi'",
    [",sz"] = "echo 'bye'",
})

P(find_mappings(maps, ",st"))
P(find_mappings(maps, ",st"))


--lua require("me").push("debug_mode", "n", {
--    [",st"] = "echo 'hi'",
--    [",sz"] = "echo 'hi'",
--})

return M
