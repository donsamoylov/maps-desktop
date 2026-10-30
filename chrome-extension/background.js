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

// Сразу после установки — страница «как это работает»: скачать приложение, подключить его к Chrome.
chrome.runtime.onInstalled.addListener(({ reason }) => {
  if (reason === 'install') chrome.tabs.create({ url: 'welcome.html' });
});

// Последний открытый адрес каждой вкладки. tab.url для этого не годится: когда ссылку открывает
// другая программа или ее вставляют в адресную строку, Chrome сразу показывает в нем новый адрес.
// Хранится в storage.session — переживает перезапуск фонового скрипта, но не перезапуск Chrome.
// Копия в памяти читается без ожидания: заранее загруженную страницу Chrome показывает так быстро,
// что запись о ней успевает появиться раньше, чем дочитается хранилище.
const urls = new Map();
const key = (tabId) => `tab${tabId}`;
const committedUrl = async (tabId) =>
  urls.has(tabId) ? urls.get(tabId) : (await chrome.storage.session.get(key(tabId)))[key(tabId)];
const remember = (tabId, url) => {
  urls.set(tabId, url);
  return chrome.storage.session.set({ [key(tabId)]: url });
};
const forget = (tabId) => {
  urls.delete(tabId);
  return chrome.storage.session.remove(key(tabId));
};

// Вкладки, открытые до запуска расширения, — запоминаем как есть.
const seed = async () => {
  for (const tab of await chrome.tabs.query({})) {
    if (tab.url && (await committedUrl(tab.id)) === undefined) await remember(tab.id, tab.url);
  }
};
chrome.runtime.onInstalled.addListener(seed);
chrome.runtime.onStartup.addListener(seed);

// Вкладка переходит на страницу handoff.html, та передает ссылку приложению (см. handoff.js).
// back — на сколько шагов назад вернуть вкладку, когда приложение открылось.
const handoffPage = chrome.runtime.getURL('handoff.html');
const handoff = (tabId, url, back = 1) => chrome.tabs.update(tabId, {
  url: `${handoffPage}?back=${back}&url=${encodeURIComponent(url)}`,
}).catch(() => {});

// Когда расширение последний раз видело переход на карты в каждой вкладке (см. onUpdated ниже).
const seen = new Map();

chrome.webNavigation.onBeforeNavigate.addListener(async (d) => {
  if (d.frameId !== 0 || !isMapsLink(d.url)) return;
  seen.set(d.tabId, Date.now());
  // Что было во вкладке до перехода — читаем первым делом, пока об этом переходе ничего не записано.
  const prev = urls.has(d.tabId) ? urls.get(d.tabId) : await committedUrl(d.tabId);
  if (!(await isEnabled())) return;
  if (new URL(d.url).searchParams.has('mdkeep')) return;   // «Открыть в браузере» из самого приложения
  // Возврат со страницы-переходника — не перехватываем снова.
  if (prev?.startsWith(handoffPage)) return;
  // Во вкладке уже карты — пользователь работает с ними в Chrome, не мешаем. Кроме явной
  // перезагрузки: тот же адрес еще раз — открываем его и в приложении.
  if (prev && isMapsLink(prev) && prev !== d.url) return;
  handoff(d.tabId, d.url);
});

// Адрес из строки адреса Chrome может загрузить заранее, в фоне, и потом просто показать готовую
// страницу — без перехода, который видно в onBeforeNavigate. Такие карты ловим по смене адреса
// вкладки: если во вкладке были не карты и перехода расширение не видело — отдаем ссылку
// приложению, а вкладку потом возвращаем на два шага назад, мимо этих карт.
chrome.tabs.onUpdated.addListener(async (tabId, info) => {
  if (!info.url || !isMapsLink(info.url) || new URL(info.url).searchParams.has('mdkeep')) return;
  const prev = await committedUrl(tabId);
  if (prev && (isMapsLink(prev) || prev.startsWith(handoffPage))) return;
  setTimeout(async () => {
    if (Date.now() - (seen.get(tabId) ?? 0) < 3000 || !(await isEnabled())) return;
    seen.set(tabId, Date.now());
    handoff(tabId, info.url, 2);
  }, 500);
});

// Карты меняют адрес без перезагрузки (history.pushState) — его тоже запоминаем, чтобы узнать перезагрузку.
const onUrl = (d) => {
  if (d.frameId !== 0) return;
  remember(d.tabId, d.url);
};
chrome.webNavigation.onCommitted.addListener(onUrl);
chrome.webNavigation.onHistoryStateUpdated.addListener(onUrl);
chrome.webNavigation.onReferenceFragmentUpdated.addListener(onUrl);
chrome.webNavigation.onTabReplaced.addListener(async (d) => {
  const url = await committedUrl(d.replacedTabId);
  if (url !== undefined) remember(d.tabId, url);
  forget(d.replacedTabId);
});
chrome.tabs.onRemoved.addListener(forget);
