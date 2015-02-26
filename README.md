PhotoDeck Publish Plugin for Lightroom
--------------------------------------

The PhotoDeck Publish plugin was created to provide a publish service
for PhotoDeck within Adobe Lightroom.

Installation
============

Either

```
git clone https://github.com/willthames/photodeck.lrdevplugin
```

Or use the download zip button to download a zip file, extract to a location of
your choice.

Within Lightroom, go to File > Plugin Manager... and then click Add and navigate
to the location of photodeck.lrdevplugin

You will need a [PhotoDeck API key](https://my.photodeck.com/developer/applications/new)

In the Lightroom Publishing Manager, add your API key and secret, enter your email address
and password, and choose which website you wish to connect to.

You will then be able to add Galleries and Folders (ie, Galleries that contain sub
galleries) to PhotoDeck and maintain them within Lightroom.

You will also be able to import the existing PhotoDeck Galleries structure into Lightroom.

Please note that photos that have not been published in PhotoDeck Galleries
by this plugin will not show up in Lightroom.


Support
=======

At present support is offered through github. Pull requests will be reviewed, and
issues will be monitored, but the plugin available through github is on an as-is
basis. No guarantees are offered and it is recommended that you keep backups of
your photos within Lightroom and on PhotoDeck.

This plugin is neither developed nor supported by PhotoDeck or Adobe, although is
written based on their documentation and SDKs.
