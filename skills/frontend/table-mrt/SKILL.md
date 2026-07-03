---
name: table-mrt
description: "How to build data tables using the DataTable component (Material React Table wrapper). Use this whenever creating a list/table view for a feature. Covers column definitions, server-side pagination, row actions menu, row selection for batch operations, custom top toolbar, and loading/error states."
---

# Data Tables with DataTable (MRT Wrapper)

The project wraps Material React Table in a shared `DataTable` component at `@/shared/components/DataTable`. Always use this wrapper — don't instantiate `MaterialReactTable` directly.

## Import

```tsx
import { DataTable } from '@/shared/components/DataTable'
import type { MRT_ColumnDef, MRT_RowSelectionState } from 'material-react-table'
```

## Basic Usage

```tsx
interface FeatureListProps {
  searchParams: FeatureFilterParams
  onPageChange: (page: number) => void
  onPageSizeChange: (pageSize: number) => void
}

export function FeatureList({ searchParams, onPageChange, onPageSizeChange }: FeatureListProps) {
  const { t } = useTranslation()
  const { data, isLoading, isError } = useFeatures(searchParams)

  const columns = useMemo<MRT_ColumnDef<Feature>[]>(() => [
    {
      accessorKey: 'id',
      header: '#',
      size: 60,
      Cell: ({ row, table }) => {
        const { pageIndex, pageSize } = table.getState().pagination
        return pageIndex * pageSize + row.index + 1
      },
    },
    {
      accessorKey: 'name',
      header: t('feature.name'),
      size: 200,
      Cell: ({ cell }) => <>{cell.getValue() || '-'}</>,
    },
    // more columns...
  ], [t])

  return (
    <DataTable
      columns={columns}
      data={data?.items || []}
      rowCount={data?.total || 0}
      isLoading={isLoading}
      isError={isError}
      page={searchParams.page}
      pageSize={searchParams.page_size}
      onPageChange={onPageChange}
      onPageSizeChange={onPageSizeChange}
    />
  )
}
```

## Column Definitions

Use `accessorKey` for simple field access, `id` + `Cell` for computed or multi-field columns.

```tsx
const columns = useMemo<MRT_ColumnDef<Feature>[]>(() => [
  // Sequential row number (works with server-side pagination)
  {
    accessorKey: 'id',
    header: '#',
    size: 60,
    Cell: ({ row, table }) => {
      const { pageIndex, pageSize } = table.getState().pagination
      return pageIndex * pageSize + row.index + 1
    },
  },
  // Nullable field with fallback
  {
    accessorKey: 'serial_number',
    header: t('feature.serialNumber'),
    size: 150,
    Cell: ({ cell }) => <>{cell.getValue() || '-'}</>,
  },
  // Nested object
  {
    accessorKey: 'category.name',
    header: t('feature.category'),
    size: 150,
  },
  // Status chip
  {
    accessorKey: 'status',
    header: t('feature.status'),
    size: 120,
    Cell: ({ cell }) => (
      <Chip label={cell.getValue<string>()} color={cell.getValue() === 'active' ? 'success' : 'default'} size="small" />
    ),
  },
], [t])
```

### Extracting Columns for Larger Tables

Once a table has more than a handful of columns, extract column definitions into a dedicated hook:

- File: `components/{Feature}Columns.tsx`
- Hook: `use{Feature}Columns()`

```tsx
// components/FeatureColumns.tsx
export function useFeatureColumns() {
  const { t } = useTranslation()
  return useMemo<MRT_ColumnDef<Feature>[]>(() => [
    // column defs...
  ], [t])
}

// components/FeatureList.tsx
const columns = useFeatureColumns()
```

## Loading and Error States

Pass query state directly to `DataTable`:

- `isLoading` — drives MRT's built-in progress bar and loading skeleton. No separate skeleton component is needed.
- `isError` — drives MRT's alert banner (`showAlertBanner`).

```tsx
const { data, isLoading, isError } = useFeatures(searchParams)

<DataTable
  // ...
  isLoading={isLoading}
  isError={isError}
/>
```

## Disabled MRT Features

The `DataTable` wrapper hard-disables these MRT features globally:

- `enableColumnActions`
- `enableColumnFilters`
- `enableSorting`
- `enableDensityToggle`
- `enableFullScreenToggle`
- `enableHiding`

Column-level overrides (e.g. `enableSorting: true` on a column def) have no effect. Filtering and sorting belong in the page-level filter form and API query params, not in the table itself.

## Row Actions Menu

When `enableRowActions` is enabled, the actions column is automatically pinned to the right (`enableColumnPinning` defaults to `true`).

Define `RowActionMenu` as a component inside `renderRowActions` to use hooks (like `useState`):

