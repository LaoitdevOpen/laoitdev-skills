---
name: flutter-clean-arch-getx
description: File-by-file conventions and copy-paste patterns for building or modifying features in a Flutter app that uses Clean Architecture (data/domain/presentation layers) with GetX state management and get_it dependency injection. Use this whenever the user is adding or changing a feature, screen, or API integration in a Flutter/GetX project — including entities, models, datasources, repositories, usecases, GetX controllers or bindings, DI registration in injection.dart, routing, or localization/translation keys. Trigger even if they don't say "clean architecture" or "GetX" by name — phrases like "add a screen that calls this API", "wire up this repository", "create a controller for X", "register this in DI", or "add these translation keys" in a Flutter project all mean this skill applies.
---

# Flutter Clean Architecture + GetX — Developer Skill

Use this skill before implementing any feature or modifying existing code in a Flutter project following Clean Architecture with GetX.

---

## Project Conventions at a Glance

- **State management**: GetX (`get` package)
- **DI container**: `get_it` — global instance in `lib/injection.dart`
- **Architecture**: Clean Architecture — data / domain / presentation per feature
- **Result type**: `ResultOf<T, Failure>` from `multiple_result` package
- **Localization**: `easy_localization` — keys auto-generated into `lib/generated/locale_keys.g.dart`
- **HTTP client**: Dio, pre-configured clients in `lib/app/core/network/http/api_client.dart`

> **Adapting to a new project**: Check whether the DI instance is named `dp`, `sl`, `getIt`, etc. Check the script names for code gen and running the app. Everything else in this skill applies directly.

---

## Feature Folder Structure

Every feature lives under `lib/app/features/<feature_name>/` with exactly this shape:

```text
feature_name/
├── data/
│   ├── datasources/        # abstract interface + RemoteImpl using Dio
│   ├── models/             # JSON models extending entity (_model.dart suffix)
│   └── repositories/       # repository implementations
├── domain/
│   ├── entities/           # pure Dart entities (_entity.dart suffix), Equatable
│   ├── repositories/       # repository interfaces (abstract classes)
│   └── usecases/           # use cases returning ResultOf<T, Failure>
└── presentation/
    ├── getx/
    │   ├── bindings/       # Bindings subclass — wires DI for this route
    │   └── controllers/    # GetxController subclasses
    ├── pages/              # GetView<Controller> pages
    └── widgets/            # feature-specific widgets (always classes, never functions)
```

Shared/reusable code (used by multiple features) goes in `lib/app/share/`.

---

## Layer-by-Layer Patterns

### 1. Entity (domain layer)

```dart
// lib/app/features/foo/domain/entities/foo_entity.dart
import 'package:equatable/equatable.dart';

class FooEntity extends Equatable {
  final String id;
  final String name;
  final int status;
  final DateTime createdAt;

  const FooEntity({
    required this.id,
    required this.name,
    required this.status,
    required this.createdAt,
  });

  // Computed business logic getters belong here, NOT in the controller
  bool get isActive => status == 1;

  // Always provide copyWith
  FooEntity copyWith({
    String? id,
    String? name,
    int? status,
    DateTime? createdAt,
  }) =>
      FooEntity(
        id: id ?? this.id,
        name: name ?? this.name,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  List<Object?> get props => [id, name, status, createdAt];
}
```

**Rules:**

- Pure Dart — no Flutter/Dio imports ever
- Always `extends Equatable`, always list every field in `props`
- Computed getters for derived business logic belong here, NOT in the controller

---

### 2. Model (data layer)

```dart
// lib/app/features/foo/data/models/foo_model.dart
import '../../domain/entities/foo_entity.dart';

class FooModel extends FooEntity {
  const FooModel({
    required super.id,
    required super.name,
    required super.status,
    required super.createdAt,
  });

  factory FooModel.fromJson(Map<String, dynamic> json) => FooModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        status: json['status'] as int? ?? 0,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
      };
}
```

**Rules:**

