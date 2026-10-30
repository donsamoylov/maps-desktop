// Настройки расширения: закрывать ли вкладку, когда карта открылась в приложении.
localize();
chrome.runtime.getPlatformInfo().then(({ os }) => { document.getElementById('notMac').hidden = os === 'mac'; });
const box = document.getElementById('closeTab');
chrome.storage.local.get('closeTab').then(({ closeTab }) => { box.checked = closeTab === true; });
box.onchange = () => chrome.storage.local.set({ closeTab: box.checked });
