local plp = {}

local sub = string.sub
local ins = table.insert

function plp.compile(s)
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
        local echo = plp.echo
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
            assert(state == "html")
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
            else error()
            end
            last=i
        elseif peek(2) == "?>" then
            assert(state ~= "html")
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
        f, err = load(table.concat(pieces), nil, nil, setmetatable({plp = plp, echo=plp.echo},{__index=_G}))
    end
    if err then error(err) end
    return f
end

return plp
