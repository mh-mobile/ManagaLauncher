# Design System Strategy: Kinetic Ink & Screen-Tone

## 1. Overview & Creative North Star
**The Creative North Star: "The Living Panel"**

This design system transcends static interfaces by treating the digital viewport as a dynamic, evolving manga sequence. We move away from the "app-in-a-grid" aesthetic toward an editorial, high-action experience. By leveraging the visual language of *shonen* and *seinen* manga—intentional asymmetry, kinetic speed lines (*shuchu-sen*), and physical layering—we create a UI that feels like it’s being hand-inked in real-time. 

Traditional grids are broken. We use overlapping elements, speech bubble motifs for micro-interactions, and "Sound Effect" typography to turn functional navigation into a visceral, tactile event.

## 2. Colors
Our palette is rooted in the high-contrast tension of ink on paper, punctuated by "Electric Accents" that denote interactive energy.

### The Palette
*   **Ink & Paper:** The foundation is `surface` (`#0e0e0e`) and `background` (`#0e0e0e`). This deep "Ink Black" creates a void that makes content explode forward.
*   **Electric Accents:** `primary` (`#ff8d8d`) and `secondary` (`#00eefc`) serve as our neon red and blue. These are reserved for high-action states, CTAs, and interactive focus.
*   **Tactile Textures:** Use `tertiary` (`#ffeb92`) for highlighted elements, mimicking the aged yellow of vintage manga magazines.

### The Rules of Engagement
*   **The "No-Line" Rule:** We strictly prohibit 1px solid borders for sectioning. Structural boundaries are defined by background shifts—using `surface_container_low` against `surface`—or via screen-tone texture overlays.
*   **Surface Hierarchy:** Depth is created through nesting. A card in `surface_container_highest` (`#262626`) sitting on a `surface_dim` (`#0e0e0e`) base creates a natural, "stacked" look without the need for dated strokes.
*   **The Glass & Gradient Rule:** For floating headers or navigation bars, use `surface_bright` with a 60% opacity and a `backdrop-filter: blur(20px)`. Main CTAs should utilize a subtle linear gradient from `primary` to `primary_container` to give them a "glowing" ink feel.
*   **Signature Textures:** Incorporate digital screen-tones (halftone patterns) as background fills for non-interactive containers to provide the "soul" of print media.

## 3. Typography
Our typography is the "Voice" of the UI. It must feel loud, urgent, and custom.

*   **Display (Space Grotesk):** Large-scale headers (`display-lg` at 3.5rem) should feel like title splashes. Use heavy weights and tight tracking.
*   **Headline (Space Grotesk):** These carry the "Action." Headlines should be bold and occasionally italicized to imply motion.
*   **Body (Plus Jakarta Sans):** For longer text and descriptions, we use Plus Jakarta Sans to ensure legibility. It provides a clean, modern counter-balance to the aggressive display faces.
*   **Labels & Giseigo/Gitaigo:** Functional labels use `label-md`. For the day selector or high-action buttons, we abandon Latin characters in favor of blocky, Sound-Effect style Kanji (`Giseigo`), treated as primary visual anchors rather than just text.

## 4. Elevation & Depth
In this system, elevation is a narrative tool. We do not use "shadows" in the CSS sense; we use "Tonal Layers" and "Halftone Offsets."

*   **The Layering Principle:** Stack `surface-container` tiers. Place a `surface-container-lowest` card on a `surface-container-low` section to create soft, natural separation.
*   **Ambient Shadows:** When an element must "float" (like a speech-bubble tooltip), use an extra-diffused shadow: `box-shadow: 0 20px 40px rgba(0, 0, 0, 0.4)`. The shadow must feel like a pool of ink, not a grey blur.
*   **The "Ghost Border" Fallback:** If accessibility requires a border, use `outline_variant` at 15% opacity. Never use 100% opaque strokes.
*   **Kinetic Depth:** Use `shuchu-sen` (speed lines) in the background of the highest-elevation elements to draw the eye to the center of the action.

## 5. Components

### The "Sound Effect" Day Selector
Instead of a standard list, days are represented by oversized, blocky Kanji characters that lean and overlap.
*   **Active State:** The Kanji glows with `secondary` (`#00eefc`) and is backed by a "burst" screen-tone.
*   **Inactive State:** `on_surface_variant` with a subtle `outline`.

### Speech Bubble Buttons
Buttons are not rectangles; they are dynamic speech and thought bubbles.
*   **Primary:** Solid `primary` fill, with a "tail" pointing toward the relevant content. Sharp, 0.25rem corners (`DEFAULT` roundedness).
*   **Secondary:** `surface_bright` with a halftone pattern texture and a 2px `outline_variant` at low opacity.

### Panels (Cards)
Cards are treated as Manga Panels.
*   **Style:** No borders. Use `surface_container_highest`. 
*   **Interaction:** On hover, the panel slightly tilts (2-3 degrees) and the background shifts to a `shuchu-sen` speed line pattern.
*   **Spacing:** Use generous vertical white space from the Spacing Scale rather than dividers to separate items in a list.

### Inputs & Fields
*   **Text Fields:** Use a "Rough Ink" style. A thick underline using `primary_dim` instead of a full box.
*   **Error State:** Use `error` (`#ff7351`) with a jagged, "vibrating" animation to mimic visual stress in a manga panel.

## 6. Do's and Don'ts

### Do:
*   **Lean into Asymmetry:** Offset your panels. Let an image bleed out of its container and overlap into the next section.
*   **Use Halftones for Hierarchy:** Use a screen-tone texture on secondary information to push it visually "behind" the primary content.
*   **Treat Typography as Art:** Let headers be massive. If it feels too big, it’s probably just right for a splash page.

### Don't:
*   **Don't Use Dividers:** Never use a 1px line to separate content. Use a shift from `surface_container_low` to `surface_container_high`.
*   **Don't Use Default Shadows:** Avoid the "Material" look. If it doesn't look like an ink smudge or a layered piece of paper, it doesn't belong.
*   **Don't Overuse Motion:** Speed lines provide "static motion." Only use actual CSS animation for high-value interactions like page transitions or "critical hit" button presses.