// Gullak NGO dashboard: a small single-page app on the Gullak NGO API.
// Everything shown comes from the API for the signed-in organisation; there
// is no built-in data. DOM is built with createElement/textContent only, so
// no server value is ever parsed as HTML.

const API = `${window.GULLAK_API_BASE}/api/v1`;
const REFRESH_MS = 15000;
const DEMO_ORGS = [
  { name: "Green Futures Foundation", user: "green.coordinator", pass: "green-demo-2026", codes: "NGO-HYD-001, NGO-HYD-002" },
  { name: "Udaan Learning Trust", user: "udaan.coordinator", pass: "udaan-demo-2026", codes: "NGO-WGL-001, NGO-KRM-001" },
  { name: "Youth Finance Collective", user: "yfc.coordinator", pass: "yfc-demo-2026", codes: "NGO-VJA-001" },
];
const CHAPTERS = {
  C1: "1 · The First ₹1,000",
  C2: "2 · The Laptop Dream",
  C3: "3 · Digital Money",
  C4: "4 · Scholarship Message",
  C5: "5 · Buy Now or Wait?",
  C6: "6 · Make Money Work",
  C7: "7 · When Plans Change",
};
const STATUS = {
  awaiting_first_sync: "Awaiting first sync",
  in_progress: "In progress",
  completed: "Story completed",
  inactive: "Inactive",
};
const INDICATORS = {
  c1_surprise_cost: ["Ch 1 · surprise ₹60 form fee", { own_money: "paid from own budget", advance: "took an advance" }],
  c2_goal: ["Ch 2 · savings goal", { kit: "₹1,000 kit", course: "₹1,500 course", laptop: "₹3,000 laptop share" }],
  c2_weeks_saved: ["Ch 2 · weeks with saving (of 4)"],
  c3_pending_payment: ["Ch 3 · pending UPI payment", { verified: "checked status first ✓", paid_twice: "paid twice", paid_cash: "paid again in cash" }],
  c4_scams_handled_safely: ["Ch 4 · fake messages handled safely (of 4)"],
  c4_scams_followed: ["Ch 4 · fake messages followed"],
  c4_hints_used: ["Ch 4 · hints used"],
  c5_payment_method: ["Ch 5 · how the phone was bought", { debit: "debit / savings", cash: "cash", credit: "store credit", waited: "waited" }],
  c5_credit_repayment: ["Ch 5 · credit repayment", { full: "paid in full", more_than_minimum: "more than minimum", minimum: "minimum only" }],
  c6_fixed_deposit: ["Ch 6 · opened a fixed deposit", { true: "yes", false: "no" }],
  c6_emergency_source: ["Ch 6 · paid the surprise cost from", { savings: "savings ✓", broke_deposit: "broke the deposit", borrowed_family: "borrowed from family" }],
  c7_claimed_excluded_cost: ["Ch 7 · tried to claim an excluded cost", { true: "yes", false: "no ✓" }],
  c7_policy_choice: ["Ch 7 · insurance decision", { keep: "kept the policy", addon: "added cover", drop: "dropped it" }],
  c7_used_emergency_fund: ["Ch 7 · used the family emergency fund", { true: "yes ✓", false: "no" }],
};

// ---- tiny DOM helpers -------------------------------------------------------

function h(tag, attrs = {}, ...children) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v === undefined || v === null || v === false) continue;
    if (k === "class") el.className = v;
    else if (k.startsWith("on")) el.addEventListener(k.slice(2), v);
    else if (k === "style") Object.assign(el.style, v);
    else el.setAttribute(k, v === true ? "" : v);
  }
  for (const c of children.flat()) {
    if (c === null || c === undefined || c === false) continue;
    el.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
  return el;
}
const app = document.getElementById("app");
function render(...nodes) { app.replaceChildren(...nodes); }

const fmtDate = (iso) => iso ? new Date(iso).toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" }) : "—";
function ago(iso) {
  if (!iso) return "never";
  const s = (Date.now() - new Date(iso).getTime()) / 1000;
  if (s < 60) return "just now";
  if (s < 3600) return `${Math.floor(s / 60)} min ago`;
  if (s < 86400) return `${Math.floor(s / 3600)} h ago`;
  return `${Math.floor(s / 86400)} days ago`;
}
const stars = (n) => h("span", { class: "stars", "aria-label": `${n} of 3 stars` }, "★".repeat(n) + "☆".repeat(Math.max(0, 3 - n)));
const pill = (status) => h("span", { class: `pill ${status}` }, STATUS[status] || status);

