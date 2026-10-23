import AppKit
import WebKit

enum Theme: String {
    case system, light, dark

    static var current: Theme {
        get { Theme(rawValue: UserDefaults.standard.string(forKey: "theme") ?? "") ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "theme") }
    }
}

/// Темная тема для веб-версии Google Maps: своей у сайта нет, поэтому страница перекрашивается
/// инверсией, а фото, видео, спутник и Street View инвертируются обратно, чтобы остались в своих цветах.
enum DarkTheme {
    private static let source = #"""
    (() => {
      if (!window.__gmDark) {
        const css = `
          html.gm-dark { filter: invert(0.9) hue-rotate(180deg) !important; background: #fff !important; }
          html.gm-dark.gm-frame { background: transparent !important; }
          html.gm-dark img, html.gm-dark video, html.gm-dark picture,
          html.gm-dark [style*="background-image: url"], html.gm-dark [style*="background-image:url"],
          html.gm-dark.gm-photo canvas, html.gm-dark .gm-unflip
            { filter: invert(1) hue-rotate(180deg) !important; }
          html.gm-dark .gm-unflip img, html.gm-dark .gm-unflip [style*="background-image"]
            { filter: none !important; }
          html.gm-dark .gm-reflip { filter: invert(1) hue-rotate(180deg) !important; }
          html.gm-dark .gm-unflip canvas { filter: none !important; }
          /* Растровые тайлы схемы (слой !1e0!2sm) — заглушка, пока не готова WebGL-карта. Светлые, а
             затемненные — серые, не в цвет темной карты: прячем, под ними уже темная WebGL-карта.
             Миниатюра кнопки «Слои» — тоже тайлы /maps/vt, но другого слоя, ее не трогаем. */
          html.gm-dark:not(.gm-photo) img[src*="/maps/vt"][src*="!1e0!2sm"] { visibility: hidden !important; }
          /* Пустой или перерисовывающийся canvas показывает свой фон и черную подложку Google под картой —
             после инверсии это белая вспышка. В режиме схемы делаем их белыми, то есть темными на экране. */
          html.gm-dark:not(.gm-photo) canvas { background-color: #fff !important; }
          /* переход в Street View и обратно: карта и фото на мгновение в одном canvas — плавно гасим его */
          html.gm-dark.gm-swap canvas { filter: brightness(0) invert(0.9) !important; }
          /* фото внутри фото (черновик и полная картинка) — второй раз не переворачиваем */
          html.gm-dark [style*="background-image: url"] [style*="background-image: url"], html.gm-dark [style*="background-image: url"] [style*="background-image:url"], html.gm-dark [style*="background-image:url"] [style*="background-image: url"], html.gm-dark [style*="background-image:url"] [style*="background-image:url"]
            { filter: none !important; }
          html.gm-dark [style*="background-image: url"] img, html.gm-dark [style*="background-image:url"] img,
          html.gm-dark picture img
            { filter: none !important; }
          #gm-tint { position: absolute; inset: 0; pointer-events: none; display: none;
                     mix-blend-mode: multiply; background: rgb(226, 234, 255); }
          html.gm-dark:not(.gm-photo) #gm-tint { display: block; }
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
        // Страница скрыта (gm-wait), пока Google не загрузил палитру карты (ее перекраска — сигнал) и карта
        // не перерисовалась в темных цветах, — иначе при каждой загрузке мелькает светлая карта.
        // Очистка холста сигналом не годится: ее делают и служебные холсты Google. Не дольше 3 секунд.
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
        new MutationObserver(list => {
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

        // Холодный оттенок схемы, как в темной теме на iPhone: светло-голубой слой в режиме «умножение»
        // поверх карты; после инверсии он дает темно-синий, а яркие значки почти не меняет.
        const tint = document.createElement('div');
        tint.id = 'gm-tint';
        const placeTint = () => {
          const map = [...document.querySelectorAll('canvas')]
            .find(c => c.clientWidth * c.clientHeight > innerWidth * innerHeight * 0.3);
          if (map && tint.previousElementSibling !== map) map.insertAdjacentElement('afterend', tint);
        };

        setInterval(() => { document.documentElement.classList.toggle('gm-photo', photo()); scan(); placeTint(); }, 400);
        setInterval(sweep, 1500);
        // Меню и карточки открываются по клику — проверяем сразу, чтобы светлое затемнение не мелькало.
        document.addEventListener('click', () => { setTimeout(sweep, 30); setTimeout(sweep, 250); }, true);
        // Перекрашиваем только сами Карты: вход в аккаунт и прочие страницы Google темные сами по себе.
        // Пины на карте рисуются через WebGL из бесцветных картинок: светлый силуэт, вокруг —
        // полупрозрачная черная тень, между ними — полупрозрачная серая кромка; цвет пину Google дает
        // при рисовании. После инверсии тень и кромка светятся. В темной теме перекрашиваем все
        // полупрозрачные бесцветные пиксели таких картинок в белые с той же прозрачностью — инверсия
        // делает их темными. Трогаем только картинки, где есть кольцо тени (≥3% слабых черных
        // пикселей), чтобы не задеть текст и значки. Тень усиливаем в 1,6 раза — на темной карте она
        // слабее заметна.
        const shadowless = px => {
          let faint = 0;
          for (let i = 3; i < px.length; i += 4)
            if (px[i] > 0 && px[i] < 80 && px[i - 3] < 40 && px[i - 2] < 40 && px[i - 1] < 40) faint++;
          if (faint < px.length / 4 * 0.03) return false;
          for (let i = 0; i < px.length; i += 4) {
            const a = px[i + 3], r = px[i], g = px[i + 1], b = px[i + 2];
            if (a === 0 || a >= 250 || Math.max(r, g, b) - Math.min(r, g, b) > 12) continue;
            const shade = Math.max(r, g, b) < 70 ? Math.min(Math.round(a * 1.6), 220) : a;
            px[i + 3] = shade;
            px[i] = px[i + 1] = px[i + 2] = 255;
          }
          return true;
        };
        const fromImage = src => {
          const w = src.width || src.naturalWidth || src.videoWidth, h = src.height || src.naturalHeight || src.videoHeight;
          if (!w || !h || w * h > 1024 * 1024 || src instanceof HTMLVideoElement) return null;   // большие — снимки, не значки
          const c = document.createElement('canvas');
          c.width = w; c.height = h;
          const ctx = c.getContext('2d', { willReadFrequently: true });
          if (src instanceof ImageData) ctx.putImageData(src, 0, 0); else ctx.drawImage(src, 0, 0);
          let data;
          try { data = ctx.getImageData(0, 0, w, h); } catch (e) { return null; }      // чужой домен без CORS
          if (!shadowless(data.data)) return null;
          ctx.putImageData(data, 0, 0);
          return c;
        };
        // Палитра темной схемы как в приложении Google Карт на iPhone: светлый цвет Google → цвет на экране.
        // На экран canvas попадает через оттенок (#gm-tint, умножение) и инверсию страницы, поэтому
        // в текстуру пишется прообраз: H⁻¹(цвет) / оттенок, где H — invert(0.9) + hue-rotate(180°).
        const HR = [[-0.574, 1.430, 0.144], [0.426, 0.430, 0.144], [0.426, 1.430, -0.856]];
        const TINT = [226 / 255, 234 / 255, 1];
        const preimage = t => HR.map((row, i) => {
          const u = row[0] * t[0] / 255 + row[1] * t[1] / 255 + row[2] * t[2] / 255;
          return Math.max(0, Math.min(255, Math.round((0.9 - u) / 0.8 / TINT[i] * 255)));
        });
        const palette = [
          [[245, 243, 243], [32, 38, 58]], [[252, 250, 248], [30, 36, 55]], [[238, 236, 236], [36, 42, 64]],
          [[243, 246, 255], [32, 40, 62]], [[242, 239, 233], [32, 38, 58]],                      // земля
          [[232, 234, 237], [42, 48, 72]],                                                         // здания
          [[248, 240, 222], [46, 44, 82]], [[252, 232, 230], [58, 40, 62]],                       // застройка, больницы
          [[216, 224, 231], [62, 72, 102]], [[207, 217, 227], [70, 80, 112]],                      // улицы
          [[199, 208, 215], [74, 84, 116]], [[189, 200, 208], [80, 90, 124]], [[193, 203, 210], [80, 90, 124]],
          [[144, 218, 238], [20, 32, 56]],                                                         // вода
          [[195, 241, 213], [30, 72, 64]], [[181, 236, 202], [34, 82, 70]], [[211, 248, 226], [28, 62, 58]],
          [[117, 199, 172], [36, 96, 80]],                                                         // парки
        ].map(([from, to]) => [from, preimage(to)]);
        const repaint = d => {
          let hit = false;
          for (let i = 0; i < d.length; i += 4)
            for (const [f, t] of palette)
              if (Math.abs(d[i] - f[0]) <= 1 && Math.abs(d[i + 1] - f[1]) <= 1 && Math.abs(d[i + 2] - f[2]) <= 1) {
                d[i] = t[0]; d[i + 1] = t[1]; d[i + 2] = t[2]; hit = true; break;
              }
          return hit;
        };
        // Фон схемы, которым Google очищает canvas, — тоже из палитры.
        const clearFrom = [242, 239, 233], clearTo = preimage([32, 38, 58]).map(v => v / 255);
        for (const proto of [window.WebGLRenderingContext?.prototype, window.WebGL2RenderingContext?.prototype]) {
          if (!proto) continue;
          const clear = proto.clearColor;
          proto.clearColor = function (r, g, b, a) {
            if (dark && !photo() && Math.abs(r * 255 - clearFrom[0]) < 2 && Math.abs(g * 255 - clearFrom[1]) < 2 &&
                Math.abs(b * 255 - clearFrom[2]) < 2) return clear.call(this, clearTo[0], clearTo[1], clearTo[2], a);
            return clear.call(this, r, g, b, a);
          };
        }
        let lastPanorama = 0;
        let panoramaArrived = () => {};
        const stats = window.__gmTextures = { calls: 0, buffers: 0, images: 0, fixed: 0, skipped: 0 };
        const touchUp = (gl, args, sourceIndex, formatIndex, typeIndex, widthIndex = -1) => {
          stats.calls++;
          if (!dark || photo()) return args;
          const src = args[sourceIndex];
          if (!src) return args;
          // Сырые буферы не трогаем: в них бывают не картинки, а данные (узоры, маски), и правка их портит.
          if (ArrayBuffer.isView(src)) {
            // Палитра схемы — узкие RGBA-текстуры (1×N): заменяем цвета заливок на палитру темной карты.
            const w = widthIndex >= 0 ? args[widthIndex] : 0;
            if (src instanceof Uint8Array && args[formatIndex] === gl.RGBA && w > 0 && w <= 4 && src.length % 4 === 0) {
              const copy = new Uint8Array(src);
              if (repaint(copy)) { reveal(); const out = args.slice(); out[sourceIndex] = copy; return out; }
            }
            return args;
          }
          if (typeof src !== 'object' || !('width' in src)) return args;
          if (src instanceof HTMLImageElement && /streetview|cbk|panoid|ggpht|googleusercontent/.test(src.currentSrc || src.src))
            { lastPanorama = performance.now(); panoramaArrived(); }
          stats.images++;
          const fixed = fromImage(src);
          if (!fixed) { stats.skipped++; return args; }
          stats.fixed++;
          const out = args.slice(); out[sourceIndex] = fixed; return out;
        };
        for (const proto of [window.WebGLRenderingContext?.prototype, window.WebGL2RenderingContext?.prototype]) {
          if (!proto) continue;
          const tex = proto.texImage2D, sub = proto.texSubImage2D;
          // texImage2D(target, level, internalformat, format, type, source) или (…, width, height, border, format, type, pixels)
          proto.texImage2D = function (...a) {
            return tex.apply(this, a.length === 6 ? touchUp(this, a, 5, 3, 4) : a.length >= 9 ? touchUp(this, a, 8, 6, 7, 3) : a);
          };
          // texSubImage2D(target, level, x, y, format, type, source) или (…, width, height, format, type, pixels)
          proto.texSubImage2D = function (...a) {
            return sub.apply(this, a.length === 7 ? touchUp(this, a, 6, 4, 5) : a.length >= 9 ? touchUp(this, a, 8, 6, 7, 4) : a);
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
