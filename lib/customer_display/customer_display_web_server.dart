import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Live web-based customer display.
///
/// Hosts a small HTTP server on [port] (default 8181).
/// GET  /         → self-contained HTML page
/// GET  /ws       → WebSocket for real-time state pushes
/// GET  /lottie.json → serves the success_animation.json asset
class CustomerDisplayWebServer {
  CustomerDisplayWebServer._();
  static final CustomerDisplayWebServer instance =
      CustomerDisplayWebServer._();

  static const int port = 8181;

  HttpServer? _server;
  final List<WebSocket> _clients = [];
  Map<String, dynamic> _lastState = {'type': 'idle'};
  String _localIp = '127.0.0.1';
  String? _lottieJson; // set by setLottieJson() after asset is loaded

  bool get isRunning => _server != null;
  String get url => 'http://$_localIp:$port';

  /// Call this after the Flutter asset bundle is available:
  ///   final d = await rootBundle.load('assets/animations/success_animation.json');
  ///   CustomerDisplayWebServer.instance.setLottieJson(utf8.decode(d.buffer.asUint8List()));
  void setLottieJson(String json) => _lottieJson = json;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  Future<void> start() async {
    if (_server != null) return;
    _localIp = await _resolveLocalIp();
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _serve();
  }

  Future<void> stop() async {
    for (final ws in List<WebSocket>.from(_clients)) {
      await ws.close();
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
  }

  // ── State broadcasting ──────────────────────────────────────────────────────

  void broadcast(Map<String, dynamic> state) {
    _lastState = state;
    final payload = jsonEncode(state);
    for (final ws in List<WebSocket>.from(_clients)) {
      if (ws.readyState == WebSocket.open) ws.add(payload);
    }
  }

  // ── Internal HTTP handling ──────────────────────────────────────────────────

  void _serve() async {
    await for (final req in _server!) {
      try {
        final path = req.uri.path;

        if (path == '/ws' && WebSocketTransformer.isUpgradeRequest(req)) {
          // WebSocket upgrade
          final ws = await WebSocketTransformer.upgrade(req);
          _clients.add(ws);
          ws.add(jsonEncode(_lastState));
          ws.listen(
            null,
            onDone:      () => _clients.remove(ws),
            onError:     (_) => _clients.remove(ws),
            cancelOnError: true,
          );
        } else if (req.method == 'GET' && path == '/') {
          req.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..write(_htmlPage)
            ..close();
        } else if (req.method == 'GET' && path == '/lottie.json') {
          final json = _lottieJson;
          if (json != null) {
            req.response
              ..statusCode = 200
              ..headers.set('Content-Type', 'application/json')
              ..headers.set('Access-Control-Allow-Origin', '*')
              ..write(json)
              ..close();
          } else {
            req.response..statusCode = 404..close();
          }
        } else {
          req.response..statusCode = 404..close();
        }
      } catch (_) {
        try { req.response.statusCode = 500; await req.response.close(); } catch (_) {}
      }
    }
  }

  static Future<String> _resolveLocalIp() async {
    try {
      final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  // ── Embedded HTML/CSS/JS ────────────────────────────────────────────────────

  static const String _htmlPage = r'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>Customer Display</title>
<style>
/* ── Reset ────────────────────────────────────────────────────────────── */
*,*::before,*::after{margin:0;padding:0;box-sizing:border-box}
html,body{height:100%;font-family:'Segoe UI',system-ui,-apple-system,sans-serif;overflow:hidden;background:#0f172a}

/* ── Screen switching ─────────────────────────────────────────────────── */
.screen{position:fixed;inset:0;display:flex;opacity:0;pointer-events:none;transition:opacity .38s ease}
.screen.active{opacity:1;pointer-events:auto}

/* ═══════════════════════════════════════════════════════════════════════
   IDLE — dark centred branding
═══════════════════════════════════════════════════════════════════════ */
#idle{background:#0f172a;flex-direction:column;align-items:center;justify-content:center;gap:24px}
#idle-logo{max-width:200px;max-height:140px;object-fit:contain;display:none}
#idle-company{color:#fff;font-size:2.8rem;font-weight:800;text-align:center;letter-spacing:.01em}
#idle-welcome{color:#94a3b8;font-size:1.15rem;text-align:center;max-width:420px;line-height:1.6}
.pulse{animation:pulse 2.4s ease-in-out infinite}
@keyframes pulse{0%,100%{opacity:1}50%{opacity:.5}}

/* ═══════════════════════════════════════════════════════════════════════
   SPLIT PANE  left 45% dark branding / right 55% dark transaction
═══════════════════════════════════════════════════════════════════════ */
#cart-screen{flex-direction:row}

/* Left */
.sp-left{
  width:45%;flex-shrink:0;
  background:#1e293b;
  display:flex;flex-direction:column;align-items:center;justify-content:center;
  gap:22px;padding:36px;
  border-right:1px solid #334155
}
.sp-logo{max-width:160px;max-height:160px;object-fit:contain;display:none}
.sp-name{color:#fff;font-size:1.9rem;font-weight:700;text-align:center;line-height:1.3}

/* Right */
.sp-right{
  flex:1;min-width:0;
  background:#111827;
  display:flex;flex-direction:column
}

/* Scrollable items */
.items-scroll{flex:1;overflow-y:auto;padding:14px 20px 6px}

/* Item row */
.item{display:flex;align-items:center;gap:14px;padding:12px 0;border-bottom:1px solid rgba(255,255,255,.07)}
.item:last-child{border-bottom:none}

/* Thumbnail */
.thumb{
  width:50px;height:50px;border-radius:10px;
  background:rgba(255,255,255,.08);flex-shrink:0;
  display:flex;align-items:center;justify-content:center;
  overflow:hidden;font-size:.85rem;font-weight:700;color:#64748b;
  letter-spacing:0
}
.thumb img{width:100%;height:100%;object-fit:cover;border-radius:10px}

/* Item text */
.item-body{flex:1;min-width:0}
.item-name{color:#f1f5f9;font-size:.95rem;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.item-meta{color:#64748b;font-size:.75rem;margin-top:2px}
.item-disc{color:#4ade80;font-size:.7rem;margin-top:1px}
.item-cmt{color:#fbbf24;font-size:.7rem;font-style:italic;margin-top:1px}
.item-total{color:#f1f5f9;font-size:.95rem;font-weight:800;white-space:nowrap;flex-shrink:0}

/* Pinned totals */
.totals-pin{
  background:#1e293b;flex-shrink:0;
  border-top:1px solid #334155;
  padding:14px 24px 20px
}
.tot-row{display:flex;justify-content:space-between;align-items:center;padding:3px 0;font-size:.875rem;color:#94a3b8}
.tot-val{color:#e2e8f0;font-weight:500}
.tot-row.disc .tot-val{color:#4ade80}
.tot-row.cash .tot-val{color:#4ade80;font-weight:700}
.tot-hr{border:none;border-top:1px solid #334155;margin:8px 0}
.grand-row{display:flex;justify-content:space-between;align-items:center;margin-top:10px}
.grand-lbl,.grand-amt{color:#fff;font-size:1.9rem;font-weight:900;letter-spacing:-.03em}
.powered{font-size:.6rem;color:#334155;text-align:right;margin-top:8px}

/* ═══════════════════════════════════════════════════════════════════════
   SUCCESS SCREEN
═══════════════════════════════════════════════════════════════════════ */
#payment-screen{
  background:#0f172a;
  flex-direction:column;align-items:center;justify-content:center;gap:0
}

/* Lottie container — shown when LottieJS loads successfully */
#lottie-wrap{width:260px;height:260px;display:none}

/* CSS fallback checkmark — shown if LottieJS unavailable */
#css-icon{display:none;align-items:center;justify-content:center;width:110px;height:110px}
.check-circle{
  width:110px;height:110px;border-radius:50%;
  background:#16a34a;
  display:flex;align-items:center;justify-content:center;
  animation:popIn .5s cubic-bezier(.175,.885,.32,1.275) both
}
@keyframes popIn{from{transform:scale(0);opacity:0}to{transform:scale(1);opacity:1}}
.check-circle svg{width:58px;height:58px}

.suc-heading{color:#fff;font-size:3.6rem;font-weight:900;letter-spacing:-.04em;margin-top:16px}
.suc-card{
  background:#1e293b;border-radius:20px;
  border:1px solid #334155;
  padding:22px 52px 26px;margin-top:20px;
  display:flex;flex-direction:column;align-items:center;gap:2px
}
.suc-label{color:#64748b;font-size:.875rem}
.suc-total{color:#fff;font-size:3.4rem;font-weight:900;letter-spacing:-.04em;line-height:1.1}
.suc-cash-row{display:flex;gap:44px;margin-top:16px;padding-top:16px;border-top:1px solid #334155}
.suc-stat{text-align:center}
.suc-stat-lbl{color:#64748b;font-size:.72rem;text-transform:uppercase;letter-spacing:.07em}
.suc-stat-val{color:#f1f5f9;font-size:1.5rem;font-weight:700;margin-top:3px}
.suc-stat-val.grn{color:#4ade80}

/* Reconnect badge */
#status{position:fixed;bottom:12px;right:12px;background:#fef3c7;color:#92400e;padding:6px 14px;border-radius:20px;font-size:.7rem;display:none;border:1px solid #fcd34d}
</style>
</head>
<body>

<!-- IDLE -->
<div id="idle" class="screen active">
  <img id="idle-logo" class="pulse" alt="logo"/>
  <div id="idle-company"></div>
  <div id="idle-welcome"></div>
</div>

<!-- SPLIT PANE -->
<div id="cart-screen" class="screen">
  <div class="sp-left">
    <img id="sp-logo" class="sp-logo" alt="logo"/>
    <div id="sp-name" class="sp-name"></div>
  </div>
  <div class="sp-right">
    <div class="items-scroll" id="items-list"></div>
    <div class="totals-pin" id="totals-block"></div>
  </div>
</div>

<!-- SUCCESS -->
<div id="payment-screen" class="screen">
  <div id="lottie-wrap"></div>
  <div id="css-icon">
    <div class="check-circle">
      <svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
        <polyline points="20 6 9 17 4 12"/>
      </svg>
    </div>
  </div>
  <div class="suc-heading">Thank You!</div>
  <div class="suc-card" id="suc-card"></div>
</div>

<div id="status">Reconnecting…</div>

<script>
/* ── Lottie setup (LottieJS loaded from CDN; CSS fallback if unavailable) ── */
var lottieReady = false;
var lottieInst  = null;

(function(){
  var s = document.createElement('script');
  s.src = 'https://cdnjs.cloudflare.com/ajax/libs/lottie-web/5.12.2/lottie.min.js';
  s.onload = function(){ lottieReady = true; };
  document.head.appendChild(s);
})();

function playLottie(){
  var wrap = document.getElementById('lottie-wrap');
  var css  = document.getElementById('css-icon');
  if(lottieReady && typeof lottie !== 'undefined'){
    wrap.style.display = 'block';
    css.style.display  = 'none';
    if(lottieInst){ lottieInst.destroy(); lottieInst = null; }
    lottieInst = lottie.loadAnimation({
      container: wrap,
      renderer:  'svg',
      loop:      false,
      autoplay:  true,
      path:      '/lottie.json'
    });
  } else {
    wrap.style.display = 'none';
    css.style.display  = 'flex';
  }
}

/* ── WebSocket ────────────────────────────────────────────────────────── */
var ws, retryMs = 1000;

function connect(){
  ws = new WebSocket('ws://' + location.host + '/ws');
  ws.onopen    = function(){ retryMs=1000; document.getElementById('status').style.display='none'; };
  ws.onmessage = function(e){ render(JSON.parse(e.data)); };
  ws.onclose   = function(){ document.getElementById('status').style.display='block'; setTimeout(connect, retryMs=Math.min(retryMs*2,30000)); };
  ws.onerror   = function(){ ws.close(); };
}

function showScreen(id){
  ['idle','cart-screen','payment-screen'].forEach(function(s){
    document.getElementById(s).classList.remove('active');
  });
  document.getElementById(id).classList.add('active');
}

function setLogo(id, b64){
  var el = document.getElementById(id);
  if(b64){ el.src='data:image/png;base64,'+b64; el.style.display='block'; }
  else    { el.style.display='none'; }
}

function esc(s){
  return (s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

function fmtQty(q){
  var n = Number(q);
  return (n%1===0) ? String(Math.round(n)) : n.toFixed(2);
}

function render(d){
  if     (d.type==='idle')    renderIdle(d);
  else if(d.type==='cart')    renderCart(d);
  else if(d.type==='success') renderSuccess(d);
}

/* ── IDLE ─────────────────────────────────────────────────────────────── */
function renderIdle(d){
  var co = d.company||{};
  setLogo('idle-logo', co.logo||null);
  document.getElementById('idle-company').textContent = co.name||'';
  document.getElementById('idle-welcome').textContent = d.welcomeText||'';
  showScreen('idle');
}

/* ── CART ─────────────────────────────────────────────────────────────── */
function renderCart(d){
  var co  = d.company||{};
  var cur = d.currency||'';

  setLogo('sp-logo', co.logo||null);
  document.getElementById('sp-name').textContent = co.name||'';

  /* Item rows */
  var html = '';
  (d.items||[]).forEach(function(it){
    /* Thumbnail: product image if available, else first letter */
    var thumb;
    if(it.image){
      thumb = '<div class="thumb"><img src="data:image/jpeg;base64,'+it.image+'" alt=""/></div>';
    } else {
      var init = esc((it.name||'?').charAt(0).toUpperCase());
      thumb = '<div class="thumb">'+init+'</div>';
    }

    var discHtml = (it.discount||0)>0.001
      ? '<div class="item-disc">Discount &minus;'+cur+' '+(it.discount).toFixed(2)+'</div>' : '';

    html += '<div class="item">'
      + thumb
      + '<div class="item-body">'
      +   '<div class="item-name">'+esc(it.name)+'</div>'
      +   '<div class="item-meta">'+fmtQty(it.qty)+' &times; '+cur+' '+(it.price).toFixed(2)+' / Units</div>'
      +   discHtml
      + '</div>'
      + '<div class="item-total">'+cur+' '+(it.lineTotal).toFixed(2)+'</div>'
      + '</div>';
  });
  document.getElementById('items-list').innerHTML = html;

  /* Totals */
  var t = '';
  if((d.tax||0)>0)
    t += '<div class="tot-row"><span>Taxes</span><span class="tot-val">'+cur+' '+(d.tax).toFixed(2)+'</span></div>';
  if((d.discount||0)>0)
    t += '<div class="tot-row disc"><span>Discount</span><span class="tot-val">&minus;'+cur+' '+(d.discount).toFixed(2)+'</span></div>';
  t += '<hr class="tot-hr"/>';
  t += '<div class="grand-row"><span class="grand-lbl">Total</span><span class="grand-amt">'+cur+' '+(d.total).toFixed(2)+'</span></div>';
  t += '<div class="powered">Powered by POS</div>';
  document.getElementById('totals-block').innerHTML = t;

  showScreen('cart-screen');
}

/* ── SUCCESS ──────────────────────────────────────────────────────────── */
function renderSuccess(d){
  var cur = d.currency||'';

  /* Build the amounts card */
  var card = '<div class="suc-label">Total Paid</div>'
    + '<div class="suc-total">'+cur+' '+(d.total).toFixed(2)+'</div>';

  if((d.cash||0)>0){
    card += '<div class="suc-cash-row">'
      +'<div class="suc-stat"><div class="suc-stat-lbl">Cash</div><div class="suc-stat-val">'+cur+' '+(d.cash).toFixed(2)+'</div></div>'
      +'<div class="suc-stat"><div class="suc-stat-lbl">Change</div><div class="suc-stat-val grn">'+cur+' '+(d.change||0).toFixed(2)+'</div></div>'
      +'</div>';
  }
  document.getElementById('suc-card').innerHTML = card;

  showScreen('payment-screen');
  playLottie();
}

connect();
</script>
</body>
</html>''';
}
