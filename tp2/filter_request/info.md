# Analyse du plan d'exécution

## Avant index

### Éléments observés
- **Stratégie utilisée**: Bitmap Heap Scan avec Bitmap Index Scan
- **Nombre de lignes retournées**: 2011
- **Nombre de lignes examinées puis rejetées par le filtre titleType**: 6265
- **Temps d'exécution total**: 58.488 ms

### Quelle stratégie est utilisée pour le filtre sur startYear?

PostgreSQL utilise un **Bitmap Index Scan** sur l'index `idx_title_basics_startyear` pour filtrer les lignes où startYear = 1950. Cette stratégie fonctionne en deux étapes:

1. Le **Bitmap Index Scan** consulte l'index pour identifier les lignes correspondant à startYear = 1950 et crée une bitmap temporaire qui marque les blocs contenant ces lignes.
2. Le **Bitmap Heap Scan** lit ensuite ces blocs spécifiques pour extraire les données complètes des lignes.

Cette approche est efficace car l'index permet d'identifier rapidement les 8276 lignes qui correspondent à l'année 1950 sans avoir à parcourir séquentiellement toute la table.

### Comment est traité le filtre sur titleType?

Le filtre sur titleType (`titletype = 'movie'`) est appliqué comme un **filtre secondaire** après que les lignes ont été extraites via l'index sur startYear. On peut observer cela dans le plan d'exécution:

```
Filter: ((titletype)::text = 'movie'::text)
Rows Removed by Filter: 6265
```

Contrairement au filtre sur startYear qui utilise l'index, le filtre sur titleType est appliqué directement sur les lignes déjà récupérées. C'est ce qu'on appelle un "Filter" dans le plan d'exécution.

##### Combien de lignes passent le premier filtre, puis le second?

1. **Premier filtre (startYear = 1950)**:
   - 8276 lignes sont identifiées par l'index comme ayant startYear = 1950
   
2. **Second filtre (titleType = 'movie')**:
   - 6265 lignes sont éliminées par ce filtre
   - 2011 lignes passent ce filtre et constituent le résultat final

Donc, sur les 8276 lignes qui correspondent à l'année 1950, seules 2011 (environ 24%) sont effectivement des films.

### Quelles sont les limitations de notre index actuel?

1. **Index mono-colonne**: L'index actuel (`idx_title_basics_startyear`) ne porte que sur la colonne startYear, ce qui signifie que le filtre sur titleType doit être appliqué séparément, après la lecture des données.

2. **Examen inutile de lignes**: 6265 lignes sont lues puis rejetées car elles ne correspondent pas au critère titleType = 'movie'. Cela représente environ 76% des lignes identifiées par l'index qui sont inutilement traitées.

3. **Inefficacité pour des requêtes combinées**: Pour des requêtes qui filtrent à la fois sur startYear et titleType (comme c'est le cas ici), un index composite sur (startYear, titleType) serait plus efficace car il permettrait d'éliminer directement les lignes qui ne sont pas des films sans avoir à les lire.

4. **Coût de recheck**: Bien que le plan ne montre pas de "lossy blocks" dans ce cas, il indique que 3280 blocs exacts sont lus, ce qui reste un nombre significatif pour retourner seulement 2011 lignes.

Une amélioration possible serait de créer un index composite sur (startYear, titleType) qui permettrait de filtrer directement sur les deux conditions et réduirait considérablement le nombre de lignes examinées inutilement.

## Après index

### Éléments observés
- **Stratégie utilisée**: Index Scan
- **Nombre de lignes retournées**: 2011
- **Temps d'exécution total**: 10.474 ms
- **Index utilisé**: idx_title_basics_startyear_titletype (index composite)

### Quelle stratégie est utilisée pour les filtres?

PostgreSQL utilise maintenant un **Index Scan** directement sur l'index composite `idx_title_basics_startyear_titletype`. Cette stratégie permet d'appliquer les deux conditions de filtre (startYear = 1950 ET titleType = 'movie') directement via l'index:

```
Index Cond: ((startyear = 1950) AND ((titletype)::text = 'movie'::text))
```

Cette approche est plus efficace car l'index composite permet d'identifier directement les lignes qui correspondent aux deux critères sans avoir à lire et filtrer des lignes supplémentaires.

### Comment sont traités les deux filtres?

Contrairement à l'approche précédente, les deux conditions sont maintenant traitées comme une seule condition d'index composite. L'index est structuré de manière à ce que les entrées soient organisées d'abord par startYear, puis par titleType, permettant une localisation rapide des lignes qui satisfont les deux conditions.

Aucun filtrage supplémentaire n'est nécessaire après la lecture des lignes via l'index, car toutes les lignes retournées par l'index correspondent déjà aux deux critères de la requête.

## Comparaison des deux approches

```
| Critère | Avant index composite | Après index composite | Amélioration |
|---------|----------------------|----------------------|--------------|
| Stratégie d'exécution | Bitmap Heap Scan + Bitmap Index Scan | Index Scan | Stratégie simplifiée |
| Temps d'exécution | 58.488 ms | 10.474 ms | 82% plus rapide |
| Lignes examinées inutilement | 6265 | 0 | 100% d'amélioration |
| Nombre d'étapes de filtrage | 2 | 1 | Processus simplifié |
| Blocs de données lus | 3280 blocs exacts | Accès direct via index | Réduction significative des I/O |
```

### Conclusion

L'ajout de l'index composite sur (startYear, titleType) a apporté des améliorations significatives:

1. **Performance améliorée**: Le temps d'exécution a été réduit de 58.488 ms à 10.474 ms, soit une amélioration d'environ 82%.

2. **Stratégie d'accès plus efficace**: Passage d'une approche en deux étapes (Bitmap Index Scan puis Bitmap Heap Scan avec filtrage) à une approche directe (Index Scan) qui exploite pleinement l'index composite.

3. **Élimination du filtrage post-lecture**: Aucune ligne n'est lue inutilement, contrairement à l'approche précédente où 6265 lignes étaient lues puis rejetées.

4. **Réduction des opérations d'I/O**: Moins de blocs doivent être lus depuis le disque, ce qui contribue significativement à l'amélioration des performances.

Cette optimisation démontre l'importance de créer des index adaptés aux requêtes fréquemment exécutées dans l'application. Pour les requêtes qui filtrent simultanément sur plusieurs colonnes, les index composites peuvent offrir des gains de performance considérables en réduisant à la fois le nombre d'opérations d'I/O et la quantité de données à traiter.


## Impact de la sélection de colonnes

En comparant les résultats entre l'exécution avec toutes les colonnes et celle avec une sélection limitée de colonnes:

```
| Critère | Avec toutes colonnes (output2) | Avec colonnes limitées (output3) | Amélioration |
|---------|------------------------------|--------------------------------|--------------|
| Largeur (width) | 86 | 44 | 49% moins de données |
| Temps d'exécution | 10.474 ms | 0.463 ms | 96% plus rapide |
| Temps de planification | 1.799 ms | 0.045 ms | 97% plus rapide |
| Stratégie d'exécution | Index Scan | Index Scan | Identique |
```

### Analyse des questions

1. **Le temps d'exécution a-t-il changé?**  
   Oui, le temps d'exécution a considérablement diminué, passant de 10.474 ms à seulement 0.463 ms, soit une amélioration de 96%. Cette réduction drastique montre l'impact significatif de la sélection limitée de colonnes sur les performances.

2. **Pourquoi cette optimisation est-elle plus ou moins efficace que dans l'exercice 1?**  
   Cette optimisation est proportionnellement plus efficace que celle observée dans l'exercice 1 (96% vs 82% d'amélioration). Cela s'explique par plusieurs facteurs:
   
   - L'index composite est déjà en place, offrant un accès direct aux données pertinentes
   - La largeur des données a été réduite de moitié (86 à 44), ce qui diminue considérablement la quantité de données à traiter
   - Dans l'exercice 1, l'amélioration provenait principalement du changement de stratégie d'accès, tandis qu'ici elle provient de la réduction de la quantité de données à traiter
   - La combinaison de l'index composite et de la sélection limitée de colonnes crée un effet multiplicatif sur les performances

