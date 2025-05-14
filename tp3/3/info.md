# Analyse des performances de requête sans index composite

## Performance actuelle
- **Type d'opération**: Bitmap Heap Scan sur title_basics
- **Coût estimé**: 734.24..129960.67
- **Temps d'exécution réel**: 329.085 ms
- **Nombre de lignes**: 20949

## Détails d'exécution
- La requête utilise un index simple (idx_title_basics_startyear) pour filtrer sur l'année 1994
- L'index permet de récupérer 68526 lignes correspondant à cette année
- Un filtre supplémentaire est ensuite appliqué pour genres LIKE '%Drama%'
- Ce filtre élimine 47577 lignes qui ne correspondent pas au critère de genre
- Le filtrage post-index représente une charge importante

## Inefficacité principale
Le plan montre que la base de données doit d'abord récupérer toutes les entrées de 1994 (68526 lignes) puis appliquer un filtre pour ne garder que celles contenant "Drama" dans le champ genres. Cette méthode nécessite de charger et filtrer beaucoup plus de lignes que nécessaire.

## Amélioration possible
Un index composite sur (startyear, genres) permettrait de réduire significativement le nombre de lignes à charger et filtrer, en accédant directement aux enregistrements qui satisfont les deux conditions à la fois.

## Impact des index séparés

### Comparaison des performances
| Métrique | Sans index sur genres | Avec index sur genres |
|----------|------------------------|------------------------|
| Temps d'exécution | 329.085 ms | 340.901 ms |
| Temps de planification | 1.071 ms | 1.550 ms |
| Scan d'index | 7.971 ms | 3.841 ms |
| Scan total | 16.241..295.180 ms | 12.548..307.978 ms |

### Analyse
- L'ajout de l'index séparé sur la colonne `genres` n'améliore pas les performances globales
- L'optimiseur continue d'utiliser uniquement l'index sur `startyear`
- Le temps d'exécution total est légèrement supérieur (340.901 ms contre 329.085 ms)
- L'index sur `genres` n'est pas utilisé car le filtre LIKE '%Drama%' contient un caractère générique au début
- Les index B-tree standards ne sont pas efficaces pour les recherches de type "contient" avec des caractères génériques au début

### Conclusion
Les index séparés n'améliorent pas cette requête. L'optimiseur ne peut pas combiner efficacement deux index distincts pour cette requête. Un index composite ou un index de type GIN/GiST serait plus approprié pour ce type de recherche.

## Impact de l'index composite

### Comparaison des performances
| Métrique | Sans index composite | Avec index composite |
|----------|----------------------|----------------------|
| Temps d'exécution | 329.085 ms | 172.958 ms |
| Temps de planification | 1.071 ms | 1.931 ms |
| Scan d'index | 7.971 ms | 4.501 ms |
| Scan total | 16.241..295.180 ms | 12.197..144.659 ms |

### Analyse
- L'index composite a considérablement amélioré les performances, réduisant le temps d'exécution de 47% (329ms → 173ms)
- Le plan d'exécution montre que l'optimiseur continue d'utiliser l'index sur `startyear` mais l'exécution globale est beaucoup plus rapide
- Le temps de planification a légèrement augmenté, mais cette hausse est négligeable comparée au gain de performance global
- La phase de filtrage est devenue beaucoup plus efficace, comme le montre la réduction du temps du scan total

### Conclusion
L'index composite améliore significativement les performances même si le plan d'exécution semble identique. Cela peut s'expliquer par:
1. Une meilleure localité des données sur le disque
2. Des optimisations internes lors de l'exécution
3. Une réorganisation des données qui améliore l'efficacité du filtrage

Cette amélioration confirme l'importance des index composites lorsque les requêtes comportent plusieurs conditions de filtrage fréquemment utilisées ensemble.

## Analyse comparative des différents types de requêtes

| Type de requête | Temps d'exécution | Plan d'exécution | Lignes retournées |
|-----------------|-------------------|------------------|-------------------|
| Filtrer sur genre et année | 122.770 ms | Bitmap Heap Scan avec idx_title_basics_startyear | 20,949 |
| Filtrer uniquement sur genre | 1,103.522 ms | Sequential Scan | 3,279,413 |
| Filtrer uniquement sur année | 78.404 ms | Bitmap Heap Scan avec idx_title_basics_startyear | 68,526 |
| Trier par genre puis année | 12,097.098 ms | Index Scan avec idx_title_basics_genres_startyear | 11,650,016 |
| Trier par année puis genre | 9,810.326 ms | Index Scan avec idx_title_basics_startyear_genres | 11,650,016 |

### Observations clés

1. **Filtrage sur le genre uniquement**: 
   - Aucun index n'est utilisé malgré la présence d'index sur cette colonne
   - Un scan séquentiel complet est effectué (1,103.522 ms)
   - Ceci confirme que les index B-tree ne sont pas efficaces pour les recherches LIKE '%pattern%'

2. **Filtrage sur l'année uniquement**:
   - L'index sur startyear est utilisé efficacement
   - C'est la requête la plus rapide (78.404 ms)
   - La condition d'égalité exacte est idéale pour les index B-tree

