# Analyse comparative des index Hash et B-tree sur la colonne tconst

## 1. Comparaison des temps d'exécution

### Résultats observés:

| Type d'index | Plan d'exécution | Temps d'exécution | Temps de planification |
|--------------|------------------|--------------------|------------------------|
| Index Primary Key (B-tree) | Index Scan using title_basics_pkey | 2.446 ms | 1.046 ms |
| Index Hash | Index Scan using idx_title_basics_tconst_hash | 0.142 ms | 1.133 ms |

**Analyse:**
- L'index Hash est environ 17 fois plus rapide (2.446 ms vs 0.142 ms) pour une recherche par égalité exacte
- Les temps de planification sont similaires (léger avantage pour l'index B-tree)
- Pour cette opération d'égalité simple, l'index Hash est nettement plus performant

## 2. Comparaison de la taille des index

Pour comparer la taille des index, exécutez la requête suivante:

```sql
SELECT pg_size_pretty(pg_indexes_size('title_basics')) AS total_index_size;
SELECT pg_size_pretty(pg_relation_size('idx_title_basics_tconst_hash')) AS hash_index_size;
SELECT pg_size_pretty(pg_relation_size('idx_title_basics_tconst_btree')) AS btree_index_size;
```

**Résultats obtenus:**
```
 total_index_size 
------------------
 1813 MB
(1 row)

 hash_index_size 
-----------------
 321 MB
(1 row)

 btree_index_size 
------------------
 350 MB
(1 row)
```

**Analyse des tailles:**
- L'index Hash est environ 8% plus petit que l'index B-tree (321 MB vs 350 MB)
- La différence de taille est moins importante que prévue, mais confirme que les index Hash sont généralement plus compacts
- Les deux index représentent une part significative du total des index de la table (1813 MB)

**Avantages observés:**
- Les index Hash sont plus compacts que les index B-tree pour des clés de même taille
- Les index Hash occupent moins d'espace disque car ils ne stockent pas les données de manière triée

## 3. Comparaison par type de recherche

### A. Recherche par égalité exacte (WHERE tconst = 'tt0068646')

- **Index Hash**: Extrêmement performant (0.142 ms) - cas d'utilisation idéal
- **Index B-tree**: Bon mais moins performant (2.446 ms)
- L'index Hash est optimisé pour ce type de recherche exacte avec une complexité théorique O(1)

### B. Recherche par plage (WHERE tconst BETWEEN 'tt0068600' AND 'tt0068700')

Pour tester cette comparaison, exécutez:

```sql
EXPLAIN ANALYZE
SELECT * FROM title_basics
WHERE tconst BETWEEN 'tt0068600' AND 'tt0068700';
```

**Prédiction des résultats:**
- L'index B-tree devrait être plus performant pour les recherches par plage
- L'index Hash ne peut pas être utilisé pour les recherches par plage car il ne maintient pas d'ordre
- PostgreSQL devra probablement effectuer un scan séquentiel ou utiliser l'index B-tree si disponible

## Conclusion

Les index Hash et B-tree ont des cas d'utilisation différents:

- **Index Hash**:
  - Avantages: Plus rapide pour les recherches par égalité exacte, généralement plus compact
  - Limitations: Ne supporte pas les recherches par plage, les opérateurs de comparaison, ou ORDER BY
  
- **Index B-tree**:
  - Avantages: Polyvalent, supporte les recherches par égalité, par plage, et les opérations ORDER BY
  - Limitations: Légèrement moins performant pour les recherches par égalité, occupe généralement plus d'espace

**Recommandation**:
- Si la colonne est uniquement utilisée pour des recherches par égalité exacte, un index Hash est préférable
- Si la colonne est utilisée pour différents types de recherches incluant des plages ou du tri, un index B-tree est nécessaire
- Pour une clé primaire qui peut être utilisée dans divers contextes, le B-tree reste le choix le plus flexible

## Réponses aux questions spécifiques

### 1. Quelles sont les différences de performance entre Hash et B-tree pour l'égalité exacte?

Pour les recherches par égalité exacte, l'index Hash présente des avantages significatifs par rapport à l'index B-tree:

- **Vitesse d'exécution**: L'index Hash est environ 17 fois plus rapide (0.142 ms contre 2.446 ms) pour notre requête de test
- **Complexité algorithmique**: L'index Hash offre une complexité théorique en O(1) pour les recherches par égalité, tandis que le B-tree a une complexité en O(log n)
- **Mécanisme d'accès**: L'index Hash calcule directement l'emplacement de la valeur recherchée grâce à une fonction de hachage, tandis que le B-tree nécessite plusieurs lectures pour naviguer dans sa structure arborescente
- **Constance des performances**: Les performances de l'index Hash restent relativement constantes quelle que soit la taille de la table, alors que les performances du B-tree se dégradent légèrement (de façon logarithmique) avec l'augmentation du volume de données

### 2. Pourquoi l'index Hash ne fonctionne-t-il pas pour les recherches par plage?

L'index Hash est fondamentalement incapable de gérer les recherches par plage pour plusieurs raisons:

- **Absence d'ordre**: Contrairement au B-tree qui maintient les clés dans un ordre lexicographique, l'index Hash distribue les valeurs de manière non ordonnée à travers la table de hachage
- **Fonctionnement de la fonction de hachage**: Une fonction de hachage transforme une valeur d'entrée en une valeur de hachage qui n'a aucune relation d'ordre avec la valeur originale (deux valeurs proches peuvent avoir des hachages très différents)
- **Impossibilité de localiser des plages**: Sans relation d'ordre, il est impossible de localiser efficacement une plage de valeurs - l'index Hash ne peut pas déterminer quelles entrées sont "proches" les unes des autres
- **Nécessité de parcours complet**: Pour une requête par plage utilisant un index Hash, PostgreSQL devrait examiner chaque entrée de la table de hachage, ce qui serait moins efficace qu'un scan séquentiel direct

### 3. Dans quel contexte précis privilégier un index Hash à un B-tree?

Un index Hash devrait être privilégié dans les contextes suivants:

- **Tables de jointure**: Pour les tables qui servent principalement à des jointures basées sur des égalités exactes (par exemple, tables de référence ou tables de jointure many-to-many)
- **Colonnes avec cardinalité élevée**: Pour les colonnes contenant de nombreuses valeurs uniques, comme les identifiants uniques ou les clés primaires
- **Requêtes exclusivement par égalité**: Lorsque la colonne n'est jamais utilisée pour des recherches par plage, des opérateurs de comparaison ou des tris
- **Colonnes immuables**: Pour les colonnes dont les valeurs ne changent pas ou très rarement (les index Hash sont moins efficaces pour les mises à jour fréquentes)
- **Optimisation ciblée**: Lorsque l'analyse des performances montre clairement que les recherches par égalité exacte sur une colonne constituent un goulot d'étranglement
- **Contraintes d'espace disque**: Dans les situations où l'optimisation de l'espace disque est prioritaire (l'index Hash est généralement plus compact)

À noter que depuis PostgreSQL 10, les index Hash sont durables et fiables en production, ce qui n'était pas le cas dans les versions antérieures.
