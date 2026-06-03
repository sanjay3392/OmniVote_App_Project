'use strict';

// ═══════════════════════════════════════════════
// STATE
// ═══════════════════════════════════════════════
const API  = '/api/admin';
let token  = null;
let admin  = null;
let curPage = 'dashboard';
let elPage = 1, uPage = 1, vPage = 1;
let allElections = [];         // cache for edit lookups
let charts = {};

// ═══════════════════════════════════════════════
// BOOT — runs when DOM is ready
// ═══════════════════════════════════════════════
document.addEventListener('DOMContentLoaded', function () {

  // Null-safe helper — prevents one missing element from crashing ALL listeners
  function on(id, evt, fn) {
    var el = document.getElementById(id);
    if (el) el.addEventListener(evt, fn);
  }

  // ── Login form ───────────────────────────────
  on('l-btn',  'click',   doLogin);
  on('l-pass', 'keydown', function (e) { if (e.key === 'Enter') doLogin(); });
  on('l-user', 'keydown', function (e) { if (e.key === 'Enter') doLogin(); });

  // ── Sidebar navigation ───────────────────────
  document.querySelectorAll('.nav-item[data-page]').forEach(function (item) {
    item.addEventListener('click', function () { navigateTo(this.dataset.page); });
  });

  // ── Topbar refresh ───────────────────────────
  on('btn-refresh', 'click', function () { navigateTo(curPage); });

  // ── Logout ───────────────────────────────────
  on('btn-logout', 'click', logout);

  // ── Elections page buttons ───────────────────
  on('btn-new-election', 'click', openCreateElection);
  on('btn-export-csv',   'click', exportAllCSV);
  on('btn-use-template', 'click', openTemplateModal);

  // ── Elections page: search + filter ─────────
  on('el-search',        'input',  debounce(function () { loadElections(1); }, 350));
  on('el-filter-status', 'change', function () { loadElections(1); });

  // ── Votes page: election select ──────────────
  on('v-election', 'change', function () { loadVotes(1); });

  // ── Users page: search + filter ─────────────
  on('u-search',        'input',  debounce(function () { loadUsers(1); }, 350));
  on('u-filter-status', 'change', function () { loadUsers(1); });

  // ── Eligible voters CSV upload ───────────────
  on('el-voters-file', 'change', handleVotersFile);

  // ── Modal: close buttons (data-close attr) ───
  document.querySelectorAll('[data-close]').forEach(function (btn) {
    btn.addEventListener('click', function () { closeModal(this.dataset.close); });
  });

  // ── Modal: click outside to close ───────────
  document.querySelectorAll('.modal-overlay').forEach(function (overlay) {
    overlay.addEventListener('click', function (e) {
      if (e.target === overlay) closeModal(overlay.id);
    });
  });

  // ── Election modal: add candidate + save ─────
  on('btn-add-candidate',  'click', function () { addCandidateRow('', ''); });
  on('btn-save-election',  'click', saveElection);

  // ── Election table: action buttons (delegation) ──
  on('el-tbody', 'click', function (e) {
    var btn = e.target.closest('[data-action]');
    if (!btn) return;
    var action = btn.dataset.action;
    var id     = btn.dataset.id;
    if (action === 'edit')     editElection(id);
    if (action === 'cancel')   cancelElection(id);
    if (action === 'activate') activateElection(id);
    if (action === 'results')  openResultsModal(id);
    if (action === 'delete')   deleteElection(id);
  });

  // ── Users table: action buttons (delegation) ─
  on('u-tbody', 'click', function (e) {
    var btn = e.target.closest('[data-action]');
    if (!btn) return;
    var action = btn.dataset.action;
    var id     = btn.dataset.id;
    if (action === 'verify') verifyUser(id);
    if (action === 'ban')    banUser(id);
    if (action === 'unban')  unbanUser(id);
  });

  // ── Candidates list: remove button (delegation) ─
  on('candidates-list', 'click', function (e) {
    var btn = e.target.closest('.btn-remove-cand');
    if (btn) btn.closest('.candidate-row').remove();
  });

  // ── Escape key closes open modal ─────────────
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') {
      document.querySelectorAll('.modal-overlay.open').forEach(function (m) {
        closeModal(m.id);
      });
    }
  });

  // ── Restore session ──────────────────────────
  try {
    var t = localStorage.getItem('ov_token');
    var a = localStorage.getItem('ov_admin');
    if (t && a) {
      token = t;
      admin = JSON.parse(a);
      showApp();
    }
  } catch (_) {
    clearSession();
  }
});

// ═══════════════════════════════════════════════
// AUTH
// ═══════════════════════════════════════════════
async function doLogin() {
  const user  = document.getElementById('l-user').value.trim();
  const pass  = document.getElementById('l-pass').value;
  const errEl = document.getElementById('l-err');
  const btn   = document.getElementById('l-btn');

  errEl.style.display = 'none';

  if (!user || !pass) {
    showLoginError('Please enter your username and password.');
    return;
  }

  btn.disabled    = true;
  btn.textContent = 'Signing in…';

  try {
    const res  = await fetch(API + '/login', {
      method:  'POST',
      headers: { 'Content-Type': 'application/json' },
      body:    JSON.stringify({ username: user, password: pass })
    });
    const data = await res.json().catch(function () { return {}; });

    if (!data.success) {
      showLoginError(data.message || 'Invalid username or password.');
      return;
    }

    token = data.data.token;
    admin = data.data.admin;

    try {
      localStorage.setItem('ov_token', token);
      localStorage.setItem('ov_admin', JSON.stringify(admin));
    } catch (_) { /* storage unavailable – session-only */ }

    showApp();

  } catch (err) {
    showLoginError('Cannot connect to server. Is the backend running on port 3000?');
  } finally {
    btn.disabled    = false;
    btn.textContent = 'Sign In';
  }
}

function showLoginError(msg) {
  const el = document.getElementById('l-err');
  el.textContent    = msg;
  el.style.display  = 'block';
}

function showApp() {
  document.getElementById('login-screen').style.display = 'none';
  document.getElementById('app').style.display          = 'block';

  if (admin) {
    const initial = (admin.username || 'A')[0].toUpperCase();
    document.getElementById('s-avatar').textContent = initial;
    document.getElementById('s-name').textContent   = admin.username || 'Admin';
    document.getElementById('s-role').textContent   = (admin.role || 'admin').replace(/_/g, ' ');
  }

  navigateTo('dashboard');
  populateVoteElectionDropdown();
}

function logout() {
  clearSession();
  document.getElementById('app').style.display          = 'none';
  document.getElementById('login-screen').style.display = 'flex';
  document.getElementById('l-pass').value               = '';
  document.getElementById('l-err').style.display        = 'none';
}

