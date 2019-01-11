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
`168479952374726667841537733610769828254`

