// Home and search for the in-app browser.
//
// R34: "Home is Google." The home page is Google in every case, connected or
// not, so opening the browser and tapping home both land on the same place.
//
// Search uses DuckDuckGo's plain-HTML endpoint rather than Google: /api/page
// returns server-fetched markup, so a search page has to be one that renders
// from HTML alone. Google's results page is script-rendered and comes back
// nearly empty through the proxy (D41).
const String browserHomeUrl = 'https://www.bing.com';

/// The page a fresh tab and the home control both open.
String browserStartUrl() => browserHomeUrl;

/// Search is a DuckDuckGo HTML query, which survives the proxy intact.
String browserSearchUrl(String q) =>
    'https://www.bing.com/search?q=${Uri.encodeComponent(q)}';