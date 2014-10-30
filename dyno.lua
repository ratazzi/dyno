local redis = require "resty.redis"
local cjson = require "cjson"
local settings = require "settings"

local store = redis:new()
local ok, err = store:connect(settings.redis_uri.ip, settings.redis_uri.port)
if not ok then
    ngx.log(ngx.ERR, err)
    ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
end

function has_auth()
    return store:sismember(string.format(settings.allowed_fmt, ngx.var.host), ngx.var.remote_user) == 1
end

local field = string.sub(ngx.var.uri, 2)
local body_field = string.format('body{%s}', field)
local content_type_field = string.format('content_type{%s}', field)
ngx.header["X-Dyno-Domain"] = ngx.var.host
ngx.header["X-Dyno-Field"] = field
-- ngx.header["X-Dyno-Version"] = ngx.var.version

local fields = {'content_type', 'body'}

-- {{{ POST
if ngx.var.request_method == 'HEAD' then
    ngx.header.Allow = "HEAD,GET,POST,OPTIONS,DELETE"
    ngx.exit(ngx.status)
elseif ngx.var.request_method == 'OPTIONS' then
    ngx.header.content_type = "application/json"
    response = {status = 0, data = fields}
    ngx.say(cjson.encode(response))
    ngx.exit(ngx.status)
elseif ngx.var.request_method == 'DELETE' then
    local exists = store:hexists(ngx.var.host, body_field)
    if exists == 0 then
        ngx.status = ngx.HTTP_NOT_FOUND
    else
        if not has_auth() then
            response = {}
            response.status = 1
            response.message = string.format('User %s is not allowed.', ngx.var.remote_user)
            ngx.status = ngx.HTTP_FORBIDDEN
            ngx.header.content_type = "application/json"
            ngx.say(cjson.encode(response))
        else
            ngx.status = 204
            local ok, err = store:hdel(ngx.var.host, content_type_field, body_field)
            if not ok then
                ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
            end
        end
    end
    ngx.exit(ngx.status)
elseif ngx.var.request_method == 'POST' then
    ngx.req.read_body()
    local args, err = ngx.req.get_post_args()
    if not args then
        ngx.say("failed to get post args: ", err)
        return
    end

    local response = {status = 0, message = 'Created'}
    local content_type = args.content_type or settings.default_type

    -- ngx.say(ngx.req.raw_header())

    if not has_auth() then
        response.status = 1
        response.message = string.format('User %s is not allowed.', ngx.var.remote_user)
        ngx.status = ngx.HTTP_FORBIDDEN
    elseif string.len(field) > 0 and string.len(args.body or '') > 0 then
        payload = {}
        payload[body_field] = args.body
        payload[content_type_field] = content_type
        ok, err = store:hmset(ngx.var.host, payload)
        if not ok then
            response.status = 1
            response.message = err
        end
        ngx.status = ngx.HTTP_CREATED
    else
        response.status = 1
        response.message = 'Bad Request'
        response.errors = {content_type = args.content_type or '', body = args.body or ''}
        ngx.status = ngx.HTTP_BAD_REQUEST
    end
    ngx.header.content_type = "application/json"
    ngx.say(cjson.encode(response))
    ngx.exit(ngx.status)
end
-- }}}

-- {{{ index
if string.len(field) == 0 then
    ngx.say(string.format('Welcome to %s', ngx.var.host))
end
-- }}}

-- {{{ GET
local exists = store:hexists(ngx.var.host, body_field)

if exists == 0 then
    ngx.exit(ngx.HTTP_NOT_FOUND)
else
    local payload = store:hmget(ngx.var.host, content_type_field, body_field)
    assert(#payload == 2, "Invalid data.")
    ngx.header.content_type = payload[1] or settings.default_type
    ngx.print(payload[2])
    ngx.exit(ngx.HTTP_OK)
end
-- }}}

local ok, err = store:set_keepalive(settings.max_idle_timeout, settings.pool_size)
if not ok then
    ngx.say(err)
    ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
end

-- vi: set fdm=marker:
