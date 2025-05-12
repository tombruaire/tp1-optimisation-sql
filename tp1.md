# IMDB Clone Database Specs

## Mesures de référence

### Configuration de l'environnement
- PostgreSQL 17
- Docker Container
- Aucun index supplémentaire au-delà des clés primaires
- Aucune optimisation de configuration PostgreSQL

### Mesures des temps d'exécution initiaux

| ## | Type de requête | Temps d'exécution | Nombre de lignes | Opérations coûteuses identifiées |
|---|----------------|-------------------|-----------------|----------------------------------|
| 1 | Requête basique sur title_basics | 699.362 ms | 438620 | Parallel Seq Scan sur title_basics |
| 2 | Jointure title_basics et title_ratings | 692.477 ms | 203156 | Parallel Seq Scan sur les deux tables et Hash Join |
| 3 | Jointure complexe à 3 tables | 929.280 ms | 100 | Nested Loop et Merge Join |
| 4 | Agrégation et regroupement | 450.651 ms | 21 | Sort, Parallel Hash Join et GroupAggregate |
| 5 | Recherche par titre avec LIKE | 371.342 ms | 7140 | Parallel Seq Scan avec filtre LIKE non optimisé |
| 6 | Requête sur title_principals (plus volumineuse) | 180.014 ms | 1000 | Parallel Seq Scan et Nested Loop |
| 7 | Requête sur title_akas (2e plus volumineuse) | 682.990 ms | 1000 | Parallel Seq Scan avec double filtre |
| 8 | Sous-requête | 60.014 ms | 2908 | Nested Loop et Sort |
| 9 | Filtrage complexe et tri | 201.333 ms | 100 | Nested Loop, Sort et Unique |
| 10 | Jointure avec sous-requête | 2545.356 ms | 74 | Parallel Seq Scan sur title_episode, Nested Loop et Memoize |

### Observations initiales

#### Requêtes les plus lentes
1. Requête #10 (Jointure avec sous-requête): 2545.356 ms - Plus lente de loin
2. Requête #3 (Jointure complexe à 3 tables): 929.280 ms
3. Requête #1 (Requête basique sur title_basics): 699.362 ms
4. Requête #7 (Requête sur title_akas): 682.990 ms
5. Requête #2 (Jointure title_basics et title_ratings): 692.477 ms

#### Opérations coûteuses identifiées
- Analyses séquentielles (Seq Scan) sur toutes les tables volumineuses
- Nested Loop joins sur des tables volumineuses
- Utilisation de LIKE avec motif commençant par '%' (non optimisable par index standard)
- Opérations de tri (Sort) sur des ensembles de résultats volumineux
- Sous-requêtes IN avec scan complet des tables

#### Causes probables des performances médiocres
- Analyses séquentielles (Seq Scan) sur des tables volumineuses
- Absence d'index adaptés aux requêtes fréquentes:
  - Aucun index sur startYear
  - Aucun index sur les colonnes de jointure
  - Aucun index pour les filtres fréquents (category, region, language)
- Jointures entre tables volumineuses sans stratégie optimisée
- Ordres/tris sur des colonnes non indexées
- Recherches textuelles avec LIKE sans index approprié (comme pg_trgm)
- Sous-requêtes qui forcent le scan complet des tables

### Plan d'optimisation à venir
1. Créer des index pour les colonnes fréquemment utilisées dans les filtres (WHERE):
   - title_basics(startYear)
   - title_basics(titleType)
   - title_basics(genres) - Envisager un index GIN pour la recherche de sous-chaînes
   - title_ratings(averageRating)
   - title_ratings(numVotes)
   - title_principals(category)
   - title_akas(region, language)

2. Créer des index pour les colonnes utilisées dans les jointures:
   - title_episode(parentTconst)

3. Optimiser les requêtes problématiques:
   - Réécrire la requête #10 pour éviter le scan complet
   - Utiliser des CTE (WITH) pour remplacer certaines sous-requêtes

4. Envisager l'utilisation d'index spécialisés:
   - Index GIN avec pg_trgm pour les recherches avec LIKE

5. Analyser les possibilités de partitionnement pour les tables volumineuses:
   - Partitionner title_principals par category
   - Partitionner title_basics par startYear ou titleType

### Instructions pour l'exécution des tests
1. Connectez-vous à la base de données : `docker exec -it postgres17 psql -U admin -d imdb_clone`
2. Exécutez chaque requête du fichier `sql/benchmark.sql` individuellement
3. Notez le temps d'exécution et les informations du plan d'exécution
4. Complétez ce document avec les résultats obtenus 


