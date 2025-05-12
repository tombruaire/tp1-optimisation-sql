# Conclusion: Optimisation des performances SQL

## 1. Quand un index est-il le plus efficace?

### Pour les recherches ponctuelles ou volumineuses?
Les index sont **particulièrement efficaces pour les recherches ponctuelles**. Comme observé dans la requête de recherche par identifiant (tconst), les index permettent d'accéder directement aux enregistrements sans parcourir l'ensemble de la table, réduisant le temps d'exécution de manière spectaculaire (1.974 ms contre plusieurs centaines de millisecondes pour les requêtes volumineuses).

Pour les recherches volumineuses (qui retournent un grand pourcentage de la table), les index perdent leur efficacité car:
- Le coût d'accès à l'index puis aux données dépasse celui d'un simple scan séquentiel
- PostgreSQL privilégie alors un Sequential Scan qui lit les données de manière continue

### Pour les colonnes avec forte ou faible cardinalité?
Les index sont **plus efficaces sur les colonnes à forte cardinalité** (nombre élevé de valeurs distinctes):
- Clés primaires et identifiants uniques (comme tconst): cardinalité maximale, efficacité optimale
- Colonnes avec beaucoup de valeurs distinctes: l'index est très sélectif
- Colonnes avec peu de valeurs distinctes (comme titleType avec seulement quelques catégories): l'index est moins efficace car il ne permet pas de réduire significativement le nombre de lignes à examiner

### Pour les opérations de type égalité ou intervalle?
Les index B-tree standards sont:
- **Très efficaces pour les opérations d'égalité** (`column = value`)
- **Efficaces pour les recherches par intervalles** (`column BETWEEN x AND y`), comme observé avec l'index sur startYear pour filtrer les films entre 1990 et 2000
- Moins efficaces pour les recherches par motif (`LIKE '%pattern%'`) ou les fonctions appliquées aux colonnes

Les index spécialisés (comme les index GiST ou GIN) peuvent être plus adaptés pour certains types d'opérations spécifiques.

## 2. Quels algorithmes de jointure avez-vous observés?

Nous avons observé principalement deux algorithmes de jointure:

### Nested Loop Join
- **Contexte d'utilisation**: Idéal pour joindre un petit nombre d'enregistrements, en particulier quand un côté de la jointure est très sélectif
- **Exemple**: Dans la requête de recherche par identifiant unique (tconst = 'tt0111161')
- **Avantage**: Très efficace pour les jointures avec des conditions hautement sélectives et des index disponibles sur les colonnes de jointure

### Hash Join
- **Contexte d'utilisation**: Préféré pour les jointures sur de grands volumes de données
- **Exemple**: Dans les requêtes d'agrégation et de filtrage sur plages de dates (1990-2000)
- **Avantage**: Performant pour traiter de grandes quantités de données en parallèle

### Influence du volume de données
Le volume de données influence considérablement le choix de l'algorithme:
- **Petit volume** (<100-1000 lignes): Nested Loop Join avec Index Scan est généralement préféré
- **Volume moyen à grand**: Hash Join devient plus efficace car:
  - Il réduit le nombre d'accès aléatoires au disque
  - Il permet une meilleure parallélisation
  - Il optimise l'utilisation du cache

PostgreSQL bascule automatiquement entre ces algorithmes en fonction de ses estimations de coût, qui dépendent du volume de données, de la sélectivité des filtres et des index disponibles.

## 3. Quand le parallélisme est-il activé?

### Activation du parallélisme
PostgreSQL active le parallélisme lorsque:
- Le coût estimé d'une opération dépasse un certain seuil (défini par min_parallel_table_scan_size et paramètres connexes)
- Les opérations peuvent être distribuées entre plusieurs workers
- Le gain potentiel justifie le surcoût de coordination

### Types d'opérations qui en bénéficient le plus
- **Scans séquentiels sur de grandes tables**: Les workers peuvent traiter différentes portions de la table
- **Jointures volumineuses**: Particulièrement les Hash Joins qui peuvent être parallélisées efficacement
- **Agrégations sur de grands ensembles de données**: Comme observé dans la requête qui calcule le nombre de films et leur note moyenne par année
- **Tris de grands ensembles**: Quand la quantité de données à trier est significative

### Pourquoi n'est-il pas toujours utilisé?
Le parallélisme n'est pas utilisé dans les cas suivants:
1. **Requêtes simples ou très sélectives**: Le coût de coordination des workers dépasserait le gain de performance (exemple: recherche par identifiant unique)
2. **Requêtes utilisant efficacement des index**: Les opérations déjà optimisées par des index n'ont pas besoin de parallélisme
3. **Petites tables**: Le surcoût de création et coordination des workers n'est pas justifié
4. **Configuration du serveur**: Limitations de ressources ou paramètres restrictifs
5. **Type de requête**: Certaines opérations ne peuvent pas être parallélisées efficacement

Comme observé dans la requête avec l'index sur averageRating, PostgreSQL a abandonné le parallélisme une fois que les index ont rendu l'exécution suffisamment efficace.

## 4. Quels types d'index utiliser dans les cas suivants?

### Recherche exacte sur une colonne
- **B-tree** (index standard): Optimal pour les recherches par égalité
- Très efficace pour les clés primaires, identifiants et colonnes fréquemment filtrées avec des conditions d'égalité
- Exemple: `WHERE tconst = 'tt0111161'` utilisait efficacement l'index B-tree sur tconst

### Filtrage sur plusieurs colonnes combinées
- **Index composite** sur les colonnes concernées, dans l'ordre adapté à la requête
- Efficace quand les filtres sont appliqués dans le même ordre que les colonnes de l'index
- Exemple: Un index sur (startYear, titleType) serait plus efficace que deux index séparés pour filtrer les films d'une année spécifique et d'un certain type

### Tri fréquent sur une colonne
- **B-tree**: Stocke les données de manière triée, ce qui accélère les opérations ORDER BY
- Particulièrement utile quand la même colonne est utilisée à la fois pour le filtrage et le tri
- Exemple: Un index sur averageRating accélèrerait à la fois le filtrage (averageRating > 8.5) et le tri (ORDER BY averageRating DESC)

### Jointures fréquentes entre tables
- **Index sur les colonnes de jointure** des deux côtés de la relation
- Particulièrement important pour les clés étrangères
- Améliore significativement les performances des Nested Loop Joins
- L'efficacité dépend de la cardinalité et de la distribution des valeurs
- Exemple: Les index sur tconst dans title_basics et title_ratings ont amélioré les performances des jointures entre ces tables

En résumé, le choix d'un index doit prendre en compte la nature des données, les types de requêtes les plus fréquentes et le compromis entre performance en lecture et surcoût en écriture.
