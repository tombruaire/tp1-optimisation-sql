# Analyse du plan complexe

## 1. Identification des différentes étapes du plan

Le plan d'exécution de cette requête comprend plusieurs étapes distinctes :

1. **Scan** : PostgreSQL utilise des **Index Scan** ou **Sequential Scan** sur les tables title_basics et title_ratings selon les index disponibles. Pour title_basics, un index sur startYear est probablement utilisé pour filtrer les films entre 1990 et 2000.

2. **Hash** : Les résultats du scan sont utilisés pour créer une table de hachage (**Hash**) en mémoire, préparant ainsi les données pour la jointure.

3. **Hash Join** : PostgreSQL effectue une jointure par hachage (**Hash Join**) entre les deux tables en utilisant les tables de hachage créées précédemment.

4. **Agrégation** : Le plan utilise une agrégation en deux phases :
   - **Partial HashAggregate** : Agrégation partielle des données par startYear
   - **Finalize HashAggregate** : Finalisation de l'agrégation des résultats partiels

5. **Sort** : En dernière étape, les résultats agrégés sont triés (**Sort**) selon la note moyenne (average_rating) en ordre décroissant.

## 2. Pourquoi l'agrégation est-elle réalisée en deux phases ?

L'agrégation est réalisée en deux phases ("Partial" puis "Finalize") pour optimiser les performances lors du traitement parallèle :

