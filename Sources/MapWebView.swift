import AppKit
import WebKit

/// Свайп двумя пальцами по карте двигает ее, как в приложении Google Карт на телефоне.
/// Сайт Google на прокрутку масштабирует карту, поэтому трекпадный свайп над картой
/// превращается здесь в перетаскивание мышью. Над панелями свайп остается прокруткой,
/// колесико обычной мыши (без точных дельт) — масштабом, как задумал Google.
final class MapWebView: WKWebView {
    private enum Target { case undecided, map, page }

    private var target = Target.page
    private var pending: [NSEvent] = []
    private var dragging = false
    private var origin = NSPoint.zero       // где начат жест, в координатах окна
    private var offset = NSPoint.zero       // накопленный сдвиг пальцев
    private var release: DispatchWorkItem?  // отпустить «мышь», если инерции после свайпа не будет
    private var upPending = false           // «мышь» стоит на месте и вот-вот отпустится

    /// Окно отдает сюда каждое событие прокрутки до того, как WebKit его увидит.
    /// true — событие забрали (оно станет перетаскиванием или ждет решения), false — пусть идет как обычно.
    func handleScroll(_ event: NSEvent) -> Bool {
        guard event.hasPreciseScrollingDeltas else { return false }

        // Инерция после свайпа — от macOS, как в нативных приложениях: карта докручивается тем же
        // перетаскиванием, «мышь» отпускается, когда инерция кончилась. Своя инерция Google на отпускании
        // с ней не совпадала: новый свайп, начатый во время нее, дергал карту назад.
        if !event.momentumPhase.isEmpty {
            guard target == .map else { return false }
            coast(event)
            return true
        }

        if event.phase.contains(.began) {
            // Пальцы легли, пока карта докручивалась: «ловим» ее — то же перетаскивание продолжается.
            if dragging || upPending {
                release?.cancel()
                release = nil
                upPending = false
                dragging = true
                target = .map
                drag(event)
                return true
            }
            target = .undecided
            pending = [event]
            dragging = false
            origin = event.locationInWindow
            offset = .zero
            isOverMap(event.locationInWindow) { [weak self] overMap in
                guard let self, self.target == .undecided else { return }
                self.target = overMap ? .map : .page
                let queued = self.pending
                self.pending = []
                for e in queued {
                    if self.target == .map { self.drag(e) } else { (self.window as? GestureWindow)?.deliver(e) }
                }
            }
            return true
        }

        switch target {
        case .undecided: pending.append(event); return true
        case .map: drag(event); return true
        case .page: return false
        }
    }

