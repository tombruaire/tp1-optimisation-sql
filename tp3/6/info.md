# Analyse de l'Index Only Scan avec PostgreSQL

## Requête analysée

```sql
SELECT primarytitle, startyear
FROM title_basics
WHERE genres LIKE '%Action%'
AND startyear > 2000;
```

## Index créé

```sql
CREATE INDEX idx_title_basics_genres ON title_basics(genres);
```

## Vérification du plan d'exécution

D'après le fichier d'exécution `index_couvrants_request_output2.txt`, PostgreSQL n'utilise **PAS** d'Index Only Scan, ni même d'Index Scan standard:

```
Gather  (cost=1000.00..277610.20 rows=312856 width=24) (actual time=6.475..339.039 rows=332139 loops=1)
  Workers Planned: 2
  Workers Launched: 2
  ->  Parallel Seq Scan on title_basics  (cost=0.00..245324.60 rows=130357 width=24) (actual time=4.246..322.184 rows=110713 loops=3)
        Filter: (((genres)::text ~~ '%Action%'::text) AND (startyear > 2000))
        Rows Removed by Filter: 3772626
```

L'optimiseur a choisi d'utiliser un **Parallel Seq Scan** (scan séquentiel parallèle) de la table complète plutôt que d'utiliser l'index. Ce choix s'explique par:

1. **La condition LIKE avec préfixe générique**: La condition `genres LIKE '%Action%'` ne peut pas bénéficier efficacement d'un index B-tree standard car elle commence par un caractère générique.

2. **L'efficacité estimée**: PostgreSQL estime qu'un scan parallèle de la table est plus efficace que d'utiliser l'index puis d'accéder à la table pour les lignes correspondantes.

3. **Sélectivité**: La requête retourne un nombre significatif de lignes (332,139 sur environ 11,650,016), soit environ 2.85% des lignes, ce qui réduit l'avantage d'utiliser un index.

## Pourquoi un Index Only Scan n'est pas possible avec cet index

Un **Index Only Scan** est une opération d'optimisation où PostgreSQL peut récupérer toutes les données demandées directement depuis l'index, sans avoir à accéder à la table elle-même. Cependant, plusieurs conditions doivent être remplies:

1. **Toutes les colonnes demandées dans la clause SELECT doivent être incluses dans l'index**
2. Les conditions de filtrage doivent pouvoir utiliser l'index efficacement

Dans notre cas, l'index standard créé sur `genres` ne contient que cette colonne, alors que la requête demande `primarytitle` et `startyear`. PostgreSQL devrait donc:

1. Utiliser l'index pour trouver les lignes correspondant à `genres LIKE '%Action%'`
2. Accéder à la table pour récupérer les valeurs de `primarytitle` et `startyear` pour ces lignes
3. Filtrer davantage sur la condition `startyear > 2000`

Même si cette approche était choisie, ce serait un **Index Scan** suivi d'un accès à la table, et non un **Index Only Scan**.

## Performances actuelles

- **Temps d'exécution**: 358.249 ms
- **Temps de planification**: 1.243 ms
- **Lignes traitées**: 3,772,626 lignes filtrées pour obtenir 332,139 résultats
- **Type d'opération**: Parallel Seq Scan (scan séquentiel parallèle à 3 workers)

## Solution pour obtenir un Index Only Scan

Pour permettre un Index Only Scan pour cette requête, nous devrions:

1. **Créer un index couvrant** qui inclut toutes les colonnes nécessaires:
   ```sql
   CREATE INDEX idx_title_basics_covering ON title_basics(startyear) INCLUDE (primarytitle, genres);
   ```

2. **Modifier la requête** pour éviter LIKE avec préfixe générique:
   ```sql
   SELECT primarytitle, startyear
   FROM title_basics
   WHERE genres LIKE 'Action%'  -- Préfixe fixe, non générique
   AND startyear > 2000;
   ```

Alternativement, pour les recherches de sous-chaînes, un index GIN avec l'extension pg_trgm serait plus approprié:
```sql
CREATE EXTENSION pg_trgm;
CREATE INDEX idx_title_basics_genres_trgm ON title_basics USING GIN (genres gin_trgm_ops);
```

Cependant, même un index GIN ne permettrait pas un Index Only Scan car il faudrait toujours accéder à la table pour récupérer primarytitle et startyear.

## Comparaison des performances entre les différents types d'index

### 1. Sans aucun index

```
Gather  (cost=1000.00..277610.20 rows=312856 width=24) (actual time=4.537..442.037 rows=332139 loops=1)
[...]
Execution Time: 462.494 ms
```

- **Type d'opération**: Parallel Seq Scan
- **Temps d'exécution**: 462.494 ms
- **Temps de planification**: 0.580 ms