function clearSession() {
  token = null;
  admin = null;
  try {
    localStorage.removeItem('ov_token');
    localStorage.removeItem('ov_admin');
  } catch (_) {}
}

// ═══════════════════════════════════════════════
// NAVIGATION
// ═══════════════════════════════════════════════
var PAGE_META = {
  dashboard: ['Dashboard',  'Overview of platform activity'],
  elections: ['Elections',  'Create and manage elections'],
  votes:     ['Votes',      'Blockchain vote records'],
  users:     ['Users',      'Registered voter accounts']
};

function navigateTo(page) {
  curPage = page;

  // Update sidebar active state
  document.querySelectorAll('.nav-item[data-page]').forEach(function (item) {
    item.classList.toggle('active', item.dataset.page === page);
  });

  // Show correct page
  document.querySelectorAll('.page').forEach(function (p) {
    p.classList.toggle('active', p.id === 'page-' + page);
  });

  // Update topbar
  var meta = PAGE_META[page] || [page, ''];
  document.getElementById('tb-title').textContent = meta[0];
  document.getElementById('tb-sub').textContent   = meta[1];

  // Load data
  if (page === 'dashboard') loadDashboard();
  if (page === 'elections') loadElections(1);
  if (page === 'users')     loadUsers(1);
  // votes page waits for election dropdown selection
}

// ═══════════════════════════════════════════════
// API HELPER
// ═══════════════════════════════════════════════
async function apiCall(path, method, body) {
  method = method || 'GET';
  try {
    var opts = {
      method:  method,
      headers: {
        'Content-Type':  'application/json',
        'Authorization': 'Bearer ' + token
      }
    };
    if (body) opts.body = JSON.stringify(body);

    var res = await fetch(API + path, opts);

    if (res.status === 401) {
      toast('error', 'Session expired — please sign in again.');
      logout();
      return null;
    }

    var data = await res.json().catch(function () { return { success: false, message: 'Invalid server response' }; });
    return data;

  } catch (err) {
    toast('error', 'Network error: ' + err.message);
    return null;
  }
}

// ═══════════════════════════════════════════════
// DASHBOARD
// ═══════════════════════════════════════════════
async function loadDashboard() {
  var data = await apiCall('/dashboard');
  if (!data || !data.success) {
    toast('error', 'Failed to load dashboard data.');
    return;
  }

  var s = data.data.stats;

  setText('d-users',         numFmt(s.users.total));
  setText('d-users-sub',     '+' + s.users.new7d + ' this week');
  setText('d-elections',     numFmt(s.elections.total));
  setText('d-elections-sub', s.elections.active + ' active');
  setText('d-votes',         numFmt(s.votes.total));
  setText('d-votes-sub',     '+' + numFmt(s.votes.recent7d) + ' this week');
  setText('d-active',        s.elections.active);
  setText('d-active-sub',    s.elections.pending + ' pending');

  // Chart
  destroyChart('chart-votes');
  var days = (data.data.charts && data.data.charts.votesByDay) || [];
  var ctx  = document.getElementById('chart-votes').getContext('2d');
  charts['chart-votes'] = new Chart(ctx, {
    type: 'line',
    data: {
      labels: days.map(function (d) { return d._id; }),
      datasets: [{
        label: 'Votes',
        data:  days.map(function (d) { return d.count; }),
        borderColor: '#6c63ff',
        backgroundColor: 'rgba(108,99,255,.12)',
        borderWidth: 2.5,
        pointRadius: 4,
        pointBackgroundColor: '#6c63ff',
        tension: 0.4,
        fill: true
      }]
    },
    options: chartOptions()
  });

  // Top elections
  var top   = ((data.data.charts && data.data.charts.topElections) || []).slice(0, 5);
  var maxV  = Math.max.apply(null, top.map(function (e) { return e.totalVotes || 0; }).concat([1]));
  var topEl = document.getElementById('top-elections');

  if (!top.length) {
    topEl.innerHTML = '<div class="empty-state"><i class="fas fa-inbox"></i>No elections yet</div>';
    return;
  }

  topEl.innerHTML = top.map(function (e) {
    var pct = ((e.totalVotes || 0) / maxV * 100).toFixed(1);
    return '<div style="margin-bottom:14px">' +
      '<div style="display:flex;justify-content:space-between;font-size:12px;margin-bottom:5px">' +
        '<span style="font-weight:600;color:var(--text)">' + esc(e.title) + '</span>' +
        '<span style="color:var(--text2)">' + numFmt(e.totalVotes || 0) + '</span>' +
      '</div>' +
      '<div style="height:7px;background:var(--bg3);border-radius:99px;overflow:hidden">' +
        '<div style="height:100%;width:' + pct + '%;background:linear-gradient(90deg,var(--primary),#8b85ff);border-radius:99px;transition:.6s"></div>' +
      '</div></div>';
  }).join('');
}

