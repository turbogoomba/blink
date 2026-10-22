// Blink: settings the Firefox theme needs. apps/install.sh copies these lines into
// your profile's user.js (between the Blink markers), and Firefox reads them at start.

// Use userChrome.css and userContent.css
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// Tabs and the window buttons in one row at the top (Firefox draws the buttons)
user_pref("browser.tabs.inTitlebar", 1);

// Compact density: lower tabs and toolbar (userChrome.css trims the rest)
user_pref("browser.compactmode.show", true);
user_pref("browser.uidensity", 1);

// New tab: only your favorites (Shortcuts), two rows, nothing sponsored
user_pref("browser.newtabpage.activity-stream.feeds.topsites", true);
user_pref("browser.newtabpage.activity-stream.topSitesRows", 2);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.showSearch", false);
user_pref("browser.newtabpage.activity-stream.showWeather", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.highlights", true);

// The address bar shows the domain bright and the rest dimmer
user_pref("browser.urlbar.formatting.enabled", true);
user_pref("browser.urlbar.trimHttps", true);
