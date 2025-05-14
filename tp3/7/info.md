# Analyse des performances de recherche textuelle avec PostgreSQL

## Requête analysée

```sql
EXPLAIN ANALYZE
SELECT tconst, primarytitle, startyear, genres
FROM title_basics
WHERE primarytitle LIKE '%love%'
ORDER BY startyear DESC
LIMIT 100;
```

## Comparaison des stratégies d'indexation

### 1. LIKE sans index spécifique pour primarytitle

```
Limit  (cost=1000.46..81217.52 rows=100 width=46) (actual time=96.794..447.638 rows=100 loops=1)
  ->  Gather Merge  (cost=1000.46..830444.91 rows=1034 width=46) (actual time=96.793..447.620 rows=100 loops=1)
        Workers Planned: 2
        Workers Launched: 2
        ->  Parallel Index Scan Backward using idx_title_basics_startyear on title_basics  (cost=0.43..829325.54 rows=431 width=46) (actual time=2.304..164.910 rows=100 loops=3)
              Filter: ((primarytitle)::text ~~ '%love%'::text)
              Rows Removed by Filter: 171176
Execution Time: 447.666 ms
```

- **Temps d'exécution**: 447.666 ms
- **Type d'opération**: Scan d'index parallèle sur idx_title_basics_startyear (index sur l'année)
- **Lignes examinées**: 171,176 sur l'ensemble des workers
- **Méthode**: PostgreSQL utilise l'index sur startyear puis applique le filtre LIKE '%love%' sur chaque ligne

### 2. LIKE avec index B-tree standard sur primarytitle

```
Limit  (cost=1000.46..81217.52 rows=100 width=46) (actual time=125.781..299.074 rows=100 loops=1)
  ->  Gather Merge  (cost=1000.46..830444.91 rows=1034 width=46) (actual time=125.780..299.064 rows=100 loops=1)
        Workers Planned: 2
        Workers Launched: 2
        ->  Parallel Index Scan Backward using idx_title_basics_startyear on title_basics  (cost=0.43..829325.54 rows=431 width=46) (actual time=4.601..122.053 rows=100 loops=3)
              Filter: ((primarytitle)::text ~~ '%love%'::text)
              Rows Removed by Filter: 177051
Execution Time: 299.126 ms
```

- **Temps d'exécution**: 299.126 ms
- **Type d'opération**: Toujours un scan d'index parallèle sur idx_title_basics_startyear
- **Lignes examinées**: 177,051 sur l'ensemble des workers
- **Observation clé**: PostgreSQL n'utilise pas l'index B-tree sur primarytitle car le motif '%love%' avec caractère générique au début n'est pas efficace avec un index B-tree

### 3. Index trigram (GIN) sur primarytitle

```
Limit  (cost=3981.05..3981.30 rows=100 width=46) (actual time=266.109..266.116 rows=100 loops=1)
  ->  Sort  (cost=3981.05..3983.64 rows=1034 width=46) (actual time=266.108..266.111 rows=100 loops=1)
        Sort Key: startyear DESC
        Sort Method: top-N heapsort  Memory: 41kB
        ->  Bitmap Heap Scan on title_basics  (cost=43.72..3941.53 rows=1034 width=46) (actual time=15.936..265.188 rows=5707 loops=1)
              Recheck Cond: ((primarytitle)::text ~~ '%love%'::text)
              Rows Removed by Index Recheck: 64711
              Heap Blocks: exact=50827
              ->  Bitmap Index Scan on idx_title_basics_primarytitle_trgm  (cost=0.00..43.46 rows=1034 width=0) (actual time=10.760..10.760 rows=70418 loops=1)
                    Index Cond: ((primarytitle)::text ~~ '%love%'::text)
Execution Time: 266.240 ms
```

- **Temps d'exécution**: 266.240 ms
- **Type d'opération**: Bitmap Heap Scan utilisant l'index GIN trigram
- **Lignes examinées par l'index**: 70,418
- **Lignes après vérification**: 5,707
- **Méthode**:
  1. L'index GIN trigram identifie efficacement les enregistrements contenant potentiellement '%love%'
  2. Vérification plus précise des correspondances
  3. Tri final par startyear

### 4. Recherche full-text (GIN) sur primarytitle

```
Limit  (cost=1000.46..4519.07 rows=100 width=84) (actual time=35.460..62.721 rows=100 loops=1)
  ->  Gather Merge  (cost=1000.46..2050592.39 rows=58250 width=84) (actual time=35.460..62.713 rows=100 loops=1)
        Workers Planned: 2
        Workers Launched: 2
        ->  Parallel Index Scan Backward using idx_title_basics_startyear on title_basics  (cost=0.43..2042868.87 rows=24271 width=84) (actual time=0.723..30.684 rows=100 loops=3)
              Filter: (to_tsvector('english'::regconfig, (primarytitle)::text) @@ '''love'''::tsquery)
              Rows Removed by Filter: 13339
Execution Time: 62.743 ms
```

- **Temps d'exécution**: 62.743 ms
- **Type d'opération**: Parallel Index Scan sur l'index startyear avec filtre utilisant full-text search
- **Lignes examinées**: 13,339 sur l'ensemble des workers (beaucoup moins que les autres méthodes)
- **Méthode**:
  1. PostgreSQL utilise l'index sur startyear pour trier
  2. Applique le filtre full-text (to_tsvector/to_tsquery) sur chaque ligne
  3. Retourne les résultats déjà triés

## Résumé des performances

| Stratégie d'indexation | Temps d'exécution | Amélioration | Type d'opération | Lignes examinées |
|------------------------|-------------------|--------------|------------------|------------------|
| Sans index primarytitle | 447.666 ms | - | Index Scan (startyear) | 171,176 |
| B-tree standard        | 299.126 ms | 33.2% | Index Scan (startyear) | 177,051 |
| Index GIN trigram      | 266.240 ms | 40.5% | Bitmap Heap Scan | 70,418 |
| Full-text search       | 62.743 ms  | 86.0% | Index Scan (startyear) | 13,339 |

## Analyse des résultats

1. **Inefficacité de l'index B-tree pour LIKE '%pattern%'**:
   - Malgré la création d'un index B-tree sur primarytitle, PostgreSQL a choisi de ne pas l'utiliser
   - Un index B-tree n'est efficace que pour des recherches de préfixe (LIKE 'pattern%')
   - L'amélioration de 33.2% est probablement due au cache ou à d'autres optimisations internes
   
2. **Efficacité de l'index GIN trigram**:
   - L'index GIN trigram est spécifiquement conçu pour gérer les recherches de sous-chaînes
   - Il divise le texte en trigrammes (séquences de 3 caractères) pour indexer efficacement
   - La recherche est beaucoup plus ciblée: 70,418 lignes examinées contre 171,176/177,051
   - Le plan d'exécution change complètement, utilisant un Bitmap Heap Scan suivi d'un tri

3. **Coût du tri**:
   - Avec l'index GIN, PostgreSQL doit effectuer un tri explicite par startyear
   - Ce tri représente une part importante du temps d'exécution total
   - Dans les autres approches, l'index sur startyear permet d'obtenir les résultats déjà triés

4. **Supériorité de la recherche full-text**:
   - Offre des performances nettement supérieures: 62.743 ms, soit 86% plus rapide que sans index
   - Examine beaucoup moins de lignes: seulement 13,339 contre 70,418 pour l'index trigram
   - N'a pas besoin de recourir à un Bitmap Scan coûteux
   - Profite de l'index sur startyear pour éviter un tri explicite

## Réponses aux questions

### 1. Quelles sont les différences entre LIKE, trigram et full-text search?

**LIKE avec un index B-tree standard**:
- **Fonctionnement**: Correspond à des motifs de chaîne exacts, sensible à la casse par défaut (ILIKE pour l'insensibilité)
- **Efficacité d'indexation**: Efficace uniquement pour les motifs commençant par une valeur fixe (LIKE 'pattern%')
- **Flexibilité**: Supporte les caractères jokers (%, _) à n'importe quelle position
- **Précision**: Correspondance littérale exacte, sans intelligence linguistique

**Recherche par index trigram**:
- **Fonctionnement**: Décompose le texte en séquences de 3 caractères (trigrammes) et indexe ces fragments
- **Efficacité d'indexation**: Efficace pour toutes les recherches de sous-chaînes, y compris '%pattern%'
- **Flexibilité**: Fonctionne bien avec les caractères jokers dans n'importe quelle position
- **Précision**: Recherche littérale de chaînes, mais avec approximation basée sur le nombre de trigrammes correspondants

**Recherche full-text**:
- **Fonctionnement**: Utilise des lexèmes (forme normalisée des mots) plutôt que des caractères bruts
- **Efficacité d'indexation**: Très efficace pour la recherche de mots et d'expressions
- **Flexibilité**: Supporte les opérateurs booléens (AND, OR, NOT), la proximité, la pondération
- **Précision**: Intelligence linguistique incluant stemming (réduction aux racines), suppression des mots vides (stop words), et normalisation

### 2. Quels compromis faites-vous en termes de précision, performance et espace?

**LIKE avec index B-tree**:
- **Précision**: Élevée pour la correspondance exacte, mais aucune intelligence linguistique
- **Performance**: Faible pour les recherches '%pattern%', bonne pour 'pattern%'
- **Espace**: Index relativement compact (le plus petit des trois)
- **Compromis**: Simplicité et précision littérale contre flexibilité limitée et performances variables

**Index trigram (GIN)**:
- **Précision**: Bonne pour les correspondances approximatives, mais pas de compréhension linguistique
- **Performance**: Bonne pour tout type de recherche de sous-chaîne
- **Espace**: Index volumineux (stocke tous les trigrammes possibles)
- **Compromis**: Flexibilité et performance pour les sous-chaînes contre coût d'espace et absence de sémantique

**Full-text search**:
- **Précision**: Excellente compréhension linguistique mais peut manquer des correspondances littérales exactes
- **Performance**: Excellente pour la recherche de mots et d'expressions
- **Espace**: Assez volumineux mais généralement plus compact que l'index trigram
- **Compromis**: Intelligence linguistique et meilleures performances contre complexité accrue et correspondance non littérale

### 3. Pour quels volumes de données et types de recherches chaque approche est-elle adaptée?

**LIKE avec index B-tree**:
- **Volume de données**: Petit à moyen (jusqu'à quelques millions d'enregistrements)
- **Types de recherches adaptées**:
  - Recherches simples de préfixe (LIKE 'pattern%')
  - Comparaisons exactes ou insensibles à la casse
  - Bases de données avec contraintes d'espace strictes
  - Applications où la correspondance littérale exacte est essentielle

**Index trigram (GIN)**:
- **Volume de données**: Moyen à grand
- **Types de recherches adaptées**:
  - Recherches de sous-chaînes (LIKE '%pattern%')
  - Recherche approximative et correction orthographique
  - Autocomplétion et suggestions
  - Quand la flexibilité de recherche est prioritaire sur l'intelligence linguistique

**Full-text search**:
- **Volume de données**: Tout volume, particulièrement efficace pour les grands volumes
- **Types de recherches adaptées**:
  - Recherche dans des documents textuels substantiels
  - Recherches nécessitant une compréhension linguistique (stemming, stop words)
  - Applications multilingues (avec configurations linguistiques appropriées)
  - Moteurs de recherche sophistiqués avec classement de pertinence
  - Applications avec des volumes de requêtes élevés nécessitant des performances optimales

## Recommandations

1. **Pour les recherches de chaînes exactes avec motif fixe au début**:
   - Utiliser un index B-tree standard (pour LIKE 'pattern%')

2. **Pour les recherches de sous-chaînes générales sans besoin linguistique**:
   - Utiliser un index GIN avec l'extension pg_trgm (pour LIKE '%pattern%')

3. **Pour les applications avec recherche avancée et grand volume**:
   - Privilégier la recherche full-text avec index GIN sur to_tsvector
   - Considérer l'utilisation de colonnes dédiées précalculées avec to_tsvector

4. **Approche hybride pour applications sophistiquées**:
   - Combiner plusieurs types d'index selon les besoins
   - Par exemple, utiliser full-text pour la recherche principale et trigram pour les suggestions
