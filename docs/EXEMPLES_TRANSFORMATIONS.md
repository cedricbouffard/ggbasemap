# Nouvelles options de transformation d’image

## Contraste

``` r

# Augmenter le contraste (>1)
ggplot() +
  add_basemap(nc, contrast = 1.5) +
  geom_sf(data = nc, fill = NA, color = "red")

# Diminuer le contraste (<1)  
ggplot() +
  add_basemap(nc, contrast = 0.7) +
  geom_sf(data = nc, fill = NA, color = "red")
```

## Gamma

``` r

# Gamma < 1 = tons moyens plus clairs
ggplot() +
  add_basemap(nc, gamma = 0.8) +
  geom_sf(data = nc, fill = NA, color = "red")

# Gamma > 1 = tons moyens plus foncés
ggplot() +
  add_basemap(nc, gamma = 1.2) +
  geom_sf(data = nc, fill = NA, color = "red")
```

## Saturation (corrigée)

``` r

# Saturation 0 = noir et blanc
ggplot() +
  add_basemap(nc, saturation = 0) +
  geom_sf(data = nc, fill = NA, color = "red")

# Saturation 0.5 = désaturé à 50%
ggplot() +
  add_basemap(nc, saturation = 0.5) +
  geom_sf(data = nc, fill = NA, color = "red")

# Saturation 2 = très saturé
ggplot() +
  add_basemap(nc, saturation = 2) +
  geom_sf(data = nc, fill = NA, color = "red")
```

## Combiner toutes les transformations

``` r

ggplot() +
  add_basemap(nc, 
              grayscale = FALSE,
              saturation = 0.7,    # Légèrement désaturé
              brightness = 1.1,    # Un peu plus lumineux
              contrast = 1.3,      # Plus de contraste
              gamma = 0.9) +       # Tons moyens éclaircis
  geom_sf(data = nc, fill = NA, color = "white")
```

## Effet “vieille photo” sépia

``` r

ggplot() +
  add_basemap(nc,
              saturation = 0.3,    # Très désaturé
              brightness = 0.9,    # Légèrement plus sombre
              contrast = 1.2,      # Plus de contraste
              gamma = 1.1) +       # Tons moyens assombris
  geom_sf(data = nc, fill = NA, color = "brown")
```
