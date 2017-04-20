-- rewrite阶段处理，生成缓存key

local cproxy = cproxy or require 'init' -- "避免 loop or previous error loading module" 错误
local req_uri_without_args = ngx.re.sub(ngx.var.request_uri, "\\?.*", "")


for idx, rule  in ipairs(cproxy["rules"]) do
	if type(rule["regex"]) == "string" then
		rule["regex"] = {rule["regex"], "i"}
	end

	local regex, mode = table.unpack(rule["regex"])
	--ngx.say(regex)
	if ngx.re.match(req_uri_without_args, regex, mode) then
		local query = {}
		local args = ngx.req.get_uri_args()

		-- scheme host  uri 固定table
		local url_prefix = {
			ngx.var.request_method, " ",
			ngx.var.scheme, "://",
			ngx.var.host, req_uri_without_args,
		}

		-- 根据rule 组装必要参数
		for name,value in pairs(rule['query']) do
			-- 处理缺省值
			if type(value) == "function" then
				value = value(args[name])
			end
			
			-- 参数赋值
			if value == true then
				value = args[name]
			end

			-- 拼接query table
			if value then
				query[name] = value
			end
		end

		-- 拼接完整url
		query = ngx.encode_args(query)
		--ngx.say("query:"..query)
		if query ~= "" then
			table.insert(url_prefix, "?")
			table.insert(url_prefix, query)
		end

		local url = table.concat(url_prefix)
		local cache_key = ngx.md5(url)
		ngx.var.cache_key = cache_key
		return 
	end
end
