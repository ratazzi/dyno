local settings = require 'settings'
local redis = require "resty.redis"

local store = redis:new()
local ok, err = store:connect(settings.redis_uri.ip, settings.redis_uri.port)
if not ok then
    ngx.log(ngx.ERR, err)
    ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
end

if ngx.var.request_method ~= 'GET' then
    if ngx.var.remote_user and ngx.var.remote_passwd then
        ngx.log(ngx.DEBUG, ngx.req.raw_header())

        local passwd = store:hget(settings.auth_domain, ngx.var.remote_user)
        if passwd ~= ngx.var.remote_passwd then
            ngx.header["WWW-Authenticate"] = [[Basic realm="Restricted"]]
            ngx.exit(ngx.HTTP_UNAUTHORIZED)
        end
    else
        ngx.header["WWW-Authenticate"] = [[Basic realm="Restricted"]]
        ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end
end

local ok, err = store:set_keepalive(settings.max_idle_timeout, settings.pool_size)
if not ok then
    ngx.say(err)
    ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
end
