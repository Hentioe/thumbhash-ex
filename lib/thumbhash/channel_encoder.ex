defmodule Thumbhash.ChannelEncoder do
  @moduledoc false

  defmodule Params do
    @moduledoc false

    defstruct [:channel, :nx, :ny, :w, :h]

    @type t :: %__MODULE__{
            channel: :array.array(),
            nx: non_neg_integer,
            ny: non_neg_integer,
            w: non_neg_integer,
            h: non_neg_integer
          }
  end

  def encode_channel(params) do
    {ac, dc, scale} = step_by_cy(params, 0, 0, {[], 0, 0})

    ac =
      if scale != 0 do
        Enum.map(ac, fn f -> 0.5 + 0.5 / scale * f end)
      else
        ac
      end

    {dc, ac, scale}
  end

  defp step_by_cy(params, cy, cx, {ac, dc, scale}) when cy < params.ny do
    {ac, dc, scale} = step_by_cx(params, cx, cy, {ac, dc, scale})

    step_by_cy(params, cy + 1, 0, {ac, dc, scale})
  end

  defp step_by_cy(_params, _cy, _cx, {ac, dc, scale}) do
    {ac, dc, scale}
  end

  defp step_by_cx(params, cx, cy, {ac, dc, scale})
       when cx * params.ny < params.nx * (params.ny - cy) do
    fx =
      Enum.reduce(0..(params.w - 1), :array.new(), fn x, fx ->
        :array.set(x, :math.cos(:math.pi() / params.w * cx * (x + 0.5)), fx)
      end)

    f =
      Enum.reduce(0..(params.h - 1), 0, fn y, f ->
        fy = :math.cos(:math.pi() / params.h * cy * (y + 0.5))

        f +
          Enum.reduce(0..(params.w - 1), 0, fn x, f ->
            f + :array.get(x + y * params.w, params.channel) * :array.get(x, fx) * fy
          end)
      end)

    f = f / (params.w * params.h)

    {ac, dc, scale} =
      if cx != 0 || cy != 0 do
        ac = ac ++ [f]
        scale = max(scale, abs(f))

        {ac, dc, scale}
      else
        dc = f

        {ac, dc, scale}
      end

    step_by_cx(params, cx + 1, cy, {ac, dc, scale})
  end

  defp step_by_cx(_params, _cx, _ny, {ac, dc, scale}) do
    {ac, dc, scale}
  end
end