// ---- session & API ----------------------------------------------------------

const session = {
  get token() { try { return sessionStorage.getItem("gullak_dash_token"); } catch { return null; } },
  set token(v) { try { v ? sessionStorage.setItem("gullak_dash_token", v) : sessionStorage.removeItem("gullak_dash_token"); } catch { /* private mode */ } },
  me: null,
};

class ApiError extends Error {
  constructor(status, code, message) { super(message); this.status = status; this.code = code; }
}

async function api(path, { method = "GET", body } = {}) {
  let res;
  try {
    res = await fetch(`${API}${path}`, {
      method,
      headers: {
        ...(body ? { "Content-Type": "application/json" } : {}),
        ...(session.token ? { Authorization: `Bearer ${session.token}` } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
  } catch {
    throw new ApiError(0, "network", `Cannot reach the Gullak API at ${window.GULLAK_API_BASE}. Is the backend running?`);
  }
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = new ApiError(res.status, data?.error?.code, data?.error?.message || `Request failed (${res.status})`);
    if (res.status === 401 && path !== "/dashboard/login") {
      session.token = null; session.me = null; go("#/login");
    }
    throw err;
  }
  return data;
}

// ---- routing & refresh ------------------------------------------------------

let timer = null;
let current = null; // { load, paint } for the visible page
let lastUpdated = null;

function go(hash) { if (location.hash !== hash) location.hash = hash; else route(); }

async function refresh(showLoading = false) {
  if (!current) return;
  const page = current;
  if (showLoading) render(h("div", { class: "loading" }, "Loading…"));
  try {
    const data = await page.load();
    if (page !== current) return;
    lastUpdated = new Date();
    page.paint(data);
  } catch (e) {
    if (page !== current || e.status === 401) return;
    render(errorView(e));
  }
}

function startPolling() {
  clearInterval(timer);
  // New enrolments and syncs show up without anyone clicking anything.
  timer = setInterval(() => { if (document.visibilityState === "visible") refresh(); }, REFRESH_MS);
}
document.addEventListener("visibilitychange", () => { if (document.visibilityState === "visible") refresh(); });

function errorView(e) {
  return h("div", { class: "card" },
    h("div", { class: "error", role: "alert" }, e.message),
    h("p", {}, h("button", { class: "btn", onclick: () => refresh(true) }, "Try again")));
}

function updatedLine() {
  return h("span", { class: "updated", id: "updated" },
    `Updated ${lastUpdated ? lastUpdated.toLocaleTimeString() : "—"} · refreshes every ${REFRESH_MS / 1000} s `,
    h("button", { class: "btn link", onclick: () => refresh() }, "Refresh now"));
}

async function route() {
  const parts = location.hash.replace(/^#\/?/, "").split("/");
  const name = parts[0] || "overview";
  if (!session.token && name !== "login") return go("#/login");
  if (session.token && !session.me) {
    try { session.me = await api("/dashboard/me"); } catch { return; }
  }
  paintChrome(name);
  const pages = { login: loginPage, overview: overviewPage, students: parts[1] ? () => studentPage(decodeURIComponent(parts[1])) : studentsPage, centres: centresPage };
  current = (pages[name] || overviewPage)();
  refresh(true);
}
window.addEventListener("hashchange", route);

function paintChrome(name) {
  const nav = document.getElementById("nav");
  const account = document.getElementById("account");
  const signedIn = Boolean(session.me) && name !== "login";
  nav.hidden = !signedIn;
  account.hidden = !signedIn;
  for (const a of nav.querySelectorAll("a")) a.classList.toggle("active", a.dataset.route === name);
  if (signedIn) {
    account.replaceChildren(
      h("span", {}, session.me.ngo.name),
      h("button", { class: "btn", onclick: signOut }, "Sign out"));
  }
}

async function signOut() {
  try { await api("/dashboard/logout", { method: "POST" }); } catch { /* already gone */ }
  session.token = null; session.me = null; go("#/login");
}

// ---- pages ------------------------------------------------------------------

function loginPage() {
  clearInterval(timer);
  let chosen = null;
  let demoLogins = false;
  const user = h("input", { name: "username", autocomplete: "username", required: true, "aria-label": "Username" });
  const pass = h("input", { name: "password", type: "password", autocomplete: "current-password", required: true, "aria-label": "Password" });
  const msg = h("div");
  const orgButtons = DEMO_ORGS.map((o) => h("button", {
    type: "button", class: "card org", "aria-pressed": "false",
    onclick: (ev) => {
      chosen = o; user.value = o.user; pass.value = demoLogins ? o.pass : "";
      if (!demoLogins) pass.focus();
      for (const b of orgButtons) b.setAttribute("aria-pressed", String(b === ev.currentTarget));
    },
  }, h("b", {}, o.name), h("span", { class: "muted small" }, `Codes: ${o.codes}`)));
  const form = h("form", {
    class: "signin",
    onsubmit: async (ev) => {
      ev.preventDefault();
      msg.replaceChildren();
      try {
        const r = await api("/dashboard/login", { method: "POST", body: { username: user.value, password: pass.value } });
        session.token = r.session_token;
        session.me = null;
        startPolling();
        go("#/overview");
      } catch (e) {
        msg.replaceChildren(h("div", { class: "error", role: "alert" }, e.message));
      }
    },
  }, h("label", {}, "Username", user), h("label", {}, "Password", pass), msg,
     h("button", { class: "btn primary", type: "submit" }, "Sign in"));
  return {
    load: async () => {
      try { demoLogins = Boolean((await api("/health")).demo_logins); } catch { demoLogins = false; }
      return null;
    },
    paint: () => render(h("section", { class: "login" },
      h("h1", {}, "Sign in to your NGO dashboard"),
      h("p", { class: "sub" }, "Each organisation sees only its own students. Students appear here automatically after they enter their NGO's code in the Gullak app."),
      h("div", { class: "card" },
        h("h2", {}, "Demo organisations"),
        h("p", { class: "muted small" }, demoLogins
          ? "Demo sign-in for the local prototype: choosing an organisation fills in its demo username and password. These are fictional NGOs; the server still checks the password and limits each session to that NGO's data."
          : "These are fictional demo NGOs. Choose one to fill in its username, then enter the password you were given. Each session sees only that NGO's data."),
        h("div", { class: "orgs" }, orgButtons),
        form))),
  };
}

function kpi(label, value, note) {
  return h("div", { class: "card kpi" }, h("div", { class: "label" }, label), h("div", { class: "value" }, value), note ? h("div", { class: "note" }, note) : null);
}

const tooltip = h("div", { class: "tooltip", role: "tooltip" });
document.body.append(tooltip);
function withTip(el, text) {
  const show = (x, y) => { tooltip.textContent = text; tooltip.style.display = "block"; tooltip.style.left = `${x + 12}px`; tooltip.style.top = `${y + 12}px`; };
  el.addEventListener("mousemove", (e) => show(e.clientX, e.clientY));
  el.addEventListener("mouseleave", () => { tooltip.style.display = "none"; });
  el.addEventListener("focus", () => { const r = el.getBoundingClientRect(); show(r.left, r.bottom); });
  el.addEventListener("blur", () => { tooltip.style.display = "none"; });
  el.tabIndex = 0;
  el.setAttribute("aria-label", text);
  return el;
}

// Horizontal bars, one series. `rows`: [{label, pct, value, tip}]
function barChart(rows, caption) {
  return h("figure", { style: { margin: "0" } },
    h("figcaption", { class: "visually-hidden" }, caption),
    h("div", { class: "bars" }, rows.map((r) => withTip(
      h("div", { class: "bar-row" },
        h("span", { class: "bar-label", title: r.label }, r.label),
        h("span", { class: "bar-track" }, h("span", { class: "bar-fill", style: { width: `${Math.max(0, Math.min(100, r.pct))}%`, display: "block" } })),
        h("span", { class: "bar-value" }, r.value)),
      r.tip))),
    h("div", { class: "axis", "aria-hidden": "true" }, h("span"), h("span", { class: "ticks" }, ["0%", "25%", "50%", "75%", "100%"].map((t) => h("span", {}, t))), h("span")));
}

function emptyState(ngo) {
  const codes = (ngo.enrolment_codes || []).filter((c) => c.status === "active").map((c) => c.code).join(", ");
  return h("div", { class: "card empty" },
    h("div", { class: "big", "aria-hidden": "true" }, "🪴"),
    h("h2", {}, "No students yet"),
    h("p", {}, "Students appear here automatically when they enter your enrolment code in the Gullak app and their phone is online. Their progress updates after each sync — nobody needs to add them by hand."),
    codes ? h("p", {}, "Share your code with students: ", h("b", { class: "mono" }, codes)) : null,
    h("p", { class: "muted small" }, "A student who enrols while offline shows up once their phone reconnects."));
}

function overviewPage() {
  return {
    load: () => api("/dashboard/overview"),
    paint: (o) => {
      const t = o.totals;
      const head = h("div", { class: "row spread" },
        h("div", {}, h("h1", {}, o.ngo.name),
          h("p", { class: "sub" }, o.ngo.centres.map((c) => `${c.name} (${c.city})`).join(" · "))),
        updatedLine());
      if (t.enrolled === 0) return render(head, emptyState(o.ngo));
      const kpis = h("div", { class: "grid kpis" },
        kpi("Enrolled students", t.enrolled, `${t.synced} have sent progress`),
        kpi(`Active in last ${o.active_days} days`, t.active_recently, `${Math.round(100 * t.active_recently / t.enrolled)}% of enrolled`),
        kpi("Overall completion", `${t.overall_completion_pct}%`, `avg ${t.avg_chapters_completed} of 7 chapters`),
        kpi("Avg stars per chapter", t.avg_stars_per_completed_chapter ?? "—", "for completed chapters, out of 3"),
        kpi("Finished the story", t.story_completed, `${t.badges_awarded} badges earned in total`));
      const chapters = h("div", { class: "card" },
        h("h2", {}, "Chapter completion"),
        h("p", { class: "muted small" }, "Share of enrolled students who have finished each chapter. Hover a bar for stars and replays."),
        barChart(o.chapters.map((c) => ({
          label: CHAPTERS[c.id], pct: c.completion_pct, value: `${c.completed} · ${c.completion_pct}%`,
          tip: `${CHAPTERS[c.id]}: ${c.completed} of ${t.enrolled} students (${c.completion_pct}%)` +
            (c.avg_stars != null ? ` · avg ${c.avg_stars}★ · avg ${c.avg_plays} plays` : ""),
        })), "Chapter completion bar chart"));
      const struggles = h("div", { class: "card" },
        h("h2", {}, "Where students may be struggling"),
        o.struggles.length === 0
          ? h("p", { class: "muted" }, "No warning signs in the progress received so far.")
          : h("ul", { class: "list" }, o.struggles.slice(0, 7).map((s) => h("li", { class: "struggle" },
              h("span", { class: "icon", "aria-hidden": "true" }, "⚠"),
              h("span", {}, h("b", {}, CHAPTERS[s.chapter] ? CHAPTERS[s.chapter].replace(/^\d · /, `Ch ${s.chapter.slice(1)} · `) : s.chapter), h("br"),
                h("span", { class: "small" }, `${s.count} of ${s.of} students ${s.description}`)),
              h("span", { class: "pct" }, `${s.pct}%`)))));
      const statusCard = h("div", { class: "card" }, h("h2", {}, "Student status"),
        h("ul", { class: "list" }, Object.entries(STATUS).map(([k]) => h("li", { class: "row spread" }, pill(k), h("b", {}, o.status_counts[k] || 0)))));
      const activity = h("div", { class: "card" }, h("h2", {}, "Recent sync activity"), activityList(o.recent_activity));
      render(head, kpis, h("div", { class: "grid two" }, chapters, struggles), h("div", { class: "grid two", style: { marginTop: "16px" } }, activity, statusCard));
    },
  };
}

function activityList(items) {
  if (!items.length) return h("p", { class: "muted" }, "Nothing yet.");
  return h("ul", { class: "list" }, items.map((a) => h("li", { class: "row spread" },
    h("span", {}, h("a", { href: `#/students/${encodeURIComponent(a.student_id)}`, class: "mono" }, a.student_id), " ",
      a.kind === "enrolled" ? `enrolled at ${a.centre_name}` : `synced progress (rev ${a.revision}, ${a.chapters_completed} chapters)`),
    h("span", { class: "muted small", title: fmtDate(a.at) }, ago(a.at)))));
}

const listState = { search: "", centre: "", status: "", sort: "last_activity", order: "desc", page: 1 };

function studentsPage() {
  const params = () => new URLSearchParams({ ...listState, page_size: 20 }).toString();
  return {
    load: () => api(`/dashboard/students?${params()}`),
    paint: (d) => {
      const ngo = session.me.ngo;
      const search = h("input", { type: "search", placeholder: "Search student ID", value: listState.search, "aria-label": "Search student ID", maxlength: "20" });
      let debounce;
      search.addEventListener("input", () => { clearTimeout(debounce); debounce = setTimeout(() => { listState.search = search.value.trim(); listState.page = 1; refresh(); }, 300); });
      const select = (key, label, options) => {
        const s = h("select", { "aria-label": label, onchange: () => { listState[key] = s.value; listState.page = 1; refresh(); } },
          options.map(([v, t]) => h("option", { value: v, selected: listState[key] === v }, t)));
        return s;
      };
      const sortHead = (key, label, num) => h("th", { class: num ? "num" : "", "aria-sort": listState.sort === key ? (listState.order === "asc" ? "ascending" : "descending") : "none" },
        h("button", { onclick: () => {
          listState.order = listState.sort === key && listState.order === "desc" ? "asc" : "desc";
          listState.sort = key; refresh();
        } }, label, listState.sort === key ? (listState.order === "asc" ? " ▲" : " ▼") : ""));
      const pages = Math.max(1, Math.ceil(d.total / d.page_size));
      const body = d.students.length === 0
        ? (d.total === 0 && !listState.search && !listState.centre && !listState.status ? emptyState(ngo) : h("p", { class: "muted" }, "No students match these filters."))
        : h("div", { class: "table-scroll" }, h("table", {},
          h("thead", {}, h("tr", {}, sortHead("student_id", "Student ID"), h("th", {}, "Centre"), sortHead("current_chapter", "Current chapter", true),
            sortHead("chapters_completed", "Completed", true), sortHead("stars", "Stars", true), h("th", { class: "num" }, "Badges"),
            sortHead("last_activity", "Last activity"), sortHead("last_sync", "Last sync"), h("th", {}, "Status"))),
          h("tbody", {}, d.students.map((s) => {
            const open = () => go(`#/students/${encodeURIComponent(s.student_id)}`);
            return h("tr", { tabindex: "0", onclick: open, onkeydown: (e) => { if (e.key === "Enter") open(); } },
              h("td", { class: "mono" }, s.student_id), h("td", {}, s.centre.name),
              h("td", { class: "num" }, s.current_chapter == null ? "—" : s.story_finished ? "Finished" : `Ch ${s.current_chapter}`),
              h("td", { class: "num" }, `${s.chapters_completed} / 7`), h("td", { class: "num" }, `${s.total_stars} ★`),
              h("td", { class: "num" }, s.badge_count), h("td", { title: fmtDate(s.last_activity_at) }, ago(s.last_activity_at)),
              h("td", { title: fmtDate(s.last_sync_at) }, ago(s.last_sync_at)), h("td", {}, pill(s.status)));
          }))));
      render(
        h("div", { class: "row spread" }, h("div", {}, h("h1", {}, "Students"), h("p", { class: "sub" }, `${d.total} student${d.total === 1 ? "" : "s"} · anonymous IDs only; Gullak never collects names.`)), updatedLine()),
        h("div", { class: "card" },
          h("div", { class: "toolbar" }, search,
            select("centre", "Centre", [["", "All centres"], ...ngo.centres.map((c) => [c.id, c.name])]),
            select("status", "Status", [["", "All statuses"], ...Object.entries(STATUS)])),
          body,
          d.total > d.page_size ? h("div", { class: "pager" },
            h("button", { class: "btn", disabled: listState.page <= 1, onclick: () => { listState.page--; refresh(); } }, "‹ Previous"),
            h("span", { class: "small" }, `Page ${d.page} of ${pages}`),
            h("button", { class: "btn", disabled: listState.page >= pages, onclick: () => { listState.page++; refresh(); } }, "Next ›")) : null));
      if (document.activeElement?.type !== "search" && listState.search) { /* keep focus behaviour simple */ }
    },
  };
}

function studentPage(id) {
  return {
    load: () => api(`/dashboard/students/${encodeURIComponent(id)}`),
    paint: (s) => {
      const indicators = Object.entries(s.indicators || {}).filter(([, v]) => v !== null && v !== undefined).map(([k, v]) => {
        const [label, names] = INDICATORS[k] || [k];
        return h("li", { class: "row spread" }, h("span", {}, label), h("b", {}, names ? (names[String(v)] ?? String(v)) : String(v)));
      });
      render(
        h("p", {}, h("a", { href: "#/students" }, "‹ All students")),
        h("div", { class: "row spread" }, h("div", {}, h("h1", { class: "mono" }, s.student_id),
          h("p", { class: "sub" }, `${s.centre.name}, ${s.centre.city} · `, pill(s.status))), updatedLine()),
        h("div", { class: "grid two" },
          h("div", { class: "card" }, h("h2", {}, "Chapters"),
            h("div", { class: "chapters" }, s.chapters.map((c) => h("div", { class: `chapter ${c.state}` },
              h("div", { class: "name" }, CHAPTERS[c.id]),
              c.state === "completed" ? h("div", {}, stars(c.best_stars), h("div", { class: "small muted" }, `${c.plays} play${c.plays === 1 ? "" : "s"}`))
                : h("div", { class: "small" }, c.state === "current" ? "Playing now" : c.state === "locked" ? "Locked" : "Not started")))),
            h("h2", { style: { marginTop: "18px" } }, `Badges (${s.badges.length})`),
            s.badges.length ? h("p", {}, s.badges.map((b) => b.replace(/_/g, " ")).join(" · ")) : h("p", { class: "muted" }, "None yet.")),
          h("div", { class: "card" }, h("h2", {}, "Sync"),
            h("dl", { class: "kv" },
              h("dt", {}, "Enrolled"), h("dd", {}, fmtDate(s.enrolled_at)),
              h("dt", {}, "Last activity"), h("dd", {}, `${ago(s.last_activity_at)} (to the hour)`),
              h("dt", {}, "Last sync"), h("dd", {}, fmtDate(s.last_sync_at)),
              h("dt", {}, "Report revision"), h("dd", {}, s.revision ?? "—"),
              h("dt", {}, "App version"), h("dd", {}, s.app_version || "—")))),
        h("div", { class: "grid two", style: { marginTop: "16px" } },
          h("div", { class: "card" }, h("h2", {}, "Learning indicators"),
            h("p", { class: "muted small" }, "Outcomes of key decisions in chapters this student has finished. Pretend-money amounts are never shared."),
            indicators.length ? h("ul", { class: "list" }, indicators) : h("p", { class: "muted" }, "Appear after the first chapter is finished.")),
          h("div", { class: "card" }, h("h2", {}, "Recent progress updates"),
            s.history.length ? h("div", { class: "table-scroll" }, h("table", {},
              h("thead", {}, h("tr", {}, h("th", { class: "num" }, "Revision"), h("th", {}, "Received"), h("th", { class: "num" }, "Chapter"), h("th", { class: "num" }, "Completed"), h("th", { class: "num" }, "Stars"))),
              h("tbody", {}, s.history.map((x) => h("tr", {}, h("td", { class: "num" }, x.revision), h("td", {}, fmtDate(x.received_at)),
                h("td", { class: "num" }, x.current_chapter === 8 ? "Finished" : x.current_chapter), h("td", { class: "num" }, x.chapters_completed), h("td", { class: "num" }, x.total_stars))))))
              : h("p", { class: "muted" }, "No progress received yet. It arrives when the student's phone is online."))));
    },
  };
}

function centresPage() {
  return {
    load: () => api("/dashboard/centres"),
    paint: (d) => {
      const total = d.centres.reduce((n, c) => n + c.enrolled, 0);
      render(
        h("div", { class: "row spread" }, h("div", {}, h("h1", {}, "Centres"), h("p", { class: "sub" }, "Rollout and completion by centre.")), updatedLine()),
        total === 0 ? emptyState(session.me.ngo) : null,
        h("div", { class: "grid", style: { gridTemplateColumns: "repeat(auto-fit, minmax(min(100%, 460px), 1fr))" } }, d.centres.map((c) => h("div", { class: "card" },
          h("h2", {}, `${c.name}`), h("p", { class: "muted small" }, c.city),
          h("div", { class: "grid kpis", style: { gridTemplateColumns: "repeat(3, minmax(0, 1fr))" } },
            kpi("Enrolled", c.enrolled), kpi("Active", c.active_recently), kpi("Completion", `${c.overall_completion_pct}%`)),
          c.enrolled === 0 ? h("p", { class: "muted" }, "No students from this centre yet.")
            : barChart(c.chapters.map((ch) => ({
              label: CHAPTERS[ch.id], pct: ch.completion_pct, value: `${ch.completed} · ${ch.completion_pct}%`,
              tip: `${c.name} · ${CHAPTERS[ch.id]}: ${ch.completed} of ${c.enrolled} (${ch.completion_pct}%)`,
            })), `${c.name} chapter completion`)))));
    },
  };
}

if (session.token) startPolling();
route();
