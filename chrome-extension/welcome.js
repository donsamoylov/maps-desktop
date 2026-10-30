// Страница после установки: как это работает, где взять приложение и кнопка «Подключить» — она
// открывает приложение (mapsdesktop://connect), Chrome при этом спрашивает «Открыть Maps Desktop?»,
// и «Всегда разрешать» ставится сразу, а не на первой ссылке. Приложение показывает, что подключено.
localize();
document.title = chrome.i18n.getMessage('welTitle');

const status = document.getElementById('status');
const say = (msg, cls = '') => {
  status.hidden = false;
  status.className = cls;
  status.textContent = chrome.i18n.getMessage(msg);
};

chrome.storage.local.get('connected').then(({ connected }) => { if (connected) say('connected', 'ok'); });

let stop = () => {};
document.getElementById('connect').onclick = () => {
  stop();
  say('connecting');
  stop = openApp('mapsdesktop://connect', {
    opened: () => { chrome.storage.local.set({ connected: true }); say('connected', 'ok'); },
    cancelled: () => say('connectCancelled', 'bad'),
    missing: () => say('connectMissing', 'bad'),
  });
};
