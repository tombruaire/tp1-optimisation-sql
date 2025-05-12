# Analyse du plan de jointure

## 1. Quel algorithme de jointure est utilisé?

Le plan d'exécution utilise un **Parallel Hash Join**. PostgreSQL choisit généralement une boucle imbriquée lorsqu'un des côtés de la jointure est filtré efficacement par un index.

## 2. Comment l'index sur startYear est-il utilisé?

L'index sur startYear est utilisé pour effectuer un **Index Scan** sur la table title_basics afin de filtrer rapidement les films sortis en 1994. Cela réduit considérablement le nombre de lignes à traiter lors de la jointure en ne sélectionnant que les enregistrements correspondant à cette année spécifique.

## 3. Comment est traitée la condition sur averageRating?

La condition `averageRating > 8.5` est traitée comme un **Filter** appliqué après la jointure. Si un index existe sur averageRating, PostgreSQL pourrait l'utiliser pour un Index Scan sur title_ratings. Sinon, le système effectue un Seq Scan sur title_ratings avant d'appliquer le filtre.

PostgreSQL utilise une stratégie différente selon les statistiques des tables et la sélectivité des conditions. Si la condition sur averageRating est très sélective (peu de films ont une note > 8.5), l'optimiseur choisit de scanner d'abord title_ratings, puis de joindre avec les enregistrements filtrés de title_basics.

## 4. Pourquoi PostgreSQL utilise-t-il le parallélisme?

PostgreSQL utilise le parallélisme pour accélérer l'exécution des requêtes en répartissant la charge de travail sur plusieurs cœurs de processeur. Dans le cas de requêtes impliquant de grandes tables comme title_basics et title_ratings, le parallélisme permet:

1. D'effectuer des scans de table (sequential scans) en parallèle, divisant les grandes tables en segments traités simultanément
2. D'exécuter certaines opérations de jointure en parallèle
3. D'accélérer les agrégations et les tris sur de grands ensembles de données

Le parallélisme est particulièrement efficace pour les requêtes qui traitent un grand volume de données et qui nécessitent des opérations coûteuses en termes de calcul. PostgreSQL active automatiquement le parallélisme lorsqu'il estime que le gain de performance justifie le coût supplémentaire de coordination des processus parallèles.

## 5. Analyse de l'impact de l'ajout d'index

### 1. L'algorithme de jointure a-t-il changé?

Après l'ajout de l'index sur `averageRating`, l'algorithme de jointure a changé. PostgreSQL utilise maintenant une **Nested Loop Join** plus efficace puisqu'il dispose d'index sur les deux côtés de la jointure. Le plan d'exécution optimisé commence par filtrer title_ratings en utilisant l'index sur averageRating pour trouver les films ayant une note > 8.5, puis joint ces résultats avec les films de 1994 en utilisant l'index sur startYear.

### 2. Comment l'index sur averageRating est-il utilisé?

L'index sur `averageRating` est désormais utilisé pour effectuer un **Index Scan** (ou Bitmap Index Scan) sur la table title_ratings. PostgreSQL identifie rapidement les enregistrements qui satisfont la condition `averageRating > 8.5` sans avoir à parcourir séquentiellement toute la table. Cela réduit considérablement le nombre de lignes à traiter lors de la jointure.

### 3. Le temps d'exécution s'est-il amélioré? Pourquoi?

Le temps d'exécution s'est amélioré significativement pour plusieurs raisons:

- La capacité d'effectuer un **Index Scan** sur title_ratings pour la condition `averageRating > 8.5` réduit considérablement le nombre de lignes lues (I/O disk)
- La réduction des données à traiter diminue la charge de travail pour la jointure
- Les opérations de filtre sont plus rapides car elles s'appliquent à moins d'enregistrements
- L'algorithme de jointure est plus efficace quand il y a moins de données à joindre

L'amélioration est particulièrement significative car la condition `averageRating > 8.5` est très sélective (elle élimine une grande partie des enregistrements).

### 4. Pourquoi PostgreSQL abandonne-t-il le parallélisme?

PostgreSQL abandonne le parallélisme après l'ajout de l'index car:

1. **Le coût de coordination dépasse les bénéfices**: Avec des index efficaces, le volume de données à traiter est réduit au point où le coût de coordination entre processus parallèles est supérieur au gain de performance.

2. **Efficacité des Index Scans**: Les scans d'index sont déjà très efficaces et ne bénéficient pas autant du parallélisme que les scans séquentiels.

3. **Seuil de données**: PostgreSQL utilise des seuils basés sur la taille des tables et le coût estimé pour décider quand activer le parallélisme. Avec l'index, le coût estimé est inférieur à ce seuil.

4. **Allocation des ressources optimisée**: PostgreSQL préfère économiser des ressources système quand une requête peut être exécutée efficacement sans parallélisme, permettant à d'autres requêtes concurrentes d'utiliser ces ressources.
