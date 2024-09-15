defmodule ThumbhashTest do
  use ExUnit.Case
  doctest Thumbhash

  import Thumbhash

  test "rgba_to_thumb_hash/3" do
    image = Image.open!("flower.jpg")
    {:ok, data} = Vix.Vips.Image.write_to_binary(image)

    rgba =
      if Image.has_alpha?(image) do
        :binary.bin_to_list(data)
      else
        data
        |> :binary.bin_to_list()
        |> Enum.chunk_every(3)
        |> Enum.map(&(&1 ++ [255]))
        |> List.flatten()
      end

    bytes = rgba_to_thumb_hash(75, 100, rgba)

    assert Base.encode64(bytes) == "k0oGLQaSVsN0BVhn2oq2Z5SQUQcZ"
  end
end
