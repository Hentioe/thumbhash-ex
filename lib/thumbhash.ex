defmodule Thumbhash do
  @moduledoc "Implementation of ThumbHash in Elixir"

  alias Thumbhash.{ChannelEncoder, FitError}

  import Bitwise

  defmodule RGBA do
    @moduledoc false

    defstruct r: 0, g: 0, b: 0, a: 0

    @type t :: %__MODULE__{
            r: 0..255,
            g: 0..255,
            b: 0..255,
            a: 0..255
          }
  end

  defmodule LQPA do
    @moduledoc false

    defstruct l: :array.new(), q: :array.new(), p: :array.new(), a: :array.new()

    def new(size) do
      %__MODULE__{
        l: :array.new(size),
        q: :array.new(size),
        p: :array.new(size),
        a: :array.new(size)
      }
    end
  end

  @doc """
  Encodes an RGBA image to a ThumbHash.

  ## Note
    - `w` and `h` cannot exceed `100`
    - `rgba` is required to be an `:array.array()`

  Returns a binary of hash.
  """
  @spec rgba_to_thumb_hash(1..100, 1..100, :array.array()) :: binary
  def rgba_to_thumb_hash(w, h, rgba) do
    # Encoding an image larger than 100x100 is slow with no benefit
    if w > 100 or h > 100, do: raise(FitError, "#{w}x#{h} doesn't fit in 100x100")
    # 像素数量
    pixels_count = w * h

    # Determine the average color
    avg_px =
      Enum.reduce(0..(pixels_count - 1), %RGBA{}, fn i, %{r: r, g: g, b: b, a: a} ->
        j = i * 4
        alpha = :array.get(j + 3, rgba) / 255
        avg_r = r + alpha / 255 * :array.get(j, rgba)
        avg_g = g + alpha / 255 * :array.get(j + 1, rgba)
        avg_b = b + alpha / 255 * :array.get(j + 2, rgba)
        avg_a = a + alpha

        %RGBA{
          r: avg_r,
          g: avg_g,
          b: avg_b,
          a: avg_a
        }
      end)

    avg_px =
      if avg_px.a > 0 do
        avg_r = avg_px.r / avg_px.a
        avg_g = avg_px.g / avg_px.a
        avg_b = avg_px.b / avg_px.a

        %{avg_px | r: avg_r, g: avg_g, b: avg_b}
      else
        avg_px
      end

    has_alpha = avg_px.a < w * h
    l_limit = if has_alpha, do: 5, else: 7
    lx = max(1, round(l_limit * w / max(w, h)))
    ly = max(1, round(l_limit * h / max(w, h)))

    # # Convert the image from RGBA to LPQA (composite atop the average color)
    lqpa =
      Enum.reduce(0..(pixels_count - 1), LQPA.new(pixels_count), fn i, lqpa ->
        %{l: l, q: q, p: p, a: a} = lqpa
        j = i * 4
        alpha = :array.get(j + 3, rgba) / 255
        r = avg_px.r * (1 - alpha) + alpha / 255 * :array.get(j, rgba)
        g = avg_px.g * (1 - alpha) + alpha / 255 * :array.get(j + 1, rgba)
        b = avg_px.b * (1 - alpha) + alpha / 255 * :array.get(j + 2, rgba)

        l = :array.set(i, (r + g + b) / 3, l)
        p = :array.set(i, (r + g) / 2 - b, p)
        q = :array.set(i, r - g, q)
        a = :array.set(i, alpha, a)

        %LQPA{
          l: l,
          q: q,
          p: p,
          a: a
        }
      end)

    {l_dc, l_ac, l_scale} =
      ChannelEncoder.encode_channel(%ChannelEncoder.Params{
        channel: lqpa.l,
        nx: max(3, lx),
        ny: max(3, ly),
        w: w,
        h: h
      })

    {p_dc, p_ac, p_scale} =
      ChannelEncoder.encode_channel(%ChannelEncoder.Params{
        channel: lqpa.p,
        nx: 3,
        ny: 3,
        w: w,
        h: h
      })

    {q_dc, q_ac, q_scale} =
      ChannelEncoder.encode_channel(%ChannelEncoder.Params{
        channel: lqpa.q,
        nx: 3,
        ny: 3,
        w: w,
        h: h
      })

    {a_dc, a_ac, a_scale} =
      if has_alpha do
        ChannelEncoder.encode_channel(%ChannelEncoder.Params{
          channel: lqpa.a,
          nx: 5,
          ny: 5
        })
      else
        {nil, nil, nil}
      end

    # # Write the constants
    is_landscape = w > h

    header24 =
      round(63 * l_dc) ||| round(31.5 + 31.5 * p_dc) <<< 6 ||| round(31.5 + 31.5 * q_dc) <<< 12 |||
        round(31 * l_scale) <<< 18 ||| if has_alpha, do: 1, else: 0 <<< 23

    header16 =
      if(is_landscape, do: ly, else: lx) ||| round(63 * p_scale) <<< 3 |||
        round(63 * q_scale) <<< 9 ||| if is_landscape, do: 1, else: 0 <<< 15

    hash = [
      header24 &&& 255,
      header24 >>> 8 &&& 255,
      header24 >>> 16,
      header16 &&& 255,
      header16 >>> 8
    ]

    ac_start = if has_alpha, do: 6, else: 5
    ac_list = if has_alpha, do: [l_ac, p_ac, q_ac, a_ac], else: [l_ac, p_ac, q_ac]

    hash =
      if has_alpha do
        hash ++ [round(15 * a_dc) ||| round(15 * a_scale) <<< 4]
      else
        hash
      end

    calculate_bytes(ac_start, ac_list, :array.from_list(hash, 0))
  end

  defp calculate_bytes(ac_start, ac_list, hash) do
    {hash, _} =
      Enum.reduce(ac_list, {hash, 0}, fn ac, {hash, ac_index} ->
        Enum.reduce(ac, {hash, ac_index}, fn f, {hash, ac_index} ->
          i = ac_start + (ac_index >>> 1)
          nv = :array.get(i, hash) ||| round(15 * f) <<< ((ac_index &&& 1) <<< 2)
          hash = :array.set(i, nv, hash)
          {hash, ac_index + 1}
        end)
      end)

    hash
    |> :array.to_list()
    |> :binary.list_to_bin()
  end
end