// ═══════════════════════════════════════════════
// ELECTIONS
// ═══════════════════════════════════════════════
async function loadElections(page) {
  page   = page || 1;
  elPage = page;

  var tbody = document.getElementById('el-tbody');
  tbody.innerHTML = '<tr><td colspan="6"><div class="loading-state"><div class="spinner"></div>Loading…</div></td></tr>';

  var search = document.getElementById('el-search').value.trim();
  var status = document.getElementById('el-filter-status').value;

  var params = new URLSearchParams({ page: page, limit: 15 });
  if (search) params.set('search', search);
  if (status) params.set('status', status);

  var data = await apiCall('/elections?' + params.toString());

  if (!data || !data.success) {
    tbody.innerHTML = '<tr><td colspan="6"><div class="empty-state"><i class="fas fa-exclamation-triangle"></i>Failed to load elections.</div></td></tr>';
    return;
  }

  allElections = data.data.elections || [];

  if (!allElections.length) {
    tbody.innerHTML = '<tr><td colspan="6"><div class="empty-state"><i class="fas fa-vote-yea"></i>No elections found. Click <strong>New Election</strong> to create one.</div></td></tr>';
    renderPagination('el-pagination', data.data.pagination, 'loadElections');
    return;
  }

  tbody.innerHTML = allElections.map(function (e) {
    var hasVotes = (e.totalVotes || 0) > 0;
    var canCancel = (e.status !== 'cancelled' && e.status !== 'closed');
    var canActivate = e.status === 'cancelled';
    // Lock delete only for active/pending with votes — cancelled/closed can always be deleted
    var isLocked = hasVotes && (e.status === 'active' || e.status === 'pending');
    var deleteBtn = isLocked
      ? '<button class="btn btn-outline btn-sm btn-icon" title="Locked — ' + numFmt(e.totalVotes) + ' vote(s) cast" disabled style="opacity:0.4;cursor:not-allowed"><i class="fas fa-lock"></i></button>'
      : '<button class="btn btn-danger btn-sm btn-icon" title="Delete" data-action="delete" data-id="' + e._id + '"><i class="fas fa-trash"></i></button>';
    var actions =
      '<button class="btn btn-outline btn-sm btn-icon" title="Edit" data-action="edit" data-id="' + e._id + '"><i class="fas fa-pen"></i></button> ' +
      (canActivate ? '<button class="btn btn-success btn-sm btn-icon" title="Reactivate (votes preserved)" data-action="activate" data-id="' + e._id + '"><i class="fas fa-play"></i></button> ' : '') +
      (canCancel ? '<button class="btn btn-danger btn-sm btn-icon" title="Cancel / Pause" data-action="cancel" data-id="' + e._id + '"><i class="fas fa-pause"></i></button> ' : '') +
      deleteBtn;
    return '<tr>' +
      '<td>' +
        '<div style="font-weight:600;font-size:13px">' + esc(e.title) + '</div>' +
        '<div style="font-size:11px;color:var(--text3)">' + esc(e.organizationName) + '</div>' +
      '</td>' +
      '<td><span class="badge badge-blue">' + (e.type || '—') + '</span></td>' +
      '<td>' + statusBadge(e.status) + '</td>' +
      '<td style="font-family:monospace">' + numFmt(e.totalVotes || 0) + '</td>' +
      '<td style="font-size:12px">' + fmtDate(e.endDate) + '</td>' +
      '<td><button class="btn btn-outline btn-sm btn-icon" title="View Results" data-action="results" data-id="' + e._id + '"><i class="fas fa-chart-bar"></i></button></td>' +
      '<td><div style="display:flex;gap:6px;align-items:center">' + actions + '</div></td>' +
    '</tr>';
  }).join('');

  renderPagination('el-pagination', data.data.pagination, 'loadElections');
}

async function populateVoteElectionDropdown() {
  var sel  = document.getElementById('v-election');
  var data = await apiCall('/elections?limit=100');
  if (!data || !data.success) return;

  // Remove all but placeholder
  while (sel.options.length > 1) sel.remove(1);

  (data.data.elections || []).forEach(function (e) {
    var opt        = document.createElement('option');
    opt.value      = e._id;
    opt.textContent = e.title + ' (' + e.status + ')';
    sel.appendChild(opt);
  });
}

function openCreateElection() {
  document.getElementById('modal-election-title').textContent = 'Create New Election';
  document.getElementById('el-id').value    = '';
  document.getElementById('el-title').value = '';
  document.getElementById('el-org').value   = '';
  document.getElementById('el-desc').value  = '';
  document.getElementById('el-type').value  = 'general';
  document.getElementById('el-status').value = 'pending';
  document.getElementById('el-turnout-target').value = '';
  window._eligibleVoters = [];
  document.getElementById('el-voters-hint').textContent = 'One Voter ID per line, or comma-separated. Leave empty = all users eligible.';
  document.getElementById('el-voters-hint').style.color = '';

  var now = new Date();
  var end = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
  document.getElementById('el-start').value = toDatetimeLocal(now);
  document.getElementById('el-end').value   = toDatetimeLocal(end);

  document.getElementById('candidates-list').innerHTML = '';
  addCandidateRow('', '');
  addCandidateRow('', '');

  openModal('modal-election');
}

function editElection(id) {
  var e = allElections.find(function (x) { return x._id === id; });
  if (!e) {
    toast('error', 'Election not found. Please refresh the list.');
    return;
  }

  document.getElementById('modal-election-title').textContent  = 'Edit Election';
  document.getElementById('el-id').value     = e._id;
  document.getElementById('el-title').value  = e.title || '';
  document.getElementById('el-org').value    = e.organizationName || '';
  document.getElementById('el-desc').value   = e.description || '';
  document.getElementById('el-type').value   = e.type || 'general';
  document.getElementById('el-status').value = e.status || 'pending';
  document.getElementById('el-turnout-target').value = e.turnoutTarget || '';
  window._eligibleVoters = e.eligibleVoters || [];
  var hint = document.getElementById('el-voters-hint');
  if (window._eligibleVoters.length) {
    hint.textContent = window._eligibleVoters.length + ' voter IDs loaded.';
    hint.style.color = 'var(--green)';
  } else {
    hint.textContent = 'One Voter ID per line, or comma-separated. Leave empty = all users eligible.';
    hint.style.color = '';
  }
  document.getElementById('el-start').value  = toDatetimeLocal(new Date(e.startDate));
  document.getElementById('el-end').value    = toDatetimeLocal(new Date(e.endDate));

  var list = document.getElementById('candidates-list');
  list.innerHTML = '';
  (e.candidates || []).forEach(function (c) {
    addCandidateRow(c.name || '', c.party || '', c.imageUrl || '');
  });
  if ((e.candidates || []).length < 2) addCandidateRow('', '');

  openModal('modal-election');
}

function addCandidateRow(name, party, imageUrl) {
  var row        = document.createElement('div');
  row.className  = 'candidate-row';
  var previewSrc = imageUrl || '';
  row.innerHTML  =
    '<input type="text" class="cand-name"  placeholder="Candidate name *"          value="' + esc(name     || '') + '">' +
    '<input type="text" class="cand-party" placeholder="Party / symbol (optional)" value="' + esc(party    || '') + '">' +
    '<div style="display:flex;align-items:center;gap:6px">' +
      '<input type="url" class="cand-img" placeholder="Logo image URL (optional)" value="' + esc(imageUrl || '') + '" style="flex:1;min-width:0">' +
      '<img class="logo-preview" src="' + esc(previewSrc) + '" alt="" ' +
        'style="width:30px;height:30px;border-radius:6px;object-fit:cover;border:1px solid var(--border);flex-shrink:0;' +
        (previewSrc ? '' : 'display:none;') + '">' +
    '</div>' +
    '<button type="button" class="btn-remove-cand" title="Remove"><i class="fas fa-times"></i></button>';

  // live preview on URL change
  var imgInput = row.querySelector('.cand-img');
  var imgEl    = row.querySelector('.logo-preview');
  var warnEl = document.createElement('div');
  warnEl.className = 'url-warn';
  warnEl.style.cssText = 'display:none;font-size:10px;color:var(--yellow);margin-top:3px;grid-column:1/-1';
  warnEl.innerHTML = '⚠ Not a direct image URL. Right-click an image → "Copy image address" to get a direct URL.';
  row.appendChild(warnEl);

  imgInput.addEventListener('input', function () {
    var url = this.value.trim();
    var isBadUrl = url && (
      url.includes('google.com/url') ||
      url.includes('google.com/search') ||
      url.includes('bing.com/') ||
      url.includes('duckduckgo.com/') ||
      url.includes('/imgres?') ||
      (!url.match(/\.(png|jpg|jpeg|gif|webp|svg)(\?|$)/i) && url.length > 10)
    );
    warnEl.style.display = isBadUrl ? 'block' : 'none';
    if (url && !isBadUrl) {
      imgEl.src = url;
      imgEl.style.display = 'block';
    } else {
      imgEl.style.display = 'none';
    }
  });
  imgEl.addEventListener('error', function () {
    this.style.display = 'none';
    warnEl.style.display = 'block';
    warnEl.innerHTML = '⚠ Image failed to load. Check the URL is a direct image link (ends in .png, .jpg, etc.)';
  });

  document.getElementById('candidates-list').appendChild(row);
}

