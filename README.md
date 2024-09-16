# Thumbhash

This is a pure Elixir implementation of [ThumbHash](https://github.com/evanw/thumbhash).

## Current status

Which only implements the encoding-related APIs, without decoding functionality. **During the alpha release phase, the API may undergo incompatible changes.**

## Preview

| File       |             Original             |                  Placeholder                  | base64                         |
| ---------- | :------------------------------: | :-------------------------------------------: | ------------------------------ |
| flower.jpg | ![Origin image](/img/flower.jpg) | ![ThumbHash image](/img/flower-thumbhash.png) | `k0oGLQaSVsN0BVhn2oq2Z5SQUQcZ` |

## Installation

Add Thumbhash to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:thumbhash, "~> 0.1.0-alpha.0"},
  ]
end
```

## Usage

Example (use [`Image`](https://github.com/elixir-image/image) to get image data):

```elixir
image = Image.open!(Path.join("img", "flower.jpg"))

rgba =
  if Image.has_alpha?(image) do
    {:ok, data} = Vix.Vips.Image.write_to_binary(image)
    :binary.bin_to_list(data)
  else
    image = Image.add_alpha!(image, 255) # If there is no alpha channel, add a fixed value of 255.

    {:ok, data} = Vix.Vips.Image.write_to_binary(image)
    :binary.bin_to_list(data)
  end

bin = Thumbhash.rgba_to_thumb_hash(75, 100, :array.from_list(rgba))

# Encode the data as a string (base64).
Base.encode64(bin) # => "k0oGLQaSVsN0BVhn2oq2Z5SQUQcZ"
```

As shown in the code above, you have to get the RGBA data of the image manually, as this library only performs calculations and does not handle image files.

Additionally, you cannot lose the alpha channel data. Even for non-transparent images, the alpha value must be filled in for every pixel.

## Benchmark

```plaintext
Name                           ips        average  deviation         median         99th %
rgba_to_thumb_hash/3         55.17       18.13 ms    ±16.46%       16.57 ms       28.34 ms
```