- Always `extends FooEntity` — the model IS-A entity, no separate mapping step
- Defensive JSON parsing: `as Type? ?? defaultValue` for every field
- Use `DateTime.tryParse(...) ?? DateTime.now()` for date fields

---

### 3. DataSource (data layer)

```dart
// lib/app/features/foo/data/datasources/foo_datasource.dart
import 'package:dio/dio.dart';
import '../../../../core/network/http/api_path.dart';
import '../models/foo_model.dart';

abstract class FooDataSource {
  Future<FooModel> getFoo({required String id});
  Future<List<FooModel>> getFoos();
}

class FooRemoteDataSource implements FooDataSource {
  final Dio client;

  FooRemoteDataSource({required this.client});

  @override
  Future<FooModel> getFoo({required String id}) async {
    final res = await client.get('${ApiPath.fooPath}/$id');
    if (res.statusCode == 200) {
      return FooModel.fromJson(res.data['result']);
    }
    throw Exception('Failed to load foo');
  }

  @override
  Future<List<FooModel>> getFoos() async {
    final res = await client.get(ApiPath.fooPath);
    if (res.statusCode == 200) {
      return (res.data['result'] as List)
          .map((e) => FooModel.fromJson(e))
          .toList();
    }
    throw Exception('Failed to load foos');
  }
}
```

**Rules:**

- Always define an abstract interface, then a concrete `RemoteImpl`
- Use `ApiClient.authenticatedClient` for auth-required endpoints, `ApiClient.publicClient` for public
- Response payload is typically at `res.data['result']`
- Throw `Exception` here — the repository layer converts it to `Failure`

---

### 4. Repository Interface (domain layer)

```dart
// lib/app/features/foo/domain/repositories/foo_repository.dart
import 'package:multiple_result/multiple_result.dart';
import '../../../../core/error/failures.dart';
import '../entities/foo_entity.dart';

abstract class FooRepository {
  Future<ResultOf<FooEntity, Failure>> getFoo({required String id});
  Future<ResultOf<List<FooEntity>, Failure>> getFoos();
}
```

---

### 5. Repository Implementation (data layer)

```dart
// lib/app/features/foo/data/repositories/foo_repository_impl.dart
import 'package:dio/dio.dart';
import 'package:multiple_result/multiple_result.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../datasources/foo_datasource.dart';
import '../../domain/entities/foo_entity.dart';
import '../../domain/repositories/foo_repository.dart';

class FooRepositoryImpl implements FooRepository {
  final FooDataSource dataSource;

  FooRepositoryImpl({required this.dataSource});

  @override
  Future<ResultOf<FooEntity, Failure>> getFoo({required String id}) async {
    try {
      final model = await dataSource.getFoo(id: id);
      return Success(model as FooEntity);
    } on ServerException {
      return Error(ServerFailure());
    } on DioException catch (e) {
      return Error(ApiFailure(e));
    } catch (e) {
      return Error(UnHandleFailure(e));
    }
  }

  @override
  Future<ResultOf<List<FooEntity>, Failure>> getFoos() async {
    try {
      final models = await dataSource.getFoos();
      return Success(models.map((m) => m as FooEntity).toList());
    } on ServerException {
      return Error(ServerFailure());
    } on DioException catch (e) {
      return Error(ApiFailure(e));
    } catch (e) {
      return Error(UnHandleFailure(e));
    }
  }
}
```

**Rules:**

- Always catch in this exact order: `ServerException` → `DioException` → generic `catch`
- `DioException` maps to `ApiFailure(e)` which auto-maps to typed failures by HTTP status:
  - 401 → `UnAuthorizedFailure`
  - 404 → `DataNotFoundFailure`
  - 400 → `BadRequestFailure`
  - 409 → `ConflictFailure`
  - 500 → `ServerFailure`
  - other → `UnHandleFailure`
- Cast `model as FooEntity` — safe because model extends entity

---

### 6. UseCase (domain layer)

**Style A — extends `UseCase<T, Params>` (simple/no-param calls):**

