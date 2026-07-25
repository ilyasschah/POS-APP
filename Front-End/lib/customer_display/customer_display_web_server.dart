import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Live web-based customer display.
///
/// Hosts a small HTTP server on [port] (default 8181).
/// GET  /         → self-contained HTML page
/// GET  /ws       → WebSocket for real-time state pushes
///
/// The page has no external dependencies and no animation. Its colours are
/// driven entirely by the `theme` object carried in every broadcast, so a
/// browser on a second monitor / other device renders in the operator's exact
/// app theme (light / dark / dimmed / night / …).
class CustomerDisplayWebServer {
  CustomerDisplayWebServer._();
  static final CustomerDisplayWebServer instance =
      CustomerDisplayWebServer._();

  static const int port = 8181;

  HttpServer? _server;
  final List<WebSocket> _clients = [];
  Map<String, dynamic> _lastState = {'type': 'idle'};
  String _localIp = '127.0.0.1';

  bool get isRunning => _server != null;
  String get url => 'http://$_localIp:$port';

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
/* ── Theme variables (overwritten live from the broadcast `theme` object). The
      defaults below are only shown for the split-second before the first
      message arrives. ─────────────────────────────────────────────────────── */
:root{
  --bg:#0f172a;
  --surface:#111827;
  --surface-alt:#1e293b;
  --on-surface:#f1f5f9;
  --on-surface-variant:#94a3b8;
  --primary:#a8c7fa;
  --on-primary:#0f172a;
  --outline:#334155;
  --success:#4ade80;
}

/* ── Reset ────────────────────────────────────────────────────────────── */
*,*::before,*::after{margin:0;padding:0;box-sizing:border-box}
html,body{height:100%;font-family:'Segoe UI',system-ui,-apple-system,sans-serif;overflow:hidden;background:var(--bg)}

/* ── Screen switching ─────────────────────────────────────────────────── */
.screen{position:fixed;inset:0;display:flex;opacity:0;pointer-events:none;transition:opacity .38s ease}
.screen.active{opacity:1;pointer-events:auto}

/* ═══════════════════════════════════════════════════════════════════════
   IDLE — centred branding
═══════════════════════════════════════════════════════════════════════ */
#idle{background:var(--bg);flex-direction:column;align-items:center;justify-content:center;gap:24px}
#idle-logo{max-width:200px;max-height:140px;object-fit:contain;display:none}
#idle-company{color:var(--on-surface);font-size:2.8rem;font-weight:800;text-align:center;letter-spacing:.01em}
#idle-welcome{color:var(--on-surface-variant);font-size:1.15rem;text-align:center;max-width:420px;line-height:1.6}

/* ═══════════════════════════════════════════════════════════════════════
   SPLIT PANE  left 45% branding / right 55% transaction
═══════════════════════════════════════════════════════════════════════ */
#cart-screen{flex-direction:row}

/* Left */
.sp-left{
  width:45%;flex-shrink:0;
  background:var(--surface-alt);
  display:flex;flex-direction:column;align-items:center;justify-content:center;
  gap:22px;padding:36px;
  border-right:1px solid var(--outline)
}
.sp-logo{max-width:160px;max-height:160px;object-fit:contain;display:none}
.sp-name{color:var(--on-surface);font-size:1.9rem;font-weight:700;text-align:center;line-height:1.3}

/* Right */
.sp-right{
  flex:1;min-width:0;
  background:var(--surface);
  display:flex;flex-direction:column
}

/* Scrollable items */
.items-scroll{flex:1;overflow-y:auto;padding:14px 20px 6px}

/* Item row */
.item{display:flex;align-items:center;gap:14px;padding:12px 0;border-bottom:1px solid var(--outline)}
.item:last-child{border-bottom:none}

/* Thumbnail */
.thumb{
  width:50px;height:50px;border-radius:10px;
  background:var(--surface-alt);flex-shrink:0;
  display:flex;align-items:center;justify-content:center;
  overflow:hidden;font-size:.85rem;font-weight:700;color:var(--on-surface-variant);
  letter-spacing:0
}
.thumb img{width:100%;height:100%;object-fit:cover;border-radius:10px}

/* Item text */
.item-body{flex:1;min-width:0}
.item-name{color:var(--on-surface);font-size:.95rem;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.item-meta{color:var(--on-surface-variant);font-size:.75rem;margin-top:2px}
.item-disc{color:var(--success);font-size:.7rem;margin-top:1px}
.item-total{color:var(--on-surface);font-size:.95rem;font-weight:800;white-space:nowrap;flex-shrink:0}

/* Pinned totals */
.totals-pin{
  background:var(--surface-alt);flex-shrink:0;
  border-top:1px solid var(--outline);
  padding:14px 24px 20px
}
.tot-row{display:flex;justify-content:space-between;align-items:center;padding:3px 0;font-size:.875rem;color:var(--on-surface-variant)}
.tot-val{color:var(--on-surface);font-weight:500}
.tot-row.disc .tot-val{color:var(--success)}
.tot-row.cash .tot-val{color:var(--success);font-weight:700}
.tot-hr{border:none;border-top:1px solid var(--outline);margin:8px 0}
.grand-row{display:flex;justify-content:space-between;align-items:center;margin-top:10px}
.grand-lbl{color:var(--on-surface);font-size:1.9rem;font-weight:900;letter-spacing:-.03em}
.grand-amt{color:var(--primary);font-size:1.9rem;font-weight:900;letter-spacing:-.03em}
.powered{font-size:.6rem;color:var(--on-surface-variant);opacity:.6;text-align:right;margin-top:8px}

/* ═══════════════════════════════════════════════════════════════════════
   SUCCESS SCREEN — configurable message + amounts, no animation
═══════════════════════════════════════════════════════════════════════ */
#payment-screen{
  background:var(--bg);
  flex-direction:column;align-items:center;justify-content:center;gap:0
}
.suc-heading{color:var(--primary);font-size:3.6rem;font-weight:900;letter-spacing:-.04em;text-align:center;padding:0 24px}
.suc-card{
  background:var(--surface-alt);border-radius:20px;
  border:1px solid var(--outline);
  padding:22px 52px 26px;margin-top:20px;
  display:flex;flex-direction:column;align-items:center;gap:2px
}
.suc-label{color:var(--on-surface-variant);font-size:.875rem}
.suc-total{color:var(--on-surface);font-size:3.4rem;font-weight:900;letter-spacing:-.04em;line-height:1.1}
.suc-cash-row{display:flex;gap:44px;margin-top:16px;padding-top:16px;border-top:1px solid var(--outline)}
.suc-stat{text-align:center}
.suc-stat-lbl{color:var(--on-surface-variant);font-size:.72rem;text-transform:uppercase;letter-spacing:.07em}
.suc-stat-val{color:var(--on-surface);font-size:1.5rem;font-weight:700;margin-top:3px}
.suc-stat-val.grn{color:var(--success)}

/* Reconnect badge */
#status{position:fixed;bottom:12px;right:12px;background:#fef3c7;color:#92400e;padding:6px 14px;border-radius:20px;font-size:.7rem;display:none;border:1px solid #fcd34d}
</style>
</head>
<body>

<!-- IDLE -->
<div id="idle" class="screen active">
  <img id="idle-logo" alt="logo"/>
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
  <div class="suc-heading" id="suc-heading"></div>
  <div class="suc-card" id="suc-card"></div>
</div>

<div id="status">Reconnecting…</div>

<script>
/* ── WebSocket ────────────────────────────────────────────────────────── */
var ws, retryMs = 1000;

function connect(){
  ws = new WebSocket('ws://' + location.host + '/ws');
  ws.onopen    = function(){ retryMs=1000; document.getElementById('status').style.display='none'; };
  ws.onmessage = function(e){ render(JSON.parse(e.data)); };
  ws.onclose   = function(){ document.getElementById('status').style.display='block'; setTimeout(connect, retryMs=Math.min(retryMs*2,30000)); };
  ws.onerror   = function(){ ws.close(); };
}

/* Apply the operator's app theme (colours pushed in every broadcast). */
function applyTheme(t){
  if(!t) return;
  var root = document.documentElement;
  var map = {
    bg:'--bg', surface:'--surface', surfaceAlt:'--surface-alt',
    onSurface:'--on-surface', onSurfaceVariant:'--on-surface-variant',
    primary:'--primary', onPrimary:'--on-primary', outline:'--outline',
    success:'--success'
  };
  for(var k in map){ if(t[k]) root.style.setProperty(map[k], t[k]); }
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
  applyTheme(d.theme);
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

  document.getElementById('suc-heading').textContent = d.thankYouText || 'Thank you!';

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
}

connect();
</script>
</body>
</html>''';
}
