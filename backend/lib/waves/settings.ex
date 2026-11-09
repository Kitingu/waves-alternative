defmodule Waves.Settings do
  import Ecto.Changeset
  import Ecto.Query
  alias Waves.{Repo, Business, Audit}
  @fields ~w(name legal_name address email phone website tax_id registration_number payment_details invoice_title invoice_prefix default_due_days invoice_notes invoice_terms invoice_footer accent_color invoice_template tax_name tax_rate tax_mode show_stamp show_signature stamp_width stamp_position signatory_name signatory_title)a
  def fields, do: @fields
  def changeset(business, attrs) do
    business |> cast(attrs, @fields)
    |> validate_required([:name, :invoice_title, :invoice_prefix, :accent_color, :invoice_template, :tax_name, :tax_rate, :tax_mode, :default_due_days, :stamp_width, :stamp_position])
    |> validate_length(:name, min: 1, max: 200)
    |> validate_length(:legal_name, max: 200)
    |> validate_length(:invoice_title, max: 60)
    |> validate_format(:invoice_prefix, ~r/\A[A-Za-z0-9_-]{1,20}\z/)
    |> validate_format(:accent_color, ~r/\A#[0-9a-fA-F]{6}\z/)
    |> validate_format(:email, ~r/\A[^\s@]+@[^\s@]+\.[^\s@]+\z/)
    |> validate_inclusion(:invoice_template, ["modern", "classic", "minimal"])
    |> validate_inclusion(:tax_mode, ["none", "exclusive", "inclusive"])
    |> validate_inclusion(:stamp_position, ["left", "center", "right"])
    |> validate_number(:tax_rate, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_change(:tax_rate, fn :tax_rate, rate ->
      if Decimal.equal?(rate, Decimal.round(rate, 4)), do: [], else: [tax_rate: "must have at most 4 decimal places"]
    end)
    |> validate_number(:default_due_days, greater_than_or_equal_to: 0, less_than_or_equal_to: 365)
    |> validate_number(:stamp_width, greater_than_or_equal_to: 60, less_than_or_equal_to: 220)
    |> validate_lengths()
  end
  defp validate_lengths(changeset) do
    Enum.reduce(~w(address payment_details invoice_notes invoice_terms invoice_footer)a, changeset, &validate_length(&2, &1, max: 3000))
    |> then(fn cs -> Enum.reduce(~w(phone website tax_id registration_number tax_name signatory_name signatory_title)a, cs, &validate_length(&2, &1, max: 200)) end)
  end
  # Asset values can only originate from the validated upload path, never from settings payloads.
  def save(key, attrs, assets \\ %{}) do
    Repo.transaction(fn ->
      business = Repo.one!(from b in Business, where: b.id == ^key.business_id, lock: "FOR UPDATE")
      changeset = changeset(business, attrs)
      changeset = Enum.reduce(assets, changeset, fn {field, data}, cs ->
        if field in [:logo_data, :stamp_data, :signature_data] and (is_nil(data) or Waves.BrandAsset.valid_data_uri?(data)),
          do: put_change(cs, field, data), else: add_error(cs, :name, "contains an invalid image")
      end)
      case Repo.update(changeset) do
        {:ok, saved} ->
          Repo.insert!(%Audit{business_id: key.business_id, api_key_id: key.id, user_id: Map.get(key, :user_id), action: "business.settings_updated", record_id: saved.id})
          saved
        {:error, errors} -> Repo.rollback(errors)
      end
    end)
  end
  def snapshot(business) do
    business |> Map.from_struct() |> Map.take(@fields ++ [:currency, :logo_data, :stamp_data, :signature_data])
    |> Enum.into(%{}, fn {key, value} -> {Atom.to_string(key), if(match?(%Decimal{}, value), do: Decimal.to_string(value, :normal), else: value)} end)
  end
end
