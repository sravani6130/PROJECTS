# Gullak NGO dashboard

Static single-page web app (HTML, CSS, plain ES modules; no build step, no
third-party code) for NGO programme coordinators. It talks only to the Gullak
NGO API; every number on it comes from the API for the signed-in NGO.

The API serves it at `/` (e.g. `http://127.0.0.1:8787/` locally, the Render URL
when deployed). For editing, it can also run on its own:

```bash
python3 -m http.server 5173 --bind 127.0.0.1 -d ngo-dashboard   # from the repo root
# open http://127.0.0.1:5173  (the API must be running on :8787)
```

- API location: `config.js` — the page's own origin, or `:8787` when opened from
  the `:5173` dev server. A dashboard on a different origin must be added to the
  CSP `connect-src` and to the API's `GULLAK_CORS_ORIGINS`.
- Pages: sign-in (demo organisation picker that fills in demo credentials; the
  server still checks them), Overview, Students (search, centre/status filters,
  sorting, pagination), Student detail, Centres.
- Data refreshes every 15 s while the tab is visible, and on "Refresh now", so
  newly enrolled students appear without anyone adding them.
- The session token is kept in `sessionStorage` (cleared when the tab closes).
  For production use HTTPS, real accounts per NGO staff member, and preferably an
  HttpOnly cookie session behind the same origin as the API.
