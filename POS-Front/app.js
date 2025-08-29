// ---------------------- API CONFIG ----------------------
const API = {
    products: 'https://localhost:7002/api/Products/GetProducts',
    productGroups: 'https://localhost:7002/api/ProductGroups/GetAll',
    barcodes: 'https://localhost:7002/api/Barcodes/GetAllBarCodeProductName',
    currencies: 'https://localhost:7002/api/Currencies/GetAll',
    productTaxes: 'https://localhost:7002/api/ProductTaxes/GetAll',
    posOrdersGetAll: 'https://localhost:7004/api/PosOrders/GetAll',
    posOrdersAdd: 'https://localhost:7004/api/PosOrders/Add',
    posOrderItemsAdd: 'https://localhost:7004/api/PosOrderItems/Add'
}

const DEFAULT_HEADERS = {
    'Content-Type': 'application/json',
    'Accept': 'application/json'
}

// ---------------------- STATE ----------------------
let catalog = []
let filtered = []
let groups = []
let barcodeMap = new Map()
let taxesByProduct = new Map()
let currencies = []
let activeGroupId = null
let cart = []   // [{ id, name, price, qty, taxPercent, taxInclusive, currencyCode }]

let payMethod = 'cash'
let currencyCode = '$'

// ---------------------- UTILS ----------------------
const $ = s => document.querySelector(s)
const $$ = s => Array.from(document.querySelectorAll(s))

const fmt = n => `${currencyCode} ${Number(isNaN(n) ? 0 : n).toFixed(2)}`
const toast = msg => { const t = $('#toast'); t.textContent = msg; t.classList.remove('hidden'); setTimeout(() => t.classList.add('hidden'), 1800) }
const setStatus = msg => $('#posStatus').textContent = msg
const show = (id, on = true) => { const el = typeof id === 'string' ? document.getElementById(id) : id; if (el) el.classList.toggle('hidden', !on) }
const debounce = (fn, wait = 250) => { let t; return (...args) => { clearTimeout(t); t = setTimeout(() => fn(...args), wait) } }
const escapeHtml = s => (s ?? '').toString().replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#039;')

// ---------------------- INIT ----------------------
document.addEventListener('DOMContentLoaded', () => {
    bindEvents()
    loadCatalog()
})

function bindEvents() {
    $('#productSearch').addEventListener('input', debounce(applyFilters, 200))
    $('#barcodeInput').addEventListener('keydown', e => {
        if (e.key === 'Enter') {
            const code = e.target.value.trim()
            e.target.value = ''
            if (code) handleBarcode(code)
        }
    })
    $('#reloadBtn').addEventListener('click', loadCatalog)
    $('#clearCartBtn').addEventListener('click', clearCart)
    $('#amountTendered').addEventListener('input', updateChange)

    // Payment method buttons
    $$('.pay-methods .btn').forEach(btn => {
        btn.addEventListener('click', () => {
            $$('.pay-methods .btn').forEach(b => b.classList.remove('btn-primary'))
            btn.classList.add('btn-primary')
            payMethod = btn.dataset.pay
            updateConfirmPreview()
        })
    })

    // Save order + Complete sale
    $('#saveOrderBtn').addEventListener('click', () => postOrder('draft'))
    $('#completeSaleBtn').addEventListener('click', openConfirm)
    $('#confirmClose').addEventListener('click', closeConfirm)
    $('#cancelConfirm').addEventListener('click', closeConfirm)
    $('#confirmSubmit').addEventListener('click', () => postOrder('completed'))

    // catalog error close
    $('#catalogErrorClose').addEventListener('click', () => show('catalogError', false))
}

