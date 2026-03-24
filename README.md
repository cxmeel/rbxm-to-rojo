# rbxm-to-rojo

```sh
$ lune run convert <path> [-o <output>] [-x] [-m] [-h] [-p]

Convert a Roblox model or place to a Rojo JSON format.

Arguments:
    <path>          The path to the .rbxm or .rbxl file to convert.

Options:
    -o, --output    The path to the output file—defaults to replacing file extension with json
    -p, --print     Print the output to the terminal, instead of writing to a file.
    -x, --explicit  Write DataTypes in Rojo explicit format.
    -m, --minified  Minify the output JSON.
    -h, --help      Show this help message and exit.
```

Also supports TOML/YAML; just change the output file extension.
