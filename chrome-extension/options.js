// Настройки расширения: тема Google Карт в Chrome и (на Mac) закрывать ли вкладку, когда карта
// открылась в приложении.
localize();
bindTheme(document.getElementById('theme'));
onMac.then((mac) => {
  document.getElementById('notMac').hidden = mac;
  for (const e of document.querySelectorAll('.mac')) e.hidden = !mac;
});
const box = document.getElementById('closeTab');
chrome.storage.local.get('closeTab').then(({ closeTab }) => { box.checked = closeTab === true; });
box.onchange = () => chrome.storage.local.set({ closeTab: box.checked });
