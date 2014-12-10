local LrDate =import 'LrDate'
local LrDigest = import 'LrDigest'
local LrDialogs = import 'LrDialogs'
local LrHttp = import 'LrHttp'
local LrTasks = import 'LrTasks'
local LrStringUtils = import 'LrStringUtils'
local LrXml = import 'LrXml'
local TableUtils = require 'TableUtils'
local TypeUtils = require 'TypeUtils'

local logger = import 'LrLogger'( 'PhotoDeckAPI' )
logger:enable('print')

local urlprefix = 'http://api.photodeck.com'
local isTable = TypeUtils.isTable
local isString = TypeUtils.isString

local PhotoDeckAPI = {}

local function printTable(t)
  if isTable(t) then
    local result = {}
    for k, v in pairs(t) do
      local current = ''
      if isString(k) then
        current = current .. k .. ' = '
      end
      table.insert(result, current .. printTable(v))
    end
    return '{ ' .. table.concat(result, ', ') .. '}'
  else
    return t
  end
end


-- sign API request according to docs at
-- http://www.photodeck.com/developers/get-started/
local function sign(method, uri, querystring)
  local cocoatime = LrDate.currentTime()
  -- cocoatime = cocoatime - (cocoatime % 600)
  -- Fri, 25 Jun 2010 12:39:15 +0200
  local timestamp = LrDate.timeToUserFormat(cocoatime, "%b, %d %Y %H:%M:%S -0000", true)

  local request = string.format('%s\n%s\n%s\n%s\n%s\n', method, uri,
                                querystring, PhotoDeckAPI.secret, timestamp)
  local signature = PhotoDeckAPI.key .. ':' .. LrDigest.SHA1.digest(request)
  -- logger:trace(timestamp)
  -- logger:trace(signature)
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
  local querystring = ''
  if data then
    querystring = table_to_querystring(data)
  end

  -- sign request
  local headers = sign('GET', uri, querystring)
  -- set login cookies
  if PhotoDeckAPI.username and PhotoDeckAPI.password and not PhotoDeckAPI.loggedin then
    local authorization = 'Basic ' .. LrStringUtils.encodeBase64(PhotoDeckAPI.username ..
                                                             ':' .. PhotoDeckAPI.password)
    table.insert(headers, { field = 'Authorization',  value=authorization })
  end
  -- build full url
  local fullurl = urlprefix .. uri
  if not (querystring == '') then
    fullurl = fullurl .. '?' .. querystring
  end
  -- call API

  local result, resp_headers = LrHttp.get(fullurl, headers)

  for _, v in pairs(headers) do
    if v.field == 'Set-Cookie' and v.value.find('_ficelle_session') then
      PhotoDeckAPI.loggedin = true
      break
    end
    PhotoDeckAPI.loggedin = false
  end

  -- local hstring = TableUtils.toString(resp_headers)
  -- logger:trace(hstring)

  return result
end

function PhotoDeckAPI.connect(key, secret, username, password)
  PhotoDeckAPI.key = key
  PhotoDeckAPI.secret = secret
  PhotoDeckAPI.username = username
  PhotoDeckAPI.password = password
  PhotoDeckAPI.loggedin = false
end

function PhotoDeckAPI.ping(text)
  local t = {}
  if text then
    t = { text = text }
  end
  return PhotoDeckAPI.get('/ping.xml', t)
end

function PhotoDeckAPI.whoami()
  local response, headers = PhotoDeckAPI.get('/whoami.xml')
  local xmltable = LrXml.xmlElementToSimpleTable(response)
  return {
    firstname = xmltable['user']['firstname']['_value'],
    lastname = xmltable['user']['lastname']['_value'],
  }
end

function PhotoDeckAPI:websites()
  local response, headers = PhotoDeckAPI.get('/websites.xml', { view = 'details' })
  local xmltable = LrXml.xmlElementToSimpleTable(response)['websites']['website']
  return {
    {
      title = xmltable['name'],
      value = xmltable['urlname'],
    }
  }
end

return PhotoDeckAPI