```tsx
<DataTable
  // ...
  enableRowActions
  positionActionsColumn="last"
  getRowId={(row: Feature) => String(row.id)}
  renderRowActions={({ row }) => {
    const RowActionMenu = () => {
      const { hasPermission } = usePermissions()
      const [anchorEl, setAnchorEl] = useState<null | HTMLElement>(null)
      const open = Boolean(anchorEl)

      const canView = hasPermission('feature-index')
      const canEdit = hasPermission('feature-edit')
      if (!canView && !canEdit) return null

      return (
        <>
          <Tooltip title={t('common.actions')} arrow>
            <IconButton size="small" onClick={(e) => setAnchorEl(e.currentTarget)}>
              <MoreVertIcon fontSize="small" />
            </IconButton>
          </Tooltip>
          <Menu anchorEl={anchorEl} open={open} onClose={() => setAnchorEl(null)}
            anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
            transformOrigin={{ vertical: 'top', horizontal: 'right' }}
          >
            {canView && (
              <MenuItem onClick={() => { navigate({ to: '/your-section/feature/$featureId', params: { featureId: String(row.original.id) } }); setAnchorEl(null) }}>
                <ListItemIcon><VisibilityIcon fontSize="small" /></ListItemIcon>
                <ListItemText>{t('feature.viewDetails')}</ListItemText>
              </MenuItem>
            )}
            {canEdit && (
              <MenuItem onClick={() => { navigate({ to: '/your-section/feature/$featureId/edit', params: { featureId: String(row.original.id) } }); setAnchorEl(null) }}>
                <ListItemIcon><EditIcon fontSize="small" /></ListItemIcon>
                <ListItemText>{t('common.edit')}</ListItemText>
              </MenuItem>
            )}
          </Menu>
        </>
      )
    }
    return <RowActionMenu />
  }}
/>
```

## Row Selection for Batch Operations

When `enableRowSelection` is enabled, the select checkbox column is automatically pinned to the left.

The top toolbar row only renders when `renderTopToolbarCustomActions` is provided (`enableTopToolbar={!!renderTopToolbarCustomActions}`).

```tsx
const [rowSelection, setRowSelection] = useState<MRT_RowSelectionState>({})

const selectedItems = useMemo(() => {
  const selectedIds = Object.keys(rowSelection).filter((key) => rowSelection[key])
  return data.filter((item) => selectedIds.includes(String(item.id)))
}, [rowSelection, data])

<DataTable
  // ...
  enableRowSelection={(row) => row.original.status !== 'exported'} // or just `true`
  getRowId={(row) => String(row.id)}
  rowSelection={rowSelection}
  onRowSelectionChange={setRowSelection}
  renderTopToolbarCustomActions={() => (
    <Box sx={{ display: 'flex', gap: 1, alignItems: 'center', width: '100%', justifyContent: 'space-between' }}>
      <Box sx={{ display: 'flex', gap: 1, alignItems: 'center' }}>
        {selectedItems.length > 0 && (
          <>
            <Chip label={t('feature.selected', { count: selectedItems.length })} color="primary" size="small" />
            <Button variant="contained" size="small" onClick={handleBatchAction}>
              {t('feature.batchAction', { count: selectedItems.length })}
            </Button>
          </>
        )}
      </Box>
      <Button variant="outlined" size="small" onClick={handleExport}>
        {t('feature.exportToExcel')}
      </Button>
    </Box>
  )}
/>
```

## DataTable Props Reference

| Prop | Type | Default | Purpose |
|---|---|---|---|
| `columns` | `MRT_ColumnDef<T>[]` | required | Column definitions |
| `data` | `T[]` | required | Row data |
| `rowCount` | `number` | `0` | Total rows (for server pagination) |
| `isLoading` | `boolean` | `false` | Loading state (progress bar + skeleton) |
| `isError` | `boolean` | `false` | Error state (alert banner) |
| `page` | `number` | `1` | Current page (1-indexed) |
| `pageSize` | `number` | `10` | Rows per page |
| `onPageChange` | `(p: number) => void` | — | Called on page change |
| `onPageSizeChange` | `(ps: number) => void` | — | Called on page size change |
| `enableRowActions` | `boolean` | `false` | Show actions column |
| `renderRowActions` | `fn` | — | Action cell renderer |
| `positionActionsColumn` | `'first' \| 'last'` | `'last'` | Actions column position |
| `actionsColumnSize` | `number` | `80` | Width of the actions column |
| `enableRowSelection` | `boolean \| fn` | `false` | Enable row checkboxes |
| `getRowId` | `(row: T) => string` | — | Required when using row selection |
| `rowSelection` | `Record<string, boolean>` | — | Controlled selection state |
| `onRowSelectionChange` | `fn` | — | Selection change handler |
| `renderTopToolbarCustomActions` | `fn` | — | Custom toolbar content (also controls toolbar visibility) |
| `enableColumnPinning` | `boolean` | `true` | Pin select column left, actions column right |
| `muiTableBodyRowProps` | `fn \| object` | — | Override default row styling |

## Pagination

Pagination is server-side (`manualPagination`). The component converts 1-indexed pages from your URL params to 0-indexed for MRT internally. Always pass `page` and `pageSize` from `searchParams`, and update the URL on change via `navigate`.
