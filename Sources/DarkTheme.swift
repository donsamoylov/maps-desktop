import AppKit
import WebKit

enum Theme: String {
    case system, light, dark

    static var current: Theme {
        get { Theme(rawValue: UserDefaults.standard.string(forKey: "theme") ?? "") ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "theme") }
    }
}

/// Темная тема для веб-версии Google Maps: своей у сайта нет. Интерфейс перекрашивается инверсией
/// страницы; фото, видео и холст карты инвертируются обратно, а темную схему карты (цвета как в Google
/// Картах на iPhone) рисуют шейдеры Google, в которые дописан перевод цветов.
enum DarkTheme {
    private static let source = #"""
    (() => {
      if (!window.__gmDark) {
        const css = `
          html.gm-dark:not(.gm-split) { filter: invert(0.9) hue-rotate(180deg) !important; background: #fff !important; }
          /* Холст карты — вне фильтра страницы (иначе цвета на нем не ярче 0,9 и не темнее 0,1): фильтр
             получает все, что рядом с цепочкой предков холста (gm-chain), а сама цепочка и холст — нет. */
          html.gm-dark.gm-split, html.gm-dark.gm-split .gm-chain
            { background-color: rgb(26, 26, 26) !important; background-image: none !important; }
          html.gm-dark.gm-split .gm-flt { filter: invert(0.9) hue-rotate(180deg) !important; }
          /* картинки и «не инвертируемое» прямо рядом с цепочкой — без фильтра вовсе */
          html.gm-dark.gm-split.gm-split .gm-flt:is(img, video, picture, canvas, .gm-unflip,
            [style*="background-image: url"], [style*="background-image:url"])
            { filter: none !important; }
          html.gm-dark.gm-frame { background: transparent !important; }
          html.gm-dark img, html.gm-dark video, html.gm-dark picture,
          html.gm-dark [style*="background-image: url"], html.gm-dark [style*="background-image:url"],
          html.gm-dark canvas, html.gm-dark .gm-unflip
            { filter: invert(1) hue-rotate(180deg) !important; }
          html.gm-dark .gm-unflip img, html.gm-dark .gm-unflip [style*="background-image"]
            { filter: none !important; }
          html.gm-dark .gm-reflip { filter: invert(1) hue-rotate(180deg) !important; }
          html.gm-dark .gm-unflip canvas { filter: none !important; }
          /* Растровые тайлы схемы (слой !1e0!2sm) — заглушка, пока не готова WebGL-карта. Светлые, а
             затемненные — серые, не в цвет темной карты: прячем, под ними уже темная WebGL-карта.
             Миниатюра кнопки «Слои» — тоже тайлы /maps/vt, но другого слоя, ее не трогаем. */
          html.gm-dark:not(.gm-photo) img[src*="/maps/vt"][src*="!1e0!2sm"] { visibility: hidden !important; }
          /* Холст карты страница не инвертирует (он перевернут обратно, как фото), темную схему рисуют
             шейдеры. Пустой или перерисовывающийся холст показывает свой фон — пусть он будет цвета земли. */
          html.gm-dark:not(.gm-photo) canvas { background-color: rgb(8, 16, 41) !important; }
          html.gm-dark.gm-split canvas.gm-map { filter: none !important; }
          /* где Google на холсте не рисует (под левой колонкой) — цвет колонки */
          html.gm-dark.gm-split:not(.gm-photo) canvas.gm-map { background-color: rgb(30, 30, 30) !important; }
          /* переход в Street View и обратно: карта и фото на мгновение в одном canvas — плавно гасим его */
          html.gm-dark.gm-swap canvas { filter: brightness(0) invert(0.9) !important; }
          html.gm-dark.gm-split.gm-swap canvas.gm-map { filter: brightness(0) invert(0.1) !important; }
          /* фото внутри фото (черновик и полная картинка) — второй раз не переворачиваем */
          html.gm-dark [style*="background-image: url"] [style*="background-image: url"], html.gm-dark [style*="background-image: url"] [style*="background-image:url"], html.gm-dark [style*="background-image:url"] [style*="background-image: url"], html.gm-dark [style*="background-image:url"] [style*="background-image:url"]
            { filter: none !important; }
          html.gm-dark [style*="background-image: url"] img, html.gm-dark [style*="background-image:url"] img,
          html.gm-dark picture img
            { filter: none !important; }
          /* Пока карта не перерисовалась в темной палитре, страницу не показываем — под ней темный фон окна.
             Прозрачность на html не годится: фон корня браузер рисует на весь экран мимо нее. */
          html.gm-dark.gm-wait, html.gm-dark.gm-wait body { background: transparent !important; }
          html.gm-dark.gm-wait body { visibility: hidden !important; }`;
        const style = document.createElement('style');
        style.id = 'gm-dark-style';
        style.textContent = css;
        const attach = () => (document.head || document.documentElement).appendChild(style);
        attach();
        document.addEventListener('DOMContentLoaded', () => { if (!style.isConnected) attach(); });
        // Street View и просмотр фото (@…,3a,75y,… — число перед «a» бывает любым): там Google сам
        // рисует темный интерфейс — не перекрашиваем.
        const street = () => /@[^/]*,[\d.]+a,[\d.]+y/.test(location.href);
        // Спутник — только по типу карты !3m…!1e3. Высота в метрах («…,353m») бывает и у обычной схемы,
        // а голый !1e3 — и у слоев (велодорожки — !5m1!1e3).
        const photo = () => /!3m\d+!1e3/.test(location.href) || inStreet;

        // Темные тени и затемняющие подложки Google (под меню, под фото) после инверсии светятся белым.
        // Перекрашиваем их в белые прямо в стилях страницы — инверсия делает их снова темными.
        // Оригиналы храним, чтобы вернуть в светлой теме.
        const overrides = [];
        // Google дописывает правила в уже загруженные таблицы стилей по ходу работы (карточки, панели),
        // поэтому таблицу перечитываем, когда в ней прибавилось правил, и обрабатываем только новые.
        const counts = new WeakMap();
        const done = new WeakSet();
        const rgba = /rgba?\(\s*(\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\s*\)/g;
        const recolor = {
          'box-shadow': v => v.replace(rgba, (m, r, g, b, a) =>
            +r + +g + +b > 300 ? m : `rgba(255, 255, 255, ${Math.min((a === undefined ? 1 : +a) * 1.6, 0.7)})`),
          // Только полупрозрачные почти черные подложки. Сплошной черный не трогаем — на нем белые значки
          // (кнопки в режиме спутника), легкие подсветки при наведении (прозрачность < 0.3) тоже.
          'background-color': v => v.replace(rgba, (m, r, g, b, a) =>
            +r + +g + +b > 60 || a === undefined || +a < 0.3 || +a >= 1 ? m : `rgba(255, 255, 255, ${a})`),
        };
        recolor['filter'] = v => /drop-shadow/.test(v) ? recolor['box-shadow'](v) : v;
        recolor['text-shadow'] = recolor['box-shadow'];
        // Темный градиент у Google — затемнение поверх фото с белой подписью («Слои» на миниатюре,
        // превью Street View). Такой слой целиком переворачиваем обратно, как фото: градиент и подпись
        // остаются в исходных цветах.
        const darkGradient = v => /gradient/.test(v) && !/url\(/.test(v) &&
          [...v.matchAll(rgba)].some(([, r, g, b, a]) => +r + +g + +b <= 300 && (a === undefined || +a > 0));
        // Цвета поверхностей Google (рамка вокруг панелей, левая колонка) почти белые с легким
        // сине-зеленым оттенком — после инверсии он дает зеленоватый темный. Делаем их нейтрально-серыми
        // той же светлоты.
        const neutral = v => {
          const t = v.trim();
          const m = t.match(/^#([0-9a-f]{6})$/i) || t.match(/^rgb\(\s*(\d+),\s*(\d+),\s*(\d+)\s*\)$/);
          if (!m) return v;
          const c = m.length === 2 ? [0, 2, 4].map(k => parseInt(m[1].slice(k, k + 2), 16)) : [+m[1], +m[2], +m[3]];
          const spread = Math.max(...c) - Math.min(...c);
          if (Math.min(...c) < 225 || spread < 3 || spread > 14) return v;
          const g = Math.round((c[0] + c[1] + c[2]) / 3);
          return `rgb(${g}, ${g}, ${g})`;
        };
        const weaken = v => v
          .replace(/\/\s*([\d.]+)\s*\)/g, (m, a) => `/ ${(+a * 0.4).toFixed(3)})`)          // rgb(from … / 0.08)
          .replace(/(rgba\(\s*\d+,\s*\d+,\s*\d+,\s*)([\d.]+)(\s*\))/g, (m, p, a, e) => p + (+a * 0.4).toFixed(3) + e);
        const collect = rules => {
          for (const rule of rules) {
            if (rule.cssRules) collect(rule.cssRules);          // @media и т.п.
            if (!rule.style || done.has(rule)) continue;
            done.add(rule);
            const props = Object.keys(recolor);
            // Слои состояний Google (наведение, фокус, нажатие) — темная заливка 8–16%, после инверсии
            // светлая плашка. В темной теме ослабляем их в 2,5 раза.
            for (let i = 0; i < rule.style.length; i++) {
              const p = rule.style[i];
              if (/^--[\w-]*state-layer/.test(p)) props.push(p);
              else if (p.startsWith('--') && neutral(rule.style.getPropertyValue(p)) !== rule.style.getPropertyValue(p)) props.push(p);
            }
            for (const prop of props) {
              const v = rule.style.getPropertyValue(prop);
              if (!v || v === 'none') continue;
              const d = (recolor[prop] || (/state-layer/.test(prop) ? weaken : neutral))(v);
              if (d !== v) overrides.push({ style: rule.style, prop, light: v, dark: d,
                                            prio: rule.style.getPropertyPriority(prop) });
            }
          }
        };
        let dark = false;
        // Страница скрыта (gm-wait), пока карта не начала рисоваться темными шейдерами (см. useProgram
        // ниже), — иначе при каждой загрузке мелькает светлая карта и заглушки. Не дольше 3 секунд.
        let revealed = false;
        const reveal = () => {
          if (revealed) return;
          revealed = true;
          setTimeout(() => requestAnimationFrame(() => requestAnimationFrame(() =>
            document.documentElement.classList.remove('gm-wait'))), 50);
        };
        const paint = () => { for (const o of overrides) o.style.setProperty(o.prop, dark ? o.dark : o.light, o.prio); };
        const scan = () => {
          const before = overrides.length;
          for (const sheet of document.styleSheets) {
            if (sheet.ownerNode === style) continue;
            let rules;
            try { rules = sheet.cssRules; } catch (e) { continue; }   // чужой домен — не читается
            if (counts.get(sheet) === rules.length) continue;
            counts.set(sheet, rules.length);
            collect(rules);
          }
          if (overrides.length !== before && dark) paint();
        };

        // Подстраховка для теней из стилей, которые страница прочитать не может (чужой домен):
        // находим элементы, у которых тень все еще темная, и перекрашиваем прямо на элементе.
        // Так же ловим затемнение под меню: это сплошной черный слой во всю страницу с прозрачностью элемента.
        const patched = new Map();
        const patch = (e, prop, value) => {
          const key = e;
          if (!patched.has(key)) patched.set(key, {});
          const saved = patched.get(key);
          if (!(prop in saved)) saved[prop] = e.style.getPropertyValue(prop);
          e.style.setProperty(prop, value, 'important');
        };
        const photoBox = '[style*="background-image: url"], [style*="background-image:url"], .gm-unflip';
        // Разбор одного элемента; вызывается и полным проходом, и для новых узлов сразу при появлении.
        // В Street View и просмотре фото темная тема не выключается (иначе панель и ее «ушко»
        // перекрашиваются на ходу), а фото переворачивается обратно. Плашки поверх фото Google
        // и так рисует темными — их тоже возвращаем в исходные цвета.
        const streetFlipped = new Map();   // элемент → его исходный inline-фон, если мы его меняли
        const visit = (e, big) => {
          if (e.classList.contains('gm-chain') || e.classList.contains('gm-map')) return;   // вне фильтра страницы
          if (e.tagName === 'IFRAME') {
            // Фрейм чужого источника (панели Google: аккаунт, приложения) красит себя сам этим же скриптом —
            // инверсия страницы поверх вернула бы его в светлый. Адрес в атрибуте src бывает about:blank,
            // поэтому определяем по недоступному содержимому.
            let sameOrigin = false;
            try { sameOrigin = !!e.contentDocument; } catch (err) {}
            if (!sameOrigin && !e.classList.contains('gm-unflip')) {
              e.classList.add('gm-unflip');
              patched.set(e, Object.assign(patched.get(e) || {}, { unflip: true }));
            }
            return;
          }
          const cs = getComputedStyle(e);
          const m = cs.backgroundColor.match(/rgba?\((\d+), (\d+), (\d+)(?:, ([\d.]+))?\)/);
          // Полупрозрачный белый — это наша же перекраска темной подложки в стилях: тоже темная плашка.
          const repainted = m && m[1] === '255' && m[2] === '255' && m[3] === '255' && m[4] !== undefined && +m[4] >= 0.3;
          // Перекраска стилей могла прийти уже после переворота плашки — тогда возвращаем темный фон сейчас.
          if (repainted && streetFlipped.has(e) && streetFlipped.get(e) === null) {
            streetFlipped.set(e, e.style.getPropertyValue('background-color'));
            e.style.setProperty('background-color', `rgba(0, 0, 0, ${m[4]})`, 'important');
          }
          // Полупрозрачные темные плашки с белым текстом (кнопки поверх фото) — везде в исходных цветах;
          // в Street View — еще и сплошные темные.
          if ((inStreet || repainted) && !e.closest('.gm-unflip')) {
            if (m && (repainted || +m[1] + +m[2] + +m[3] <= 150) && (m[4] === undefined || +m[4] >= 0.15)) {
              const r = e.getBoundingClientRect();
              if (r.width > 0 && r.width * r.height < big && e.tagName !== 'CANVAS') {
                e.classList.add('gm-unflip');
                // Внутри перевернутой обратно плашки перекраска не нужна — возвращаем темный фон.
                streetFlipped.set(e, repainted ? e.style.getPropertyValue('background-color') : null);
                if (repainted) e.style.setProperty('background-color', `rgba(0, 0, 0, ${m[4]})`, 'important');
                return;
              }
            }
          }
          const box = e.closest(photoBox + ', .gm-reflip');
          const inPhoto = box && box !== e && box.matches(photoBox) && !box.matches('.gm-reflip');
          // Обычный элемент интерфейса со сплошным фоном внутри фото (подсказка «Определяю
          // местоположение» и т.п.) — переворачиваем еще раз, чтобы он стал темным, как все вокруг.
          if (inPhoto && !e.classList.contains('gm-reflip') && /^rgb\(/.test(cs.backgroundColor) &&
              cs.backgroundImage === 'none' && e.tagName !== 'IMG') {
            e.classList.add('gm-reflip');
            patched.set(e, Object.assign(patched.get(e) || {}, { reflip: true }));
            return;
          }
          // Фото, заданное фоном из таблицы стилей (миниатюры «Тип карты» и т.п.), а не в атрибуте style.
          // Маленькие фоновые картинки — значки, их оставляем перевернутыми, чтобы светлели вместе с темой.
          if (!inPhoto && !e.matches(photoBox) && /url\(/.test(cs.backgroundImage)) {
            const r = e.getBoundingClientRect();
            if (r.width >= 40 && r.height >= 40)
              { e.classList.add('gm-unflip'); patched.set(e, Object.assign(patched.get(e) || {}, { unflip: true })); return; }
          }
          if (!inPhoto && darkGradient(cs.backgroundImage) && !e.closest('.gm-unflip'))
            { e.classList.add('gm-unflip'); patched.set(e, Object.assign(patched.get(e) || {}, { unflip: true })); }
          if (!inPhoto) for (const prop of ['box-shadow', 'text-shadow']) {
            const v = cs.getPropertyValue(prop);
            if (!v || v === 'none') continue;
            const d = recolor[prop](v);
            if (d !== v) patch(e, prop, d);
          }
          // Фон-фото переворачивается обратно вместе со всем содержимым: рамка элемента выходит
          // светлой, а внутри наши перекраски не нужны — там и так исходные цвета.
          if (e.matches(photoBox)) {
            const own = cs.boxShadow;                     // своя тень фото тоже перевернута обратно
            if (/rgba\(255, 255, 255, /.test(own)) patch(e, 'box-shadow', own.replace(/rgba\(255, 255, 255, ([\d.]+)\)/g, 'rgba(0, 0, 0, $1)'));
            for (const side of ['top', 'right', 'bottom', 'left']) {
              const c = cs.getPropertyValue(`border-${side}-color`);
              if (`border-${side}-color` in (patched.get(e) || {})) continue;   // уже перевернута
              if (parseFloat(cs.getPropertyValue(`border-${side}-width`)) > 0)
                patch(e, `border-${side}-color`, c.replace(rgba, (m, r, g, b, a) =>
                  `rgba(${255 - r}, ${255 - g}, ${255 - b}, ${a === undefined ? 1 : a})`));
            }
          } else if (inPhoto) {
            for (const prop of ['box-shadow']) {
              const v = cs.getPropertyValue(prop);
              if (/rgba\(255, 255, 255, /.test(v) && !/url\(/.test(v))
                patch(e, prop, v.replace(/rgba\(255, 255, 255, ([\d.]+)\)/g, 'rgba(0, 0, 0, $1)'));
            }
          }
          // Большие подложки под картой (черная, бирюзовая — видны, пока canvas пуст) — в темный на экране.
          const under = cs.backgroundColor.match(/^rgb\((\d+), (\d+), (\d+)\)$/);
          if (under && +under[1] + +under[2] + +under[3] < 600 && +cs.opacity === 1 && e.tagName !== 'CANVAS' && !inPhoto) {
            const rect = e.getBoundingClientRect();
            if (rect.width * rect.height >= big) patch(e, 'background-color', '#fff');
          }
          if (+cs.opacity < 1 && /^rgb\(\s*(\d+),\s*(\d+),\s*(\d+)\)$/.test(cs.backgroundColor)) {
            const [, r, g, b] = cs.backgroundColor.match(/(\d+),\s*(\d+),\s*(\d+)/);
            const rect = e.getBoundingClientRect();
            if (+r + +g + +b <= 60 && rect.width * rect.height >= big) patch(e, 'background-color', '#fff');
          }
        };
        const sweep = () => {
          if (!dark) return;
          const big = innerWidth * innerHeight * 0.3;
          for (const e of document.querySelectorAll('*')) visit(e, big);
        };
        // Новые и измененные элементы разбираем до отрисовки кадра, а не по таймеру, — иначе
        // всплывающие панели (полоска слоев и т.п.) на мгновение мелькают в исходных цветах.
        const pending = new Set();
        let queued = false;
        // Цепочка от холста карты до корня: она остается без фильтра страницы (см. CSS gm-split).
        let mapCanvas = null;
        const markChain = () => {
          if (mapCanvas && mapCanvas.isConnected && mapCanvas.clientWidth * mapCanvas.clientHeight > innerWidth * innerHeight * 0.3) return;
          const c = [...document.querySelectorAll('canvas')]
            .find(c => c.clientWidth * c.clientHeight > innerWidth * innerHeight * 0.3);
          if (!c || window !== window.top) return;
          document.querySelectorAll('.gm-chain, .gm-flt, .gm-wrap').forEach(e => e.classList.remove('gm-chain', 'gm-flt', 'gm-wrap'));
          mapCanvas?.classList.remove('gm-map');
          mapCanvas = c;
          c.classList.add('gm-map');
          for (let e = c.parentElement; e; e = e.parentElement) {
            e.classList.add('gm-chain');
            // фон, который перекраска поставила, пока элемент был под фильтром, больше не нужен
            const saved = patched.get(e);
            if (saved && 'background-color' in saved) {
              saved['background-color'] ? e.style.setProperty('background-color', saved['background-color']) : e.style.removeProperty('background-color');
              delete saved['background-color'];
            }
          }
          document.documentElement.classList.add('gm-split');
          refilter();
        };
        // Кому ставить фильтр (gm-flt): соседям цепочки. Но фильтр делает элемент отдельным слоем, и тогда
        // вложенные панели с z-index уже не поднимаются над картой. Поэтому прозрачные обертки без своего
        // слоя (static, без z-index) не фильтруем, а спускаемся к их детям.
        const wrapper = e => {
          if (e.childElementCount === 0) return false;
          const cs = getComputedStyle(e);
          return cs.position === 'static' && cs.zIndex === 'auto' && cs.opacity === '1' && cs.transform === 'none' &&
            /rgba\(0, 0, 0, 0\)|transparent/.test(cs.backgroundColor) && cs.backgroundImage === 'none' &&
            cs.boxShadow === 'none' && cs.borderTopWidth === '0px' && cs.borderBottomWidth === '0px';
        };
        const target = e => {
          if (e.classList.contains('gm-chain') || e.classList.contains('gm-map') || e.classList.contains('gm-flt')) return;
          if (/^(SCRIPT|STYLE|LINK|META|NOSCRIPT|TEMPLATE)$/.test(e.tagName)) return;
          if (wrapper(e)) { e.classList.add('gm-wrap'); for (const c of e.children) target(c); }
          else e.classList.add('gm-flt');
        };
        const refilter = () => {
          if (!mapCanvas) return;
          for (const chain of document.querySelectorAll('.gm-chain'))
            for (const c of chain.children) target(c);
          for (const w of document.querySelectorAll('.gm-wrap'))
            for (const c of w.children) target(c);
        };
        new MutationObserver(list => {
          markChain();
          if (mapCanvas) for (const m of list)
            if (m.type === 'childList' && m.target.nodeType === 1 && /gm-(chain|wrap)/.test(m.target.className))
              m.addedNodes.forEach(n => n.nodeType === 1 && target(n));
          if (!dark) return;
          if (inStreet && swapping === null) queueMicrotask(() => check());
          for (const m of list) {
            if (m.type === 'childList') m.addedNodes.forEach(n => n.nodeType === 1 && pending.add(n));
            else pending.add(m.target);
          }
          if (queued) return;
          queued = true;
          requestAnimationFrame(() => {
            queued = false;
            const big = innerWidth * innerHeight * 0.3;
            for (const n of pending) {
              if (!n.isConnected) continue;
              visit(n, big);
              for (const e of n.querySelectorAll('*')) visit(e, big);
            }
            pending.clear();
          });
        }).observe(document.documentElement, { childList: true, subtree: true, attributes: true, attributeFilter: ['class'] });
        const unsweep = () => {
          for (const [e, saved] of patched)
            for (const prop in saved)
              if (prop === 'unflip') e.classList.remove('gm-unflip');
              else if (prop === 'reflip') e.classList.remove('gm-reflip');
              else saved[prop] ? e.style.setProperty(prop, saved[prop]) : e.style.removeProperty(prop);
          patched.clear();
        };

        setInterval(() => { document.documentElement.classList.toggle('gm-photo', photo()); scan(); markChain(); }, 400);
        setInterval(sweep, 1500);
        // Меню и карточки открываются по клику — проверяем сразу, чтобы светлое затемнение не мелькало.
        document.addEventListener('click', () => { setTimeout(sweep, 30); setTimeout(sweep, 250); }, true);
        // Темная схема — как в Google Картах на iPhone. Холст карты стоит вне фильтра страницы (gm-split),
        // так что его цвет — ровно цвет на экране. Цвета переводим прямо в шейдерах Google — откуда бы цвет
        // ни пришел (палитра, данные отрисовки, текстура):
        //  — карта (заливки, линии, подписи): цвет из таблицы → свой темный; насыщенное, чего нет в таблице
        //    (маршрут, пробки, транспорт), — как в светлой теме; остальное — как его дала бы инверсия
        //    страницы invert(0.9) + hue-rotate(180°) с холодным оттенком;
        //  — значки и метки: цветное светлее (пастель), белый значок на пине — темный, остальное как есть;
        //  — шейдер, которым Google копирует готовую карту на экран, не трогаем.
        // Включено, пока темная схема; на спутнике и в светлой теме шейдеры работают как у Google.
        // H — invert(0.9) + hue-rotate(180°): цвет на экране = HRI · (0,9 − 0,8 · оттенок · цвет).
        const HR = [[-0.574, 1.430, 0.144], [0.426, 0.430, 0.144], [0.426, 1.430, -0.856]];
        const HRI = (() => {
          const [[a, b, c], [d, e, f], [g, h, i]] = HR, det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
          return [[e * i - f * h, c * h - b * i, b * f - c * e], [f * g - d * i, a * i - c * g, c * d - a * f],
            [d * h - e * g, b * g - a * h, a * e - b * d]].map(row => row.map(v => v / det));
        })();
        const TINT = [226 / 255, 234 / 255, 1];
        // Цвет Google (0…1) → как его показала бы инверсия страницы: 0,1 + 0,8 · (A · цвет + B).
        const A = HRI.map(row => row.map((k, j) => -k * TINT[j]));
        const B = HRI.map(row => (0.9 * (row[0] + row[1] + row[2]) - 0.1) / 0.8);
        // Свои цвета темной схемы — пипеткой с Google Карт на iPhone: светлый цвет Google → цвет на экране.
        const LAND = [21, 37, 64], WATER = [0, 12, 40], PARK = [13, 73, 86],
          URBAN = [60, 73, 125], BUILDING = [33, 46, 77], HOSPITAL = [70, 60, 110],
          MINOR = [49, 56, 77], STREET = [46, 66, 90], ARTERIAL = [59, 80, 104],
          HIGHWAY = [71, 104, 137],
          // крупный масштаб: дома, тротуары, обочины — немногим светлее земли
          BLOCK = [27, 40, 68], SIDEWALK = [31, 44, 72], CURB = [38, 48, 72];
        const palette = [
          [[242, 239, 233], LAND], [[245, 243, 243], LAND], [[252, 250, 248], LAND], [[238, 236, 236], LAND],
          [[243, 246, 255], LAND], [[245, 240, 229], LAND], [[245, 244, 244], LAND], [[237, 236, 236], LAND],
          [[244, 243, 241], LAND],
          [[232, 234, 237], BUILDING], [[248, 240, 222], URBAN], [[247, 236, 207], URBAN], [[252, 232, 230], HOSPITAL],
          [[216, 224, 231], BUILDING], [[221, 223, 227], BUILDING], [[210, 213, 217], BUILDING],
          [[207, 217, 227], MINOR], [[204, 215, 224], MINOR],
          [[199, 208, 215], STREET], [[198, 207, 214], STREET], [[156, 165, 180], STREET], [[136, 147, 165], STREET],
          [[189, 200, 208], ARTERIAL], [[193, 203, 210], ARTERIAL], [[154, 175, 202], ARTERIAL], [[134, 159, 189], ARTERIAL],
          [[107, 133, 174], HIGHWAY],
          // Крупный масштаб (ближе 100 м): здания, тротуары, велодорожки, переходы, обочины.
          [[253, 249, 239], BLOCK], [[248, 249, 250], BLOCK], [[248, 247, 247], BLOCK], [[241, 239, 239], BLOCK],
          [[255, 255, 255], SIDEWALK], [[241, 243, 244], SIDEWALK], [[223, 230, 238], SIDEWALK],
          [[220, 224, 231], CURB], [[219, 224, 232], CURB], [[218, 220, 224], CURB], [[214, 217, 230], CURB],
          [[213, 221, 235], CURB], [[215, 215, 215], CURB], [[207, 210, 214], CURB],
          [[196, 204, 217], STREET], [[191, 204, 218], STREET], [[185, 200, 214], ARTERIAL], [[171, 185, 200], ARTERIAL],
          [[169, 229, 197], PARK], [[127, 205, 176], PARK],
          // Мелкий масштаб и глобус: суша, пустыни, растительность, океан, границы и трассы.
          [[255, 255, 240], LAND], [[255, 250, 230], LAND], [[247, 243, 235], LAND], [[242, 231, 212], LAND],
          [[207, 246, 224], PARK], [[191, 242, 213], PARK], [[175, 239, 202], PARK],
          [[132, 215, 235], WATER],
          [[225, 227, 231], MINOR], [[214, 222, 230], MINOR],
          [[168, 188, 218], ARTERIAL], [[171, 188, 214], ARTERIAL], [[180, 187, 201], ARTERIAL], [[179, 186, 200], ARTERIAL],
          [[143, 160, 188], HIGHWAY], [[123, 143, 185], HIGHWAY], [[103, 122, 170], HIGHWAY],
          [[144, 218, 238], WATER], [[81, 194, 225], WATER], [[171, 235, 255], WATER],
          [[195, 241, 213], PARK], [[194, 240, 212], PARK], [[181, 236, 202], PARK], [[211, 248, 226], PARK],
          [[149, 218, 189], PARK], [[117, 199, 172], PARK],
        ].map(([from, to]) => [from.map(v => v / 255), to.map(v => v / 255)]);
        // Темные тона, которых нет в таблице, после инверсии серые — сдвигаем их в синеву, как на iPhone.
        const COOL = [0.92, 0.96, 1.04];
        const toCanvas = c => {
          const own = palette.find(([f]) => f.every((v, i) => Math.abs(v - c[i]) < 0.006));
          if (own) return own[1];
          // Как gmMap в шейдерах: светлое — по ближайшему оттенку таблицы.
          const lc = 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2];
          if (lc > 0.28) {
            let best = null, bd = 0.12;
            for (const [f, t] of palette) {
              const lf = 0.299 * f[0] + 0.587 * f[1] + 0.114 * f[2];
              const d = Math.hypot(...f.map((v, i) => c[i] / lc - v / lf));
              if (d < bd) { bd = d; best = t.map(v => Math.max(0, Math.min(1, v * Math.max(0.25, Math.min(1.3, lc / lf))))); }
            }
            if (best) return best;
          }
          const d = A.map((row, i) => 0.1 + 0.8 * (row[0] * c[0] + row[1] * c[1] + row[2] * c[2] + B[i]));
          const lum = 0.299 * d[0] + 0.587 * d[1] + 0.114 * d[2];
          const k = 1 - Math.min(1, Math.max(0, (lum - 0.25) / 0.25));
          return d.map((v, i) => Math.max(0, Math.min(1, v * (1 + k * (COOL[i] - 1)))));
        };
        const n = v => v.toFixed(5);
        // gmMap(u, near): точное совпадение с таблицей → свой цвет. Иначе, если near и цвет светлый (заливки),
        // — ближайший по оттенку цвет таблицы, темнее во столько раз, во сколько исходный темнее табличного:
        // так переживают освещение глобуса и затенения рельефа. Остальное — как при инверсии страницы.
        const lum = c => 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2];
        const mapGLSL = 'vec3 gmMap(vec3 u,bool near){' +
          palette.map(([f, t]) => 'if(all(lessThan(abs(u-vec3(' + f.map(n) + ')),vec3(.006))))return vec3(' + t.map(n) + ');').join('') +
          'float lu=dot(u,vec3(.299,.587,.114));' +
          'if(near&&lu>.28){float bd=1.;vec3 bt=vec3(0);float br=1.;vec3 cu=u/lu;' +
          palette.map(([f, t]) => '{float d=length(cu-vec3(' + f.map(v => n(v / lum(f))) + '));if(d<bd){bd=d;bt=vec3(' + t.map(n) +
            ');br=lu/' + n(lum(f)) + ';}}').join('') +
          'if(bd<.12)return clamp(bt*clamp(br,.25,1.3),0.,1.);}' +
          // Насыщенное, чего нет в таблице (маршрут, пробки, линии транспорта), — как у Google в светлой теме.
          'if(near&&max(u.r,max(u.g,u.b))-min(u.r,min(u.g,u.b))>.3)return u;' +
          'vec3 d=.1+.8*vec3(' + A.map((row, i) => 'dot(vec3(' + row.map(n) + '),u)+' + n(B[i])).join(',') + ');' +
          'd*=mix(vec3(1),vec3(' + COOL.map(n) + '),1.-smoothstep(.25,.5,dot(d,vec3(.299,.587,.114))));' +
          'return clamp(d,0.,1.);}';
        const withMain = (src, body) => src.replace(/void\s+main\s*\(\s*\)/, 'void gmMain()') +
          '\nuniform float gmFix;' + body;
        // Карта. Цвет на выходе бывает умножен на прозрачность (заливки, пунктир) — тогда делим и умножаем.
        // Подписи: у текста карты есть обводка, у текста на табличках дорог — нет; его оставляем темным.
        const mapShader = src => {
          const text = src.match(/(\w+)\*=(\w+)\.a;\w+\*=\w+\.a;vec4 \w+=mix\(vec4\(\2\.rgb\*\1,\1\)/);
          const near = text ? 'false' : 'true';                    // подписи — только точно или как при инверсии
          return withMain(src, mapGLSL + 'void main(){gmMain();if(gmFix>.5&&gl_FragColor.a>0.' + (text ? '&&' + text[2] + '.a>.01' : '') +
            '){vec4 c=gl_FragColor;' +
            (/\.rgb\*=\w+|\w+\*\w+\.a\*/.test(src) ? 'gl_FragColor.rgb=gmMap(clamp(c.rgb/c.a,0.,1.),' + near + ')*c.a;}}'
              : 'gl_FragColor.rgb=gmMap(c.rgb,' + near + ');}}'));
        };
        // Космос вокруг глобуса: у Google светло-голубой градиент (темнее у самого глобуса). В темной схеме —
        // почти черный, у края глобуса темно-синее свечение.
        const isSpace = src => /if\(\w+<1\.\)discard;else\{/.test(src) && /length\(/.test(src);
        const spaceShader = src => withMain(src, 'void main(){gmMain();if(gmFix>.5){' +
          'float t=1.-dot(gl_FragColor.rgb,vec3(.299,.587,.114));gl_FragColor.rgb=vec3(.03,.07,.16)*t*1.6;}}');
        // Значки. Белый значок шейдер красит по маске (цветной текстуре) — такие пиксели помечаем gmT.
        const iconShader = src => withMain(src
          .replace(/(if\((?:[^;{()]*?&&)?)(\w+)(\.rgb!=\w+&&\2\.rgb!=\w+\))([^;{]*;)/, '$1$2$3{gmT=gmMask($2);$4}')
          .replace(/void\s+main\s*\(\s*\)/, 'float gmT=0.;float gmMask(vec4 t){vec3 u=t.rgb/max(t.a,.001);' +
            'return smoothstep(.15,.35,max(u.r,max(u.g,u.b))-min(u.r,min(u.g,u.b)));}void main()'),
          'void main(){gmMain();if(gmFix>.5&&gl_FragColor.a>0.){vec4 c=gl_FragColor;' +
          'vec3 u=c.rgb/c.a;float s=max(u.r,max(u.g,u.b))-min(u.r,min(u.g,u.b)),l=dot(u,vec3(.299,.587,.114));' +
          // Цветное — как пастель iPhone: самый яркий канал до максимума, чуть разбавить белым.
          'vec3 n=u/max(max(u.r,max(u.g,u.b)),.001);' +
          'u=mix(u,mix(n,vec3(1),.38),smoothstep(.12,.25,s));' +
          // Желтое (звезды сохраненных мест, таблички дорог) белым не разбавляем — на iPhone оно сочное.
          'u=mix(u,vec3(1.,.84,.21),step(.95,n.r)*step(.6,n.g)*step(n.g,.97)*step(n.b,.3)*smoothstep(.12,.25,s));' +
          'u=mix(u,vec3(.13,.13,.15),gmT*(1.-smoothstep(.1,.2,s))*smoothstep(.55,.75,l));' +
          // Белый полупрозрачный ореол вокруг метки (у «Дома», «Работы») на темной карте не нужен.
          'u=mix(u,vec3(.05,.06,.09),(1.-gmT)*(1.-smoothstep(.1,.2,s))*smoothstep(.55,.75,l)*(1.-smoothstep(.5,.8,c.a)));' +
          'gl_FragColor.rgb=u*c.a;}}');
        const isIcon = src => /\.rgb!=\w+&&\w+\.rgb!=\w+/.test(src);
        // Готовую картинку карты Google копирует на экран отдельным шейдером — его не трогаем.
        const isBlit = src => /gl_FragColor=texture2D\(\w+,\w+\);gl_FragColor\.a=gl_FragColor\.a\*\w+\+\w+;/.test(src);
        // Плашка над маршрутом (время в пути): рамка со стрелкой и тенью. Оставляем как в светлой теме —
        // белая с темным текстом.
        const isCallout = src => /gl_FragCoord/.test(src) && /\*vec4\(1,1,1,\w+\)/.test(src);
        const isMatrix = src => /uniform mat4 \w+;/.test(src) && /texture2D/.test(src);
        // В текстурах с цветовой матрицей — сетка загрузки: светло-серые линии приглушаем к цвету земли.
        const matrixShader = src => withMain(src, 'void main(){gmMain();' +
          'if(gmFix>.5&&gl_FragColor.a>0.){vec4 c=gl_FragColor;vec3 u=c.rgb/c.a;' +
          'float s=max(u.r,max(u.g,u.b))-min(u.r,min(u.g,u.b));' +
          // Плашки (время маршрута) — чисто белые: их не трогаем, сетка — серая.
          'float l=dot(u,vec3(.299,.587,.114));' +
          'u=mix(u,vec3(' + LAND.map(v => n(v / 255)).join(',') + '),.75*(1.-smoothstep(.06,.14,s))*smoothstep(.2,.45,l)*(1.-smoothstep(.9,.97,l)));' +
          'gl_FragColor.rgb=u*c.a;}}');
        const fixedShaders = new WeakSet(), fixedPrograms = new WeakMap(), mapPrograms = new WeakSet();
        const mapShaders = new WeakSet();
        for (const proto of [window.WebGLRenderingContext?.prototype, window.WebGL2RenderingContext?.prototype]) {
          if (!proto) continue;
          const clear = proto.clearColor;
          proto.clearColor = function (r, g, b, a) {
            if (dark && !photo()) [r, g, b] = toCanvas([r, g, b]);
            return clear.call(this, r, g, b, a);
          };
          const source = proto.shaderSource, attach = proto.attachShader, use = proto.useProgram;
          proto.shaderSource = function (sh, src) {
            if (typeof src === 'string' && /gl_FragColor/.test(src) && !isBlit(src) && !isCallout(src) &&
                this.getShaderParameter(sh, this.SHADER_TYPE) === this.FRAGMENT_SHADER) {
              fixedShaders.add(sh);
              if (isMatrix(src)) return source.call(this, sh, matrixShader(src));
              if (isIcon(src)) return source.call(this, sh, iconShader(src));
              if (isSpace(src)) return source.call(this, sh, spaceShader(src));
              mapShaders.add(sh);
              return source.call(this, sh, mapShader(src));
            }
            return source.call(this, sh, src);
          };
          proto.attachShader = function (p, sh) {
            if (fixedShaders.has(sh)) fixedPrograms.set(p, null);
            if (mapShaders.has(sh)) mapPrograms.add(p);
            return attach.call(this, p, sh);
          };
          proto.useProgram = function (p) {
            const r = use.call(this, p);
            if (p && fixedPrograms.has(p)) {
              let loc = fixedPrograms.get(p);
              if (loc === null) { loc = this.getUniformLocation(p, 'gmFix'); fixedPrograms.set(p, loc); }
              const on = dark && !photo();
              if (loc) this.uniform1f(loc, on ? 1 : 0);
              if (on && mapPrograms.has(p)) reveal();          // карта уже рисуется темной
            }
            return r;
          };
        }
        let lastPanorama = 0;
        let panoramaArrived = () => {};
        const stats = window.__gmTextures = { calls: 0, images: 0 };
        // Фото Street View, загруженные в видеокарту, — сигнал входа в Street View.
        const touchUp = (args, sourceIndex) => {
          stats.calls++;
          const src = args[sourceIndex];
          if (src instanceof HTMLImageElement && /streetview|cbk|panoid|ggpht|googleusercontent/.test(src.currentSrc || src.src))
            { lastPanorama = performance.now(); panoramaArrived(); }
          if (src && typeof src === 'object' && 'width' in src && !ArrayBuffer.isView(src)) stats.images++;
          return args;
        };
        for (const proto of [window.WebGLRenderingContext?.prototype, window.WebGL2RenderingContext?.prototype]) {
          if (!proto) continue;
          const tex = proto.texImage2D, sub = proto.texSubImage2D;
          // texImage2D(target, level, internalformat, format, type, source) или (…, width, height, border, format, type, pixels)
          proto.texImage2D = function (...a) { return tex.apply(this, a.length === 6 ? touchUp(a, 5) : a); };
          // texSubImage2D(target, level, x, y, format, type, source)
          proto.texSubImage2D = function (...a) {
            return sub.apply(this, a.length === 7 ? touchUp(a, 6) : a);
          };
        }

        // Встроенные панели Google поверх Карт (карточка аккаунта, меню приложений) — отдельные страницы
        // ogs.google.com во фрейме. Карты показывают их без своей инверсии, а темная тема применяется
        // внутри фрейма этим же скриптом — тогда фото и тени в них тоже в правильных цветах.
        const parentIsMaps = () => { try { return /^\/maps/.test(window.parent.location.pathname); } catch (e) { return false; } };
        const googlePanel = window !== window.top &&
          (/^ogs\.google\./.test(location.hostname) || location.protocol === 'about:' && parentIsMaps());
        const isMaps = googlePanel ||
          /(^|\.)google\.[a-z.]+$/.test(location.hostname) && /^\/maps/.test(location.pathname);
        let wanted = false, inStreet = street();
        const apply = () => {
          dark = wanted && isMaps;
          if (dark && !revealed && !photo() && !googlePanel) {
            document.documentElement.classList.add('gm-wait');
            setTimeout(reveal, 3000);
          } else {
            revealed = true;
            document.documentElement.classList.remove('gm-wait');
          }
          document.documentElement.classList.toggle('gm-dark', dark);
          document.documentElement.classList.toggle('gm-frame', dark && googlePanel);
          document.documentElement.classList.toggle('gm-photo', photo());
          // Вышли из Street View — темные панели просмотрщика больше не исключение.
          if (!inStreet) {
            streetFlipped.forEach((bg, e) => {
              if (bg !== null && e.isConnected) return;     // плашка поверх фото — она нужна и вне Street View
              streetFlipped.delete(e);
              e.classList.remove('gm-unflip');
              if (bg !== null) bg ? e.style.setProperty('background-color', bg) : e.style.removeProperty('background-color');
            });
          }
          scan();
          paint();
          dark ? setTimeout(sweep, 100) : unsweep();
        };
        window.__gmDark = on => { wanted = on; apply(); };
        // Режим меняем сразу при смене адреса, а не по таймеру — иначе мелькает белый фон.
        // Переход в Street View и обратно анимируется в том же canvas, что и карта: на входе адрес
        // меняется раньше, чем появляется фото, на выходе анимация начинается раньше смены адреса.
        // Поэтому на время перехода canvas гасится, а режим меняется под затемнением:
        // на входе — когда Google загрузил фото Street View (или по тайм-ауту), на выходе — когда адрес
        // уже не Street View. Начало выхода ловим по исчезновению кнопок Street View поверх фото.
        let swapping = null;
        const overlaysGone = () => [...streetFlipped.keys()].some(e => !e.isConnected || !e.getClientRects().length);
        const startSwap = target => {
          swapping = target;
          const root = document.documentElement;
          if (dark) root.classList.add('gm-swap');
          const started = performance.now();
          let leftAt = 0;
          const wait = () => {
            if (swapping !== target) return;
            const now = performance.now();
            let ready;
            if (target) {
              // Фото может появиться раньше смены адреса (вход из карточки места) — ждем и того и другого.
              if (!street()) {
                if (now - started < 4000) return setTimeout(wait, 100);
                swapping = null;                   // адрес так и не сменился — это был не вход в Street View
                return root.classList.remove('gm-swap');
              }
              ready = lastPanorama > 0 && now - lastPanorama > 250 || now - started > 2500;
            }
            else {
              if (!street() && !leftAt) leftAt = now;
              if (!leftAt && now - started > 1500) {
                // Кнопка просто спряталась, а из Street View не вышли — отменяем затемнение.
                for (const [e, bg] of streetFlipped) if (!e.isConnected || !e.getClientRects().length) streetFlipped.delete(e);
                swapping = null;
                return root.classList.remove('gm-swap');
              }
              ready = leftAt && now - leftAt > 700;
            }
            if (!ready) return setTimeout(wait, 100);
            swapping = null;
            inStreet = target;
            apply();
            setTimeout(() => root.classList.remove('gm-swap'), 120);
          };
          wait();
        };
        // Фото Street View пришло в видеокарту, а мы еще в режиме карты — значит, начался вход.
        panoramaArrived = () => { if (dark && !inStreet && swapping === null) queueMicrotask(() => startSwap(true)); };
        const check = () => {
          if (swapping !== null) return;
          if (!inStreet && street()) startSwap(true);
          else if (inStreet && (!street() || overlaysGone())) startSwap(false);
        };
        for (const name of ['pushState', 'replaceState']) {
          const orig = history[name];
          history[name] = function (...a) { const r = orig.apply(this, a); check(); return r; };
        }
        addEventListener('popstate', check);
        setInterval(check, 300);
      }
    })();
    """#

    static func userScript(dark: Bool) -> WKUserScript {
        WKUserScript(source: source + "window.__gmDark(\(dark));",
                     injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }

    static func apply(_ dark: Bool, to webView: WKWebView) {
        let content = webView.configuration.userContentController
        content.removeAllUserScripts()
        content.addUserScript(LocationBridge.userScript)
        content.addUserScript(userScript(dark: dark))       // для следующих загрузок
        webView.evaluateJavaScript(source + "window.__gmDark(\(dark));")   // для открытой страницы
        webView.underPageBackgroundColor = dark ? NSColor(white: 0.1, alpha: 1) : .white
    }
}
