// Where the Gullak NGO API runs. When the dashboard is served by the API
// itself (deployments, or http://127.0.0.1:8787/ locally) it is the same
// origin. The stand-alone dev server on :5173 talks to the local API.
window.GULLAK_API_BASE = window.GULLAK_API_BASE ||
  (location.port === "5173" ? `${location.protocol}//${location.hostname}:8787` : location.origin);
