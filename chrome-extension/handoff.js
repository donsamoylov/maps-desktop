// Страница-переходник: вкладка с ссылкой на карты на мгновение открывает ее и отсюда передает ссылку
// приложению через mapsdesktop://. Страница расширения, а не голая ссылка — тогда Chrome в запросе
// «Открыть Maps Desktop?» предлагает «Всегда разрешать», и вкладку не закрывает.
//   Приложение открылось — закрываем вкладку или возвращаем ее туда, где она была, как выбрал
//   пользователь (в первый раз спрашиваем; настройка closeTab, меняется и в настройках расширения).
//   В запросе нажали «Отмена» — открываем карту здесь же, в Chrome.
//   Приложения на этом Mac нет — предлагаем скачать его или открыть карту здесь.
const params = new URLSearchParams(location.search);
const url = params.get('url') || '';
const back = Number(params.get('back')) || 1;

localize();
document.title = chrome.i18n.getMessage('opening');

const show = (id) => {
  for (const view of document.querySelectorAll('.view')) view.hidden = view.id !== id;
  document.title = document.querySelector(`#${id} h1`).textContent;
};

const goBack = () => {
  if (history.length > back) history.go(-back);
  else chrome.tabs.getCurrent((t) => chrome.tabs.update(t.id, { url: 'chrome://newtab/' }));
};
const closeTab = () => chrome.tabs.getCurrent((t) => chrome.tabs.remove(t.id));

const leave = async () => {
  chrome.storage.local.set({ connected: true });
  const { closeTab: choice } = await chrome.storage.local.get('closeTab');
  if (choice === true) return closeTab();
  if (choice === false) return goBack();
  // Первый раз: спрашиваем, пока пользователь в приложении, — ответ увидит, когда вернется в Chrome.
  show('ask');
  const answer = async (value) => {
    await chrome.storage.local.set({ closeTab: value });
    value ? closeTab() : goBack();
  };
  document.getElementById('close').onclick = () => answer(true);
  document.getElementById('keep').onclick = () => answer(false);
};

const openHere = () => {
  stop();
  const u = new URL(url);
  u.searchParams.set('mdkeep', '1');   // метка: расширение оставит эту ссылку в Chrome
  location.replace(u.href);
};

for (const id of ['here', 'here2']) {
  document.getElementById(id).onclick = (e) => { e.preventDefault(); openHere(); };
}

const stop = openApp('mapsdesktop://open?url=' + encodeURIComponent(url), {
  opened: leave,
  cancelled: openHere,
  missing: () => show('missing'),
});