async function saveElection() {
  var btn = document.getElementById('btn-save-election');

  // Read fields
  var id    = document.getElementById('el-id').value.trim();
  var title = document.getElementById('el-title').value.trim();
  var org   = document.getElementById('el-org').value.trim();
  var desc  = document.getElementById('el-desc').value.trim();
  var start = document.getElementById('el-start').value;
  var end   = document.getElementById('el-end').value;
  var type  = document.getElementById('el-type').value;
  var stat  = document.getElementById('el-status').value;

  // Validation
  if (!title) { toast('error', 'Election title is required.'); return; }
  if (!org)   { toast('error', 'Organisation name is required.'); return; }
  if (!desc)  { toast('error', 'Description is required.'); return; }
  if (!start) { toast('error', 'Start date is required.'); return; }
  if (!end)   { toast('error', 'End date is required.'); return; }
  if (new Date(end) <= new Date(start)) {
    toast('error', 'End date must be after start date.');
    return;
  }

  // Read turnout target
  var turnoutTarget = parseInt(document.getElementById('el-turnout-target').value.trim()) || null;

  // Read eligible voters (loaded from CSV or manual)
  var eligibleVoters = window._eligibleVoters || [];

  var rows       = document.querySelectorAll('#candidates-list .candidate-row');
  var candidates = [];
  rows.forEach(function (row) {
    var name     = row.querySelector('.cand-name').value.trim();
    var party    = row.querySelector('.cand-party').value.trim();
    var imageUrl = row.querySelector('.cand-img').value.trim();
    if (name) candidates.push({ name: name, party: party || undefined, imageUrl: imageUrl || undefined });
  });

  if (candidates.length < 2) {
    toast('error', 'At least 2 candidates are required.');
    return;
  }

  btn.disabled   = true;
  btn.innerHTML  = '<i class="fas fa-spinner fa-spin"></i> Saving…';

  var payload = {
    title:            title,
    organizationName: org,
    description:      desc,
    type:             type,
    status:           stat,
    turnoutTarget:    turnoutTarget,
    eligibleVoters:   eligibleVoters.length ? eligibleVoters : undefined,
    startDate:        new Date(start).toISOString(),
    endDate:          new Date(end).toISOString(),
    candidates:       candidates,
    settings: { requireBiometric: false, allowVoteChange: false, isPublic: true }
  };

  var data = id
    ? await apiCall('/elections/' + id, 'PUT',  payload)
    : await apiCall('/elections',        'POST', payload);

  if (data && data.success) {
    toast('success', id ? 'Election updated successfully!' : 'Election created successfully!');
    closeModal('modal-election');
    loadElections(elPage);
    populateVoteElectionDropdown();
  } else {
    var msg = 'Save failed.';
    if (data && data.errors && data.errors.length) {
      msg = data.errors.map(function (e) { return e.msg; }).join(', ');
    } else if (data && data.message) {
      msg = data.message;
    }
    toast('error', msg);
  }

  btn.disabled  = false;
  btn.innerHTML = '<i class="fas fa-save"></i> Save Election';
}

async function activateElection(id) {
  if (!confirm('Reactivate this election? All existing votes will be preserved and voting will resume.')) return;
  var data = await apiCall('/elections/' + id + '/activate', 'POST');
  if (data && data.success) {
    toast('success', 'Election reactivated. Votes preserved.');
    loadElections();
    loadDashboard();
  } else {
    toast('error', (data && data.message) || 'Could not reactivate election.');
  }
}

async function cancelElection(id) {
  if (!confirm('Cancel this election? Voters will no longer be able to vote.')) return;
  var data = await apiCall('/elections/' + id + '/cancel', 'POST');
  if (data && data.success) {
    toast('success', 'Election cancelled.');
    loadElections(elPage);
  } else {
    toast('error', (data && data.message) || 'Could not cancel election.');
  }
}

async function deleteElection(id) {
  if (!confirm('Permanently delete this election? This cannot be undone.')) return;
  var data = await apiCall('/elections/' + id, 'DELETE');
  if (data && data.success) {
    toast('success', 'Election deleted.');
    loadElections(elPage);
  } else {
    toast('error', (data && data.message) || 'Could not delete election. (Active elections cannot be deleted — cancel first.)');
  }
}

// ═══════════════════════════════════════════════
// VOTES
// ═══════════════════════════════════════════════
async function loadVotes(page) {
  page   = page || 1;
  vPage  = page;

  var tbody = document.getElementById('v-tbody');
  var elId  = document.getElementById('v-election').value;

  if (!elId) {
    tbody.innerHTML = '<tr><td colspan="4"><div class="empty-state"><i class="fas fa-filter"></i>Select an election above</div></td></tr>';
    document.getElementById('v-pagination').innerHTML = '';
    return;
  }

  tbody.innerHTML = '<tr><td colspan="4"><div class="loading-state"><div class="spinner"></div>Loading…</div></td></tr>';

  var data = await apiCall('/elections/' + elId + '/votes?page=' + page + '&limit=20');

  if (!data || !data.success) {
    tbody.innerHTML = '<tr><td colspan="4"><div class="empty-state"><i class="fas fa-exclamation"></i>Failed to load votes.</div></td></tr>';
    return;
  }

  var votes = data.data.votes || [];

  if (!votes.length) {
    tbody.innerHTML = '<tr><td colspan="4"><div class="empty-state"><i class="fas fa-check-to-slot"></i>No votes cast in this election yet.</div></td></tr>';
    return;
  }

  tbody.innerHTML = votes.map(function (v) {
    var hash = (v.transactionHash || '');
    var short = hash.length > 30 ? hash.substring(0, 30) + '…' : hash;
    return '<tr>' +
      '<td style="font-family:monospace;font-size:11px">' + esc(short) + '</td>' +
      '<td>' + statusBadge(v.status || 'confirmed') + '</td>' +
      '<td><span class="badge badge-green">' + esc(v.network || 'Solana') + '</span></td>' +
      '<td style="font-size:12px">' + fmtDate(v.timestamp) + '</td>' +
    '</tr>';
  }).join('');

  renderPagination('v-pagination', data.data.pagination, 'loadVotes');
}