// ---------------------- LOAD CATALOG ----------------------
async function loadCatalog() {
    setStatus('Loading…')
    show('catalogLoading', true)
    show('catalogError', false)
    try {
        const [prodRes, groupRes, bcRes, curRes, taxRes] = await Promise.all([
            fetch(API.products, { headers: DEFAULT_HEADERS }),
            fetch(API.productGroups, { headers: DEFAULT_HEADERS }),
            fetch(API.barcodes, { headers: DEFAULT_HEADERS }),
            fetch(API.currencies, { headers: DEFAULT_HEADERS }),
            fetch(API.productTaxes, { headers: DEFAULT_HEADERS })
        ])

        if (!prodRes.ok) throw new Error(`Products ${prodRes.status}`)
        if (!groupRes.ok) throw new Error(`Groups ${groupRes.status}`)
        if (!bcRes.ok) throw new Error(`Barcodes ${bcRes.status}`)
        if (!curRes.ok) console.warn('Currencies failed', curRes.status)
        if (!taxRes.ok) console.warn('Taxes failed', taxRes.status)

        catalog = await prodRes.json() || []
        groups = await groupRes.json() || []
        const bcList = await bcRes.json() || []
        currencies = curRes.ok ? (await curRes.json() || []) : []
        const taxList = taxRes.ok ? (await taxRes.json() || []) : []

        // maps
        barcodeMap = new Map()
        bcList.forEach(bc => {
            const code = bc.barcode || bc.barCode || bc.code
            const pid = bc.productId || bc.productID || bc.productid
            if (code && pid) barcodeMap.set(String(code), Number(pid))
        })

        taxesByProduct = new Map()
        taxList.forEach(t => {
            const pid = t.productId || t.productID
            const percent = t.taxPercent ?? t.vatPercent ?? t.percent
            if (pid != null && percent != null) taxesByProduct.set(Number(pid), Number(percent) / 100)
        })

        // currency
        if (currencies.length) {
            const def = currencies.find(c => c.isDefault) || currencies[0]
            currencyCode = def?.code || def?.symbol || '$'
        } else {
            const codes = new Set(catalog.map(p => p.currencyCode).filter(Boolean))
            if (codes.size === 1) currencyCode = [...codes][0]
        }

        // initial render
        activeGroupId = null
        filtered = [...catalog]
        renderGroups()
        renderStats()
        renderProducts()

        setStatus('Ready')
    } catch (err) {
        console.error(err)
        $('#catalogErrorMessage').textContent = `Failed to load catalog: ${err.message}`
        show('catalogError', true)
        setStatus('Error')
    } finally {
        show('catalogLoading', false)
    }
}

// ---------------------- FILTERING ----------------------
function applyFilters() {
    const q = $('#productSearch').value.trim().toLowerCase()
    filtered = catalog.filter(p => {
        const inGroup = activeGroupId == null || p.productGroupId === activeGroupId
        if (!inGroup) return false
        if (!q) return true
        const hay = [p.name, p.code, p.plu, p.productGroupName, p.description]
            .map(x => (x ?? '').toString().toLowerCase())
        return hay.some(h => h.includes(q))
    })
    renderStats()
    renderProducts()
}

function renderGroups() {
    const wrap = $('#groupPills')
    const pills = [
        `<button class="group-pill ${activeGroupId == null ? 'active' : ''}" data-id="">All</button>`,
        ...groups.map(g => `<button class="group-pill ${activeGroupId === g.id ? 'active' : ''}" data-id="${g.id}">${escapeHtml(g.name ?? 'Group')}</button>`)
    ].join('')
    wrap.innerHTML = pills
    $$('#groupPills .group-pill').forEach(btn => {
        btn.addEventListener('click', () => {
            const id = btn.dataset.id
            activeGroupId = id === '' ? null : Number(id)
            $$('#groupPills .group-pill').forEach(b => b.classList.remove('active'))
            btn.classList.add('active')
            applyFilters()
        })
    })
}

function renderStats() {
    $('#statProducts').textContent = filtered.length
    $('#statGroups').textContent = new Set(catalog.map(p => p.productGroupName).filter(Boolean)).size
    const avg = filtered.length ? filtered.reduce((s, p) => s + Number(p.price || 0), 0) / filtered.length : 0
    $('#statAvgPrice').textContent = fmt(avg)
    show('catalogStats', true)
}

// ---------------------- CATALOG RENDER ----------------------
function renderProducts() {
    const grid = $('#productGrid')
    if (!filtered.length) {
        grid.innerHTML = ''
        show('noCatalogResults', true)
        return
    }
    show('noCatalogResults', false)
    grid.innerHTML = filtered.map(p => productCardHTML(p)).join('')
    // add-to-cart handlers
    $$('#productGrid .product-card').forEach(card => {
        card.addEventListener('click', () => {
            const id = Number(card.dataset.id)
            const prod = catalog.find(p => p.id === id)
            if (prod) addToCart(prod)
        })
    })
}

