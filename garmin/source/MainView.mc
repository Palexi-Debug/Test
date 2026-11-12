import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Seiten: 0 Jetzt, 1 Heute, 2 Vertretungen
class MainView extends WatchUi.View {

    static var page = 0;
    const PAGES = 3;
    const ACCENT = 0x7986CB;
    const AMBER = 0xFFC107;
    const RED = 0xFF5252;
    const CARD = 0x1B1D2E;
    const TOP = 48;
    const BOTTOM = 34;

    function initialize() {
        View.initialize();
    }

    function hm(m as Number) as String {
        return (m / 60).format("%02d") + ":" + (m % 60).format("%02d");
    }

    // Groesste Schrift, in die der Text noch hineinpasst
    function fit(dc as Dc, text as String, maxW as Number, fonts as Array) as Number {
        for (var i = 0; i < fonts.size(); i++) {
            if (dc.getTextWidthInPixels(text, fonts[i]) <= maxW) {
                return fonts[i];
            }
        }
        return fonts[fonts.size() - 1];
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var titles = ["Jetzt", "Heute", "Vertretungen"];
        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, 10, Graphics.FONT_SMALL, titles[page], Graphics.TEXT_JUSTIFY_CENTER);

        var t = System.getClockTime();
        var now = t.hour * 60 + t.min;

        if (page == 0) {
            drawNow(dc, w, h, now);
        } else if (page == 1) {
            drawToday(dc, w, h, now);
        } else {
            drawSubs(dc, w, h);
        }

        // Fuss: Stand links, Seitenpunkte mittig
        dc.setColor(0x777777, Graphics.COLOR_TRANSPARENT);
        if (DataStore.live && DataStore.syncMin >= 0) {
            dc.drawText(10, h - 24, Graphics.FONT_XTINY, "Stand " + hm(DataStore.syncMin), Graphics.TEXT_JUSTIFY_LEFT);
        } else {
            dc.drawText(10, h - 24, Graphics.FONT_XTINY, "Beispiel", Graphics.TEXT_JUSTIFY_LEFT);
        }
        for (var i = 0; i < PAGES; i++) {
            dc.setColor(i == page ? ACCENT : 0x444444, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(w - 54 + i * 18, h - 14, i == page ? 5 : 3);
        }
    }

    function drawNow(dc as Dc, w as Number, h as Number, now as Number) as Void {
        var cur = null;
        var next = null;
        var after = null;
        for (var i = 0; i < DataStore.lessons.size(); i++) {
            var l = DataStore.lessons[i];
            if (l["s"] <= now && now < l["e"]) { cur = l; }
            else if (l["s"] > now) {
                if (next == null) { next = l; }
                else if (after == null) { after = l; }
            }
        }
        var main = cur != null ? cur : next;
        if (main == null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h / 2, Graphics.FONT_LARGE, "Schule aus", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        var y = TOP + 6;
        dc.setColor(0x999999, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, y, Graphics.FONT_XTINY, cur != null ? "JETZT" : "NAECHSTE STUNDE", Graphics.TEXT_JUSTIFY_CENTER);
        y += Graphics.getFontHeight(Graphics.FONT_XTINY) + 6;

        var nameFont = fit(dc, main["n"], w - 24, [Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL]);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, y, nameFont, main["n"], Graphics.TEXT_JUSTIFY_CENTER);
        y += Graphics.getFontHeight(nameFont) + 8;

        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, y, Graphics.FONT_SMALL, hm(main["s"]) + " - " + hm(main["e"]) + "   " + main["r"], Graphics.TEXT_JUSTIFY_CENTER);
        y += Graphics.getFontHeight(Graphics.FONT_SMALL) + 12;

        // Fortschritt bzw. Countdown
        var barX = 24;
        var barW = w - 48;
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(barX, y, barW, 10, 5);
        var label;
        if (cur != null) {
            var total = cur["e"] - cur["s"];
            var done = now - cur["s"];
            var fw = total > 0 ? (barW * done / total) : barW;
            dc.setColor(AMBER, Graphics.COLOR_TRANSPARENT);
            if (fw > 4) { dc.fillRoundedRectangle(barX, y, fw, 10, 5); }
            label = "noch " + (cur["e"] - now) + " min";
        } else {
            label = "in " + (next["s"] - now) + " min";
        }
        y += 18;
        dc.setColor(AMBER, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, y, Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_CENTER);
        y += Graphics.getFontHeight(Graphics.FONT_SMALL) + 10;

