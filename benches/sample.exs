image = Image.open!(Path.join("img", "flower.jpg"))

rgba =
  if Image.has_alpha?(image) do
    {:ok, data} = Vix.Vips.Image.write_to_binary(image)
    :binary.bin_to_list(data)
  else
    image = Image.add_alpha!(image, 255)

    {:ok, data} = Vix.Vips.Image.write_to_binary(image)
    :binary.bin_to_list(data)
  end

rgba_array = :array.from_list(rgba)

Benchee.run(%{
  "rgba_to_thumb_hash/3" => fn ->
    Thumbhash.rgba_to_thumb_hash(75, 100, rgba_array)
  end
})
