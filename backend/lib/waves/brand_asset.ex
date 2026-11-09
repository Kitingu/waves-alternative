defmodule Waves.BrandAsset do
  @moduledoc "Small PNG assets stored with the business and copied into issued document snapshots."
  @max_bytes 512_000
  def from_file(path) do
    with {:ok, %{size: size}} <- File.stat(path), true <- size <= @max_bytes,
         {:ok, bytes} <- File.read(path), true <- valid_png?(bytes) do
      {:ok, "data:image/png;base64," <> Base.encode64(bytes)}
    else
      _ -> {:error, :invalid_png}
    end
  end
  def valid_data_uri?("data:image/png;base64," <> encoded) when byte_size(encoded) <= 683_000 do
    case Base.decode64(encoded) do
      {:ok, bytes} -> valid_png?(bytes)
      _ -> false
    end
  end
  def valid_data_uri?(_), do: false
  def valid_png?(<<137, 80, 78, 71, 13, 10, 26, 10, 13::32, "IHDR", width::32, height::32, depth, color, 0, 0, interlace, crc::32, rest::binary>> = bytes)
      when byte_size(bytes) <= @max_bytes and width in 1..4096 and height in 1..4096 and interlace in [0, 1] do
    header = <<"IHDR", width::32, height::32, depth, color, 0, 0, interlace>>
    valid_depth = case color do
      0 -> depth in [1, 2, 4, 8, 16]
      2 -> depth in [8, 16]
      3 -> depth in [1, 2, 4, 8]
      4 -> depth in [8, 16]
      6 -> depth in [8, 16]
      _ -> false
    end
    valid_depth and :erlang.crc32(header) == crc and chunks_valid?(rest, false)
  end
  def valid_png?(_), do: false
  defp chunks_valid?(<<0::32, "IEND", crc::32>>, true), do: :erlang.crc32("IEND") == crc
  defp chunks_valid?(<<size::32, type::binary-size(4), data::binary-size(size), crc::32, rest::binary>>, seen_data)
       when size <= @max_bytes and type not in ["IHDR", "IEND"] do
    :erlang.crc32(type <> data) == crc and chunks_valid?(rest, seen_data or type == "IDAT")
  end
  defp chunks_valid?(_, _), do: false
end
