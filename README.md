# infinite-monkey-simulator
Can an infinite number of monkeys typing keys eventually exit vim?


Testing
-------

Test with known random seed
```
make SEED=304202780880517450631793213253801940104 run
```

Format captured output: 
```
hexdump -e '/1 "%_u "'
```
