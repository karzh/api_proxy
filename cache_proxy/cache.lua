-- lock version
local redis = require 'resty.redis'
local resty_lock = require "resty.lock"
local cproxy = require 'init'
local serv_count = #cproxy["redis_server"]
local cache_key = ngx.var.cache_key

-- init redis
local redisInstance = redis:new()
-- 数据存储分布
local hash = ngx.crc32_long(cache_key) % serv_count + 1 
local serv_config = cproxy["redis_server"][hash]
local host = serv_config.host
local port = serv_config.port or "6379"

redisInstance:set_timeout(1000)

local ok, err = redisInstance:connect(host, port)

if not ok then
	ngx.log(ngx.ERR, "failed to connect:" .. err)
	return ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
end

if serv_config.password then
	ok, err = redisInstance:auth(serv_config.password)
	if err then
		ngx.log(ngx.ERR, err)
		return ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
	end 
end
if serv_config.db then
	redisInstance:select(serv_config.db)
end

local req_method = ngx.req.get_method()

if req_method == "GET" then
	local res, err = redisInstance:get(cache_key)

	if res == ngx.null then
		ngx.log(ngx.ERR, "cache not found!")
		-- create lock
		local lock, err = resty_lock:new("my_locks")
		if not lock then
			ngx.log(ngx.ERR, "failed to create lock: "..err)
			return ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
		end

		local elapsed, err = lock:lock(cache_key)
		if not elapsed then
			ngx.log(ngx.ERR, "failed to acquire the lock: "..err)
			return ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
		end

		local uri_args = ngx.req.get_uri_args()
		local req_uri_without_args = ngx.re.sub(ngx.var.request_uri, "\\?.*", "")

		local ret, err = ngx.location.capture("/subrequest_fastcgi" .. req_uri_without_args, { method = ngx.HTTP_GET, args = ngx.req.get_uri_args() })

		if err then
			local ok, err = lock:unlock()
			if not ok then
				ngx.log(ngx.ERR, "failed to unlock:" .. err)
				return ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
			end
		end

		local ok, err = redisInstance:set(cache_key, ret.body, "EX", 60 * 10)
		if not ok then
			local ok, err = lock:unlock()
			if not ok then
				ngx.log(ngx.ERR, "failed to unlock:" .. err)
				return ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
			end
			ngx.log(ngx.WARN, "failed to update cache:" .. err)
			return
		end
		
		local ok, err = lock:unlock()
		if not ok then
			ngx.log(ngx.ERR, "failed to unlock:" .. err)
			return ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
		end 

		return
		
		--ngx.say(ret.body)
	end

	ngx.print(res)
	ngx.flush()
end
