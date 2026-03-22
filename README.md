# rbxm-to-rojo

```sh
$ lune run convert <path> [-o <output>] [-x] [-m] [-h]

Convert a Roblox model or place to a Rojo JSON format.

Arguments:
    <path>          The path to the .rbxm or .rbxl file to convert.

Options:
    -o, --output    The path to the output file. Just prints to stdout if not specified.
    -x, --explicit  Write DataTypes in Rojo explicit format.
    -m, --minified  Minify the output JSON.
    -h, --help      Show this help message and exit.
```

Also supports TOML/YAML; just change the output file extension.