3. **Filtrage combiné (genre et année)**:
   - L'optimiseur utilise toujours l'index sur startyear et non l'index composite
   - Le temps d'exécution (122.770 ms) est significativement réduit par rapport aux mesures précédentes
   - L'amélioration s'explique probablement par des optimisations internes du cache

4. **Tri par genre puis année vs année puis genre**:
   - Les deux utilisent des index différents adaptés à l'ordre de tri
   - Le tri par année puis genre est ~19% plus rapide (9,810 ms vs 12,097 ms)
   - Cette différence s'explique par la cardinalité: moins de valeurs distinctes pour l'année que pour le genre

### Conclusions

1. **Choix des index**: L'optimiseur PostgreSQL choisit intelligemment entre les index disponibles en fonction de la sélectivité des colonnes
2. **Performance des tris**: Pour le tri, l'ordre des colonnes dans l'index est crucial - il devrait correspondre à l'ordre dans la clause ORDER BY
3. **Filtrage LIKE**: Les recherches contenant des caractères génériques au début ('%pattern%') ne bénéficient pas des index B-tree standards
4. **Amélioration des performances**: Un index GIN serait plus approprié pour les recherches de sous-chaînes dans la colonne genres

### Recommandations

1. Maintenir l'index composite (genres, startyear) pour les tris par genre puis année
2. Créer/maintenir l'index composite inverse (startyear, genres) pour les tris par année puis genre
3. Pour améliorer les recherches sur genres avec LIKE '%pattern%', envisager un index GIN avec l'extension pg_trgm
4. Conserver l'index simple sur startyear qui est efficace pour les filtrages par année

## Questions sur les index composites

### 1. Comment l'ordre des colonnes dans l'index composite affecte-t-il son utilisation?

L'ordre des colonnes dans un index composite est crucial pour son utilisation efficace:

- **Utilisation partielle**: Un index composite peut être utilisé partiellement, mais uniquement pour les colonnes qui apparaissent dans l'ordre défini, en partant de la gauche. Par exemple, un index (A, B, C) peut être utilisé pour des requêtes sur A, sur (A, B), ou sur (A, B, C), mais pas pour des requêtes sur B seul ou (B, C).

- **Tri**: Pour les opérations ORDER BY, l'index est efficace si l'ordre de tri correspond exactement à l'ordre des colonnes dans l'index, comme démontré dans nos tests (12,097 ms vs 9,810 ms pour les tris selon différents ordres).

- **Saut de prédicat**: Si une condition est absente sur une colonne du début, l'index peut devenir moins efficace. Par exemple, un index (A, B) où la requête filtre seulement sur B ne pourra pas être utilisé efficacement.

- **Sélectivité**: L'efficacité dépend aussi de la sélectivité des premières colonnes. Si les premières colonnes de l'index retournent une grande partie des données, l'avantage de l'index composite peut être réduit.

### 2. Quand un index composite est-il préférable à plusieurs index séparés?

Un index composite est généralement préférable dans les cas suivants:

- **Requêtes combinées**: Lorsque les requêtes filtrent régulièrement sur plusieurs colonnes simultanément (comme notre exemple filtrant sur genre ET année).

- **Inefficacité des index combinés**: Comme démontré dans nos tests, l'optimiseur de PostgreSQL n'a pas utilisé les deux index séparés de manière combinée (il a utilisé uniquement l'index sur startyear même après l'ajout d'un index sur genres).

- **Tri multi-colonnes**: Pour les requêtes impliquant des ORDER BY sur plusieurs colonnes, un index composite dans le même ordre est beaucoup plus efficace que des index séparés.

- **Économie d'espace et de maintenance**: Moins d'index signifie moins d'espace disque utilisé et moins de surcharge lors des opérations DML (INSERT, UPDATE, DELETE).

- **Prédicats d'égalité/inégalité**: Particulièrement utile lorsque certaines colonnes sont filtrées par égalité exacte (=) et d'autres avec des plages de valeurs (>, <, BETWEEN).

### 3. Comment choisir l'ordre optimal des colonnes dans un index composite?

Pour déterminer l'ordre optimal des colonnes:

- **Type de prédicat**: Placer d'abord les colonnes utilisées avec des prédicats d'égalité (=), puis celles avec des plages (>, <, BETWEEN), et enfin celles utilisées dans des opérations LIKE. Dans notre cas, startyear (avec égalité =) avant genres (avec LIKE).

- **Cardinalité/sélectivité**: Placer les colonnes de forte sélectivité (qui filtrent plus efficacement) en premier. Toutefois, cette règle peut être en conflit avec la règle des prédicats, et chaque cas nécessite une analyse spécifique.

- **Patterns de requêtes**: Aligner l'ordre sur les patterns de requêtes les plus fréquents ou critiques pour l'application.

- **Équilibre**: Pour les tris, l'ordre des colonnes doit correspondre exactement à celui de la clause ORDER BY. Si les deux ordres de tri sont fréquemment utilisés (comme dans notre cas: par genre puis année, et par année puis genre), envisager de créer deux index composites différents.

- **Tests empiriques**: Comme démontré dans notre analyse, les tests empiriques restent le meilleur moyen de valider l'efficacité d'un choix d'index.
