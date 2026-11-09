defmodule Waves.Accounts do
  import Ecto.Query
  import Ecto.Changeset
  alias Waves.{Repo, User, UserToken, Membership, Business}

  def registration(attrs) do
    email = normalize_email(attrs["email"])
    password = attrs["password"]

    changeset =
      cast(%User{}, Map.put(attrs, "email", email), [:name, :email])
      |> validate_required([:name, :email])
      |> validate_length(:name, max: 200)
      |> validate_format(:email, ~r/\A[^\s@]+@[^\s@]+\.[^\s@]+\z/)
      |> validate_length(:email, max: 254)
      |> unique_constraint(:email)

    changeset =
      if valid_password?(password),
        do: changeset,
        else: add_error(changeset, :password_hash, "Use a password of 12–72 bytes.")

    changeset =
      if password == attrs["password_confirmation"],
        do: changeset,
        else: add_error(changeset, :password_hash, "Passwords do not match.")

    if changeset.valid?,
      do: Repo.insert(put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))),
      else: {:error, changeset}
  end

  def authenticate(email, password) when is_binary(password) and byte_size(password) <= 72 do
    user = Repo.get_by(User, email: normalize_email(email))

    cond do
      is_nil(user) ->
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}

      not Bcrypt.verify_pass(password, user.password_hash) ->
        {:error, :invalid_credentials}

      is_nil(user.confirmed_at) ->
        {:error, :unconfirmed}

      true ->
        {:ok, user}
    end
  end

  def authenticate(_, _), do: {:error, :invalid_credentials}

  def issue_token(user, purpose) do
    raw = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

    seconds =
      case purpose do
        "session" -> 30 * 86400
        "verify" -> 86400
        "reset" -> 3600
      end

    Repo.insert!(%UserToken{
      user_id: user.id,
      token_hash: hash(raw),
      purpose: purpose,
      expires_at: DateTime.add(DateTime.utc_now(), seconds, :second)
    })

    raw
  end

  def user_for_session(raw), do: user_for_token(raw, "session")

  defp user_for_token(raw, purpose) when is_binary(raw) and byte_size(raw) in 32..100 do
    Repo.one(
      from(t in UserToken,
        join: u in User,
        on: u.id == t.user_id,
        where:
          t.token_hash == ^hash(raw) and t.purpose == ^purpose and
            t.expires_at > ^DateTime.utc_now(),
        select: u
      )
    )
  end

  defp user_for_token(_, _), do: nil

  def revoke_session(raw) when is_binary(raw) do
    Repo.delete_all(
      from(t in UserToken, where: t.token_hash == ^hash(raw) and t.purpose == "session")
    )

    :ok
  end

  def revoke_session(_), do: :ok

  def confirm(raw) do
    consume(raw, "verify", fn user ->
      Repo.update!(change(user, confirmed_at: user.confirmed_at || DateTime.utc_now()))
    end)
  end

  def reset_password(raw, attrs) do
    password = attrs["password"]

    if valid_password?(password) and password == attrs["password_confirmation"] do
      consume(raw, "reset", fn user ->
        Repo.delete_all(from(t in UserToken, where: t.user_id == ^user.id))
        Repo.update!(change(user, password_hash: Bcrypt.hash_pwd_salt(password)))
      end)
    else
      {:error, :invalid_password}
    end
  end

  defp consume(raw, purpose, function) when is_binary(raw) and byte_size(raw) in 32..100 do
    Repo.transaction(fn ->
      # Lock the user before the token so password resets and simultaneous confirmations serialize.
      user = user_for_token(raw, purpose) || Repo.rollback(:expired_token)
      user = Repo.one!(from(u in User, where: u.id == ^user.id, lock: "FOR UPDATE"))

      token =
        Repo.one(
          from(t in UserToken,
            where:
              t.token_hash == ^hash(raw) and t.purpose == ^purpose and
                t.expires_at > ^DateTime.utc_now(),
            lock: "FOR UPDATE"
          )
        ) || Repo.rollback(:expired_token)

      Repo.delete!(token)
      function.(user)
    end)
  end

  defp consume(_, _, _), do: {:error, :expired_token}

  def send_link(email, purpose) when purpose in ["verify", "reset"] do
    case Repo.get_by(User, email: normalize_email(email)) do
      nil ->
        :ok

      user ->
        if purpose == "reset" or is_nil(user.confirmed_at) do
          raw = issue_token(user, purpose)
          Waves.AccountMailer.link(user, purpose, raw)
        else
          :ok
        end
    end
  end

  def businesses(user) do
    Repo.all(
      from(m in Membership,
        join: b in Business,
        on: b.id == m.business_id,
        where: m.user_id == ^user.id,
        select: b,
        order_by: b.name
      )
    )
  end

  def actor(user, business_id) do
    with {:ok, id} <- Ecto.UUID.cast(business_id),
         %Membership{} = membership <- Repo.get_by(Membership, user_id: user.id, business_id: id) do
      %{id: nil, business_id: id, user_id: user.id, role: membership.role}
    else
      _ -> nil
    end
  end

  def onboard(user, attrs) do
    tax_mode = attrs["tax_mode"] || "none"

    cs =
      %Business{}
      |> cast(attrs, [:name, :country, :currency, :tax_name, :tax_rate])
      |> put_change(:tax_mode, tax_mode)
      |> validate_required([:name, :country, :currency, :tax_name, :tax_rate])
      |> validate_length(:name, max: 200)
      |> validate_length(:country, max: 100)
      |> validate_length(:tax_name, max: 100)
      |> validate_inclusion(:currency, ["KES", "USD", "EUR", "GBP"])
      |> validate_inclusion(:tax_mode, ["none", "exclusive", "inclusive"])
      |> validate_number(:tax_rate, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
      |> validate_change(:tax_rate, fn _, rate ->
        if Decimal.equal?(rate, Decimal.round(rate, 4)),
          do: [],
          else: [tax_rate: "Use at most four decimal places."]
      end)

    if cs.valid? do
      Repo.transaction(fn ->
        business = Repo.insert!(cs)
        Repo.insert!(%Membership{user_id: user.id, business_id: business.id, role: "owner"})
        business
      end)
    else
      {:error, cs}
    end
  end

  def bootstrap_owner(business_id, attrs) do
    Repo.transaction(fn ->
      business =
        Repo.one(from(b in Business, where: b.id == ^business_id, lock: "FOR UPDATE")) ||
          Repo.rollback(:business_not_found)

      if Repo.exists?(
           from(m in Membership, where: m.business_id == ^business.id and m.role == "owner")
         ), do: Repo.rollback(:already_has_owner)

      user =
        case registration(attrs) do
          {:ok, user} -> Repo.update!(change(user, confirmed_at: DateTime.utc_now()))
          {:error, error} -> Repo.rollback(error)
        end

      Repo.insert!(%Membership{user_id: user.id, business_id: business.id, role: "owner"})
      user
    end)
  end

  defp normalize_email(email) when is_binary(email),
    do: email |> String.trim() |> String.downcase()

  defp normalize_email(_), do: ""

  defp valid_password?(password),
    do: is_binary(password) and String.length(password) >= 12 and byte_size(password) <= 72

  defp hash(token), do: Base.encode16(:crypto.hash(:sha256, token), case: :lower)
end
