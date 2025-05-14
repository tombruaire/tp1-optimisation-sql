# Analyse du plan d'exécution

## Avant index

### Éléments observés
- **Stratégie utilisée**: Parallel Sequential Scan
- **Nombre de lignes retournées**: 438,620
- **Nombre de lignes examinées puis rejetées**: 3,737,132
- **Temps d'exécution total**: 1708.356 ms

### Réponses aux questions

1. **Pourquoi PostgreSQL utilise-t-il un Parallel Sequential Scan?**  
   PostgreSQL utilise un Parallel Sequential Scan car il n'y a pas d'index sur la colonne "startyear". 
   La requête doit examiner toutes les lignes de la table pour trouver celles où startyear = 2020, et un scan séquentiel est la seule option dans ce cas.

2. **La parallélisation est-elle justifiée ici? Pourquoi?**  
   La parallélisation est justifiée car:
   - La table est volumineuse (plus de 4 millions de lignes au total)
   - L'opération de scan séquentiel est facilement parallélisable
   - Le plan montre 2 workers planifiés et lancés, divisant efficacement le travail

3. **Que représente la valeur "Rows Removed by Filter"?**  
   "Rows Removed by Filter" représente le nombre de lignes qui ont été lues pendant le scan mais qui ne correspondaient pas à la condition du filtre (startyear = 2020). Ces 3,737,132 lignes ont été examinées mais rejetées car elles ne satisfaisaient pas la condition WHERE.

## Après index

### Éléments observés
- **Stratégie utilisée**: Parallel Bitmap Heap Scan avec Bitmap Index Scan
- **Nombre de lignes retournées**: 438,620
- **Nombre de lignes examinées puis rejetées**: 672,361
- **Temps d'exécution total**: 309.741 ms

### Réponses aux questions

1. **Quelle stratégie PostgreSQL utilise-t-il maintenant et pourquoi?**  
   PostgreSQL utilise désormais un Bitmap Index Scan suivi d'un Parallel Bitmap Heap Scan. Cette stratégie est possible grâce à la création d'un index sur la colonne "startyear" (idx_title_basics_startyear). L'index permet d'identifier rapidement les lignes correspondant à startyear = 2020 sans parcourir séquentiellement toute la table.

2. **Comment fonctionne cette stratégie?**  
   Le Bitmap Index Scan consulte d'abord l'index pour créer une bitmap des blocs contenant des lignes correspondantes. Ensuite, le Bitmap Heap Scan lit ces blocs spécifiques pour extraire les données complètes des lignes. La parallélisation est appliquée à l'étape du Heap Scan pour accélérer le traitement.

3. **Quelle est la différence entre "Rows Removed by Filter" et "Rows Removed by Index Recheck"?**  
   "Rows Removed by Index Recheck" représente les lignes qui ont été initialement sélectionnées par l'index bitmap (qui peut être imprécis en raison de sa nature de bitmap) mais qui ne correspondaient pas à la condition lors de la vérification finale. Cette valeur est beaucoup plus faible (672,361) que les "Rows Removed by Filter" (3,737,132) du plan précédent.

## Comparaison des deux approches

```
| Critère | Avant index | Après index | Amélioration |
|---------|-------------|-------------|--------------|
| Stratégie | Parallel Sequential Scan | Parallel Bitmap Heap Scan + Bitmap Index Scan | Utilisation d'un index |
| Temps d'exécution | 1708.356 ms | 309.741 ms | 82% plus rapide |
| Lignes examinées puis rejetées | 3,737,132 | 672,361 | 82% de lectures inutiles évitées |
| Coût estimé | 1000.00..277712.45 | 5853.20..271519.11 | Coût de démarrage plus élevé mais coût total légèrement inférieur |
```

### Conclusion

L'ajout d'un index sur la colonne "startYear" a considérablement amélioré les performances de la requête, réduisant le temps d'exécution de 1708 ms à 310 ms environ. Cette amélioration est principalement due à la capacité de l'index à limiter le nombre de lignes à examiner, évitant ainsi un scan complet de la table. La stratégie basée sur l'index est particulièrement efficace pour ce type de requête où une petite portion des données (environ 10% des lignes) correspond au critère de recherche.

## Impact de la sélection de colonnes

En comparant les résultats avec un nombre réduit de colonnes (3 colonnes au lieu de toutes) et le même index:

```
| Critère | Toutes colonnes (output2) | Colonnes limitées (output3) | Amélioration |
|---------|---------------------------|--------------------------|--------------|
| Largeur (width) | 86 | 35 | 59% moins de données |
| Temps d'exécution | 309.741 ms | 236.612 ms | ~32% / ~24% plus rapide |
| Stratégie d'exécution | Parallel Bitmap Heap Scan | Parallel Bitmap Heap Scan | Identique |
| Temps de planification | 0.963 ms | 0.058 ms | Plus rapide |
```

### Analyse des questions

1. **Le temps d'exécution a-t-il changé? Pourquoi?**  
   Oui, le temps d'exécution s'est amélioré d'environ 30%, passant de 310 ms à 235 ms. Cette amélioration est due à la réduction de la quantité de données à traiter et à transférer. Avec moins de colonnes à lire et à traiter, PostgreSQL a besoin de moins d'opérations d'E/S et moins de mémoire.

2. **Le plan d'exécution est-il différent?**  
   Non, la stratégie d'exécution reste la même (Parallel Bitmap Heap Scan avec Bitmap Index Scan). PostgreSQL utilise le même chemin d'accès car la condition de filtrage (startYear = 2020) est identique. La différence réside uniquement dans la quantité de données récupérées de chaque ligne.

3. **Pourquoi la sélection de moins de colonnes peut-elle améliorer les performances?**  
   La sélection de moins de colonnes améliore les performances pour plusieurs raisons:
   - **Moins de données à lire**: PostgreSQL lit moins d'octets par ligne depuis le disque
   - **Moins de données en mémoire**: Moins de RAM est nécessaire pour stocker les lignes en cours de traitement
   - **Moins de données à transférer**: Moins de données sont envoyées entre les processus et vers le client
   - **Meilleure utilisation du cache**: Plus de lignes peuvent tenir dans les caches du système et de PostgreSQL
   
   Ces avantages sont particulièrement visibles dans notre cas où la largeur des données est réduite de 86 à 35 (une réduction de 59%), ce qui se traduit par une amélioration des performances d'environ 30%.

## 1.6 Analyse de l'impact global

En comparant le plan d'exécution initial (étape 1.1) avec le plan optimisé (après index et avec sélection de colonnes limitée):

### Réponses aux questions

1. **Quelle nouvelle stratégie PostgreSQL utilise-t-il maintenant?**  
   PostgreSQL est passé d'un Parallel Sequential Scan à une combinaison de Bitmap Index Scan suivi d'un Parallel Bitmap Heap Scan. Cette stratégie permet d'utiliser l'index pour identifier efficacement les blocs de données à lire, au lieu de parcourir l'intégralité de la table.

2. **Le temps d'exécution s'est-il amélioré? De combien?**  
   Le temps d'exécution s'est considérablement amélioré, passant de 1708.356 ms (initial) à 236.612 ms (optimisé), soit une réduction d'environ 86%. Cette amélioration combine l'effet de l'index et de la sélection limitée de colonnes.

3. **Que signifie "Bitmap Heap Scan" et "Bitmap Index Scan"?**  
   - **Bitmap Index Scan**: Cette opération consulte l'index pour identifier les lignes correspondant à la condition (startYear = 2020) et crée une bitmap temporaire qui marque les blocs contenant ces lignes.
   - **Bitmap Heap Scan**: Cette opération lit ensuite les blocs identifiés par la bitmap pour extraire les données réelles des lignes. Elle peut être parallélisée pour améliorer les performances.
   
   Cette approche en deux étapes est plus efficace qu'un Index Scan direct pour des requêtes qui retournent un nombre significatif de lignes (ici 438,620 lignes, soit environ 10% de la table).

4. **Pourquoi l'amélioration n'est-elle pas plus importante?**  
   Bien qu'une amélioration de 86% soit significative, plusieurs facteurs limitent un gain encore plus important:
   
   - **Volume de résultats**: La requête retourne encore un nombre important de lignes (438,620), ce qui nécessite un traitement substantiel indépendamment de la stratégie d'accès.
   - **Ratio de sélectivité**: Environ 10% des lignes de la table correspondent à notre critère, ce qui est relativement élevé. L'avantage des index diminue lorsqu'une proportion importante de la table doit être lue.
   - **Lossy Heap Blocks**: Le plan montre des "lossy blocks" (10986), indiquant que la bitmap est devenue trop grande pour être précise à 100%, nécessitant des vérifications supplémentaires.
   - **Recheck Condition**: 672,361 lignes ont dû être reconsidérées après l'accès initial via l'index, ajoutant une charge de traitement.
   
   Pour des requêtes avec une sélectivité encore plus fine (par exemple, moins de 1% des lignes), l'amélioration relative serait probablement encore plus importante.