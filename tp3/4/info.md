# Analyse de la distribution des années de sortie dans title_basics

## Distribution par décennie

| Décennie | Nombre de titres | Nombre de films |
|----------|------------------|-----------------|
| 2030     | 13               | 3               |
| 2020     | 2,442,560        | 105,831         |
| 2010     | 3,845,455        | 168,277         |
| 2000     | 1,626,655        | 78,266          |
| 1990     | 751,988          | 45,959          |
| 1980     | 463,499          | 44,193          |
| 1970     | 397,281          | 40,484          |
| 1960     | 324,164          | 31,862          |
| 1950     | 164,342          | 23,858          |
| 1940     | 29,566           | 14,720          |
| 1930     | 32,760           | 20,569          |
| 1920     | 36,934           | 22,093          |
| 1910     | 72,576           | 12,992          |
| 1900     | 25,769           | 184             |
| 1890     | 6,091            | 19              |

## Observations générales

1. **Tendance historique**:
   - Une augmentation exponentielle du nombre de titres et de films est observée au fil des décennies
   - Le volume de productions a considérablement augmenté à partir des années 2000

2. **Décennies les plus prolifiques**:
   - La décennie 2010 est de loin la plus prolifique avec 3,845,455 titres et 168,277 films
   - La décennie 2020 (encore en cours) montre déjà un volume très important avec 2,442,560 titres

3. **Ratio films/titres**:
   - Le ratio entre le nombre de films et le nombre total de titres varie considérablement selon les époques
   - Les décennies plus anciennes avaient proportionnellement plus de films par rapport au nombre total de titres

## Analyse détaillée de la décennie 2010

| Année | Nombre de titres | Nombre de films |
|-------|------------------|-----------------|
| 2010  | 264,160          | 12,964          |
| 2011  | 296,866          | 13,912          |
| 2012  | 336,950          | 14,977          |
| 2013  | 361,437          | 15,639          |
| 2014  | 383,301          | 16,854          |
| 2015  | 403,899          | 17,461          |
| 2016  | 429,200          | 18,634          |
| 2017  | 453,510          | 19,116          |
| 2018  | 459,715          | 19,378          |
| 2019  | 456,417          | 19,342          |

## Tendances au sein de la décennie 2010