// ═══════════════════════════════════════════════
// USERS
// ═══════════════════════════════════════════════
async function loadUsers(page) {
  page   = page || 1;
  uPage  = page;

  var tbody = document.getElementById('u-tbody');
  tbody.innerHTML = '<tr><td colspan="6"><div class="loading-state"><div class="spinner"></div>Loading…</div></td></tr>';

  var search = document.getElementById('u-search').value.trim();
  var status = document.getElementById('u-filter-status').value;

  var params = new URLSearchParams({ page: page, limit: 15 });
  if (search) params.set('search', search);
  if (status === 'active') params.set('status', 'active');
  if (status === 'banned') params.set('status', 'banned');

  var data = await apiCall('/users?' + params.toString());

  if (!data || !data.success) {
    tbody.innerHTML = '<tr><td colspan="6"><div class="empty-state"><i class="fas fa-exclamation"></i>Failed to load users.</div></td></tr>';
    return;
  }

  var users = data.data.users || [];

  if (!users.length) {
    tbody.innerHTML = '<tr><td colspan="6"><div class="empty-state"><i class="fas fa-users"></i>No users found.</div></td></tr>';
    return;
  }

  tbody.innerHTML = users.map(function (u) {
    var initial = (u.name || u.voterIdNumber || 'U')[0].toUpperCase();
    var statusBadgeHtml = u.isBanned
      ? '<span class="badge badge-red"><span class="dot"></span>Banned</span>'
      : u.isActive
        ? '<span class="badge badge-green"><span class="dot"></span>Active</span>'
        : '<span class="badge badge-grey">Inactive</span>';

    var verifyBtn = !u.isVerified
      ? '<button class="btn btn-success btn-sm btn-icon" title="Verify user" data-action="verify" data-id="' + u._id + '"><i class="fas fa-check"></i></button>'
      : '';
    var banBtn = u.isBanned
      ? '<button class="btn btn-outline btn-sm btn-icon" title="Unban user" data-action="unban" data-id="' + u._id + '"><i class="fas fa-unlock"></i></button>'
      : '<button class="btn btn-danger btn-sm btn-icon" title="Ban user" data-action="ban" data-id="' + u._id + '"><i class="fas fa-ban"></i></button>';

    return '<tr>' +
      '<td>' +
        '<div style="display:flex;align-items:center;gap:9px">' +
          '<div style="width:30px;height:30px;border-radius:8px;background:linear-gradient(135deg,var(--primary),#8b85ff);display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:700;flex-shrink:0">' + initial + '</div>' +
          '<div>' +
            '<div style="font-weight:600;font-size:13px">' + esc(u.name || 'Unknown') + '</div>' +
            '<div style="font-size:11px;color:var(--text3)">' + esc(u.email || '') + '</div>' +
          '</div>' +
        '</div>' +
      '</td>' +
      '<td style="font-family:monospace;font-size:12px">' + esc(u.voterIdNumber || '—') + '</td>' +
      '<td>' + statusBadgeHtml + '</td>' +
      '<td>' + (u.isVerified
        ? '<span class="badge badge-green"><i class="fas fa-check" style="font-size:10px"></i> Yes</span>'
        : '<span class="badge badge-yellow">No</span>') + '</td>' +
      '<td style="font-size:12px">' + fmtDate(u.createdAt) + '</td>' +
      '<td><div style="display:flex;gap:6px;align-items:center">' + verifyBtn + banBtn + '</div></td>' +
    '</tr>';
  }).join('');

  renderPagination('u-pagination', data.data.pagination, 'loadUsers');
}

async function verifyUser(id) {
  var data = await apiCall('/users/' + id + '/verify', 'POST');
  if (data && data.success) { toast('success', 'User verified.'); loadUsers(uPage); }
  else toast('error', (data && data.message) || 'Failed to verify user.');
}

async function banUser(id) {
  var reason = prompt('Ban reason (optional):');
  if (reason === null) return; // user cancelled
  var data = await apiCall('/users/' + id + '/ban', 'POST', { reason: reason || 'Banned by admin' });
  if (data && data.success) { toast('success', 'User banned.'); loadUsers(uPage); }
  else toast('error', (data && data.message) || 'Failed to ban user.');
}

async function unbanUser(id) {
  var data = await apiCall('/users/' + id + '/unban', 'POST');
  if (data && data.success) { toast('success', 'User unbanned.'); loadUsers(uPage); }
  else toast('error', (data && data.message) || 'Failed to unban user.');
}

// ═══════════════════════════════════════════════
// MODAL HELPERS
// ═══════════════════════════════════════════════
function openModal(id) {
  var el = document.getElementById(id);
  if (el) el.classList.add('open');
}

function closeModal(id) {
  var el = document.getElementById(id);
  if (el) el.classList.remove('open');
}

// ═══════════════════════════════════════════════
// PAGINATION
// ═══════════════════════════════════════════════
function renderPagination(containerId, pagination, callbackName) {
  var el = document.getElementById(containerId);
  if (!el || !pagination) return;

  var page  = pagination.page  || 1;
  var pages = pagination.pages || 1;
  var total = pagination.total || 0;

  if (pages <= 1) { el.innerHTML = ''; return; }

  var html = '<span class="page-info">' + total + ' total</span>';
  html += '<button class="page-btn" ' + (page === 1 ? 'disabled' : '') + ' onclick="' + callbackName + '(' + (page - 1) + ')">‹</button>';

  var start = Math.max(1, page - 2);
  var end   = Math.min(pages, page + 2);
  for (var i = start; i <= end; i++) {
    html += '<button class="page-btn ' + (i === page ? 'active' : '') + '" onclick="' + callbackName + '(' + i + ')">' + i + '</button>';
  }

  html += '<button class="page-btn" ' + (page === pages ? 'disabled' : '') + ' onclick="' + callbackName + '(' + (page + 1) + ')">›</button>';
  el.innerHTML = html;
}

// ═══════════════════════════════════════════════
// TOAST
// ═══════════════════════════════════════════════
function toast(type, msg) {
  var container = document.getElementById('toast-container');
  var el        = document.createElement('div');
  el.className  = 'toast toast-' + type;

  var icon = type === 'success' ? 'circle-check' : type === 'error' ? 'circle-xmark' : 'circle-info';
  el.innerHTML = '<i class="fas fa-' + icon + '"></i> ' + esc(msg);

  container.appendChild(el);

  setTimeout(function () {
    el.style.transition = 'opacity .3s, transform .3s';
    el.style.opacity    = '0';
    el.style.transform  = 'translateX(30px)';
    setTimeout(function () { if (el.parentNode) el.parentNode.removeChild(el); }, 320);
  }, 4000);
}

