## 1.5.2

- Fix crash when reading dynamic type converters.

## 1.5.1

- Support migrations from `moor_flutter` to `drift_sqflite` in the `migrate`
  command.

## 1.5.0

- Add `validateDatabaseSchema` extension to `api/migrations.dart`. It validates
  that the schema of a database at runtime matches what one would expect.
- Allow cascade operators in the query for Dart-defined views.

## 1.4.0

- Generator support for the `LIST()` feature introduced in drift 1.4.
- Fix imported views in `.drift` files not being available in all cases.

## 1.3.0

- Support `drift` version `1.3.x`.

## 1.2.1

- Support the latest `analyzer` and `analyzer_plugin` packages.

## 1.2.0

- Generate code needed to support streams of views.

## 1.1.1

- Improve error handling around custom row classes.

## 1.1.0

- Consider `drift`-named files when generating schema migrations ([#1486](https://github.com/simolus3/drift/issues/1486))
- Emit correct SQL code when using arrays with the `new_sql_code_generation`
  option in specific scenarios.
- Transform `.moor.dart` part files in the `migrate` command.

## 1.0.2

- Also transform `analysis_options.yaml` files in the `drift_dev migrate` command.

## 1.0.1

This is the initial release of the `drift_dev` package (formally known as `moor_generator`).
For an overview of old `moor` releases, see its [changelog](https://pub.dev/packages/moor_generator/changelog).
