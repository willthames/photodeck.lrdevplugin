local LrDate =import 'LrDate'
local LrDigest = import 'LrDigest'
local LrDialogs = import 'LrDialogs'
local LrHttp = import 'LrHttp'
local LrTasks = import 'LrTasks'
local logger = import 'LrLogger'( 'PhotoDeckAPI' )
local LrStringUtils = import 'LrStringUtils'
logger:enable('print')

local urlprefix = 'http://api.photodeck.com'

PhotoDeckAPI = {}

-- sign API request according to docs at
-- http://www.photodeck.com/developers/get-started/
local function sign(method, uri, querystring)
  local cocoatime = LrDate.currentTime()
  -- Fri, 25 Jun 2010 12:39:15 +0200
  local timestamp = LrDate.timeToUserFormat(cocoatime, "%b, %d %Y %H:%M:%S -0000", true)

  local request = string.format('%s\n%s\n%s\n%s\n%s\n', method, uri,
                                querystring, PhotoDeckAPI.secret, timestamp)
  local signature = PhotoDeckAPI.key .. ':' .. LrDigest.SHA1.digest(request)
  return {
    { field = 'X-PhotoDeck-TimeStamp', value=timestamp },
    { field = 'X-PhotoDeck-Authorization', value=signature },
  }
end

-- convert lua table to url encoded data
-- from http://www.lua.org/pil/20.3.html
local function table_to_querystring(data)
  assert(data, isString)
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
  local querystring = nil
  if data then
    querystring = table_to_querystring(data)
  end

  -- sign request
  local headers = sign('GET', uri, querystring)
  -- set login cookies
  if PhotoDeckAPI.cookie then
    -- handle session expiry
    table.insert(headers, { field = 'Cookie', value=PhotoDeckAPI.cookie.value })
  else
    if PhotoDeckAPI.username and PhotoDeckAPI.password then
      authorization = 'Basic ' .. LrStringUtils.encodeBase64(PhotoDeckAPI.username ..
                                                             ':' .. PhotoDeckAPI.password)
      table.insert(headers, { field = 'Authorization',  value=authorization })
    end
  end
  -- build full url
  local fullurl = urlprefix .. uri
  if querystring then
    fullurl = fullurl .. '?' .. querystring
  end
  -- call API
  logger:trace(fullurl)
  result, resp_headers = LrHttp.get(fullurl, headers)

  hstring = ''
  for _, h in ipairs(resp_headers) do
    hstring = hstring .. h.field .. ' = ' .. h.value .. "\n"
  end
  logger:trace(hstring)

  for _, h in ipairs(resp_headers) do
    if h.field == 'Set-Cookie' and string.find(h.value, '_ficelle_session') then
      PhotoDeckAPI.cookie = LrHttp.parsecookie(h)
    end
  end

  return result
end

function PhotoDeckAPI.connect(key, secret, username, password)
  PhotoDeckAPI.key = key
  PhotoDeckAPI.secret = secret
  PhotoDeckAPI.username = username
  PhotoDeckAPI.password = password
end

