// Перехватывает переходы на Google Карты и передает адрес приложению Maps Desktop
// через его схему mapsdesktop://open?url=… . Кнопка расширения включает и выключает перехват.

const isMapsLink = (raw) => {
  let u;
  try { u = new URL(raw); } catch { return false; }
  const host = u.hostname.toLowerCase();
  const path = u.pathname.toLowerCase();
  if (host === 'maps.app.goo.gl') return true;
  if (host === 'goo.gl' && path.startsWith('/maps')) return true;
  if (host === 'maps.apple.com') return true;
  if (/^maps\.google\.[a-z.]+$/.test(host)) return true;
  if (/^(www\.)?google\.[a-z.]+$/.test(host) && (path === '/maps' || path.startsWith('/maps/'))) return true;
  return false;
};

const isEnabled = async () => (await chrome.storage.local.get({ enabled: true })).enabled;

const showState = async () => {
  const on = await isEnabled();
  chrome.action.setBadgeText({ text: on ? '' : 'off' });
  chrome.action.setBadgeBackgroundColor({ color: '#5f6368' });
  chrome.action.setTitle({ title: `Open map links in Maps Desktop: ${on ? 'on' : 'off'}` });
};

chrome.action.onClicked.addListener(async () => {
  await chrome.storage.local.set({ enabled: !(await isEnabled()) });
  showState();
});
chrome.runtime.onInstalled.addListener(showState);
chrome.runtime.onStartup.addListener(showState);

// Последний открытый адрес каждой вкладки. tab.url для этого не годится: когда ссылку открывает
// другая программа или ее вставляют в адресную строку, Chrome сразу показывает в нем новый адрес.
// Хранится в storage.session — переживает перезапуск фонового скрипта, но не перезапуск Chrome.
const key = (tabId) => `tab${tabId}`;
const committedUrl = async (tabId) => (await chrome.storage.session.get(key(tabId)))[key(tabId)];
const remember = (tabId, url) => chrome.storage.session.set({ [key(tabId)]: url });

// Вкладки, открытые до запуска расширения, — запоминаем как есть.
const seed = async () => {
  for (const tab of await chrome.tabs.query({})) {
    if (tab.url && (await committedUrl(tab.id)) === undefined) await remember(tab.id, tab.url);
  }
};
chrome.runtime.onInstalled.addListener(seed);
chrome.runtime.onStartup.addListener(seed);

chrome.webNavigation.onBeforeNavigate.addListener(async (d) => {
  if (d.frameId !== 0 || !isMapsLink(d.url) || !(await isEnabled())) return;
  if (new URL(d.url).searchParams.has('mdkeep')) return;   // «Открыть в браузере» из самого приложения
  const prev = await committedUrl(d.tabId);
  // Во вкладке уже карты — пользователь работает с ними в Chrome, не мешаем.
  if (prev && isMapsLink(prev)) return;

  const handoff = 'mapsdesktop://open?url=' + encodeURIComponent(d.url);
  // Вкладка новая и пустая: ее открыли только ради ссылки.
  const blank = !prev || prev === 'about:blank' || prev.startsWith('chrome://newtab') ||
    prev.startsWith('chrome-search://');
  await chrome.tabs.update(d.tabId, { url: handoff }).catch(() => {});
  // Приложение уже показывает карту — пустую вкладку закрываем.
  if (blank) setTimeout(() => chrome.tabs.remove(d.tabId).catch(() => {}), 1500);
});

chrome.webNavigation.onCommitted.addListener((d) => {
  if (d.frameId === 0) remember(d.tabId, d.url);
});
chrome.webNavigation.onTabReplaced.addListener(async (d) => {
  const url = await committedUrl(d.replacedTabId);
  if (url !== undefined) remember(d.tabId, url);
  chrome.storage.session.remove(key(d.replacedTabId));
});
chrome.tabs.onRemoved.addListener((id) => chrome.storage.session.remove(key(id)));
