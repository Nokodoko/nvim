local status_ok, notify = pcall(require, "notify")
if not status_ok then
    return
end

local setup = {
    background_colour = "#000000",
    notify = false,
}

notify.setup(setup)
