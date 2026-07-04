# Focus Management

TanStack Form fires `onSubmitInvalid` when the form fails validation on submit. Use the project's utilities instead of rolling your own.

## Import

```tsx
import { createOnSubmitInvalidFocusHandler, focusFirstInvalidField } from '@/shared/utils/focusFirstInvalidField'
```

## `createOnSubmitInvalidFocusHandler` (standard)

Returns a ready-made `onSubmitInvalid` callback. Requires a `ref` on the `<form>` element.

```tsx
export function FeatureForm() {
  const formRef = useRef<HTMLFormElement>(null)

  const form = useAppForm({
    defaultValues: { name: '', amount: 0 },
    validators: { onChange: schema },
    onSubmitInvalid: createOnSubmitInvalidFocusHandler(() => formRef.current),
    onSubmit: async ({ value }) => { /* ... */ },
  })

  return (
    <form.AppForm>
      <Box
        component="form"
        ref={formRef}
        onSubmit={(e) => { e.preventDefault(); form.handleSubmit() }}
        noValidate
      >
        {/* fields */}
        <form.SubmitButton label={t('common.save')} loading={mutation.isPending} />
      </Box>
    </form.AppForm>
  )
}
```

Options:
```tsx
onSubmitInvalid: createOnSubmitInvalidFocusHandler(() => formRef.current, {
  scroll: true,          // default: true
  behavior: 'smooth',   // default: 'smooth'
})
```

## `focusFirstInvalidField` (imperative)

Call directly after server errors or when re-validating from a stepper:

```tsx
requestAnimationFrame(() => {
  focusFirstInvalidField(formRef.current)               // returns true if found
  focusFirstInvalidField(formRef.current, { scroll: false })
})
```

## How it works

Two-pass DOM query inside the form element:

1. `[aria-invalid="true"]` — scrolls closest `.MuiFormControl-root` into view, then focuses
2. `.MuiFormControl-root:has(.Mui-error), .MuiFormControl-root.Mui-error` — fallback when `aria-invalid` isn't set

`requestAnimationFrame` defers the query until after React flushes error state into the DOM.

## `noValidate` is required

Always set `noValidate` on the `<form>` element — without it the browser's native validation fires first and can block `onSubmitInvalid` from running.

```tsx
<Box component="form" ref={formRef} onSubmit={(e) => { e.preventDefault(); form.handleSubmit() }} noValidate>
```