```dart
// lib/app/features/foo/domain/usecases/get_foo_usecase.dart
import 'package:equatable/equatable.dart';
import 'package:multiple_result/multiple_result.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/foo_entity.dart';
import '../repositories/foo_repository.dart';

class GetFooUseCase extends UseCase<FooEntity, GetFooParams> {
  final FooRepository repository;

  GetFooUseCase(this.repository);

  @override
  Future<ResultOf<FooEntity, Failure>> call(GetFooParams params) =>
      repository.getFoo(id: params.id);
}

class GetFooParams extends Equatable {
  final String id;

  const GetFooParams({required this.id});

  @override
  List<Object?> get props => [id];
}
```

**Style B — plain class with named constructor (preferred for multi-param usecases):**

```dart
class GetFoosParams extends Equatable {
  final int page;
  final int perpage;

  const GetFoosParams({required this.page, required this.perpage});

  @override
  List<Object?> get props => [page, perpage];
}

class GetFoosUseCase {
  final FooRepository repository;

  GetFoosUseCase({required this.repository});

  Future<ResultOf<List<FooEntity>, Failure>> call(GetFoosParams params) =>
      repository.getFoos();
}
```

Use `NoParams()` from `usecase.dart` when the call takes no parameters.

---

### 7. Binding (presentation layer)

```dart
// lib/app/features/foo/presentation/getx/bindings/foo_binding.dart
import 'package:get/get.dart';
import '../../../../../../injection.dart';
import '../../../domain/usecases/get_foos_usecase.dart';
import '../controllers/foo_controller.dart';

class FooBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FooController>(() => FooController(
          getFoosUseCase: dp.get<GetFoosUseCase>(),
        ));
  }
}
```

**Rules:**

- Always `Get.lazyPut` — never `Get.put`
- Use `dp.get<T>()` (or `dp<T>()`) to resolve use cases from `lib/injection.dart`
- One binding per page/route
- If no use cases needed: `Get.lazyPut<FooController>(() => FooController())`

---

### 8. Controller (presentation layer)

```dart
// lib/app/features/foo/presentation/getx/controllers/foo_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../core/utils/dialog_helper.dart';
import '../../../../../navigation/routes.dart';
import '../../../domain/entities/foo_entity.dart';
import '../../../domain/usecases/get_foos_usecase.dart';

class FooController extends GetxController {
  // ALWAYS include this static accessor
  static FooController get to => Get.find();

  final GetFoosUseCase _getFoosUseCase;

  // Reactive state
  final foos = <FooEntity>[].obs;
  final isLoading = false.obs;
  final errorMessage = ''.obs;

  FooController({required GetFoosUseCase getFoosUseCase})
      : _getFoosUseCase = getFoosUseCase;

  @override
  void onInit() {
    super.onInit();
    fetchFoos();
  }

  Future<void> fetchFoos() async {
    isLoading.value = true;
    errorMessage.value = '';

    final result = await _getFoosUseCase(
      const GetFoosParams(page: 1, perpage: 20),
    );

    isLoading.value = false;
    result.when(
      (data) => foos.assignAll(data),
      (failure) => errorMessage.value = failure.message,
    );
  }

  // For actions that show a loading dialog:
  Future<void> doAction(BuildContext context) async {
    DialogHelper.showLoadingDialog(context);
    final result = await _getFoosUseCase(
      const GetFoosParams(page: 1, perpage: 20),
    );
    DialogHelper.dismissDialog(context);

    result.when(
      (data) => DialogHelper.showSuccessDialog(
        context,
        title: 'Success',
        message: 'Done',
      ),
      (failure) => DialogHelper.showErrorDialog(
        context,
        'Error',
        failure.message,
      ),
    );
  }

  void goToDetail(String id) =>
      Get.toNamed(Routes.fooDetail, arguments: id);
}
```

**Rules:**

