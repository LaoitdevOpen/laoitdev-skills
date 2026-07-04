---
name: mui-theme
description: "MUI theme configuration, color palette, typography, dark/light mode, and shared UI building blocks. Use this when working with colors, spacing, typography, component styling, adding theme overrides, or using SectionCard/InfoRow shared components for consistent UI. Also covers how ThemeContext and LocalizationProvider are wired up."
---

# Theme & UI Building Blocks

## Color Palette

The theme uses a government-style palette. Reference these via MUI's `sx` prop or `theme.palette`:

| Token | Value | Use |
|---|---|---|
| `primary.main` | `#027BC5` | Azure Blue — primary actions, headers |
| `primary.dark` | `#015A94` | Hover/active state |
| `secondary.main` | `#CE1126` | Red — destructive, secondary accent |
| `success.main` | `#059669` | Success state |
| `warning.main` | `#D97706` | Warning state |
| `error.main` | `#DC2626` | Error state |
| `info.main` | `#027BC5` | Same as primary |

Light mode backgrounds:
- `background.default`: `#F8FAFC` (page background)
- `background.paper`: `#FFFFFF` (card/surface)
- `divider`: `#E2E8F0`
- `text.primary`: `#1E293B`
- `text.secondary`: `#64748B`

Dark mode backgrounds:
- `background.default`: `#0F172A`
- `background.paper`: `#1E293B`
- `divider`: `#334155`

## Typography Scale

| Variant | Size | Weight | Use |
|---|---|---|---|
| `h1` | 32px | 700 | Page titles (rare) |
| `h4` | 20px | 600 | Form headings |
| `h6` | 16px | 600 | Card/section headings |
| `body1` | 15px | 400 | Main body text |
| `body2` | 14px | 400 | Secondary text |
| `caption` | 13px | 500 | Labels in InfoRow |
| `overline` | 12px | 600 | Uppercase section labels |
| `button` | 15px | 500 | Button text (no uppercase) |

Font stack: `'Noto Sans Lao', 'Noto Sans', 'Phetsarath OT', 'Saysettha OT', sans-serif`

## Component Defaults

- `MuiButton`: `borderRadius: 8px`, `disableElevation: true`, no uppercase transform
- `MuiTextField`: `size: 'small'`, `borderRadius: 6px`
- `MuiCard`: `borderRadius: 8px`, subtle shadow
- `MuiChip`: `borderRadius: 4px`
- `spacing`: 8px baseline (`theme.spacing(1) === '8px'`)

## Dark/Light Mode Toggle

```tsx
import { useTheme } from '@/core/context/ThemeContext'

function MyComponent() {
  const { mode, toggleTheme } = useTheme()

  return (
    <IconButton onClick={toggleTheme}>
      {mode === 'dark' ? <LightModeIcon /> : <DarkModeIcon />}
    </IconButton>
  )
}
```

Mode persists in `localStorage` under key `'admin-theme-mode'`.

## Provider Setup

Wrap the app (in `main.tsx`) in this order:
```tsx
<QueryClientProvider client={queryClient}>
  <ThemeProvider>          {/* MUI theme + CssBaseline + LocalizationProvider */}
    <AuthProvider>
      <SnackbarProvider>
        <ConfirmDialogProvider>
          <RouterProvider router={router} />
        </ConfirmDialogProvider>
      </SnackbarProvider>
    </AuthProvider>
  </ThemeProvider>
</QueryClientProvider>
```

`ThemeProvider` wraps MUI's `ThemeProvider`, `CssBaseline`, and MUI's `LocalizationProvider` (with Day.js adapter) — so date pickers work without additional setup.

## SectionCard

A card with an icon avatar, title, and a divider — used in detail pages to group related fields.

```tsx
import { SectionCard } from '@/shared/components'

<SectionCard
  icon={<InfoIcon />}             // MUI icon
  title="Basic Information"
  iconColor="primary.main"        // optional, defaults to 'primary.main'
>
  {/* InfoRow children or raw children */}
  <InfoRow label="Name" value={item.name} />
</SectionCard>

// With raw children (not wrapped in List):
<SectionCard icon={<AttachFileIcon />} title="Attachments" rawChildren>
  <Button href={item.fileUrl}>Download</Button>
</SectionCard>
```

Hover effect: border color changes to `primary.main`, box shadow lifts.

## InfoRow

A label + value pair used inside `SectionCard`. Displays a subtle uppercase label above the value.

```tsx
import { InfoRow } from '@/shared/components'

<InfoRow label="Serial Number" value={item.serialNumber} />
<InfoRow label="Status" value={null} />        // shows '-' for null/undefined
<InfoRow label="Actions" value={<Button>Edit</Button>} />  // accepts ReactNode
```

Labels render as `caption` variant, uppercase, `text.secondary`. Values render as `body1`, `text.primary`.

## Page Layout Patterns

### Page Header
```tsx
<Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
  <Box>
    <Box component="h1" sx={{ fontSize: { xs: '1.5rem', md: '2rem' }, fontWeight: 600, mb: 0.5 }}>
      {pageTitle}
    </Box>
    <Box component="p" sx={{ fontSize: '0.875rem', color: 'text.secondary' }}>
      {description}
    </Box>
  </Box>
  <Button variant="contained" startIcon={<AddIcon />}>Create</Button>
</Box>
```

### Detail Page Hero (full-width colored header)
```tsx
<Paper
  elevation={0}
  sx={{
    bgcolor: 'primary.main',
    color: 'white',
    py: { xs: 2.5, md: 3.5 },
    px: { xs: 3, md: 4 },
    mx: { xs: -2, md: -4 },  // bleed beyond container padding
    borderRadius: 0,
    position: 'relative',
    overflow: 'hidden',
    // decorative circles
    '&::before': {
      content: '""', position: 'absolute', top: 0, right: 0,
      width: { xs: '120px', md: '250px' }, height: { xs: '120px', md: '250px' },
      bgcolor: 'rgba(255, 255, 255, 0.05)', borderRadius: '50%',
      transform: 'translate(35%, -35%)',
    },
  }}
>
  ...
</Paper>
```

### MUI Grid

Grid items must use the `size` prop — never legacy `xs`/`md` props or the `item` prop. See `react-standard` for the full rule.

### Card Grid for Detail Sections
```tsx
<Container maxWidth="xl" sx={{ mt: 4, mb: 4 }}>
  <Grid container spacing={3}>
    <Grid size={{ xs: 12, md: 6 }}>
      <SectionCard icon={<InfoIcon />} title="Section Title">
        <InfoRow label="Field" value={value} />
      </SectionCard>
    </Grid>
  </Grid>
</Container>
```

## sx Prop Tips

```tsx
// Responsive values
sx={{ fontSize: { xs: '1rem', md: '1.25rem' } }}

// Theme-aware colors
sx={{ bgcolor: 'primary.main', color: 'white' }}
sx={{ borderColor: 'divider' }}

// Callback form for theme access
sx={{ bgcolor: (theme) => theme.palette.action.hover }}

// Combined
sx={{
  borderRadius: 3,
  border: '1px solid',
  borderColor: 'divider',
  '&:hover': { borderColor: 'primary.main' },
}}
```

## Theme Config Location

`src/core/config/theme.config.ts` — edit this file to change global colors, typography, or component defaults.
