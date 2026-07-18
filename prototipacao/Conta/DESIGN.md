---
name: Evergreen Professional
colors:
  surface: '#fefae7'
  surface-dim: '#dedac8'
  surface-bright: '#fefae7'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f8f4e1'
  surface-container: '#f2eedc'
  surface-container-high: '#ede8d6'
  surface-container-highest: '#e7e3d1'
  on-surface: '#1d1c11'
  on-surface-variant: '#414943'
  inverse-surface: '#323125'
  inverse-on-surface: '#f5f1de'
  outline: '#717973'
  outline-variant: '#c0c9c1'
  surface-tint: '#3a6750'
  primary: '#001c0f'
  on-primary: '#ffffff'
  primary-container: '#00331f'
  on-primary-container: '#6e9d82'
  inverse-primary: '#a1d1b4'
  secondary: '#40665a'
  on-secondary: '#ffffff'
  secondary-container: '#bfe9da'
  on-secondary-container: '#446a5f'
  tertiary: '#330700'
  on-tertiary: '#ffffff'
  tertiary-container: '#571300'
  on-tertiary-container: '#e07555'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#bceecf'
  primary-fixed-dim: '#a1d1b4'
  on-primary-fixed: '#002112'
  on-primary-fixed-variant: '#224f39'
  secondary-fixed: '#c2ebdd'
  secondary-fixed-dim: '#a6cfc1'
  on-secondary-fixed: '#002019'
  on-secondary-fixed-variant: '#284e43'
  tertiary-fixed: '#ffdbd1'
  tertiary-fixed-dim: '#ffb5a0'
  on-tertiary-fixed: '#3b0a00'
  on-tertiary-fixed-variant: '#7e2b12'
  background: '#fefae7'
  on-background: '#1d1c11'
  surface-variant: '#e7e3d1'
typography:
  headline-lg:
    fontFamily: Manrope
    fontSize: 48px
    fontWeight: '800'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Manrope
    fontSize: 32px
    fontWeight: '800'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Manrope
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  headline-sm:
    fontFamily: Manrope
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  body-lg:
    fontFamily: Hanken Grotesk
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Hanken Grotesk
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-caps:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  unit: 8px
  gutter: 24px
  margin-mobile: 16px
  margin-desktop: 64px
  container-max: 1280px
---

## Brand & Style

The brand identity centers on a sophisticated, high-contrast aesthetic that bridges the gap between traditional industry stability and modern digital precision. The target audience is discerning professionals who value longevity, clarity, and architectural rigor.

The design style is **Corporate / Modern** with a **Minimalist** foundation. It prioritizes structure and legibility, using deep earth-toned primaries to ground the interface while employing high-contrast accents to guide the user's eye. The visual mood is authoritative and grounded, avoiding unnecessary flourishes in favor of intentional whitespace and bold, geometric compositions.

## Colors

The palette is anchored by **Verde Escuro (#00331F)**, a deep, professional green used for primary actions, heavy typography, and structural elements. This is balanced by a secondary **Verde Billhard (#B2DBCD)** which provides a softer, breathable mint tone for lighter UI surfaces and success states.

**Bege (#E2DECC)** serves as the primary neutral, replacing standard grays to add a touch of warmth and premium "paper-like" quality to the interface. **Terracota (#A94B2F)** is utilized strictly as a high-contrast accent for notifications, highlights, or secondary calls-to-action, providing a sharp visual counterpoint to the green foundation.

The system defaults to a **light mode** with high-contrast text to ensure maximum readability and a clean, editorial feel.

## Typography

The typography mirrors the bold, geometric wordmark of the brand kit. **Manrope** is used for headlines, providing a modern, technical feel with high impact. Headlines should be set with tight letter spacing to emulate the "Billhard" logo style.

**Hanken Grotesk** serves as the body typeface, chosen for its exceptional clarity and contemporary professional tone. For technical metadata, small captions, and labels, **JetBrains Mono** is introduced to provide a subtle "utility" feel that reinforces the system's professional rigor.

Large headlines should use the primary dark green color to maintain a strong brand presence across the layout.

## Layout & Spacing

The layout follows a **Fixed Grid** philosophy on desktop to maintain an editorial, structured feel, transitioning to a fluid model on mobile. A 12-column grid is standard for desktop, utilizing generous 64px outer margins to create a focused "stage" for content.

Spacing follows a strict 8px base unit. Vertical rhythm is emphasized through significant "white-space" (or "beige-space"), allowing the high-contrast elements to breathe. Content blocks should be clearly separated by large gaps (48px+) to signify distinct thematic shifts.

## Elevation & Depth

To maintain a sophisticated and modern look, this design system avoids heavy shadows. Depth is primarily conveyed through **Tonal Layers** and **Low-contrast outlines**.

Surfaces are differentiated using subtle shifts between the white background and the Beige (#E2DECC) neutral. Elements that require focus (like modals or dropdowns) use a very soft, highly diffused ambient shadow with a hint of the primary green color in the tint (e.g., `rgba(0, 51, 31, 0.08)`).

Borders are used sparingly and should be thin (1px), using either the secondary mint or a muted version of the neutral beige to define boundaries without cluttering the visual field.

## Shapes

The shape language is disciplined and "Soft" (0.25rem). While the brand wordmark features some rounded corners, the overall identity is architectural. Standard buttons and input fields use the base 4px (0.25rem) radius.

Cards and larger containers may scale up to a "rounded-lg" (8px) for a slightly friendlier feel on mobile, but the general rule is to keep corners crisp to maintain a professional, high-end engineering or architectural aesthetic.

## Components

- **Buttons:** Primary buttons use the dark green background with white or mint text. They are rectangular with a 4px corner radius. Secondary buttons should use the Terracotta accent for high-visibility actions or a simple Beige outline for low-emphasis actions.
- **Input Fields:** Use a 1px border of Beige (#E2DECC) which transitions to Primary Green (#00331F) on focus. Labels should use the JetBrains Mono "label-caps" style above the field.
- **Cards:** Cards should not have shadows by default. Instead, use a subtle background fill of the Beige or Mint colors to distinguish them from the main surface.
- **Chips:** Small, pill-shaped elements using the Secondary Mint (#B2DBCD) background with Primary Green text for "active" states, and Beige for "inactive" states.
- **Lists:** Clean, borderless lists with 16px vertical padding between items, using the Primary Green for headers and Hanken Grotesk for list content.