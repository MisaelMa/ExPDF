# `Pdf.Reader.Lexer`
[🔗](https://github.com/MisaelMa/ExPDF/blob/v1.0.0/lib/pdf/reader/lexer.ex#L1)

PDF binary tokenizer.

## Token shapes

    :eof
    {:integer, integer()}
    {:real, float()}
    {:boolean, boolean()}
    :null
    {:name, binary()}          # without leading /
    {:string, binary()}        # literal (...)
    {:hex_string, binary()}    # <...> decoded to bytes
    :array_open  |  :array_close
    :dict_open   |  :dict_close
    {:obj, rest}  |  {:endobj, rest}
    {:stream, rest}  |  {:endstream, rest}
    {:xref, rest}  |  {:trailer, rest}  |  {:startxref, rest}
    {:r, rest}  |  {:f, rest}  |  {:n, rest}

`next_token/1` returns `{token, rest_binary}` or `:eof`.

# `next_token`

```elixir
@spec next_token(binary()) :: {term(), binary()} | :eof
```

Returns the next token from `binary` together with the unconsumed rest.

Returns `:eof` when the binary is empty or contains only whitespace/comments.

# `skip_whitespace`

```elixir
@spec skip_whitespace(binary()) :: binary()
```

Skips all leading whitespace (PDF § 7.2.2: space, tab, LF, CR, FF, NUL).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
