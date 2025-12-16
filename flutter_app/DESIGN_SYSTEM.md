# Design System

## Color System

### Palette Generation
Random seed hue (0-360) generates full palette via split-complementary color wheel theory.

| Color | Formula |
|-------|---------|
| Primary | seed @ 65% sat, 55% light |
| Secondary | seed + 150° |
| Tertiary | seed + 210° |
| Accent | seed + 30° (higher sat) |

**Purple Exclusion**: Hues 270-310 shifted to nearest allowed value.

### Semantic Colors
```
userBubble, assistantBubble, inputBackground, divider
surface, background, onSurface, onBackground
primary, secondary, tertiary, accent
error, success
```

## Typography

| Element | Font | Size | Weight |
|---------|------|------|--------|
| Display | Space Grotesk | 32 | 600 |
| Headline | Space Grotesk | 24 | 600 |
| Title | Space Grotesk | 18 | 500 |
| Body | Inter | 15 | 400 |
| Caption | Inter | 11 | 500 |

## Spacing Scale

| Token | Value |
|-------|-------|
| xs | 4px |
| sm | 8px |
| md | 12px |
| lg | 16px |
| xl | 24px |
| xxl | 32px |

## Border Radius

| Token | Value |
|-------|-------|
| sm | 8px |
| md | 12px |
| lg | 16px |
| xl | 20px |
| pill | 28px |
| bubble | 20px |
| bubbleTail | 4px |

## Responsive Breakpoints

| Breakpoint | Width |
|------------|-------|
| phone | < 600px |
| tablet | < 1200px |
| desktop | >= 1200px |

### Layout Values by Breakpoint

| Element | Phone | Tablet | Desktop |
|---------|-------|--------|---------|
| Max chat width | 100% | 720px | 800px |
| Bubble max-width | 85% | 70% | 60% |
| Horizontal padding | 12px | 24px | 32px |
| App bar height | 56px | 64px | 72px |

## Animation Durations

| Token | Value |
|-------|-------|
| fast | 150ms |
| medium | 250ms |
| slow | 400ms |
| scroll | 300ms |

## Shadows

### Subtle
```
color: black @ 8% alpha
blur: 8px
offset: (0, 2)
```

### Elevated
```
color: black @ 12% alpha
blur: 20px
offset: (0, 4)
```

### Glow (dark mode)
```
color: accent @ 25% alpha
blur: 16px
spread: 2px
```

## Components

### Message Bubble
- Asymmetric border radius (tail effect)
- User: radiusBubble all corners except bottomRight (bubbleTail)
- Assistant: radiusBubble all corners except bottomLeft (bubbleTail)
- Subtle shadow in light mode
- Max-width constrained by breakpoint

### Input Bar
- Floating with margin from edges
- Pill shape (28px radius)
- Gradient circular send button
- Elevated shadow

### App Bar
- Minimal, no elevation
- Accent color dot indicator
- Space Grotesk title
- Bottom divider line
