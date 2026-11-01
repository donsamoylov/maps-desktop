// Тема Google Карт в Chrome, в мире страницы — рядом с dark-theme.js. «Авто» — как в системе,
// или всегда светлая / темная: выбор из настроек расширения передает theme-bridge.js сообщением.
(() => {
  let choice = 'auto';
  const media = matchMedia('(prefers-color-scheme: dark)');
  const update = () => window.__gmDark(choice === 'dark' || (choice === 'auto' && media.matches));
  media.addEventListener('change', () => { if (choice === 'auto') update(); });
  addEventListener('message', (e) => {
    if (e.source !== window || typeof e.data?.gmTheme !== 'string') return;
    if (e.data.gmTheme === choice) return;
    choice = e.data.gmTheme;
    update();
  });
  update();
  // Сообщение окну самому себе. '*', а не location.origin: в пустых фреймах about:blank, которые
  // создают Карты, location.origin — 'null', и с ним postMessage падает.
  window.postMessage({ gmThemeAsk: true }, '*');
})();