// ═══════════════════════════════════════════════
// CHART / MISC UTILITIES
// ═══════════════════════════════════════════════
function destroyChart(id) {
  if (charts[id]) {
    charts[id].destroy();
    delete charts[id];
  }
}

function chartOptions() {
  return {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { labels: { color: '#9898b8', font: { size: 11 } } }
    },
    scales: {
      x: { grid: { color: 'rgba(255,255,255,.04)' }, ticks: { color: '#555570', font: { size: 11 } } },
      y: { grid: { color: 'rgba(255,255,255,.04)' }, ticks: { color: '#555570', font: { size: 11 } }, beginAtZero: true }
    }
  };
}

function setText(id, val) {
  var el = document.getElementById(id);
  if (el) el.textContent = val;
}

function esc(s) {
  if (s == null) return '';
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function numFmt(n) {
  if (n == null) return '0';
  n = Number(n);
  if (n >= 1e6) return (n / 1e6).toFixed(1) + 'M';
  if (n >= 1e3) return (n / 1e3).toFixed(1) + 'K';
  return n.toLocaleString();
}

function fmtDate(d) {
  if (!d) return '—';
  return new Date(d).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
}

function toDatetimeLocal(d) {
  var pad = function (n) { return String(n).padStart(2, '0'); };
  return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) +
    'T' + pad(d.getHours()) + ':' + pad(d.getMinutes());
}

function statusBadge(status) {
  var map = {
    active:    'badge-green',
    confirmed: 'badge-green',
    verified:  'badge-green',
    pending:   'badge-yellow',
    closed:    'badge-grey',
    cancelled: 'badge-red',
    failed:    'badge-red'
  };
  var cls = map[status] || 'badge-grey';
  return '<span class="badge ' + cls + '"><span class="dot"></span>' + (status || '—') + '</span>';
}

// ═══════════════════════════════════════════════
// RESULTS MODAL
// ═══════════════════════════════════════════════
var _currentResultsElection = null;

async function openResultsModal(id) {
  _currentResultsElection = null;
  document.getElementById('results-modal-title').textContent = 'Election Results';
  document.getElementById('results-modal-body').innerHTML =
    '<div class="loading-state"><div class="spinner"></div>Loading results…</div>';
  document.getElementById('results-public-url').value = '';

  // Set public URL
  var publicUrl = window.location.origin + '/results/' + id;
  document.getElementById('results-public-url').value = publicUrl;

  openModal('modal-results');

  // Fetch results from public endpoint (no auth needed)
  var res = await fetch('/api/elections/' + id + '/results');
  var data = res.ok ? await res.json().catch(function(){return null;}) : null;

  if (!data || !data.success) {
    document.getElementById('results-modal-body').innerHTML =
      '<div class="empty-state"><i class="fas fa-exclamation"></i>No results available yet.</div>';
    return;
  }

  _currentResultsElection = data.data;
  var d = data.data;
  var total = d.totalVotes || 0;

  // Build results title
  document.getElementById('results-modal-title').textContent = d.title || 'Election Results';

  // Build results HTML
  var html = '';

  // Stats row
  html += '<div style="display:flex;gap:12px;margin-bottom:20px">';
  html += '<div style="flex:1;background:var(--bg3);border:1px solid var(--border);border-radius:10px;padding:12px;text-align:center">';
  html += '<div style="font-size:22px;font-weight:800;color:var(--primary)">' + numFmt(total) + '</div>';
  html += '<div style="font-size:11px;color:var(--text2)">Total Votes</div></div>';
  html += '<div style="flex:1;background:var(--bg3);border:1px solid var(--border);border-radius:10px;padding:12px;text-align:center">';
  html += '<div style="font-size:22px;font-weight:800;color:var(--text)">' + (d.results ? d.results.length : 0) + '</div>';
  html += '<div style="font-size:11px;color:var(--text2)">Candidates</div></div>';
  html += '<div style="flex:1;background:var(--bg3);border:1px solid var(--border);border-radius:10px;padding:12px;text-align:center">';
  html += '<div style="font-size:13px;font-weight:700">' + statusBadge(d.status) + '</div>';
  html += '<div style="font-size:11px;color:var(--text2);margin-top:4px">Status</div></div>';
  html += '</div>';

  // Candidate bars
  if (d.results && d.results.length) {
    var palette = ['#6C63FF','#E74C3C','#2ECC71','#3498DB','#E67E22','#9B59B6','#1ABC9C','#F39C12'];
    html += '<div style="display:flex;flex-direction:column;gap:12px">';
    d.results.forEach(function(r, i) {
      var pct = total > 0 ? (r.voteCount / total * 100).toFixed(1) : '0.0';
      var color = palette[i % palette.length];
      var isFirst = i === 0 && r.voteCount > 0;
      html += '<div>';
      html += '<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:5px">';
      html += '<div style="display:flex;align-items:center;gap:8px">';
      html += '<div style="width:10px;height:10px;border-radius:50%;background:' + color + ';flex-shrink:0"></div>';
      html += '<span style="font-size:13px;font-weight:' + (isFirst ? '700' : '500') + ';color:var(--text)">' + esc(r.name) + '</span>';
      if (r.party) html += '<span style="font-size:11px;color:var(--text2)">· ' + esc(r.party) + '</span>';
      if (isFirst && d.status === 'closed') html += '<span class="badge badge-green" style="font-size:9px;padding:2px 7px">WINNER</span>';
      html += '</div>';
      html += '<span style="font-size:12px;font-weight:700;color:' + color + '">' + r.voteCount + '  ' + pct + '%</span>';
      html += '</div>';
      html += '<div style="height:8px;background:var(--border);border-radius:4px;overflow:hidden">';
      html += '<div style="height:100%;width:' + pct + '%;background:' + color + ';border-radius:4px;transition:width .6s"></div>';
      html += '</div>';
      html += '</div>';
    });
    html += '</div>';
  } else {
    html += '<div class="empty-state"><i class="fas fa-chart-bar"></i>No votes cast yet.</div>';
  }

  document.getElementById('results-modal-body').innerHTML = html;

  // Inject turnout bar if turnoutTarget exists
  if (d.turnoutTarget && d.turnoutTarget > 0) {
    var statsEl = document.getElementById('results-modal-body');
    statsEl.innerHTML = buildTurnoutBar(d.totalVotes || 0, d.turnoutTarget) + statsEl.innerHTML;
  }

  // Wire export buttons
  document.getElementById('btn-results-csv').onclick = function() { exportResultsCSV(_currentResultsElection); };
  document.getElementById('btn-results-pdf').onclick = function() { exportResultsPDF(_currentResultsElection); };
}

