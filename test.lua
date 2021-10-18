
local eng = require("engine")

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

local function test_timecalc() -- luacheck: no unused
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
end

local function test_has_table() -- luacheck: no unused
	local truelist = { "tagnames", "tags", "tasks", "options" }
	local falselist = { "pay", "dress", "sauna", "hook" }
	for _,v in ipairs(truelist) do
		assert(eng.has_table(v), string.format("expected '%s' table not found", v))
	end
	for _,v in ipairs(falselist) do
		assert(not eng.has_table(v), string.format("unexpected '%s' table found", v))
	end
end

local function test_has_id() -- luacheck: no unused
	local expected = "expected id number '%d' not found in table '%s'"
	local unexpected = "unexpected id number '%d' found in table '%s'"
	local list = { tagnames = 38, tasks = 0, options = 8 }
	for k,v in pairs(list) do
		if v == 0 then
			assert(not eng.has_id(1, k), string.format(unexpected, 1, k))
		else
			for i = 1, v do
				assert(eng.has_id(i, k), string.format(expected, i, k))
			end
			assert(not eng.has_id(v + 1, k), string.format(unexpected, v + 1, k))
		end
	end
end

local function test_has_tag() -- luacheck: no unused
	assert(not eng.has_tag(1, 1), "has_tag: unexpected tag")
	-- WARNING: there is no task to test
end

local function test_get_options() -- luacheck: no unused
	local o = eng.get_options()
	for _, v in pairs{ "anytime", "tomorrow", "future", "today", "yesterday", "late" } do
		assert(o[v] == "ON", v .. " ~= 'ON'")
	end
	assert(o.tag == 1, "tag ~= 1")
end

local function test_set_options() -- luacheck: no unused
	assert(eng.set_options("option", "ON") == nil, "accepting invalid option")
	assert(eng.set_options("tomorrow", "NO") == nil, accept.value)
	assert(eng.set_options("tomorrow", "OFF"), reject.value)
	assert(eng.set_options("tag", "ON") == nil, accept.value)
	local o = assert(eng.set_options("tag", 2), reject.value)
	assert(o.tomorrow == "OFF", "tomorrow ~= 'OFF'")
	assert(o.tag == 2, "tag ~= 2")
end

local function test_get_tags() -- luacheck: no unused
	assert(#eng.get_tags() == 0, "unexpected tag")
	assert(eng.get_tags("") == nil, accept.value)
	assert(eng.get_tags("1"), reject.value)
	assert(eng.get_tags(1), reject.value)
end

local function test_set_tags() -- luacheck: no unused
	assert(eng.set_tags() == nil, accept.value)
	assert(eng.set_tags({}) == nil, accept.value)
	assert(eng.set_tags(1, "") == nil, accept.value)
	assert(eng.set_tags(nil, "test").name == "test", "unexpected result")
end

local function test_del_tags(id) -- luacheck: no unused
	assert(eng.del_tags() == nil, accept.value)
	assert(eng.del_tags(1) == nil, accept.value)
	assert(eng.del_tags(40) == nil, accept.value)
	local t = assert(eng.del_tags("39"), reject.value)
	assert(#t == 0, "unexpected result")
end

local function test_del_tags_task() -- luacheck: no unused
	assert(eng.del_tags_task(1, {}))
end

local function test_isdate() -- luacheck: no unused
	assert(not eng.isdate('2020-00-01'), "accepting invalid date")
	assert(eng.isdate('2020-01-01'), "not accepting valid date")
	assert(not eng.isdate('01-01-2020'), "accepting invalid format")
end

local function test_isanytime() -- luacheck: no unused
	assert(eng.isanytime(), "not accepting nil")
	assert(eng.isanytime(""), "not accepting empty string")
	assert(eng.isanytime("anytime"), "not accepting 'anytime'")
	assert(not eng.isanytime(true), "accepting 'true'")
end

local function test_istomorrow() -- luacheck: no unused
	assert(not eng.istomorrow(eng.get_late()), accept.late)
	assert(not eng.istomorrow(eng.get_yesterday()), accept.yesterday)
	assert(not eng.istomorrow(eng.get_today()), accept.today)
	assert(eng.istomorrow(eng.get_tomorrow()), reject.tomorrow)
	assert(not eng.istomorrow(eng.get_future()), accept.future)
end

local function test_isfuture() -- luacheck: no unused
	assert(not eng.isfuture(eng.get_late()), accept.late)
	assert(not eng.isfuture(eng.get_yesterday()), accept.yesterday)
	assert(not eng.isfuture(eng.get_today()), accept.today)
	assert(not eng.isfuture(eng.get_tomorrow()), accept.tomorrow)
	assert(eng.isfuture(eng.get_future()), reject.future)
end

local function test_istoday() -- luacheck: no unused
	assert(not eng.istoday(eng.get_late()), accept.late)
	assert(not eng.istoday(eng.get_yesterday()), accept.yesterday)
	assert(eng.istoday(eng.get_today()), reject.today)
	assert(not eng.istoday(eng.get_tomorrow()), accept.tomorrow)
	assert(not eng.istoday(eng.get_future()), accept.future)
end

local function test_isyesterday() -- luacheck: no unused
	assert(not eng.isyesterday(eng.get_late()), accept.late)
	assert(eng.isyesterday(eng.get_yesterday()), reject.yesterday)
	assert(not eng.isyesterday(eng.get_today()), accept.today)
	assert(not eng.isyesterday(eng.get_tomorrow()), accept.tomorrow)
	assert(not eng.isyesterday(eng.get_future()), accept.future)
end

local function test_islate() -- luacheck: no unused
	assert(eng.islate(eng.get_late()), reject.late)
	assert(not eng.islate(eng.get_yesterday()), accept.yesterday)
	assert(not eng.islate(eng.get_today()), accept.today)
	assert(not eng.islate(eng.get_tomorrow()), accept.tomorrow)
	assert(not eng.islate(eng.get_future()), accept.future)
end

local function test_daysmonth() -- luacheck: no unused
	for i, v in pairs{ 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 } do
		assert(eng.daysmonth(i, 2020) == v, string.format("wrong result for 2020-%02d", i))
	end
	assert(eng.daysmonth(2, 2019) == 28, "wrong result for 2019-02")
end
