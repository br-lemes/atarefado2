
local sqlite3 = sqlite3 or require("lsqlite3")

local DEBUG = true
if mg then DEBUG = string.find(mg.document_root, "/public$") end
local level = DEBUG and 1 or 0

-- assert time calculations (os dependent)

assert(
	os.time{day = -1, month = 1, year = 2013}
	==
	os.time{day = 30, month = 12, year = 2012}
)

assert(
	os.time{day = 32, month = 12, year = 2012}
	==
	os.time{day = 1, month = 1, year = 2013}
)

local db, _, errmsg = sqlite3.open("database.sqlite3")
if not db then error(errmsg, level) end

local dateformat = "%Y-%m-%d"

local accept = {
	late      = "accepting late (before yesterday)",
	yesterday = "accepting yesterday",
	today     = "accepting today",
	tomorrow  = "accepting tomorrow",
	future    = "accepting future (after tomorrow)",
	value     = "accepting invalid value",
}

local reject = {
	late      = "not " .. accept.late,
	yesterday = "not " .. accept.yesterday,
	today     = "not " .. accept.today,
	tomorrow  = "not " .. accept.tomorrow,
	future    = "not " .. accept.future,
	value     = "not accepting valid value",
}

local invalid = {
	option = "Invalid option",
	value  = "Invalid value",
}

local function read_data(valid_keys)
	if not mg then return nil end
	if mg.request_info.content_length > 1024 then
		return nil, "Too large data"
	end
	local request_body = mg.read()
	if not request_body then
		return nil, "No data"
	end
	local data = require("json").decode(request_body)
	if valid_keys then
		for k, _ in pairs(data) do
			if not valid_keys[k] then
				return nil, "Invalid data"
			end
		end
	else
		for k, _ in pairs(data) do
			if type(k) ~= "number" then
				return nil, "Invalid data"
			end
		end
	end
	return data
end

local function exec(sql)
	local r = db:exec(sql)
	if r ~= sqlite3.OK then error(db:errmsg(), level == 1 and 2 or level) end
end

-- check if database has the given table
-- return: true or false
local function has_table(tname)
	local query = db:prepare(
		'SELECT name FROM sqlite_master WHERE type="table" AND name=?')
	if not query then error(db:errmsg(), level) end
	assert(query:bind_values(tname) == sqlite3.OK)
	local result = query:step() == sqlite3.ROW and query:get_value(0) == tname
	query:finalize()
	return result
end

local function test_has_table() -- luacheck: no unused
	local truelist = { "tagnames", "tags", "tasks", "options" }
	local falselist = { "pay", "dress", "sauna", "hook" }
	for _,v in ipairs(truelist) do
		assert(has_table(v), string.format("expected '%s' table not found", v))
	end
	for _,v in ipairs(falselist) do
		assert(not has_table(v), string.format("unexpected '%s' table found", v))
	end
end

-- check if the given id has in the given table
-- return: true or false
local function has_id(id, tname)
	if not has_table(tname) then
		error(string.format("No such table: %s", tname), level)
	end
	local query = db:prepare(string.format(
		"SELECT id FROM %s WHERE id=?", tname))
	if not query then error(db:errmsg(), level) end
	assert(query:bind_values(id) == sqlite3.OK)
	local result = query:step() == sqlite3.ROW and query:get_value(0) == id
	query:finalize()
	return result
end

local function test_has_id() -- luacheck: no unused
	local expected = "expected id number '%d' not found in table '%s'"
	local unexpected = "unexpected id number '%d' found in table '%s'"
	local list = { tagnames = 38, tasks = 0, options = 8 }
	for k,v in pairs(list) do
		if v == 0 then
			assert(not has_id(1, k), string.format(unexpected, 1, k))
		else
			for i = 1, v do
				assert(has_id(i, k), string.format(expected, i, k))
			end
			assert(not has_id(v + 1, k), string.format(unexpected, v + 1, k))
		end
	end
end

-- check if the given task has the given tag
-- return: true or false
local function has_tag(task, tag)
	local query = db:prepare(
		"SELECT task FROM tags WHERE task=? and tag=?")
	if not query then error(db:errmsg(), level) end
	assert(query:bind_values(task, tag) == sqlite3.OK)
	local result = query:step() == sqlite3.ROW and query:get_value(0) == task
	query:finalize()
	return result
end

local function test_has_tag() -- luacheck: no unused
	assert(not has_tag(1, 1), "has_tag: unexpected tag")
	-- WARNING: there is no task to test
