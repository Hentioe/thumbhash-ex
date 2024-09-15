defmodule ThumbhashTest do
  use ExUnit.Case
  doctest Thumbhash

  import Thumbhash

  test "rgba_to_thumb_hash/3" do
    image = Image.open!("flower.jpg")

    rgba =
      if Image.has_alpha?(image) do
        {:ok, data} = Vix.Vips.Image.write_to_binary(image)
        :binary.bin_to_list(data)
      else
        image = Image.add_alpha!(image, 255)

        {:ok, data} = Vix.Vips.Image.write_to_binary(image)
        :binary.bin_to_list(data)
      end

    bytes = rgba_to_thumb_hash(75, 100, :array.from_list(rgba))

    assert Base.encode64(bytes) == "k0oGLQaSVsN0BVhn2oq2Z5SQUQcZ"
  end
end
