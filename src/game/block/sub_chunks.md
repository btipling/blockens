
## Figuring this sub chunk business out in 2D


example mappings
```



(0, 0) (1, 0) (2, 0) (3, 0)
(0, 1) (1, 1) (2, 1) (3, 1)
(0, 2) (1, 2) (2, 2) (3, 2)
(0, 3) (1, 3) (2, 3) (3, 3)

(0, 0) (1, 0)
(0, 1) (1, 1)


sub_pos (0, 0) -> (0, 0)
sub_index_pos (0, 0) -> (0, 0)

sub_pos (1, 0) > (0, 0)
sub_index_pos (1, 0) -> (0, 1)

sub_pos (2, 0) -> (1, 0)
sub_index_pos (2, 0) -> (0, 0)

sub_pos (3, 0) -> (1, 0)
sub_index_pos (3, 0) -> (1, 0)

sub_pos (0, 1) -> (0, 0)
sub_index_pos (0, 1) -> (0, 1)

sub_pos(1, 1) -> (0, 0)
sub_index_pos (1, 1) -> (1, 1)

sub_pos(2, 1) -> (1, 0)
sub_index_pos (2, 1) -> (0, 1)

sub_pos (3, 1) -> (1, 0)
sub_index_pos (3, 1) -> (1, 1)

sub_pos (0, 2) -> (0, 1)
sub_index_pos (0, 2) -> (0, 0)

sub_pos (1, 2) -> (0, 1)
sub_index_pos (1, 2) -> (1, 0)

sub_pos (2, 2) -> (1, 1)
sub_index_pos (2, 2) -> (0, 0)

sub_pos (3, 2) -> (1, 1)
sub_index_pos (3, 2) -> (1, 0)

sub_pos (0, 3) -> (0, 1)
sub_index_pos (0, 3) -> (0, 1)

sub_pos (1, 3) -> (0, 1)
sub_index_pos (1, 3) -> (1, 1)

sub_pos (2, 3) -> (1, 1)
sub_index_pos (2, 3) -> (0, 1)

sub_pos (3, 3) -> (1, 1)
sub_index_pos (3, 3) -> (1, 1)

```

sub_pos_x = @divFloor(pos_x, sub_pos_dim)

```
sub_pos (0, 0) -> (0, 0)
sub_pos (1, 0) > (0, 0)
sub_pos (0, 1) -> (0, 0)
sub_pos(1, 1) -> (0, 0)

sub_pos (2, 0) -> (1, 0)
sub_pos (3, 0) -> (1, 0)
sub_pos(2, 1) -> (1, 0)
sub_pos (3, 1) -> (1, 0)

sub_pos (0, 2) -> (0, 1)
sub_pos (1, 2) -> (0, 1)
sub_pos (0, 3) -> (0, 1)
sub_pos (1, 3) -> (0, 1)

sub_pos (2, 2) -> (1, 1)
sub_pos (3, 2) -> (1, 1)
sub_pos (2, 3) -> (1, 1)
sub_pos (3, 3) -> (1, 1)

```
sub_index_pos_x = @mod(sub_pos_x, sub_pos_dim)

```
sub_index_pos (0, 0) -> (0, 0)
sub_index_pos (1, 0) -> (0, 1)
sub_index_pos (2, 0) -> (0, 0)
sub_index_pos (3, 0) -> (1, 0)

sub_index_pos (0, 1) -> (0, 1)
sub_index_pos (1, 1) -> (1, 1)
sub_index_pos (2, 1) -> (0, 1)
sub_index_pos (3, 1) -> (1, 1)

sub_index_pos (0, 2) -> (0, 0)
sub_index_pos (1, 2) -> (1, 0)
sub_index_pos (2, 2) -> (0, 0)
sub_index_pos (3, 2) -> (1, 0)

sub_index_pos (0, 3) -> (0, 1)
sub_index_pos (1, 3) -> (1, 1)
sub_index_pos (2, 3) -> (0, 1)
sub_index_pos (3, 3) -> (1, 1)
```

## scratch data
```

 0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31
32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47
```