function copyResultsUrl() {
  var input = document.getElementById('results-public-url');
  input.select();
  document.execCommand('copy');
  toast('success', 'Public URL copied to clipboard!');
}

// ═══════════════════════════════════════════════
// EXPORT — All Elections CSV
// ═══════════════════════════════════════════════
async function exportAllCSV() {
  var data = await apiCall('/elections?limit=200');
  if (!data || !data.success) { toast('error', 'Failed to fetch elections.'); return; }
  var elections = data.data.elections || [];
  var rows = [['Title','Organisation','Type','Status','Total Votes','Start Date','End Date']];
  elections.forEach(function(e) {
    rows.push([
      e.title, e.organizationName, e.type, e.status,
      e.totalVotes || 0,
      fmtDate(e.startDate), fmtDate(e.endDate)
    ]);
  });
  downloadCSV('omnivote_elections_' + datestamp() + '.csv', rows);
  toast('success', 'Elections CSV downloaded.');
}

// ═══════════════════════════════════════════════
// EXPORT — Single Election Results CSV
// ═══════════════════════════════════════════════
function exportResultsCSV(d) {
  if (!d) { toast('error', 'No results to export.'); return; }
  var rows = [['Election', d.title || '']];
  rows.push(['Status', d.status || '']);
  rows.push(['Total Votes', d.totalVotes || 0]);
  rows.push([]);
  rows.push(['Rank','Candidate','Party','Votes','Percentage']);
  (d.results || []).forEach(function(r, i) {
    rows.push([i + 1, r.name, r.party || '', r.voteCount, r.percentage + '%']);
  });
  downloadCSV('results_' + slugify(d.title) + '_' + datestamp() + '.csv', rows);
  toast('success', 'Results CSV downloaded.');
}

// ═══════════════════════════════════════════════
// EXPORT — Single Election Results PDF (print dialog)
// ═══════════════════════════════════════════════
function exportResultsPDF(d) {
  if (!d) { toast('error', 'No results to export.'); return; }
  var palette = ['#6C63FF','#E74C3C','#2ECC71','#3498DB','#E67E22','#9B59B6','#1ABC9C','#F39C12'];
  var total = d.totalVotes || 1;
  var rows = (d.results || []).map(function(r, i) {
    var pct = (r.voteCount / total * 100).toFixed(1);
    var color = palette[i % palette.length];
    return '<tr style="border-bottom:1px solid #eee">' +
      '<td style="padding:10px 8px;font-weight:700;color:#333">' + (i+1) + '</td>' +
      '<td style="padding:10px 8px"><b>' + esc(r.name) + '</b>' +
        (r.party ? '<br><span style="font-size:11px;color:#888">' + esc(r.party) + '</span>' : '') + '</td>' +
      '<td style="padding:10px 8px;text-align:right;font-family:monospace">' + r.voteCount + '</td>' +
      '<td style="padding:10px 8px;min-width:140px">' +
        '<div style="background:#eee;border-radius:3px;height:12px;overflow:hidden">' +
          '<div style="height:100%;width:' + pct + '%;background:' + color + '"></div>' +
        '</div>' +
        '<span style="font-size:11px;color:' + color + ';font-weight:700">' + pct + '%</span>' +
      '</td>' +
    '</tr>';
  }).join('');

  var html = '<!DOCTYPE html><html><head><meta charset="utf-8">' +
    '<title>Results — ' + esc(d.title) + '</title>' +
    '<style>body{font-family:Arial,sans-serif;margin:32px;color:#1a1a2e}' +
    'h1{font-size:22px;margin-bottom:4px}' +
    '.meta{color:#666;font-size:13px;margin-bottom:24px}' +
    '.stats{display:flex;gap:16px;margin-bottom:28px}' +
    '.stat{background:#f5f5f5;border-radius:8px;padding:12px 20px;text-align:center}' +
    '.stat-val{font-size:24px;font-weight:800;color:#6C63FF}' +
    '.stat-lbl{font-size:11px;color:#888}' +
    'table{width:100%;border-collapse:collapse}th{background:#6C63FF;color:#fff;padding:10px 8px;text-align:left;font-size:13px}' +
    '.footer{margin-top:32px;font-size:11px;color:#aaa;border-top:1px solid #eee;padding-top:12px}' +
    '@media print{button{display:none}}' +
    '</style></head><body>' +
    '<div style="display:flex;align-items:center;gap:12px;margin-bottom:8px">' +
    '<div style="width:40px;height:40px;background:#6C63FF;border-radius:10px;display:flex;align-items:center;justify-content:center">' +
    '<span style="color:#fff;font-size:20px">🗳️</span></div>' +
    '<div><div style="font-size:11px;color:#6C63FF;font-weight:700;letter-spacing:1px">OMNIVOTE · OFFICIAL RESULTS</div>' +
    '<h1 style="margin:0">' + esc(d.title) + '</h1></div></div>' +
    '<div class="meta">Generated: ' + new Date().toLocaleString('en-IN') + ' · Status: ' + esc(d.status) + '</div>' +
    '<div class="stats">' +
    '<div class="stat"><div class="stat-val">' + numFmt(d.totalVotes) + '</div><div class="stat-lbl">Total Votes</div></div>' +
    '<div class="stat"><div class="stat-val">' + (d.results||[]).length + '</div><div class="stat-lbl">Candidates</div></div>' +
    (d.status === 'closed' && d.results && d.results[0] ? '<div class="stat"><div class="stat-val" style="font-size:14px">' + esc(d.results[0].name) + '</div><div class="stat-lbl">Winner</div></div>' : '') +
    '</div>' +
    '<table><thead><tr><th style="width:40px">#</th><th>Candidate</th><th style="width:80px;text-align:right">Votes</th><th>Share</th></tr></thead>' +
    '<tbody>' + rows + '</tbody></table>' +
    '<div class="footer">OmniVote — Secure, Transparent Democracy · Blockchain-verified results</div>' +
    '<script>window.onload=function(){window.print();}<\/script>' +
    '</body></html>';

  var win = window.open('', '_blank', 'width=800,height=700');
  if (win) { win.document.write(html); win.document.close(); }
  else toast('error', 'Pop-up blocked. Please allow pop-ups for this site.');
}