### 2. Avec index standard sur genres

```
Gather  (cost=1000.00..277610.20 rows=312856 width=24) (actual time=6.475..339.039 rows=332139 loops=1)
[...]
Execution Time: 358.249 ms
```

- **Type d'opération**: Toujours un Parallel Seq Scan (l'index n'est pas utilisé)
- **Temps d'exécution**: 358.249 ms (22.5% plus rapide que sans index)
- **Temps de planification**: 1.243 ms (plus lent car PostgreSQL évalue plus d'options)

### 3. Avec index couvrant sur startyear incluant primarytitle et genres

```
Gather  (cost=1000.00..277610.20 rows=312856 width=24) (actual time=5.203..299.908 rows=332139 loops=1)
[...]
Execution Time: 320.329 ms
```

- **Type d'opération**: Toujours un Parallel Seq Scan (l'index couvrant n'est pas utilisé pour un Index Only Scan)
- **Temps d'exécution**: 320.329 ms (30.7% plus rapide que sans index, 10.6% plus rapide qu'avec l'index standard)
- **Temps de planification**: 1.830 ms (le plus lent en raison de l'évaluation de plus d'options)

### Analyse de l'amélioration des performances

| Type d'index | Temps d'exécution | Amélioration vs. sans index | Type d'opération |
|--------------|-------------------|----------------------------|------------------|
| Aucun index  | 462.494 ms        | -                          | Parallel Seq Scan |
| Index standard | 358.249 ms      | 22.5%                      | Parallel Seq Scan |
| Index couvrant | 320.329 ms      | 30.7%                      | Parallel Seq Scan |

**Observations clés**:

1. **Aucun Index Only Scan**: PostgreSQL continue d'utiliser un scan séquentiel parallèle dans tous les cas, même avec des index disponibles.

2. **Amélioration sans utilisation d'index**: Malgré l'absence d'Index Scan ou d'Index Only Scan, les performances s'améliorent. Cela pourrait être dû à:
   - Une meilleure mise en cache des données
   - Des optimisations internes de PostgreSQL lors des exécutions répétées
   - Une meilleure utilisation des statistiques pour le planificateur

3. **Limitations persistantes**: La condition `LIKE '%Action%'` avec un caractère générique au début continue d'empêcher l'utilisation efficace des index B-tree.

## Questions sur les index couvrants

### 1. Qu'est-ce qu'un "Index Only Scan" et pourquoi est-il avantageux?

Un **Index Only Scan** est une stratégie d'exécution de requête dans laquelle PostgreSQL peut répondre à une requête en consultant **uniquement l'index**, sans avoir besoin d'accéder à la table elle-même. Pour qu'un Index Only Scan soit possible, deux conditions principales doivent être remplies:

1. **Toutes les colonnes** demandées dans la requête doivent être présentes dans l'index
2. Les conditions de filtrage doivent pouvoir être évaluées efficacement à l'aide de l'index

**Avantages du Index Only Scan:**

1. **Réduction drastique des I/O disque**: PostgreSQL n'a pas besoin d'accéder aux blocs de données de la table, uniquement aux blocs d'index qui sont généralement beaucoup moins nombreux.

2. **Performance accrue**: Les index sont généralement plus petits que les tables complètes et organisés de manière optimale, ce qui permet des accès plus rapides.

3. **Meilleure utilisation du cache**: Les index occupent moins d'espace en mémoire cache que les tables complètes, ce qui augmente les chances que toutes les données nécessaires soient déjà en mémoire.

4. **Réduction de la charge de travail**: Moins de données à charger et traiter signifie une charge CPU réduite.

5. **Visibilité optimisée**: PostgreSQL utilise une "carte de visibilité" pour déterminer rapidement si un accès à la table est nécessaire pour vérifier la visibilité MVCC, ce qui peut parfois permettre un Index Only Scan même pour des tables récemment modifiées.

Un Index Only Scan peut offrir des gains de performance de plusieurs ordres de grandeur par rapport à un scan de table complet ou même à un index scan standard, en particulier pour les requêtes qui n'extraient qu'un petit sous-ensemble de colonnes d'une grande table.

### 2. Quelle est la différence entre ajouter une colonne à l'index et l'inclure avec INCLUDE?

Il existe deux façons d'inclure des colonnes supplémentaires dans un index B-tree PostgreSQL:

1. **Ajouter comme clé d'index** (colonnes normales de l'index):
   ```sql
   CREATE INDEX idx ON table(key_col1, key_col2, additional_col);
   ```

2. **Utiliser la clause INCLUDE** (colonnes non-clés):
   ```sql
   CREATE INDEX idx ON table(key_col1, key_col2) INCLUDE (additional_col);
   ```