3. **Dans quel cas un "covering index" (index qui contient toutes les colonnes de la requête) serait idéal?**  
   Un covering index serait particulièrement efficace dans les cas suivants:
   
   - Requêtes qui sélectionnent un petit sous-ensemble de colonnes fréquemment utilisées
   - Requêtes d'agrégation ou de comptage qui n'ont pas besoin d'accéder aux données complètes
   - Requêtes à haute fréquence d'exécution où la performance est critique
   - Applications où les recherches et filtrages sont très fréquents, mais les mises à jour sont rares
   
   L'avantage principal d'un covering index est qu'il permet à PostgreSQL d'obtenir toutes les données nécessaires directement depuis l'index, sans avoir à accéder à la table elle-même (l'opération "Index Only Scan"), ce qui élimine complètement les accès aux blocs de données de la table.

4. **Quelle est la différence de temps d'exécution par rapport à l'étape 2.1?**  
   En comparant avec le plan d'exécution initial (Bitmap Heap Scan sur l'index simple):
   - Étape 2.1 (index simple): 58.488 ms
   - Étape actuelle (index composite + colonnes limitées): 0.463 ms
   
   Cela représente une amélioration de 99.2%, soit environ 126 fois plus rapide. Cette amélioration spectaculaire combine les effets de l'index composite et de la sélection limitée de colonnes.

5. **Comment l'index composite modifie-t-il la stratégie?**  
   L'index composite a fondamentalement changé la stratégie d'accès aux données:
   - **Avant**: Bitmap Index Scan pour identifier les lignes avec startYear=1950, puis Bitmap Heap Scan avec un filtre supplémentaire pour titleType='movie'
   - **Après**: Index Scan direct utilisant l'index composite pour identifier précisément les lignes correspondant aux deux conditions simultanément
   
   Cette modification élimine l'étape de filtrage supplémentaire et permet un accès direct et ciblé aux données pertinentes.

6. **Pourquoi le nombre de blocs lus ("Heap Blocks") a-t-il diminué?**  
   Le nombre de blocs lus a considérablement diminué pour plusieurs raisons:
   - L'index composite permet d'identifier directement les lignes qui satisfont toutes les conditions, sans avoir à examiner les lignes qui ne correspondent qu'à une partie des conditions
   - Avec l'approche précédente, il fallait lire 3280 blocs pour traiter 8276 lignes, dont 6265 finissaient par être rejetées
   - Avec l'index composite, seuls les blocs contenant effectivement les 2011 lignes pertinentes doivent être lus
   - La sélection de colonnes limitée réduit encore la quantité de données à lire pour chaque ligne

7. **Dans quels cas un index composite est-il particulièrement efficace?**  
   Un index composite est particulièrement efficace dans les cas suivants:
   
   - Requêtes avec plusieurs conditions de filtrage sur différentes colonnes qui sont fréquemment utilisées ensemble
   - Données avec une forte corrélation entre les colonnes indexées (comme ici, où seulement 24% des entrées de 1950 sont des films)
   - Requêtes de jointure sur plusieurs colonnes
   - Requêtes avec des clauses ORDER BY sur les mêmes colonnes que celles utilisées dans les conditions
   - Applications où la sélectivité combinée des conditions est nettement meilleure que la sélectivité de chaque condition individuelle

