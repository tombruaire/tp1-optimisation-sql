# Analyse du plan d'exécution pour la recherche par identifiant

## 1. Quel algorithme de jointure est utilisé cette fois?

Cette fois, PostgreSQL utilise un **Nested Loop Join** (boucle imbriquée). Contrairement aux requêtes précédentes qui utilisaient un Hash Join, l'optimiseur a choisi une stratégie différente adaptée à cette requête spécifique.

Le Nested Loop Join fonctionne en:
- Parcourant d'abord une table (la table externe)
- Pour chaque ligne trouvée, en recherchant les lignes correspondantes dans la seconde table (la table interne)

Dans ce cas, PostgreSQL parcourt d'abord la table title_basics pour trouver l'enregistrement avec tconst = 'tt0111161', puis recherche l'enregistrement correspondant dans title_ratings.

## 2. Comment les index sur tconst sont-ils utilisés?

Les index sur tconst sont utilisés très efficacement par cette requête:

1. **Index Scan sur title_basics**: 
   - PostgreSQL utilise l'index primaire "title_basics_pkey" pour localiser directement l'enregistrement avec tconst = 'tt0111161'
   - On peut voir cette utilisation à la ligne: `Index Scan using title_basics_pkey on title_basics tb`
   - La condition appliquée est: `Index Cond: ((tconst)::text = 'tt0111161'::text)`

2. **Index Scan sur title_ratings**:
   - PostgreSQL utilise l'index "idx_title_ratings_tconst" pour trouver rapidement la ligne correspondante dans title_ratings
   - On peut voir cette utilisation à la ligne: `Index Scan using idx_title_ratings_tconst on title_ratings tr`
   - La condition appliquée est: `Index Cond: ((tconst)::text = 'tt0111161'::text)`

Dans les deux cas, l'index permet d'accéder directement à l'enregistrement souhaité sans avoir à parcourir séquentiellement la table, ce qui est extrêmement efficace.

## 3. Comparez le temps d'exécution avec les requêtes précédentes

Le temps d'exécution de cette requête est remarquablement court par rapport aux requêtes précédentes:

- **Cette requête**: 1.974 ms
- **Requête de jointure et filtrage**: ~264-342 ms (requête précédente)
- **Requête d'agrégation**: ~265 ms (avec index sur tconst)

Cette requête est donc:
- **~134-173 fois plus rapide** que la requête de jointure et filtrage
- **~134 fois plus rapide** que la requête d'agrégation

Cette différence spectaculaire s'explique par la quantité de données traitées et l'efficacité des index pour cette requête spécifique.

## 4. Pourquoi cette requête est-elle si rapide?

Cette requête est extrêmement rapide pour plusieurs raisons:

1. **Haute sélectivité**: La recherche par identifiant unique (tconst) est extrêmement sélective - elle retourne exactement une ligne par table.

2. **Utilisation optimale des index**: Les index sur des clés primaires/uniques sont parfaitement adaptés à ce type de recherche ponctuelle. L'accès via index est presque instantané, équivalent à une recherche O(log n) dans une structure arborescente.

3. **Nested Loop Join optimal**: Pour joindre un très petit nombre d'enregistrements (ici, un seul), le Nested Loop Join est l'algorithme le plus efficace. Il évite les surcoûts liés à la création de tables de hachage ou au tri.

4. **Pas de traitement supplémentaire**: Contrairement aux requêtes précédentes, il n'y a pas d'agrégation, de tri ou de filtrage complexe après la jointure.

5. **Faible I/O**: La requête ne lit que deux pages de données dans la base (une pour chaque table), réduisant considérablement les opérations d'entrée/sortie disque.

6. **Pas de parallélisme nécessaire**: La requête est si simple que PostgreSQL n'a pas besoin d'utiliser le parallélisme, évitant ainsi le surcoût lié à la coordination entre workers.

Cette requête représente le cas d'utilisation idéal pour des index bien conçus - une recherche ponctuelle par clé primaire suivie d'une jointure simple.
