defmodule Thumbhash do
  @moduledoc "Implementation of ThumbHash in Elixir"

  alias Thumbhash.{FitError, ChannelEncoder}
  alias Aja.Vector

  import ChannelEncoder, only: [encode_channel: 1]
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

    defstruct l: Vector.new(), q: Vector.new(), p: Vector.new(), a: Vector.new()
  end

  @doc """
  Encodes an RGBA image to a ThumbHash.

  ## Arguments
    - `w`: Width, cannot exceed `100`.
    - `h`: Height, cannot exceed `100`.
    - `rgba`: RGBA data, is required to be an `:array.array()`.

  Returns a binary of hash.
  """
  @spec rgba_to_thumb_hash(1..100, 1..100, Vector.t(0..255)) :: binary
  def rgba_to_thumb_hash(w, h, rgba) do
    # Encoding an image larger than 100x100 is slow with no benefit
    if w > 100 or h > 100, do: raise(FitError, "#{w}x#{h} doesn't fit in 100x100")
    # Calculate the number of pixels
    pixels_count = w * h

    # Determine the average color
    avg = calculate_avg_rgba(pixels_count, rgba)

    has_alpha = avg.a < w * h
    l_limit = if has_alpha, do: 5, else: 7
    lx = max(1, round(l_limit * w / max(w, h)))
    ly = max(1, round(l_limit * h / max(w, h)))

    # # Convert the image from RGBA to LPQA (composite atop the average color)
    lqpa = caculate_lqpa(pixels_count, avg, rgba)

    {l_dc, l_ac, l_scale} =
      encode_channel(%ChannelEncoder.Params{
        channel: lqpa.l,
        nx: max(3, lx),
        ny: max(3, ly),
        w: w,
        h: h
      })

    {p_dc, p_ac, p_scale} =
      encode_channel(%ChannelEncoder.Params{
        channel: lqpa.p,
        nx: 3,
        ny: 3,
        w: w,
        h: h
      })

    {q_dc, q_ac, q_scale} =
      encode_channel(%ChannelEncoder.Params{
        channel: lqpa.q,
        nx: 3,
        ny: 3,
        w: w,
        h: h
      })

    {a_dc, a_ac, a_scale} =
      if has_alpha do
        encode_channel(%ChannelEncoder.Params{
          channel: lqpa.a,
          nx: 5,
          ny: 5
        })
      else
        {nil, nil, nil}
      end

    hash =
      caculate_hash(
        w > h,
        lx,
        ly,
        has_alpha,
        %{
          l: {l_dc, l_scale},
          p: {p_dc, p_scale},
          q: {q_dc, q_scale},
          a: {a_dc, a_scale}
        }
      )

    ac_start = if has_alpha, do: 6, else: 5
    ac_list = if has_alpha, do: [l_ac, p_ac, q_ac, a_ac], else: [l_ac, p_ac, q_ac]

    calculate_bytes(ac_start, ac_list, :array.from_list(hash, 0))
  end

  defp caculate_hash(
         is_landscape,
         lx,
         ly,
         has_alpha,
         %{
           l: {l_dc, l_scale},
           p: {p_dc, p_scale},
           q: {q_dc, q_scale},
           a: {a_dc, a_scale}
         }
       ) do
    header24 = caculate_header24(has_alpha, l_dc, p_dc, q_dc, l_scale)
    header16 = caculate_header16(is_landscape, lx, ly, p_scale, q_scale)

    hash = [
      header24 &&& 255,
      header24 >>> 8 &&& 255,
      header24 >>> 16,
      header16 &&& 255,
      header16 >>> 8
    ]

    if has_alpha do
      hash ++ [round(15 * a_dc) ||| round(15 * a_scale) <<< 4]
    else
      hash
    end
  end

  defp caculate_header24(has_alpha, l_dc, p_dc, q_dc, l_scale) do
    round(63 * l_dc) ||| round(31.5 + 31.5 * p_dc) <<< 6 ||| round(31.5 + 31.5 * q_dc) <<< 12 |||
      round(31 * l_scale) <<< 18 ||| if has_alpha, do: 1, else: 0 <<< 23
  end

  defp caculate_header16(is_landscape, lx, ly, p_scale, q_scale) do
    if(is_landscape, do: ly, else: lx) ||| round(63 * p_scale) <<< 3 |||
      round(63 * q_scale) <<< 9 ||| if is_landscape, do: 1, else: 0 <<< 15
  end

  defp calculate_avg_rgba(pixels_count, rgba) do
    avg =
      Enum.reduce(0..(pixels_count - 1), %RGBA{}, fn i, %{r: r, g: g, b: b, a: a} ->
        j = i * 4
        alpha = rgba[j + 3] / 255
        avg_r = r + alpha / 255 * rgba[j]
        avg_g = g + alpha / 255 * rgba[j + 1]
        avg_b = b + alpha / 255 * rgba[j + 2]
        avg_a = a + alpha

        %RGBA{
          r: avg_r,
          g: avg_g,
          b: avg_b,
          a: avg_a
        }
      end)

    if avg.a > 0 do
      avg_r = avg.r / avg.a
      avg_g = avg.g / avg.a
      avg_b = avg.b / avg.a

      %{avg | r: avg_r, g: avg_g, b: avg_b}
    else
      avg
    end
  end

  defp caculate_lqpa(pixels_count, avg, rgba) do
    Enum.reduce(0..(pixels_count - 1), %LQPA{}, fn i, lqpa ->
      %{l: l, q: q, p: p, a: a} = lqpa
      j = i * 4
      alpha = rgba[j + 3] / 255
      r = avg.r * (1 - alpha) + alpha / 255 * rgba[j]
      g = avg.g * (1 - alpha) + alpha / 255 * rgba[j + 1]
      b = avg.b * (1 - alpha) + alpha / 255 * rgba[j + 2]

      l = Vector.append(l, (r + g + b) / 3)
      p = Vector.append(p, (r + g) / 2 - b)
      q = Vector.append(q, r - g)
      a = Vector.append(a, alpha)

      %LQPA{
        l: l,
        q: q,
        p: p,
        a: a
      }
    end)
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
