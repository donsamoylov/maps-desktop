// Общее для страниц расширения: тексты, адреса, запуск приложения.

const REPO_URL = 'https://github.com/donsamoylov/maps-desktop';
const DOWNLOAD_URL = `${REPO_URL}/releases/latest/download/MapsDesktop.zip`;
const INSTALL_HELP_URL = `${REPO_URL}#download-and-install`;

// Тексты — из _locales по data-msg, адреса ссылок — по data-href.
const localize = () => {
  for (const e of document.querySelectorAll('[data-msg]')) e.textContent = chrome.i18n.getMessage(e.dataset.msg);
  const hrefs = { download: DOWNLOAD_URL, installHelp: INSTALL_HELP_URL, repo: REPO_URL };
  for (const e of document.querySelectorAll('[data-href]')) e.href = hrefs[e.dataset.href];
};

// Открывает приложение ссылкой mapsdesktop://… и сообщает, что вышло. Chrome этого не говорит,
// поэтому судим по фокусу (событиям focus/blur тут верить нельзя — опрашиваем):
//   окна Chrome потеряли фокус — приложение открылось: opened;
//   был запрос «Открыть Maps Desktop?», а фокус вернулся в Chrome — в нем нажали «Отмена»: cancelled;
//   запроса нет, приложение не открылось — Chrome не знает такой программы, на этом Mac ее нет: missing.
// После missing уход из Chrome уже ничего не значит (пользователь ушел ставить приложение) — дальше не следим.
const openApp = (href, on) => {
  let prompted = false;
  let over = false;
  const started = Date.now();
  const finish = (result) => {
    if (over) return;
    over = true;
    clearInterval(poll);
    chrome.windows.onFocusChanged.removeListener(onFocus);
    on[result]?.();
  };
  const onFocus = (id) => { if (id === chrome.windows.WINDOW_ID_NONE) finish('opened'); };
  chrome.windows.onFocusChanged.addListener(onFocus);
  const poll = setInterval(async () => {
    if (!document.hasFocus()) { prompted = true; return; }
    const win = await chrome.windows.getCurrent();
    if (!win.focused) return;
    if (prompted) finish('cancelled');
    else if (Date.now() - started > 4000) finish('missing');
  }, 250);
  location.href = href;
  return () => finish('stopped');
};
