local plp = {}

local sub = string.sub
local ins = table.insert

plp.loaded = {}

function plp.execute(name, t)
    local f = plp.loaded[name]
    if f then
        return f(t)
    end
    return "Not found"
end

local function basename(filename)
    return filename:match"([^/%.]+)%.?[^%.]*$"
end

function plp.compilefiles(filenames)
    for _, filename in ipairs(filenames) do
        local file, err = io.open(filename, "r")
        if err then return nil, err end
        local func, err = plp.compilestring((file:read"*a"))
        if err then return nil, err end
        plp.loaded[filename] = func
        plp.loaded[basename(filename)] = func
    end
end

local parse_error = "Parse error"

function plp.compilestring(s)
    -- allow user to have other echo function
    plp.echo = plp.echo or io.write

    local i = 1

    local pieces = {}
    local last = 1

    local state = "html"

    local function peek(n)
        return sub(s, i, i + (n or 1) - 1)
    end

    local function consume(n)
        i = i + (n or 1)
    end

    if _VERSION == "Lua 5.1" then
        -- If lua5.1 or luajit `_ENV` doesn't exist
        ins(pieces, [[
        local plp = require"plp"
        local echo, execute = plp.echo, plp.execute
        ]])
    end
    ins(pieces, "echo[[")
    while i <= #s do
        if state ~= "html" and (peek() == "'" or peek() == "'") then
            local match = peek()
            repeat
                consume()
                if peek() == "\\" then consume(2) end
            until peek() == match or i > #s
            consume()
        elseif state ~= "html" and peek() == "$" then
            ins(pieces, sub(s, last, i-1))
            -- if is identifier: `$something` becomes `(...).something`
            if string.match(s, "^[_a-zA-Z][_a-zA-Z0-9]*", i+1) then
                ins(pieces, "(...).")
            else -- `execute("template2.html", $)` or `$["lispy-value"]` expands `$` to just `(...)`
                ins(pieces, "(...)")
            end
            consume()
            last=i
        elseif peek(2) == "<?" then
            if state ~= "html" then return nil, parse_error end
            -- strip newline if it precedes
            -- TODO: skip all spaces/tabs before too?
            ins(pieces, sub(s, last, i-(sub(s,i-1,i-1) == "\n" and 2 or 1)))
            ins(pieces, "]]")
            consume(2)
            if peek() == "=" then
                state="inline"
                ins(pieces, "echo((")
                consume()
            elseif peek(3) == "lua" then
                state="block"
                consume(3)
            else
                return nil, parse_error
            end
            last=i
        elseif peek(2) == "?>" then
            if state == "html" then return nil, parse_error end
            ins(pieces, sub(s, last, i-1))
            if state == "inline" then
                ins(pieces, "))")
            end
            ins(pieces, "echo[[")
            consume(2)
            -- because lua skips first newline in multiline string
            if peek() == "\n" then ins(pieces, "\n") end
            state = "html"
            last=i
        else
            consume()
        end
    end
    ins(pieces, sub(s, last, i-1))
    ins(pieces, "]]")

    local f, err
    if _VERSION == "Lua 5.1" then
        f, err = loadstring(table.concat(pieces))
    else
        f, err = load(table.concat(pieces), nil, nil, setmetatable({plp = plp, echo=plp.echo, execute=plp.execute},{__index=_G}))
    end
    if err then return nil, err end
    return f
end

return plp
