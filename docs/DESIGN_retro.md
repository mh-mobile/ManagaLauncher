# Design System Strategy: The Gekiga Editorial

## 1. Overview & Creative North Star
**The Creative North Star: "The Analog Serial"**

This design system rejects the clinical perfection of modern SaaS interfaces in favor of the soulful, tactile imperfection of 1970s and 80s manga. We are not building a website; we are composing a digital *tankōbon*. The aesthetic is rooted in the "Gekiga" movement—dramatic, cinematic, and gritty. 

To break the "template" look, we move away from symmetrical grids. Layouts should feel like a dynamic manga page: intentional overlap, varying panel widths (inspired by 4-koma structures), and "bleeding" elements that break out of their containers. We trade the sterile "digital" look for the warmth of aged paper and the weight of physical ink.

---

## 2. Colors & Tactility
The palette is a curated selection of "weathered" tones that mimic the chemical aging of paper and the saturation of vintage print.

### The Palette
- **The Ground:** `surface` (#fcf9f2) acts as our aged paper base. It is never pure white.
- **The Ink:** `on_tertiary_fixed` (#1a1b25) is our "Vintage Ink Blue." Use this for text and structural "ink" lines.
- **The Accents:** `primary_container` (#ff6b35 / Retro Orange) and `secondary_container` (#ffd167 / Mustard Yellow) are used sparingly to highlight narrative peaks—mimicking the limited color pages of a special edition manga volume.

### Rules of Engagement
- **The "No-Line" Rule:** Standard 1px UI borders are strictly prohibited. Sectioning must be achieved through background shifts (e.g., a `surface_container_low` block resting on a `surface` background). 
- **Surface Hierarchy & Nesting:** Treat the UI as stacked sheets of newsprint. Use `surface_container_lowest` for the most prominent "hero" panels to create a soft, natural lift. For deeper "inset" panels, use `surface_dim`.
- **The "Ink Bleed" Gradient:** For primary CTAs, use a subtle linear gradient from `primary` (#ab3500) to `primary_container` (#ff6b35) to simulate the way heavy ink pools and thins on textured paper.
- **Signature Textures:** Overlay a global "Halftone" pattern (Ben-Day dots) at 3% opacity over `surface_variant` areas to provide that quintessential gritty, printed feel.

---

## 3. Typography
Our typography is a tension between the "Raw Narrative" and the "Editorial Commentary."

- **Display & Headlines (Epilogue):** Set with high tracking and bold weights. This is our "Brush-Style" surrogate. It should feel loud and cinematic. In hero sections, use `display-lg` with a slight `-2deg` rotation to mimic hand-lettered sound effects (SFX).
- **Titles & Body (Public Sans):** A clean, vintage-feeling sans-serif that ensures readability against the textured backgrounds. It provides the "typeset" look found in translated manga bubbles.
- **Labels (Space Grotesk):** Used for technical metadata. These should feel like the small print found on the spine of a vintage magazine.

---

## 4. Elevation & Depth
In this system, depth is not a product of light and shadow, but of **Tonal Layering** and physical stacking.

- **The Layering Principle:** Avoid CSS shadows where possible. Instead, use a "double-offset" panel: a `surface_container_high` card with a 2px offset "ghost" of `on_surface_variant` behind it to simulate a physical paper cutout.
- **Ambient Shadows:** If a floating element (like a modal) is required, use a high-spread, low-opacity (4%) shadow tinted with `tertiary` (#5d5d69) to keep the "gritty" tone.
- **The "Ghost Border":** For interactive states, use `outline_variant` at 20% opacity. It should look like a faint pencil sketch before the ink is applied.
- **Manga Glassmorphism:** For top navigation or floating speech bubbles, use `surface` at 85% opacity with a heavy `backdrop-blur`. This simulates the "tracing paper" used by mangaka.

---

## 5. Components

### Buttons (Vintage Arcade/Label Style)
- **Primary:** High-contrast `primary_container` with a bold `on_primary_container` label. Use `radius-md` (0.375rem). The hover state should increase the "Ink Bleed" gradient intensity.
- **Tertiary:** No background. Use `label-md` in all-caps with a `primary` underline that looks hand-drawn.

### Panels & Cards (Manga Frames)
- Forbid divider lines. Separate content using the Spacing Scale (minimum 24px) or a shift to `surface_container_low`. 
- Panels should use slightly asymmetrical rounded corners (e.g., top-left: `xl`, bottom-right: `md`) to mimic the hand-cut nature of old gekiga panels.

### Speech Bubbles (The Narrative Tool)
- A bespoke component for tooltips and callouts. Use a `surface_container_lowest` background with a small, hand-drawn vector "tail" (pointer).
- Ensure the text has generous padding to mimic the "white space" of manga dialogue.

### Input Fields
- Avoid the "box" look. Use a `surface_dim` bottom-bar only, with a `label-sm` floating above it. 
- Error states use `error` (#ba1a1a) with a subtle halftone pattern fill to make the error feel like a dramatic "red ink" correction.

---

## 6. Do’s and Don’ts

### Do:
- **Embrace Asymmetry:** Align text to the left but offset images to the right, breaking the container edge.
- **Use Halftones:** Apply Ben-Day dot patterns to `secondary_container` elements to add "mechanical" soul.
- **Think in Panels:** Treat every page as a vertical 4-koma strip.

### Don’t:
- **No 1px Solid Black Borders:** It kills the "aged paper" vibe. Use background tonal shifts or "ghost borders" instead.
- **No Perfect Grids:** Avoid standard 12-column layouts. Use staggered "gutter" widths to create visual tension.
- **No Pure Grey:** Shadows and neutrals must always be "warm" (sepia-tinted) or "cool" (ink-blue-tinted), never neutral #888888.

### Accessibility Note:
While we embrace the "faded" look, ensure all `body-md` text on `surface` backgrounds maintains a contrast ratio of at least 4.5:1 by using the `on_surface` (#1c1c18) token for all long-form reading.