1. **Croissance annuelle**:
   - Augmentation régulière du nombre de titres et de films chaque année de 2010 à 2018
   - Légère baisse en 2019 (possiblement due à des retards dans l'enregistrement des données)

2. **Évolution du volume**:
   - Entre 2010 et 2018, le nombre de titres a augmenté de 74% (264,160 à 459,715)
   - Le nombre de films a augmenté de 49% sur la même période (12,964 à 19,378)

3. **Considérations pour les index**:
   - La décennie 2010 contient environ 33% de tous les titres et 28% de tous les films
   - Cette concentration élevée fait de cette décennie un candidat idéal pour l'utilisation d'index partiels

## Comparaison des performances avec index partiel vs. index complet

### 1. Performances pour les requêtes dans la période ciblée (2010-2019, films uniquement)

| Métrique | Valeur |
|----------|--------|
| Plan d'exécution | Bitmap Index Scan sur idx_title_basics_movies_2010s |
| Temps d'exécution | 242.276 ms |
| Lignes retournées | 168,277 |
| Type d'opération | Gather Merge, Sort, Parallel Bitmap Heap Scan |

### 2. Performances pour les requêtes hors de la période ciblée

| Métrique | Valeur |
|----------|--------|
| Plan d'exécution | Parallel Sequential Scan (aucun index utilisé) |
| Temps d'exécution | 335.413 ms |
| Lignes retournées | 441,034 |
| Type d'opération | Gather Merge, Sort, Parallel Seq Scan |

### 3. Comparaison de la taille des index

| Index | Taille | Définition |
|-------|--------|------------|
| idx_title_basics_startyear (complet) | 77 MB | CREATE INDEX idx_title_basics_startyear ON public.title_basics USING btree (startyear) |
| idx_title_basics_movies_2010s (partiel) | 1160 kB | CREATE INDEX idx_title_basics_movies_2010s ON public.title_basics USING btree (startyear) WHERE (((startyear >= 2010) AND (startyear <= 2019)) AND ((titletype)::text = 'movie'::text)) |

### Analyse des résultats

1. **Efficacité de l'index partiel**:
   - L'index partiel est environ 68 fois plus petit que l'index complet (1.13 MB vs 77 MB)
   - Il occupe seulement environ 1.5% de l'espace de l'index complet
   - Malgré sa taille réduite, il offre d'excellentes performances pour les requêtes ciblant la période 2010-2019

2. **Comparaison des performances**:
   - Les requêtes dans la période ciblée s'exécutent environ 28% plus rapidement (242 ms vs 335 ms)
   - L'optimiseur utilise efficacement l'index partiel pour les requêtes ciblant la décennie 2010
   - Pour les requêtes hors période, aucun index n'est utilisé (scan séquentiel)

3. **Impact sur le stockage et la maintenance**:
   - L'index partiel a un impact minimal sur l'espace de stockage
   - La maintenance de l'index (lors des insertions/mises à jour) sera beaucoup plus rapide
   - L'index partiel sera chargé plus rapidement en mémoire lors des opérations

## Conclusion générale

L'utilisation d'un index partiel pour la décennie 2010 offre un excellent compromis entre performances et utilisation des ressources. Avec seulement 1.5% de l'espace requis par l'index complet, il permet d'accélérer significativement les requêtes ciblant les films récents, qui représentent une part importante de la base de données et probablement la majorité des accès dans un système en production.

Cette approche est particulièrement pertinente pour les bases de données volumineuses où l'optimisation de l'espace et des performances est cruciale. L'identification de sous-ensembles de données fréquemment accédés (comme les films récents dans notre cas) constitue une stratégie efficace pour l'application d'index partiels.

## Questions sur les index partiels

### 1. Quels sont les avantages et inconvénients d'un index partiel?

#### Avantages
- **Économie d'espace**: Comme démontré dans notre analyse, un index partiel peut être significativement plus petit qu'un index complet (68 fois plus petit dans notre exemple)
- **Performances de maintenance améliorées**: Moins de données à mettre à jour lors des opérations d'insertion, de mise à jour et de suppression
- **Chargement plus rapide en mémoire**: Étant plus petit, l'index peut être entièrement chargé en mémoire cache plus facilement
- **Impact réduit sur les performances d'écriture**: Les opérations d'écriture qui n'affectent pas les données indexées n'entraînent pas de mise à jour de l'index
- **Optimisation ciblée**: Permet d'optimiser spécifiquement les requêtes les plus fréquentes ou critiques

#### Inconvénients
- **Utilité limitée**: Ne bénéficie pas aux requêtes qui ne correspondent pas aux conditions de l'index partiel
- **Complexité de gestion**: Nécessite une analyse préalable des modèles d'accès et peut compliquer la maintenance du schéma
- **Risque d'obsolescence**: Si les modèles d'accès aux données évoluent, l'index partiel peut devenir moins pertinent
- **Multiplication potentielle des index**: Peut mener à la création de nombreux index partiels différents pour couvrir divers scénarios
- **Visibilité réduite pour l'optimiseur**: L'optimiseur de requêtes peut parfois ne pas choisir un index partiel même lorsqu'il serait bénéfique

### 2. Dans quels scénarios un index partiel est-il particulièrement utile?

- **Distribution non uniforme des données**: Comme dans notre exemple, lorsqu'une petite partie des données (28% des films) est fréquemment consultée
- **Requêtes ciblant des sous-ensembles spécifiques**: Par exemple, uniquement les produits actifs dans un catalogue, les transactions récentes, ou les utilisateurs non-archivés
- **Bases de données volumineuses avec contraintes d'espace**: Quand l'espace disque ou mémoire est limité mais que des performances optimales sont requises
- **Tables avec de fréquentes modifications**: Lorsque beaucoup d'insertions/mises à jour se produisent, mais qu'un sous-ensemble stable des données est souvent consulté
- **Applications multi-usages**: Lorsque certaines requêtes critiques doivent être optimisées sans pénaliser l'ensemble du système
- **Données temporelles avec concentration d'intérêt**: Comme notre cas d'étude, où les données récentes sont plus fréquemment consultées que les données historiques
- **Colonnes avec valeurs NULL fréquentes**: En excluant les valeurs NULL de l'index lorsqu'elles ne sont pas pertinentes pour les requêtes

### 3. Comment déterminer si un index partiel est adapté à votre cas d'usage?

1. **Analyser la distribution des données**: 
   - Identifier les sous-ensembles qui concentrent l'activité (comme notre analyse par décennie)
   - Mesurer le ratio entre la portion ciblée et l'ensemble des données (28% des films dans notre cas)

2. **Étudier les modèles d'accès**:
   - Analyser les logs de requêtes pour identifier les filtres fréquemment utilisés
   - Déterminer si certaines valeurs ou plages de valeurs sont plus souvent consultées

3. **Évaluer l'impact potentiel**:
   - Comparer la taille estimée d'un index partiel vs index complet (1.5% dans notre cas)
   - Mesurer la fréquence des requêtes qui bénéficieraient de l'index partiel

4. **Tester empiriquement**:
   - Créer des index partiels expérimentaux et mesurer les performances avant/après (comme notre analyse comparative)
   - Comparer différentes conditions d'index partiel pour identifier l'optimal

5. **Considérer la dynamique des données**:
   - Évaluer comment les modèles d'accès évoluent dans le temps
   - Prévoir des mécanismes de maintenance ou d'ajustement des index selon l'évolution des données

6. **Critères décisionnels clés**:
   - Un index partiel est généralement adapté si:
     - Le sous-ensemble indexé représente moins de 30% du total des données
     - Ce sous-ensemble est impliqué dans plus de 70% des requêtes
     - La condition de l'index partiel est hautement sélective
     - L'économie d'espace est significative (comme dans notre cas: 1.5% vs 100%)
