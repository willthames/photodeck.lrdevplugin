local LrDate =import 'LrDate'
local LrDigest = import 'LrDigest'
local LrDialogs = import 'LrDialogs'
local LrHttp = import 'LrHttp'
local LrTasks = import 'LrTasks'
local LrStringUtils = import 'LrStringUtils'
local LrXml = import 'LrXml'
local PhotoDeckUtils = require 'PhotoDeckUtils'
local PhotoDeckAPIXSLT = require 'PhotoDeckAPIXSLT'

local logger = import 'LrLogger'( 'PhotoDeckAPI' )
logger:enable('print')

local urlprefix = 'http://api.photodeck.com'
local isTable = PhotoDeckUtils.isTable
local isString = PhotoDeckUtils.isString
local printTable = PhotoDeckUtils.printTable

local PhotoDeckAPI = {}


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

local function auth_headers(method, uri, querystring)
  -- sign request
  local headers = sign(method, uri, querystring)
  -- set login cookies
  if PhotoDeckAPI.username and PhotoDeckAPI.password and not PhotoDeckAPI.loggedin then
    local authorization = 'Basic ' .. LrStringUtils.encodeBase64(PhotoDeckAPI.username ..
                                                             ':' .. PhotoDeckAPI.password)
    table.insert(headers, { field = 'Authorization',  value=authorization })
  end
  return headers
end

-- convert lua table to url encoded data
-- from http://www.lua.org/pil/20.3.html
-- extra chars from http://tools.ietf.org/html/rfc3986#section-2.2
local function table_to_querystring(data)
  assert(PhotoDeckUtils.isTable(data))
  local function escape (s)
    s = string.gsub(s, "([][:/?#@!#'()*,;&=+%c])", function (c)
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
function PhotoDeckAPI.request(method, uri, data)
  local querystring = ''
  local body = ''
  if data then
    if method == 'GET' then
      querystring = table_to_querystring(data)
    else
      body = table_to_querystring(data)
    end
  end

  -- set up authorisation headers
  local headers = auth_headers(method, uri, querystring)
  -- build full url
  local fullurl = urlprefix .. uri
  if not (querystring == '') then
    fullurl = fullurl .. '?' .. querystring
  end

  -- call API
  local result, resp_headers
  if method == 'GET' then
    result, resp_headers = LrHttp.get(fullurl, headers)
  else
    -- override default Content-Type!
    table.insert(headers, { field = 'Content-Type',  value = 'application/x-www-form-urlencoded'})
    result, resp_headers = LrHttp.post(fullurl, body, headers, method)
  end

  local status = PhotoDeckUtils.filter(resp_headers, function(v) return isTable(v) and v.field == 'Status' end)[1]
  if status.value > "400" then
    logger:error("Bad response: " .. result)
    logger:error(PhotoDeckUtils.printLrTable(resp_headers))
    -- raise this up to the user at this point?
  end

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
  local response, headers = PhotoDeckAPI.request('GET', '/ping.xml', t)
  local xmltable = LrXml.xmlElementToSimpleTable(response)
  return xmltable['message']['_value']
end

function PhotoDeckAPI.whoami()
  local response, headers = PhotoDeckAPI.request('GET', '/whoami.xml')
  local xmltable = LrXml.xmlElementToSimpleTable(response)
  return {
    firstname = xmltable['user']['firstname']['_value'],
    lastname = xmltable['user']['lastname']['_value'],
  }
end

function PhotoDeckAPI.websites()
  local response, headers = PhotoDeckAPI.request('GET', '/websites.xml', { view = 'details' })
  local xmltable = LrXml.xmlElementToSimpleTable(response)['websites']['website']
  -- logger:trace(printTable(xmltable))
  return {
    {
      title = xmltable['title']['_value'],
      value = xmltable['urlname']['_value'],
    }
  }
end

function PhotoDeckAPI.galleries(urlname)
  local response, headers = PhotoDeckAPI.request('GET', '/websites/' .. urlname .. '/galleries.xml', { view = 'details' })
  local result = PhotoDeckAPIXSLT.transform(response, PhotoDeckAPIXSLT.galleries)
  -- logger:trace(printTable(result))
  return result
end

function PhotoDeckAPI.createGallery(urlname, galleryname, parentId)
  local galleryInfo = {}
  galleryInfo['gallery[name]'] = galleryname
  galleryInfo['gallery[parent]'] = parentId
  logger:trace(printTable(galleryInfo))
  PhotoDeckAPI.request('POST', '/websites/' .. urlname .. '/galleries.xml', galleryInfo)
  local galleries = PhotoDeckAPI.galleries(urlname)
  return galleries[galleryname]
end

function PhotoDeckAPI.createOrUpdateGallery(exportSettings, collectionInfo)
  local urlname = exportSettings.websiteChosen
  local galleries = PhotoDeckAPI.galleries(urlname)
  local gallery
  -- TODO update gallery
  if galleries[collectionInfo.name] then
    gallery = galleries[collectionInfo.name]
  else
    -- no idea how to deal with multiple parents as yet
    assert(#collectionInfo.parents < 2)
    local parentgallery
    for _, parent in pairs(collectionInfo.parents) do
      if not galleries[parent.remoteCollectionId] then
        parentgallery = PhotoDeckAPI.createGallery(urlname, parent.name,
            galleries["Galleries"].uuid)
      end
    end
    gallery = PhotoDeckAPI.createGallery(urlname, collectionInfo.name, parentgallery.uuid)
  end
  return gallery
end

function PhotoDeckAPI.photosInGallery(exportSettings, gallery)
  local url = '/websites/' .. exportSettings.websiteChosen .. '/galleries/' .. gallery.uuid .. '.xml'
  local response, headers = PhotoDeckAPI.request('GET', url, { view = 'details_with_medias' })
  local medias = PhotoDeckAPIXSLT.transform(response, PhotoDeckAPIXSLT.photosInGallery)
  logger:trace(printTable(medias))
  -- turn it into a set for ease of testing inclusion
  local mediaSet = {}
  for _, v in pairs(medias) do
    mediaSet[v] = v
  end
  return medias
end

function PhotoDeckAPI.uploadPhoto( exportSettings, t)
  -- set up authorisation headers request
  local headers = auth_headers('POST', '/medias.xml')
  local content = {
    { name = 'media[publish_to_galleries]', value = t.gallery },
    { name = 'media[replace]', value = not not t.photo_id },
    { name = 'media[content]', filePath = t.filePath, fileName = t.title, contentType = 'image/jpeg' },
  }
  local response, resp_headers = LrHttp.postMultipart(urlprefix .. '/medias.xml', content, headers)
  local xmltable = LrXml.xmlElementToSimpleTable(response)['media']

  local website = exportSettings.websites[exportSettings.websiteChosen]
  return { uuid = xmltable.uuid, url = website.homeurl .. "/-/" .. xmltable.url }
end

return PhotoDeckAPI
