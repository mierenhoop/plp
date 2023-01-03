local plp = require"plp"

plp.echo = io.write

local f, err = plp.compilestring[[
<!DOCTYPE html>
<html>
<head>
<title>
Hello from <?= _VERSION ?>
</title>
</head>
<body>
<?lua if $list then ?>
<ul>
<?lua for _, v in ipairs($list) do ?>
<li>Value <?= v ?></li>
<?lua end ?>
</ul>
<?lua end ?>
</body>
</html>
]]

print"Test compilestring"
assert(not err)
f{list={1,2,3}}
print""

plp.compilefiles{"t-index.html"}

print"Test execute"
assert(not plp.execute("t-index.html",{list={}}))
print""
print"Test execute by basename"
assert(not plp.execute("t-index",{list={}}))