**Différences fondamentales:**

| Aspect | Ajout comme clé d'index | Inclusion avec INCLUDE |
|--------|-------------------------|------------------------|
| **Utilisation dans l'ordre** | Participe à l'ordre de tri de l'index | N'influence pas l'ordre de tri |
| **Utilisation pour filtrage** | Peut être utilisée dans les clauses WHERE | Ne peut pas être utilisée efficacement pour le filtrage |
| **Utilisation pour tri** | Peut être utilisée pour ORDER BY | Ne peut pas être utilisée pour ORDER BY |
| **Duplication** | Crée des entrées dupliquées si valeurs dupliquées | Ne crée pas d'entrées supplémentaires |
| **Taille d'index** | Généralement plus grand | Généralement plus petit pour les mêmes colonnes |
| **Maintien de l'index** | Plus coûteux (affecte l'ordre) | Moins coûteux (n'affecte pas l'ordre) |
| **Disponibilité pour Index Only Scan** | Disponible | Disponible |

**Avantages de l'utilisation de INCLUDE:**

1. **Index plus compacts**: L'index est généralement plus petit car les colonnes INCLUDE n'apparaissent qu'au niveau des feuilles de l'arbre B-tree, pas dans les nœuds internes.

2. **Performances d'insertion/mise à jour améliorées**: Moins d'impact sur la maintenance de l'index car les colonnes INCLUDE n'affectent pas l'ordre des entrées d'index.

3. **Soutient toujours l'Index Only Scan**: Les colonnes INCLUDE sont disponibles pour l'Index Only Scan, permettant les mêmes optimisations qu'avec des colonnes régulières d'index.

4. **Contournement des limitations de taille**: Permet d'inclure des données de grande taille ou des types de données qui ne seraient pas autorisés dans la partie clé de l'index.

**Quand utiliser INCLUDE:**
Utilisez INCLUDE pour les colonnes qui sont nécessaires uniquement pour l'Index Only Scan mais qui ne seront pas utilisées pour le filtrage ou le tri. C'est particulièrement utile pour les colonnes larges qui augmenteraient considérablement la taille de l'index si elles étaient incluses comme clés.

### 3. Quand privilégier un index couvrant par rapport à un index composite?

Un **index composite** est un index sur plusieurs colonnes, tandis qu'un **index couvrant** est tout index (simple ou composite) qui contient toutes les colonnes nécessaires pour répondre à une requête spécifique (permettant un Index Only Scan).

**Quand privilégier un index couvrant:**

1. **Requêtes SELECT sur un sous-ensemble limité de colonnes**: Lorsque vos requêtes les plus fréquentes ou critiques sélectionnent un petit nombre de colonnes spécifiques.

2. **Lecture intensive, faible écriture**: Pour les tables qui sont principalement lues avec peu de modifications, car les index couvrants peuvent être plus larges et donc plus coûteux à maintenir lors des mises à jour.

3. **Extraction de données volumineuses avec filtrage sélectif**: Lorsque vous devez extraire un grand volume de données provenant de quelques colonnes, après avoir filtré sur d'autres colonnes.

4. **Opérations d'agrégation sur des colonnes spécifiques**: Pour optimiser les requêtes avec des fonctions COUNT(), SUM(), AVG() sur un sous-ensemble de colonnes.

5. **Réutilisation de l'index pour plusieurs types de requêtes**: Quand un seul index peut servir à la fois au filtrage, tri et récupération de données.

**Quand privilégier un index composite simple:**

1. **Conditions multiples mais sélection de nombreuses colonnes**: Si vos requêtes filtrent sur plusieurs colonnes mais sélectionnent la majorité des colonnes de la table.

2. **Écriture intensive**: Pour les tables fréquemment mises à jour, car des index plus petits sont moins coûteux à maintenir.

3. **Contraintes d'espace**: Lorsque l'espace disque est limité et que vous devez optimiser la taille des index.

4. **Requêtes variées avec différentes colonnes**: Si différentes requêtes sélectionnent des ensembles différents de colonnes, il peut être préférable d'avoir plusieurs index composites ciblés plutôt qu'un seul grand index couvrant.

5. **Combinaison avec d'autres types d'index**: Lorsque vous avez besoin de fonctionnalités spécifiques comme les index GIN ou GiST pour certaines colonnes.

**Approche pragmatique:**
Dans la pratique, une bonne stratégie consiste souvent à commencer par des index composites sur les colonnes de filtrage et de tri les plus utilisées, puis à les étendre en index couvrants en ajoutant les colonnes nécessaires avec INCLUDE lorsque vous identifiez des requêtes fréquentes qui pourraient bénéficier d'un Index Only Scan.