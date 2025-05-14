# Analyse des performances avec index B-tree standard et recherche insensible à la casse

## Problématique

Lorsqu'on effectue des recherches insensibles à la casse sur une colonne de texte (comme `primarytitle`), en utilisant des fonctions comme `LOWER()`, un index B-tree standard sur cette colonne n'est pas utilisé par l'optimiseur.

## Explication du problème

Notre requête actuelle utilise la fonction `LOWER()` :
```sql
SELECT *
FROM title_basics
WHERE LOWER(primarytitle) LIKE LOWER('%Star Wars%');
```

Si nous avons un index B-tree standard sur la colonne `primarytitle`, cet index **ne sera pas utilisé** car :

1. Les index B-tree standards indexent les valeurs exactes des colonnes
2. L'application d'une fonction (LOWER) sur la colonne empêche l'utilisation de l'index
3. PostgreSQL ne peut pas utiliser un index quand la colonne apparaît à l'intérieur d'une fonction dans la clause WHERE

## Performances attendues

Sans index adapté, cette requête entraîne :
- Un scan séquentiel complet de la table
- Des performances de recherche médiocres, particulièrement sur de grandes tables
- Une utilisation intensive des ressources (CPU, I/O)

## Solution : Index d'expression

Pour résoudre ce problème, nous devons créer un **index d'expression** qui indexe directement le résultat de la fonction LOWER() :

```sql
CREATE INDEX idx_title_basics_primarytitle_lower ON title_basics(LOWER(primarytitle));
```

## Comparaison des performances

| Métrique | Sans index d'expression | Avec index d'expression | Amélioration |
|----------|-------------------------|-------------------------|--------------|
| Temps d'exécution | 1261.079 ms | 1068.402 ms | 192.677 ms (15.3%) |
| Temps de planification | 0.895 ms | 0.557 ms | 0.338 ms (37.8%) |
| Type d'opération | Parallel Seq Scan | Parallel Seq Scan | Aucun changement |

## Analyse des résultats

Malgré la création d'un index d'expression sur LOWER(primarytitle), nous observons que:

1. **Le plan d'exécution reste inchangé**: PostgreSQL continue d'utiliser un scan séquentiel parallèle.
2. **Amélioration modeste**: Une réduction de 15.3% du temps d'exécution, bien que toujours supérieur à 1 seconde.
3. **Limitation fondamentale**: La présence du caractère générique en début de motif ('%star wars%') empêche l'utilisation efficace de l'index.

L'index d'expression n'est pas utilisé principalement parce que les recherches avec LIKE '%pattern%' ne peuvent pas efficacement exploiter un index B-tree. Un index B-tree est ordonné séquentiellement et ne peut être utilisé efficacement que pour les modèles qui commencent par une valeur fixe (comme 'pattern%').

## Recommandations

1. **Adapter la recherche si possible**: Utiliser 'Star Wars%' au lieu de '%Star Wars%' permettrait d'exploiter l'index.
2. **Utiliser un index GIN avec pg_trgm**: Pour les recherches qui nécessitent des caractères génériques au début:
   ```sql
   CREATE EXTENSION pg_trgm;
   CREATE INDEX idx_title_basics_trgm ON title_basics USING GIN (primarytitle gin_trgm_ops);
   ```
3. **Considérer la fréquence des requêtes**: Si ces recherches sont rares, le scan séquentiel peut être acceptable.
4. **Optimiser d'autres aspects**: Assurer que la table est correctement analysée (VACUUM ANALYZE) pour de meilleures estimations du planificateur.

## Questions sur les index d'expressions

### 1. Pourquoi l'expression dans la requête doit-elle correspondre exactement à celle de l'index?

L'expression dans la requête doit correspondre exactement à celle de l'index pour que l'optimiseur puisse l'utiliser car:

- PostgreSQL utilise la correspondance textuelle exacte pour identifier si un index est applicable
- Le planificateur de requêtes ne peut pas déterminer automatiquement l'équivalence mathématique ou logique de deux expressions différentes
- Les différences syntaxiques, même mineures (comme des parenthèses supplémentaires ou un ordre différent dans une fonction), empêchent l'utilisation de l'index
- Si l'expression ne correspond pas exactement, PostgreSQL exécutera l'expression pour chaque ligne lors d'un scan séquentiel au lieu d'utiliser l'index

Par exemple, si vous avez un index sur `LOWER(primarytitle)`, une requête utilisant `UPPER(LOWER(primarytitle))` ou même `lower(primarytitle)` avec une casse différente ne bénéficiera pas de l'index.

### 2. Quel est l'impact des index d'expressions sur les performances d'écriture?

Les index d'expressions ont un impact plus important sur les performances d'écriture que les index standards:

- **Coût de calcul supplémentaire**: Chaque insertion ou mise à jour nécessite d'évaluer l'expression pour la nouvelle valeur
- **Maintenance accrue**: L'index doit être mis à jour même si la modification ne change pas le résultat de l'expression
- **Opérations plus complexes**: Les transactions d'écriture prennent plus de temps car elles doivent recalculer et réindexer les valeurs d'expression
- **Impact sur le verrouillage**: Plus de temps passé à mettre à jour les index signifie plus de temps de verrouillage potentiel
- **Utilisation du CPU**: L'évaluation d'expressions complexes peut consommer significativement plus de ressources CPU

Ce coût supplémentaire augmente proportionnellement à la complexité de l'expression indexée.

### 3. Quels types de transformations sont souvent utilisés dans les index d'expressions?

Les transformations couramment utilisées dans les index d'expressions incluent:

- **Transformations de casse**: `LOWER()`, `UPPER()` pour les recherches insensibles à la casse
- **Extraction de parties de données**:
  - `SUBSTRING()` pour extraire des portions de texte
  - `EXTRACT(YEAR FROM date)` pour les champs de date
  - `SPLIT_PART()` pour diviser des chaînes selon un délimiteur
- **Calculs dérivés**:
  - `price * quantity` pour indexer un sous-total
  - `point[0]` et `point[1]` pour les coordonnées géographiques
- **Normalisations**:
  - `TRIM()` pour éliminer les espaces
  - `REPLACE()` pour standardiser des formats
- **Fonctions de hachage**: `MD5()` pour des recherches par empreinte
- **Opérations de conversion**: `CAST(numeric_col AS TEXT)` pour des comparaisons textuelles

Ces transformations permettent d'optimiser des motifs de requêtes spécifiques qui seraient autrement inefficaces avec des index traditionnels.