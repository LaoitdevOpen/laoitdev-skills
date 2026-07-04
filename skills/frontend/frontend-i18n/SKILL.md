---
name: frontend-i18n
description: "Translation and i18n rules for the AMIS admin project. Use this whenever writing any user-visible string, building a form with validation messages, handling API or business errors, or adding new translation keys. Also use when the user asks 'how do I translate X', 'add translation for Y', 'don't hardcode this string', or 'add an error message'. Covers: useTranslation usage, Zod schema factory pattern, validation key structure, API error translation via useAPIErrorTranslator, and adding new error codes to both translation files."
---

# Translation & i18n

The project uses `react-i18next` with a single `translation` namespace. All user-visible text — labels, placeholders, validation messages, snackbar messages, error strings — must go through `t()`. Never hardcode English (or Lao) strings directly in components or schemas.

Config: `src/core/config/i18n.config.ts`  
Translation files: `src/assets/locales/en/translation.json` and `src/assets/locales/lo/translation.json`  
Default language: `lo` (Lao). Fallback: `lo`.

---

## 1. Using `t()` in Components

Always call `useTranslation()` at the top of the component. Pass the result of `t()` everywhere a string is displayed to the user.

```tsx
const { t } = useTranslation()

// Labels, buttons, headings
<Button>{t('common.save')}</Button>
<Typography>{t('ministries.edit')}</Typography>

// Dynamic values
<Typography>{t('dashboard.welcome', { name: user.name })}</Typography>

// Option lists — store the key, translate at render time
const GROUP_OPTIONS = [
  { value: 'CENTER', label: 'ministries.groups.CENTER' },
  { value: 'PROVINCE', label: 'ministries.groups.PROVINCE' },
]
{GROUP_OPTIONS.map(opt => <MenuItem key={opt.value}>{t(opt.label)}</MenuItem>)}
```

**Never do this:**
```tsx
// Bad — hardcoded string
<Button>Save</Button>
label="ຊື່"

// Bad — string in a constant without t()
const label = 'Province'
```

---

## 2. Zod Validation Schemas — Factory Function Pattern

Schemas that produce user-visible error messages must be factory functions that accept `t: TFunction`. This lets them produce translated messages at runtime.

```ts
import { z } from 'zod'
import type { TFunction } from 'i18next'

export const getFeatureSchema = (t: TFunction) => z.object({
  name: z
    .string()
    .min(1, t('validation.required'))
    .max(255, t('validation.maxLength', { max: 255 })),
  code: z
    .string()
    .max(50, t('validation.maxLength', { max: 50 }))
    .optional()
    .or(z.literal('')),
  group: z.enum(['A', 'B'], {
    message: t('validation.required'),
  }),
})

export type FeatureFormData = z.infer<ReturnType<typeof getFeatureSchema>>
```

In the form component, call the factory with `t`:

```tsx
const { t } = useTranslation()
const schema = getFeatureSchema(t)

const form = useAppForm({
  defaultValues: { name: '', code: '', group: 'A' } as FeatureFormData,
  validators: { onChange: schema },
  onSubmit: async ({ value }) => { ... }
})
```

### Available `validation.*` keys

These shared keys live at the top level of `translation.json`:

| Key | Parameters | Use for |
|---|---|---|
| `validation.required` | — | Field is empty / required |
| `validation.minLength` | `{ min }` | Minimum character count |
| `validation.maxLength` | `{ max }` | Maximum character count |
| `validation.email` | — | Email format |
| `validation.number` | — | Must be a number |
| `validation.positive` | — | Must be positive |
| `validation.min` | `{ min }` | Numeric minimum |
| `validation.max` | `{ max }` | Numeric maximum |
| `validation.passwordMismatch` | — | Password confirmation |

If you need a validation message that doesn't fit any of these, add a new key under `validation.*` in **both** `en/translation.json` and `lo/translation.json`.

For feature-specific validation messages that only apply to one domain, put them under `featureName.validation.*`:

```json
// in translation.json
"ministries": {
  "validation": {
    "codeFormat": "Code must be alphanumeric"
  }
}
```

---

## 3. API Error Translation

The project uses `useAPIErrorTranslator` (at `src/shared/hooks/useAPIErrorTranslator.ts`) to translate server errors into user-friendly strings. Use it in every mutation `onError` callback.

```tsx
import { useAPIErrorTranslator } from '@/shared/hooks'

const { translateError } = useAPIErrorTranslator()

createMutation.mutate(value, {
  onSuccess: () => showSuccess(t('feature.createSuccess')),
  onError: (error) => showError(translateError(error)),
})
```

