0.16.0 - 23/11/2018
-------------------
Update to latest API
Fix a case where just-republished photos would jump back again to "Modified Photos to Re-Published"

0.15.1 - 01/09/2016
-------------------
Use IPTC headline as photo title, fallback to title when blank

0.15.0 - 31/08/2015
-------------------
Update photo ratings from Lightroom
Use IPTC headline as photo title when title is blank

0.14.1 - 22/06/2015
-------------------
Fix image duplication on PhotoDeck when publishing a photo deleted directly from PhotoDeck to another gallery and then republishing the photo from a previous gallery

0.14.0 - 18/06/2015
-------------------
Use https
Optimize unpublish operation for many photos

0.13.0 - 16/06/2015
-------------------
Deal with API requests rate limits

0.12.0 - 02/03/2015
-------------------
Add a button in gallery/folder settings to open PhotoDeck admin space
Try to deal with Lightroom installations that looses their cookies between each API call

0.11.5 - 26/02/2015
-------------------
Fix URL encoding of % character

0.11.4 - 26/02/2015
-------------------
Fix LUA error when exporting

0.11.3 - 23/02/2015
-------------------
Tabs/indentation fixes

0.11.2 - 06/02/2015
-------------------
Fix connection issues for non english systems
Minor fixes


0.11 - 05/02/2015
-----------------
Multiple accounts fixes
Virtual copies support
Always show current gallery description and display styles in gallery/folder settings
Usability improvements for first time users
PhotoDeck galleries structure synchronization gets a proper cancelable progress bar
Minor performance improvements
Minor fixes
Code reorganisation

0.10 - 03/02/2015
-----------------
Improved robustness and performance
Lightroom -> PhotoDeck photo metadata synchronization
Republishing will not reupload image again by default (see plugin settings)
PhotoDeck galleries structure synchronization
Plugin can be used in export only mode
French translations
Minor fixes

0.9 - 15/01/2015
----------------
Don't replace photos with identical file names at upload
Fix root gallery discovery when root gallery is not named "Galleries"
Reduce number of calls to PhotoDeck API
Minor fixes

0.8 - 29/12/2014
----------------
Fix republishing deleted photos
Add getPhoto API to give some details of photos, including contents
Correct published URLs for photos

0.7 - 28/12/2014
----------------
A single photo can be in multiple galleries. Changes to those photos should propagate
across all of those galleries. Uploading a photo into one gallery should not duplicate
the photo in another gallery

Allow removing an image that exists in multiple collections from a single collection.
The removal of an image in just one collection causes the deletion of the image

0.6 - 27/12/2014
----------------
Improved maintainability of galleries
- Rename gallery - also updates URL as well as name
- Reparent gallery
- Delete gallery
- Set Display Style of gallery

0.5 - 27/12/2014
----------------
Corrected bugs to improve user experience on first use

0.4 - 26/12/2014
----------------
Logging improvements

0.3 - 18/12/2014
----------------
Allow user to select the website they wish to publish to

0.2 - 18/12/2014
----------------
Ready for publishing
- Added MIT license
- Make terms more PhotoDeck specific
- Added README
- Improvements to updating photos

0.1 - 03/12/2014
----------------
Initial commit