        var follow = cur != null ? next : after;
        if (follow != null && y < h - BOTTOM - 20) {
            dc.setColor(0x999999, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, y, Graphics.FONT_XTINY, "Danach: " + follow["n"] + " " + hm(follow["s"]), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function drawToday(dc as Dc, w as Number, h as Number, now as Number) as Void {
        var rowH = 42;
        var maxRows = (h - BOTTOM - TOP) / rowH;
        var size = DataStore.lessons.size();
        if (size == 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h / 2, Graphics.FONT_MEDIUM, "Keine Stunden", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        var start = 0;
        for (var i = 0; i < size; i++) {
            if (DataStore.lessons[i]["e"] > now) { start = i; break; }
        }
        if (start + maxRows > size) { start = size - maxRows; }
        if (start < 0) { start = 0; }

        var y = TOP;
        for (var i = start; i < size && i < start + maxRows; i++) {
            var l = DataStore.lessons[i];
            var active = l["s"] <= now && now < l["e"];
            dc.setColor(active ? 0x283593 : CARD, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(6, y + 2, w - 12, rowH - 4, 10);
            var cy = y + rowH / 2;
            dc.setColor(active ? Graphics.COLOR_WHITE : 0xAAAAAA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(16, cy, Graphics.FONT_XTINY, hm(l["s"]), Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(AMBER, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w - 16, cy, Graphics.FONT_XTINY, l["r"], Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            var roomW = dc.getTextWidthInPixels(l["r"], Graphics.FONT_XTINY);
            var f = fit(dc, l["n"], w - 96 - roomW - 24, [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY]);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(86, cy, f, l["n"], Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            y += rowH;
        }
        if (start + maxRows < size) {
            dc.setColor(0x777777, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h - 24, Graphics.FONT_XTINY, "+" + (size - start - maxRows), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function drawSubs(dc as Dc, w as Number, h as Number) as Void {
        var size = DataStore.subs.size();
        if (size == 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h / 2, Graphics.FONT_MEDIUM, "Keine Vertretungen", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        var cardH = 70;
        var maxRows = (h - BOTTOM - TOP) / cardH;
        var y = TOP;
        for (var i = 0; i < size && i < maxRows; i++) {
            var s = DataStore.subs[i];
            dc.setColor(CARD, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(6, y + 2, w - 12, cardH - 6, 12);

            var art = s["art"];
            var isOut = art.find("ntfall") != null || art.find("Frei") != null;
            // farbiger Streifen links
            dc.setColor(isOut ? RED : AMBER, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(6, y + 2, 6, cardH - 6, 3);

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            var head = s["std"] + ". Std  " + s["fach"];
            var f = fit(dc, head, w - 44, [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY]);
            dc.drawText(22, y + 8, f, head, Graphics.TEXT_JUSTIFY_LEFT);

            var y2 = y + 8 + Graphics.getFontHeight(f) + 4;
            dc.setColor(isOut ? RED : AMBER, Graphics.COLOR_TRANSPARENT);
            dc.drawText(22, y2, Graphics.FONT_XTINY, art, Graphics.TEXT_JUSTIFY_LEFT);
            var x = 22 + dc.getTextWidthInPixels(art, Graphics.FONT_XTINY) + 12;
            var info = "";
            if (!s["vertr"].equals("")) { info = s["vertr"]; }
            if (!s["raum"].equals("")) { info = info + (info.equals("") ? "" : "  ") + s["raum"]; }
            dc.setColor(0xBBBBBB, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y2, Graphics.FONT_XTINY, info, Graphics.TEXT_JUSTIFY_LEFT);
            y += cardH;
        }
        if (size > maxRows) {
            dc.setColor(0x777777, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h - 24, Graphics.FONT_XTINY, "+" + (size - maxRows) + " weitere", Graphics.TEXT_JUSTIFY_CENTER);
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