### How `translateError` works (priority order)

1. **Network / no response** → `errors.http.503` or `errors.http.504`
2. **HTTP 422 with `errors` array** → field-level validation via `apiValidation.*`
3. **Legacy `detail` array** → same field-level validation
4. **`status` code present** → business error via `errors.{category}.*`
5. **HTTP status code** → `errors.http.{status}`
6. **Fallback** → raw message or `errors.general.unexpected`

### `apiValidation.*` keys — server-side field errors

When the API returns a 422 with validation details (`{ field, tag, param }`), `translateError` maps the `tag` to `apiValidation.{tag}`:

| Key | Parameters | Tag |
|---|---|---|
| `apiValidation.required` | `{ field }` | `required` |
| `apiValidation.min` | `{ field, n }` | `min` |
| `apiValidation.max` | `{ field, n }` | `max` |
| `apiValidation.email` | `{ field }` | `email` |
| `apiValidation.gt` | `{ field, n }` | `gt` |
| `apiValidation.gte` | `{ field, n }` | `gte` |
| `apiValidation.numeric` | `{ field }` | `numeric` |
| `apiValidation.alpha` | `{ field }` | `alpha` |
| `apiValidation.alphanum` | `{ field }` | `alphanum` |

Field names in the error output come from `fields.{fieldName}`. Add new field names to `fields.*` in both translation files.

---

## 4. Adding New Business Errors

When the backend returns a new error code (e.g., `CONTRACT_ALREADY_SIGNED`), add it in two places.

### Step 1: Add to `useAPIErrorTranslator.ts`

Find the right `translate*Error` function and add the code to its `errorCodeMap`:

```ts
// In translateInvalidArgumentError:
const errorCodeMap: Record<string, string> = {
  // ... existing entries
  'CONTRACT_ALREADY_SIGNED': 'contractAlreadySigned',  // add here
}
```

Which function to use:
- `translateNotFoundError` → status `NOT_FOUND` (resource doesn't exist)
- `translateAlreadyExistsError` → status `ALREADY_EXISTS` (duplicate)
- `translateInvalidArgumentError` → status `INVALID_ARGUMENT` (bad state / business rule violation)
- `translateBusinessError` in the `INTERNAL` / `UNAVAILABLE` cases → for service-level errors

If the error belongs in `errors.businessLogic.*` (not `errors.invalidArgument.*`), add the key name to the `businessLogic` check inside `translateInvalidArgumentError`:

```ts
if (['resourceFeeAlreadyPaid', 'contractAlreadySigned'].includes(errorType)) {
  return t(`errors.businessLogic.${errorType}`)
}
```

### Step 2: Add translation keys to both files

In `src/assets/locales/en/translation.json`:
```json
"errors": {
  "invalidArgument": {
    "contractAlreadySigned": "Contract has already been signed"
  }
}
```

In `src/assets/locales/lo/translation.json`:
```json
"errors": {
  "invalidArgument": {
    "contractAlreadySigned": "ສັນຍານີ້ໄດ້ຖືກລົງນາມແລ້ວ"
  }
}
```

Always add keys to **both** files at the same time.

---

## 5. `common.errors.*` — Module-Specific Export/Operation Errors

There is a flat error map under `common.errors` used for module-specific operation codes (e.g. `VEHICLE_ALREADY_EXPORTED`). These are used directly in components, not through `useAPIErrorTranslator`:

```tsx
// Used in ExportDialog components
const errorKey = `common.errors.${error.code}`
showError(t(errorKey, { defaultValue: error.message }))
```

To add a new one, add to `common.errors` in both translation files:
```json
"common": {
  "errors": {
    "LAND_ALREADY_EXPORTED": "Land record has already been exported"
  }
}
```

---

## 6. Translation Key Naming Conventions

- Use camelCase for all keys: `createSuccess`, not `create_success` or `CreateSuccess`
- Feature-level keys nest under the feature name: `ministries.createSuccess`
- Shared labels go under `common.*` or `fields.*`
- Validation messages: `validation.*` (generic) or `featureName.validation.*` (specific)
- Error messages: `errors.{category}.{key}` — never put error strings in the feature namespace

## 7. Adding Translation Keys Checklist

When adding any new user-visible text:

1. Add the English key to `en/translation.json`
2. Add the Lao key to `lo/translation.json`  
3. Use `t('key.path')` in the component — never the raw string
4. If it's a validation message in a Zod schema, use the factory function pattern
5. If it's an API error code, register it in `useAPIErrorTranslator.ts` + both translation files