    private func drag(_ event: NSEvent) {
        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            // Инерция, если будет, начнется сразу; не началась — отпускаем.
            guard dragging else { return }
            let work = DispatchWorkItem { [weak self] in self?.finishDrag() }
            release = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
            return
        }
        move(event)
        if !dragging {
            guard hypot(offset.x, offset.y) >= 3 else { return }   // короткое касание — не клик по карте
            send(.leftMouseDown, at: origin)
            dragging = true
        }
        send(.leftMouseDragged)
    }

    /// Пальцы и карта двигаются вместе; при выключенной «естественной» прокрутке дельты перевернуты.
    private func move(_ event: NSEvent) {
        let sign: CGFloat = event.isDirectionInvertedFromDevice ? 1 : -1
        offset.x += sign * event.scrollingDeltaX
        offset.y -= sign * event.scrollingDeltaY            // у окна ось y смотрит вверх
    }

    private func coast(_ event: NSEvent) {
        release?.cancel()
        release = nil
        guard dragging else { return }
        if event.momentumPhase.contains(.ended) || event.momentumPhase.contains(.cancelled) {
            finishDrag()
            return
        }
        move(event)
        send(.leftMouseDragged)
    }

    /// Отпустить «мышь», сначала постояв на месте, — чтобы Google не добавил своей инерции.
    private func finishDrag() {
        release?.cancel()
        release = nil
        guard dragging else { return }
        dragging = false
        send(.leftMouseDragged)
        upPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            guard let self, self.upPending else { return }
            self.upPending = false
            self.send(.leftMouseUp)
        }
    }

    private func send(_ type: NSEvent.EventType, at point: NSPoint? = nil) {
        guard let window,
              let event = NSEvent.mouseEvent(
                  with: type, location: point ?? NSPoint(x: origin.x + offset.x, y: origin.y + offset.y),
                  modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                  windowNumber: window.windowNumber, context: nil, eventNumber: 0,
                  clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1)
        else { return }
        switch type {
        case .leftMouseDown: mouseDown(with: event)
        case .leftMouseDragged: mouseDragged(with: event)
        default: mouseUp(with: event)
        }
    }

    // MARK: Щипок

    private var pinchTarget = Target.page
    private var lastPinch: TimeInterval = 0

    /// Щипок над картой. Chrome передает его сайтам как прокрутку с Ctrl (масштаб — в дельте), и
    /// Google Карты, считая нас Chrome, масштабируют по ней. Делаем так же, с небольшим ускорением
    /// на быстром щипке.
    func handleMagnify(_ event: NSEvent) -> Bool {
        if event.phase.contains(.began) {
            pinchTarget = .undecided
            lastPinch = event.timestamp
            isOverMap(event.locationInWindow) { [weak self] overMap in
                guard let self, self.pinchTarget == .undecided else { return }
                self.pinchTarget = overMap ? .map : .page
            }
            return true
        }
        guard pinchTarget != .page else { return false }
        guard !event.phase.contains(.ended), !event.phase.contains(.cancelled) else { return true }
        let dt = max(event.timestamp - lastPinch, 1.0 / 120)
        lastPinch = event.timestamp
        guard pinchTarget == .map, event.magnification != 0 else { return true }

        // Шаг от скорости растет не больше чем в 2,5 раза. Сила — скрытая настройка PinchGain.
        let gain = UserDefaults.standard.object(forKey: "PinchGain") as? Double ?? 1.2
        let speed = abs(event.magnification) / dt
        let factor = gain * (1 + min(speed * 0.15, 1.5))
        let delta = 100 * log(1 + event.magnification) * factor
        scrollWithControl(delta: delta, at: event.locationInWindow)
        return true
    }

    private func scrollWithControl(delta: Double, at windowPoint: NSPoint) {
        guard let cg = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
                               wheel1: Int32(delta.rounded()), wheel2: 0, wheel3: 0)
        else { return }
        // Событие без окна: его locationInWindow — это экранная точка. Ставим точку так, чтобы она
        // совпала с местом щипка в окне, и отдаем событие прямо WebKit.
        let primaryHeight = NSScreen.screens.first?.frame.maxY ?? 0
        cg.location = CGPoint(x: windowPoint.x, y: primaryHeight - windowPoint.y)
        cg.flags = .maskControl
        cg.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        guard let wheel = NSEvent(cgEvent: cg) else { return }
        scrollWheel(with: wheel)
    }

    /// Карта у Google — большой canvas; все, что над ним в другом слое (панели, поиск, кнопки), — не карта.
    private func isOverMap(_ windowPoint: NSPoint, completion: @escaping (Bool) -> Void) {
        let p = convert(windowPoint, from: nil)
        let x = p.x / pageZoom
        let y = (isFlipped ? p.y : bounds.height - p.y) / pageZoom
        let js = """
            (() => {
              const el = document.elementFromPoint(\(x), \(y));
              if (!el) return false;
              const big = [...document.querySelectorAll('canvas')]
                .filter(c => c.clientWidth * c.clientHeight > innerWidth * innerHeight * 0.3);
              return big.some(c => c === el || c.parentElement.contains(el));
            })()
            """
        evaluateJavaScript(js) { result, _ in completion(result as? Bool ?? false) }
    }
}

/// Окно, которое показывает жесты прокрутки карте раньше WebKit.
final class GestureWindow: NSWindow {
    weak var mapView: MapWebView?
    private var delivering = false

    override func sendEvent(_ event: NSEvent) {
        if event.type == .scrollWheel, !delivering, let mapView, mapView.handleScroll(event) { return }
        if event.type == .magnify, let mapView, mapView.handleMagnify(event) { return }
        super.sendEvent(event)
    }

    /// Отложенное событие, которое оказалось не над картой, — доставить как обычно.
    func deliver(_ event: NSEvent) {
        delivering = true
        super.sendEvent(event)
        delivering = false
    }
}
