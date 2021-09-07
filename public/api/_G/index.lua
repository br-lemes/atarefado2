
local errno = 500

local DEBUG = string.find(mg.document_root, "/public$")
local level = DEBUG and 1 or 0

local status, errmsg = pcall(function()
	if not DEBUG then
		errno = 404
		error("Not found", level)
	end
	if mg.request_info.request_method ~= "GET" then
		errno = 405
		error("Method not allowed", level)
	end
	local current_table = _G
	if mg.request_info.path_info then
		for current_path in string.gmatch(mg.request_info.path_info, "/([_%a][_%w]*)") do
			current_table = current_table[current_path]
			if not current_table then
				errno = 404
				error("Not found", level)
			end
		end
	end
	local response_table = { }
	for key, value in pairs(current_table) do
		response_table[key] = tostring(value)
	end
	mg.send_http_ok(mg.get_mime_type("type.json"), require("json").encode(response_table))
end)
if not status then mg.send_http_error(errno, errmsg) end