1. **Phase Partial HashAggregate** :
   - Chaque worker (processus parallèle) effectue une agrégation partielle sur son propre sous-ensemble de données
   - Cette phase réduit considérablement le volume de données à traiter en les regroupant par startYear
   - Elle permet de calculer des résultats intermédiaires (COUNT et SUM pour l'AVG) pour chaque groupe

2. **Phase Finalize HashAggregate** :
   - Combine les résultats partiels de tous les workers
   - Calcule les valeurs finales des agrégations (COUNT final et AVG final)
   - Produit les résultats définitifs par groupe

Cette approche en deux phases permet un parallélisme efficace et réduit la quantité de données à transférer entre les workers et le processus principal.

## 3. Comment sont utilisés les index existants ?

Les index sont utilisés de la manière suivante dans le plan d'exécution :

1. **Index sur startYear** :
   - PostgreSQL utilise l'index sur startYear de la table title_basics pour filtrer efficacement les films entre 1990 et 2000
   - Cet index permet d'éviter un scan séquentiel complet de la table et de ne récupérer que les lignes pertinentes

2. **Index sur tconst** :
   - Les index primaires sur tconst dans les deux tables sont utilisés pour la jointure
   - Ils permettent d'accélérer la phase de création des tables de hachage pour la Hash Join

3. **Index sur titleType** :
   - Si un index composite sur (startYear, titleType) existe, il peut être utilisé pour filtrer à la fois l'année et le type 'movie'
   - Sinon, le filtre sur titleType est appliqué après le scan indexé sur startYear

## 4. Le tri final est-il coûteux ? Pourquoi ?

Le tri final (**Sort**) est relativement coûteux pour plusieurs raisons :

1. **Opération en mémoire** : Le tri nécessite que toutes les données agrégées soient chargées en mémoire, ce qui peut être significatif même après l'agrégation.

2. **Complexité algorithmique** : Les algorithmes de tri ont une complexité de O(n log n), ce qui devient coûteux lorsque le nombre d'éléments à trier augmente.

3. **Tri sur valeur calculée** : Le tri s'effectue sur average_rating, une valeur calculée pendant l'agrégation, ce qui signifie qu'aucun index ne peut être utilisé pour accélérer cette opération.

4. **Petit ensemble de résultats** : Cependant, le coût est limité par le fait que nous ne trions qu'un petit nombre de lignes (11 années au total entre 1990 et 2000), ce qui réduit considérablement l'impact du tri sur les performances globales.

Dans ce cas précis, bien que le tri soit intrinsèquement coûteux, son impact sur les performances globales est minime en raison du petit nombre de lignes à trier après l'agrégation.

## 5. Comparaison des plans d'exécution avant et après l'ajout des index sur tconst

La comparaison des plans d'exécution avant et après l'ajout des index sur les colonnes tconst révèle plusieurs améliorations significatives :

### Temps d'exécution global
- **Avant** : 342.069 ms
- **Après** : 264.777 ms
- **Amélioration** : 77.292 ms (22.6% plus rapide)

### Temps par opération

1. **Sort final** :
   - Avant : 303.554..306.608 ms
   - Après : 227.664..229.012 ms
   - Amélioration : ~26% plus rapide

2. **Finalize GroupAggregate** :
   - Avant : 302.575..306.572 ms
   - Après : 226.679..228.996 ms
   - Amélioration : ~25% plus rapide

3. **Hash Join parallèle** :
   - Avant : 151.099..286.215 ms
   - Après : 134.758..214.510 ms
   - Amélioration : ~25% plus rapide

4. **Scan séquentiel sur title_ratings** :
   - Avant : 0.028..57.143 ms
   - Après : 0.031..29.608 ms
   - Amélioration : ~48% plus rapide

5. **Bitmap Index Scan** :
   - Avant : 19.762 ms
   - Après : 11.079 ms
   - Amélioration : ~44% plus rapide

6. **Planning Time** :
   - Avant : 2.543 ms
   - Après : 1.695 ms
   - Amélioration : ~33% plus rapide

### Analyse des améliorations

1. **Efficacité de la jointure** : L'index sur tconst accélère considérablement la jointure entre les tables. PostgreSQL peut maintenant localiser rapidement les enregistrements correspondants dans les deux tables, réduisant le temps nécessaire pour la phase de Hash Join.

2. **Précision des estimations** : Les index améliorent la qualité des estimations statistiques utilisées par l'optimiseur, ce qui conduit à un meilleur plan d'exécution global.

3. **Réduction de l'I/O** : Bien que le plan utilise toujours un scan séquentiel sur title_ratings, le temps de ce scan est réduit de près de moitié, indiquant une meilleure utilisation des caches et une réduction des opérations d'I/O disque.

4. **Accélération en cascade** : L'amélioration des premières étapes du plan (scan et jointure) a un effet en cascade sur toutes les opérations suivantes, y compris l'agrégation et le tri final.

### Conclusion

L'ajout d'index sur les colonnes tconst, utilisées comme clés de jointure, a significativement amélioré les performances de la requête, même si la structure globale du plan d'exécution reste similaire. Cette amélioration démontre l'importance cruciale des index bien placés pour optimiser les opérations de jointure, même lorsque d'autres index (comme celui sur startYear) sont déjà présents.

## 6. Analyse des résultats

### 1. Les index de jointure sont-ils utilisés? Pourquoi?

Bien que nous ayons créé des index sur les colonnes tconst des deux tables, le plan d'exécution montre qu'ils ne sont pas utilisés directement pour la jointure comme on pourrait s'y attendre. Au lieu d'un Nested Loop Join avec Index Scan, PostgreSQL continue d'utiliser un Hash Join avec Parallel Seq Scan sur title_ratings. Voici pourquoi:

1. **Volume de données** : La requête traite un grand volume de données (plus de 30 000 lignes au total). Pour de grandes tables, le Hash Join est souvent plus efficace qu'un Nested Loop Join avec Index Scan, car:
   - Il réduit le nombre total d'accès aléatoires au disque
   - Il permet un traitement séquentiel plus efficace
   - Il exploite mieux le parallélisme

2. **Sélectivité des filtres** : Le filtre sur startYear et titleType (1990-2000, 'movie') retourne environ 51 264 lignes. Comme ce nombre est élevé, l'optimiseur préfère un algorithme qui peut traiter efficacement de grands ensembles de données.

3. **Optimisation du cache** : Avec un Seq Scan, PostgreSQL peut lire les pages entières séquentiellement, ce qui est plus efficace pour le cache disque et mémoire que des accès aléatoires répétés à travers un index.

4. **Amélioration indirecte** : Bien que les index ne soient pas utilisés directement dans la stratégie de jointure, ils améliorent les statistiques disponibles pour l'optimiseur, ce qui conduit à une meilleure exécution globale.

### 2. Pourquoi le plan d'exécution reste-t-il pratiquement identique?

Le plan d'exécution reste presque identique pour plusieurs raisons:

1. **Décision basée sur les coûts** : PostgreSQL estime que le plan avec Hash Join parallèle reste le plus efficace même avec les nouveaux index. Cette décision est basée sur:
   - Le coût estimé de lecture séquentielle vs. accès indexé pour ce volume de données
   - Le coût de création des tables de hachage vs. les multiples accès à l'index
   - La capacité à paralléliser efficacement un Hash Join

2. **Seuil de bascule non atteint** : Pour que PostgreSQL bascule vers un plan utilisant les index de jointure (comme Nested Loop Join), il faudrait que:
   - Le nombre de lignes à traiter soit significativement plus petit
   - La sélectivité des filtres soit beaucoup plus élevée
   - Le coût d'accès aléatoire via l'index soit inférieur au coût du scan séquentiel et du hachage

3. **Caractéristiques des données** : La distribution des données dans ces tables favorise une approche basée sur le hachage plutôt que sur les index pour cette requête spécifique.

### 3. Dans quels cas les index de jointure seraient-ils plus efficaces?

Les index de jointure seraient plus efficaces dans les scénarios suivants:

1. **Haute sélectivité des filtres** : Si les filtres réduisaient drastiquement le nombre de lignes (par exemple, en cherchant seulement les films de 1994 avec une note > 9.5), un Nested Loop Join avec Index Scan serait plus efficace.

2. **Requêtes OLTP vs OLAP** : Pour des requêtes transactionnelles (OLTP) qui accèdent à un petit nombre d'enregistrements spécifiques, les index de jointure sont généralement plus efficaces que pour les requêtes analytiques (OLAP) comme celle-ci.

3. **Petites tables ou jointures inégales** : Si l'une des tables est très petite ou si les cardinalités des tables sont très différentes, un Nested Loop Join avec Index Scan sur la plus grande table serait plus efficace.

4. **Jointures avec prédicats complexes** : Pour les jointures avec des conditions additionnelles complexes qui réduisent significativement le nombre de correspondances, les index de jointure seraient plus efficaces.

5. **Données non uniformément distribuées** : Si les valeurs de jointure ne sont pas uniformément distribuées, un index peut être plus efficace qu'un Hash Join, particulièrement si la plupart des accès concernent un sous-ensemble spécifique de valeurs.

En résumé, bien que les index sur tconst aient amélioré les performances globales, la nature et le volume des données traitées dans cette requête font que PostgreSQL continue à préférer un Hash Join parallèle comme stratégie optimale.