function productCardHTML(p) {
    const price = Number(p.price || 0)
    const badge = p.isService ? 'Service' : 'Product'
    const colorTag = p.color && p.color !== 'Transparent'
        ? `<span class="tag" style="border:1px solid #e1e1e1">${escapeHtml(p.color)}</span>` : ''
    return `
    <div class="product-card" data-id="${p.id}">
      <div class="pc-top">
        <span class="pc-name">${escapeHtml(p.name || 'Unnamed')}</span>
        <span class="pc-price">${fmt(price)}</span>
      </div>
      <div class="pc-body">
        <div class="pc-tags">
          <span class="tag">${escapeHtml(p.productGroupName || '—')}</span>
          <span class="tag">${escapeHtml(badge)}</span>
          ${colorTag}
        </div>
      </div>
    </div>
  `
}

// ---------------------- BARCODE ----------------------
function handleBarcode(code) {
    const pid = barcodeMap.get(String(code))
    let product = pid ? catalog.find(p => p.id === pid) : null
    if (!product) {
        const q = code.toLowerCase()
        product = catalog.find(p =>
            String(p.code ?? '').toLowerCase() === q ||
            String(p.plu ?? '').toLowerCase() === q ||
            String(p.name ?? '').toLowerCase() === q
        )
    }
    if (product) { addToCart(product); toast(`Added: ${product.name}`) }
    else toast('No product found for this code')
}

// ---------------------- CART ----------------------
function addToCart(product) {
    const idx = cart.findIndex(i => i.id === product.id)
    const taxPercent = taxesByProduct.get(product.id) ?? 0
    const itemShape = {
        id: product.id,
        name: product.name,
        price: Number(product.price || 0),
        qty: 1,
        taxPercent,
        taxInclusive: !!product.isTaxInclusivePrice,
        currencyCode: product.currencyCode || currencyCode
    }
    if (idx >= 0) cart[idx].qty += 1
    else cart.push(itemShape)
    renderCart()
}

function renderCart() {
    const list = $('#cartList')
    if (!cart.length) {
        list.innerHTML = `
      <div class="no-results">
        <h3>No items in order</h3>
        <p>Tap a product or scan a barcode to add</p>
      </div>
    `
        updateTotals()
        return
    }
    list.innerHTML = cart.map(item => cartRowHTML(item)).join('')
    $$('#cartList .qty-dec').forEach(btn => btn.addEventListener('click', () => stepQty(btn.dataset.id, -1)))
    $$('#cartList .qty-inc').forEach(btn => btn.addEventListener('click', () => stepQty(btn.dataset.id, +1)))
    $$('#cartList .qty-input').forEach(inp => inp.addEventListener('input', onQtyInput))
    $$('#cartList .remove-btn').forEach(btn => btn.addEventListener('click', () => removeItem(btn.dataset.id)))
    updateTotals()
}

function cartRowHTML(item) {
    const lineTotals = computeLine(item)
    return `
    <div class="cart-row">
      <div>
        <div class="cart-title">${escapeHtml(item.name)}</div>
        <div class="cart-meta">${fmt(item.price)} ${item.taxInclusive ? '(tax inc.)' : ''}</div>
      </div>
      <div class="qty">
        <button class="qty-dec" data-id="${item.id}">−</button>
        <input class="qty-input" data-id="${item.id}" value="${item.qty}" inputmode="numeric"/>
        <button class="qty-inc" data-id="${item.id}">+</button>
      </div>
      <div class="line-total">${fmt(lineTotals.gross)}</div>
      <button class="remove-btn" title="Remove" data-id="${item.id}">×</button>
    </div>
  `
}

function stepQty(id, delta) {
    id = Number(id)
    const idx = cart.findIndex(i => i.id === id)
    if (idx < 0) return
    cart[idx].qty = Math.max(0, Number(cart[idx].qty) + delta)
    if (cart[idx].qty === 0) cart.splice(idx, 1)
    renderCart()
}

function onQtyInput(e) {
    const id = Number(e.target.dataset.id)
    const val = clampInt(e.target.value, 1, 9999)
    e.target.value = val
    const item = cart.find(i => i.id === id)
    if (item) {
        item.qty = val
        updateTotals()
        const row = e.target.closest('.cart-row')
        if (row) row.querySelector('.line-total').textContent = fmt(computeLine(item).gross)
    }
}

function clampInt(v, min, max) { const n = Math.floor(Number(v || 0)); if (isNaN(n)) return min; return Math.max(min, Math.min(max, n)) }
function removeItem(id) { id = Number(id); cart = cart.filter(i => i.id !== id); renderCart() }
function clearCart() { if (!cart.length) return; cart = []; renderCart() }

