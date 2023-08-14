
--[[
-- Things we need:
-- 1) Define what mappings look like
-- 2) How will we insert (push) new keybinds per layer
-- 2) workflow for pushing and poping
--
-- user actions:
-- lua require("keylayer").push("mode_1", n, {
-- ["<leader>st"] = "echo 'hi'"
-- ["<leader>sz"] = "echo 'bye'"
-- })
-d ...
-- lua require("keylayer").pop("mode_1"{
-- going to need all of the elements in the object (table) of a keymap -> so you can make a datatype and marshal/unmarhsal the values
-- ...
-- })
--]]--

-- usefulfor making a setup funciton for user
--M.setup = function (opts)
--    print("opts:", opts)
--end


-- ** do i need to use vim.api now?
-- 1. save mappings 
-- 2. Call map
-- 3. Call saved mappings back
-- How to create new keymaps -> vim.api.nvim_set_keymap
-- ((global keymaps))

-- How to get keymaps -> vim.api.nvim_get_keymap
-- ((buffer keymaps))
--check out how plenary can open a new instance of vim without changing state of the current instance - userful for keymaps

local M = {}

local find_mapping = function (maps, lhs)
    for _, value in ipairs(maps)do
        if value.lhs == lhs then
            return value
        end
    end
end


M._stack = {}

M.push = function (name, mode, mappings)
    local maps = vim.api.nvim_get_keymap(mode)

    local existing_maps = {}
    for lhs, rhs in pairs(mappings) do
        local existing = find_mapping(maps, lhs)
        if existing then
            table.insert(existing_maps, existing)
        end
    end
    M._stack[name] = existing_maps

    for lhs, rhs in pairs(mappings) do
        vim.keymap.set(mode, lhs, rhs)
    end
end


M.pop =function (name)
    -- code
end


--test
M.push("debug_mode", "n", {
     ["<F9>"] = "echo 'hi'",
     --["<F3>"] = "echo 'bye'",
     --["<leadedr>sz"] = "echo 'bye'"
})

return M
