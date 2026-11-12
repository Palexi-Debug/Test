import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Seiten: 0 Jetzt, 1 Heute, 2 Vertretungen
class MainView extends WatchUi.View {

    static var page = 0;
    const PAGES = 3;
    const ACCENT = 0x5C6BC0;
    const AMBER = 0xFFC107;

    function initialize() {
        View.initialize();
    }

    function hm(m as Number) as String {
        return (m / 60).format("%02d") + ":" + (m % 60).format("%02d");
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var titles = ["Jetzt", "Heute", "Vertretungen"];
        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 14, Graphics.FONT_SMALL, titles[page], Graphics.TEXT_JUSTIFY_CENTER);
        if (DataStore.live) {
            dc.setColor(AMBER, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w - 18, 26, 5);
        }

        var t = System.getClockTime();
        var now = t.hour * 60 + t.min;

        if (page == 0) {
            drawNow(dc, w, h, now);
        } else if (page == 1) {
            drawToday(dc, w, h, now);
        } else {
            drawSubs(dc, w, h);
        }

        // Seitenpunkte
        for (var i = 0; i < PAGES; i++) {
            dc.setColor(i == page ? ACCENT : 0x444444, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w / 2 - 20 + i * 20, h - 14, i == page ? 5 : 3);
        }
    }

    function drawNow(dc as Dc, w as Number, h as Number, now as Number) as Void {
        var cur = null;
        var next = null;
        for (var i = 0; i < DataStore.lessons.size(); i++) {
            var l = DataStore.lessons[i];
            if (l["s"] <= now && now < l["e"]) { cur = l; }
            if (l["s"] > now && next == null) { next = l; }
        }
        var l2 = cur != null ? cur : next;
        if (l2 == null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h / 2, Graphics.FONT_LARGE, "Schule aus", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 90, Graphics.FONT_XTINY, cur != null ? "JETZT" : "NAECHSTE", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 125, Graphics.FONT_LARGE, l2["n"], Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 185, Graphics.FONT_SMALL, hm(l2["s"]) + " - " + hm(l2["e"]) + "  " + l2["r"], Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(AMBER, Graphics.COLOR_TRANSPARENT);
        var mins = cur != null ? (cur["e"] - now) : (l2["s"] - now);
        dc.drawText(w / 2, 225, Graphics.FONT_SMALL, (cur != null ? "noch " : "in ") + mins + " min", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawToday(dc as Dc, w as Number, h as Number, now as Number) as Void {
        var y = 52;
        for (var i = 0; i < DataStore.lessons.size() && y < h - 40; i++) {
            var l = DataStore.lessons[i];
            var active = l["s"] <= now && now < l["e"];
            if (active) {
                dc.setColor(0x283593, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(8, y - 2, w - 16, 44, 10);
            }
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(16, y, Graphics.FONT_XTINY, hm(l["s"]) + "  " + l["r"], Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(16, y + 14, Graphics.FONT_TINY, l["n"], Graphics.TEXT_JUSTIFY_LEFT);
            y += 48;
        }
    }

    function drawSubs(dc as Dc, w as Number, h as Number) as Void {
        if (DataStore.subs.size() == 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h / 2, Graphics.FONT_MEDIUM, "Keine Vertretungen", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        var y = 56;
        for (var i = 0; i < DataStore.subs.size() && y < h - 60; i++) {
            var s = DataStore.subs[i];
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(16, y, Graphics.FONT_TINY, "Std " + s["std"] + " " + s["fach"], Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(AMBER, Graphics.COLOR_TRANSPARENT);
            var info = s["art"];
            if (!s["vertr"].equals("")) { info = info + "  " + s["vertr"]; }
            if (!s["raum"].equals("")) { info = info + "  " + s["raum"]; }
            dc.drawText(16, y + 26, Graphics.FONT_XTINY, info, Graphics.TEXT_JUSTIFY_LEFT);
            y += 62;
        }
    }
}

class MainDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onNextPage() as Boolean {
        MainView.page = (MainView.page + 1) % 3;
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Boolean {
        MainView.page = (MainView.page + 2) % 3;
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect() as Boolean {
        return onNextPage();
    }
}