end

-- return a table with options
local function get_options()
	local result = { }
	for name, value in db:urows("SELECT name, value FROM options;") do
		if name == "tag" then value = tonumber(value) end
		result[name] = value
	end
	return result
end

local function test_get_options() -- luacheck: no unused
	local o = get_options()
	for _, v in pairs{ "anytime", "tomorrow", "future", "today", "yesterday", "late" } do
		assert(o[v] == "ON", v .. " ~= 'ON'")
	end
	assert(o.tag == 1, "tag ~= 1")
end

-- set an option
local function set_options(option, value)
	local valid_options = {
		anytime   = true,
		tomorrow  = true,
		future    = true,
		today     = true,
		yesterday = true,
		late      = true,
		tag       = true,
	}
	if not valid_options[option] then
		return nil, invalid.option
	end
	if option == "tag" then
		value = tostring(value)
		if not value:find("^%d+$") then
			return nil, invalid.value
		end
	else
		if value ~= "ON" and value ~= "OFF" then
			return nil, invalid.value
		end
	end
	exec(string.format("UPDATE options SET value=%q WHERE name=%q;", value, option))
	return true
end

local function test_set_options() -- luacheck: no unused
	assert(set_options("option", "ON") == nil, "accepting invalid option")
	assert(set_options("tomorrow", "NO") == nil, accept.value)
	assert(set_options("tomorrow", "OFF"), reject.value)
	assert(set_options("tag", "ON") == nil, accept.value)
	assert(set_options("tag", 2), reject.value)
	local o = get_options()
	assert(o.tomorrow == "OFF", "tomorrow ~= 'OFF'")
	assert(o.tag == 2, "tag ~= 2")
end

local function get_tags(id)
	local sql
	if id then
		id = tostring(id)
		if not id:find("^%d+$") then
			return nil, invalid.value
		end
		sql = string.format("SELECT id, name FROM tagnames WHERE id=%d;", id)
	else
		sql = "SELECT id, name FROM tagnames WHERE id > 38 ORDER BY name;"
	end
	local result = { }
	for row in db:nrows(sql) do
		table.insert(result, row)
	end
	return result
end

local function test_get_tags() -- luacheck: no unused
	assert(#get_tags() == 0, "unexpected tag")
	assert(get_tags("") == nil, accept.value)
	assert(get_tags("1"), reject.value)
	assert(get_tags(1), reject.value)
end

-- return true if d is a valid date else return nil or false
local function isdate(d)
	local t = { }
	t.year, t.month, t.day = d:match('(%d%d%d%d)-(%d%d)-(%d%d)')
	return t.year and t.month and t.day and
		os.date(dateformat, os.time(t)) == d
end

local function test_isdate() -- luacheck: no unused
	assert(not isdate('2020-00-01'), "accepting invalid date")
	assert(isdate('2020-01-01'), "not accepting valid date")
	assert(not isdate('01-01-2020'), "accepting invalid format")
end

-- return true if d is an unespecified time
local function isanytime(d)
	return not d or d == '' or d == 'anytime'
end
local function test_isanytime() -- luacheck: no unused
	assert(isanytime(), "not accepting nil")
	assert(isanytime(""), "not accepting empty string")
	assert(isanytime("anytime"), "not accepting 'anytime'")
	assert(not isanytime(true), "accepting 'true'")
end

-- return true if d is tomorrow
local function istomorrow(d)
	local tomorrow = os.date("*t")
	tomorrow.day = tomorrow.day + 1
	return d == os.date(dateformat, os.time(tomorrow))
end

local function get_today()
	return os.date(dateformat)
end

local function get_late()
	local d = os.date("*t")
	d.day = d.day - 2
	return os.date(dateformat, os.time(d))
end

local function get_yesterday()
	local d = os.date("*t")
	d.day = d.day - 1
	return os.date(dateformat, os.time(d))
end

local function get_tomorrow()
	local d = os.date("*t")
	d.day = d.day + 1
	return os.date(dateformat, os.time(d))
end

local function get_future()
	local d = os.date("*t")
	d.day = d.day + 2
	return os.date(dateformat, os.time(d))
end

local function test_istomorrow() -- luacheck: no unused
	assert(not istomorrow(get_late()), accept.late)
	assert(not istomorrow(get_yesterday()), accept.yesterday)
	assert(not istomorrow(get_today()), accept.today)
	assert(istomorrow(get_tomorrow()), reject.tomorrow)
	assert(not istomorrow(get_future()), accept.future)
end

-- return true if d is in the future but not tomorrow
local function isfuture(d)
	return not isanytime(d) and not istomorrow(d) and
		d > os.date(dateformat)
end

local function test_isfuture() -- luacheck: no unused
	assert(not isfuture(get_late()), accept.late)
	assert(not isfuture(get_yesterday()), accept.yesterday)
	assert(not isfuture(get_today()), accept.today)
	assert(not isfuture(get_tomorrow()), accept.tomorrow)
	assert(isfuture(get_future()), reject.future)
end

-- return true if d is today
local function istoday(d)
	return d == os.date(dateformat)
end

local function test_istoday() -- luacheck: no unused
	assert(not istoday(get_late()), accept.late)
	assert(not istoday(get_yesterday()), accept.yesterday)
	assert(istoday(get_today()), reject.today)
	assert(not istoday(get_tomorrow()), accept.tomorrow)
	assert(not istoday(get_future()), accept.future)
end

-- return true if d is yesterday
local function isyesterday(d)
	return d == get_yesterday()
end

local function test_isyesterday() -- luacheck: no unused
	assert(not isyesterday(get_late()), accept.late)
	assert(isyesterday(get_yesterday()), reject.yesterday)
	assert(not isyesterday(get_today()), accept.today)
	assert(not isyesterday(get_tomorrow()), accept.tomorrow)
	assert(not isyesterday(get_future()), accept.future)
end

-- return true if d is in the past but not yesterday
local function islate(d)
	return not isanytime(d) and not isyesterday(d) and
		d < os.date(dateformat)
end

local function test_islate() -- luacheck: no unused
	assert(islate(get_late()), reject.late)
	assert(not islate(get_yesterday()), accept.yesterday)
	assert(not islate(get_today()), accept.today)
	assert(not islate(get_tomorrow()), accept.tomorrow)
	assert(not islate(get_future()), accept.future)
end

-- return the number of days in a month
local function daysmonth(month, year)
	while month > 12 do month = month - 12 end
	return month == 2 and (year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)) and 29
		or ('\31\28\31\30\31\30\31\31\30\31\30\31'):byte(month)
