---
name: tanstack-form
description: "How to build forms using TanStack Form v1 with the shared useAppForm hook and App* field components. Use this whenever creating or modifying any form — create forms, update/edit forms, filter forms, or modal forms. Covers form setup, field components, Zod schema validation, form sections pattern, submit handling with confirmation dialogs, and filter forms that sync with URL."
---

# Forms with TanStack Form

The project uses TanStack Form v1 with a shared `useAppForm` hook that pre-binds all form components. Always use this hook rather than raw `useForm`.

## Core Invariants (always enforced — never violate)

- Always use `useAppForm`, don't use `useApp`.
- Every form's DOM scope is `<form.AppForm>` wrapping a `<form>` element with `onSubmit={(e) => { e.preventDefault(); form.handleSubmit() }}` (the existing `<Box component="form">` examples already satisfy this — no code changes needed there, this just makes the structural rule explicit).
- Always render the submit action via `<form.SubmitButton>` — never a raw MUI `<Button type="submit">`.

## References

Read the relevant file when you need it:
- `references/form-composition.md` — `withForm`, `withFieldGroup`, `useTypedAppFormContext` for multi-section or nested-object forms
- `references/focus-management.md` — `createOnSubmitInvalidFocusHandler`, `focusFirstInvalidField`, how it works
- `references/filter-forms.md` — URL-synced filter forms (Accordion + search params) + reactive/cascading fields

---

## Imports

```tsx
import { useAppForm, withForm, withFieldGroup, useTypedAppFormContext } from '@/shared/components/form'
import { createOnSubmitInvalidFocusHandler } from '@/shared/components/form'
```

---

## Basic Form Setup

```tsx
export function FeatureForm() {
  const { t } = useTranslation()
  const formRef = useRef<HTMLFormElement>(null)

  const form = useAppForm({
    defaultValues: {
      name: '' as string,
      count: 0,
      category_id: null as number | null,
    },
    validators: { onChange: yourZodSchema },
    onSubmitInvalid: createOnSubmitInvalidFocusHandler(() => formRef.current),
    onSubmit: async ({ value }) => {
      await mutation.mutateAsync(value)
    },
  })

  return (
    <form.AppForm>
      <Box
        component="form"
        ref={formRef}
        onSubmit={(e) => { e.preventDefault(); form.handleSubmit() }}
        noValidate
      >
        <form.AppField name="name">
          {(field) => <field.TextField label={t('feature.name')} required />}
        </form.AppField>

        <form.AppField name="count">
          {(field) => <field.TextFieldNumber label={t('feature.count')} />}
        </form.AppField>

        <form.SubmitButton
          label={t('common.save')}
          loading={mutation.isPending}
        />
      </Box>
    </form.AppForm>
  )
}
```

`form.SubmitButton` renders MUI's native `loading` prop under the hood — this shows a `CircularProgress` spinner and auto-disables the button; no separate `loadingLabel` text-swap is needed.

---

## Available Field Components

All accessed via `field.ComponentName` inside `form.AppField`:

| Component | Use for |
|---|---|
| `field.TextField` | Text input |
| `field.TextFieldNumber` | Numeric input |
| `field.Select` | Dropdown with `options: { value, label }[]` |
| `field.Autocomplete` | Searchable dropdown |
| `field.AutocompleteInfinite` | Paginated searchable dropdown |
| `field.DatePicker` | Date picker (Day.js) |
| `field.DateTimePicker` | Date + time picker |
| `field.Checkbox` | Boolean checkbox |
| `field.Switch` | Toggle switch |
| `field.ImageUploadField` | File upload |

### TextField

```tsx
<form.AppField name="description">
  {(field) => (
    <field.TextField label="Description" required multiline rows={4} placeholder="Enter..." />
  )}
</form.AppField>
```

### Select

```tsx
<form.AppField name="status">
  {(field) => (
    <field.Select
      label={t('feature.status')}
      options={STATUS_OPTIONS.map(opt => ({ value: opt.value, label: t(opt.label) }))}
      clearable
    />
  )}
</form.AppField>
```

### Autocomplete

```tsx
<form.AppField name="category_id">
  {(field) => (
    <field.Autocomplete
      label={t('feature.category')}
      options={categories}
      getOptionLabel={(opt) => opt.name}
      getOptionValue={(opt) => opt.id}
      multiple={false}
    />
  )}
</form.AppField>
```

---

## Zod Schema with Translation

Schemas needing translated error messages are factory functions accepting `t: TFunction`:

```ts
import { z } from 'zod'
import type { TFunction } from 'i18next'
import { formOptions } from '@tanstack/react-form'

export const getFeatureCreateSchema = (t: TFunction) => z.object({
  name: z.string().min(1, t('feature.validation.nameRequired')).max(255),
  count: z.number().min(0),
  category_id: z.number().min(1, t('feature.validation.categoryRequired')),
  notes: z.string().nullable(),
})

export type FeatureCreateFormData = z.infer<ReturnType<typeof getFeatureCreateSchema>>

export const featureCreateFormOption = formOptions({
  defaultValues: {
    name: '',
    count: 0,
    category_id: null as number | null,
    notes: null as string | null,
  },
})
```

Usage:
```tsx
const schema = getFeatureCreateSchema(t)
const form = useAppForm({
  defaultValues: featureCreateFormOption.defaultValues,
  validators: { onChange: schema },
})
```

---

## Submit with Confirmation Dialog

```tsx
const { confirm } = useConfirmDialog()

const form = useAppForm({
  onSubmit: async () => {
    const confirmed = await confirm({
      title: t('feature.confirmUpdate'),
      message: t('feature.confirmUpdateMessage'),
      confirmText: t('common.save'),
      cancelText: t('common.cancel'),
      confirmColor: 'primary',
      maxWidth: 'xs',
    })
    if (!confirmed) return

    mutation.mutate(form.state.values, {
      onSuccess: () => {
        showSuccess(t('feature.updateSuccess'))
        navigate({ to: '/feature/$featureId', params: { featureId: String(id) } })
      },
      onError: (error) => showError(translateError(error)),
    })
  },
})
```

---

## Sticky Footer Submit Bar

```tsx
<Box
  sx={{
    position: 'sticky', bottom: 0,
    bgcolor: 'background.paper',
    borderTop: '1px solid', borderColor: 'divider',
    p: 2, mt: 3, mx: -2,
  }}
>
  <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} justifyContent="flex-end">
    <Button variant="outlined" onClick={() => navigate({ to: '..' })}>
      {t('common.cancel')}
    </Button>
    <form.SubmitButton
      label={t('common.save')}
      loading={mutation.isPending}
    />
  </Stack>
</Box>
```
