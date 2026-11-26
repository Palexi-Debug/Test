import Toybox.Application;
import Toybox.Lang;
import Toybox.System;

// Aktuelle Daten. s/e = Start/Ende in Minuten seit 0 Uhr.
module DataStore {
    // Muss zur version in manifest.xml passen.
    const VERSION = "0.1.4";

    var live = false;
    var syncMin = -1;
    var week = "";
    var msgCount = 0;

    var lessons = [
        {"s" => 480, "e" => 525, "n" => "Mathematik", "r" => "R 214"},
        {"s" => 525, "e" => 570, "n" => "Deutsch", "r" => "R 108"},
        {"s" => 595, "e" => 640, "n" => "Biologie", "r" => "N 02"},
        {"s" => 640, "e" => 685, "n" => "Englisch", "r" => "R 110"},
        {"s" => 705, "e" => 750, "n" => "Geschichte", "r" => "R 215"},
        {"s" => 750, "e" => 795, "n" => "Sport", "r" => "Halle"}
    ];

    var subs = [
        {"std" => "3", "fach" => "Biologie", "art" => "Vertretung", "vertr" => "MLR", "raum" => "N 02"},
        {"std" => "5", "fach" => "Geschichte", "art" => "Entfall", "vertr" => "", "raum" => ""}
    ];

    function num(v, def as Number) as Number {
        return (v instanceof Number) ? v : def;
    }

    function str(v) as String {
        return (v instanceof String) ? v : "";
    }

    // Kaputte Eintraege aussortieren, damit die Anzeige nie abstuerzt.
    function cleanLessons(a as Array) as Array {
        var out = [];
        for (var i = 0; i < a.size(); i++) {
            var l = a[i];
            if (l instanceof Dictionary && (l["s"] instanceof Number) && (l["e"] instanceof Number)) {
                out.add({"s" => l["s"], "e" => l["e"], "n" => str(l["n"]), "r" => str(l["r"])});
            }
        }
        return out;
    }

    function cleanSubs(a as Array) as Array {
        var out = [];
        for (var i = 0; i < a.size(); i++) {
            var s = a[i];
            if (s instanceof Dictionary) {
                out.add({"std" => str(s["std"]), "fach" => str(s["fach"]), "art" => str(s["art"]),
                         "vertr" => str(s["vertr"]), "raum" => str(s["raum"])});
            }
        }
        return out;
    }

    function update(d as Dictionary) as Void {
        msgCount += 1;
        var t = System.getClockTime();
        syncMin = t.hour * 60 + t.min;
        var l = d["lessons"];
        if (l instanceof Array) {
            lessons = cleanLessons(l);
            live = true;
        }
        var s = d["subs"];
        if (s instanceof Array) {
            subs = cleanSubs(s);
            live = true;
        }
        var wk = d["wk"];
        if (wk instanceof String) {
            week = wk;
        }
        save();
    }

    // Daten ueberleben das Schliessen der App (kein erneutes Senden noetig).
    function save() as Void {
        try {
            Application.Storage.setValue("lessons", lessons);
            Application.Storage.setValue("subs", subs);
            Application.Storage.setValue("syncMin", syncMin);
            Application.Storage.setValue("week", week);
        } catch (e) {
        }
    }

    function load() as Void {
        try {
            var l = Application.Storage.getValue("lessons");
            var s = Application.Storage.getValue("subs");
            if (l instanceof Array && s instanceof Array) {
                lessons = cleanLessons(l);
                subs = cleanSubs(s);
                syncMin = num(Application.Storage.getValue("syncMin"), -1);
                var wk = Application.Storage.getValue("week");
                if (wk instanceof String) { week = wk; }
                live = true;
            }
        } catch (e) {
        }
    }
}
