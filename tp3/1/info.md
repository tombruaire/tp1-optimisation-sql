# Analyse des performances avec index B-tree

## Comparaison des plans d'exécution

### Sans utilisation de l'index (output.txt)
- Temps d'exécution: 600.754 ms
- Temps de planification: 3.718 ms
- JIT Total: 29.128 ms
- Utilise un Parallel Seq Scan sur title_basics

### Après création de l'index (output2.txt)
- Temps d'exécution: 394.312 ms
- Temps de planification: 1.591 ms
- JIT Total: 8.823 ms
- Utilise toujours un Parallel Seq Scan sur title_basics

## Observations
Malgré la création d'un index B-tree sur la colonne primaryTitle, PostgreSQL continue d'utiliser un scan séquentiel parallèle au lieu d'un scan d'index pour la requête LIKE 'The%'. Cependant, des améliorations significatives de performance sont observées:

- Réduction du temps d'exécution de 34%
- Réduction du temps de planification de 57% 
- Réduction du temps de compilation JIT de 70%

## Explications possibles
1. La sélectivité de la requête est relativement faible (599,915 lignes retournées)
2. PostgreSQL a déterminé que pour ce volume de données, le scan séquentiel parallèle est plus efficace que l'utilisation de l'index
3. Les accès aléatoires requis par un scan d'index pourraient être plus coûteux que la lecture séquentielle pour cette requête
4. Le rapport entre le nombre de lignes retournées et le nombre total de lignes est trop élevé pour justifier l'utilisation de l'index

L'amélioration des performances sans utilisation de l'index pourrait être attribuée à une meilleure mise en cache des données ou à l'optimisation interne de PostgreSQL pour les requêtes répétées.

## Analyse des résultats des tests supplémentaires

### Résumé des performances par type d'opération

| Type d'opération | Plan d'exécution | Utilise l'index ? | Temps d'exécution |
|------------------|------------------|-------------------|-------------------|
| Préfixe (LIKE 'The%') | Parallel Seq Scan | Non | 609.261 ms |
| Égalité exacte (= 'The Godfather') | Bitmap Index Scan + Bitmap Heap Scan | Oui | 1.413 ms |
| Suffixe (LIKE '%The') | Parallel Seq Scan | Non | 311.754 ms |
| Sous-chaîne (LIKE '%The%') | Parallel Seq Scan | Non | 332.542 ms |
| Ordre (ORDER BY) | Index Scan | Oui | 1.859 ms |

### 1. Pour quels types d'opérations l'index B-tree est-il efficace?

L'index B-tree est particulièrement efficace pour:
- Les comparaisons d'égalité exacte (`WHERE primaryTitle = 'The Godfather'`): réduction drastique du temps d'exécution à 1.413 ms
- Les opérations de tri (`ORDER BY primaryTitle`): temps d'exécution de seulement 1.859 ms
- Ces deux types d'opérations utilisent directement l'index, comme indiqué dans le plan d'exécution

### 2. Pourquoi l'index n'est-il pas utilisé pour certaines opérations?

L'index B-tree n'est pas utilisé pour:
- Les recherches par préfixe avec nombreux résultats: bien que théoriquement possible, PostgreSQL a estimé qu'un scan séquentiel serait plus efficace vu le grand nombre de résultats (599,915 lignes)
- Les recherches par suffixe (`LIKE '%The'`): les index B-tree stockent les données dans un ordre lexicographique qui ne permet pas de rechercher efficacement les suffixes
- Les recherches par sous-chaîne (`LIKE '%The%'`): pour la même raison, les recherches contenant un caractère générique au début ne peuvent pas bénéficier de l'organisation hiérarchique d'un B-tree

### 3. Dans quels cas un index B-tree est-il le meilleur choix?

Un index B-tree est le meilleur choix dans les cas suivants:
- Recherches par égalité exacte (`WHERE col = valeur`)
- Recherches par intervalle (`WHERE col BETWEEN val1 AND val2`)
- Recherches par préfixe (`WHERE col LIKE 'préfixe%'`) avec une bonne sélectivité (peu de résultats)
- Opérations de tri (`ORDER BY col`)
- Recherches utilisant des opérateurs de comparaison (`>`, `<`, `>=`, `<=`)
- Jointures sur des colonnes indexées

Pour les recherches par suffixe ou sous-chaîne, d'autres types d'index comme GIN avec l'extension pg_trgm seraient plus appropriés.
