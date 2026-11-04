using Toybox.Lang;

//! Personal-build sync key override (0.9.7). Every committed build compiles this stub: no key.
//! A personal sideload build replaces it (annotation `keystub` excluded) with a PersonalSync
//! module generated OUTSIDE the repo by tools/make_personal_sync.sh from $SELAH_VAULT_SYNC_KEY;
//! HwSync uses that key only while Garmin Connect's "Sync key" setting is blank.
(:keystub)
module PersonalSync {
    function key() as Lang.String or Null {
        return null;
    }
}
