function OnServerStart()
    -- Replenish 1 token per second,
    -- count per /23 (two /24's),
    -- disable the automatic reject/ignore/ban since we handle it manually
    ProgramTokenBucket(1, 23, -1, -1, -1)

    -- Even 256 processes sounds like quite a bit for our plucky little service!
    assert(unix.setrlimit(unix.RLIMIT_NPROC, 256, 256))
end

-- Map for MIME content negotiation on '/'
mime_method_map = {
    ['text/html'] = 'html',
    ['text/plain'] = 'txt',
    ['application/json'] = 'json',
    ['application/x-sh'] = 'env',
    ['text/x-sh'] = 'env',
    ['application/x-lua'] = 'lua',
    ['text/x-lua'] = 'lua'
}

-- List of strings that indicate a user agent is textual (also used on '/')
text_agents = {
    'curl', 'wget'
}

function OnHttpRequest()
    -- No reason to allow clients to hold on to any connections
    SetHeader('Connection', 'close')

    local ip_int = GetRemoteAddr()

    if not IsTrustedIp(ip_int) then
        local tokens = AcquireToken(ip_int)

        -- Below 16 tokens start returning 429 errors
        if tokens < 16 then
            Log(kLogWarn, 'ip %s has %d tokens' % { FormatIp(ip_int), tokens })

            -- Below 8 tokens just kill the connection
            if tokens < 8 then return end

            ServeError(429)
            return
        end
    end

    -- We only handle GET requests
    if GetMethod() ~= 'GET' then
        ServeError(405)
        return
    end

	local path = GetPath()

	if path == '/' then
        local method

        -- Content negotiation, very fancy!
        local accept = GetHeader('Accept')
        if accept then
            method = accept_to_method(accept)
        end

        -- Known CLI agents get text by default
        local user_agent = GetHeader('User-Agent')
        if not method and user_agent then
            method = agent_to_method(user_agent)
        end

        if not method then method = 'html' end

        _G['handle_' .. method](FormatIp(ip_int))
	elseif path == '/favicon.ico' then
        -- In the HTML output the shortcut icon is set to a blank `data:` URI,
        -- but if an agent _really_ wants that sweet favicon then go ahead and
        -- serve it up
		ServeAsset('favicon.ico')
    elseif string.sub(path, 1, 1) == '/' then
        -- Get the part after the '/'
        local path_after_slash = string.sub(path, 2)
        -- Append it to the 'handle_' prefix for the callback functions below
        local path_method = 'handle_' .. path_after_slash

        -- Verify the method string is sane firsut
        if not string.match(path_method, '^%l[%l%d_]+$') then
            Log(kLogWarn, 'path tomfoolery: %s' % { path_method })
            -- Thought about 402, but I guess we should be professional here
            ServeError(400)
            return
        end

        if _G[path_method] then
            _G[path_method](FormatIp(ip_int))
        else
            ServeError(404)
        end
    else
        Log(kLogWarn, 'strange request')
        ServeError(400)
    end
end

function handle_html(ip)
    SetHeader('Content-Type', 'text/html; charset=UTF-8')

	Write('<!doctype html>\n<title>Get Your Public IP, Now With Less Bogons!</title><link rel="icon" href="data:,">\n')
	Write('<style>html{height:100%;background-color:#27303d;color:#fff;box-sizing:border-box;border:1em solid #1b1e20;font-weight:bold;font-size:4em;font-family:monospace;text-align:center;display:flex;align-items:center;justify-content:center}</style>\n')
	Write('<!-- Don\'t parse! See: /{txt,{json,env,lua}{,?k=foo}} -->\n')
    Write('<body>' .. ip)
end

function handle_json(ip)
    SetHeader('Content-Type', 'application/json')

    local k = GetParam('k')
    if not k then k = 'ip' end

    Write(EncodeJson({[k]=ip}))
end

function handle_txt(ip)
    SetHeader('Content-Type', 'text/plain')
    Write(ip .. '\n')
end

function handle_env(ip)
    common_handle_var('IP', function(k)
        Write('%s="%s"' % { k, ip })
    end)
end

function handle_lua(ip)
    common_handle_var('ip', function(k)
        Write(EncodeLua({[k]=ip}))
    end)
end

function accept_to_method(accept)
    if not accept then return nil end

    -- As always with HTTP, parsing the Accept header probably isn't as
    -- straightforward as it appears; just peek at the first one and see
    -- if there's a match
    local first_mime = string.match(accept, '(.-),')
    if first_mime then accept = first_mime end

    if mime_method_map[accept] then
        return mime_method_map[accept]
    end
end

function agent_to_method(user_agent)
    if not user_agent then return nil end

    for _, text_agent in ipairs(text_agents) do
        if string.match(user_agent, text_agent) then
            return 'txt'
        end
    end
end

function common_handle_var(default_k, finish)
    SetHeader('Content-Type', 'text/plain')

    local k

    if HasParam('k') then
        k = sanitize_var_name(GetParam('k'))
    end

    if not k then k = default_k end

    finish(k)
end

function sanitize_var_name(var)
    local removed
    var, removed = string.gsub(GetParam('k'), '[^%a%d_]', '')

    if removed > 0 then
        Log(kLogWarn, 'var tomfoolery : removed %d returned %s' % { removed, var })
    end

    return var
end
