## Enemy projectile fired by the active enemy on a wrong answer (FR4.11).
##
## Mirrors bullet.tscn but inherits ALL movement from Bullet so player and
## enemy bullets share one TRAVEL_TIME constant and identical travel
## behavior - exactly 0.3 seconds from source to target regardless of
## distance (NFR4.7). Purely presentational: it never decrements lives,
## never gates input, and its arrival only plays cosmetic feedback.
class_name EnemyBullet
extends Bullet
