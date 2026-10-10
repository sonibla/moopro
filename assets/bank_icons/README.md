# Bank icons

## Adding an icon

1. **Save** it as `assets/bank_icons/<id>.svg`. `<id>` is lowercase
   `a-z0-9_`, e.g. `ing`, `bnp_paribas`. The id is permanent — stored
   records reference it; never rename or reuse one.
2. **Register** it in `lib/widgets/bank_icons.dart` (`bankIconRegistry`,
   sorted by id): display name plus lowercase search `aliases`.

## Sources

https://companieslogo.com/
https://simpleicons.org