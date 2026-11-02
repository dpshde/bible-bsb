using Toybox.Lang;

//! Prevents button BehaviorDelegate handlers from re-running an action already
//! handled by onTap / onSwipe / onHold on touch-capable devices.
module TouchGuard {
    var _suppressSelect as Lang.Boolean = false;
    var _suppressPage as Lang.Boolean = false;
    var _suppressBack as Lang.Boolean = false;

    function markSelect() as Void {
        _suppressSelect = true;
    }

    function markPage() as Void {
        _suppressPage = true;
    }

    function markBack() as Void {
        _suppressBack = true;
    }

    //! Returns true if this select should be ignored (touch already handled it).
    function consumeSelect() as Lang.Boolean {
        if (_suppressSelect) {
            _suppressSelect = false;
            return true;
        }
        return false;
    }

    function consumePage() as Lang.Boolean {
        if (_suppressPage) {
            _suppressPage = false;
            return true;
        }
        return false;
    }

    function consumeBack() as Lang.Boolean {
        if (_suppressBack) {
            _suppressBack = false;
            return true;
        }
        return false;
    }
}
