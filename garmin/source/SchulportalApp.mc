import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.WatchUi;

// Schulportal fuer Garmin Venu Sq 2 (rechteckig, 320x360) - TESTVERSION.
// Zeigt zunaechst Beispieldaten. Echte Daten sollen spaeter vom Handy
// (Schulportal-App) per Connect-IQ-Nachricht kommen.
class SchulportalApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        Communications.registerForPhoneAppMessages(method(:onPhoneMessage));
    }

    function onPhoneMessage(msg as Communications.PhoneAppMessage) as Void {
        var data = msg.data;
        if (data instanceof Dictionary) {
            DataStore.update(data);
            WatchUi.requestUpdate();
        }
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new MainView(), new MainDelegate()];
    }
}
