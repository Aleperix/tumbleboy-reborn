# TumbleBoy — Formato de niveles (.txt)

Los niveles son archivos de **texto plano** que el juego carga por orden alfabético
(`data/levels/*.txt`). Este es **el mismo formato del original**; el editor visual
del port lee y escribe este formato para que los niveles creados sean intercambiables.

## Estructura general

```
.boy {boy1}            <- atributos (opcionales), van ANTES del mapa
.theme {spacetheme1}
.background-color {#FF5500}
.text-color {#DD0000}
.instructions {Texto}
.name {Mi nivel}
.author {Quién lo hizo}
.junk {Se ignora}
!!!
####...
mapa de símbolos
...
!!!
```

- Todo lo que empiece por `.` y tenga llaves `{...}` es un atributo: formato
  `.nombre {contenido}` (el contenido puede llevar espacios; se lee hasta `}` o
  fin de línea).
- El mapa va entre dos líneas `!!!`. `!!!` abre y cierra el bloque de nivel.

## Símbolos del mapa

| Símbolo | Bloque | Altura (unidades) |
|---------|--------|-------------------|
| ` ` (espacio) | Hueco (la bola se cae) | -5 |
| `-` | Piso | 0 |
| `=` | Piso 2 | 0 |
| `+` | Piso 3 | 0 |
| `#` | Muro | 1 |
| `w` | Muro 2 | 1 |
| `W` | Muro 3 | 1 |
| `%` | Muro doble | 2 |
| `d` | Muro doble 2 | 2 |
| `D` | Muro doble 3 | 2 |
| `$` | **Inicio** (posición de la bola) | 0 |
| `1` | **Meta** (pueden usarse `1`-`9` como múltiples metas) | 0 |
| `<` | Rampa ↑ a la derecha | altura fraccional en X |
| `>` | Rampa ↑ a la izquierda | altura fraccional en X |
| `v` | Rampa ↑ hacia abajo | altura fraccional en Y |
| `^` | Rampa ↑ hacia arriba | altura fraccional en Y |
| `@` | **Bumper** (rebota la bola a velocidad 4.0) | 0 |

Cualquier símbolo desconocido se interpreta como hueco (`BLOCK_NONE`).

## Atributos soportados

| Atributo | Ejemplo | Efecto |
|----------|---------|--------|
| `.name` | `.name {Kink}` | Nombre del nivel (se muestra arriba a la izquierda) |
| `.author` | `.author {Eben Myers}` | Autor (solo documental) |
| `.theme` | `.theme {beach}` | Tema del tablero: `default`, `beach`, `spacetheme1` |
| `.boy` | `.boy {boy2}` | Tema del niño: `boy1`…`boy4` |
| `.instructions` | `.instructions {Usa las flechas}` | Instrucciones (documental/ayuda) |
| `.background-color` | `.background-color {#FF5500}` | Color de fondo (documental; el port lo respeta) |
| `.text-color` | `.text-color {#DD0000}` | Color de texto (documental; el port lo respeta) |
| `.junk` | `.junk {no me leas}` | Se ignora |

## Ejemplo (nivel 1 real)

```
.boy {boy1}
!!!
d###w###w###d
#-----------#
#-$-------1-#
#-----------#
d###w###w###d
!!!
```

## Notas del port

- El parser (`Levels.gd`) reproduce el original: atributos antes de `!!!`,
  mapa entre las dos líneas `!!!`, filas de igual longitud (las más cortas se
  rellenan con huecos).
- El orden de carga del modo historia = orden alfabético de nombre de archivo.
- Los niveles creados en el editor se guardan en `user://tumbleboy_levels/`.
- El editor visual guarda con este mismo formato y puede abrir niveles de terceros
  (`FileDialog` de apertura y desde el hub **Niveles propios**).
