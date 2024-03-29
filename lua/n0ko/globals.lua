P = function (v)
    print(vim.inspect(v))
    return v
end

RELOAD = function (...)
  return require("plenary.reload").reload.module(...)
end

R = function (name)
    RELOAD(name)
   return require(name)
end

Print = function (tbl)
    for _, v in ipairs(tbl) do
        print(v)
    end
end
