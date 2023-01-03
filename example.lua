local plp = require"plp"

local outstream = {}
plp.echo = function(s) table.insert(outstream, s) end

local f = plp.compile[[
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

f{list={1,2,3}}

print(table.concat(outstream))