end

local function test_daysmonth() -- luacheck: no unused
	for i, v in pairs{ 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 } do
		assert(daysmonth(i, 2020) == v, string.format("wrong result for 2020-%02d", i))
	end
	assert(daysmonth(2, 2019) == 28, "wrong result for 2019-02")
end

exec("BEGIN;")
if not has_table("tagnames") then
	exec([[
		CREATE TABLE tagnames (
			id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
			name TEXT NOT NULL
		);]])
	for _, v in ipairs{
			"Dom", "Seg", "Ter", "Qua",
			"Qui", "Sex", "Sáb"
		} do
		exec(string.format(
			"INSERT INTO tagnames VALUES(NULL, %q);", v))
	end
	for i = 1, 31 do
		exec(string.format(
			'INSERT INTO tagnames VALUES(NULL, "%02d");',
			i))
	end
end

if not has_table("tags") then
	exec([[
		CREATE TABLE tags (
			task INTEGER NOT NULL,
			tag INTEGER NOT NULL
		);]])
end

if not has_table("tasks") then
	exec([[
		CREATE TABLE tasks (
			id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
			name TEXT NOT NULL,
			date TEXT,
			comment TEXT,
			recurrent INTEGER NOT NULL
		);]])
end

if not has_table("options") then
	exec([[
		CREATE TABLE options (
			id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
			name TEXT NOT NULL,
			value TEXT
		);]])
	local optfmt = "INSERT INTO options VALUES(NULL, %q, %q);"
	for _, v in ipairs{
			"anytime", "tomorrow", "future",
			"today", "yesterday", "late"
		} do
		exec(string.format(optfmt, v, "ON"))
	end
	exec(string.format(optfmt, "tag", "1"))
	exec(string.format(optfmt, "version", "1"))
end
exec("END;")

return {
	read_data   = read_data,
	db          = db,
	has_table   = has_table,
	has_id      = has_id,
	has_tag     = has_tag,
	get_options = get_options,
	set_options = set_options,
	get_tags    = get_tags,
	isdate      = isdate,
	isanytime   = isanytime,
	istomorrow  = istomorrow,
	isfuture    = isfuture,
	istoday     = istoday,
	isyesterday = isyesterday,
	islate      = islate,
	daysmonth   = daysmonth,
}
