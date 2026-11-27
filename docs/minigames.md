# Optional Poker and Farkle

This adapts the supplied friend script to Combat V2's existing native text callback. No Sys framework or extra import is required. It starts OFF after loading/reloading/disconnecting, and `cv2 off` disables both helpers.

    cv2 games on
    cv2 games off
    cv2 games status

Or enable only one: `cv2 poker on|off|status`, `cv2 farkle on|off|status`.

While enabled and combat OFF:

- The four exact Poker turn prompts send the original `poker check` / `poker call`. It never chooses raise, bet, fold or all-in.
- A matching single-word player-seat announcement triggers `poker buyin for 200` once. This spends 200 IN-GAME GOLD. The remaining-gold leave receipt clears the table bookkeeping, including while the helper is off. Changing toggles does not reset a requested buy-in; a failed/unknown send is not blindly retried.
- The exact Farkle turn prompt sends `farkle done` (intentionally retained from the friend script, NOT changed to FARKLE ROLL).
- The supplied Farkle invitation pattern sends `PLAY FARKLE`.

Other active combat modes, travel/walking and pending known action owners pause game replies. Nothing raises combat mode, moves, cures, changes FIRSTAID or rewrites input. Controls are session-only, not saved opt-ins. Reload disarms but retains current table/requested-buy-in bookkeeping; disconnect clears it. Neither OFF nor reload cancels a command the server already received or leaves a table automatically.

The original regex name scope is retained (one word, including underscores). Prompt changes or line wrapping not represented by the supplied strings may not match. There is no table-ID, bankroll or pot-limit protocol in the supplied script: Poker CALL can spend additional in-game gold. Enable deliberately and stay present. Tests use fake sends only; no actual Poker/Farkle actions were performed during development.
