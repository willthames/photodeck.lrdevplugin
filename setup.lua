local require = require
import = require

local pkgroot = '/Applications/Adobe Photoshop Lightroom 5.app/Contents/Frameworks/'

local frameworks = {
  'AgFTPClient.agtoolkit/Contents';
  'AgSubstrate.framework/Versions/A';
  'WichitaFoundation.agtoolkit/Versions/A/Frameworks/WFCore.framework/Versions/A';
}

local dylibs = {
  'AgKernel.framework/Versions/A/AgKernel';
  'AgSubstrate.framework/AgSubstrate';
  'WichitaFoundation.agtoolkit/Versions/A/WichitaFoundation';
}

for _, framework in ipairs(frameworks) do
  package.path = package.path..';'..pkgroot..framework..'/Resources/?.lua'
end

for _, dylib in ipairs(dylibs) do
  package.cpath = package.cpath..';'..pkgroot..dylib
end

print(package.path)
print(package.cpath)
LrDigest = require 'LrDigest'

print (LrMD5:digest('hello'))