## Premières observations sur les performances

### Analyse des tables volumineuses

```
title_principals | 9519 MB    | 6733 MB    | 2787 MB
title_akas       | 5422 MB    | 3852 MB    | 1571 MB
title_basics     | 1699 MB    | 1348 MB    | 351 MB
name_basics      | 1628 MB    | 1194 MB    | 433 MB
title_crew       | 1044 MB    | 693 MB     | 351 MB
title_episode    | 772 MB     | 503 MB     | 270 MB
title_ratings    | 126 MB     | 78 MB      | 47 MB
```

Les données ci-dessus montrent clairement que les tables les plus volumineuses sont:
1. **title_principals** (9.5 GB): Cette table contient les relations entre films/séries et personnes (acteurs, réalisateurs, etc.)
2. **title_akas** (5.4 GB): Cette table contient les titres alternatifs dans différentes régions/langues
3. **title_basics** (1.7 GB): Cette table contient les informations de base sur les films/séries

La taille de ces tables explique en grande partie pourquoi les requêtes qui les interrogent sont particulièrement lentes, notamment lorsqu'elles impliquent des analyses séquentielles complètes.

### Observation des premières opérations coûteuses

D'après nos benchmarks, les opérations les plus coûteuses sont:

1. **Scans séquentiels (Seq Scan) sur des tables volumineuses**:
   - La requête #10 (2545.356 ms) effectue un scan séquentiel sur title_episode
   - La requête #3 (929.280 ms) implique des nested loops sur plusieurs tables volumineuses
   - La requête #1 (699.362 ms) effectue un scan séquentiel complet sur title_basics

2. **Jointures non optimisées**:
   - Les nested loops entre tables volumineuses sont particulièrement inefficaces
   - Les jointures sans index appropriés forcent PostgreSQL à scanner entièrement les tables

3. **Filtres textuels inefficaces**:
   - La recherche avec LIKE '%Star Wars%' force un scan séquentiel complet
   - Les filtres sur des colonnes comme genres (avec LIKE '%Action%') sont également coûteux

4. **Opérations de tri sur des ensembles volumineux**:
   - Les opérations ORDER BY sans index approprié nécessitent des tris en mémoire ou sur disque

5. **Sous-requêtes non optimisées**:
   - La requête #10 utilise une sous-requête IN qui force un scan complet

Observations importantes:
- Seuls les index de clé primaire existent, aucun index d'optimisation supplémentaire
- Des analyses séquentielles sont effectuées sur des tables très volumineuses
- Aucune utilisation d'index n'est enregistrée (toutes les valeurs idx_scan sont à 0)

### Hypothèses sur les optimisations possibles

Sur la base des observations précédentes, plusieurs pistes d'optimisation peuvent être envisagées:

1. **Création d'index stratégiques**:
   - Index sur les colonnes fréquemment utilisées pour les filtres (WHERE): startYear, titleType, category
   - Index sur les colonnes utilisées dans les jointures: tconst dans les différentes tables
   - Index sur title_episode(parentTconst) qui est utilisé dans la requête la plus lente

2. **Index spécialisés pour les recherches textuelles**:
   - Index GIN avec l'extension pg_trgm pour les recherches avec LIKE '%pattern%'
   - Index fonctionnels sur lower(primaryTitle) pour les recherches insensibles à la casse

3. **Optimisation des requêtes problématiques**:
   - Réécrire la requête #10 en utilisant des CTE (WITH) pour matérialiser les résultats intermédiaires
   - Optimiser les jointures pour éviter les nested loops entre tables volumineuses

4. **Partitionnement des tables volumineuses**:
   - Partitionner title_principals par category pourrait améliorer les requêtes sur les acteurs
   - Partitionner title_basics par startYear ou titleType pourrait accélérer les requêtes filtrées

5. **Configuration de PostgreSQL**:
   - Augmenter work_mem pour les opérations de tri et de hachage
   - Ajuster maintenance_work_mem pour les opérations de maintenance
   - Optimiser shared_buffers pour améliorer la mise en cache des données

6. **Matérialisation de vues fréquemment utilisées**:
   - Créer des vues matérialisées pour les jointures fréquentes entre title_basics et title_ratings

Ces optimisations devront être testées individuellement pour mesurer leur impact réel sur les performances des requêtes problématiques identifiées. 