// ═══════════════════════════════════════════════
// CSV HELPERS
// ═══════════════════════════════════════════════
function downloadCSV(filename, rows) {
  var csv = rows.map(function(row) {
    return row.map(function(cell) {
      var s = String(cell == null ? '' : cell).replace(/"/g, '""');
      return /[,\n\r"]/.test(s) ? '"' + s + '"' : s;
    }).join(',');
  }).join('\r\n');
  var blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' });
  var url  = URL.createObjectURL(blob);
  var a    = document.createElement('a');
  a.href     = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

function datestamp() {
  var d = new Date();
  return d.getFullYear() + pad2(d.getMonth()+1) + pad2(d.getDate());
}

function pad2(n) { return String(n).padStart(2,'0'); }

function slugify(s) {
  return (s || '').toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'').substring(0,30);
}

// ═══════════════════════════════════════════════
// VOTER TURNOUT — show % on results modal
// ═══════════════════════════════════════════════
function buildTurnoutBar(totalVotes, turnoutTarget) {
  if (!turnoutTarget || turnoutTarget <= 0) return '';
  var pct = Math.min(100, (totalVotes / turnoutTarget * 100)).toFixed(1);
  var color = pct >= 75 ? 'var(--green)' : pct >= 40 ? 'var(--yellow)' : 'var(--red)';
  return '<div style="margin-bottom:20px">' +
    '<div style="display:flex;justify-content:space-between;margin-bottom:6px;font-size:13px">' +
      '<span style="color:var(--text2)"><i class="fas fa-users" style="margin-right:5px"></i>Voter Turnout</span>' +
      '<span style="font-weight:700;color:' + color + '">' + pct + '% · ' + numFmt(totalVotes) + ' / ' + numFmt(turnoutTarget) + '</span>' +
    '</div>' +
    '<div style="height:10px;background:var(--border);border-radius:5px;overflow:hidden;position:relative">' +
      '<div style="height:100%;width:' + pct + '%;background:' + color + ';border-radius:5px;transition:width .8s"></div>' +
      // Target line at 60%
      '<div style="position:absolute;top:0;bottom:0;left:60%;width:2px;background:rgba(255,255,255,.3)" title="60% quorum target"></div>' +
    '</div>' +
    '<div style="font-size:10px;color:var(--text3);margin-top:3px;text-align:right">Quorum guide line at 60%</div>' +
  '</div>';
}

// ═══════════════════════════════════════════════
// ELIGIBLE VOTERS CSV UPLOAD
// ═══════════════════════════════════════════════
window._eligibleVoters = [];

function handleVotersFile(e) {
  var file = e.target.files[0];
  if (!file) return;
  var reader = new FileReader();
  reader.onload = function(ev) {
    var text = ev.target.result;
    // Split by newlines and/or commas, trim, filter empty
    var ids = text
      .split(/[\n\r,]+/)
      .map(function(s) { return s.trim(); })
      .filter(function(s) { return s.length > 0; });
    window._eligibleVoters = ids;
    var hint = document.getElementById('el-voters-hint');
    if (ids.length) {
      hint.textContent = '✓ ' + ids.length + ' voter IDs loaded from file.';
      hint.style.color = 'var(--green)';
      document.getElementById('el-voters-label').innerHTML =
        '<i class="fas fa-check" style="color:var(--green)"></i> ' + ids.length + ' IDs loaded';
    } else {
      hint.textContent = 'No valid IDs found in file.';
      hint.style.color = 'var(--red)';
    }
    toast('success', ids.length + ' voter IDs loaded from CSV.');
  };
  reader.readAsText(file);
}

// ═══════════════════════════════════════════════
// ELECTION TEMPLATES
// ═══════════════════════════════════════════════
async function openTemplateModal() {
  openModal('modal-template');
  document.getElementById('template-list').innerHTML =
    '<div class="loading-state"><div class="spinner"></div>Loading elections…</div>';

  var data = await apiCall('/elections?limit=50');
  if (!data || !data.success || !data.data.elections.length) {
    document.getElementById('template-list').innerHTML =
      '<div class="empty-state"><i class="fas fa-copy"></i>No past elections to use as templates.</div>';
    return;
  }

  document.getElementById('template-list').innerHTML = data.data.elections.map(function(e) {
    return '<div style="display:flex;align-items:center;gap:12px;padding:10px 12px;' +
      'background:var(--bg3);border:1px solid var(--border);border-radius:10px;cursor:pointer;' +
      'transition:border-color .15s" ' +
      'onmouseover="this.style.borderColor='var(--primary)'" ' +
      'onmouseout="this.style.borderColor='var(--border)'" ' +
      'onclick="applyTemplate('' + e._id + '')">' +
      '<div style="flex:1">' +
        '<div style="font-weight:600;font-size:13px">' + esc(e.title) + '</div>' +
        '<div style="font-size:11px;color:var(--text2)">' + esc(e.organizationName) + ' · ' + (e.type||'general') + ' · ' + numFmt(e.totalVotes||0) + ' votes</div>' +
      '</div>' +
      statusBadge(e.status) +
      '<i class="fas fa-chevron-right" style="color:var(--text3);font-size:12px"></i>' +
    '</div>';
  }).join('');
}

async function applyTemplate(id) {
  closeModal('modal-template');

  // Fetch full election details
  var data = await apiCall('/elections/' + id);
  if (!data || !data.success) { toast('error', 'Failed to load template.'); return; }
  var e = data.data.election;

  // Open create modal pre-filled
  openCreateElection();

  // Fill fields — clear ID so it creates new
  document.getElementById('el-id').value    = '';
  document.getElementById('el-title').value = e.title + ' (Copy)';
  document.getElementById('el-org').value   = e.organizationName || '';
  document.getElementById('el-desc').value  = e.description || '';
  document.getElementById('el-type').value  = e.type || 'general';
  document.getElementById('el-status').value = 'pending';
  document.getElementById('el-turnout-target').value = e.turnoutTarget || '';

  // Clear candidates list and repopulate
  document.getElementById('candidates-list').innerHTML = '';
  (e.candidates || []).forEach(function(c) {
    addCandidateRow(c.name || '', c.party || '', c.imageUrl || '');
  });
  if ((e.candidates||[]).length < 2) {
    addCandidateRow('', '');
    addCandidateRow('', '');
  }

  // Set dates: keep same duration, shifted to today+1
  var origDuration = new Date(e.endDate) - new Date(e.startDate);
  var newStart = new Date(Date.now() + 24*60*60*1000); // tomorrow
  var newEnd   = new Date(newStart.getTime() + origDuration);
  document.getElementById('el-start').value = toDatetimeLocal(newStart);
  document.getElementById('el-end').value   = toDatetimeLocal(newEnd);

  document.getElementById('modal-election-title').textContent = 'New Election (from template)';
  toast('success', 'Template applied — update the dates and save.');
}

function debounce(fn, delay) {
  var timer;
  return function () {
    clearTimeout(timer);
    var args = arguments;
    var ctx  = this;
    timer = setTimeout(function () { fn.apply(ctx, args); }, delay);
  };
}