- Always include `static FooController get to => Get.find();`
- Reactive vars: `''.obs`, `false.obs`, `<T>[].obs`, `Rxn<T>()` for nullable
- Use `result.when(success, error)` for inline handling
- Use `result.tryGetSuccess()` / `result.tryGetError()` when conditional access is needed
- Call `super.onInit()` FIRST, `super.onClose()` LAST
- Dispose non-GetX controllers (e.g. `PagingController`, `TextEditingController`) in `onClose()`
- Access sibling controllers via `OtherController.to` — never `Get.find<T>()` inline

---

### 9. Page (presentation layer)

```dart
// lib/app/features/foo/presentation/pages/foo_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../../generated/locale_keys.g.dart';
import '../getx/controllers/foo_controller.dart';

class FooPage extends GetView<FooController> {
  const FooPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.foo_title.tr),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.value.isNotEmpty) {
          return Center(child: Text(controller.errorMessage.value));
        }
        return ListView.builder(
          itemCount: controller.foos.length,
          itemBuilder: (_, i) => FooCard(foo: controller.foos[i]),
        );
      }),
    );
  }
}
```

**Rules:**

- Always `extends GetView<FooController>` — gives `controller` accessor for free
- Wrap reactive UI in `Obx(() => ...)`
- Never hardcode user-visible strings — always use `LocaleKeys.xxx.tr`

---

### 10. Widget (presentation layer)

```dart
// lib/app/features/foo/presentation/widgets/foo_card.dart
import 'package:flutter/material.dart';
import '../../../domain/entities/foo_entity.dart';

class FooCard extends StatelessWidget {
  final FooEntity foo;

  const FooCard({super.key, required this.foo});

  @override
  Widget build(BuildContext context) {
    return Card(child: Text(foo.name));
  }
}
```

**Rules:**

- ALWAYS a class — never a function or method returning `Widget`
- `const` constructors wherever possible
- Feature widgets go in `presentation/widgets/`
- Shared/reusable widgets go in `lib/app/share/widgets/`

---

## DI Registration (`lib/injection.dart`)

Add ALL new registrations in this order inside `dpInit()`:

```dart
// 1. DataSource
dp.registerLazySingleton<FooDataSource>(
  () => FooRemoteDataSource(client: ApiClient.authenticatedClient),
);

// 2. Repository
dp.registerLazySingleton<FooRepository>(
  () => FooRepositoryImpl(dataSource: dp()),
);

// 3. UseCases
dp.registerLazySingleton(
  () => GetFooUseCase(repository: dp()),
);
dp.registerLazySingleton(
  () => GetFoosUseCase(repository: dp()),
);
```

`dp()` is shorthand for `dp.get()` — get_it infers the type from the constructor parameter.

---

## API Paths

Add new endpoints to `lib/app/core/network/http/api_path.dart`:

```dart
abstract class ApiPath {
  // ... existing paths
  static const String fooPath = '/foo';
  static const String fooDetailPath = '/foo/detail';
}
```

---

## Navigation

**Step 1** — Add the route constant to `lib/app/navigation/routes.dart`:

```dart
static const foo = "/foo";
static const fooDetail = "/foo/detail";
```

**Step 2** — Register the page with its binding in `lib/app/navigation/pages.dart`:

```dart
GetPage(
  name: Routes.foo,
  page: () => const FooPage(),
  binding: FooBinding(),
),
```

**Step 3** — Navigate:

```dart
Get.toNamed(Routes.foo);                           // push
Get.toNamed(Routes.foo, arguments: someData);      // push with args
Get.offNamed(Routes.foo);                          // replace current
Get.offAllNamed(Routes.foo);                       // clear stack
```

Receive args in `onInit()`:

```dart
@override
void onInit() {
  super.onInit();
  final data = Get.arguments as FooPassData;
}
```

---

## Localization

**Step 1** — Add keys to all three translation files:

```json
{
  "foo": {
    "title": "Foo List",
    "empty": "No items found"
  }
}
```

Files to edit:

- `assets/translations/en-US.json`
- `assets/translations/lo-LA.json`
- `assets/translations/th-TH.json`

**Step 2** — Regenerate locale keys:

