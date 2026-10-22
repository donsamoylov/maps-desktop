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

    /// Окно отдает сюда каждое событие прокрутки до того, как WebKit его увидит.
    /// true — событие забрали (оно станет перетаскиванием или ждет решения), false — пусть идет как обычно.
    func handleScroll(_ event: NSEvent) -> Bool {
        guard event.hasPreciseScrollingDeltas else { return false }

        // Инерция после свайпа: над картой Google докручивает сам по скорости отпускания.
        if !event.momentumPhase.isEmpty { return target == .map }

        if event.phase.contains(.began) {
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
            if dragging { send(.leftMouseUp) }
            dragging = false
            return
        }
        // Пальцы и карта двигаются вместе; при выключенной «естественной» прокрутке дельты перевернуты.
        let sign: CGFloat = event.isDirectionInvertedFromDevice ? 1 : -1
        offset.x += sign * event.scrollingDeltaX
        offset.y -= sign * event.scrollingDeltaY            // у окна ось y смотрит вверх
        if !dragging {
            guard hypot(offset.x, offset.y) >= 3 else { return }   // короткое касание — не клик по карте
            send(.leftMouseDown, at: origin)
            dragging = true
        }
        send(.leftMouseDragged)
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
        super.sendEvent(event)
    }

    /// Отложенное событие, которое оказалось не над картой, — доставить как обычно.
    func deliver(_ event: NSEvent) {
        delivering = true
        super.sendEvent(event)
        delivering = false
    }
}
