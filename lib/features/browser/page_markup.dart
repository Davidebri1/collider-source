// Markup for the web browser frame (pure Dart, so it is unit-tested).
//
// The page proxy hands back a site's HTML; the frame shows it with srcdoc.
// Two things have to be added before it goes in the frame:
//  - a <base> naming the real address, so relative links, images and styles
//    resolve against the site. The proxy already writes the address it ended
//    on after redirects; that one is kept (resolving against the typed
//    address breaks links on any site that redirects, wikipedia.org ->
//    www.wikipedia.org).
//  - a small link script. Without it a link or a GET form navigates the
//    frame straight to the real site, which most sites refuse to be framed
//    by, and the address bar never hears about it. With it the page asks
//    Collider to open the address, which goes through the proxy like a typed
//    address. Same-page #anchors still scroll in place.

/// Message the page's link script posts to Collider: "collider-nav:<url>".
const String pageNavPrefix = 'collider-nav:';

const String pageNavScript = '<script>(function(){'
    'function go(u){try{parent.postMessage("$pageNavPrefix"+u,"*")}catch(e){}}'
    'function bare(u){return String(u).split("#")[0]}'
    'document.addEventListener("click",function(e){'
    'if(e.button!==0||e.metaKey||e.ctrlKey||e.shiftKey||e.altKey)return;'
    'var a=e.target&&e.target.closest?e.target.closest("a[href]"):null;if(!a)return;'
    'var h=a.getAttribute("href")||"";if(!h||h.charAt(0)==="#"||/^(javascript|mailto|tel|data|blob):/i.test(h))return;'
    'var u=a.href;if(!/^https?:/i.test(u))return;'
    'if(bare(u)===bare(document.baseURI)&&u.indexOf("#")>=0)return;'
    'e.preventDefault();e.stopPropagation();go(u);},true);'
    'document.addEventListener("submit",function(e){'
    'var f=e.target;if(!f||String(f.method||"get").toLowerCase()!=="get")return;'
    'e.preventDefault();e.stopPropagation();'
    'var u=new URL(f.getAttribute("action")||document.baseURI,document.baseURI);var p=new URLSearchParams();'
    'new FormData(f).forEach(function(v,k){if(typeof v==="string")p.append(k,v)});'
    'if(e.submitter&&e.submitter.name)p.append(e.submitter.name,e.submitter.value||"");'
    'u.search=p.toString();go(u.href);},true);'
    'window.open=function(u){if(u)go(new URL(u,document.baseURI).href);return null};'
    '})();</script>';

/// The proxy's HTML for [target], ready for the frame: one <base> (the
/// proxy's own when present) followed by [pageNavScript], at the top of
/// <head>.
String preparePageMarkup(String html, String target) {
  final given = RegExp(r'''<base[^>]*href=["']([^"']+)["']''', caseSensitive: false).firstMatch(html)?.group(1);
  final safe = (given ?? target).replaceAll('"', '%22').replaceAll('<', '%3C');
  final tag = '<base href="$safe">$pageNavScript';
  final stripped = html.replaceAll(RegExp(r'<base[^>]*>', caseSensitive: false), '');
  final head = RegExp(r'<head[^>]*>', caseSensitive: false).firstMatch(stripped);
  if (head != null) return stripped.replaceRange(head.end, head.end, tag);
  final open = RegExp(r'<html[^>]*>', caseSensitive: false).firstMatch(stripped);
  if (open != null) return stripped.replaceRange(open.end, open.end, tag);
  return '$tag$stripped';
}

/// The address a frame message asks for, or null when the message is not a
/// link request or the address is not http(s).
String? pageNavTarget(Object? data) {
  if (data is! String || !data.startsWith(pageNavPrefix)) return null;
  final url = data.substring(pageNavPrefix.length);
  final u = Uri.tryParse(url);
  if (u == null || !(u.scheme == 'http' || u.scheme == 'https') || u.host.isEmpty) return null;
  return url;
}
