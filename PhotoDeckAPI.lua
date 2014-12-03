local LrDate =import 'LrDate'
local LrDigest = import 'LrDigest'
local LrDialogs = import 'LrDialogs'
local LrHttp = import 'LrHttp'
local LrTasks = import 'LrTasks'
local logger = import 'LrLogger'( 'PhotoDeckAPI' )
logger:enable('print')

local urlprefix = 'http://api.photodeck.com'
local prefs = import 'LrPrefs'.prefsForPlugin()

PhotoDeckAPI = {}

local function getApiKeyAndSecret()

  local apiKey, apiSecret = prefs.apiKey, prefs.apiSecret

  if not apiKey or not apiSecret then
    local apiKeyFile = assert(io.open('KEY'))
    apiKey = string.match(apiKeyFile:read(), '%x+')
    apiKeyFile:close()
    local apiSecretFile = assert(io.open('SECRET'))
    apiSecret = string.match(apiSecretFile:read(), '%x+')
    apiSecretFile:close()
  end
  prefs.apiKey, prefs.apiSecret = apiKey, apiSecret

  return apiKey, apiSecret
end


-- sign API request according to docs at
-- http://www.photodeck.com/developers/get-started/
local function sign(method, uri, querystring)
  local cocoatime = LrDate.currentTime()
  -- Fri, 25 Jun 2010 12:39:15 +0200
  local timestamp = LrDate.timeToUserFormat(cocoatime, "%b, %d %Y %H:%M:%S -0000", true)

  local apiKey, apiSecret = getApiKeyAndSecret()

  local request = string.format('%s\n%s\n%s\n%s\n%s\n', method, uri,
                                querystring, apiSecret, timestamp)
  local signature = apiKey .. ':' .. LrDigest:digest(request)
  return {
    { field = 'X-PhotoDeck-TimeStamp', value=timestamp },
    { field = 'X-PhotoDeck-Authorization', value=signature },
  }
end

-- convert lua table to url encoded data
-- from http://www.lua.org/pil/20.3.html
local function table_to_querystring(data)
  local function escape (s)
    s = string.gsub(s, "([&=+%c])", function (c)
           return string.format("%%%02X", string.byte(c))
        end)
    s = string.gsub(s, " ", "+")
    return s
  end

  local s = ""
  for k,v in pairs(data) do
    s = s .. "&" .. escape(k) .. "=" .. escape(v)
  end
  return string.sub(s, 2)     -- remove first `&'
end


-- make HTTP GET request to PhotoDeck API
-- must be called within an LrTask
function PhotoDeckAPI.get(uri, data)
  data = data or {}
  logger:trace('entering get')
  local querystring = table_to_querystring(data)

  -- sign request
  local headers = sign('GET', uri, querystring)
  LrDialogs.message('headers', headers['X-PhotoDeck-Authorization'], 'info')

  logger:trace(headers)

  -- build full url
  local fullurl = urlprefix .. uri
  if querystring then
    fullurl = fullurl .. '?' .. querystring
  end
  -- call API
  return LrHttp.get(fullurl, headers)
end