```bash
./gen.sh locale
```

**Step 3** — Use in Dart:

```dart
// Nested key "foo.title" becomes LocaleKeys.foo_title
Text(LocaleKeys.foo_title.tr)            // in widget
context.tr(LocaleKeys.foo_title)         // also in widget
tr(LocaleKeys.foo_title)                 // in controller (no BuildContext)
```

---

## More Result & Dialog Patterns

The Controller section above covers the common case: `result.when(success, error)` after a loading dialog. Two less-common variants:

```dart
// Awaiting an async success branch
await result.when(
  (data) async { /* async success */ },
  (failure) { /* error */ },
);

// Conditional access instead of branching immediately
final data = result.tryGetSuccess();
final failure = result.tryGetError();
if (data != null) { /* ... */ }
```

```dart
// Confirmation dialog before running a use case
await DialogHelper.showQuestionDialog(
  context: context,
  title: '...',
  description: '...',
  btnOkText: '...',
  btnOkOnPress: () { confirmed = true; },
  btnCancelText: '...',
  dismissOnTouchOutside: false,
);
```

---

## Common Utilities Reference

| Utility | Purpose |
| --- | --- |
| `DialogHelper.showLoadingDialog(context)` | Spinner during async ops |
| `DialogHelper.dismissDialog(context)` | Dismiss spinner |
| `DialogHelper.showSuccessDialog(...)` | Success confirmation |
| `DialogHelper.showErrorDialog(...)` | Error display |
| `DialogHelper.showQuestionDialog(...)` | Yes/No confirmation |
| `ApiClient.authenticatedClient` | Dio with auth/refresh interceptors |
| `ApiClient.publicClient` | Dio without auth |
| `ApiClient.alternativeClient` | Dio with alternate base URL |
| `FetchState` enum | idle / loading / success / error states |

---

## Common Pitfalls

1. **Forgot `lib/injection.dart` registration** — crashes at runtime with `StateError: Instance not found`.
2. **Forgot `./gen.sh locale`** — compile error on `LocaleKeys.xxx` after adding translations.
3. **Widget as function** — causes rebuild issues and hot reload problems. Always use a class.
4. **Missing `static get to`** — sibling controllers cannot access this controller.
5. **Reading `Get.arguments` in `build()`** — read it in `onInit()`. `build()` can run multiple times.
6. **`ApiFailure` message vs typed failure** — `ApiFailure.message` is raw JSON. Call `.failure.message` to get the human-readable message from the typed sub-failure.
7. **`dp()` type ambiguity** — if get_it cannot infer the type, use explicit `dp.get<FooRepository>()`.
8. **Accessing `SomeController.to` before its binding** — a controller is only registered when its route's binding runs. Never access `.to` from a route loaded before the target feature.

---

## Checklist for a New Feature

- [ ] Create folder structure: `data/`, `domain/`, `presentation/`
- [ ] Write entity — Equatable, const constructor, copyWith, props
- [ ] Write model — extends entity, defensive `fromJson`, `toJson`
- [ ] Write datasource abstract interface + `RemoteImpl`
- [ ] Add API path constant to `ApiPath`
- [ ] Write repository interface (domain)
- [ ] Write repository impl (data) — exact catch order: ServerException → DioException → catch
- [ ] Write use case(s) with Equatable params class
- [ ] Register datasource → repository → usecases in `lib/injection.dart`
- [ ] Write controller — `static get to`, reactive `.obs` vars, `onInit`, `result.when`
- [ ] Write binding — `Get.lazyPut` with `dp.get<UseCase>()`
- [ ] Write page — `GetView<Controller>`, `Obx` around reactive sections
- [ ] Write widgets as classes with `const` constructors
- [ ] Add route constant to `Routes`
- [ ] Register `GetPage` with binding in `pages.dart`
- [ ] Add translation keys to all 3 JSON files → run `./gen.sh locale`
- [ ] Run `flutter analyze` — zero issues before commit
- [ ] Run `dart format .` before committing
