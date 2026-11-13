#!/usr/bin/env python3
import http.server
import json
import os
import socketserver
from urllib.parse import urlparse

PORT = 3000
APK_PATH = "/app/applet/.build-outputs/app-debug.apk"
CONTENT_PATH = "/app/applet/app/src/main/assets/content.json"
ART_DIR = "/app/applet/app/src/main/assets/art"

HTML_PAGE = r"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>摸索台灯 · Android 原生 Material 3 预览与 APK</title>
<style>
  :root {
    --paper: #F7F4EC;
    --surf: #EFECE2;
    --surf-low: #F3F0E7;
    --surf-lowest: #FDFBF6;
    --surf-high: #E7E3D7;
    --ink: #1F241F;
    --sub: #545B52;
    --outline: #CEC9BA;
    --moss: #486856;
    --moss-container: #CBE4D3;
    --on-moss-container: #142E20;
    --bead: #D9A441;
    --bead-light: #F3DFB2;
    --sec-container: #DCE5DC;
    --err-container: #F9DEDC;
    --on-err-container: #410E0B;
  }
  * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
  body {
    margin: 0;
    font-family: system-ui, -apple-system, "Noto Sans SC", Roboto, sans-serif;
    background: #E4E0D4;
    color: var(--ink);
    display: flex;
    flex-direction: column;
    align-items: center;
    min-height: 100vh;
    padding: 12px;
  }
  .top-banner {
    width: 100%;
    max-width: 440px;
    background: var(--surf-lowest);
    border-radius: 20px;
    padding: 10px 14px;
    margin-bottom: 10px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 10px;
    border: 1px solid var(--outline);
  }
  .top-banner .meta {
    font-size: 12px;
    color: var(--sub);
  }
  .top-banner .meta strong {
    color: var(--moss);
    display: block;
    font-size: 13px;
  }
  .apk-btn {
    background: var(--moss);
    color: #fff;
    text-decoration: none;
    font-size: 12px;
    font-weight: 600;
    padding: 8px 14px;
    border-radius: 14px;
    white-space: nowrap;
  }
  .phone {
    width: 100%;
    max-width: 440px;
    height: calc(100vh - 82px);
    min-height: 640px;
    max-height: 880px;
    background: var(--paper);
    border-radius: 36px;
    box-shadow: 0 14px 36px rgba(25, 32, 25, 0.14);
    border: 4px solid #2A302B;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    position: relative;
  }
  .status-bar {
    height: 28px;
    padding: 0 22px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    font-size: 11px;
    font-weight: 600;
    color: var(--sub);
    flex-shrink: 0;
  }
  .screen {
    flex: 1;
    overflow-y: auto;
    padding: 6px 14px 24px 14px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .card {
    background: var(--surf-lowest);
    border-radius: 26px;
    padding: 18px;
  }
  .card.hero {
    background: var(--surf);
    border-radius: 30px;
  }
  .card.tray {
    background: var(--surf-low);
    border: 1.5px solid #D9CFB8;
    border-radius: 28px;
  }
  .row { display: flex; align-items: center; gap: 10px; }
  .between { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
  .chips {
    display: flex;
    gap: 8px;
    overflow-x: auto;
    padding-bottom: 4px;
    scrollbar-width: none;
  }
  .chips::-webkit-scrollbar { display: none; }
  .chip {
    border: 1px solid var(--outline);
    background: var(--surf-low);
    color: var(--ink);
    padding: 7px 13px;
    border-radius: 14px;
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    white-space: nowrap;
    user-select: none;
    transition: all 0.15s ease;
  }
  .chip.active {
    background: var(--moss-container);
    color: var(--on-moss-container);
    border-color: var(--moss);
  }
  .btn {
    border: none;
    background: var(--moss);
    color: #fff;
    padding: 10px 16px;
    border-radius: 16px;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
  }
  .btn.tonal {
    background: var(--sec-container);
    color: var(--on-moss-container);
  }
  .btn.bead {
    background: var(--bead);
    color: var(--ink);
  }
  .btn.outline {
    background: transparent;
    border: 1px solid var(--outline);
    color: var(--ink);
  }
  .sec-title {
    padding: 4px 4px 0 4px;
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
  }
  .sec-title h3 { margin: 0; font-size: 18px; }
  .sec-title span { font-size: 11px; color: var(--sub); }
  .sandpaper {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    background: #E5DEC9;
    color: var(--moss);
    font-weight: 800;
    border-radius: 12px;
    padding: 4px 11px;
    font-variant-numeric: tabular-nums;
  }
  .quick-grid {
    display: grid;
    grid-template-columns: repeat(5, 1fr);
    gap: 8px;
  }
  .quick-item {
    background: var(--surf-low);
    border-radius: 20px;
    padding: 10px 4px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 5px;
    cursor: pointer;
    font-size: 12px;
    font-weight: 600;
    border: 1px solid transparent;
  }
  .quick-item:active { transform: scale(0.96); }
  .badge {
    width: 36px;
    height: 36px;
    border-radius: 14px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 700;
    font-size: 15px;
  }
  .tag-row {
    display: flex;
    gap: 8px;
    align-items: baseline;
    margin-top: 6px;
    font-size: 13px;
    line-height: 1.5;
  }
  .tag-label {
    font-size: 11px;
    font-weight: 700;
    color: var(--moss);
    background: var(--moss-container);
    padding: 2px 7px;
    border-radius: 8px;
    flex-shrink: 0;
  }
  .navbar {
    height: 68px;
    background: var(--surf-low);
    border-top: 1px solid var(--outline);
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    padding: 6px 8px;
    flex-shrink: 0;
  }
  .nav-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 3px;
    cursor: pointer;
    color: var(--sub);
    font-size: 11px;
    font-weight: 600;
  }
  .nav-pill {
    padding: 3px 16px;
    border-radius: 14px;
    font-size: 15px;
  }
  .nav-item.active { color: var(--ink); }
  .nav-item.active .nav-pill {
    background: var(--moss-container);
    color: var(--on-moss-container);
  }
  .check-row {
    display: flex;
    align-items: flex-start;
    gap: 10px;
    padding: 8px;
    border-radius: 12px;
    cursor: pointer;
  }
  .check-row:hover { background: var(--surf-low); }
  .check-circle {
    width: 22px;
    height: 22px;
    border-radius: 50%;
    border: 2px solid var(--moss);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    margin-top: 1px;
    color: #fff;
    font-size: 12px;
  }
  .check-circle.done { background: var(--moss); }
  .modal-backdrop {
    position: absolute;
    inset: 0;
    background: rgba(20, 26, 20, 0.42);
    display: flex;
    align-items: flex-end;
    z-index: 20;
  }
  .sheet {
    width: 100%;
    max-height: 86%;
    overflow-y: auto;
    background: var(--surf-lowest);
    border-radius: 28px 28px 0 0;
    padding: 20px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .segmented {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    background: var(--surf);
    border-radius: 16px;
    padding: 3px;
    gap: 3px;
  }
  .seg-btn {
    border: none;
    background: transparent;
    padding: 8px 6px;
    border-radius: 13px;
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    color: var(--sub);
  }
  .seg-btn.active {
    background: var(--moss-container);
    color: var(--on-moss-container);
  }
  .toast {
    position: absolute;
    bottom: 78px;
    left: 18px;
    right: 18px;
    background: #232A24;
    color: #fff;
    padding: 12px 16px;
    border-radius: 16px;
    font-size: 13px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    z-index: 30;
  }
</style>
</head>
<body>
  <div class="top-banner">
    <div class="meta">
      <strong>摸索台灯 (Mossling) · 纯正 Android Material 3</strong>
      <span>Compose Canvas 原生矢量 IP（小苔 Moss & 奥托 Otto）· 已通过编译与 14 项单测</span>
    </div>
    <a class="apk-btn" href="/app-debug.apk" download="mossling-debug.apk">下载 APK</a>
  </div>

  <div class="phone">
    <div class="status-bar">
      <span>9:41</span>
      <span>Android Material 3 Expressive</span>
    </div>
    <div id="screen" class="screen"></div>
    <div id="toast-box"></div>
    <div id="modal-box"></div>
    <div class="navbar">
      <div class="nav-item active" onclick="switchTab('today')" id="tab-today">
        <div class="nav-pill">☀</div>
        <span>今天</span>
      </div>
      <div class="nav-item" onclick="switchTab('grow')" id="tab-grow">
        <div class="nav-pill">●●○</div>
        <span>成长</span>
      </div>
      <div class="nav-item" onclick="switchTab('journal')" id="tab-journal">
        <div class="nav-pill">✎</div>
        <span>手帐</span>
      </div>
      <div class="nav-item" onclick="switchTab('you')" id="tab-you">
        <div class="nav-pill">☺</div>
        <span>我的</span>
      </div>
    </div>
  </div>

<script>
let DATA = null;
let STATE = {
  tab: 'today',
  month: 6,
  babyMonth: 6,
  companion: 'moss',
  domainKey: 'A',
  expandAllDomains: false,
  observeGroup: null,
  donePlays: { 'A19': true },
  observed: { '6:0-0': true },
  logs: [
    { id: 1, type: 'bottle', label: '瓶喂', detail: '母乳 · 150 毫升', time: '08:30', cat: '喂养' },
    { id: 2, type: 'sleep', label: '睡觉', detail: '1 小时 15 分钟', time: '09:40–10:55', cat: '睡眠' },
    { id: 3, type: 'diaper', label: '尿布', detail: '湿了', time: '11:05', cat: '尿布' }
  ],
  logFilter: '全部',
  bottleMl: 150,
  bottleKind: '母乳',
  activeTopicId: null,
  aboutTab: 0,
  aboutLevel: null
};

function mossSvg(kind = 'moss', size = 68) {
  if (kind === 'otto') {
    return `<svg width="${size}" height="${size}" viewBox="0 0 100 100">
      <circle cx="50" cy="54" r="36" fill="#D9A441" opacity="0.22"/>
      <circle cx="30" cy="30" r="10" fill="#8C6239"/>
      <circle cx="70" cy="30" r="10" fill="#8C6239"/>
      <ellipse cx="50" cy="56" rx="30" ry="28" fill="#A67649"/>
      <ellipse cx="50" cy="60" rx="18" ry="14" fill="#E6D2B5"/>
      <circle cx="41" cy="50" r="3.2" fill="#1F241F"/>
      <circle cx="59" cy="50" r="3.2" fill="#1F241F"/>
      <ellipse cx="50" cy="56" rx="4.5" ry="3.2" fill="#3B2818"/>
    </svg>`;
  }
  return `<svg width="${size}" height="${size}" viewBox="0 0 100 100">
    <circle cx="50" cy="54" r="38" fill="#D9A441" opacity="0.22"/>
    <path d="M50 18 C45 10, 58 10, 52 18" stroke="#486856" stroke-width="3" fill="none"/>
    <ellipse cx="45" cy="15" rx="6" ry="3.5" fill="#689278" transform="rotate(-20 45 15)"/>
    <ellipse cx="55" cy="15" rx="6" ry="3.5" fill="#689278" transform="rotate(20 55 15)"/>
    <ellipse cx="50" cy="56" rx="31" ry="29" fill="#5D826B"/>
    <circle cx="40" cy="52" r="3.3" fill="#1F241F"/>
    <circle cx="60" cy="52" r="3.3" fill="#1F241F"/>
    <circle cx="34" cy="58" r="4" fill="#D98B73" opacity="0.55"/>
    <circle cx="66" cy="58" r="4" fill="#D98B73" opacity="0.55"/>
    <path d="M45 60 Q50 64 55 60" stroke="#1F241F" stroke-width="2.2" fill="none" stroke-linecap="round"/>
  </svg>`;
}

function showToast(msg) {
  const box = document.getElementById('toast-box');
  box.innerHTML = `<div class="toast"><span>${msg}</span><span style="color:#F3DFB2;cursor:pointer" onclick="this.parentElement.remove()">知道了</span></div>`;
  setTimeout(() => { box.innerHTML = ''; }, 2600);
}

function closeModal() {
  document.getElementById('modal-box').innerHTML = '';
}

function switchTab(t) {
  STATE.tab = t;
  ['today', 'grow', 'journal', 'you'].forEach(k => {
    document.getElementById('tab-' + k).classList.toggle('active', k === t);
  });
  render();
}

function openBottleSheet() {
  const m = document.getElementById('modal-box');
  m.innerHTML = `
    <div class="modal-backdrop" onclick="if(event.target===this)closeModal()">
      <div class="sheet">
        <div class="between">
          <h3 style="margin:0">瓶喂 · 喝了多少</h3>
          <button class="chip" onclick="closeModal()">关闭</button>
        </div>
        <div class="chips">
          ${['母乳', '配方奶', '水'].map(k => `<div class="chip ${STATE.bottleKind===k?'active':''}" onclick="STATE.bottleKind='${k}';openBottleSheet()">${k}</div>`).join('')}
        </div>
        <div class="row" style="justify-content:center;padding:8px 0">
          <button class="btn outline" onclick="STATE.bottleMl=Math.max(5,STATE.bottleMl-10);openBottleSheet()">−10</button>
          <button class="btn outline" onclick="STATE.bottleMl=Math.max(5,STATE.bottleMl-5);openBottleSheet()">−5</button>
          <div style="font-size:24px;font-weight:800;padding:0 10px;font-variant-numeric:tabular-nums">${STATE.bottleMl} 毫升</div>
          <button class="btn outline" onclick="STATE.bottleMl=Math.min(360,STATE.bottleMl+5);openBottleSheet()">+5</button>
          <button class="btn outline" onclick="STATE.bottleMl=Math.min(360,STATE.bottleMl+10);openBottleSheet()">+10</button>
        </div>
        <div class="chips">
          ${[60, 90, 120, 150, 180, 210].map(p => `<div class="chip ${STATE.bottleMl===p?'active':''}" onclick="STATE.bottleMl=${p};openBottleSheet()">${p}</div>`).join('')}
        </div>
        <button class="btn" style="width:100%;padding:14px" onclick="saveBottle()">记下来</button>
      </div>
    </div>`;
}

function saveBottle() {
  STATE.logs.unshift({
    id: Date.now(),
    type: 'bottle',
    label: '瓶喂',
    detail: `${STATE.bottleKind} · ${STATE.bottleMl} 毫升`,
    time: '刚刚',
    cat: '喂养'
  });
  closeModal();
  showToast(`记下了：瓶喂 · ${STATE.bottleMl} 毫升`);
  render();
}

function openFollowAlong(code, stepIdx = 0) {
  if (!DATA) return;
  const play = DATA.activities.find(a => a.code === code) || DATA.activities[0];
  const total = play.steps.length;
  const isDonePage = stepIdx >= total;
  const m = document.getElementById('modal-box');
  if (!isDonePage) {
    m.innerHTML = `
      <div class="modal-backdrop" onclick="if(event.target===this)closeModal()">
        <div class="sheet" style="min-height:76%">
          <div class="between">
            <button class="chip" onclick="closeModal()">✕ 退出跟着做</button>
            <div style="display:flex;gap:6px">
              ${play.steps.map((_, i) => `<span style="width:10px;height:10px;border-radius:50%;background:${i<=stepIdx?'#D9A441':'#CEC9BA'};display:inline-block"></span>`).join('')}
            </div>
            <span style="font-size:12px;font-weight:700">${stepIdx + 1}/${total}</span>
          </div>
          <div style="font-size:12px;color:var(--moss);font-weight:700">${play.code} · ${play.name}</div>
          <div class="card" style="background:var(--surf-low)">
            <div class="row" style="align-items:flex-start">
              <span class="sandpaper">${stepIdx + 1}</span>
              <div style="font-size:17px;font-weight:600;line-height:1.5">${play.steps[stepIdx]}</div>
            </div>
            ${stepIdx === 0 && play.prepare ? `<div class="tag-row"><span class="tag-label">准备</span><span>${play.prepare}</span></div>` : ''}
            ${play.safety ? `<div class="tag-row"><span class="tag-label" style="background:var(--err-container);color:var(--on-err-container)">注意</span><span>${play.safety}</span></div>` : ''}
          </div>
          <div style="font-size:12px;color:var(--sub);text-align:center">左右滑动或点击下方按钮切换步骤</div>
          <div class="row" style="margin-top:auto">
            <button class="btn outline" style="flex:1" onclick="${stepIdx>0 ? `openFollowAlong('${play.code}',${stepIdx-1})` : 'closeModal()'}">${stepIdx>0 ? '上一步' : '稍后继续'}</button>
            <button class="btn" style="flex:1" onclick="openFollowAlong('${play.code}',${stepIdx+1})">${stepIdx===total-1 ? '看小结' : '下一步'}</button>
          </div>
        </div>
      </div>`;
  } else {
    m.innerHTML = `
      <div class="modal-backdrop" onclick="if(event.target===this)closeModal()">
        <div class="sheet">
          <div style="text-align:center">${mossSvg(STATE.companion, 76)}</div>
          <h3 style="margin:0;text-align:center">${play.name}</h3>
          <div class="card" style="background:var(--surf-low)">
            ${play.observe ? `<div class="tag-row"><span class="tag-label">看到什么</span><span>${play.observe}</span></div>` : ''}
            ${play.stop ? `<div class="tag-row"><span class="tag-label">停一下</span><span>${play.stop}</span></div>` : ''}
          </div>
          <div class="row">
            <button class="btn outline" style="flex:1" onclick="openFollowAlong('${play.code}',${total-1})">回上一步</button>
            <button class="btn bead" style="flex:1.4" onclick="STATE.donePlays['${play.code}']=true;closeModal();showToast('记下了：今天玩了「${play.name}」');render()">✓ 做完了，记一次</button>
          </div>
        </div>
      </div>`;
  }
}

function openTopicModal(topicId) {
  if (!DATA) return;
  STATE.activeTopicId = topicId || DATA.topics[0].id;
  const tp = DATA.topics.find(t => t.id === STATE.activeTopicId) || DATA.topics[0];
  const m = document.getElementById('modal-box');
  m.innerHTML = `
    <div class="modal-backdrop" onclick="if(event.target===this)closeModal()">
      <div class="sheet" style="height:88%;max-height:88%">
        <div class="between">
          <h3 style="margin:0">${tp.title}</h3>
          <button class="chip" onclick="closeModal()">返回</button>
        </div>
        <div class="chips">
          ${DATA.topics.map(t => `<div class="chip ${t.id===tp.id?'active':''}" onclick="openTopicModal('${t.id}')">${t.title}</div>`).join('')}
        </div>
        <div style="display:flex;flex-direction:column;gap:10px">
          ${tp.blocks.map(b => renderBlock(b)).join('')}
        </div>
      </div>
    </div>`;
}

function renderBlock(b) {
  const clean = s => (s || '').replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');
  if (b.type === 'h2' || b.type === 'h3') {
    return `<div style="font-weight:700;color:var(--moss);margin-top:6px;font-size:${b.type==='h2'?'16px':'14px'}">${clean(b.text)}</div>`;
  }
  if (b.type === 'quote') {
    return `<div class="card" style="background:rgba(220,229,220,0.6);padding:14px;font-size:13px;line-height:1.5">💡 ${clean(b.text)}</div>`;
  }
  if (b.type === 'ul' && b.items) {
    return `<div class="card" style="background:var(--surf-low);padding:12px 14px;display:flex;flex-direction:column;gap:8px">
      ${b.items.map(it => `<div style="font-size:13px;line-height:1.5;display:flex;gap:8px"><span style="color:var(--moss)">●</span><span>${clean(it)}</span></div>`).join('')}
    </div>`;
  }
  if (b.type === 'table' && b.rows) {
    return `<div style="display:flex;flex-direction:column;gap:6px">
      ${b.rows.map(r => `<div class="card" style="background:var(--surf-low);padding:10px 12px;display:flex;gap:10px;align-items:flex-start">
        <span class="tag-label">${clean(r[0])}</span>
        <div style="font-size:12px;line-height:1.45">${r.slice(1).map(clean).join(' · ')}</div>
      </div>`).join('')}
    </div>`;
  }
  return `<div class="card" style="padding:12px 14px;font-size:13px;line-height:1.55">${clean(b.text)}</div>`;
}

function openAboutModal() {
  if (!DATA) return;
  const m = document.getElementById('modal-box');
  const refs = DATA.about.references.filter(r => !STATE.aboutLevel || r.level === STATE.aboutLevel);
  let body = '';
  if (STATE.aboutTab === 0) {
    body = DATA.about.intro.map(renderBlock).join('');
  } else if (STATE.aboutTab === 1) {
    body = `
      <div class="chips">
        <div class="chip ${!STATE.aboutLevel?'active':''}" onclick="STATE.aboutLevel=null;openAboutModal()">全部 (${DATA.about.references.length})</div>
        <div class="chip ${STATE.aboutLevel==='A'?'active':''}" onclick="STATE.aboutLevel='A';openAboutModal()">等级 A</div>
        <div class="chip ${STATE.aboutLevel==='B'?'active':''}" onclick="STATE.aboutLevel='B';openAboutModal()">等级 B</div>
      </div>
      ${refs.map(r => `<div class="card" style="background:var(--surf-low);padding:14px">
        <div class="between"><span class="tag-label">证据等级 ${r.level}</span><span style="font-size:11px;color:var(--sub)">${r.year} · ${r.org}</span></div>
        <div style="font-weight:700;font-size:14px;margin-top:6px">${r.title}</div>
        <div style="font-size:12px;color:var(--sub);margin-top:4px">${r.scope}</div>
      </div>`).join('')}`;
  } else {
    body = DATA.about.claims.slice(0, 20).map(c => `<div class="card" style="background:var(--surf-low);padding:14px">
      <div style="font-weight:600;font-size:13px">${c.claim}</div>
      <div style="font-size:11px;color:var(--moss);margin-top:6px">${c.source} · 等级 ${c.level}</div>
    </div>`).join('');
  }
  m.innerHTML = `
    <div class="modal-backdrop" onclick="if(event.target===this)closeModal()">
      <div class="sheet" style="height:88%;max-height:88%">
        <div class="between">
          <h3 style="margin:0">内容来源与分级</h3>
          <button class="chip" onclick="closeModal()">返回</button>
        </div>
        <div class="segmented">
          <button class="seg-btn ${STATE.aboutTab===0?'active':''}" onclick="STATE.aboutTab=0;openAboutModal()">分级与方法</button>
          <button class="seg-btn ${STATE.aboutTab===1?'active':''}" onclick="STATE.aboutTab=1;openAboutModal()">参考文献 (${DATA.about.references.length})</button>
          <button class="seg-btn ${STATE.aboutTab===2?'active':''}" onclick="STATE.aboutTab=2;openAboutModal()">核对台账 (${DATA.about.claims.length})</button>
        </div>
        <div style="display:flex;flex-direction:column;gap:10px">${body}</div>
      </div>
    </div>`;
}

function render() {
  const el = document.getElementById('screen');
  if (!DATA) {
    el.innerHTML = `<div class="card">正在加载本地内容库…</div>`;
    return;
  }
  const guide = DATA.months.find(m => m.month === STATE.month) || DATA.months[0];
  const play = DATA.activities.find(a => a.months.includes(STATE.month)) || DATA.activities[0];

  if (STATE.tab === 'today') {
    const done = !!STATE.donePlays[play.code];
    el.innerHTML = `
      <div class="card hero">
        <div class="between">
          <div>
            <div style="font-size:12px;color:var(--sub)">小芽 · 11月13日 · 星期五</div>
            <div class="row" style="margin-top:8px;align-items:baseline">
              <span class="sandpaper" style="font-size:28px">${STATE.babyMonth}</span>
              <div>
                <div style="font-size:18px;font-weight:700">个月 12 天</div>
                <div style="font-size:11px;color:var(--sub)">第 ${STATE.babyMonth} 站 · ${guide.title}</div>
              </div>
            </div>
            <div class="row" style="margin-top:10px">
              <span class="chip" onclick="switchTab('grow')">0–36 个月成长地图</span>
              <span class="chip" onclick="openAboutModal()">来源与分级</span>
            </div>
          </div>
          <div>${mossSvg(STATE.companion, 76)}</div>
        </div>
      </div>

      <div class="sec-title">
        <div><h3>记一下</h3><span>点一下就能记，也可直接开始计时</span></div>
      </div>
      <div class="quick-grid">
        <div class="quick-item" onclick="showToast('已开始左侧亲喂计时')"><div class="badge" style="background:#F3DDD4;color:#C2724F">♥</div><span>亲喂</span></div>
        <div class="quick-item" onclick="openBottleSheet()"><div class="badge" style="background:#F5E8C8;color:#B58324">🍼</div><span>瓶喂</span></div>
        <div class="quick-item" onclick="showToast('已开始睡眠计时')"><div class="badge" style="background:#DCE6EC;color:#486B82">☾</div><span>睡觉</span></div>
        <div class="quick-item" onclick="showToast('记下了：换尿布 · 湿了')"><div class="badge" style="background:#D8E8DD;color:#486856">◡</div><span>尿布</span></div>
        <div class="quick-item" onclick="switchTab('journal')"><div class="badge" style="background:#E7E3D7;color:#1F241F">＋</div><span>更多</span></div>
      </div>

      <div class="card tray">
        <div class="between">
          <div>
            <div style="font-size:12px;font-weight:700;color:var(--moss)">今天一起玩 ${done ? '· 今天玩过' : ''}</div>
            <div style="font-size:11px;color:var(--sub);margin-top:2px">${play.code} · 满 ${play.months[0]}–${play.months[play.months.length-1]} 个月</div>
          </div>
          <button class="chip ${done?'active':''}" onclick="STATE.donePlays['${play.code}']=!STATE.donePlays['${play.code}'];render()">${done ? '✓ 已做过' : '记为做过'}</button>
        </div>
        <h2 style="margin:10px 0 6px 0;font-size:21px">${play.name}</h2>
        ${play.prepare && play.prepare !== '无' ? `<div class="tag-row"><span class="tag-label">准备</span><span>${play.prepare}</span></div>` : ''}
        <div class="tag-row"><span class="tag-label">怎么做</span><span>${play.steps[0]}</span></div>
        ${play.observe ? `<div class="tag-row"><span class="tag-label">留意</span><span>${play.observe}</span></div>` : ''}
        <div class="between" style="margin-top:14px">
          <span style="font-size:12px;color:var(--moss);font-weight:600">共 ${play.steps.length} 步 · 点开跟着做</span>
          <button class="btn" onclick="openFollowAlong('${play.code}', 0)">开始跟着做</button>
        </div>
      </div>
    `;
  } else if (STATE.tab === 'grow') {
    const activeDom = guide.domains.find(d => d.key === STATE.domainKey) || guide.domains[0];
    el.innerHTML = `
      <div class="chips">
        ${[0,1,2,3,4,6,8,10,12,15,18,24,30,36].map(m => `<div class="chip ${STATE.month===m?'active':''}" onclick="STATE.month=${m};STATE.observeGroup=null;render()">满 ${m} 月</div>`).join('')}
      </div>
      <div class="card hero">
        <div class="between">
          <div>
            <div style="font-size:11px;color:var(--moss);font-weight:700">${STATE.month===STATE.babyMonth?'现在这一站':'第 '+STATE.month+' 站'} · 左右切月龄</div>
            <div class="row" style="margin:6px 0"><span style="font-size:20px;font-weight:700">满</span><span class="sandpaper" style="font-size:24px">${STATE.month}</span><span style="font-size:20px;font-weight:700">个月</span></div>
            <div style="font-size:13px;color:var(--sub)">${guide.title}</div>
          </div>
          <div class="row">
            <button class="btn outline" onclick="STATE.month=Math.max(0,STATE.month-1);render()">‹</button>
            <button class="btn outline" onclick="STATE.month=Math.min(36,STATE.month+1);render()">›</button>
          </div>
        </div>
      </div>

      <div class="sec-title">
        <div><h3>六个方面</h3><span>满 ${STATE.month} 个月 · 点色板切换领域</span></div>
        <span class="chip" onclick="STATE.expandAllDomains=!STATE.expandAllDomains;render()">${STATE.expandAllDomains ? '分项查看' : '全部展开'}</span>
      </div>
      ${STATE.expandAllDomains ? guide.domains.map(d => `
        <div class="card">
          <div style="font-weight:700;font-size:15px;color:var(--moss)">● ${d.name}</div>
          <div style="font-size:13px;line-height:1.55;margin-top:6px">${d.text.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')}</div>
        </div>`).join('') : `
        <div class="chips">
          ${guide.domains.map(d => `<div class="chip ${d.key===activeDom.key?'active':''}" onclick="STATE.domainKey='${d.key}';render()">● ${d.name}</div>`).join('')}
        </div>
        <div class="card">
          <div style="font-weight:700;font-size:16px;color:var(--moss)">${activeDom.name}</div>
          <div style="font-size:13px;line-height:1.6;margin-top:6px">${activeDom.text.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')}</div>
        </div>
      `}

      <div class="sec-title">
        <div><h3>可以留意</h3><span>观察参考，不是考试</span></div>
      </div>
      <div class="card">
        <div class="chips" style="margin-bottom:8px">
          <div class="chip ${!STATE.observeGroup?'active':''}" onclick="STATE.observeGroup=null;render()">全部</div>
          ${guide.observe.map(g => `<div class="chip ${STATE.observeGroup===g.group?'active':''}" onclick="STATE.observeGroup='${g.group}';render()">${g.group} (${g.items.length})</div>`).join('')}
        </div>
        ${guide.observe.filter(g => !STATE.observeGroup || g.group === STATE.observeGroup).map((g, gi) => `
          <div style="font-size:12px;font-weight:700;color:var(--moss);margin-top:8px">${g.group}</div>
          ${g.items.map((it, ii) => {
            const k = `${STATE.month}:${gi}-${ii}`;
            const ck = !!STATE.observed[k];
            return `<div class="check-row" onclick="STATE.observed['${k}']=!STATE.observed['${k}'];render()">
              <div class="check-circle ${ck?'done':''}">${ck?'✓':''}</div>
              <div style="font-size:13px;line-height:1.45">${it}</div>
            </div>`;
          }).join('')}
        `).join('')}
      </div>

      <div class="sec-title"><div><h3>常翻的专题</h3><span>点开即读 · 顶部可横向速切</span></div></div>
      <div class="chips">
        ${DATA.topics.map(t => `<div class="chip" onclick="openTopicModal('${t.id}')">💡 ${t.title}</div>`).join('')}
      </div>
    `;
  } else if (STATE.tab === 'journal') {
    const filtered = STATE.logs.filter(l => STATE.logFilter === '全部' || l.cat === STATE.logFilter);
    el.innerHTML = `
      <div class="card hero">
        <div class="between">
          <div>
            <div style="font-size:18px;font-weight:700">今天 · 11月13日</div>
            <div style="font-size:12px;color:var(--sub)">喂养 · 睡眠 · 尿布 · 5毫升精度瓶喂</div>
          </div>
          <button class="btn" onclick="openBottleSheet()">+ 记瓶喂</button>
        </div>
      </div>
      <div class="chips">
        ${['全部', '喂养', '睡眠', '尿布'].map(f => `<div class="chip ${STATE.logFilter===f?'active':''}" onclick="STATE.logFilter='${f}';render()">${f}</div>`).join('')}
      </div>
      ${filtered.map(l => `
        <div class="card between">
          <div>
            <div style="font-weight:700;font-size:15px">${l.label}</div>
            <div style="font-size:12px;color:var(--sub);margin-top:2px">${l.detail}</div>
          </div>
          <div style="font-size:12px;color:var(--sub);font-variant-numeric:tabular-nums">${l.time}</div>
        </div>
      `).join('')}
    `;
  } else {
    el.innerHTML = `
      <div class="card hero between">
        <div>
          <div style="font-size:20px;font-weight:700">小芽 · 满 ${STATE.babyMonth} 个月</div>
          <div style="font-size:12px;color:var(--sub);margin-top:4px">陪伴伙伴：${STATE.companion==='moss'?'小苔 Moss':'奥托 Otto'}（纯正 Android 矢量 IP）</div>
          <div class="row" style="margin-top:10px">
            <button class="chip ${STATE.companion==='moss'?'active':''}" onclick="STATE.companion='moss';render()">小苔 Moss</button>
            <button class="chip ${STATE.companion==='otto'?'active':''}" onclick="STATE.companion='otto';render()">奥托 Otto</button>
          </div>
        </div>
        <div>${mossSvg(STATE.companion, 76)}</div>
      </div>
      <div class="sec-title"><div><h3>常翻的专题</h3></div></div>
      <div class="chips">
        ${DATA.topics.map(t => `<div class="chip" onclick="openTopicModal('${t.id}')">💡 ${t.title}</div>`).join('')}
      </div>
      <div class="card" style="cursor:pointer" onclick="openAboutModal()">
        <div style="font-weight:700;font-size:16px">内容来源与分级方法</div>
        <div style="font-size:12px;color:var(--sub);margin-top:4px">三栏分段浏览：分级与方法 · ${DATA.about.references.length} 篇权威指南文献 · ${DATA.about.claims.length} 条核对台账</div>
      </div>
    `;
  }
}

fetch('/api/content').then(r => r.json()).then(d => { DATA = d; render(); });
</script>
</body>
</html>
"""

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/api/content":
            with open(CONTENT_PATH, "rb") as f:
                data = f.read()
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return

        if parsed.path == "/app-debug.apk" and os.path.exists(APK_PATH):
            size = os.path.getsize(APK_PATH)
            self.send_response(200)
            self.send_header("Content-Type", "application/vnd.android.package-archive")
            self.send_header("Content-Disposition", 'attachment; filename="mossling-debug.apk"')
            self.send_header("Content-Length", str(size))
            self.end_headers()
            with open(APK_PATH, "rb") as f:
                while chunk := f.read(65536):
                    self.wfile.write(chunk)
            return

        body = HTML_PAGE.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

class ReusableTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    allow_reuse_address = True

if __name__ == "__main__":
    with ReusableTCPServer(("0.0.0.0", PORT), Handler) as httpd:
        httpd.serve_forever()
