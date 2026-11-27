# Chat, mapper and gauges companion

`mudlet-base-ui.xml` is the existing Mudlet Base UI source package used with this Combat V2 setup. It is included unmodified; it is separate from Combat V2's combat panel. No account data, profile settings, chat history or saved panel positions are included.

## Install the missing chat UI

1. If `baseui show` already works, Base UI is installed: do not import a duplicate. If chat remains invisible, check for overlap with the Combat V2 sidebar and report a screenshot before changing layouts.
2. Otherwise, in the SAME Mudlet profile as Combat V2, open Package Manager, Install, and select `ui/mudlet-base-ui.xml` from the extracted complete release.
3. Type `baseui show`. The interface may wait for genuine game chat/character data before it is built. Drag the chat section's header out if you want it floating.
4. Keep the existing Combat V2 loader. Do not install the separate ManualBasher prototype.

The Python Combat V2 installer copies the combat code/assets, but deliberately does not edit your saved profile or silently import/duplicate this companion. Base UI can read native chat, mapper and vitals and may request SCORE for missing gauge information. It does not select combat targets or issue attacks.

This source was copied from the existing working local package, its XML and embedded Lua syntax were checked, and the GitHub artifact hash was verified. Layout/visibility on the home computer has not been visually verified. Existing local Base UI settings can hide the panel or overlap another sidebar; importing a duplicate is not a layout fix.
