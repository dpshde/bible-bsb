using Toybox.Lang;

//! Taps / Enter / hold that arrive within SETTLE_MS of a screen appearing were aimed at the
//! screen before it (mash during a chapter-open flash): ignore them so they cannot open the
//! reader menu or toggle a setting. Scroll keys are never gated (no lost scrolling).
module InputGate {
    // POKE: INPUT_SETTLE_MS
    const SETTLE_MS = 400;

    function accept(shownAt as Lang.Number, now as Lang.Number) as Lang.Boolean {
        return now - shownAt >= SETTLE_MS;
    }
}
