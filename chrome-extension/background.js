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

// Вкладки, которые сами по себе — карты (пользователь работает с картами в Chrome): их не трогаем,
// перехватываем только переход НА карты извне.
const stayOnMaps = new Set();

chrome.webNavigation.onBeforeNavigate.addListener(async (d) => {
  if (d.frameId !== 0 || !isMapsLink(d.url) || !(await isEnabled())) return;
  if (new URL(d.url).searchParams.has('mdkeep')) return;   // «Открыть в браузере» из самого приложения
  const tab = await chrome.tabs.get(d.tabId).catch(() => null);
  if (!tab) return;
  if (stayOnMaps.has(d.tabId) || isMapsLink(tab.url || '')) return;

  const handoff = 'mapsdesktop://open?url=' + encodeURIComponent(d.url);
  const blank = !tab.url || tab.url === 'about:blank' || tab.url.startsWith('chrome://newtab');
  await chrome.tabs.update(d.tabId, { url: handoff });
  // Ссылка открылась в новой пустой вкладке — закрываем ее, приложение уже показывает карту.
  if (blank) setTimeout(() => chrome.tabs.remove(d.tabId).catch(() => {}), 1500);
});

// Если пользователь все-таки остался на картах во вкладке — дальше не мешаем.
chrome.webNavigation.onCommitted.addListener((d) => {
  if (d.frameId !== 0) return;
  if (isMapsLink(d.url)) stayOnMaps.add(d.tabId); else stayOnMaps.delete(d.tabId);
});
chrome.tabs.onRemoved.addListener((id) => stayOnMaps.delete(id));
