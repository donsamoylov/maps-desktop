// Страница-переходник: вкладка с ссылкой на карты на мгновение открывает ее и отсюда передает ссылку
// приложению через mapsdesktop://. Страница расширения, а не голая ссылка — тогда Chrome в запросе
// «Открыть Maps Desktop?» предлагает «Всегда разрешать», и вкладку не закрывает.
//   Приложение открылось (Chrome потерял фокус) — закрываем вкладку или возвращаем ее туда, где она была,
//   как выбрал пользователь (в первый раз спрашиваем; настройка closeTab, меняется и в настройках расширения).
//   В запросе нажали «Отмена» — открываем карту здесь же, в Chrome.
const params = new URLSearchParams(location.search);
const url = params.get('url') || '';
const back = Number(params.get('back')) || 1;
let done = false;

for (const e of document.querySelectorAll('[data-msg]')) e.textContent = chrome.i18n.getMessage(e.dataset.msg);
document.title = chrome.i18n.getMessage('opening');

const goBack = () => {
  if (history.length > back) history.go(-back);
  else chrome.tabs.getCurrent((t) => chrome.tabs.update(t.id, { url: 'chrome://newtab/' }));
};
const closeTab = () => chrome.tabs.getCurrent((t) => chrome.tabs.remove(t.id));

const leave = async () => {
  if (done) return;
  done = true;
  const { closeTab: choice } = await chrome.storage.local.get('closeTab');
  if (choice === true) return closeTab();
  if (choice === false) return goBack();
  // Первый раз: спрашиваем, пока пользователь в приложении, — ответ увидит, когда вернется в Chrome.
  document.getElementById('wait').style.display = 'none';
  document.getElementById('ask').style.display = 'block';
  document.title = chrome.i18n.getMessage('opened');
  const answer = async (value) => {
    await chrome.storage.local.set({ closeTab: value });
    value ? closeTab() : goBack();
  };
  document.getElementById('close').onclick = () => answer(true);
  document.getElementById('keep').onclick = () => answer(false);
};

const openHere = () => {
  if (done) return;
  done = true;
  const u = new URL(url);
  u.searchParams.set('mdkeep', '1');   // метка: расширение оставит эту ссылку в Chrome
  location.replace(u.href);
};

chrome.windows.onFocusChanged.addListener((id) => {
  if (id === chrome.windows.WINDOW_ID_NONE) leave();
});

// Запрос Chrome «Открыть Maps Desktop?» забирает фокус у страницы. Фокус вернулся, а Chrome
// по-прежнему впереди — в запросе нажали «Отмена». Событиям focus/blur тут верить нельзя,
// поэтому просто опрашиваем.
let prompted = false;
const started = Date.now();
const poll = setInterval(async () => {
  if (done) return clearInterval(poll);
  const focused = document.hasFocus();
  if (!focused) { prompted = true; return; }
  const win = await chrome.windows.getCurrent();
  if (!win.focused) return;
  // Запрос был и закрылся «Отменой» — или запроса не было, а приложение так и не открылось.
  if (prompted || Date.now() - started > 4000) openHere();
}, 250);
document.getElementById('here').onclick = (e) => { e.preventDefault(); openHere(); };

location.href = 'mapsdesktop://open?url=' + encodeURIComponent(url);