// ---------------------- TOTALS & TAX ----------------------
function computeLine(item) {
    const qty = Number(item.qty || 0)
    const price = Number(item.price || 0)
    const tax = Number(item.taxPercent || 0)
    if (item.taxInclusive) {
        const netUnit = price / (1 + tax)
        const taxUnit = price - netUnit
        return { net: netUnit * qty, tax: taxUnit * qty, gross: price * qty }
    } else {
        const taxUnit = price * tax
        return { net: price * qty, tax: taxUnit * qty, gross: (price + taxUnit) * qty }
    }
}

function updateTotals() {
    let net = 0, tax = 0, gross = 0
    cart.forEach(item => { const t = computeLine(item); net += t.net; tax += t.tax; gross += t.gross })
    $('#subtotal').textContent = fmt(net)
    $('#taxTotal').textContent = fmt(tax)
    $('#grandTotal').textContent = fmt(gross)
    updateChange()
    updateConfirmPreview()
}

function updateChange() {
    const tendered = Number($('#amountTendered').value || 0)
    const total = Number($('#grandTotal').textContent.replace(/[^\d.]/g, '')) || 0
    const change = Math.max(0, tendered - total)
    $('#changeDue').textContent = fmt(change)
}

// ---------------------- CONFIRMATION ----------------------
function openConfirm() {
    if (!cart.length) { toast('Cart is empty'); return }
    updateConfirmPreview()
    show('confirmModal', true)
}
function closeConfirm() { show('confirmModal', false) }
function updateConfirmPreview() {
    const items = cart.reduce((s, i) => s + Number(i.qty || 0), 0)
    const total = Number($('#grandTotal').textContent.replace(/[^\d.]/g, '')) || 0
    $('#confirmItems').textContent = items
    $('#confirmTotal').textContent = fmt(total)
    $('#confirmMethod').textContent = payMethod[0].toUpperCase() + payMethod.slice(1)
}

// ---------------------- ORDER POSTING ----------------------
async function postOrder(status = 'completed') {
    if (!cart.length) { toast('Cart is empty'); return }

    try {
        setStatus(status === 'completed' ? 'Posting order…' : 'Saving order…')
        $('#confirmSubmit')?.setAttribute('disabled', 'true')

        const totals = {
            subtotal: Number($('#subtotal').textContent.replace(/[^\d.]/g, '')) || 0,
            tax: Number($('#taxTotal').textContent.replace(/[^\d.]/g, '')) || 0,
            total: Number($('#grandTotal').textContent.replace(/[^\d.]/g, '')) || 0
        }

        // Payloads may need adjusting to your DTO
        const orderPayload = {
            orderDate: new Date().toISOString(),
            paymentMethod: status === 'completed' ? payMethod : 'pending',
            currencyCode,
            totalAmount: totals.total,
            taxAmount: totals.tax,
            note: status === 'completed' ? '' : 'Saved from POS (draft)',
            status // optional: server may ignore
        }

        const orderRes = await fetch(API.posOrdersAdd, {
            method: 'POST',
            headers: DEFAULT_HEADERS,
            body: JSON.stringify(orderPayload)
        })
        if (!orderRes.ok) throw new Error(`PosOrders/Add ${orderRes.status}`)
        const orderData = await orderRes.json().catch(() => ({}))
        const orderId = orderData.id ?? orderData.orderId ?? orderData.data?.id

        // Post items
        for (const item of cart) {
            const line = computeLine(item)
            const itemPayload = {
                orderId,
                productId: item.id,
                qty: item.qty,
                unitPrice: item.price,
                taxPercent: item.taxPercent,   // 0..1
                taxInclusive: item.taxInclusive,
                lineSubtotal: Number(line.net.toFixed(2)),
                lineTax: Number(line.tax.toFixed(2)),
                lineTotal: Number(line.gross.toFixed(2))
            }
            const itemRes = await fetch(API.posOrderItemsAdd, {
                method: 'POST',
                headers: DEFAULT_HEADERS,
                body: JSON.stringify(itemPayload)
            })
            if (!itemRes.ok) throw new Error(`PosOrderItems/Add ${itemRes.status}`)
        }

        toast(status === 'completed' ? 'Sale completed' : 'Order saved')
        closeConfirm()
        clearCart()
        setStatus('Ready')
    } catch (err) {
        console.error(err)
        toast(`Failed: ${err.message}`)
        setStatus('Error')
    } finally {
        $('#confirmSubmit')?.removeAttribute('disabled')
    }
}
