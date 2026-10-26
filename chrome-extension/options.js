// Настройки расширения: закрывать ли вкладку, когда карта открылась в приложении.
for (const e of document.querySelectorAll('[data-msg]')) e.textContent = chrome.i18n.getMessage(e.dataset.msg);
const box = document.getElementById('closeTab');
chrome.storage.local.get('closeTab').then(({ closeTab }) => { box.checked = closeTab === true; });
box.onchange = () => chrome.storage.local.set({ closeTab: box.checked });
