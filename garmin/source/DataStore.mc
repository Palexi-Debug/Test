import Toybox.Lang;

// Aktuelle Daten. s/e = Start/Ende in Minuten seit 0 Uhr.
module DataStore {
    var live = false;

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

    function update(d as Dictionary) as Void {
        var l = d["lessons"];
        if (l instanceof Array) {
            lessons = l;
            live = true;
        }
        var s = d["subs"];
        if (s instanceof Array) {
            subs = s;
            live = true;
        }
    }
}
