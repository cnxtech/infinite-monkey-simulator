# infinite-monkey-simulator
Can an infinite number of monkeys typing keys eventually exit vim?


Testing
-------

Test with known random seed
```
make IMS_SEED=304202780880517450631793213253801940104 run
```

Format captured output: 
```
hexdump -e '/1 "%_u "'
```

### interesting seed
This seed terminated after 28 seconds, but only if 85 <= CPS <= 128
168479952374726667841537733610769828254


### Literal Note

The author remembers reading a short story about this concept, originally printed in Fantastic Stories, and reprinted in the 
anthology (Galactic Empires, edited by Brian Aldiss)[http://brianaldiss.co.uk/writing/edited-by-brian/edited-by-a-m/galactic-empires/]

BEEN A LONG, LONG TIME
R. A. LAFFERTY 

You’ve heard the one about the monkeys, the typewriter, and 
the complete works of Shakespeare? So did Michael . . . but he 
set out to prove it—! 

(The full text is archived here)[https://archive.org/stream/Fantastic_v20n02_1970-12/Fantastic_v20n02_1970-12_djvu.txt



