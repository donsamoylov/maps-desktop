// Передает странице Google Карт тему из настроек расширения (theme: auto | light | dark): у скриптов
// в мире страницы нет доступа к chrome.storage. Сообщение уходит при загрузке, по запросу theme-page.js
// и при каждой смене настройки.
const sendTheme = async () => {
  const { theme } = await chrome.storage.local.get({ theme: 'auto' });
  window.postMessage({ gmTheme: theme }, '*');   // окну самому себе; '*' — см. theme-page.js
};
addEventListener('message', (e) => { if (e.source === window && e.data?.gmThemeAsk) sendTheme(); });
chrome.storage.onChanged.addListener((changes) => { if (changes.theme) sendTheme(); });
sendTheme();
